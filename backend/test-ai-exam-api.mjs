// End-to-end checks for the AI Examination module against a running backend.
// Usage: SEED_PW=... node test-ai-exam-api.mjs          (run from backend/; uses Prisma only for setup checks and cleanup)
// Works with the AI evaluator unconfigured (descriptive answers stay PENDING) or with AI_PROVIDER=mock on the server.
import { PrismaClient } from '@prisma/client';

const B = process.env.API_BASE_URL ?? 'http://localhost:3000/api/v1';
const PW = process.env.SEED_PW;
if (!PW) throw new Error('Set SEED_PW');
const prisma = new PrismaClient();
const started = new Date();
const created = [];
let passed = 0;
let failed = 0;
let last = '';

const call = async (method, path, body, token) => {
  const r = await fetch(B + path, { method, headers: { 'Content-Type': 'application/json', ...(token && { Authorization: 'Bearer ' + token }) }, body: body ? JSON.stringify(body) : undefined });
  const j = await r.json().catch(() => null);
  last = `${method} ${path} -> ${r.status} ${JSON.stringify(j?.error ?? '').slice(0, 200)}`;
  return { status: r.status, data: j?.data, body: j };
};
const login = async (u) => (await call('POST', '/auth/login', { login: u, password: PW })).data.accessToken;
const check = (name, ok, extra) => {
  if (ok) {
    passed++;
    console.log('PASS', name);
  } else {
    failed++;
    console.log('FAIL', name, extra !== undefined ? JSON.stringify(extra).slice(0, 400) : '', '| last:', last);
  }
};
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

try {
  const [teacher, other, student, admin] = await Promise.all([
    login('teacher.jones@oakridge.edu'),
    login('teacher.smith@oakridge.edu'),
    login('student.john@oakridge.edu'),
    login('admin@oakridge.edu'),
  ]);
  const john = await prisma.student.findFirst({ where: { user: { email: 'student.john@oakridge.edu' } }, include: { enrollments: { where: { status: 'ACTIVE' } } } });
  const enr = john.enrollments[0];
  const schoolId = john.schoolId;
  const settingsBefore = await prisma.aiExamSettings.findUnique({ where: { schoolId } });

  const cfg = await call('GET', '/ai-evaluation/config', null, teacher);
  const aiOn = cfg.data?.configured === true;
  check('AI config endpoint reports status without secrets', cfg.status === 200 && !('apiKey' in (cfg.data ?? {})) && !(process.env.AI_API_KEY && JSON.stringify(cfg.body).includes(process.env.AI_API_KEY)), cfg.data);
  console.log('   evaluator:', aiOn ? `${cfg.data.provider}${cfg.data.mock ? ' (development mock)' : ''}` : 'not configured');

  // ------------------------------------------------------------ options & eligibility
  const opts = await call('GET', '/ai-exams/options', null, teacher);
  const g10 = opts.data?.classes?.find((c) => c.id === enr.classId);
  const sci = g10?.subjects?.[0];
  check('options list only eligible classes the teacher teaches', opts.status === 200 && g10 && opts.data.classes.every((c) => c.grade >= 10 && c.grade <= 12) && sci.sections.length === 1, opts.data);
  check('teacher of one section cannot set whole-class tests', sci && sci.wholeClass === false);

  const g9 = await prisma.class.findFirst({ where: { schoolId, code: 'G9' } });
  const now = Date.now();
  const base = { title: 'ZZAI Photosynthesis unit test', classId: enr.classId, subjectId: sci.id, chapter: 'Life processes', topics: ['Photosynthesis', 'Respiration'], instructions: 'Answer all questions.', durationMinutes: 20, startsAt: new Date(now - 60_000).toISOString(), endsAt: new Date(now + 30 * 60_000).toISOString(), assignMode: 'SECTION', sectionId: enr.sectionId };
  if (g9) check('Class 9 is refused', (await call('POST', '/ai-exams', { ...base, classId: g9.id }, teacher)).status === 403);
  check('whole-class test refused for a one-section teacher', (await call('POST', '/ai-exams', { ...base, assignMode: 'CLASS', sectionId: null }, teacher)).status === 403);
  check('students cannot create tests', (await call('POST', '/ai-exams', base, student)).status === 403);

  // ------------------------------------------------------------ create, questions, publish
  const c = await call('POST', '/ai-exams', base, teacher);
  check('teacher creates a draft test', c.status === 201 && c.data?.status === 'DRAFT', c.body);
  const testId = c.data.id;
  created.push(testId);

  const questions = [
    { type: 'MCQ', text: 'Which pigment absorbs light?', marks: 1, topic: 'Photosynthesis', options: ['Haemoglobin', 'Chlorophyll', 'Keratin'], correctOption: 1 },
    { type: 'TRUE_FALSE', text: 'Oxygen is released in photosynthesis.', marks: 1, topic: 'Photosynthesis', correctOption: 1 },
    { type: 'FILL_BLANK', text: 'Glucose is stored in plants as ____.', marks: 1, topic: 'Photosynthesis', answerKey: 'starch' },
    { type: 'NUMERICAL', text: 'How many ATP per glucose in aerobic respiration (textbook value)?', marks: 2, topic: 'Respiration', answerKey: '38', tolerance: 0 },
    {
      type: 'LONG', text: 'Explain photosynthesis.', marks: 5, topic: 'Photosynthesis', difficulty: 'MEDIUM',
      answerKey: 'Green plants use sunlight absorbed by chlorophyll to convert carbon dioxide and water into glucose, releasing oxygen.',
      concepts: ['chlorophyll', 'sunlight', 'carbon dioxide', 'water', 'glucose', 'oxygen'],
      rubric: [
        { description: 'Definition of photosynthesis', marks: 1 },
        { description: 'Role of chlorophyll', marks: 1 },
        { description: 'Role of sunlight', marks: 1 },
        { description: 'Carbon dioxide and water as raw materials', marks: 1 },
        { description: 'Formation of glucose and oxygen', marks: 1 },
      ],
    },
    { type: 'SHORT', text: 'Name the site of aerobic respiration.', marks: 2, topic: 'Respiration', answerKey: 'Mitochondria', acceptableAnswers: ['The mitochondrion'] },
  ];
  check('rubric that does not add up is rejected', (await call('POST', `/ai-exams/${testId}/questions`, { questions: [{ ...questions[4], marks: 4 }] }, teacher)).status === 400);
  check('MCQ without a correct option is rejected', (await call('POST', `/ai-exams/${testId}/questions`, { questions: [{ ...questions[0], correctOption: null }] }, teacher)).status === 400);
  check('question image must be an uploaded image path', (await call('POST', `/ai-exams/${testId}/questions`, { questions: [{ ...questions[0], imageUrl: 'https://evil.test/x.svg' }] }, teacher)).status === 400);
  const q = await call('POST', `/ai-exams/${testId}/questions`, { questions }, teacher);
  check('questions with answer keys and rubric saved; total marks computed', q.status === 201 && q.data.questions.length === 6 && q.data.totalMarks === 12 && q.data.questions[4].rubric.length === 5, q.body);

  check('draft is invisible to the student', (await call('GET', `/student/ai-exams/${testId}`, null, student)).status === 404);
  check('another teacher cannot open the test', (await call('GET', `/ai-exams/${testId}`, null, other)).status === 403);
  check('another teacher cannot see its submissions', (await call('GET', `/ai-exams/${testId}/submissions`, null, other)).status === 403);
  const pub = await call('POST', `/ai-exams/${testId}/publish`, null, teacher);
  check('teacher publishes the test', pub.status === 201 && pub.data.status === 'PUBLISHED' && pub.data.phase === 'ACTIVE', pub.body);

  // ------------------------------------------------------------ individually assigned test (not John)
  const otherStudent = await prisma.enrollment.findFirst({ where: { classId: enr.classId, sectionId: enr.sectionId, academicYearId: enr.academicYearId, status: 'ACTIVE', studentId: { not: john.id } } });
  let privateTestId = null;
  if (otherStudent) {
    const p = await call('POST', '/ai-exams', { ...base, title: 'ZZAI private test', assignMode: 'STUDENTS', studentIds: [otherStudent.studentId] }, teacher);
    privateTestId = p.data?.id;
    created.push(privateTestId);
    await call('POST', `/ai-exams/${privateTestId}/questions`, { questions: questions.slice(0, 1) }, teacher);
    await call('POST', `/ai-exams/${privateTestId}/publish`, null, teacher);
    const list = await call('GET', '/student/ai-exams', null, student);
    check('test assigned to other students is not listed for John', !JSON.stringify(list.data).includes(privateTestId));
    check('John cannot open or start a test not assigned to him', (await call('GET', `/student/ai-exams/${privateTestId}`, null, student)).status === 404 && (await call('POST', `/student/ai-exams/${privateTestId}/start`, null, student)).status === 404);
  }

  // ------------------------------------------------------------ attempt
  const list = await call('GET', '/student/ai-exams', null, student);
  check('student sees the test as available', list.status === 200 && list.data.eligible && list.data.available.some((t) => t.id === testId), list.data);
  const st = await call('POST', `/student/ai-exams/${testId}/start`, null, student);
  const leaked = JSON.stringify(st.data?.questions ?? []);
  check('start returns questions without answer keys or rubrics', st.status === 201 && st.data.questions.length === 6 && !/answerKey|correctOption|rubric|acceptableAnswers|Mitochondria|starch/.test(leaked), st.data);
  check('attempt has a deadline from the duration', st.data?.deadline && new Date(st.data.deadline) - new Date(st.data.startedAt) === 20 * 60_000);
  const qs = st.data.questions;
  const id = (type) => qs.find((x) => x.type === type).id;
  const longAnswer = 'Photosynthesis is how green plants make food. Chlorophyll absorbs sunlight, and the plant uses carbon dioxide and water to make glucose and releases oxygen.';
  const save1 = await call('PUT', `/student/ai-exams/${testId}/answers`, { answers: [
    { questionId: id('MCQ'), choice: 1 },
    { questionId: id('TRUE_FALSE'), choice: 1 },
    { questionId: id('LONG'), text: longAnswer, inputMethod: 'VOICE' },
  ] }, student);
  check('typed and voice answers autosave', save1.status === 200 && save1.data.saved === 3, save1.body);
  check('invalid option is rejected', (await call('PUT', `/student/ai-exams/${testId}/answers`, { answers: [{ questionId: id('MCQ'), choice: 5 }] }, student)).status === 400);
  check('answers to questions of another test are rejected', (await call('PUT', `/student/ai-exams/${testId}/answers`, { answers: [{ questionId: '00000000-0000-0000-0000-000000000000', text: 'x' }] }, student)).status === 400);
  const sneaky = await call('PUT', `/student/ai-exams/${testId}/answers`, { answers: [{ questionId: id('SHORT'), text: 'Mitochondria', marks: 2, score: 99 }] }, student);
  check('marks sent by the student are ignored', sneaky.status === 200 && !(await prisma.aiExamEvaluation.count({ where: { answer: { submission: { testId } } } })));
  await call('PUT', `/student/ai-exams/${testId}/answers`, { answers: [
    { questionId: id('FILL_BLANK'), text: 'Starch.' },
    { questionId: id('NUMERICAL'), text: 'It gives 36 ATP' },
    { questionId: id('SHORT'), text: 'Mitochondria', inputMethod: 'MIXED' },
  ] }, student);
  const resume = await call('POST', `/student/ai-exams/${testId}/start`, null, student);
  const byQ = Object.fromEntries(resume.data.answers.map((a) => [a.questionId, a]));
  check('refresh resumes the same attempt with saved answers', resume.data.submissionId === st.data.submissionId && byQ[id('LONG')].text === longAnswer && byQ[id('LONG')].inputMethod === 'VOICE' && byQ[id('MCQ')].choice === 1, resume.data.answers);
  check('result is not available before submitting', (await call('GET', `/student/ai-exams/${testId}/result`, null, student)).status === 404);

  const sub = await call('POST', `/student/ai-exams/${testId}/submit`, {}, student);
  check('student submits', sub.status === 201 && sub.data.status === 'SUBMITTED', sub.body);
  check('second submit is refused', (await call('POST', `/student/ai-exams/${testId}/submit`, {}, student)).status === 409);
  check('answers cannot change after submitting', (await call('PUT', `/student/ai-exams/${testId}/answers`, { answers: [{ questionId: id('MCQ'), choice: 0 }] }, student)).status === 409);
  check('results stay hidden until published', (await call('GET', `/student/ai-exams/${testId}/result`, null, student)).data?.published === false);

  // ------------------------------------------------------------ evaluation
  if (aiOn) {
    for (let i = 0; i < 60; i++) {
      const s = await call('GET', `/ai-evaluation/status/${st.data.submissionId}`, null, teacher);
      if (!['PENDING', 'PROCESSING'].includes(s.data.evaluationStatus)) break;
      await sleep(500);
    }
  }
  const detail = await call('GET', `/ai-exams/${testId}/submissions/${st.data.submissionId}`, null, teacher);
  const ev = (type) => detail.data.answers.find((a) => a.question.type === type).evaluation;
  check('objective answers are marked from the key', ev('MCQ').status === 'EVALUATED' && ev('MCQ').finalMarks === 1 && ev('MCQ').method === 'AUTO' && ev('TRUE_FALSE').finalMarks === 1 && ev('FILL_BLANK').finalMarks === 1, detail.data.answers.map((a) => [a.question.type, a.evaluation]));
  check('wrong numerical value is not given zero automatically (sent for evaluation)', ev('NUMERICAL').method !== 'AUTO');
  check('voice answer kept with its input method', detail.data.answers.find((a) => a.question.type === 'LONG').inputMethod === 'VOICE');
  if (!aiOn) {
    check('without an AI key descriptive answers stay pending (never faked)', ev('LONG').status === 'PENDING' && ev('LONG').aiMarks === null && ev('LONG').method === null);
    check('evaluate endpoint explains the missing configuration', (await call('POST', '/ai-evaluation/evaluate', { testId }, teacher)).status === 503);
  } else {
    const long = ev('LONG');
    check('AI-path evaluation stored with criteria, feedback and history', ['EVALUATED', 'REVIEW'].includes(long.status) && long.aiMarks !== null && long.aiMarks <= 5 && Array.isArray(long.criteria) && long.events.some((e) => e.kind === 'AI_RESULT'), long);
    if (cfg.data.mock) check('development evaluator results are flagged, never final AI marks', long.method === 'MOCK' && long.status === 'REVIEW' && long.finalMarks === null);
    // Duplicate prevention: put one evaluation back to PENDING and trigger two runs at once.
    await prisma.aiExamEvaluation.update({ where: { id: long.id }, data: { status: 'PENDING' } });
    await Promise.all([call('POST', '/ai-evaluation/evaluate', { submissionId: st.data.submissionId }, teacher), call('POST', '/ai-evaluation/evaluate', { submissionId: st.data.submissionId }, teacher)]);
    for (let i = 0; i < 40; i++) {
      const e = await prisma.aiExamEvaluation.findUnique({ where: { id: long.id } });
      if (!['PENDING', 'PROCESSING'].includes(e.status)) break;
      await sleep(500);
    }
    const runs = await prisma.aiExamEvaluationEvent.count({ where: { evaluationId: long.id, kind: 'AI_RESULT' } });
    check('concurrent evaluate requests evaluate the answer once', runs === 2, runs);
  }

  check('results cannot be published while the test is open', (await call('POST', `/ai-exams/${testId}/publish-results`, null, teacher)).status === 409);
  const closed = await call('POST', `/ai-exams/${testId}/close`, null, teacher);
  check('teacher closes the test', closed.data?.status === 'CLOSED');
  const pr = await call('POST', `/ai-exams/${testId}/publish-results`, null, teacher);
  check('results cannot be published until every answer is evaluated', pr.status === 409 && /evaluated/i.test(pr.body?.error?.message ?? ''), pr.body);

  // ------------------------------------------------------------ teacher review
  const longEv = (await call('GET', `/ai-exams/${testId}/submissions/${st.data.submissionId}`, null, teacher)).data.answers.find((a) => a.question.type === 'LONG').evaluation;
  check('override above the maximum is refused', (await call('PUT', `/ai-exams/evaluations/${longEv.id}/override`, { marks: 6, reason: 'too many' }, teacher)).status === 400);
  check('override needs a reason', (await call('PUT', `/ai-exams/evaluations/${longEv.id}/override`, { marks: 4 }, teacher)).status === 400);
  check('students cannot change marks', (await call('PUT', `/ai-exams/evaluations/${longEv.id}/override`, { marks: 5, reason: 'please' }, student)).status === 403);
  check('another teacher cannot change marks', (await call('PUT', `/ai-exams/evaluations/${longEv.id}/override`, { marks: 5, reason: 'x y z' }, other)).status === 403);
  const ov = await call('PUT', `/ai-exams/evaluations/${longEv.id}/override`, { marks: 4.5, reason: 'All points present; respiration link missing' }, teacher);
  check('teacher overrides the marks', ov.status === 200 && ov.data.finalMarks === 4.5, ov.body);
  const after = await prisma.aiExamEvaluation.findUnique({ where: { id: longEv.id }, include: { events: true } });
  check('teacher marks kept separate from AI marks, with reason and history', after.teacherMarks === 4.5 && after.aiMarks === longEv.aiMarks && after.overrideReason && after.events.some((e) => e.kind === 'TEACHER_OVERRIDE'));
  for (const a of (await call('GET', `/ai-exams/${testId}/submissions/${st.data.submissionId}`, null, teacher)).data.answers) {
    if (a.evaluation.status !== 'EVALUATED') {
      await call('PUT', `/ai-exams/evaluations/${a.evaluation.id}/override`, { marks: a.question.type === 'SHORT' ? 2 : 1, reason: 'Marked by teacher' }, teacher);
    }
  }
  const pr2 = await call('POST', `/ai-exams/${testId}/publish-results`, null, teacher);
  check('results published once everything is evaluated', pr2.status === 201 && pr2.data.resultsPublishedAt, pr2.body);

  // ------------------------------------------------------------ student result & analytics
  const res = await call('GET', `/student/ai-exams/${testId}/result`, null, student);
  const expected = 1 + 1 + 1 + 1 + 4.5 + 2;
  check('student sees question-wise result and model answers', res.data?.published && res.data.score === expected && res.data.maxScore === 12 && res.data.questions.length === 6 && res.data.questions.find((x) => x.type === 'LONG').modelAnswer, res.data);
  check('teacher-marked answers are labelled as such', res.data.questions.find((x) => x.type === 'LONG').evaluatedBy === 'TEACHER');
  const perf = await call('GET', '/student/ai-exams/performance', null, student);
  check('student performance uses evaluated tests', perf.status === 200 && perf.data.overall.tests >= 1 && perf.data.subjects.length >= 1 && perf.data.topics.some((t) => t.topic === 'Photosynthesis'), perf.data);
  const plan = await call('GET', '/student/ai-exams/improvement-plan', null, student);
  check('improvement plan is generated from records', plan.status === 200 && plan.data.plan && Array.isArray(plan.data.plan.priorities), plan.data);

  const an = await call('GET', `/ai-exams/analytics?classId=${enr.classId}&subjectId=${sci.id}`, null, teacher);
  check('teacher class analytics', an.status === 200 && an.data.summary.submissions >= 1 && an.data.topics.length >= 1 && an.data.hardestQuestions.length >= 1, an.data?.summary);
  check('test analytics', (await call('GET', `/ai-exams/${testId}/analytics`, null, teacher)).data?.summary?.evaluated >= 1);
  check('student drill-down for the teacher', (await call('GET', `/ai-exams/analytics/students/${john.id}`, null, teacher)).data?.overall?.tests >= 1);
  check('other teacher cannot drill into that student', (await call('GET', `/ai-exams/analytics/students/${john.id}`, null, other)).status === 403);
  check('other teacher analytics exclude tests they do not teach', !(await call('GET', '/ai-exams/analytics', null, other)).data?.tests?.some((t) => t.testId === testId));
  check('students cannot open teacher analytics', (await call('GET', '/ai-exams/analytics', null, student)).status === 403);

  const ov2 = await call('GET', '/admin/ai-exams/overview', null, admin);
  check('admin overview', ov2.status === 200 && ov2.data.counts.tests >= 1 && ov2.data.eligibleClasses.every((c) => c.grade >= 10), ov2.data?.counts);
  check('teachers cannot open admin overview', (await call('GET', '/admin/ai-exams/overview', null, teacher)).status === 403);
  const set = await call('PUT', '/admin/ai-exams/settings', { reviewConfidence: 0.7 }, admin);
  check('admin saves module settings', set.status === 200 && set.data.reviewConfidence === 0.7);
  check('admin can monitor every test', (await call('GET', '/admin/ai-exams/tests', null, admin)).body?.data?.some((t) => t.id === testId));

  // ------------------------------------------------------------ expiry
  const e = await call('POST', '/ai-exams', { ...base, title: 'ZZAI expiry test' }, teacher);
  created.push(e.data.id);
  await call('POST', `/ai-exams/${e.data.id}/questions`, { questions: questions.slice(0, 2) }, teacher);
  await call('POST', `/ai-exams/${e.data.id}/publish`, null, teacher);
  const es = await call('POST', `/student/ai-exams/${e.data.id}/start`, null, student);
  await call('PUT', `/student/ai-exams/${e.data.id}/answers`, { answers: [{ questionId: es.data.questions[0].id, choice: 1 }] }, student);
  await prisma.aiExamSubmission.update({ where: { id: es.data.submissionId }, data: { deadline: new Date(Date.now() - 5 * 60_000) } });
  check('answers are refused after the deadline', (await call('PUT', `/student/ai-exams/${e.data.id}/answers`, { answers: [{ questionId: es.data.questions[0].id, choice: 0 }] }, student)).status === 403);
  const late = await call('POST', `/student/ai-exams/${e.data.id}/submit`, { answers: [{ questionId: es.data.questions[0].id, choice: 0 }] }, student);
  const lateAns = await prisma.aiExamAnswer.findFirst({ where: { submissionId: es.data.submissionId, questionId: es.data.questions[0].id } });
  check('expired attempt is auto-submitted with the saved answers only', late.data?.autoSubmitted === true && lateAns.choice === 1, late.body);
  check('cannot restart a submitted test', (await call('POST', `/student/ai-exams/${e.data.id}/start`, null, student)).status === 409);
  check('tests with attempts cannot be deleted', (await call('DELETE', `/ai-exams/${e.data.id}`, null, teacher)).status === 409);
  check('questions are locked once attempted', (await call('POST', `/ai-exams/${e.data.id}/questions`, { questions }, teacher)).status === 409);

  // restore settings
  if (settingsBefore) await prisma.aiExamSettings.update({ where: { schoolId }, data: { autoEvaluate: settingsBefore.autoEvaluate, reviewConfidence: settingsBefore.reviewConfidence, allowVoice: settingsBefore.allowVoice } });
  else await prisma.aiExamSettings.deleteMany({ where: { schoolId } });
} catch (e) {
  failed++;
  console.log('FAIL (exception)', e?.stack ?? e);
} finally {
  await prisma.aiExamTest.deleteMany({ where: { id: { in: created.filter(Boolean) } } });
  await prisma.aiExamImprovementPlan.deleteMany({ where: { createdAt: { gte: started } } });
  const left = await prisma.aiExamTest.count({ where: { title: { startsWith: 'ZZAI' } } });
  console.log(`cleanup done (${left} test rows left)`);
  await prisma.$disconnect();
  console.log(failed ? `${failed} FAILED, ${passed} passed` : `ALL PASSED (${passed})`);
  process.exitCode = failed ? 1 : 0;
}
