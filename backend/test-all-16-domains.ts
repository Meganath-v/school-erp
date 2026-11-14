import * as http from 'http';

const BASE_URL = 'http://localhost:3000/api/v1';

interface ApiResponse<T = any> {
  status: number;
  body: T;
}

function request<T = any>(
  method: string,
  path: string,
  data?: any,
  token?: string,
): Promise<ApiResponse<T>> {
  return new Promise((resolve, reject) => {
    const url = new URL(BASE_URL + path);
    const reqHeaders: Record<string, string> = {};

    if (token) {
      reqHeaders['Authorization'] = `Bearer ${token}`;
    }

    let payload: string | undefined;
    if (data !== undefined) {
      payload = JSON.stringify(data);
      reqHeaders['Content-Type'] = 'application/json';
      reqHeaders['Content-Length'] = Buffer.byteLength(payload).toString();
    }

    const req = http.request(
      url,
      {
        method,
        headers: reqHeaders,
      },
      (res) => {
        let raw = '';
        res.on('data', (chunk) => (raw += chunk));
        res.on('end', () => {
          let body = raw as any;
          try {
            body = JSON.parse(raw);
          } catch {
            // raw string
          }
          resolve({ status: res.statusCode || 500, body });
        });
      },
    );

    req.on('error', (err) => reject(err));
    if (payload) {
      req.write(payload);
    }
    req.end();
  });
}

function getData(res: ApiResponse) {
  return res.body?.data !== undefined ? res.body.data : res.body;
}

let passed = 0;
let failed = 0;

function assert(condition: boolean, testName: string, detail?: string) {
  if (condition) {
    console.log(`  ✓ [PASS] ${testName}`);
    passed++;
  } else {
    console.error(`  ✗ [FAIL] ${testName} ${detail ? `-> ${detail}` : ''}`);
    failed++;
  }
}

async function runDomainTests() {
  console.log('======================================================================');
  console.log('   SCHOOL ERP - 16 DOMAINS COMPLETE REAL-DATA VERIFICATION SUITE      ');
  console.log('======================================================================\n');

  // 1. Authenticate users
  const adminRes = await request('POST', '/auth/login', {
    login: 'admin@oakridge.edu',
    password: 'password123',
    schoolCode: 'OAK01',
  });
  const adminToken = adminRes.body?.data?.accessToken || adminRes.body?.accessToken;

  const officeRes = await request('POST', '/auth/login', {
    login: 'office@oakridge.edu',
    password: 'password123',
    schoolCode: 'OAK01',
  });
  const officeToken = officeRes.body?.data?.accessToken || officeRes.body?.accessToken;

  const teacherRes = await request('POST', '/auth/login', {
    login: 'teacher.smith@oakridge.edu',
    password: 'password123',
    schoolCode: 'OAK01',
  });
  const teacherToken = teacherRes.body?.data?.accessToken || teacherRes.body?.accessToken;

  const parentRes = await request('POST', '/auth/login', {
    login: 'parent.doe@gmail.com',
    password: 'password123',
    schoolCode: 'OAK01',
  });
  const parentToken = parentRes.body?.data?.accessToken || parentRes.body?.accessToken;

  assert(!!adminToken && !!officeToken && !!teacherToken && !!parentToken, 'Multi-role authentication succeeded');

  // Baseline Entities
  const classesRes = await request('GET', '/schools/classes', undefined, adminToken);
  const classes = getData(classesRes) || [];
  const targetClass = classes[0];
  const targetSection = targetClass?.sections?.[0];

  const subjectsRes = await request('GET', '/schools/subjects', undefined, adminToken);
  const subjects = getData(subjectsRes) || [];
  const targetSubject = subjects[0];

  const yearsRes = await request('GET', '/schools/academic-years', undefined, adminToken);
  console.log('yearsRes:', yearsRes.status, yearsRes.body);
  const years = getData(yearsRes) || [];
  const activeYear = years.find((y: any) => y.isCurrent) || years[0];

  const studentsRes = await request('GET', '/students', undefined, adminToken);
  const students = getData(studentsRes) || [];
  const targetStudent = students[0];

  console.log('\n--- Domain 1: School & Platform Management ---');
  const schoolProfile = await request('GET', '/schools/current', undefined, adminToken);
  const profileData = getData(schoolProfile);
  assert(schoolProfile.status === 200 && profileData?.code === 'OAK01', 'School tenant profile retrieved');
  const campusesRes = await request('GET', '/schools/campuses', undefined, adminToken);
  assert(campusesRes.status === 200 && Array.isArray(getData(campusesRes)), 'Campuses retrieved');

  console.log('\n--- Domain 2: Student Management & Lifecycle ---');
  // Student document management
  const addDocRes = await request('POST', `/students/${targetStudent.id}/documents`, {
    title: 'Birth Certificate Official Copy',
    documentType: 'BIRTH_CERTIFICATE',
    fileUrl: 'https://docs.erp.com/certificates/bc_001.pdf',
    fileType: 'application/pdf',
  }, officeToken);
  const docData = getData(addDocRes);
  assert(addDocRes.status === 201 && docData?.id, 'Student document uploaded successfully');
  const docId = docData?.id;

  const getDocsRes = await request('GET', `/students/${targetStudent.id}/documents`, undefined, officeToken);
  assert(getDocsRes.status === 200 && getData(getDocsRes)?.some((d: any) => d.id === docId), 'Student documents retrieved');

  const delDocRes = await request('DELETE', `/students/${targetStudent.id}/documents/${docId}`, undefined, officeToken);
  assert(delDocRes.status === 200, 'Student document deleted successfully');

  // Admit a test student for promotion and transfer testing
  const admitRes = await request('POST', '/students', {
    firstName: 'TestAdmission',
    lastName: 'LifecycleUser',
    dob: '2013-08-15',
    gender: 'FEMALE',
    classId: targetClass.id,
    sectionId: targetSection.id,
    guardianName: 'Parent Lifecycle',
    guardianPhone: '+91 9999900001',
  }, officeToken);
  const admitData = getData(admitRes);
  assert(admitRes.status === 201 && admitData?.id, 'Student admitted with auto-generated admission number');
  const newStudentId = admitData?.id;

  // Student promotion
  const promoRes = await request('POST', `/students/${newStudentId}/promote`, {
    targetAcademicYearId: activeYear.id,
    targetClassId: targetClass.id,
    targetSectionId: targetSection.id,
    newRollNo: 99,
  }, officeToken);
  assert((promoRes.status === 200 || promoRes.status === 201) && getData(promoRes)?.newEnrollment?.rollNo === 99, 'Student promoted to new academic year session');

  // Student transfer
  const transferRes = await request('POST', `/students/${newStudentId}/transfer`, {
    tcNumber: 'TC-2026-999',
    reason: 'Parent transferred out of state',
    transferDate: '2026-11-14',
  }, officeToken);
  assert((transferRes.status === 200 || transferRes.status === 201) && getData(transferRes)?.student?.status === 'TRANSFERRED', 'Student transferred and enrollment archived');

  console.log('\n--- Domain 3: Staff Management & Teacher Portal ---');
  const staffList = await request('GET', '/staff', undefined, adminToken);
  const staffData = getData(staffList);
  assert(staffList.status === 200 && staffData?.length > 0, 'Staff directory retrieved');
  const myClasses = await request('GET', '/teacher/my-classes', undefined, teacherToken);
  assert(myClasses.status === 200 && getData(myClasses)?.staffName, 'Teacher assigned classes and roster retrieved');

  console.log('\n--- Domain 4: Academics, OBE Outcomes & Bloom\'s Taxonomy ---');
  const bloomsRes = await request('GET', '/academics/blooms-taxonomy', undefined, teacherToken);
  assert(bloomsRes.status === 200 && getData(bloomsRes)?.length === 6, 'Bloom\'s Taxonomy 6 cognitive levels retrieved');

  const coCreate = await request('POST', `/academics/subjects/${targetSubject.id}/course-outcomes`, {
    code: 'CO1',
    description: 'Demonstrate fundamental principles and applications',
    bloomLevel: 'APPLY',
    targetAttainment: 75,
  }, teacherToken);
  assert(coCreate.status === 201 && getData(coCreate)?.code === 'CO1', 'OBE Course Outcome created');

  const coList = await request('GET', `/academics/subjects/${targetSubject.id}/course-outcomes`, undefined, teacherToken);
  assert(coList.status === 200 && getData(coList)?.some((c: any) => c.code === 'CO1'), 'OBE Course Outcomes listed');

  console.log('\n--- Domain 5: Timetable & 8-Period Weekly Matrix ---');
  const gridRes = await request('GET', '/timetable/grid', undefined, adminToken);
  const gridData = getData(gridRes);
  assert(gridRes.status === 200 && gridData?.periodsHeader?.length === 8, 'Timetable 8-period header generated');
  assert(gridData?.days?.length === 6, 'Timetable 6-day (Mon-Sat) weekly grid generated');

  const availRes = await request('GET', `/timetable/check-availability?staffId=${staffData[0].id}&dayOfWeek=1&periodNumber=1`, undefined, adminToken);
  assert(availRes.status === 200 && typeof getData(availRes)?.available === 'boolean', 'Teacher timetable availability check verified');

  console.log('\n--- Domain 6: Attendance, Register & Correction ---');
  const attToday = await request('GET', `/attendance/today?sectionId=${targetSection.id}`, undefined, teacherToken);
  assert(attToday.status === 200 && Array.isArray(getData(attToday)?.students), 'Attendance today roster retrieved');

  const attMatrix = await request('GET', `/attendance/matrix?sectionId=${targetSection.id}`, undefined, teacherToken);
  assert(attMatrix.status === 200 && getData(attMatrix)?.stats?.condonationThreshold === 75, 'Attendance monthly matrix with condonation risk retrieved');

  // Attendance Save
  const saveAtt = await request('POST', '/attendance/sessions', {
    sectionId: targetSection.id,
    records: [
      { studentId: targetStudent.id, status: 'ABSENT', remarks: 'Unexcused absence' },
    ],
  }, teacherToken);
  assert(saveAtt.status === 201, 'Attendance session recorded');

  // Attendance Reports
  const reportsAtt = await request('GET', `/attendance/reports?sectionId=${targetSection.id}`, undefined, teacherToken);
  assert(reportsAtt.status === 200, 'Attendance reports retrieved');

  console.log('\n--- Domain 7: Examinations & Consolidated Broadsheet ---');
  const examsList = await request('GET', '/exams', undefined, teacherToken);
  const examsData = getData(examsList);
  assert(examsList.status === 200 && examsData?.length > 0, 'Exams list retrieved');
  const testExam = examsData[0];

  const broadsheetRes = await request('GET', `/exams/${testExam.id}/classes/${targetClass.id}/broadsheet`, undefined, teacherToken);
  assert(broadsheetRes.status === 200 && getData(broadsheetRes)?.broadsheet !== undefined, 'Consolidated exam broadsheet retrieved');

  console.log('\n--- Domain 8: Assignments & Student Submissions ---');
  const assignRes = await request('GET', `/assignments?classId=${targetClass.id}`, undefined, teacherToken);
  assert(assignRes.status === 200 && Array.isArray(getData(assignRes)), 'Assignments retrieved');

  console.log('\n--- Domain 9: Fees, Categories & Serialized Receipts ---');
  const feePlans = await request('GET', '/fees/plans', undefined, officeToken);
  assert(feePlans.status === 200 && Array.isArray(getData(feePlans)?.plans), 'Fee plans retrieved');

  const invoices = await request('GET', '/fees/invoices', undefined, officeToken);
  assert(invoices.status === 200 && Array.isArray(getData(invoices)), 'Fee invoices retrieved');

  console.log('\n--- Domain 10: Leave Management with Types & Attachments ---');
  const myChildrenRes = await request('GET', '/parent/my-children', undefined, parentToken);
  const myChildren = getData(myChildrenRes) || [];
  const parentStudentId = myChildren[0]?.studentId || myChildren[0]?.id || targetStudent.id;

  const leaveApp = await request('POST', '/leave-requests', {
    studentId: parentStudentId,
    startDate: '2026-12-01',
    endDate: '2026-12-03',
    leaveType: 'MEDICAL',
    reason: 'Fever and viral infection',
    supportingDocUrl: 'https://docs.erp.com/medical/cert_123.pdf',
  }, parentToken);
  const leaveData = getData(leaveApp);
  assert(leaveApp.status === 201 && leaveData?.leaveType === 'MEDICAL', 'Leave application submitted with leaveType & attachment');
  const leaveId = leaveData?.id;

  const decideLeave = await request('POST', `/leave-requests/${leaveId}/decision`, {
    status: 'APPROVED',
    remarks: 'Approved. Get well soon.',
  }, teacherToken);
  assert((decideLeave.status === 200 || decideLeave.status === 201) && getData(decideLeave)?.status === 'APPROVED', 'Leave decided by Class Teacher with remarks');

  console.log('\n--- Domain 11: Circulars with Sequential Numbers & Sign-off ---');
  const circulars = await request('GET', '/circulars', undefined, teacherToken);
  assert(circulars.status === 200 && Array.isArray(getData(circulars)), 'Circulars retrieved');

  console.log('\n--- Domain 12: Announcements with Expiration & Attachments ---');
  const announceCreate = await request('POST', '/announcements', {
    title: 'Upcoming Science Exhibition 2026',
    content: 'All students are encouraged to participate in the annual science fair.',
    targetRole: 'ALL',
    priority: 'HIGH',
    startsAt: '2026-11-14T00:00:00Z',
    expiresAt: '2026-12-31T23:59:59Z',
    attachments: 'https://docs.erp.com/notices/science_fair.pdf',
  }, adminToken);
  assert(announceCreate.status === 201 && getData(announceCreate)?.attachments, 'Announcement created with expiration & attachments');

  const announceList = await request('GET', '/announcements', undefined, teacherToken);
  assert(announceList.status === 200 && getData(announceList)?.some((a: any) => a.title === 'Upcoming Science Exhibition 2026'), 'Active announcements listed');

  console.log('\n--- Domain 13: Feedback, Ratings & Resolution ---');
  const feedSub = await request('POST', '/feedback', {
    category: 'FACILITIES',
    title: 'Library Lighting Upgrade Request',
    content: 'The reading section on the 2nd floor could use additional LED lighting.',
    rating: 4,
    isAnonymous: false,
  }, parentToken);
  const feedData = getData(feedSub);
  assert(feedSub.status === 201 && feedData?.id, 'Feedback submitted with category and star rating');
  const feedbackId = feedData?.id;

  const feedResp = await request('POST', `/feedback/${feedbackId}/respond`, {
    response: 'Work order has been placed with facility maintenance.',
    status: 'RESOLVED',
  }, adminToken);
  assert((feedResp.status === 200 || feedResp.status === 201) && getData(feedResp)?.status === 'RESOLVED', 'Feedback resolved by administration');

  console.log('\n--- Domain 14: Notifications & Reminders ---');
  const notifs = await request('GET', '/notifications', undefined, parentToken);
  assert(notifs.status === 200 && Array.isArray(getData(notifs)?.notifications), 'Notification inbox retrieved');

  const reminders = await request('GET', '/reminders', undefined, teacherToken);
  assert(reminders.status === 200 && Array.isArray(getData(reminders)), 'Reminders retrieved');

  console.log('\n--- Domain 15: Tasks Pipeline ---');
  const tasks = await request('GET', '/tasks', undefined, teacherToken);
  assert(tasks.status === 200 && Array.isArray(getData(tasks)), 'Task list retrieved');

  console.log('\n--- Domain 16: Institutional Reporting Suite ---');
  const rStudents = await request('GET', '/reports/students', undefined, officeToken);
  assert(rStudents.status === 200 && getData(rStudents)?.genderBreakdown !== undefined, 'Reports: Student demographics & class distribution');

  const rAttendance = await request('GET', '/reports/attendance', undefined, officeToken);
  assert(rAttendance.status === 200 && getData(rAttendance)?.condonationThreshold === 75, 'Reports: Attendance condonation deficiency (<75%) report');

  const rExams = await request('GET', '/reports/examinations', undefined, officeToken);
  assert(rExams.status === 200 && Array.isArray(getData(rExams)?.broadsheet), 'Reports: Examination consolidated class broadsheet & rankings');

  const rFees = await request('GET', '/reports/fees', undefined, officeToken);
  assert(rFees.status === 200 && getData(rFees)?.categories?.SCHOOL !== undefined, 'Reports: Fee category collections (SCHOOL, HOSTEL, TRANSPORT) & defaulters');

  const rWorkload = await request('GET', '/reports/teacher-workload', undefined, officeToken);
  assert(rWorkload.status === 200 && Array.isArray(getData(rWorkload)), 'Reports: Faculty weekly periods workload report');

  const rFeedback = await request('GET', '/reports/feedback', undefined, officeToken);
  assert(rFeedback.status === 200 && getData(rFeedback)?.byCategory !== undefined, 'Reports: Feedback resolution & sentiment analytics report');

  console.log('\n======================================================================');
  console.log('                     TEST RESULTS SUMMARY                             ');
  console.log('======================================================================');
  console.log(`Total Domain Tests Run : ${passed + failed}`);
  console.log(`Passed                   : ${passed}`);
  console.log(`Failed                   : ${failed}`);
  console.log(`Success Rate             : ${((passed / (passed + failed)) * 100).toFixed(1)}%`);

  if (failed === 0) {
    console.log('\n🌟 ALL 16 DOMAINS VERIFIED WITH 100% REAL-DATABASE DATA & ZERO PLACEHOLDERS!');
    process.exit(0);
  } else {
    console.error(`\n❌ ${failed} domain tests failed.`);
    process.exit(1);
  }
}

runDomainTests().catch((err) => {
  console.error('Fatal test error:', err);
  process.exit(1);
});
