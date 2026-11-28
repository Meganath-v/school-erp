// End-to-end checks for the bell schedule, class timetable, substitutions, period attendance,
// one-class-teacher rule and class-teacher admissions, against a running backend with seed data.
// Usage: SEED_PW=... node test-timetable-api.mjs   (run from backend/; Prisma is used for setup and cleanup only)
// Uses periods 11 and 12 (late evening) yesterday/today/tomorrow so real timetable data is untouched,
// and restores the bell schedule and class teacher exactly as they were.
import 'dotenv/config';
import { PrismaClient } from '@prisma/client';

const B = process.env.API_BASE_URL ?? 'http://localhost:3000/api/v1';
const PW = process.env.SEED_PW;
if (!PW) throw new Error('Set SEED_PW');
const dbUrl = new URL(process.env.DATABASE_URL);
if (!dbUrl.searchParams.has('connect_timeout')) dbUrl.searchParams.set('connect_timeout', '60');
const prisma = new PrismaClient({ datasources: { db: { url: dbUrl.toString() } } });

let passed = 0;
let failed = 0;
let last = '';
const call = async (method, path, body, token) => {
  const r = await fetch(B + path, { method, headers: { 'Content-Type': 'application/json', ...(token && { Authorization: 'Bearer ' + token }) }, body: body ? JSON.stringify(body) : undefined });
  const j = await r.json().catch(() => null);
  last = `${method} ${path} -> ${r.status} ${JSON.stringify(j?.error?.message ?? '').slice(0, 200)}`;
  return { status: r.status, data: j?.data, error: j?.error };
};
const login = async (u) => (await call('POST', '/auth/login', { login: u, password: PW })).data.accessToken;
const check = (name, ok, extra) => {
  if (ok) { passed++; console.log('PASS', name); }
  else { failed++; console.log('FAIL', name, extra !== undefined ? JSON.stringify(extra).slice(0, 400) : '', '| last:', last); }
};

const today = new Intl.DateTimeFormat('en-CA', { timeZone: 'Asia/Kolkata', year: 'numeric', month: '2-digit', day: '2-digit' }).format(new Date());
const shift = (text, days) => { const d = new Date(text + 'T00:00:00Z'); d.setUTCDate(d.getUTCDate() + days); return d.toISOString().slice(0, 10); };
const dow = (text) => { const d = new Date(text + 'T00:00:00Z').getUTCDay(); return d === 0 ? 7 : d; };
const yesterday = shift(today, -1);
const tomorrow = shift(today, 1);
const [dY, dT, dN] = [yesterday, today, tomorrow].map(dow);
const P = (day, n, s, e) => ({ dayOfWeek: day, periodNumber: n, startTime: s, endTime: e, label: `Test P${n}` });
const testPeriods = [dY, dT, dN].flatMap((d) => [P(d, 11, '22:00', '22:20'), P(d, 12, '22:25', '22:45')]);

const school = await prisma.school.findFirst({ where: { code: 'OAK01' } });
const secA = await prisma.section.findFirst({ where: { schoolId: school.id, name: 'Section A', class: { name: 'Grade 10' } } });
const secB = await prisma.section.findFirst({ where: { schoolId: school.id, name: 'Section B', class: { name: 'Grade 10' } } });
const subj = Object.fromEntries((await prisma.subject.findMany({ where: { schoolId: school.id } })).map((s) => [s.name, s]));
const jones = await prisma.staff.findFirst({ where: { schoolId: school.id, email: 'teacher.jones@oakridge.edu' } });
const smithStaff = await prisma.staff.findFirst({ where: { schoolId: school.id, email: 'teacher.smith@oakridge.edu' } });
const originalCT = await prisma.teacherAssignment.findMany({ where: { schoolId: school.id, sectionId: secA.id, isClassTeacher: true } });
let originalPeriods = [];
const createdStudents = [];
const pastDaily = '2020-01-06';

try {
  const [office, smith, jonesT, admin, student] = [
    await login('oakoffice'),
    await login('teacher.smith@oakridge.edu'),
    await login('teacherjones'),
    await login('admin@oakridge.edu'),
    await login('student.john@oakridge.edu'),
  ];
  check('logins', office && smith && jonesT && admin && student);

  // ------------------------------------------------ bell schedule (office)
  const before = await call('GET', '/timetable/periods', null, office);
  check('office reads bell schedule', before.status === 200 && Array.isArray(before.data.periods));
  originalPeriods = before.data.periods;
  const kept = originalPeriods.filter((p) => !(p.periodNumber >= 11));
  check('class teacher cannot change bell schedule', (await call('PUT', '/timetable/periods', { periods: kept }, smith)).status === 403);
  check('subject teacher cannot change bell schedule', (await call('PUT', '/timetable/periods', { periods: kept }, jonesT)).status === 403);
  check('overlapping periods rejected', (await call('PUT', '/timetable/periods', { periods: [...kept, P(dT, 11, '22:00', '22:30'), P(dT, 12, '22:20', '22:45')] }, office)).status === 400);
  check('end before start rejected', (await call('PUT', '/timetable/periods', { periods: [...kept, P(dT, 11, '22:30', '22:00')] }, office)).status === 400);
  check('bad time format rejected', (await call('PUT', '/timetable/periods', { periods: [...kept, P(dT, 11, '9:00', '22:00')] }, office)).status === 400);
  const saved = await call('PUT', '/timetable/periods', { periods: [...kept, ...testPeriods] }, office);
  check('office saves bell schedule', saved.status === 200 && saved.data.periods.filter((p) => p.periodNumber >= 11).length === 6, saved.data);
  const std = [['09:00', '09:45'], ['09:45', '10:30'], ['10:45', '11:30'], ['11:30', '12:15'], ['13:00', '13:45'], ['13:45', '14:30'], ['14:35', '15:20'], ['15:20', '16:00']];
  const fullDay = [1, 2, 3, 4, 5, 6].flatMap((d) => std.map(([s, e], i) => P(d, i + 1, s, e)));
  const full = await call('PUT', '/timetable/periods', { periods: [...fullDay, ...testPeriods] }, office);
  check('office saves a full week (54 periods) in one go', full.status === 200 && full.data.periods.length === fullDay.length + testPeriods.length, full.error);

  // ------------------------------------------------ class timetable (class teacher fills subject + teacher)
  const ct = await call('GET', `/timetable/class/${secA.id}`, null, smith);
  check('class teacher sees own class timetable as editable', ct.status === 200 && ct.data.canEdit === true && ct.data.subjects.length >= 1);
  check('subject teacher sees it read-only', (await call('GET', `/timetable/class/${secA.id}`, null, jonesT)).data?.canEdit === false);
  check('student cannot read class timetable editor', (await call('GET', `/timetable/class/${secA.id}`, null, student)).status === 403);
  const slot = (day, n, subject, teacher) => ({ dayOfWeek: day, periodNumber: n, subjectId: subj[subject].id, teacher });
  check('subject teacher cannot fill slots', (await call('PUT', `/timetable/class/${secA.id}/slot`, slot(dT, 11, 'English Literature', 'teacherjones'), jonesT)).status === 403);
  check('class teacher cannot fill another section', (await call('PUT', `/timetable/class/${secB.id}/slot`, slot(dT, 11, 'Science', 'teacherjones'), smith)).status === 403);
  check('unknown teacher rejected', (await call('PUT', `/timetable/class/${secA.id}/slot`, slot(dT, 11, 'Science', 'nobody@nowhere.test'), smith)).status === 400);
  check('a student account is not a teacher', (await call('PUT', `/timetable/class/${secA.id}/slot`, slot(dT, 11, 'Science', 'student.john@oakridge.edu'), smith)).status === 400);
  check('slot outside the bell schedule rejected', (await call('PUT', `/timetable/class/${secA.id}/slot`, { ...slot(dT, 10, 'Science', 'teacherjones'), periodNumber: 10 }, smith)).status === 400);

  const set = await call('PUT', `/timetable/class/${secA.id}/slot`, slot(dT, 11, 'English Literature', 'teacherjones'), smith);
  const e11 = set.data?.entries?.find((e) => e.dayOfWeek === dT && e.periodNumber === 11);
  check('class teacher sets subject + teacher by username', set.status === 200 && e11?.teacher?.staffId === jones.id && e11.subject.name === 'English Literature', e11);
  const gen = await prisma.teacherAssignment.findFirst({ where: { staffId: jones.id, sectionId: secA.id, subjectId: subj['English Literature'].id } });
  check('teacher gets access to the subject (timetable assignment)', gen?.source === 'TIMETABLE');
  const outcomes = await call('GET', '/outcomes/subjects', null, jonesT);
  check('subject now appears in the teacher’s subject modules', outcomes.status === 200 && outcomes.data.some((s) => s.id === subj['English Literature'].id));
  check('slot by email works too', (await call('PUT', `/timetable/class/${secA.id}/slot`, slot(dT, 12, 'Mathematics', 'teacher.smith@oakridge.edu'), smith)).status === 200);
  check('office can fill a slot', (await call('PUT', `/timetable/class/${secA.id}/slot`, slot(dY, 11, 'Science', 'teacherjones'), office)).status === 200);
  check('tomorrow slot', (await call('PUT', `/timetable/class/${secA.id}/slot`, slot(dN, 11, 'Science', 'teacherjones'), smith)).status === 200);
  check('teacher clash across sections rejected', (await call('PUT', `/timetable/class/${secB.id}/slot`, slot(dT, 11, 'Science', 'teacherjones'), office)).status === 409);
  check('period times follow the bell schedule', set.data.entries.find((e) => e.dayOfWeek === dT && e.periodNumber === 11)?.startTime === '22:00');

  // ------------------------------------------------ daily view & my day
  const dailySmith = await call('GET', `/timetable/daily/${secA.id}?date=${today}`, null, smith);
  const d11 = dailySmith.data?.periods?.find((p) => p.periodNumber === 11);
  check('daily periods show the period teacher', dailySmith.status === 200 && d11?.effectiveTeacher?.staffId === jones.id && d11.canTakeAttendance === false);
  const dailyJones = await call('GET', `/timetable/daily/${secA.id}?date=${today}`, null, jonesT);
  check('period teacher can take attendance today', dailyJones.data?.periods?.find((p) => p.periodNumber === 11)?.canTakeAttendance === true);
  const myDay = await call('GET', `/timetable/my-day?date=${today}`, null, jonesT);
  check('my day lists the period', myDay.status === 200 && myDay.data.periods.some((p) => p.sectionId === secA.id && p.periodNumber === 11 && p.canTakeAttendance));

  // ------------------------------------------------ period attendance
  const roster = (await prisma.enrollment.findMany({ where: { sectionId: secA.id, status: 'ACTIVE' }, select: { studentId: true } })).map((r) => r.studentId);
  const records = (status = 'PRESENT') => roster.map((studentId, i) => ({ studentId, status: i === 0 ? 'ABSENT' : status }));
  const pa = (date, n, recs = records()) => ({ sectionId: secA.id, date, periodNumber: n, records: recs });
  check('class teacher cannot take another teacher’s period', (await call('POST', '/attendance/periods', pa(today, 11), smith)).status === 403);
  check('student cannot take attendance', (await call('POST', '/attendance/periods', pa(today, 11), student)).status === 403);
  const take = await call('POST', '/attendance/periods', pa(today, 11), jonesT);
  check('period teacher takes attendance on the day', take.status === 201 && take.data.taken && take.data.students.find((s) => s.studentId === roster[0])?.status === 'ABSENT', take.data);
  const change = await call('POST', '/attendance/periods', pa(today, 11, records('LATE')), jonesT);
  check('period teacher can change it the same day', change.status === 201 && change.data.students.filter((s) => s.status === 'LATE').length === roster.length - 1);
  check('outsider in records rejected', (await call('POST', '/attendance/periods', pa(today, 11, [{ studentId: '00000000-0000-0000-0000-000000000000', status: 'PRESENT' }]), jonesT)).status === 400);
  check('class teacher can view the period roster', (await call('GET', `/attendance/periods?sectionId=${secA.id}&date=${today}&periodNumber=11`, null, smith)).data?.canMark === false);

  // ------------------------------------------------ substitutions
  const sub = (date, n, teacher, extra = {}) => ({ date, periodNumber: n, teacher, reason: 'Test cover', ...extra });
  check('cannot substitute after attendance is taken', (await call('PUT', `/timetable/daily/${secA.id}/substitution`, sub(today, 11, 'teacher.smith@oakridge.edu'), smith)).status === 409);
  check('subject teacher cannot substitute', (await call('PUT', `/timetable/daily/${secA.id}/substitution`, sub(today, 12, 'teacherjones'), jonesT)).status === 403);
  check('past day cannot be changed', (await call('PUT', `/timetable/daily/${secA.id}/substitution`, sub(yesterday, 11, 'teacher.smith@oakridge.edu'), smith)).status === 403);
  check('same teacher is not a substitution', (await call('PUT', `/timetable/daily/${secA.id}/substitution`, sub(today, 12, 'teachersmith'), smith)).status === 400);
  const subbed = await call('PUT', `/timetable/daily/${secA.id}/substitution`, sub(today, 12, 'teacherjones'), smith);
  const s12 = subbed.data?.periods?.find((p) => p.periodNumber === 12);
  check('class teacher substitutes a period for today', subbed.status === 200 && s12?.effectiveTeacher?.staffId === jones.id && s12.substitution?.reason === 'Test cover', s12);
  check('timetable teacher can no longer take it', (await call('POST', '/attendance/periods', pa(today, 12), smith)).status === 403);
  check('substitute takes the attendance', (await call('POST', '/attendance/periods', pa(today, 12), jonesT)).status === 201);
  const jonesDay = await call('GET', `/timetable/my-day?date=${today}`, null, jonesT);
  check('substitution shows in the substitute’s day', jonesDay.data?.periods?.some((p) => p.periodNumber === 12 && p.isSubstitution));
  const smithDay = await call('GET', `/timetable/my-day?date=${today}`, null, smith);
  check('handed-over period shows for the timetable teacher', smithDay.data?.periods?.some((p) => p.periodNumber === 12 && p.handedOverTo?.staffId === jones.id && !p.canTakeAttendance));
  const tom = await call('PUT', `/timetable/daily/${secA.id}/substitution`, sub(tomorrow, 11, 'teachersmith'), office);
  check('office substitutes a future period', tom.status === 200 && tom.data.periods.find((p) => p.periodNumber === 11)?.effectiveTeacher?.staffId === smithStaff.id);
  check('substitute busy elsewhere is rejected', (await call('PUT', `/timetable/daily/${secB.id}/substitution`, sub(tomorrow, 11, 'teachersmith', { subjectId: subj.Science.id }), office)).status === 409);
  const undo = await call('DELETE', `/timetable/daily/${secA.id}/substitution?date=${tomorrow}&periodNumber=11`, null, smith);
  check('class teacher removes a substitution', undo.status === 200 && !undo.data.periods.find((p) => p.periodNumber === 11)?.substitution);

  // ------------------------------------------------ same-day rule, office corrections
  check('teacher cannot take attendance for tomorrow', (await call('POST', '/attendance/periods', pa(tomorrow, 11), jonesT)).status === 403);
  check('teacher cannot take attendance for a past day', (await call('POST', '/attendance/periods', pa(yesterday, 11), jonesT)).status === 403);
  check('office cannot take attendance for the future', (await call('POST', '/attendance/periods', pa(tomorrow, 11), office)).status === 403);
  const corr = await call('POST', '/attendance/periods', pa(yesterday, 11), office);
  check('office corrects a past day', corr.status === 201 && corr.data.taken);
  const corrAudit = await prisma.auditLog.count({ where: { schoolId: school.id, action: 'PERIOD_ATTENDANCE_CORRECTED', timestamp: { gte: new Date(Date.now() - 120000) } } });
  check('past-day change audited as a correction', corrAudit >= 1);
  const dailyPast = { sectionId: secA.id, date: pastDaily, records: roster.map((studentId) => ({ studentId, status: 'PRESENT' })) };
  check('teacher cannot save daily attendance for a past day', (await call('POST', '/attendance/sessions', dailyPast, smith)).status === 403);
  check('office can change daily attendance for a past day', (await call('POST', '/attendance/sessions', dailyPast, office)).status === 201);
  const todayCT = await call('GET', '/attendance/today', null, smith);
  check('class teacher’s register defaults to their own class', todayCT.data?.section?.id === secA.id);

  // ------------------------------------------------ one class teacher per class
  const dup = await call('POST', '/staff/assignments', { staffId: jones.id, classId: secA.classId, sectionId: secA.id, isClassTeacher: true }, admin);
  check('second class teacher for a class is refused', dup.status === 409 && /already has a class teacher/.test(dup.error?.message ?? ''), dup.error);
  const repl = await call('POST', '/staff/assignments', { staffId: jones.id, classId: secA.classId, sectionId: secA.id, isClassTeacher: true, replaceClassTeacher: true }, admin);
  const ctNow = await prisma.teacherAssignment.findMany({ where: { sectionId: secA.id, isClassTeacher: true } });
  check('replacing hands the role over (still one class teacher)', repl.status === 201 && ctNow.length === 1 && ctNow[0].staffId === jones.id);
  const smithKept = await prisma.teacherAssignment.findFirst({ where: { sectionId: secA.id, staffId: smithStaff.id, subjectId: subj.Mathematics.id } });
  check('old class teacher keeps their subject', !!smithKept && !smithKept.isClassTeacher);
  const back = await call('POST', '/staff/assignments', { staffId: smithStaff.id, classId: secA.classId, sectionId: secA.id, subjectId: subj.Mathematics.id, isClassTeacher: true, replaceClassTeacher: true }, admin);
  const ctBack = await prisma.teacherAssignment.findMany({ where: { sectionId: secA.id, isClassTeacher: true } });
  check('class teacher restored', back.status === 201 && ctBack.length === 1 && ctBack[0].staffId === smithStaff.id && ctBack[0].id === originalCT[0]?.id);

  // ------------------------------------------------ admissions by the class teacher
  const ctAdd = await call('POST', '/students', { firstName: 'Zz', lastName: 'Tester', gender: 'FEMALE', dob: '2011-05-01' }, smith);
  if (ctAdd.data?.id) createdStudents.push(ctAdd.data.id);
  const enr = ctAdd.data?.id ? await prisma.enrollment.findFirst({ where: { studentId: ctAdd.data.id } }) : null;
  check('class teacher adds a student to their own class', ctAdd.status === 201 && enr?.sectionId === secA.id, ctAdd.data);
  check('class teacher cannot add to another class', (await call('POST', '/students', { firstName: 'Zz', lastName: 'Other', classId: secB.classId, sectionId: secB.id }, smith)).status === 403);
  check('subject teacher cannot add students', (await call('POST', '/students', { firstName: 'Zz', lastName: 'Nope' }, jonesT)).status === 403);
  const offAdd = await call('POST', '/students', { firstName: 'Zz', lastName: 'Office', classId: secB.classId, sectionId: secB.id }, office);
  if (offAdd.data?.id) createdStudents.push(offAdd.data.id);
  check('office adds a student to any class', offAdd.status === 201);

  // ------------------------------------------------ clearing a slot removes generated access
  const cleared = await call('DELETE', `/timetable/class/${secA.id}/slot?dayOfWeek=${dT}&periodNumber=11`, null, smith);
  check('class teacher clears a slot', cleared.status === 200 && !cleared.data.entries.some((e) => e.dayOfWeek === dT && e.periodNumber === 11));
  check('timetable access removed when no longer teaching', !(await prisma.teacherAssignment.findFirst({ where: { staffId: jones.id, sectionId: secA.id, subjectId: subj['English Literature'].id } })));
  check('admin-made access is kept', !!(await prisma.teacherAssignment.findFirst({ where: { staffId: jones.id, sectionId: secA.id, subjectId: subj.Science.id, source: null } })));
  const removeWithSlots = await call('PUT', '/timetable/periods', { periods: kept }, office);
  check('removing periods that are in use needs confirmation', removeWithSlots.status === 409);
} finally {
  try {
    const sections = [secA.id, secB.id];
    await prisma.periodAttendance.deleteMany({ where: { sectionId: { in: sections }, periodNumber: { gte: 11 } } });
    await prisma.periodSubstitution.deleteMany({ where: { sectionId: { in: sections }, periodNumber: { gte: 11 } } });
    await prisma.timetableEntry.deleteMany({ where: { sectionId: { in: sections }, periodNumber: { gte: 11 } } });
    await prisma.teacherAssignment.deleteMany({ where: { schoolId: school.id, source: 'TIMETABLE', sectionId: { in: sections } } });
    // Put the bell schedule back exactly as it was.
    const year = await prisma.academicYear.findFirst({ where: { schoolId: school.id, isCurrent: true } });
    await prisma.timetablePeriod.deleteMany({ where: { schoolId: school.id, academicYearId: year.id } });
    if (originalPeriods.length) {
      await prisma.timetablePeriod.createMany({
        data: originalPeriods.map((p) => ({ schoolId: school.id, academicYearId: year.id, dayOfWeek: p.dayOfWeek, periodNumber: p.periodNumber, startTime: p.startTime, endTime: p.endTime, label: p.label })),
      });
    }
    const extraCT = await prisma.teacherAssignment.findMany({ where: { sectionId: secA.id, isClassTeacher: true } });
    if (originalCT.length && !(extraCT.length === 1 && extraCT[0].id === originalCT[0].id)) {
      await prisma.teacherAssignment.updateMany({ where: { sectionId: secA.id, isClassTeacher: true, NOT: { id: originalCT[0].id } }, data: { isClassTeacher: false } });
      await prisma.teacherAssignment.update({ where: { id: originalCT[0].id }, data: { isClassTeacher: true } });
    }
    await prisma.teacherAssignment.deleteMany({ where: { sectionId: secA.id, staffId: jones.id, subjectId: null } });
    for (const id of createdStudents) {
      await prisma.enrollment.deleteMany({ where: { studentId: id } });
      await prisma.student.delete({ where: { id } }).catch(() => {});
    }
    const s = await prisma.attendanceSession.findFirst({ where: { sectionId: secA.id, date: { gte: new Date('2020-01-05'), lte: new Date('2020-01-07') } } });
    if (s) await prisma.attendanceSession.delete({ where: { id: s.id } });
    const left = await prisma.timetablePeriod.count({ where: { schoolId: school.id } });
    console.log(`cleanup done (bell schedule periods now ${left}, was ${originalPeriods.length})`);
  } catch (e) {
    console.log('CLEANUP ERROR', e.message);
    failed++;
  }
  await prisma.$disconnect();
  console.log(failed ? `${failed} FAILED, ${passed} passed` : `ALL PASSED (${passed})`);
  process.exitCode = failed ? 1 : 0;
}
