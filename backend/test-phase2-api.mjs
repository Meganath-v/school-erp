// End-to-end test of internal marks, weak students and quizzes against a running backend.
// Creates throwaway data (ZZ* names) and removes it at the end.
//
//   cd backend && SEED_PW=<seed password> node test-phase2-api.mjs
const B = process.env.API ?? 'http://localhost:3000/api/v1';
const PW = process.env.SEED_PW;
if (!PW) { console.error('Set SEED_PW to the seed accounts password'); process.exit(2); }
let failures = 0;
const ok = (c, m) => { console.log((c ? 'PASS ' : 'FAIL ') + m); if (!c) failures++; };
const call = async (method, path, body, token) => {
  const r = await fetch(B + path, { method, headers: { 'Content-Type': 'application/json', ...(token ? { Authorization: 'Bearer ' + token } : {}) }, body: body ? JSON.stringify(body) : undefined });
  let j = null; try { j = await r.json(); } catch {}
  return { status: r.status, data: j?.data, body: j };
};
const login = async (u) => (await call('POST', '/auth/login', { login: u, password: PW })).data.accessToken;
const stamp = Date.now().toString(36).toUpperCase().slice(-4);
const clean = { exams: [], assignments: [], schemes: [], quizzes: [], questions: [] };

const admin = await login('admin@oakridge.edu');
const teacher = await login('teacher.jones@oakridge.edu');
const student = await login('student.john@oakridge.edu');
const parent = await login('parent.doe@gmail.com');

try {
  const subjects = (await call('GET', '/outcomes/subjects', null, teacher)).data;
  const subject = subjects.find((s) => s.classes.length);
  const other = (await call('GET', '/outcomes/subjects', null, admin)).data.find((s) => !subjects.some((t) => t.id === s.id));
  const klass = subject.classes[0];
  const sections = (await call('GET', '/schools/classes', null, admin)).data.find((c) => c.id === klass.id).sections;
  console.log(`   subject ${subject.name}, class ${klass.name}`);

  // ---------- assessments with known totals (via question-wise marks)
  const q20 = (await call('POST', `/outcomes/subjects/${subject.id}/questions`, { text: 'ZZ long answer', marks: 20, bloomLevel: 'APPLY' }, teacher)).data;
  clean.questions.push(q20.id);
  const examSubject = async (name) => {
    const exam = (await call('POST', '/exams', { name: `ZZ ${name} ${stamp}`, term: 'TERM_1', startDate: '2026-12-01', endDate: '2026-12-02' }, admin)).data;
    clean.exams.push(exam.id);
    const es = (await call('POST', `/exams/${exam.id}/subjects`, { classId: klass.id, subjectId: subject.id, examDate: '2026-12-01', maxMarks: 20 }, admin)).data;
    await call('PUT', `/outcomes/exam-subjects/${es.id}/paper`, { title: name, sections: [{ title: 'A', items: [{ questionId: q20.id, label: '1' }] }] }, teacher);
    return es;
  };
  const t1 = await examSubject('Test 1');
  const t2 = await examSubject('Test 2');
  const roster = (await call('GET', `/outcomes/exam-subjects/${t1.id}/marks`, null, teacher)).data;
  const students = roster.students.map((s) => s.studentId);
  const setMarks = async (kind, id, values) => {
    const r = (await call('GET', `/outcomes/${kind}/${id}/marks`, null, teacher)).data;
    const itemId = r.items[0].id;
    await call('PUT', `/outcomes/${kind}/${id}/marks`, { entries: students.map((s, i) => ({ studentId: s, itemId, marks: values[i % values.length] })) }, teacher);
  };
  // student 0: test1 18/20 (0.9), test2 10/20 (0.5); student 1: 4/20, 6/20
  await setMarks('exam-subjects', t1.id, [18, 4, 12, 16]);
  await setMarks('exam-subjects', t2.id, [10, 6, 14, 8]);
  const asg = (await call('POST', '/assignments', { title: 'ZZ Worksheet ' + stamp, classId: klass.id, sectionId: sections[0].id, subjectId: subject.id, dueDate: '2026-12-10', maxMarks: 20 }, teacher)).data;
  clean.assignments.push(asg.id);
  await call('PUT', `/outcomes/assignments/${asg.id}/paper`, { title: 'Worksheet', sections: [{ title: 'A', items: [{ questionId: q20.id, label: '1' }] }] }, teacher);
  const aRoster = (await call('GET', `/outcomes/assignments/${asg.id}/marks`, null, teacher)).data;
  await call('PUT', `/outcomes/assignments/${asg.id}/marks`, { entries: [{ studentId: aRoster.students[0].studentId, itemId: aRoster.items[0].id, marks: 15 }] }, teacher);

  // ---------- internal mark scheme
  const bad = await call('POST', `/internal-assessment/subjects/${subject.id}/schemes`, { name: 'bad', classId: klass.id, components: [{ label: 'x', type: 'EXAM', weight: 10, sourceIds: [asg.id] }] }, teacher);
  ok(bad.status === 400, 'exam component pointing at an assignment -> 400');
  if (other) ok((await call('POST', `/internal-assessment/subjects/${other.id}/schemes`, { name: 'x', components: [{ label: 'm', type: 'MANUAL', weight: 5 }] }, teacher)).status === 403, 'teacher cannot create a scheme for a subject they do not teach');
  const scheme = await call('POST', `/internal-assessment/subjects/${subject.id}/schemes`, {
    name: 'ZZ Internal ' + stamp, classId: klass.id, passPercent: 40, components: [
      { label: 'Class tests (best 1)', type: 'EXAM', weight: 20, bestOf: 1, sourceIds: [t1.id, t2.id] },
      { label: 'Assignment', type: 'ASSIGNMENT', weight: 10, sourceIds: [asg.id] },
      { label: 'Attendance', type: 'ATTENDANCE', weight: 5 },
      { label: 'Participation', type: 'MANUAL', weight: 5 },
    ] }, teacher);
  ok(scheme.status === 201 && scheme.data.components.length === 4, 'scheme with 4 components created');
  clean.schemes.push(scheme.data.id);
  const manual = scheme.data.components.find((c) => c.type === 'MANUAL');
  ok((await call('PUT', `/internal-assessment/components/${manual.id}/manual-marks`, { entries: [{ studentId: students[0], marks: 6 }] }, teacher)).status === 400, 'manual mark above the weight -> 400');
  await call('PUT', `/internal-assessment/components/${manual.id}/manual-marks`, { entries: [{ studentId: students[0], marks: 4 }] }, teacher);

  const sheet = (await call('GET', `/internal-assessment/schemes/${scheme.data.id}/sheet`, null, teacher)).data;
  const s0 = sheet.students.find((s) => s.studentId === students[0]);
  const s1 = sheet.students.find((s) => s.studentId === students[1]);
  const byLabel = (s) => Object.fromEntries(s.components.map((c) => [c.label, c.score]));
  ok(byLabel(s0)['Class tests (best 1)'] === 18, 'best 1 of 2 tests: 0.9 × 20 = 18');
  ok(byLabel(s0)['Assignment'] === 7.5, 'assignment 15/20 × 10 = 7.5');
  ok(byLabel(s0)['Participation'] === 4, 'manual mark 4');
  const att = byLabel(s0)['Attendance'];
  ok(att === null || (att >= 0 && att <= 5), `attendance component within 0..5 (${att})`);
  ok(Math.abs(s0.total - (18 + 7.5 + 4 + (att ?? 0))) < 0.01 && s0.max === 40, `total ${s0.total} / 40 adds up`);
  ok(byLabel(s1)['Class tests (best 1)'] === 6 && byLabel(s1)['Assignment'] === null && s1.complete === false, 'student without assignment mark: 0.3 × 20 = 6, incomplete');

  // update keeps manual marks for kept components
  const upd = await call('PUT', `/internal-assessment/schemes/${scheme.data.id}`, {
    name: 'ZZ Internal ' + stamp, classId: klass.id, passPercent: 50,
    components: scheme.data.components.map((c) => ({ id: c.id, label: c.label, type: c.type, weight: c.weight, bestOf: c.bestOf, sourceIds: c.sourceIds })),
  }, teacher);
  const sheet2 = (await call('GET', `/internal-assessment/schemes/${scheme.data.id}/sheet`, null, teacher)).data;
  ok(upd.status === 200 && byLabel(sheet2.students.find((s) => s.studentId === students[0]))['Participation'] === 4, 'updating the scheme keeps manual marks');

  // ---------- weak students
  const weakExam = (await call('GET', `/internal-assessment/weak-students?examSubjectId=${t1.id}&threshold=50`, null, teacher)).data;
  ok(weakExam.students.some((s) => s.studentId === students[1]) && !weakExam.students.some((s) => s.studentId === students[0]), 'exam weak list: 20% student flagged, 90% student not');
  const weakScheme = (await call('GET', `/internal-assessment/weak-students?schemeId=${scheme.data.id}`, null, teacher)).data;
  ok(weakScheme.threshold === 50 && weakScheme.students.every((s) => s.percent < 50), 'scheme weak list uses the scheme pass % (50) and lists only students below it');
  ok((await call('GET', '/internal-assessment/weak-students', null, teacher)).status === 400, 'weak students without a source -> 400');

  // ---------- quizzes
  ok((await call('POST', `/outcomes/subjects/${subject.id}/questions`, { text: 'ZZ one option', marks: 1, bloomLevel: 'REMEMBER', type: 'MCQ', options: ['only'], correctOption: 0 }, teacher)).status === 400, 'MCQ with one option -> 400');
  const mcq = async (text, options, correct) => {
    const q = (await call('POST', `/outcomes/subjects/${subject.id}/questions`, { text, marks: 1, bloomLevel: 'REMEMBER', type: 'MCQ', options, correctOption: correct }, teacher)).data;
    clean.questions.push(q.id);
    return q;
  };
  const m1 = await mcq('ZZ Unit of force?', ['Joule', 'Newton', 'Watt'], 1);
  const m2 = await mcq('ZZ Speed = distance ÷ ?', ['time', 'mass'], 0);
  ok(Array.isArray(m1.options) && m1.correctOption === 1, 'MCQ stored with options and answer');

  const quiz = (await call('POST', '/quizzes', { title: 'ZZ Quiz ' + stamp, subjectId: subject.id, classId: klass.id, durationMinutes: 10 }, teacher)).data;
  clean.quizzes.push(quiz.id);
  ok(quiz.status === 'DRAFT', 'quiz created as draft');
  ok((await call('POST', `/quizzes/${quiz.id}/publish`, null, teacher)).status === 400, 'publishing without questions -> 400');
  ok((await call('PUT', `/quizzes/${quiz.id}/questions`, { questions: [{ questionId: q20.id }] }, teacher)).status === 400, 'descriptive question in a quiz -> 400');
  await call('PUT', `/quizzes/${quiz.id}/questions`, { questions: [{ questionId: m1.id, marks: 2 }, { questionId: m2.id }] }, teacher);
  ok((await call('POST', `/quizzes/${quiz.id}/publish`, null, teacher)).data?.status === 'PUBLISHED', 'quiz published');

  const mine = (await call('GET', '/quizzes/mine', null, student)).data;
  ok(Array.isArray(mine) && mine.some((q) => q.id === quiz.id && q.open && q.maxScore === 3), 'student sees the open quiz (3 marks)');
  ok((await call('GET', '/quizzes/mine', null, parent)).status === 403, 'parent cannot take quizzes');
  ok((await call('GET', `/quizzes/${quiz.id}`, null, student)).status === 403, 'student cannot read the staff view (answers)');
  const started = (await call('POST', `/quizzes/${quiz.id}/start`, null, student)).data;
  ok(started.status === 'IN_PROGRESS' && started.questions.length === 2 && started.questions.every((q) => !('correctOption' in q)), 'start returns questions without answers');
  ok(!!started.deadline, 'attempt has a deadline from the duration');
  ok((await call('PUT', `/quizzes/${quiz.id}/questions`, { questions: [{ questionId: m1.id }] }, teacher)).status === 409, 'questions locked once an attempt exists -> 409');
  const submitted = (await call('POST', `/quizzes/${quiz.id}/submit`, { answers: { [m1.id]: 1, [m2.id]: 1 } }, student)).data;
  ok(submitted.score === 2 && submitted.maxScore === 3 && submitted.questions.find((q) => q.questionId === m2.id).correctOption === 0, 'graded 2/3; answers revealed after submitting');
  ok((await call('POST', `/quizzes/${quiz.id}/submit`, { answers: {} }, student)).status === 409, 'second submission -> 409');
  const results = (await call('GET', `/quizzes/${quiz.id}/results`, null, teacher)).data;
  const mineRow = results.students.find((s) => s.status === 'SUBMITTED');
  ok(mineRow && mineRow.score === 2 && results.summary.submitted === 1, 'teacher results show the submission');
  ok((await call('DELETE', `/outcomes/questions/${m1.id}`, null, teacher)).status === 409, 'question used in a quiz cannot be deleted -> 409');
} catch (e) {
  failures++;
  console.log('FAIL unexpected error:', e.stack ?? e);
} finally {
  for (const id of clean.quizzes) await call('DELETE', `/quizzes/${id}`, null, admin);
  for (const id of clean.schemes) await call('DELETE', `/internal-assessment/schemes/${id}`, null, admin);
  for (const id of clean.assignments) await call('DELETE', `/assignments/${id}`, null, admin);
  try {
    const { PrismaClient } = await import('@prisma/client');
    const prisma = new PrismaClient();
    await prisma.exam.deleteMany({ where: { id: { in: clean.exams }, name: { startsWith: 'ZZ ' } } });
    await prisma.question.deleteMany({ where: { id: { in: clean.questions }, text: { startsWith: 'ZZ ' } } });
    await prisma.$disconnect();
    console.log('cleanup done');
  } catch (e) {
    console.log('cleanup failed:', e.message);
  }
  console.log(failures ? `${failures} FAILED` : 'ALL PASSED');
  process.exitCode = failures ? 1 : 0;
}
