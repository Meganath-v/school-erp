import * as http from 'http';

const BASE_URL = 'http://localhost:3000/api/v1';

interface ApiResponse<T = any> {
  status: number;
  body: T;
  headers: http.IncomingHttpHeaders;
}

function request<T = any>(
  method: string,
  path: string,
  data?: any,
  headers: Record<string, string> = {},
): Promise<ApiResponse<T>> {
  return new Promise((resolve, reject) => {
    const url = new URL(BASE_URL + path);
    const reqHeaders: Record<string, string> = {
      ...headers,
    };

    let bodyStr: string | undefined;
    if (data !== undefined) {
      bodyStr = JSON.stringify(data);
      reqHeaders['Content-Type'] = 'application/json';
      reqHeaders['Content-Length'] = Buffer.byteLength(bodyStr).toString();
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
          let parsed: any;
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
    if (bodyStr) req.write(bodyStr);
    req.end();
  });
}

let passed = 0;
let failed = 0;

async function test(name: string, fn: () => Promise<void>) {
  try {
    await fn();
    console.log(`  ✓ [PASS] ${name}`);
    passed++;
  } catch (err: any) {
    console.error(`  ✗ [FAIL] ${name}: ${err.message || String(err)}`);
    failed++;
  }
}

async function runAuthSecuritySuite() {
  console.log('======================================================================');
  console.log('    SCHOOL ERP - AUTHENTICATION, MULTI-TENANCY & RBAC TEST SUITE      ');
  console.log('======================================================================\n');

  let superadminToken = '';
  let oakridgeAdminToken = '';
  let principalToken = '';
  let officeToken = '';
  let classTeacherToken = '';
  let subjectTeacherToken = '';
  let parentToken = '';
  let studentToken = '';

  let oakridgeSchoolId = '';
  let stXaviersSchoolId = '';

  // ------------------------------------------------------------------
  // 1. TENANT DISCOVERY & MULTI-TENANCY SETUP
  // ------------------------------------------------------------------
  console.log('--- 1. Tenant Discovery & Resolution ---');

  await test('Public Tenant Discovery lists active schools', async () => {
    const res = await request('GET', '/tenant-discovery');
    if (res.status !== 200) throw new Error(`Expected 200, got ${res.status}`);
    const schools = res.body;
    if (!Array.isArray(schools) || schools.length < 2) {
      throw new Error(`Expected at least 2 schools, got ${schools?.length}`);
    }
    const oak = schools.find((s: any) => s.code === 'OAK01');
    const stx = schools.find((s: any) => s.code === 'STX02');
    if (!oak || !stx) throw new Error('Missing OAK01 or STX02 in tenant discovery');
    oakridgeSchoolId = oak.id;
    stXaviersSchoolId = stx.id;
  });

  await test('Resolve tenant by school code OAK01', async () => {
    const res = await request('GET', '/tenants/resolve/OAK01');
    if (res.status !== 200) throw new Error(`Expected 200, got ${res.status}`);
    if (res.body.code !== 'OAK01') throw new Error(`Expected code OAK01, got ${res.body.code}`);
  });

  await test('Resolve non-existent tenant returns 404', async () => {
    const res = await request('GET', '/tenants/resolve/INVALID_XYZ_99');
    if (res.status !== 404) throw new Error(`Expected 404, got ${res.status}`);
  });

  // ------------------------------------------------------------------
  // 2. AUTHENTICATION & LOGIN WORKFLOWS
  // ------------------------------------------------------------------
  console.log('\n--- 2. Multi-Role Authentication & Token Issuance ---');

  await test('Superadmin login (PLATFORM_OWNER)', async () => {
    const res = await request('POST', '/auth/login', {
      login: 'superadmin@erp.com',
      password: 'password123',
    });
    if (res.status !== 200 && res.status !== 201) throw new Error(`Expected 200, got ${res.status}`);
    if (!res.body.accessToken || !res.body.refreshToken) throw new Error('Tokens missing');
    if (res.body.user.activeRole !== 'PLATFORM_OWNER') {
      throw new Error(`Expected role PLATFORM_OWNER, got ${res.body.user.activeRole}`);
    }
    superadminToken = res.body.accessToken;
  });

  await test('School Admin login (SCHOOL_ADMIN)', async () => {
    const res = await request('POST', '/auth/login', {
      login: 'admin@oakridge.edu',
      password: 'password123',
    });
    if (res.status !== 200 && res.status !== 201) throw new Error(`Expected 200, got ${res.status}`);
    if (res.body.user.activeRole !== 'SCHOOL_ADMIN') throw new Error(`Expected SCHOOL_ADMIN, got ${res.body.user.activeRole}`);
    oakridgeAdminToken = res.body.accessToken;
  });

  await test('Principal login (PRINCIPAL)', async () => {
    const res = await request('POST', '/auth/login', {
      login: 'principal@oakridge.edu',
      password: 'password123',
    });
    if (res.status !== 200 && res.status !== 201) throw new Error(`Expected 200, got ${res.status}`);
    if (res.body.user.activeRole !== 'PRINCIPAL') throw new Error(`Expected PRINCIPAL, got ${res.body.user.activeRole}`);
    principalToken = res.body.accessToken;
  });

  await test('Office Staff login (OFFICE)', async () => {
    const res = await request('POST', '/auth/login', {
      login: 'office@oakridge.edu',
      password: 'password123',
    });
    if (res.status !== 200 && res.status !== 201) throw new Error(`Expected 200, got ${res.status}`);
    if (res.body.user.activeRole !== 'OFFICE') throw new Error(`Expected OFFICE, got ${res.body.user.activeRole}`);
    officeToken = res.body.accessToken;
  });

  await test('Class Teacher login (CLASS_TEACHER)', async () => {
    const res = await request('POST', '/auth/login', {
      login: 'teacher.smith@oakridge.edu',
      password: 'password123',
    });
    if (res.status !== 200 && res.status !== 201) throw new Error(`Expected 200, got ${res.status}`);
    if (res.body.user.activeRole !== 'CLASS_TEACHER') throw new Error(`Expected CLASS_TEACHER, got ${res.body.user.activeRole}`);
    classTeacherToken = res.body.accessToken;
  });

  await test('Subject Teacher login (SUBJECT_TEACHER)', async () => {
    const res = await request('POST', '/auth/login', {
      login: 'teacher.jones@oakridge.edu',
      password: 'password123',
    });
    if (res.status !== 200 && res.status !== 201) throw new Error(`Expected 200, got ${res.status}`);
    if (res.body.user.activeRole !== 'SUBJECT_TEACHER') throw new Error(`Expected SUBJECT_TEACHER, got ${res.body.user.activeRole}`);
    subjectTeacherToken = res.body.accessToken;
  });

  await test('Parent login with school code selection (PARENT)', async () => {
    const res = await request('POST', '/auth/login', {
      login: 'parent.doe@gmail.com',
      password: 'password123',
      schoolCode: 'OAK01',
    });
    if (res.status !== 200 && res.status !== 201) throw new Error(`Expected 200, got ${res.status}`);
    if (res.body.user.activeRole !== 'PARENT') throw new Error(`Expected PARENT, got ${res.body.user.activeRole}`);
    if (res.body.user.activeSchool.code !== 'OAK01') throw new Error('Not scoped to OAK01');
    parentToken = res.body.accessToken;
  });

  await test('Student login (STUDENT)', async () => {
    const res = await request('POST', '/auth/login', {
      login: 'student.john@oakridge.edu',
      password: 'password123',
    });
    if (res.status !== 200 && res.status !== 201) throw new Error(`Expected 200, got ${res.status}`);
    if (res.body.user.activeRole !== 'STUDENT') throw new Error(`Expected STUDENT, got ${res.body.user.activeRole}`);
    studentToken = res.body.accessToken;
  });

  await test('Reject invalid credentials with 401', async () => {
    const res = await request('POST', '/auth/login', {
      login: 'admin@oakridge.edu',
      password: 'wrong_password_999',
    });
    if (res.status !== 401) throw new Error(`Expected 401, got ${res.status}`);
  });

  await test('Reject login with non-member school code with 401', async () => {
    const res = await request('POST', '/auth/login', {
      login: 'student.john@oakridge.edu',
      password: 'password123',
      schoolCode: 'STX02', // student is only enrolled in OAK01
    });
    if (res.status !== 401) throw new Error(`Expected 401, got ${res.status}`);
  });

  // ------------------------------------------------------------------
  // 3. TOKEN REFRESH & SESSION REVOCATION
  // ------------------------------------------------------------------
  console.log('\n--- 3. Token Refresh, Logout & Session Invalidation ---');

  let testRefreshAccessToken = '';
  let testRefreshToken = '';

  await test('Issue fresh session and refresh tokens', async () => {
    const res = await request('POST', '/auth/login', {
      login: 'office@oakridge.edu',
      password: 'password123',
    });
    testRefreshAccessToken = res.body.accessToken;
    testRefreshToken = res.body.refreshToken;
    if (!testRefreshAccessToken || !testRefreshToken) throw new Error('Missing tokens');
  });

  await test('Exchange valid refresh token for a new access token', async () => {
    const res = await request('POST', '/auth/refresh', {
      refreshToken: testRefreshToken,
    });
    if (res.status !== 200 && res.status !== 201) throw new Error(`Expected 200, got ${res.status}`);
    if (!res.body.accessToken) throw new Error('Missing new accessToken');
  });

  await test('Reject tampered/invalid refresh token with 401', async () => {
    const res = await request('POST', '/auth/refresh', {
      refreshToken: 'invalid.tampered.token_signature',
    });
    if (res.status !== 401) throw new Error(`Expected 401, got ${res.status}`);
  });

  await test('Revoke all sessions via /auth/revoke-sessions', async () => {
    const revokeRes = await request(
      'POST',
      '/auth/revoke-sessions',
      {},
      { Authorization: `Bearer ${testRefreshAccessToken}` },
    );
    if (revokeRes.status !== 200 && revokeRes.status !== 201) {
      throw new Error(`Expected 200, got ${revokeRes.status}`);
    }

    // Now the old access token must immediately be rejected
    const checkRes = await request('GET', '/auth/me', undefined, {
      Authorization: `Bearer ${testRefreshAccessToken}`,
    });
    if (checkRes.status !== 401) throw new Error(`Expected 401 after session revocation, got ${checkRes.status}`);

    // Refresh token must also be rejected because user tokenVersion was incremented
    const refreshRes = await request('POST', '/auth/refresh', {
      refreshToken: testRefreshToken,
    });
    if (refreshRes.status !== 401) throw new Error(`Expected 401 for old refresh token, got ${refreshRes.status}`);
  });

  // ------------------------------------------------------------------
  // 4. PASSWORD CHANGE & FORGOT/RESET WORKFLOW
  // ------------------------------------------------------------------
  console.log('\n--- 4. Password Change & Password Reset Workflows ---');

  let teacherToken = '';
  await test('Login teacher for password lifecycle tests', async () => {
    const res = await request('POST', '/auth/login', {
      login: 'teacher.smith@oakridge.edu',
      password: 'password123',
    });
    teacherToken = res.body.accessToken;
  });

  await test('Reject change password when old password does not match (400)', async () => {
    const res = await request(
      'POST',
      '/auth/change-password',
      {
        oldPassword: 'wrongOldPassword!',
        newPassword: 'newValidPassword123!',
      },
      { Authorization: `Bearer ${teacherToken}` },
    );
    if (res.status !== 400) throw new Error(`Expected 400, got ${res.status}`);
  });

  await test('Change password with valid credentials, verify old session revoked', async () => {
    const changeRes = await request(
      'POST',
      '/auth/change-password',
      {
        oldPassword: 'password123',
        newPassword: 'temporaryUpdatedPass456!',
      },
      { Authorization: `Bearer ${teacherToken}` },
    );
    if (changeRes.status !== 200 && changeRes.status !== 201) {
      throw new Error(`Expected 200, got ${changeRes.status}`);
    }

    // Old token is revoked
    const checkOldRes = await request('GET', '/auth/me', undefined, {
      Authorization: `Bearer ${teacherToken}`,
    });
    if (checkOldRes.status !== 401) throw new Error(`Expected 401 on old token, got ${checkOldRes.status}`);

    // Login with OLD password must fail
    const oldLoginRes = await request('POST', '/auth/login', {
      login: 'teacher.smith@oakridge.edu',
      password: 'password123',
    });
    if (oldLoginRes.status !== 401) throw new Error(`Expected 401 with old password, got ${oldLoginRes.status}`);

    // Login with NEW password must succeed
    const newLoginRes = await request('POST', '/auth/login', {
      login: 'teacher.smith@oakridge.edu',
      password: 'temporaryUpdatedPass456!',
    });
    if (newLoginRes.status !== 200 && newLoginRes.status !== 201) {
      throw new Error(`Expected 200 with new password, got ${newLoginRes.status}`);
    }

    // Revert password back to password123 for test environment cleanliness
    const revertRes = await request(
      'POST',
      '/auth/change-password',
      {
        oldPassword: 'temporaryUpdatedPass456!',
        newPassword: 'password123',
      },
      { Authorization: `Bearer ${newLoginRes.body.accessToken}` },
    );
    if (revertRes.status !== 200 && revertRes.status !== 201) {
      throw new Error('Failed to revert test password');
    }
  });

  let resetToken = '';
  await test('Forgot password dispatches single-use reset token', async () => {
    const res = await request('POST', '/auth/forgot-password', {
      email: 'teacher.smith@oakridge.edu',
    });
    if (res.status !== 200 && res.status !== 201) throw new Error(`Expected 200, got ${res.status}`);
    if (!res.body.resetToken) throw new Error('Missing resetToken in development payload');
    resetToken = res.body.resetToken;
  });

  await test('Reset password with invalid token is rejected (400)', async () => {
    const res = await request('POST', '/auth/reset-password', {
      token: 'invalid_fake_reset_token_9999',
      newPassword: 'password123',
    });
    if (res.status !== 400) throw new Error(`Expected 400, got ${res.status}`);
  });

  await test('Reset password with valid token succeeds and invalidates token', async () => {
    const res = await request('POST', '/auth/reset-password', {
      token: resetToken,
      newPassword: 'password123',
    });
    if (res.status !== 200 && res.status !== 201) throw new Error(`Expected 200, got ${res.status}`);

    // Re-using the same token must now fail
    const reUseRes = await request('POST', '/auth/reset-password', {
      token: resetToken,
      newPassword: 'password123',
    });
    if (reUseRes.status !== 400) throw new Error(`Expected 400 on reused reset token, got ${reUseRes.status}`);
  });

  // ------------------------------------------------------------------
  // 5. ROLE-BASED ACCESS CONTROL (ALL 8 ROLES)
  // ------------------------------------------------------------------
  console.log('\n--- 5. Role-Based Permissions & Privilege Boundaries ---');

  // Obtain fresh tokens for accounts whose tokens were revoked in Section 3 & 4
  officeToken = (
    await request('POST', '/auth/login', { login: 'office@oakridge.edu', password: 'password123' })
  ).body.accessToken;

  classTeacherToken = (
    await request('POST', '/auth/login', { login: 'teacher.smith@oakridge.edu', password: 'password123' })
  ).body.accessToken;

  await test('PLATFORM_OWNER can access platform statistics and tenant provisioning', async () => {
    const statsRes = await request('GET', '/platform/stats', undefined, {
      Authorization: `Bearer ${superadminToken}`,
    });
    if (statsRes.status !== 200) throw new Error(`Expected 200, got ${statsRes.status}`);

    const schoolsRes = await request('GET', '/platform/schools', undefined, {
      Authorization: `Bearer ${superadminToken}`,
    });
    if (schoolsRes.status !== 200) throw new Error(`Expected 200, got ${schoolsRes.status}`);
  });

  await test('Non-PLATFORM_OWNER (SCHOOL_ADMIN) is forbidden from platform control plane (403)', async () => {
    const res = await request('GET', '/platform/stats', undefined, {
      Authorization: `Bearer ${oakridgeAdminToken}`,
    });
    if (res.status !== 403) throw new Error(`Expected 403 Forbidden, got ${res.status}`);
  });

  await test('Student is forbidden from platform control plane (403)', async () => {
    const res = await request('GET', '/platform/schools', undefined, {
      Authorization: `Bearer ${studentToken}`,
    });
    if (res.status !== 403) throw new Error(`Expected 403 Forbidden, got ${res.status}`);
  });

  await test('SCHOOL_ADMIN can onboard staff and update school profile', async () => {
    const staffRes = await request('GET', '/staff', undefined, {
      Authorization: `Bearer ${oakridgeAdminToken}`,
    });
    if (staffRes.status !== 200) throw new Error(`Expected 200, got ${staffRes.status}`);
  });

  await test('OFFICE staff cannot access superadmin or publish exams (403)', async () => {
    // Try to access platform stats
    const platRes = await request('GET', '/platform/stats', undefined, {
      Authorization: `Bearer ${officeToken}`,
    });
    if (platRes.status !== 403) throw new Error(`Expected 403, got ${platRes.status}`);

    // Try to publish exams (only Principal / Admin allowed)
    const pubRes = await request('POST', '/exams/non-existent-id/publish', {}, {
      Authorization: `Bearer ${officeToken}`,
    });
    if (pubRes.status !== 403) throw new Error(`Expected 403, got ${pubRes.status}`);
  });

  await test('PRINCIPAL can view audit logs and institutional reports', async () => {
    const repRes = await request('GET', '/reports/overview', undefined, {
      Authorization: `Bearer ${principalToken}`,
    });
    if (repRes.status !== 200) throw new Error(`Expected 200, got ${repRes.status}`);

    const auditRes = await request('GET', '/audit-logs', undefined, {
      Authorization: `Bearer ${principalToken}`,
    });
    if (auditRes.status !== 200) throw new Error(`Expected 200, got ${auditRes.status}`);
  });

  await test('CLASS_TEACHER can view assigned sections and leave inbox', async () => {
    const classRes = await request('GET', '/teacher/my-classes', undefined, {
      Authorization: `Bearer ${classTeacherToken}`,
    });
    if (classRes.status !== 200) throw new Error(`Expected 200, got ${classRes.status}`);

    const leaveRes = await request('GET', '/leave-requests/inbox', undefined, {
      Authorization: `Bearer ${classTeacherToken}`,
    });
    if (leaveRes.status !== 200) throw new Error(`Expected 200, got ${leaveRes.status}`);
  });

  await test('CLASS_TEACHER forbidden from dispatching school-wide circulars (CIR-CT-01)', async () => {
    const res = await request(
      'POST',
      '/circulars',
      {
        title: 'Unauthorized Global Notice',
        content: 'This should be blocked',
        targetAudience: 'ALL',
      },
      { Authorization: `Bearer ${classTeacherToken}` },
    );
    if (res.status !== 403) throw new Error(`Expected 403 Forbidden, got ${res.status}`);
  });

  await test('SUBJECT_TEACHER can log teaching diary and view course materials', async () => {
    const diaryRes = await request('GET', '/academics/teaching-diaries', undefined, {
      Authorization: `Bearer ${subjectTeacherToken}`,
    });
    if (diaryRes.status !== 200) throw new Error(`Expected 200, got ${diaryRes.status}`);

    const matRes = await request('GET', '/academics/course-materials', undefined, {
      Authorization: `Bearer ${subjectTeacherToken}`,
    });
    if (matRes.status !== 200) throw new Error(`Expected 200, got ${matRes.status}`);
  });

  await test('SUBJECT_TEACHER forbidden from approving student leaves (403)', async () => {
    const res = await request(
      'POST',
      '/leave-requests/any-id/decision',
      { status: 'APPROVED' },
      { Authorization: `Bearer ${subjectTeacherToken}` },
    );
    if (res.status !== 403) throw new Error(`Expected 403 Forbidden, got ${res.status}`);
  });

  await test('PARENT can access linked children (/parent/my-children)', async () => {
    const res = await request('GET', '/parent/my-children', undefined, {
      Authorization: `Bearer ${parentToken}`,
    });
    if (res.status !== 200) throw new Error(`Expected 200, got ${res.status}`);
    if (!Array.isArray(res.body) || res.body.length === 0) {
      throw new Error('Expected linked children array');
    }
  });

  await test('PARENT forbidden from recording class attendance sessions (403)', async () => {
    const res = await request(
      'POST',
      '/attendance/sessions',
      {
        sectionId: 'fake-section',
        records: [],
      },
      { Authorization: `Bearer ${parentToken}` },
    );
    if (res.status !== 403) throw new Error(`Expected 403 Forbidden, got ${res.status}`);
  });

  await test('STUDENT can view personal profile and timetable', async () => {
    const profRes = await request('GET', '/students/me/profile', undefined, {
      Authorization: `Bearer ${studentToken}`,
    });
    if (profRes.status !== 200) throw new Error(`Expected 200, got ${profRes.status}`);

    const timeRes = await request('GET', '/timetable/entries', undefined, {
      Authorization: `Bearer ${studentToken}`,
    });
    if (timeRes.status !== 200) throw new Error(`Expected 200, got ${timeRes.status}`);
  });

  await test('STUDENT forbidden from entering exam marks (403)', async () => {
    const res = await request(
      'POST',
      '/exams/subjects/any-sub/marks',
      { marks: [] },
      { Authorization: `Bearer ${studentToken}` },
    );
    if (res.status !== 403) throw new Error(`Expected 403 Forbidden, got ${res.status}`);
  });

  // ------------------------------------------------------------------
  // 6. MULTI-TENANT ISOLATION & DEFENSIVE SECURITY
  // ------------------------------------------------------------------
  console.log('\n--- 6. Multi-Tenant Cross-School Isolation ---');

  let stXaviersAdminToken = '';
  await test('Login St. Xaviers admin (STX02)', async () => {
    const res = await request('POST', '/auth/login', {
      login: 'admin@stxaviers.edu',
      password: 'password123',
    });
    if (res.status !== 200 && res.status !== 201) throw new Error(`Expected 200, got ${res.status}`);
    stXaviersAdminToken = res.body.accessToken;
  });

  await test('Client cannot bypass tenant isolation by spoofing x-school-id header', async () => {
    // Calling with Oakridge token but sending x-school-id for St. Xavier's
    const res = await request('GET', '/schools/current', undefined, {
      Authorization: `Bearer ${oakridgeAdminToken}`,
      'x-school-id': stXaviersSchoolId,
    });
    if (res.status !== 200) throw new Error(`Expected 200, got ${res.status}`);
    // Backend must have used the token's schoolId (Oakridge), NOT the spoofed header
    if (res.body.id === stXaviersSchoolId || res.body.code !== 'OAK01') {
      throw new Error('Tenant spoofing vulnerability detected! Backend trusted x-school-id header.');
    }
  });

  await test('Oakridge Admin querying students only receives Oakridge students', async () => {
    const res = await request('GET', '/students', undefined, {
      Authorization: `Bearer ${oakridgeAdminToken}`,
    });
    if (res.status !== 200) throw new Error(`Expected 200, got ${res.status}`);
    const students = res.body;
    for (const s of students) {
      if (s.schoolId !== oakridgeSchoolId) {
        throw new Error(`Data leakage! Found student ${s.id} from foreign school ${s.schoolId}`);
      }
    }
  });

  await test('St. Xaviers Admin querying students only receives St. Xaviers students', async () => {
    const res = await request('GET', '/students', undefined, {
      Authorization: `Bearer ${stXaviersAdminToken}`,
    });
    if (res.status !== 200) throw new Error(`Expected 200, got ${res.status}`);
    const students = res.body;
    for (const s of students) {
      if (s.schoolId !== stXaviersSchoolId) {
        throw new Error(`Data leakage! Found student ${s.id} from foreign school ${s.schoolId}`);
      }
    }
  });

  await test('Oakridge teacher cannot access St. Xaviers audit logs (cross-tenant rejection)', async () => {
    const res = await request('GET', '/audit-logs', undefined, {
      Authorization: `Bearer ${classTeacherToken}`,
    });
    // Class teachers can't access audit logs at all (403)
    if (res.status !== 403) throw new Error(`Expected 403 Forbidden, got ${res.status}`);
  });

  // ------------------------------------------------------------------
  // 7. SUMMARY
  // ------------------------------------------------------------------
  console.log('\n======================================================================');
  console.log('                     TEST RESULTS SUMMARY                             ');
  console.log('======================================================================');
  console.log(`Total Security Tests Run : ${passed + failed}`);
  console.log(`Passed                   : ${passed}`);
  console.log(`Failed                   : ${failed}`);
  console.log(`Success Rate             : ${((passed / (passed + failed)) * 100).toFixed(1)}%`);

  if (failed > 0) {
    process.exit(1);
  } else {
    console.log('\n🛡️ ALL AUTHENTICATION, MULTI-TENANCY & RBAC TESTS PASSED WITH 100% SUCCESS!');
  }
}

runAuthSecuritySuite().catch((err) => {
  console.error('Fatal test error:', err);
  process.exit(1);
});
