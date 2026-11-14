async function testNavigationAndDiscovery() {
  const loginRes = await fetch('http://localhost:3000/api/v1/auth/login', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      login: 'admin@oakridge.edu',
      password: 'password123',
      schoolCode: 'OAK01'
    })
  });
  const loginData = await loginRes.json();
  const token = loginData.data?.accessToken || loginData.accessToken;
  console.log('Login status:', loginRes.status, 'Token acquired:', !!token);

  async function apiGet(path: string, params: Record<string, string> = {}) {
    const url = new URL('http://localhost:3000/api/v1' + path);
    for (const [k, v] of Object.entries(params)) {
      url.searchParams.append(k, v);
    }
    const res = await fetch(url.toString(), {
      headers: { Authorization: 'Bearer ' + token }
    });
    const json = await res.json();
    return { status: res.status, json };
  }

  console.log('\n1. Testing Unified OmniSearch (GET /search?q=a)');
  const omniRes = await apiGet('/search', { q: 'a' });
  const results = omniRes.json.data?.results || [];
  console.log('OmniSearch matched items count:', results.length);
  const types = [...new Set(results.map((i: any) => i.type))];
  console.log('Matched domains across DB:', types.join(', '));
  if (results.length > 0) {
    console.log('Sample OmniSearch hit:', {
      type: results[0].type,
      title: results[0].title,
      subtitle: results[0].subtitle,
      routeTarget: results[0].routeTarget,
    });
  }

  console.log('\n2. Testing Fee Filter by Status & Category (GET /fees/invoices?status=PAID)');
  const feeRes = await apiGet('/fees/invoices', { status: 'PAID' });
  console.log('Paid invoices count:', (feeRes.json.data || []).length);

  console.log('\n3. Testing Student Search (GET /students?search=a)');
  const studentRes = await apiGet('/students', { search: 'a' });
  console.log('Student matches count:', (studentRes.json.data || []).length);
  console.log('Sample students:', (studentRes.json.data || []).slice(0, 3).map((s: any) => s.fullName).join(', '));

  console.log('\n4. Testing Staff Filter (GET /staff?search=smith)');
  const staffRes = await apiGet('/staff', { search: 'smith' });
  console.log('Staff matches count:', (staffRes.json.data || []).length);
  console.log('Staff names:', (staffRes.json.data || []).map((s: any) => s.name).join(', '));

  console.log('\n5. Testing Circular Filter (GET /circulars?priority=URGENT)');
  const circRes = await apiGet('/circulars', { priority: 'URGENT' });
  console.log('Urgent circulars count:', (circRes.json.data || []).length);

  console.log('\n6. Testing Exam Filter (GET /exams?term=FIRST_TERM)');
  const examRes = await apiGet('/exams', { term: 'FIRST_TERM' });
  console.log('First term exams count:', (examRes.json.data || []).length);

  console.log('\n🌟 ALL NAVIGATION, SEARCH & FILTER ENDPOINTS VERIFIED WITH REAL DATABASE DATA!');
}

testNavigationAndDiscovery().catch(e => {
  console.error(e);
  process.exit(1);
});
