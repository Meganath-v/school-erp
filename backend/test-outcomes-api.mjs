// End-to-end test of the outcome-based education API against a running backend.
// Creates throwaway data (ZZ* names/codes) and removes it at the end.
//
//   cd backend && SEED_PW=<seed password> node test-outcomes-api.mjs
//   (API defaults to http://localhost:3000/api/v1; override with API=...)
const B = process.env.API ?? 'http://localhost:3000/api/v1';
const PW = process.env.SEED_PW;
if (!PW) { console.error('Set SEED_PW to the seed accounts password'); process.exit(2); }
let failures = 0;
const ok = (c, m) => { console.log((c ? 'PASS ' : 'FAIL ') + m); if (!c) failures++; };
const call = async (method, path, body, token) => {
  const r = await fetch(B + path, { method, headers: { 'Content-Type': 'application/json', ...(token ? { Authorization: 'Bearer ' + token } : {}) }, body: body ? JSON.stringify(body) : undefined });
  let j = null; try { j = await r.json(); } catch {}
  return { status: r.status, body: j, data: j?.data };
};
const login = async (u) => (await call('POST', '/auth/login', { login: u, password: PW })).data.accessToken;
const stamp = Date.now().toString(36).toUpperCase().slice(-4);
const cleanup = { programs: [], cos: [], questions: [], assignments: [], examIds: [] };

const admin = await login('admin@oakridge.edu');
const teacher = await login('teacher.jones@oakridge.edu'); // subject teacher
const parent = await login('parent.doe@gmail.com');

try {
  // ---------- subjects visible to the teacher
  const tSubjects = (await call('GET', '/outcomes/subjects', null, teacher)).data;
  const aSubjects = (await call('GET', '/outcomes/subjects', null, admin)).data;
  ok(Array.isArray(tSubjects) && tSubjects.length > 0 && tSubjects.every((s) => s.canEdit), 'teacher sees only subjects they teach');
  ok(aSubjects.length >= tSubjects.length, 'admin sees all subjects');
  const subject = tSubjects.find((s) => s.classes.length > 0) ?? tSubjects[0];
  const other = aSubjects.find((s) => !tSubjects.some((t) => t.id === s.id));
  const klass = subject.classes[0];
  console.log(`   using subject ${subject.name} in ${klass?.name}`);

  ok((await call('GET', '/outcomes/programs', null, parent)).status === 403, 'parent cannot read outcomes');

  // ---------- programs & POs (admin only)
  ok((await call('POST', '/outcomes/programs', { code: 'ZZP' + stamp, name: 'x' }, teacher)).status === 403, 'teacher cannot create programs');
  const program = (await call('POST', '/outcomes/programs', { code: 'zzp' + stamp, name: 'ZZ Test Program' }, admin)).data;
  cleanup.programs.push(program.id);
  ok(program.code === 'ZZP' + stamp, 'program created, code upper-cased');
  ok((await call('POST', '/outcomes/programs', { code: 'ZZP' + stamp, name: 'dup' }, admin)).status === 409, 'duplicate program code -> 409');
  const po1 = (await call('POST', `/outcomes/programs/${program.id}/outcomes`, { type: 'PO', code: 'PO1', description: 'Knowledge' }, admin)).data;
  const po2 = (await call('POST', `/outcomes/programs/${program.id}/outcomes`, { type: 'PO', code: 'PO2', description: 'Problem analysis' }, admin)).data;
  const pso1 = (await call('POST', `/outcomes/programs/${program.id}/outcomes`, { type: 'PSO', code: 'PSO1', description: 'Specific skill' }, admin)).data;
  ok(po1?.id && po2?.id && pso1?.id, 'PO1, PO2, PSO1 created');
  ok((await call('POST', `/outcomes/programs/${program.id}/outcomes`, { type: 'XX', code: 'X1', description: 'bad' }, admin)).status === 400, 'invalid outcome type -> 400');

  // ---------- course outcomes (teacher on own subject)
  const co1 = (await call('POST', `/outcomes/subjects/${subject.id}/course-outcomes`, { code: 'ZZ1' + stamp, description: 'Explain concepts', bloomLevel: 'UNDERSTAND', orderIndex: 1 }, teacher)).data;
  const co2 = (await call('POST', `/outcomes/subjects/${subject.id}/course-outcomes`, { code: 'ZZ2' + stamp, description: 'Apply methods', bloomLevel: 'APPLY', orderIndex: 2 }, teacher)).data;
  cleanup.cos.push(co1.id, co2.id);
  ok(co1?.id && co2?.id, 'teacher creates course outcomes on their subject');
  if (other) {
    const r = await call('POST', `/outcomes/subjects/${other.id}/course-outcomes`, { code: 'ZZX', description: 'x', bloomLevel: 'APPLY' }, teacher);
    ok(r.status === 403, 'teacher cannot edit a subject they do not teach');
  }

  // ---------- mapping (explicit program because the class is not linked yet)
  const save = await call('PUT', `/outcomes/subjects/${subject.id}/mapping`, { entries: [
    { courseOutcomeId: co1.id, programOutcomeId: po1.id, strength: 3 },
    { courseOutcomeId: co2.id, programOutcomeId: po1.id, strength: 1 },
    { courseOutcomeId: co1.id, programOutcomeId: pso1.id, strength: 2 },
    { courseOutcomeId: co2.id, programOutcomeId: po2.id, strength: 2 },
  ] }, teacher);
  ok(save.status === 200, 'teacher saves CO-PO mapping');
  await call('PUT', `/outcomes/subjects/${subject.id}/mapping`, { entries: [{ courseOutcomeId: co2.id, programOutcomeId: po2.id, strength: 0 }] }, teacher);
  const matrix = (await call('GET', `/outcomes/subjects/${subject.id}/mapping?programId=${program.id}`, null, teacher)).data;
  const mine = matrix.entries.filter((e) => [co1.id, co2.id].includes(e.courseOutcomeId));
  ok(mine.length === 3 && !mine.some((e) => e.programOutcomeId === po2.id), 'strength 0 removes a link; 3 links remain');
  ok((await call('PUT', `/outcomes/subjects/${subject.id}/mapping`, { entries: [{ courseOutcomeId: co1.id, programOutcomeId: po1.id, strength: 4 }] }, teacher)).status === 400, 'strength > 3 -> 400');

  // link the class to the program so attainment picks it up without programId
  if (klass) {
    const linked = await call('PUT', `/outcomes/programs/${program.id}/classes`, { classIds: [klass.id] }, admin);
    ok(linked.status === 200 && linked.data.classes.some((c) => c.id === klass.id), 'class linked to program');
  }

  // ---------- question bank
  const q = async (text, marks, co, bloom) => (await call('POST', `/outcomes/subjects/${subject.id}/questions`, { text, marks, bloomLevel: bloom, courseOutcomeId: co }, teacher)).data;
  const q1 = await q('ZZ Define the term', 10, co1.id, 'REMEMBER');
  const q2 = await q('ZZ Explain with example', 10, co1.id, 'UNDERSTAND');
  const q3 = await q('ZZ Solve the problem', 5, co2.id, 'APPLY');
  const q4 = await q('ZZ Unmapped question', 5, null, 'APPLY');
  cleanup.questions.push(q1.id, q2.id, q3.id, q4.id);
  ok(q1.courseOutcome?.id === co1.id && q4.courseOutcome === null, 'questions created with CO tags');
  if (other) {
    const otherCo = (await call('GET', `/outcomes/subjects/${other.id}/course-outcomes`, null, admin)).data[0];
    if (otherCo) ok((await call('POST', `/outcomes/subjects/${subject.id}/questions`, { text: 'x', marks: 1, bloomLevel: 'APPLY', courseOutcomeId: otherCo.id }, teacher)).status === 400, 'question cannot use another subject’s CO');
  }

  // ---------- throwaway exam (INTERNAL) and assignment (also INTERNAL) for the class
  const sections = (await call('GET', '/schools/classes', null, admin)).data.find((c) => c.id === klass.id).sections;
  const exam = (await call('POST', '/exams', { name: 'ZZ Unit Test ' + stamp, term: 'TERM_1', startDate: '2026-12-01', endDate: '2026-12-02' }, admin)).data;
  cleanup.examIds.push(exam.id);
  const es = (await call('POST', `/exams/${exam.id}/subjects`, { classId: klass.id, subjectId: subject.id, examDate: '2026-12-01', maxMarks: 30, passMarks: 12 }, admin)).data;
  ok(es?.id, 'test exam subject created');

  // paper validation
  ok((await call('PUT', `/outcomes/exam-subjects/${es.id}/paper`, { title: 'too big', sections: [{ title: 'A', items: [{ questionId: q1.id, label: '1', marks: 40 }] }] }, teacher)).status === 400, 'paper over the max marks -> 400');
  ok((await call('PUT', `/outcomes/exam-subjects/${es.id}/paper`, { title: 'dup', sections: [{ title: 'A', items: [{ questionId: q1.id, label: '1' }, { questionId: q2.id, label: '1' }] }] }, teacher)).status === 400, 'duplicate question labels -> 400');
  const paper = await call('PUT', `/outcomes/exam-subjects/${es.id}/paper`, { title: 'Unit test paper', durationMinutes: 60, sections: [
    { title: 'Part A', items: [{ questionId: q1.id, label: '1' }, { questionId: q2.id, label: '2' }] },
    { title: 'Part B', items: [{ questionId: q3.id, label: '3' }, { questionId: q4.id, label: '4' }] },
  ] }, teacher);
  ok(paper.status === 200 && paper.data.totalMarks === 30, 'paper saved (2 sections, 30 marks, bank marks used)');

  // marks roster
  const roster = (await call('GET', `/outcomes/exam-subjects/${es.id}/marks`, null, teacher)).data;
  ok(roster.items.length === 4 && roster.students.length > 0, `marks roster: 4 questions, ${roster.students.length} students`);
  const it = Object.fromEntries(roster.items.map((i) => [i.label, i.id]));
  const st = roster.students.map((s) => s.studentId);
  ok((await call('PUT', `/outcomes/exam-subjects/${es.id}/marks`, { entries: [{ studentId: st[0], itemId: it['3'], marks: 6 }] }, teacher)).status === 400, 'marks above the question maximum -> 400');

  // Design data so expected attainment is known. CO1 = q1+q2 (20 marks), CO2 = q3 (5 marks).
  // target 60% (school default rule). With n students: s0 CO1 15/20 ✓, CO2 4/5 ✓; s1 CO1 10/20 ✗, CO2 1/5 ✗; others CO1 12/20 ✓ (=60%), CO2 3/5 ✓.
  const entries = [];
  st.forEach((sid, idx) => {
    const [a, b, c] = idx === 0 ? [8, 7, 4] : idx === 1 ? [5, 5, 1] : [6, 6, 3];
    entries.push({ studentId: sid, itemId: it['1'], marks: a }, { studentId: sid, itemId: it['2'], marks: b }, { studentId: sid, itemId: it['3'], marks: c }, { studentId: sid, itemId: it['4'], marks: 2 });
  });
  const saved = await call('PUT', `/outcomes/exam-subjects/${es.id}/marks`, { entries }, teacher);
  ok(saved.status === 200 && saved.data.students[0].total === 21, 'question marks saved; total for first student = 8+7+4+2 = 21');
  const details = (await call('GET', `/exams/subjects/${es.id}/details`, null, teacher)).data;
  const totalsSynced = JSON.stringify(details).includes('"marksObtained":21');
  ok(totalsSynced, 'exam mark total synced to the regular exam marks');

  ok((await call('PUT', `/outcomes/exam-subjects/${es.id}/paper`, { title: 'change', sections: [{ title: 'A', items: [{ questionId: q1.id, label: '1' }] }] }, teacher)).status === 409, 'paper cannot change once marks exist -> 409');
  ok((await call('DELETE', `/outcomes/questions/${q1.id}`, null, teacher)).status === 409, 'question in use cannot be deleted -> 409');

  // ---------- attainment
  const n = st.length;
  const att = (await call('GET', `/outcomes/subjects/${subject.id}/attainment?programId=${program.id}`, null, teacher)).data;
  const c1 = att.courseOutcomes.find((c) => c.courseOutcomeId === co1.id);
  const c2 = att.courseOutcomes.find((c) => c.courseOutcomeId === co2.id);
  const pctAttained = Math.round(((n - 1) / n) * 10000) / 100;
  const expLevel = pctAttained >= 60 ? 3 : pctAttained >= 50 ? 2 : pctAttained >= 40 ? 1 : 0;
  console.log(`   ${n} students -> ${pctAttained}% attain CO1 and CO2 -> level ${expLevel}`);
  ok(c1.internal?.studentsAssessed === n && c1.internal?.studentsAttained === n - 1, 'CO1: everyone assessed, all but one attain (60% boundary counts)');
  ok(c1.internal.level === expLevel && c1.external === null && c1.finalLevel === expLevel, `CO1 level ${expLevel}, internal only, no survey ⇒ final = ${expLevel}`);
  ok(c2.internal?.studentsAttained === n - 1 && c2.finalLevel === expLevel, 'CO2 matches');
  ok(att.summary.unmappedQuestions >= 1, 'unmapped question reported in summary');

  // indirect + external
  await call('PATCH', `/outcomes/exam-subjects/${es.id}/assessment-type`, { assessmentType: 'EXTERNAL' }, teacher);
  await call('PUT', `/outcomes/subjects/${subject.id}/indirect`, { entries: [{ courseOutcomeId: co1.id, level: 3 }] }, teacher);
  const att2 = (await call('GET', `/outcomes/subjects/${subject.id}/attainment?programId=${program.id}`, null, teacher)).data;
  const d1 = att2.courseOutcomes.find((c) => c.courseOutcomeId === co1.id);
  const expFinal = Math.round(((80 * expLevel + 20 * 3) / 100) * 100) / 100;
  ok(d1.external?.level === expLevel && d1.internal === null, 'after switching to EXTERNAL the marks count as external');
  ok(d1.finalLevel === expFinal, `with survey level 3: final = 0.8×${expLevel} + 0.2×3 = ${expFinal}`);
  const p1 = att2.programOutcomes.find((p) => p.programOutcomeId === po1.id);
  const d2 = att2.courseOutcomes.find((c) => c.courseOutcomeId === co2.id);
  const expPo1 = Math.round(((3 * d1.finalLevel + 1 * d2.finalLevel) / 4) * 100) / 100;
  ok(p1.attainment === expPo1, `PO1 = (3×CO1 + 1×CO2)/4 = ${expPo1}`);
  ok(att2.programOutcomes.find((p) => p.programOutcomeId === po2.id).attainment === null, 'PO2 (no mapping) has no attainment');

  // subject rule
  ok((await call('PUT', `/outcomes/subjects/${subject.id}/attainment-rule`, { studentTargetPercent: 50, level1Percent: 70, level2Percent: 50, level3Percent: 80, internalWeight: 40, externalWeight: 60, directWeight: 80, indirectWeight: 20, targetLevel: 2 }, teacher)).status === 400, 'rule with non-increasing thresholds -> 400');
  const ruleSaved = await call('PUT', `/outcomes/subjects/${subject.id}/attainment-rule`, { studentTargetPercent: 80, level1Percent: 40, level2Percent: 50, level3Percent: 60, internalWeight: 40, externalWeight: 60, directWeight: 80, indirectWeight: 20, targetLevel: 2 }, teacher);
  ok(ruleSaved.data?.source === 'SUBJECT', 'subject rule saved');
  const att3 = (await call('GET', `/outcomes/subjects/${subject.id}/attainment?programId=${program.id}`, null, teacher)).data;
  ok(att3.courseOutcomes.find((c) => c.courseOutcomeId === co1.id).external.studentsAttained === 0, 'stricter rule (80% target): nobody attains CO1');
  ok((await call('PUT', '/outcomes/attainment-rule', ruleSaved.data.rule, teacher)).status === 403, 'teacher cannot change the school default rule');
  await call('DELETE', `/outcomes/subjects/${subject.id}/attainment-rule`, null, teacher);

  // program attainment
  const pa = await call('GET', `/outcomes/programs/${program.id}/attainment`, null, admin);
  ok(pa.status === 200 && pa.data.programOutcomes.length === 3, 'program-level attainment returns all program outcomes');

  // ---------- assignment paper: totals sync to submissions
  const asg = (await call('POST', '/assignments', { title: 'ZZ Worksheet ' + stamp, classId: klass.id, sectionId: sections[0].id, subjectId: subject.id, dueDate: '2026-12-10', maxMarks: 20 }, teacher)).data;
  cleanup.assignments.push(asg.id);
  const apaper = await call('PUT', `/outcomes/assignments/${asg.id}/paper`, { title: 'Worksheet', sections: [{ title: 'Questions', items: [{ questionId: q3.id, label: 'a' }, { questionId: q4.id, label: 'b' }] }] }, teacher);
  ok(apaper.status === 200 && apaper.data.totalMarks === 10, 'assignment paper saved');
  const aroster = (await call('GET', `/outcomes/assignments/${asg.id}/marks`, null, teacher)).data;
  const aitems = Object.fromEntries(aroster.items.map((i) => [i.label, i.id]));
  const s0 = aroster.students[0].studentId;
  await call('PUT', `/outcomes/assignments/${asg.id}/marks`, { entries: [{ studentId: s0, itemId: aitems.a, marks: 4.5 }, { studentId: s0, itemId: aitems.b, marks: 3 }] }, teacher);
  const subs = (await call('GET', `/assignments/${asg.id}/submissions`, null, teacher)).data;
  const sub = (Array.isArray(subs) ? subs : subs?.submissions ?? []).find((x) => (x.studentId ?? x.student?.id) === s0);
  ok(sub && sub.marksObtained === 8, 'assignment total 4.5 + 3 = 7.5 rounds to 8 on the submission');
  const cleared = await call('PUT', `/outcomes/assignments/${asg.id}/marks`, { entries: [{ studentId: s0, itemId: aitems.a, marks: null }, { studentId: s0, itemId: aitems.b, marks: null }] }, teacher);
  ok(cleared.data.students.find((x) => x.studentId === s0).total === null, 'null clears question marks');
} catch (e) {
  failures++;
  console.log('FAIL unexpected error:', e.stack ?? e);
} finally {
  // ---------- cleanup of throwaway data (exams have no delete endpoint, so use Prisma directly)
  for (const id of cleanup.assignments) await call('DELETE', `/assignments/${id}`, null, admin);
  for (const id of cleanup.programs) await call('DELETE', `/outcomes/programs/${id}`, null, admin);
  try {
    const { PrismaClient } = await import('@prisma/client');
    const prisma = new PrismaClient();
    await prisma.exam.deleteMany({ where: { id: { in: cleanup.examIds }, name: { startsWith: 'ZZ ' } } });
    await prisma.question.deleteMany({ where: { id: { in: cleanup.questions }, text: { startsWith: 'ZZ ' } } });
    await prisma.courseOutcome.deleteMany({ where: { id: { in: cleanup.cos }, code: { startsWith: 'ZZ' } } });
    await prisma.$disconnect();
    console.log('cleanup done');
  } catch (e) {
    console.log('cleanup failed:', e.message);
  }
  console.log(failures ? `${failures} FAILED` : 'ALL PASSED');
  process.exitCode = failures ? 1 : 0;
}
