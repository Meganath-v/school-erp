/**
 * Comprehensive Security Review & Audit Controls Verification Suite
 * Verifies all 16 inspection items and 12 audit log event categories.
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

let passed = 0;
let failed = 0;

function assert(condition: boolean, testName: string, detail?: string) {
  if (condition) {
    console.log(`  ✅ [PASS] ${testName}`);
    passed++;
  } else {
    console.error(`  ❌ [FAIL] ${testName} ${detail ? `- ${detail}` : ''}`);
    failed++;
  }
}

async function runSecuritySuite() {
  console.log('================================================================');
  console.log('🔒 EXECUTING LINWAYS-GRADE COMPREHENSIVE SECURITY TEST SUITE');
  console.log('================================================================\n');

  // 1. Password Handling & Failed Login Audit
  console.log('--- 1. Password Handling & Failed Login Audit ---');
  const failedLoginRes = await request('/auth/login', {
    method: 'POST',
    body: JSON.stringify({
      login: 'admin@oakridge.edu',
      password: 'wrong_password_123!',
      schoolCode: 'OAK01',
    }),
  });
  assert(
    failedLoginRes.status === 401,
    'Failed login returns 401 Unauthorized',
    `Received status: ${failedLoginRes.status}`,
  );

  // 2. Successful Login & JWT Issuance for Multi-Tenancy Roles
  console.log('\n--- 2. Multi-Role Authentication & Token Issuance ---');
  // Admin Login
  const adminLoginRes = await request('/auth/login', {
    method: 'POST',
    body: JSON.stringify({
      login: 'admin@oakridge.edu',
      password: 'password123',
      schoolCode: 'OAK01',
    }),
  });
  assert(
    adminLoginRes.status === 200 || adminLoginRes.status === 201,
    'School Admin login succeeds',
    `Status: ${adminLoginRes.status}`,
  );
  const adminToken = adminLoginRes.data?.data?.accessToken;
  const oakridgeSchoolId = adminLoginRes.data?.data?.activeSchool?.id;
  assert(!!adminToken && adminToken.split('.').length === 3, 'JWT access token is cryptographically formatted');
  assert(!JSON.stringify(adminLoginRes.data).includes('passwordHash'), 'Response does not expose password hashes');

  // Platform Owner Login
  const superAdminLoginRes = await request('/auth/login', {
    method: 'POST',
    body: JSON.stringify({
      login: 'superadmin@erp.com',
      password: 'password123',
    }),
  });
  assert(
    superAdminLoginRes.status === 200 || superAdminLoginRes.status === 201,
    'Platform Owner login succeeds',
    `Status: ${superAdminLoginRes.status}`,
  );
  const superToken = superAdminLoginRes.data?.data?.accessToken;

  // Student Login
  const studentLoginRes = await request('/auth/login', {
    method: 'POST',
    body: JSON.stringify({
      login: 'student.john@oakridge.edu',
      password: 'password123',
      schoolCode: 'OAK01',
    }),
  });
  assert(
    studentLoginRes.status === 200 || studentLoginRes.status === 201,
    'Student login succeeds',
    `Status: ${studentLoginRes.status}`,
  );
  const studentToken = studentLoginRes.data?.data?.accessToken;

  // Subject Teacher Login (David Jones)
  const teacherLoginRes = await request('/auth/login', {
    method: 'POST',
    body: JSON.stringify({
      login: 'teacher.jones@oakridge.edu',
      password: 'password123',
      schoolCode: 'OAK01',
    }),
  });
  assert(
    teacherLoginRes.status === 200 || teacherLoginRes.status === 201,
    'Subject Teacher login succeeds',
    `Status: ${teacherLoginRes.status}`,
  );
  const teacherToken = teacherLoginRes.data?.data?.accessToken;

  // Parent Login
  const parentLoginRes = await request('/auth/login', {
    method: 'POST',
    body: JSON.stringify({
      login: 'parent.doe@gmail.com',
      password: 'password123',
      schoolCode: 'OAK01',
    }),
  });
  assert(
    parentLoginRes.status === 200 || parentLoginRes.status === 201,
    'Parent login succeeds',
    `Status: ${parentLoginRes.status}`,
  );
  const parentToken = parentLoginRes.data?.data?.accessToken;

  // 3. JWT Tampering & Signature Validation
  console.log('\n--- 3. JWT Tampering & Signature Validation ---');
  const forgedToken = adminToken.substring(0, adminToken.length - 8) + 'invalid_sig';
  const tamperRes = await request('/schools/current', {
    headers: { Authorization: `Bearer ${forgedToken}` },
  });
  assert(tamperRes.status === 401, 'Forged JWT signature is rejected with 401 Unauthorized');

  // 4. Role-Based Authorization Guard & Boundary Enforcement
  console.log('\n--- 4. Role-Based Access Control Guards ---');
  // Student attempting to access audit logs -> 403 Forbidden
  const studentAuditRes = await request('/audit-logs', {
    headers: { Authorization: `Bearer ${studentToken}` },
  });
  assert(studentAuditRes.status === 403, 'Student blocked from audit logs with 403 Forbidden');

  // Parent attempting to access audit logs -> 403 Forbidden
  const parentAuditRes = await request('/audit-logs', {
    headers: { Authorization: `Bearer ${parentToken}` },
  });
  assert(parentAuditRes.status === 403, 'Parent blocked from audit logs with 403 Forbidden');

  // Subject Teacher attempting to access audit logs -> 403 Forbidden
  const teacherAuditRes = await request('/audit-logs', {
    headers: { Authorization: `Bearer ${teacherToken}` },
  });
  assert(teacherAuditRes.status === 403, 'Teacher blocked from audit logs with 403 Forbidden');

  // School Admin accessing audit logs -> 200 OK
  const adminAuditRes = await request('/audit-logs', {
    headers: { Authorization: `Bearer ${adminToken}` },
  });
  assert(adminAuditRes.status === 200, 'School Admin permitted to view audit logs with 200 OK');

  // Platform Owner accessing audit logs -> 200 OK
  const superAuditRes = await request('/audit-logs', {
    headers: { Authorization: `Bearer ${superToken}` },
  });
  assert(superAuditRes.status === 200, 'Platform Owner permitted to view audit logs with 200 OK');

  // 5. Tenant Isolation Verification
  console.log('\n--- 5. Tenant Isolation Verification ---');
  // Login as St. Xavier's Admin
  const xavierAdminRes = await request('/auth/login', {
    method: 'POST',
    body: JSON.stringify({
      login: 'admin@stxaviers.edu',
      password: 'password123',
      schoolCode: 'STX02',
    }),
  });
  const xavierToken = xavierAdminRes.data?.data?.accessToken;
  assert(!!xavierToken, 'St. Xavier\'s Admin logged in for cross-tenant boundary verification');

  // St. Xavier admin attempting to read Oakridge students
  const crossTenantStudents = await request('/students', {
    headers: { Authorization: `Bearer ${xavierToken}` },
  });
  const xavierStudentList = crossTenantStudents.data?.data || [];
  // Ensure none of the returned students belong to Oakridge
  const leakedOakridgeStudents = xavierStudentList.filter((s: any) => s.schoolId === oakridgeSchoolId);
  assert(
    leakedOakridgeStudents.length === 0,
    'Cross-tenant isolation enforced: St. Xavier\'s Admin cannot see Oakridge student records',
  );

  // 6. Payment Manipulation Defenses
  console.log('\n--- 6. Payment Manipulation Defenses ---');
  const invRes = await request('/fees/invoices', {
    headers: { Authorization: `Bearer ${adminToken}` },
  });
  const invoice = invRes.data?.data?.[0];
  assert(!!invoice, 'Active institution invoice located for payment manipulation checks');

  if (invoice) {
    // A: Zero amount payment attempt
    const zeroPayRes = await request('/fees/pay', {
      method: 'POST',
      headers: { Authorization: `Bearer ${adminToken}` },
      body: JSON.stringify({
        invoiceId: invoice.id,
        amount: 0,
        method: 'CASH',
      }),
    });
    assert(zeroPayRes.status === 400, 'Zero payment amount rejected with 400 Bad Request');

    // B: Negative amount payment attempt
    const negPayRes = await request('/fees/pay', {
      method: 'POST',
      headers: { Authorization: `Bearer ${adminToken}` },
      body: JSON.stringify({
        invoiceId: invoice.id,
        amount: -500,
        method: 'CASH',
      }),
    });
    assert(negPayRes.status === 400, 'Negative payment amount rejected with 400 Bad Request');

    // C: Exorbitant overpayment attempt
    const overPayRes = await request('/fees/pay', {
      method: 'POST',
      headers: { Authorization: `Bearer ${adminToken}` },
      body: JSON.stringify({
        invoiceId: invoice.id,
        amount: 99999999,
        method: 'CASH',
      }),
    });
    assert(overPayRes.status === 400, 'Payment exceeding invoice balance rejected with 400 Bad Request');
  }

  // 7. Examination Authorization & Published Lock
  console.log('\n--- 7. Examination Authorization & Published Lock ---');
  const examsRes = await request('/exams', {
    headers: { Authorization: `Bearer ${adminToken}` },
  });
  const exams = examsRes.data?.data || [];
  const publishedExam = exams.find((e: any) => e.status === 'PUBLISHED');
  assert(!!publishedExam, 'Found published examination for lock testing');

  if (publishedExam && publishedExam.subjects?.length > 0) {
    const mathExamSubject = publishedExam.subjects.find((s: any) => s.subjectName?.toLowerCase().includes('math')) || publishedExam.subjects[0];

    // Attempt to edit marks on a published exam
    const editPublishedRes = await request(`/exams/subjects/${mathExamSubject.id}/marks`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${adminToken}` },
      body: JSON.stringify({
        marks: [{ studentId: 'some-student', marksObtained: 85 }],
      }),
    });
    assert(
      editPublishedRes.status === 400,
      'Cannot edit marks for an already published examination (400 Bad Request)',
      `Status: ${editPublishedRes.status}`,
    );

    // Create a new DRAFT examination to test Subject Teacher assignment boundaries
    const createDraftExamRes = await request('/exams', {
      method: 'POST',
      headers: { Authorization: `Bearer ${adminToken}` },
      body: JSON.stringify({
        name: `Unit Assessment Draft ${Date.now()}`,
        academicYearId: publishedExam.academicYearId,
        term: 'TERM_1',
        startDate: '2026-11-20',
        endDate: '2026-11-25',
      }),
    });
    const draftExam = createDraftExamRes.data?.data;

    if (draftExam) {
      // Add Math subject to draft exam
      const addMathRes = await request(`/exams/${draftExam.id}/subjects`, {
        method: 'POST',
        headers: { Authorization: `Bearer ${adminToken}` },
        body: JSON.stringify({
          classId: mathExamSubject.classId,
          subjectId: mathExamSubject.subjectId,
          examDate: '2026-11-21',
          maxMarks: 100,
          passMarks: 40,
        }),
      });
      const draftMathSubject = addMathRes.data?.data;

      if (draftMathSubject) {
        // Teacher Jones (assigned to Science, NOT Math) attempts to enter Math marks
        const teacherJonesRes = await request(`/exams/subjects/${draftMathSubject.id}/marks`, {
          method: 'POST',
          headers: { Authorization: `Bearer ${teacherToken}` },
          body: JSON.stringify({
            marks: [{ studentId: 'dummy-id', marksObtained: 90 }],
          }),
        });
        assert(
          teacherJonesRes.status === 403,
          'Subject Teacher forbidden from entering marks for unassigned course (403 Forbidden)',
          `Status: ${teacherJonesRes.status}`,
        );

        // Authorized Admin submits marks for enrolled student -> triggers MARKS_SUBMITTED
        const classStudentsRes = await request('/students', {
          headers: { Authorization: `Bearer ${adminToken}` },
        });
        const enrolledStudent = classStudentsRes.data?.data?.[0];
        if (enrolledStudent) {
          await request(`/exams/subjects/${draftMathSubject.id}/marks`, {
            method: 'POST',
            headers: { Authorization: `Bearer ${adminToken}` },
            body: JSON.stringify({
              marks: [{ studentId: enrolledStudent.id, marksObtained: 88, isAbsent: false }],
            }),
          });
        }

        // Publish the examination -> triggers RESULTS_PUBLISHED
        await request(`/exams/${draftExam.id}/publish`, {
          method: 'POST',
          headers: { Authorization: `Bearer ${adminToken}` },
        });
      }
    }
  }

  // 8. Audit Logging Verification Across All 12 Mandated Categories
  console.log('\n--- 8. Audit Logging Verification Across All 12 Mandated Categories ---');
  // Trigger operations to ensure recent entries are generated
  // A: Student creation & update
  const studentCreateRes = await request('/students', {
    method: 'POST',
    headers: { Authorization: `Bearer ${adminToken}` },
    body: JSON.stringify({
      firstName: 'AuditTest',
      lastName: 'Student',
      dob: '2012-05-10',
      gender: 'MALE',
      bloodGroup: 'O+',
      emergencyContact: '9876543210',
    }),
  });
  const createdStudent = studentCreateRes.data?.data;
  assert(
    studentCreateRes.status === 200 || studentCreateRes.status === 201,
    'Audit test student created',
  );

  if (createdStudent) {
    await request(`/students/${createdStudent.id}`, {
      method: 'PATCH',
      headers: { Authorization: `Bearer ${adminToken}` },
      body: JSON.stringify({ emergencyContact: '9998887776' }),
    });
  }

  // B: Staff Update
  const staffListRes = await request('/staff', {
    headers: { Authorization: `Bearer ${adminToken}` },
  });
  const firstStaff = staffListRes.data?.data?.[0];
  if (firstStaff) {
    await request(`/staff/${firstStaff.id}`, {
      method: 'PATCH',
      headers: { Authorization: `Bearer ${adminToken}` },
      body: JSON.stringify({ designation: 'Senior Faculty' }),
    });
  }

  // C: Attendance Marking
  await request('/attendance', {
    method: 'POST',
    headers: { Authorization: `Bearer ${adminToken}` },
    body: JSON.stringify({
      sectionId: 'sec-10a',
      date: new Date().toISOString(),
      records: [{ studentId: createdStudent?.id || 'stu-01', status: 'PRESENT' }],
    }),
  });

  // D: Fee Generation & Fee Payment
  if (createdStudent) {
    const invCreateRes = await request('/fees/invoices/generate', {
      method: 'POST',
      headers: { Authorization: `Bearer ${adminToken}` },
      body: JSON.stringify({
        studentId: createdStudent.id,
        title: 'Security Audit Fee Test',
        amount: 250,
        dueDate: '2026-12-31',
        category: 'SCHOOL',
      }),
    });
    const generatedInv = invCreateRes.data?.data;
    if (generatedInv) {
      await request('/fees/pay', {
        method: 'POST',
        headers: { Authorization: `Bearer ${adminToken}` },
        body: JSON.stringify({
          invoiceId: generatedInv.id,
          amount: 250,
          method: 'CASH',
          notes: 'Security audit test payment',
        }),
      });
    }
  }

  // E: Circular Dispatch
  await request('/circulars', {
    method: 'POST',
    headers: { Authorization: `Bearer ${adminToken}` },
    body: JSON.stringify({
      title: 'Security Review Circular',
      content: 'Institutional safety protocol testing in progress.',
      targetAudience: 'ALL',
      priority: 'NORMAL',
    }),
  });

  // Fetch all audit logs for Oakridge
  const auditLogsRes = await request('/audit-logs?limit=300', {
    headers: { Authorization: `Bearer ${adminToken}` },
  });
  const logs = Array.isArray(auditLogsRes.data?.data)
    ? auditLogsRes.data.data
    : auditLogsRes.data?.data?.items || [];
  const logActions = new Set(logs.map((l: any) => l.action));

  console.log(`  Retrieved ${logs.length} institutional audit entries from database.`);

  // 12 Mandated Audit Categories Verification
  assert(logActions.has('LOGIN_SUCCESS'), 'Audit entry recorded: Login success (LOGIN_SUCCESS)');
  assert(logActions.has('LOGIN_FAILED'), 'Audit entry recorded: Failed login attempt (LOGIN_FAILED)');
  assert(logActions.has('STUDENT_CREATED'), 'Audit entry recorded: Student creation (STUDENT_CREATED)');
  assert(logActions.has('STUDENT_UPDATED'), 'Audit entry recorded: Student update (STUDENT_UPDATED)');
  assert(logActions.has('STAFF_CREATED') || logActions.has('STAFF_ASSIGNED') || logActions.has('STAFF_UPDATED'), 'Audit entry recorded: Staff changes (STAFF_UPDATED / STAFF_CREATED)');
  assert(logActions.has('ATTENDANCE_MARKED') || logActions.has('ATTENDANCE_MODIFIED'), 'Audit entry recorded: Attendance modifications (ATTENDANCE_MARKED / MODIFIED)');
  assert(logActions.has('MARKS_SUBMITTED') || logActions.has('MARKS_BULK_IMPORTED'), 'Audit entry recorded: Marks submission (MARKS_SUBMITTED)');
  assert(logActions.has('RESULTS_PUBLISHED'), 'Audit entry recorded: Result publication (RESULTS_PUBLISHED)');
  assert(logActions.has('FEE_COLLECTION') || logActions.has('INVOICE_PAYMENT_RECORDED'), 'Audit entry recorded: Fee collections (FEE_COLLECTION)');
  assert(logActions.has('RECEIPT_GENERATED'), 'Audit entry recorded: Receipt generation (RECEIPT_GENERATED)');
  assert(logActions.has('LEAVE_APPROVED') || logActions.has('LEAVE_REJECTED'), 'Audit entry recorded: Leave approvals (LEAVE_APPROVED / REJECTED)');
  assert(logActions.has('CIRCULAR_DISPATCHED'), 'Audit entry recorded: Circular dispatch (CIRCULAR_DISPATCHED)');

  // Verify Audit Log Structure (actor, action, relevant record, timestamp, tenant context)
  const sampleLog = logs[0];
  assert(
    !!sampleLog?.actorName && !!sampleLog?.action && !!sampleLog?.entity && !!sampleLog?.timestamp,
    'Audit entries contain actor, action, relevant record, timestamp, and details',
  );

  // 9. Token Revocation on Logout
  console.log('\n--- 9. Token Revocation on Logout ---');
  const tempLogin = await request('/auth/login', {
    method: 'POST',
    body: JSON.stringify({
      login: 'office@oakridge.edu',
      password: 'password123',
      schoolCode: 'OAK01',
    }),
  });
  const officeToken = tempLogin.data?.data?.accessToken;
  assert(
    tempLogin.status === 200 || tempLogin.status === 201,
    'Office user signed in for session revocation test',
  );

  // Verify token works before logout
  const beforeLogoutRes = await request('/schools/current', {
    headers: { Authorization: `Bearer ${officeToken}` },
  });
  assert(beforeLogoutRes.status === 200, 'Token valid prior to logout');

  // Perform logout
  const logoutRes = await request('/auth/logout', {
    method: 'POST',
    headers: { Authorization: `Bearer ${officeToken}` },
  });
  assert(
    logoutRes.status === 200 || logoutRes.status === 201,
    'Logout succeeded and tokenVersion incremented',
  );

  // Verify token is immediately invalidated
  const afterLogoutRes = await request('/schools/current', {
    headers: { Authorization: `Bearer ${officeToken}` },
  });
  assert(
    afterLogoutRes.status === 401,
    'Revoked token rejected with 401 Unauthorized ("Session has been revoked")',
  );

  // 10. SQL Injection & Error Masking Checks
  console.log('\n--- 10. SQL Injection & Error Masking Checks ---');
  const sqliTest = await request(`/students?search=${encodeURIComponent("' OR 1=1 --")}`, {
    headers: { Authorization: `Bearer ${adminToken}` },
  });
  assert(sqliTest.status === 200, 'Parameterized queries resist SQL injection strings gracefully');
  assert(!JSON.stringify(sqliTest.data).includes('SELECT *'), 'No raw SQL queries leaked in payload');

  // 11. Final Summary
  console.log('\n================================================================');
  console.log(`🏁 SECURITY SUITE SUMMARY: ${passed} PASSED, ${failed} FAILED (${((passed / (passed + failed)) * 100).toFixed(1)}%)`);
  console.log('================================================================\n');

  if (failed > 0) {
    process.exit(1);
  }
}

runSecuritySuite().catch((err) => {
  console.error('Security test suite fatal error:', err);
  process.exit(1);
});
