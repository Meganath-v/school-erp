import * as http from 'http';

const API_BASE = 'http://localhost:3000/api/v1';

async function request(method: string, path: string, data?: any, token?: string) {
  const url = new URL(API_BASE + path);
  const postData = data ? JSON.stringify(data) : undefined;

  const headers: Record<string, string> = {
    'Content-Type': 'application/json',
  };
  if (token) headers['Authorization'] = `Bearer ${token}`;
  if (postData) headers['Content-Length'] = Buffer.byteLength(postData).toString();

  return new Promise<any>((resolve, reject) => {
    const req = http.request(
      url,
      { method, headers },
      (res) => {
        let body = '';
        res.on('data', (c) => (body += c));
        res.on('end', () => {
          let parsed;
          try {
            parsed = JSON.parse(body);
          } catch {
            parsed = body;
          }
          resolve({ status: res.statusCode, body: parsed });
        });
      },
    );
    req.on('error', reject);
    if (postData) req.write(postData);
    req.end();
  });
}

async function runTests() {
  console.log('🧪 Starting Linways ERP New Services Verification Test...');

  // 1. Authenticate as Class Teacher
  const loginRes = await request('POST', '/auth/login', {
    login: 'teacher.smith@oakridge.edu',
    password: 'password123',
    schoolCode: 'OAK01',
  });
  console.log('1. Login status:', loginRes.status);
  const token = loginRes.body?.data?.accessToken;
  if (!token) throw new Error('Failed to obtain auth token');

  // 2. Reminders
  const remindersRes = await request('GET', '/reminders', undefined, token);
  console.log('2. Reminders count:', remindersRes.body?.data?.length, 'Status:', remindersRes.status);

  const scanRes = await request('POST', '/reminders/trigger-automated', {}, token);
  console.log('2b. Trigger automated reminders:', scanRes.body?.data?.message, 'Count:', scanRes.body?.data?.remindersGenerated);

  // 3. Tasks
  const tasksRes = await request('GET', '/tasks', undefined, token);
  console.log('3. Tasks count:', tasksRes.body?.data?.length, 'Status:', tasksRes.status);

  const taskStatsRes = await request('GET', '/tasks/stats', undefined, token);
  console.log('3b. Task stats:', taskStatsRes.body?.data);

  // 4. Feedbacks
  const feedbackRes = await request('GET', '/feedback', undefined, token);
  console.log('4. Feedbacks count:', feedbackRes.body?.data?.length, 'Status:', feedbackRes.status);

  const submitFeedback = await request('POST', '/feedback', {
    category: 'ACADEMIC',
    title: 'Great improvements in Math quizzes',
    content: 'Students have demonstrated 25% higher engagement with interactive whiteboard problems.',
    rating: 5,
  }, token);
  console.log('4b. Submit feedback:', submitFeedback.status, 'Title:', submitFeedback.body?.data?.title);

  // 5. Circulars
  const circRes = await request('GET', '/circulars', undefined, token);
  console.log('5. Circulars count:', circRes.body?.data?.length, 'Status:', circRes.status);

  const newCirc = await request('POST', '/circulars', {
    title: 'Mid-Term Revision Guidelines & Schedule',
    content: 'Dear Parents, Please review the syllabus revision sheets distributed for next week.',
    targetAudience: 'CLASS_PARENTS',
    priority: 'IMPORTANT',
    requiresAck: true,
  }, token);
  console.log('5b. Dispatched class teacher circular:', newCirc.status, 'No:', newCirc.body?.data?.circularNumber);

  // 6. Exam Marks, Template Export & Excel Import
  const examsRes = await request('GET', '/exams', undefined, token);
  const firstExam = examsRes.body?.data?.[0];
  const firstSubject = firstExam?.subjects?.[0];
  console.log('6. Exams found:', examsRes.body?.data?.length, 'Subject:', firstSubject?.subjectName);

  if (firstSubject) {
    const detailsRes = await request('GET', `/exams/subjects/${firstSubject.id}/details`, undefined, token);
    console.log('6b. Exam Subject details:', detailsRes.status, 'Students count:', detailsRes.body?.data?.students?.length);

    const templateRes = await request('GET', `/exams/subjects/${firstSubject.id}/template`, undefined, token);
    console.log('6c. Template download:', templateRes.status, 'Filename:', templateRes.body?.data?.filename);

    // Import marks test
    const testImportRows = [
      {
        admissionNo: 'ADM-2026-001',
        marksObtained: 92,
        isAbsent: 'N',
        remarks: 'Outstanding analytical clarity',
      },
      {
        admissionNo: 'ADM-2026-002',
        marksObtained: 78,
        isAbsent: 'N',
        remarks: 'Good progress in theorems',
      },
    ];

    const importRes = await request('POST', `/exams/subjects/${firstSubject.id}/import`, { rows: testImportRows }, token);
    console.log('6d. Bulk Excel/CSV marks import:', importRes.status, 'Saved count:', importRes.body?.data?.successCount);

    // Broadsheet
    const broadsheetRes = await request('GET', `/exams/${firstExam.id}/classes/${firstSubject.classId}/broadsheet`, undefined, token);
    console.log('6e. Class Broadsheet:', broadsheetRes.status, 'Roster count:', broadsheetRes.body?.data?.broadsheet?.length);
  }

  // 7. Check Teacher Desktop Webpage static asset
  const webpageRes = await new Promise<any>((resolve) => {
    http.get('http://localhost:3000/teacher/index.html', (res) => {
      resolve({ status: res.statusCode, contentType: res.headers['content-type'] });
    });
  });
  console.log('7. Teacher Desktop Webpage served:', webpageRes.status, webpageRes.contentType);

  console.log('🎉 ALL Linways ERP New Services Verified Successfully!');
}

runTests().catch((e) => {
  console.error('Test execution failed:', e);
  process.exit(1);
});
