const http = require('node:http');

// Helper for making HTTP requests
function request(options, body) {
  return new Promise((resolve, reject) => {
    const req = http.request(options, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        try {
          resolve({ status: res.statusCode, data: JSON.parse(data) });
        } catch {
          resolve({ status: res.statusCode, data });
        }
      });
    });
    req.on('error', reject);
    if (body) req.write(typeof body === 'string' ? body : JSON.stringify(body));
    req.end();
  });
}

async function runTests() {
  console.log('🧪 Starting NoteForge Backend Verification Tests...\n');

  // Start server
  require('./server.js');
  await new Promise(r => setTimeout(r, 600));

  let passed = 0;
  let failed = 0;

  function assert(condition, testName) {
    if (condition) {
      console.log(`✅ [PASS] ${testName}`);
      passed++;
    } else {
      console.error(`❌ [FAIL] ${testName}`);
      failed++;
    }
  }

  try {
    // 1. Health check
    const health = await request({ host: '127.0.0.1', port: 5000, path: '/health', method: 'GET' });
    assert(health.status === 200 && health.data.status === 'ok', 'Health Check Endpoint /health');

    // 2. User registration
    const testEmail = `student_${Date.now()}@noteforge.edu`;
    const reg = await request(
      {
        host: '127.0.0.1',
        port: 5000,
        path: '/api/auth/register',
        method: 'POST',
        headers: { 'Content-Type': 'application/json' }
      },
      { name: 'Test Student', email: testEmail, password: 'password123' }
    );
    assert(reg.status === 201 && reg.data.token, 'User Registration & JWT Generation');
    const token = reg.data.token;

    // 3. User login
    const login = await request(
      {
        host: '127.0.0.1',
        port: 5000,
        path: '/api/auth/login',
        method: 'POST',
        headers: { 'Content-Type': 'application/json' }
      },
      { email: testEmail, password: 'password123' }
    );
    assert(login.status === 200 && login.data.token, 'User Login & Authentication');

    // 4. Create Note via API
    const note = await request(
      {
        host: '127.0.0.1',
        port: 5000,
        path: '/api/notes',
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${token}`
        }
      },
      { title: 'Algorithms Lecture Notes', content: 'Big-O notation notes', plainText: 'Big-O notation notes' }
    );
    assert(note.status === 201 && note.data.noteId, 'Create Cloud Note in Database');

    // 5. Fetch Notes
    const notesList = await request({
      host: '127.0.0.1',
      port: 5000,
      path: '/api/notes',
      method: 'GET',
      headers: { 'Authorization': `Bearer ${token}` }
    });
    assert(notesList.status === 200 && notesList.data.notes.length >= 1, 'Fetch User Notes from Database');

    // 6. Test Two-Way Sync Push
    const syncPush = await request(
      {
        host: '127.0.0.1',
        port: 5000,
        path: '/api/sync/push',
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${token}`
        }
      },
      {
        folders: [{ id: 'f_test_1', name: 'Computer Science', color: 4288585374 }],
        tags: [{ id: 't_test_1', name: 'Exam Prep', color: 4288585374 }],
        notes: [{ id: 'n_sync_1', title: 'Calculus III Notes', content: 'Partial derivatives', plainText: 'Partial derivatives' }]
      }
    );
    assert(syncPush.status === 200 && syncPush.data.success, 'Two-Way Sync Push Batch to Database');

    // 7. Test Two-Way Sync Pull
    const syncPull = await request({
      host: '127.0.0.1',
      port: 5000,
      path: '/api/sync/pull',
      method: 'GET',
      headers: { 'Authorization': `Bearer ${token}` }
    });
    assert(syncPull.status === 200 && syncPull.data.data.folders.length >= 1 && syncPull.data.data.notes.length >= 2, 'Two-Way Sync Pull Batch from Database');

    // 8. Test Two-Way Sync Deletion
    const syncDelete = await request(
      {
        host: '127.0.0.1',
        port: 5000,
        path: '/api/sync/push',
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${token}`
        }
      },
      {
        deletedNoteIds: ['n_sync_1']
      }
    );
    assert(syncDelete.status === 200 && syncDelete.data.success, 'Sync Deletion Batch to Database');

    // 9. Verify Deletion in Pull
    const syncPullAfterDelete = await request({
      host: '127.0.0.1',
      port: 5000,
      path: '/api/sync/pull',
      method: 'GET',
      headers: { 'Authorization': `Bearer ${token}` }
    });
    assert(
      syncPullAfterDelete.status === 200 &&
      syncPullAfterDelete.data.data.deletedNoteIds &&
      syncPullAfterDelete.data.data.deletedNoteIds.includes('n_sync_1') &&
      !syncPullAfterDelete.data.data.notes.some(n => n.id === 'n_sync_1'),
      'Sync Pull Confirms Deleted Note Removed'
    );

    console.log(`\n🎉 Results: ${passed} Passed, ${failed} Failed.`);
    process.exit(failed > 0 ? 1 : 0);
  } catch (err) {
    console.error('Test execution error:', err);
    process.exit(1);
  }
}

runTests();

