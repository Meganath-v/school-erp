/**
 * Linways AMS & Multi-Tenant School ERP
 * Automated End-to-End API Test Suite
 */

import * as http from 'http';

const API_BASE = 'http://localhost:3000/api/v1';

interface TestResult {
  suite: string;
  testName: string;
  passed: boolean;
  durationMs: number;
  error?: string;
  details?: any;
}

const results: TestResult[] = [];

async function request(
  method: string,
  path: string,
  data?: any,
  headers: Record<string, string> = {},
): Promise<{ status: number; body: any; headers: http.IncomingHttpHeaders }> {
  const url = new URL(API_BASE + path);

  return new Promise((resolve, reject) => {
    const postData = data ? JSON.stringify(data) : undefined;
    const reqHeaders: Record<string, string> = {
      'Content-Type': 'application/json',
      ...headers,
    };
    if (postData) {
      reqHeaders['Content-Length'] = Buffer.byteLength(postData).toString();
    }

    const req = http.request(
      url,
      {
        method,
        headers: reqHeaders,
      },
      (res) => {
        let rawBody = '';
        res.on('data', (chunk) => (rawBody += chunk));
        res.on('end', () => {
          let parsed;
          try {
            parsed = JSON.parse(rawBody);
          } catch {
            parsed = rawBody;
          }
          // Unwrap standard Nest response envelope if present
          const unwrapped =
            parsed && typeof parsed === 'object' && 'data' in parsed && !('statusCode' in parsed)
              ? parsed.data
              : parsed;

          resolve({
            status: res.statusCode || 0,
            body: unwrapped,
            headers: res.headers,
          });
        });
      },
    );

    req.on('error', reject);
    if (postData) {
      req.write(postData);
    }
    req.end();
  });
}

async function runTest(
  suite: string,
  testName: string,
  fn: () => Promise<void>,
) {
  const start = Date.now();
  try {
    await fn();
    results.push({
      suite,
      testName,
      passed: true,
      durationMs: Date.now() - start,
    });
    console.log(`  ✓ [PASS] ${testName}`);
  } catch (err: any) {
    results.push({
      suite,
      testName,
      passed: false,
      durationMs: Date.now() - start,
      error: err.message || String(err),
    });
    console.error(`  ✗ [FAIL] ${testName}: ${err.message || String(err)}`);
  }
}

async function main() {
  console.log('===============================================================');
  console.log('   LINWAYS ACADEMIC MANAGEMENT SYSTEM - API TEST SUITE        ');
  console.log('===============================================================\n');

  let superadminToken = '';
  let oakridgeAdminToken = '';
  let classTeacherToken = '';
  let subjectTeacherToken = '';
  let parentToken = '';
  let oakridgeSchoolId = '';
  let testInvoiceId = '';

  // 1. Tenant Discovery & Resolution
  console.log('--- 1. Tenant Discovery & Domain Resolution ---');
  await runTest('Tenant Discovery', 'List all active school tenants', async () => {
    const res = await request('GET', '/tenant-discovery');
    if (res.status !== 200) throw new Error(`Expected 200, got ${res.status}`);
    if (!Array.isArray(res.body) || res.body.length < 2) {
      throw new Error(`Expected at least 2 tenants, found ${res.body?.length}`);
    }
    const oak = res.body.find((t: any) => t.code === 'OAK01');
    if (!oak) throw new Error('Tenant OAK01 not found');
    oakridgeSchoolId = oak.id;
  });

  await runTest('Tenant Discovery', 'Resolve tenant by school code OAK01', async () => {
    const res = await request('GET', '/tenants/resolve/OAK01');
    if (res.status !== 200) throw new Error(`Expected 200, got ${res.status}`);
    if (res.body.code !== 'OAK01' || !res.body.name.includes('Oakridge')) {
      throw new Error(`Unexpected tenant resolution payload: ${JSON.stringify(res.body)}`);
    }
  });

  // 2. Multi-Role Authentication
  console.log('\n--- 2. Multi-Role Authentication ---');
  await runTest('Authentication', 'Superadmin login and JWT generation', async () => {
    const res = await request('POST', '/auth/login', {
      login: 'superadmin@erp.com',
      password: 'password123',
    });
    if (res.status !== 200 && res.status !== 201) {
      throw new Error(`Expected 200/201, got ${res.status}: ${JSON.stringify(res.body)}`);
    }
    if (!res.body.accessToken) throw new Error('Missing accessToken');
    superadminToken = res.body.accessToken;
  });

  await runTest('Authentication', 'School Admin login for Oakridge', async () => {
    const res = await request('POST', '/auth/login', {
      login: 'admin@oakridge.edu',
      password: 'password123',
      schoolCode: 'OAK01',
    });
    if (res.status !== 200 && res.status !== 201) {
      throw new Error(`Expected 200/201, got ${res.status}: ${JSON.stringify(res.body)}`);
    }
    if (!res.body.accessToken) throw new Error('Missing accessToken');
    oakridgeAdminToken = res.body.accessToken;
  });

  await runTest('Authentication', 'Class Teacher login', async () => {
    const res = await request('POST', '/auth/login', {
      login: 'teacher.smith@oakridge.edu',
      password: 'password123',
      schoolCode: 'OAK01',
    });
    if (res.status !== 200 && res.status !== 201) {
      throw new Error(`Expected 200/201, got ${res.status}: ${JSON.stringify(res.body)}`);
    }
    classTeacherToken = res.body.accessToken;
  });

  await runTest('Authentication', 'Subject Teacher login', async () => {
    const res = await request('POST', '/auth/login', {
      login: 'teacher.jones@oakridge.edu',
      password: 'password123',
      schoolCode: 'OAK01',
    });
    if (res.status !== 200 && res.status !== 201) {
      throw new Error(`Expected 200/201, got ${res.status}: ${JSON.stringify(res.body)}`);
    }
    subjectTeacherToken = res.body.accessToken;
  });

  await runTest('Authentication', 'Parent login with multi-school profile', async () => {
    const res = await request('POST', '/auth/login', {
      login: 'parent.doe@gmail.com',
      password: 'password123',
    });
    if (res.status !== 200 && res.status !== 201) {
      throw new Error(`Expected 200/201, got ${res.status}: ${JSON.stringify(res.body)}`);
    }
    parentToken = res.body.accessToken;
  });

  // 3. Platform Administration Plane
  console.log('\n--- 3. Platform Control Plane (Superadmin) ---');
  await runTest('Platform Admin', 'Retrieve multi-tenant SaaS stats', async () => {
    const res = await request('GET', '/platform/stats', undefined, {
      Authorization: `Bearer ${superadminToken}`,
    });
    if (res.status !== 200) throw new Error(`Expected 200, got ${res.status}: ${JSON.stringify(res.body)}`);
    if (typeof res.body.totalSchools !== 'number' || res.body.totalSchools < 2) {
      throw new Error(`Invalid totalSchools metric: ${res.body.totalSchools}`);
    }
  });

  await runTest('Platform Admin', 'Retrieve school tenants directory', async () => {
    const res = await request('GET', '/platform/schools', undefined, {
      Authorization: `Bearer ${superadminToken}`,
    });
    if (res.status !== 200) throw new Error(`Expected 200, got ${res.status}`);
    if (!Array.isArray(res.body) || res.body.length < 2) {
      throw new Error(`Expected schools array, got ${typeof res.body}`);
    }
  });

  // 4. Linways Academic Management System
  console.log('\n--- 4. Linways Academic Management System ---');
  let firstLessonPlanId = '';
  await runTest('Linways Academics', 'Retrieve Course Delivery Plans (OBE Lesson Plans)', async () => {
    const res = await request('GET', '/academics/lesson-plans', undefined, {
      Authorization: `Bearer ${subjectTeacherToken}`,
      'x-school-id': oakridgeSchoolId,
    });
    if (res.status !== 200) throw new Error(`Expected 200, got ${res.status}`);
    const plans = Array.isArray(res.body) ? res.body : res.body.plans;
    if (!Array.isArray(plans) || plans.length === 0) {
      throw new Error('No lesson plans returned');
    }
    const sample = plans[0];
    firstLessonPlanId = sample.id;
    if (!sample.topic || typeof sample.plannedHours !== 'number') {
      throw new Error(`Invalid lesson plan schema: ${JSON.stringify(sample)}`);
    }
  });

  await runTest('Linways Academics', 'Update Course Delivery Plan progress', async () => {
    const updateRes = await request(
      'PATCH',
      `/academics/lesson-plans/${firstLessonPlanId}/progress`,
      {
        status: 'IN_PROGRESS',
        conductedHours: 3,
      },
      {
        Authorization: `Bearer ${subjectTeacherToken}`,
        'x-school-id': oakridgeSchoolId,
      },
    );
    if (updateRes.status !== 200) throw new Error(`Expected 200, got ${updateRes.status}: ${JSON.stringify(updateRes.body)}`);
    if (updateRes.body.status !== 'IN_PROGRESS') {
      throw new Error(`Expected status IN_PROGRESS, got ${updateRes.body.status}`);
    }
  });

  await runTest('Linways Academics', 'Fetch and log Faculty Teaching Diary', async () => {
    const getRes = await request('GET', '/academics/teaching-diaries', undefined, {
      Authorization: `Bearer ${subjectTeacherToken}`,
      'x-school-id': oakridgeSchoolId,
    });
    if (getRes.status !== 200) throw new Error(`Expected 200, got ${getRes.status}`);
    if (!Array.isArray(getRes.body)) throw new Error('Expected array of diary entries');

    // Create a new diary log
    const postRes = await request(
      'POST',
      '/academics/teaching-diaries',
      {
        topicCovered: 'Quadratic Formula Proof & Worked Examples',
        teachingMethod: 'Interactive Whiteboard & Group Problem Solving',
        homeworkGiven: 'Exercise 4.2 Questions 1 to 8',
        remarks: 'Class participated enthusiastically, all students grasped discriminant formula',
      },
      {
        Authorization: `Bearer ${subjectTeacherToken}`,
        'x-school-id': oakridgeSchoolId,
      },
    );
    if (postRes.status !== 201) throw new Error(`Expected 201, got ${postRes.status}: ${JSON.stringify(postRes.body)}`);
    if (!postRes.body.id) throw new Error('Diary entry ID missing');
  });

  await runTest('Linways Academics', 'Fetch Course Study Materials Repository', async () => {
    const res = await request('GET', '/academics/course-materials', undefined, {
      Authorization: `Bearer ${parentToken}`,
      'x-school-id': oakridgeSchoolId,
    });
    if (res.status !== 200) throw new Error(`Expected 200, got ${res.status}`);
    if (!Array.isArray(res.body) || res.body.length === 0) {
      throw new Error('Expected course materials array');
    }
  });

  await runTest('Linways Academics', 'Calculate Attendance Condonation Shortage Risk (<75%)', async () => {
    const res = await request('GET', '/academics/attendance-analytics', undefined, {
      Authorization: `Bearer ${classTeacherToken}`,
      'x-school-id': oakridgeSchoolId,
    });
    if (res.status !== 200) throw new Error(`Expected 200, got ${res.status}`);
    if (typeof res.body.thresholdPercentage !== 'number' || res.body.thresholdPercentage !== 75) {
      throw new Error(`Expected thresholdPercentage 75, got ${res.body.thresholdPercentage}`);
    }
    if (!Array.isArray(res.body.atRiskStudents)) {
      throw new Error('Missing atRiskStudents array');
    }
  });

  // 5. Parent & Student Portal Workflows
  console.log('\n--- 5. Parent Portal & Online Fee Checkout ---');
  await runTest('Parent Portal', 'Fetch student fee invoices', async () => {
    const res = await request('GET', '/fees/invoices', undefined, {
      Authorization: `Bearer ${parentToken}`,
      'x-school-id': oakridgeSchoolId,
    });
    if (res.status !== 200) throw new Error(`Expected 200, got ${res.status}`);
    if (!Array.isArray(res.body) || res.body.length === 0) {
      throw new Error('Expected at least one invoice for student');
    }
    testInvoiceId = res.body[0].id;
  });

  await runTest('Parent Portal', 'Execute online fee payment simulation', async () => {
    const payRes = await request(
      'POST',
      '/fees/pay',
      {
        invoiceId: testInvoiceId,
        paymentMethod: 'UPI',
        transactionRef: `UPI-TXN-${Date.now()}`,
      },
      {
        Authorization: `Bearer ${parentToken}`,
        'x-school-id': oakridgeSchoolId,
      },
    );
    if (payRes.status !== 200 && payRes.status !== 201) {
      throw new Error(`Payment failed with status ${payRes.status}: ${JSON.stringify(payRes.body)}`);
    }
    if (payRes.body.invoice?.status !== 'PAID' && payRes.body.status !== 'PAID') {
      throw new Error(`Expected invoice status PAID, got ${payRes.body.invoice?.status || payRes.body.status}`);
    }
    if (!payRes.body.receiptNo) {
      throw new Error('Missing digital receiptNo');
    }
  });

  // 6. Multi-Tenant Security & Defensive Tests
  console.log('\n--- 6. Multi-Tenant Security & Defensive Tests ---');
  await runTest('Tenant Isolation', 'Reject unauthenticated access to protected routes (AUTH-01)', async () => {
    const res = await request('GET', '/platform/stats');
    if (res.status !== 401) {
      throw new Error(`Expected 401 Unauthorized, got ${res.status}`);
    }
  });

  await runTest('Tenant Isolation', 'Reject non-platform role access to platform control plane (AUTH-02)', async () => {
    const res = await request('GET', '/platform/stats', undefined, {
      Authorization: `Bearer ${parentToken}`,
    });
    if (res.status !== 403) {
      throw new Error(`Expected 403 Forbidden, got ${res.status}`);
    }
  });

  await runTest('Tenant Isolation', 'Verify Tenant Scoping Headers on School Queries (TEN-01)', async () => {
    const res = await request('GET', '/students', undefined, {
      Authorization: `Bearer ${oakridgeAdminToken}`,
      'x-school-id': oakridgeSchoolId,
    });
    if (res.status !== 200) throw new Error(`Expected 200, got ${res.status}`);
    if (!Array.isArray(res.body)) throw new Error('Expected students array');
    for (const student of res.body) {
      if (student.schoolId !== oakridgeSchoolId) {
        throw new Error(`Tenant leak! Student ${student.id} belongs to ${student.schoolId}`);
      }
    }
  });

  // 7. v2.1 Detailed Role Workflows & Parent Fee Acceptance Tests
  console.log('\n--- 7. v2.1 Detailed Role Workflows & Parent Fee Tests ---');
  await runTest('Parent Workflow', 'Resolve linked children via /parent/my-children (PAR-01, PAR-02)', async () => {
    const res = await request('GET', '/parent/my-children', undefined, {
      Authorization: `Bearer ${parentToken}`,
      'x-school-id': oakridgeSchoolId,
    });
    if (res.status !== 200) throw new Error(`Expected 200, got ${res.status}`);
    if (!Array.isArray(res.body) || res.body.length === 0) {
      throw new Error('Expected at least one linked child for parent');
    }
    const child = res.body[0];
    if (!child.id || !child.admissionNo || !child.currentClass) {
      throw new Error(`Invalid child payload structure: ${JSON.stringify(child)}`);
    }
  });

  await runTest('Parent Fees', 'Retrieve 3-Category Fee Ledger (School, Hostel, Transport) (FEE-01, FEE-02)', async () => {
    const childrenRes = await request('GET', '/parent/my-children', undefined, {
      Authorization: `Bearer ${parentToken}`,
      'x-school-id': oakridgeSchoolId,
    });
    const studentId = childrenRes.body[0].id;

    const res = await request('GET', `/parent/children/${studentId}/fees`, undefined, {
      Authorization: `Bearer ${parentToken}`,
      'x-school-id': oakridgeSchoolId,
    });
    if (res.status !== 200) throw new Error(`Expected 200, got ${res.status}`);
    if (!res.body.summary?.school || !res.body.summary?.hostel || !res.body.summary?.transport) {
      throw new Error(`Expected summary for school, hostel, and transport fees: ${JSON.stringify(res.body.summary)}`);
    }
    if (!res.body.categories?.school) {
      throw new Error('Expected categories.school array');
    }
  });

  await runTest('Class Teacher Workflow', 'Retrieve assigned section roster and leave inbox (MAP-02, LEV-01)', async () => {
    const classRes = await request('GET', '/teacher/my-classes', undefined, {
      Authorization: `Bearer ${classTeacherToken}`,
      'x-school-id': oakridgeSchoolId,
    });
    if (classRes.status !== 200) throw new Error(`Expected 200, got ${classRes.status}`);
    if (!Array.isArray(classRes.body.assignedSections) || classRes.body.assignedSections.length === 0) {
      throw new Error('Expected assigned sections for class teacher');
    }

    const inboxRes = await request('GET', '/leave-requests/inbox', undefined, {
      Authorization: `Bearer ${classTeacherToken}`,
      'x-school-id': oakridgeSchoolId,
    });
    if (inboxRes.status !== 200) throw new Error(`Expected 200, got ${inboxRes.status}`);
  });

  await runTest('Receipts & Audit', 'Retrieve serialized official fee receipt (REC-01)', async () => {
    const res = await request('GET', '/receipts/REC-2026-00084', undefined, {
      Authorization: `Bearer ${parentToken}`,
      'x-school-id': oakridgeSchoolId,
    });
    if (res.status !== 200) throw new Error(`Expected 200, got ${res.status}`);
    if (!res.body.receiptNo || !res.body.feeDetails?.digitalSignature) {
      throw new Error(`Receipt missing serial or signature: ${JSON.stringify(res.body)}`);
    }
  });

  await runTest('Notifications', 'Access notification inbox and unread count (NOT-01, NOT-02)', async () => {
    const res = await request('GET', '/notifications', undefined, {
      Authorization: `Bearer ${parentToken}`,
      'x-school-id': oakridgeSchoolId,
    });
    if (res.status !== 200) throw new Error(`Expected 200, got ${res.status}`);
    if (typeof res.body.unreadCount !== 'number' || !Array.isArray(res.body.notifications)) {
      throw new Error(`Invalid notifications payload: ${JSON.stringify(res.body)}`);
    }
  });

  // Summary Report
  console.log('\n===============================================================');
  console.log('                     TEST RESULTS SUMMARY                      ');
  console.log('===============================================================');
  const passedCount = results.filter((r) => r.passed).length;
  const failedCount = results.filter((r) => !r.passed).length;

  console.log(`Total Tests Run : ${results.length}`);
  console.log(`Passed          : ${passedCount}`);
  console.log(`Failed          : ${failedCount}`);
  console.log(`Success Rate    : ${((passedCount / results.length) * 100).toFixed(1)}%\n`);

  if (failedCount > 0) {
    console.error('Failed tests details:');
    for (const failure of results.filter((r) => !r.passed)) {
      console.error(`- [${failure.suite}] ${failure.testName}: ${failure.error}`);
    }
    process.exit(1);
  } else {
    console.log('🏆 ALL E2E AND LINWAYS AMS SUITES PASSED FLAWLESSLY!');
    process.exit(0);
  }
}

main().catch((err) => {
  console.error('Fatal test execution error:', err);
  process.exit(1);
});
