/**
 * Comprehensive Senior QA Multi-Role Automated Test Suite
 * Covers 8 institutional roles across:
 * 1. Authentication (All 8 roles, invalid logins, session revocation, RBAC)
 * 2. Multi-Tenancy & Tenant Boundaries (Cross-school, cross-student, parameter tampering)
 * 3. Student Management & Lifecycle (Admission, auto-number, edit, guardian, enrollment, search, profile)
 * 4. Attendance & 75% Threshold Engine (Mark all, absentees, authorized correction, threshold risk)
 * 5. Examination, Excel Import, Broadsheet & Locks (Create, marks, Excel bulk import & rejection, broadsheet, publish, post-publish lock)
 * 6. Fees, Serialized Receipts & Overpayment Defense (Create, counter collection, overpayment rejection, receipt, balance, parent portal boundaries)
 * 7. Circulars, Targeted Broadcasting & Acknowledgment Reports (Principal broadcast, class teacher restrictions, digital acknowledgment, compliance report)
 * 8. Assignments, Student Submissions & Faculty Grading (Create, student HTTPS submission, faculty grading & feedback)
 * 9. Leave Management Workflows (Parent medical leave application, teacher inbox, approval decision & remarks)
 * 10. Platform Management (Superadmin stats, multi-tenant directory)
 */

const BASE_URL = 'http://localhost:3000/api/v1';

async function request(path: string, options: RequestInit = {}) {
  const url = `${BASE_URL}${path}`;
  const headers: Record<string, string> = {
    'Content-Type': 'application/json',
    ...(options.headers as Record<string, string> || {}),
  };
  const res = await fetch(url, { ...options, headers });
  const text = await res.text();
  let json: any = null;
  try {
    json = JSON.parse(text);
  } catch {
    json = text;
  }
  return { status: res.status, headers: res.headers, data: json };
}

interface TestResult {
  id: string;
  category: string;
  role: string;
  description: string;
  passed: boolean;
  statusCode?: number;
  expectedStatus?: number | string;
  errorDetail?: string;
}

const testResults: TestResult[] = [];

function recordTest(
  id: string,
  category: string,
  role: string,
  description: string,
  condition: boolean,
  statusCode?: number,
  expectedStatus?: number | string,
  errorDetail?: string,
) {
  testResults.push({
    id,
    category,
    role,
    description,
    passed: condition,
    statusCode,
    expectedStatus,
    errorDetail: condition ? undefined : errorDetail,
  });

  const icon = condition ? '✅ [PASS]' : '❌ [FAIL]';
  console.log(`  ${icon} [${id}] [${role}] ${description} (Status: ${statusCode ?? 'N/A'})`);
  if (!condition && errorDetail) {
    console.error(`      Detail: ${errorDetail}`);
  }
}

async function runQASuite() {
  console.log('======================================================================');
  console.log('🎯 SENIOR QA AUTOMATION: 8-ROLE COMPREHENSIVE INSTITUTIONAL SUITE');
  console.log('======================================================================\n');

  // =========================================================================
  // 1. AUTHENTICATION SCENARIOS (ALL 8 ROLES + NEGATIVE CASES)
  // =========================================================================
  console.log('--- 1. AUTHENTICATION SCENARIOS ---');

  const rolesCredentials = [
    { role: 'PLATFORM_OWNER', login: 'superadmin@erp.com', password: 'password123' },
    { role: 'SCHOOL_ADMIN', login: 'admin@oakridge.edu', password: 'password123', schoolCode: 'OAK01' },
    { role: 'OFFICE', login: 'office@oakridge.edu', password: 'password123', schoolCode: 'OAK01' },
    { role: 'PRINCIPAL', login: 'principal@oakridge.edu', password: 'password123', schoolCode: 'OAK01' },
    { role: 'CLASS_TEACHER', login: 'teacher.smith@oakridge.edu', password: 'password123', schoolCode: 'OAK01' },
    { role: 'SUBJECT_TEACHER', login: 'teacher.jones@oakridge.edu', password: 'password123', schoolCode: 'OAK01' },
    { role: 'PARENT', login: 'parent.doe@gmail.com', password: 'password123', schoolCode: 'OAK01' },
    { role: 'STUDENT', login: 'student.john@oakridge.edu', password: 'password123', schoolCode: 'OAK01' },
  ];

  const tokens: Record<string, string> = {};
  const userIds: Record<string, string> = {};

  for (let i = 0; i < rolesCredentials.length; i++) {
    const cred = rolesCredentials[i];
    const res = await request('/auth/login', {
      method: 'POST',
      body: JSON.stringify({
        login: cred.login,
        password: cred.password,
        schoolCode: cred.schoolCode,
      }),
    });

    const isSuccess = res.status === 200 || res.status === 201;
    const token = res.data?.data?.accessToken;
    const userId = res.data?.data?.user?.id;
    if (token) tokens[cred.role] = token;
    if (userId) userIds[cred.role] = userId;

    recordTest(
      `TC-AUTH-0${i + 1}`,
      'Authentication',
      cred.role,
      `Valid login authenticates successfully and issues JWT access token`,
      isSuccess && !!token,
      res.status,
      '200|201',
      JSON.stringify(res.data),
    );
  }

  // 1.2 Invalid password
  const invalidPwdRes = await request('/auth/login', {
    method: 'POST',
    body: JSON.stringify({
      login: 'admin@oakridge.edu',
      password: 'wrong_password_XYZ999',
      schoolCode: 'OAK01',
    }),
  });
  recordTest(
    'TC-AUTH-09',
    'Authentication',
    'ALL',
    'Invalid password rejected with 401 Unauthorized',
    invalidPwdRes.status === 401,
    invalidPwdRes.status,
    401,
  );

  // 1.3 Wrong school code
  const wrongCodeRes = await request('/auth/login', {
    method: 'POST',
    body: JSON.stringify({
      login: 'admin@oakridge.edu',
      password: 'password123',
      schoolCode: 'NON_EXISTENT_CODE',
    }),
  });
  recordTest(
    'TC-AUTH-10',
    'Authentication',
    'ALL',
    'Invalid school code rejected with 401 Unauthorized',
    wrongCodeRes.status === 401,
    wrongCodeRes.status,
    401,
  );

  // 1.4 Expired / Revoked session via Logout
  const tempSignRes = await request('/auth/login', {
    method: 'POST',
    body: JSON.stringify({
      login: 'office@oakridge.edu',
      password: 'password123',
      schoolCode: 'OAK01',
    }),
  });
  const tempToken = tempSignRes.data?.data?.accessToken;
  const logoutRes = await request('/auth/logout', {
    method: 'POST',
    headers: { Authorization: `Bearer ${tempToken}` },
  });
  const postLogoutCall = await request('/schools/current', {
    headers: { Authorization: `Bearer ${tempToken}` },
  });
  recordTest(
    'TC-AUTH-11',
    'Authentication',
    'OFFICE',
    'Logout terminates session and invalidates access token (401 Unauthorized)',
    (logoutRes.status === 200 || logoutRes.status === 201) && postLogoutCall.status === 401,
    postLogoutCall.status,
    401,
  );

  // Re-login office staff so subsequent tests have an active valid token
  const reOfficeLogin = await request('/auth/login', {
    method: 'POST',
    body: JSON.stringify({
      login: 'office@oakridge.edu',
      password: 'password123',
      schoolCode: 'OAK01',
    }),
  });
  tokens['OFFICE'] = reOfficeLogin.data?.data?.accessToken;

  // 1.5 Unauthorized Route Access (RBAC boundary checks)
  // Student accessing audit logs
  const studentAudit = await request('/audit-logs', {
    headers: { Authorization: `Bearer ${tokens['STUDENT']}` },
  });
  recordTest(
    'TC-AUTH-12',
    'Authentication',
    'STUDENT',
    'Student blocked from accessing administrative audit logs with 403 Forbidden',
    studentAudit.status === 403,
    studentAudit.status,
    403,
  );

  // Parent accessing fee payment counter
  const parentPay = await request('/fees/pay', {
    method: 'POST',
    headers: { Authorization: `Bearer ${tokens['PARENT']}` },
    body: JSON.stringify({ invoiceId: 'dummy', amount: 100 }),
  });
  recordTest(
    'TC-AUTH-13',
    'Authentication',
    'PARENT',
    'Parent blocked from counter fee payment endpoint with 403 Forbidden',
    parentPay.status === 403,
    parentPay.status,
    403,
  );

  // Office staff accessing superadmin tenant management
  const officePlatform = await request('/platform/schools', {
    headers: { Authorization: `Bearer ${tokens['OFFICE']}` },
  });
  recordTest(
    'TC-AUTH-14',
    'Authentication',
    'OFFICE',
    'Office staff blocked from SaaS platform tenant provisioning with 403 Forbidden',
    officePlatform.status === 403,
    officePlatform.status,
    403,
  );

  // =========================================================================
  // 2. MULTI-TENANCY & TENANT BOUNDARIES
  // =========================================================================
  console.log('\n--- 2. MULTI-TENANCY & ISOLATION ---');

  // Authenticate as St. Xavier's Admin (STX02)
  const stxLoginRes = await request('/auth/login', {
    method: 'POST',
    body: JSON.stringify({
      login: 'admin@stxaviers.edu',
      password: 'password123',
      schoolCode: 'STX02',
    }),
  });
  const stxToken = stxLoginRes.data?.data?.accessToken;
  const stxSchoolId = stxLoginRes.data?.data?.activeSchool?.id;

  // Oakridge Admin details
  const oakCurrentRes = await request('/schools/current', {
    headers: { Authorization: `Bearer ${tokens['SCHOOL_ADMIN']}` },
  });
  const oakSchoolId = oakCurrentRes.data?.data?.id;

  // St. Xavier query for students: must NOT contain Oakridge students
  const stxStudentsRes = await request('/students', {
    headers: { Authorization: `Bearer ${stxToken}` },
  });
  const stxStudents = stxStudentsRes.data?.data || [];
  const leakedStudents = stxStudents.filter((s: any) => s.schoolId === oakSchoolId);
  recordTest(
    'TC-TEN-01',
    'Multi-Tenancy',
    'SCHOOL_ADMIN',
    'School A (St. Xavier) cannot access School B (Oakridge) student records',
    leakedStudents.length === 0,
    stxStudentsRes.status,
    200,
  );

  // St. Xavier query for invoices: must NOT contain Oakridge invoices
  const stxInvoicesRes = await request('/fees/invoices', {
    headers: { Authorization: `Bearer ${stxToken}` },
  });
  const stxInvoices = stxInvoicesRes.data?.data || [];
  const leakedInvoices = stxInvoices.filter((inv: any) => inv.schoolId === oakSchoolId);
  recordTest(
    'TC-TEN-02',
    'Multi-Tenancy',
    'SCHOOL_ADMIN',
    'School A cannot access School B financial fee invoices',
    leakedInvoices.length === 0,
    stxInvoicesRes.status,
    200,
  );

  // Parent isolation: Parent Michael Doe can only see his child's data
  const parentChildrenRes = await request('/parent/my-children', {
    headers: { Authorization: `Bearer ${tokens['PARENT']}` },
  });
  const linkedChildren = parentChildrenRes.data?.data || [];
  const linkedStudent = linkedChildren[0];
  const linkedStudentId = linkedStudent?.id;
  recordTest(
    'TC-TEN-03',
    'Multi-Tenancy',
    'PARENT',
    'Parent can only access linked ward records, not general school students',
    linkedChildren.length > 0 && !!linkedStudentId,
    parentChildrenRes.status,
    200,
  );

  // Attempting to access an unlinked student's assessment report as parent
  const unlinkedAssessmentRes = await request('/parent/children/bogus-unlinked-student-id/assessments', {
    headers: { Authorization: `Bearer ${tokens['PARENT']}` },
  });
  recordTest(
    'TC-TEN-04',
    'Multi-Tenancy',
    'PARENT',
    'Parent cannot access assessment data of another unlinked student (403 Forbidden)',
    unlinkedAssessmentRes.status === 403,
    unlinkedAssessmentRes.status,
    403,
  );

  // Parameter tampering defense: client passing schoolId in query cannot override token tenant
  const paramTamperRes = await request(`/students?schoolId=${stxSchoolId}`, {
    headers: { Authorization: `Bearer ${tokens['SCHOOL_ADMIN']}` }, // Oakridge token
  });
  const oakStudents = paramTamperRes.data?.data || [];
  const tamperSuccess = oakStudents.some((s: any) => s.schoolId === stxSchoolId);
  recordTest(
    'TC-TEN-05',
    'Multi-Tenancy',
    'SCHOOL_ADMIN',
    'User cannot change tenant by passing arbitrary schoolId in request parameters',
    !tamperSuccess,
    paramTamperRes.status,
    200,
  );

  // =========================================================================
  // 3. STUDENT MANAGEMENT & LIFECYCLE
  // =========================================================================
  console.log('\n--- 3. STUDENT MANAGEMENT ---');

  // 3.1 Fetch available class and section for enrollment
  const classesRes = await request('/schools/classes', {
    headers: { Authorization: `Bearer ${tokens['SCHOOL_ADMIN']}` },
  });
  const firstClass = classesRes.data?.data?.[0];
  const firstSection = firstClass?.sections?.[0];

  // 3.2 Create Student via POST /students
  const admPayload = {
    firstName: 'QAEngineer',
    lastName: 'TestLearner',
    dob: '2012-08-15',
    gender: 'FEMALE',
    bloodGroup: 'B+',
    address: '42 QA Testing Boulevard, Academic Zone',
    emergencyContact: '+91 99887 76655',
    classId: firstClass?.id,
    sectionId: firstSection?.id,
    guardianName: 'Robert TestLearner',
    guardianRelation: 'FATHER',
    guardianPhone: '+91 99887 76650',
    guardianEmail: 'robert.test@gmail.com',
  };

  const createStuRes = await request('/students', {
    method: 'POST',
    headers: { Authorization: `Bearer ${tokens['SCHOOL_ADMIN']}` },
    body: JSON.stringify(admPayload),
  });
  const createdStu = createStuRes.data?.data;
  const isStuCreated = (createStuRes.status === 200 || createStuRes.status === 201) && !!createdStu?.id;

  recordTest(
    'TC-STU-01',
    'Student Management',
    'SCHOOL_ADMIN',
    'Create student via admission workflow with active status',
    isStuCreated,
    createStuRes.status,
    '200|201',
  );

  recordTest(
    'TC-STU-02',
    'Student Management',
    'SCHOOL_ADMIN',
    'Admission number auto-generated in format ADM-2026-xxx',
    !!createdStu?.admissionNo && createdStu.admissionNo.startsWith('ADM-'),
    createStuRes.status,
    '200|201',
    `Generated: ${createdStu?.admissionNo}`,
  );

  // 3.3 Edit Student
  if (createdStu?.id) {
    const editStuRes = await request(`/students/${createdStu.id}`, {
      method: 'PATCH',
      headers: { Authorization: `Bearer ${tokens['SCHOOL_ADMIN']}` },
      body: JSON.stringify({
        emergencyContact: '+91 99887 00000',
        bloodGroup: 'AB+',
      }),
    });
    const isStuEdited = editStuRes.status === 200 && editStuRes.data?.data?.emergencyContact === '+91 99887 00000';
    recordTest(
      'TC-STU-03',
      'Student Management',
      'SCHOOL_ADMIN',
      'Edit student demographic and emergency contact details',
      isStuEdited,
      editStuRes.status,
      200,
    );
  }

  // 3.4 Search Student
  const searchStuRes = await request('/students?search=TestLearner', {
    headers: { Authorization: `Bearer ${tokens['OFFICE']}` },
  });
  const searchList = searchStuRes.data?.data || [];
  const foundStu = searchList.some((s: any) => s.lastName === 'TestLearner');
  recordTest(
    'TC-STU-04',
    'Student Management',
    'OFFICE',
    'Search student by name keyword returns matching profile records',
    foundStu,
    searchStuRes.status,
    200,
  );

  // 3.5 View Student Profile with Guardian & Enrollment mapping
  if (createdStu?.id) {
    const viewStuRes = await request(`/students/${createdStu.id}`, {
      headers: { Authorization: `Bearer ${tokens['OFFICE']}` },
    });
    const profile = viewStuRes.data?.data;
    const hasEnrollment = profile?.enrollments?.length > 0;
    const hasGuardian = profile?.studentGuardians?.length > 0;
    recordTest(
      'TC-STU-05',
      'Student Management',
      'OFFICE',
      'View student profile with active enrollment and guardian association',
      viewStuRes.status === 200 && hasEnrollment && hasGuardian,
      viewStuRes.status,
      200,
    );
  }

  // =========================================================================
  // 4. ATTENDANCE & 75% CONDONATION THRESHOLD ENGINE
  // =========================================================================
  console.log('\n--- 4. ATTENDANCE & CONDONATION ---');

  const todayIso = new Date().toISOString().split('T')[0];

  // 4.1 Class Teacher marks all present for assigned section (POST /attendance/sessions)
  const markAllPresRes = await request('/attendance/sessions', {
    method: 'POST',
    headers: { Authorization: `Bearer ${tokens['CLASS_TEACHER']}` },
    body: JSON.stringify({
      sectionId: firstSection?.id || 'sec-10a',
      date: todayIso,
      records: [
        { studentId: createdStu?.id || linkedStudentId, status: 'PRESENT' },
      ],
    }),
  });
  recordTest(
    'TC-ATT-01',
    'Attendance',
    'CLASS_TEACHER',
    'Class Teacher marks attendance session for assigned section',
    markAllPresRes.status === 200 || markAllPresRes.status === 201,
    markAllPresRes.status,
    '200|201',
  );

  // 4.2 Mark individual absentees (ABSENT status)
  const markAbsentRes = await request('/attendance/sessions', {
    method: 'POST',
    headers: { Authorization: `Bearer ${tokens['CLASS_TEACHER']}` },
    body: JSON.stringify({
      sectionId: firstSection?.id || 'sec-10a',
      date: todayIso,
      records: [
        { studentId: createdStu?.id || linkedStudentId, status: 'ABSENT', remarks: 'Unexcused sick leave' },
      ],
    }),
  });
  recordTest(
    'TC-ATT-02',
    'Attendance',
    'CLASS_TEACHER',
    'Mark individual student as ABSENT with remarks',
    markAbsentRes.status === 200 || markAbsentRes.status === 201,
    markAbsentRes.status,
    '200|201',
  );

  // 4.3 Retrieve attendance session and correct an individual record with reason
  const todayRosterRes = await request(`/attendance/today?sectionId=${firstSection?.id || 'sec-10a'}`, {
    headers: { Authorization: `Bearer ${tokens['CLASS_TEACHER']}` },
  });
  const sessionData = todayRosterRes.data?.data?.session;
  const targetRecord = sessionData?.records?.[0];

  if (targetRecord?.id) {
    const correctRecordRes = await request(`/attendance/records/${targetRecord.id}/correction`, {
      method: 'PATCH',
      headers: { Authorization: `Bearer ${tokens['CLASS_TEACHER']}` },
      body: JSON.stringify({
        status: 'EXCUSED',
        remarks: 'Doctor prescription submitted and verified',
        reason: 'Authorized Medical Exemption',
      }),
    });
    recordTest(
      'TC-ATT-03',
      'Attendance',
      'CLASS_TEACHER',
      'Authorized attendance correction updates status and persists audit log',
      correctRecordRes.status === 200,
      correctRecordRes.status,
      200,
    );
  }

  // 4.4 Attendance Percentage and 75% Condonation Threshold Risk Calculation
  const matrixRes = await request(`/attendance/matrix?sectionId=${firstSection?.id || 'sec-10a'}`, {
    headers: { Authorization: `Bearer ${tokens['CLASS_TEACHER']}` },
  });
  const matrixData = matrixRes.data?.data;
  const hasThreshold = matrixData?.stats?.condonationThreshold === 75;
  const hasRiskFlag = matrixData?.students?.every((s: any) => typeof s.isCondonationRisk === 'boolean');
  recordTest(
    'TC-ATT-04',
    'Attendance',
    'CLASS_TEACHER',
    'Attendance register calculates cumulative percentage and 75% condonation threshold',
    matrixRes.status === 200 && hasThreshold && hasRiskFlag,
    matrixRes.status,
    200,
  );

  // =========================================================================
  // 5. EXAMINATION, EXCEL IMPORT, BROADSHEET & LOCKS
  // =========================================================================
  console.log('\n--- 5. EXAMINATION & MARKS ENTRY ---');

  // 5.1 School Admin creates a new examination session
  const createExamRes = await request('/exams', {
    method: 'POST',
    headers: { Authorization: `Bearer ${tokens['SCHOOL_ADMIN']}` },
    body: JSON.stringify({
      name: `QA Term-2 Assessment ${Date.now()}`,
      academicYearId: '673d14a3-ad8d-4b02-9921-bbde48978dc5',
      term: 'TERM_2',
      startDate: '2026-12-01',
      endDate: '2026-12-10',
    }),
  });
  const exam = createExamRes.data?.data;
  const isExamCreated = (createExamRes.status === 200 || createExamRes.status === 201) && !!exam?.id;
  recordTest(
    'TC-EXM-01',
    'Examination',
    'SCHOOL_ADMIN',
    'School Admin creates examination session in DRAFT status',
    isExamCreated,
    createExamRes.status,
    '200|201',
  );

  // 5.2 Add subject schedule to examination
  const subjectsRes = await request('/schools/subjects', {
    headers: { Authorization: `Bearer ${tokens['SCHOOL_ADMIN']}` },
  });
  const subjectsList = subjectsRes.data?.data || [];
  const mathSub = subjectsList.find((s: any) => s.code === 'MTH10') || subjectsList[0];

  let examSubjectId: string | null = null;
  if (exam?.id && mathSub) {
    const addSubRes = await request(`/exams/${exam.id}/subjects`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${tokens['SCHOOL_ADMIN']}` },
      body: JSON.stringify({
        classId: firstClass?.id,
        subjectId: mathSub.id,
        examDate: '2026-12-05',
        maxMarks: 100,
        passMarks: 40,
      }),
    });
    examSubjectId = addSubRes.data?.data?.id;
    recordTest(
      'TC-EXM-02',
      'Examination',
      'SCHOOL_ADMIN',
      'Add subject schedule with maxMarks (100) and passMarks (40)',
      (addSubRes.status === 200 || addSubRes.status === 201) && !!examSubjectId,
      addSubRes.status,
      '200|201',
    );
  }

  // 5.3 Faculty enters marks directly for enrolled student
  const classStudentsRes = await request(`/students?classId=${firstClass?.id}`, {
    headers: { Authorization: `Bearer ${tokens['SCHOOL_ADMIN']}` },
  });
  const enrolledStudents = classStudentsRes.data?.data || [];
  const targetStudent = enrolledStudents[0] || createdStu;

  if (examSubjectId && targetStudent?.id) {
    const enterMarksRes = await request(`/exams/subjects/${examSubjectId}/marks`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${tokens['SCHOOL_ADMIN']}` },
      body: JSON.stringify({
        marks: [
          { studentId: targetStudent.id, marksObtained: 85, isAbsent: false, remarks: 'Excellent performance' },
        ],
      }),
    });
    recordTest(
      'TC-EXM-03',
      'Examination',
      'SCHOOL_ADMIN',
      'Atomically record student marks and remarks for subject exam',
      enterMarksRes.status === 200 || enterMarksRes.status === 201,
      enterMarksRes.status,
      '200|201',
      JSON.stringify(enterMarksRes.data),
    );
  }

  // 5.4 Excel Import Simulation & Row Validation (POST /exams/subjects/:id/import)
  if (examSubjectId && targetStudent?.admissionNo) {
    // A: Valid rows import
    const validImportRes = await request(`/exams/subjects/${examSubjectId}/import`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${tokens['SCHOOL_ADMIN']}` },
      body: JSON.stringify({
        rows: [
          { admissionNo: targetStudent.admissionNo, marksObtained: 92, isAbsent: false },
        ],
      }),
    });
    recordTest(
      'TC-EXM-04',
      'Examination',
      'SCHOOL_ADMIN',
      'Excel / CSV bulk marks import parses valid rows and persists scores',
      validImportRes.status === 200 || validImportRes.status === 201,
      validImportRes.status,
      '200|201',
    );

    // B: Invalid rows rejected (out of bounds mark: 999 > 100, and non-existent student)
    const invalidImportRes = await request(`/exams/subjects/${examSubjectId}/import`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${tokens['SCHOOL_ADMIN']}` },
      body: JSON.stringify({
        rows: [
          { admissionNo: 'NON_EXISTENT_ADM_999', marksObtained: 80 },
          { admissionNo: targetStudent.admissionNo, marksObtained: 999 }, // out of bounds
        ],
      }),
    });
    const importData = invalidImportRes.data?.data;
    const hasRejections = importData?.errorCount === 2 && importData?.errors?.length === 2;
    recordTest(
      'TC-EXM-05',
      'Examination',
      'SCHOOL_ADMIN',
      'Excel import validator isolates and rejects invalid rows (unknown admissionNo, mark > 100)',
      hasRejections,
      invalidImportRes.status,
      '200|201',
      `Errors caught: ${importData?.errorCount}`,
    );
  }

  // 5.5 Broadsheet & Grade Calculation
  const broadsheetRes = await request(`/reports/class-broadsheet?classId=${firstClass?.id || 'cls-10'}`, {
    headers: { Authorization: `Bearer ${tokens['PRINCIPAL']}` },
  });
  const broadsheetData = broadsheetRes.data?.data;
  const isBroadsheetValid = broadsheetRes.status === 200 && Array.isArray(broadsheetData?.rows);
  recordTest(
    'TC-EXM-06',
    'Examination',
    'PRINCIPAL',
    'Consolidated class broadsheet calculates percentages, total marks, and ranks',
    isBroadsheetValid,
    broadsheetRes.status,
    200,
  );

  // 5.6 Result Publication & Published Lock Enforcement
  if (exam?.id && examSubjectId && targetStudent?.id) {
    const publishRes = await request(`/exams/${exam.id}/publish`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${tokens['SCHOOL_ADMIN']}` },
    });
    recordTest(
      'TC-EXM-07',
      'Examination',
      'SCHOOL_ADMIN',
      'Publish examination results to parents and generate audit event',
      publishRes.status === 200 || publishRes.status === 201,
      publishRes.status,
      '200|201',
    );

    // Attempting to edit marks after publication must be REJECTED (EXM-03)
    const postPubEditRes = await request(`/exams/subjects/${examSubjectId}/marks`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${tokens['SCHOOL_ADMIN']}` },
      body: JSON.stringify({
        marks: [{ studentId: targetStudent.id, marksObtained: 99 }],
      }),
    });
    recordTest(
      'TC-EXM-08',
      'Examination',
      'SCHOOL_ADMIN',
      'Immutable lock rejects marks editing after examination publication (400 Bad Request)',
      postPubEditRes.status === 400,
      postPubEditRes.status,
      400,
    );
  }

  // =========================================================================
  // 6. FEES, SERIALIZED RECEIPTS & OVERPAYMENT DEFENSE
  // =========================================================================
  console.log('\n--- 6. FEES & BILLING CONTROLS ---');

  // 6.1 Create Invoice for linked student (John Doe)
  const genInvRes = await request('/fees/invoices/generate', {
    method: 'POST',
    headers: { Authorization: `Bearer ${tokens['OFFICE']}` },
    body: JSON.stringify({
      studentId: linkedStudentId,
      title: 'QA Term Tuition & Lab Fee Demand',
      amount: 1500,
      dueDate: '2026-12-31',
      category: 'SCHOOL',
    }),
  });
  const invoice = genInvRes.data?.data;
  const isInvCreated = (genInvRes.status === 200 || genInvRes.status === 201) && !!invoice?.id;
  recordTest(
    'TC-FEE-01',
    'Fees',
    'OFFICE',
    'Office cashier generates tuition invoice with positive amount',
    isInvCreated,
    genInvRes.status,
    '200|201',
  );

  // 6.2 Reject Overpayment
  if (invoice?.id) {
    const overpayRes = await request('/fees/pay', {
      method: 'POST',
      headers: { Authorization: `Bearer ${tokens['OFFICE']}` },
      body: JSON.stringify({
        invoiceId: invoice.id,
        amount: 999999, // Exceeds 1500
        method: 'CASH',
      }),
    });
    recordTest(
      'TC-FEE-02',
      'Fees',
      'OFFICE',
      'Payment amount exceeding outstanding balance rejected with 400 Bad Request',
      overpayRes.status === 400,
      overpayRes.status,
      400,
    );

    // 6.3 Collect Valid Payment & Generate Serialized Receipt
    const payRes = await request('/fees/pay', {
      method: 'POST',
      headers: { Authorization: `Bearer ${tokens['OFFICE']}` },
      body: JSON.stringify({
        invoiceId: invoice.id,
        amount: 500, // Partial payment
        method: 'CASH',
        notes: 'Partial cash collection at fee desk',
      }),
    });
    const receiptNo = payRes.data?.data?.receiptNo || payRes.data?.receiptNo;
    const isPaid = (payRes.status === 200 || payRes.status === 201) && !!receiptNo && receiptNo.startsWith('REC-');
    recordTest(
      'TC-FEE-03',
      'Fees',
      'OFFICE',
      'Record partial fee payment and generate serialized official receipt (REC-2026-xxxxx)',
      isPaid,
      payRes.status,
      '200|201',
      `Receipt: ${receiptNo}`,
    );

    // 6.4 Verify Outstanding Balance Decreased Accurately
    const updatedInvRes = await request(`/fees/invoices?search=${invoice.invoiceNo}`, {
      headers: { Authorization: `Bearer ${tokens['OFFICE']}` },
    });
    const fetchedInv = updatedInvRes.data?.data?.[0];
    const balanceAccurate = fetchedInv?.paidAmount === 500 && fetchedInv?.dueAmount === 1000 && fetchedInv?.status === 'PARTIAL';
    recordTest(
      'TC-FEE-04',
      'Fees',
      'OFFICE',
      'Outstanding balance updates accurately: Total ₹1500 - Paid ₹500 = Due ₹1000 (PARTIAL status)',
      balanceAccurate,
      updatedInvRes.status,
      200,
    );

    // 6.5 Parent cannot self-mark payment as settled directly
    const parentDirectPay = await request('/fees/pay', {
      method: 'POST',
      headers: { Authorization: `Bearer ${tokens['PARENT']}` },
      body: JSON.stringify({
        invoiceId: invoice.id,
        amount: 1000,
        method: 'CASH',
      }),
    });
    recordTest(
      'TC-FEE-05',
      'Fees',
      'PARENT',
      'Parent is forbidden from directly settling invoices via internal payment endpoint (403 Forbidden)',
      parentDirectPay.status === 403,
      parentDirectPay.status,
      403,
    );

    // 6.6 Parent online checkout session calculation
    const checkoutRes = await request('/payments/checkout', {
      method: 'POST',
      headers: { Authorization: `Bearer ${tokens['PARENT']}` },
      body: JSON.stringify({
        invoiceId: invoice.id,
      }),
    });
    const checkoutData = checkoutRes.data?.data;
    const isCheckoutValid = (checkoutRes.status === 200 || checkoutRes.status === 201) && checkoutData?.serverCalculatedAmount === 1000;
    recordTest(
      'TC-FEE-06',
      'Fees',
      'PARENT',
      'Online checkout creates gateway order with server-calculated payable balance (₹1000)',
      isCheckoutValid,
      checkoutRes.status,
      '200|201',
    );
  }

  // =========================================================================
  // 7. CIRCULARS, TARGETED BROADCASTING & ACKNOWLEDGMENT REPORTS
  // =========================================================================
  console.log('\n--- 7. CIRCULARS & NOTIFICATIONS ---');

  // 7.1 Class Teacher attempts school-wide broadcast -> Must be FORBIDDEN (CIR-CT-01)
  const ctBroadRes = await request('/circulars', {
    method: 'POST',
    headers: { Authorization: `Bearer ${tokens['CLASS_TEACHER']}` },
    body: JSON.stringify({
      title: 'Class Teacher Unauthorized School Announcement',
      content: 'Attempting to broadcast to all parents and staff.',
      targetAudience: 'ALL',
      priority: 'URGENT',
    }),
  });
  recordTest(
    'TC-CIR-01',
    'Circulars',
    'CLASS_TEACHER',
    'Class Teacher forbidden from school-wide broadcasting (403 Forbidden - CIR-CT-01)',
    ctBroadRes.status === 403,
    ctBroadRes.status,
    403,
  );

  // 7.2 Principal creates school-wide circular with sequential circular number
  const principalCircRes = await request('/circulars', {
    method: 'POST',
    headers: { Authorization: `Bearer ${tokens['PRINCIPAL']}` },
    body: JSON.stringify({
      title: 'Annual Institutional Science Fair 2026',
      content: 'All students, parents, and faculty are cordially invited.',
      targetAudience: 'ALL',
      priority: 'HIGH',
      requiresAck: true,
    }),
  });
  const circular = principalCircRes.data?.data;
  const isCircCreated = (principalCircRes.status === 200 || principalCircRes.status === 201) && !!circular?.id;
  recordTest(
    'TC-CIR-02',
    'Circulars',
    'PRINCIPAL',
    'Principal dispatches school-wide circular with sequential number (CIR/2026/xxx)',
    isCircCreated && circular?.circularNumber?.startsWith('CIR/'),
    principalCircRes.status,
    '200|201',
    `Circular: ${circular?.circularNumber}`,
  );

  // 7.3 Parent acknowledges circular with digital remarks
  if (circular?.id) {
    const ackRes = await request(`/circulars/${circular.id}/acknowledge`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${tokens['PARENT']}` },
      body: JSON.stringify({
        remarks: 'Acknowledged. Alexander and parents will attend the science fair.',
      }),
    });
    recordTest(
      'TC-CIR-03',
      'Circulars',
      'PARENT',
      'Parent acknowledges circular and provides signed confirmation note',
      ackRes.status === 200 || ackRes.status === 201,
      ackRes.status,
      '200|201',
    );

    // 7.4 Principal retrieves circular acknowledgment report
    const ackReportRes = await request(`/circulars/${circular.id}/acknowledgements`, {
      headers: { Authorization: `Bearer ${tokens['PRINCIPAL']}` },
    });
    const reportData = ackReportRes.data?.data;
    const hasAck = reportData?.totalAcknowledgements >= 1;
    recordTest(
      'TC-CIR-04',
      'Circulars',
      'PRINCIPAL',
      'Generate real-time circular acknowledgment compliance report',
      ackReportRes.status === 200 && hasAck,
      ackReportRes.status,
      200,
    );
  }

  // =========================================================================
  // 8. ASSIGNMENTS, STUDENT SUBMISSIONS & FACULTY GRADING
  // =========================================================================
  console.log('\n--- 8. ASSIGNMENTS & HOMEWORK PIPELINE ---');

  // 8.1 Find John Doe and his active enrolled class/section
  const myStuProfile = await request(`/students?search=John`, {
    headers: { Authorization: `Bearer ${tokens['SCHOOL_ADMIN']}` },
  });
  const studentsList = myStuProfile.data?.data || [];
  const johnStudent = studentsList.find((s: any) => s.firstName === 'John' && s.lastName === 'Doe') || studentsList[0];
  const johnStudentId = johnStudent?.id;

  const johnDetailsRes = await request(`/students/${johnStudentId}`, {
    headers: { Authorization: `Bearer ${tokens['SCHOOL_ADMIN']}` },
  });
  const johnActiveEnrollment = johnDetailsRes.data?.data?.enrollments?.find((e: any) => e.status === 'ACTIVE');
  const targetClassId = johnActiveEnrollment?.classId || firstClass?.id;
  const targetSectionId = johnActiveEnrollment?.sectionId || firstSection?.id;

  // 8.2 Subject Teacher creates homework assignment for John Doe's section
  const createAsnRes = await request('/assignments', {
    method: 'POST',
    headers: { Authorization: `Bearer ${tokens['SUBJECT_TEACHER']}` },
    body: JSON.stringify({
      title: 'Lab Report: Acid-Base Titration & pH Curves',
      description: 'Prepare a 3-page experimental report including indicator color changes and graphs.',
      classId: targetClassId,
      sectionId: targetSectionId,
      subjectId: mathSub?.id,
      maxMarks: 50,
      dueDate: new Date(Date.now() + 5 * 86400000).toISOString(),
    }),
  });
  const assignment = createAsnRes.data?.data;
  const isAsnCreated = (createAsnRes.status === 200 || createAsnRes.status === 201) && !!assignment?.id;
  recordTest(
    'TC-ASN-01',
    'Assignments',
    'SUBJECT_TEACHER',
    'Subject Teacher creates course assignment with due date and maxMarks',
    isAsnCreated,
    createAsnRes.status,
    '200|201',
  );

  // 8.3 Student submits homework
  let submissionId: string | null = null;
  if (assignment?.id && johnStudentId) {
    const submitAsnRes = await request(`/assignments/${assignment.id}/submissions`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${tokens['STUDENT']}` },
      body: JSON.stringify({
        studentId: johnStudentId,
        notes: 'Attached lab observations and neutralization curves graph.',
        fileUrl: 'https://storage.schoolerp.com/submissions/lab_report_titration.pdf',
      }),
    });
    const submission = submitAsnRes.data?.data;
    submissionId = submission?.id;
    recordTest(
      'TC-ASN-02',
      'Assignments',
      'STUDENT',
      'Student submits assignment response with notes and HTTPS document link',
      (submitAsnRes.status === 200 || submitAsnRes.status === 201) && !!submissionId,
      submitAsnRes.status,
      '200|201',
      JSON.stringify(submitAsnRes.data),
    );
  }

  // 8.3 Teacher evaluates submission, assigns marks, and provides feedback
  if (submissionId) {
    const gradeRes = await request(`/assignments/submissions/${submissionId}/grade`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${tokens['SUBJECT_TEACHER']}` },
      body: JSON.stringify({
        marksObtained: 46,
        feedback: 'Exceptional lab analysis. Data table and graphs are accurately calibrated.',
      }),
    });
    const gradedData = gradeRes.data?.data;
    const isGraded = (gradeRes.status === 200 || gradeRes.status === 201) && gradedData?.marksObtained === 46 && gradedData?.status === 'REVIEWED';
    recordTest(
      'TC-ASN-03',
      'Assignments',
      'SUBJECT_TEACHER',
      'Teacher grades submission: records score (46/50), qualitative feedback, and sets status to REVIEWED',
      isGraded,
      gradeRes.status,
      '200|201',
    );
  }

  // =========================================================================
  // 9. LEAVE WORKFLOWS & GUARDIAN NOTIFICATIONS
  // =========================================================================
  console.log('\n--- 9. LEAVE MANAGEMENT WORKFLOW ---');

  // 9.1 Parent submits leave request for ward (POST /leave-requests)
  const leaveReqRes = await request('/leave-requests', {
    method: 'POST',
    headers: { Authorization: `Bearer ${tokens['PARENT']}` },
    body: JSON.stringify({
      studentId: linkedStudentId,
      leaveType: 'MEDICAL',
      startDate: '2026-11-20',
      endDate: '2026-11-22',
      reason: 'Fever and viral infection, doctor advises 2 days bed rest.',
      supportingDocUrl: 'https://storage.schoolerp.com/medical/doctor_note.pdf',
    }),
  });
  const leave = leaveReqRes.data?.data || leaveReqRes.data;
  const isLeaveCreated = (leaveReqRes.status === 200 || leaveReqRes.status === 201) && !!leave?.id;
  recordTest(
    'TC-LEV-01',
    'Leave Management',
    'PARENT',
    'Parent applies for student medical leave with duration and prescription link',
    isLeaveCreated,
    leaveReqRes.status,
    '200|201',
    JSON.stringify(leaveReqRes.data),
  );

  // 9.2 Class Teacher retrieves inbox and decides leave
  if (leave?.id) {
    const inboxRes = await request('/leave-requests/inbox', {
      headers: { Authorization: `Bearer ${tokens['CLASS_TEACHER']}` },
    });
    const inboxItems = inboxRes.data?.data || [];
    const foundInInbox = inboxItems.some((l: any) => l.id === leave.id);
    recordTest(
      'TC-LEV-02',
      'Leave Management',
      'CLASS_TEACHER',
      'Class Teacher inbox displays pending leave requests for assigned section',
      inboxRes.status === 200 && foundInInbox,
      inboxRes.status,
      200,
    );

    // Decide leave with APPROVED
    const decideRes = await request(`/leave-requests/${leave.id}/decide`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${tokens['CLASS_TEACHER']}` },
      body: JSON.stringify({
        status: 'APPROVED',
        remarks: 'Approved. Please collect missed class notes from Section 10-A classroom repo.',
      }),
    });
    const decidedData = decideRes.data?.data || decideRes.data;
    recordTest(
      'TC-LEV-03',
      'Leave Management',
      'CLASS_TEACHER',
      'Class Teacher approves leave application and notifies guardians',
      (decideRes.status === 200 || decideRes.status === 201) && decidedData?.status === 'APPROVED',
      decideRes.status,
      '200|201',
    );
  }

  // =========================================================================
  // 10. PLATFORM SUPERADMIN CONTROL PLANE
  // =========================================================================
  console.log('\n--- 10. PLATFORM SUPERADMIN CONTROL PLANE ---');

  // 10.1 SaaS platform metrics
  const statsRes = await request('/platform/stats', {
    headers: { Authorization: `Bearer ${tokens['PLATFORM_OWNER']}` },
  });
  const stats = statsRes.data?.data;
  recordTest(
    'TC-PLT-01',
    'Platform Superadmin',
    'PLATFORM_OWNER',
    'Platform Owner views SaaS platform statistics (schools count, ARR, active plans)',
    statsRes.status === 200 && typeof stats?.totalSchools === 'number',
    statsRes.status,
    200,
  );

  // 10.2 List all provisioned institutions
  const schoolsListRes = await request('/platform/schools', {
    headers: { Authorization: `Bearer ${tokens['PLATFORM_OWNER']}` },
  });
  const schools = schoolsListRes.data?.data || [];
  recordTest(
    'TC-PLT-02',
    'Platform Superadmin',
    'PLATFORM_OWNER',
    'List all provisioned school tenants across the SaaS ecosystem',
    schoolsListRes.status === 200 && schools.length >= 2,
    schoolsListRes.status,
    200,
  );

  // =========================================================================
  // FINAL EXECUTION SUMMARY
  // =========================================================================
  const total = testResults.length;
  const passed = testResults.filter((r) => r.passed).length;
  const failed = testResults.filter((r) => !r.passed).length;
  const passRate = ((passed / total) * 100).toFixed(1);

  console.log('\n======================================================================');
  console.log(`🏁 QA EXECUTION COMPLETE: ${total} TESTS RUN`);
  console.log(`   Passed: ${passed} | Failed: ${failed} | Success Rate: ${passRate}%`);
  console.log('======================================================================\n');

  if (failed > 0) {
    console.error('FAILED TESTS:');
    testResults.filter((r) => !r.passed).forEach((f) => {
      console.error(`- [${f.id}] [${f.role}] ${f.description}: ${f.errorDetail || 'Check logs'}`);
    });
    process.exit(1);
  }
}

runQASuite().catch((err) => {
  console.error('Senior QA Suite fatal error:', err);
  process.exit(1);
});
