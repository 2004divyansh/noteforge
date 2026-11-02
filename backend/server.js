require('dotenv').config();
const express = require('express');
const cors = require('cors');
const db = require('./db');

const authRoutes = require('./routes/auth');
const noteRoutes = require('./routes/notes');
const folderRoutes = require('./routes/folders');
const tagRoutes = require('./routes/tags');
const syncRoutes = require('./routes/sync');

const app = express();
const PORT = process.env.PORT || 5000;

// Middleware
app.use(cors());
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// Request Logger
app.use((req, res, next) => {
  const start = Date.now();
  res.on('finish', () => {
    const duration = Date.now() - start;
    console.log(`[${new Date().toISOString()}] ${req.method} ${req.originalUrl} - ${res.statusCode} (${duration}ms)`);
  });
  next();
});

// API Routes
app.use('/api/auth', authRoutes);
app.use('/api/notes', noteRoutes);
app.use('/api/folders', folderRoutes);
app.use('/api/tags', tagRoutes);
app.use('/api/sync', syncRoutes);

// Health Check Endpoint
app.get('/health', (req, res) => {
  try {
    const row = db.prepare('SELECT 1 as alive').get();
    res.json({
      status: 'ok',
      service: 'NoteForge REST API Backend',
      database: row ? 'SQLite (WAL Mode)' : 'Unavailable',
      timestamp: new Date().toISOString()
    });
  } catch (err) {
    res.status(500).json({ status: 'error', error: err.message });
  }
});

// Admin Reset Database Endpoint (Clears all data fresh)
app.post('/api/admin/reset-db', (req, res) => {
  try {
    db.exec(`
      DELETE FROM note_tags;
      DELETE FROM notes;
      DELETE FROM folders;
      DELETE FROM tags;
      DELETE FROM users;
      DELETE FROM deleted_records;
      VACUUM;
    `);
    console.log('🧹 [ADMIN] Database reset successfully. All users, notes, and folders cleared.');
    if (req.headers['accept'] && req.headers['accept'].includes('text/html')) {
      return res.redirect('/?reset=success');
    }
    return res.json({ success: true, message: 'Database reset successfully. All users, notes, and folders cleared.' });
  } catch (err) {
    console.error('Reset database error:', err);
    return res.status(500).json({ success: false, error: 'Failed to reset database: ' + err.message });
  }
});

// Web Dashboard & Live API Documentation
app.get('/', (req, res) => {
  try {
    const userCount = db.prepare('SELECT COUNT(*) as count FROM users').get().count;
    const activeNoteCount = db.prepare('SELECT COUNT(*) as count FROM notes WHERE is_trashed = 0').get().count;
    const trashedNoteCount = db.prepare('SELECT COUNT(*) as count FROM notes WHERE is_trashed = 1').get().count;
    const folderCount = db.prepare('SELECT COUNT(*) as count FROM folders').get().count;
    const tagCount = db.prepare('SELECT COUNT(*) as count FROM tags').get().count;
    const isReset = req.query.reset === 'success';

    res.send(`<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>NoteForge Backend API Dashboard</title>
  <style>
    :root {
      --primary: #FF6B35;
      --bg: #FAF7F2;
      --card: #FFFFFF;
      --border: #E8E2D9;
      --text: #1C1917;
      --muted: #78716C;
      --accent: #16A34A;
    }
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
      background: var(--bg);
      color: var(--text);
      padding: 2.5rem 1.5rem;
      line-height: 1.6;
    }
    .container { max-width: 920px; margin: 0 auto; }
    header { margin-bottom: 2rem; border-bottom: 1px solid var(--border); padding-bottom: 1.5rem; }
    h1 { font-size: 2rem; display: flex; align-items: center; gap: 0.6rem; color: #1C1917; }
    .status-badge {
      display: inline-flex;
      align-items: center;
      gap: 0.4rem;
      background: rgba(22, 163, 74, 0.1);
      color: var(--accent);
      border: 1px solid rgba(22, 163, 74, 0.3);
      padding: 0.3rem 0.85rem;
      border-radius: 20px;
      font-size: 0.85rem;
      font-weight: 600;
    }
    .dot { width: 8px; height: 8px; background: var(--accent); border-radius: 50%; }
    .grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(180px, 1fr)); gap: 1rem; margin-bottom: 2rem; }
    .card { background: var(--card); border: 1px solid var(--border); border-radius: 12px; padding: 1.25rem; box-shadow: 0 4px 12px rgba(0,0,0,0.03); }
    .card-num { font-size: 2rem; font-weight: 800; color: var(--primary); }
    .card-label { font-size: 0.85rem; color: var(--muted); text-transform: uppercase; font-weight: 600; }
    h2 { font-size: 1.3rem; margin-bottom: 1rem; }
    table { width: 100%; border-collapse: collapse; margin-bottom: 2rem; background: var(--card); border-radius: 12px; overflow: hidden; border: 1px solid var(--border); box-shadow: 0 4px 12px rgba(0,0,0,0.03); }
    th, td { padding: 0.85rem 1rem; text-align: left; border-bottom: 1px solid var(--border); font-size: 0.9rem; }
    th { background: #F3ECE2; color: #44403C; font-weight: 700; }
    .method { font-weight: 700; font-family: monospace; font-size: 0.85rem; padding: 0.2rem 0.5rem; border-radius: 4px; }
    .post { background: #E0E7FF; color: #3730A3; }
    .get { background: #DCFCE7; color: #166534; }
    .put { background: #FEF3C7; color: #92400E; }
    .delete { background: #FEE2E2; color: #991B1B; }
    code { font-family: monospace; color: #C2410C; font-weight: 600; }
    .btn-reset {
      background: #EF4444;
      color: #FFFFFF;
      border: none;
      padding: 0.65rem 1.25rem;
      border-radius: 8px;
      font-weight: 700;
      cursor: pointer;
      font-size: 0.9rem;
      transition: background 0.2s;
    }
    .btn-reset:hover { background: #DC2626; }
    .alert-success {
      background: #DCFCE7;
      color: #166534;
      border: 1px solid #86EFAC;
      padding: 0.75rem 1rem;
      border-radius: 8px;
      margin-bottom: 1.5rem;
      font-weight: 600;
    }
  </style>
</head>
<body>
  <div class="container">
    <header>
      <h1>📝 NoteForge Cloud Backend</h1>
      <p style="color: var(--muted); margin: 0.5rem 0 1rem;">
        Integrated Cloud REST API & SQLite Database for NoteForge Application Synchronization.
      </p>
      <div class="status-badge"><span class="dot"></span> Server Live & Operational</div>
    </header>

    ${isReset ? '<div class="alert-success">✓ Database has been completely reset to a clean state.</div>' : ''}

    <h2>Database Metrics</h2>
    <div class="grid">
      <div class="card"><div class="card-num">${userCount}</div><div class="card-label">Active Users</div></div>
      <div class="card"><div class="card-num">${activeNoteCount}</div><div class="card-label">Active Notes${trashedNoteCount > 0 ? ` (${trashedNoteCount} in trash)` : ''}</div></div>
      <div class="card"><div class="card-num">${folderCount}</div><div class="card-label">Cloud Folders</div></div>
      <div class="card"><div class="card-num">${tagCount}</div><div class="card-label">Cloud Tags</div></div>
    </div>

    <div style="background: var(--card); border: 1px solid var(--border); padding: 1.25rem; border-radius: 12px; margin-bottom: 2rem;">
      <h3 style="font-size: 1.1rem; margin-bottom: 0.5rem;">Database Maintenance</h3>
      <p style="color: var(--muted); font-size: 0.9rem; margin-bottom: 1rem;">
        Clear all stored users, notes, and folders to reset the database and start fresh.
      </p>
      <form method="POST" action="/api/admin/reset-db" onsubmit="return confirm('⚠️ Are you sure you want to reset the database? This will delete all users and notes to start fresh.');">
        <button type="submit" class="btn-reset">🧹 Reset Database (Clear All Data)</button>
      </form>
    </div>

    <h2>API Endpoints</h2>
    <table>
      <thead>
        <tr><th>Method</th><th>Endpoint</th><th>Description</th><th>Auth Required</th></tr>
      </thead>
      <tbody>
        <tr><td><span class="method get">GET</span></td><td><code>/health</code></td><td>Health Check & Server Status</td><td>No</td></tr>
        <tr><td><span class="method post">POST</span></td><td><code>/api/auth/register</code></td><td>Register new user account</td><td>No</td></tr>
        <tr><td><span class="method post">POST</span></td><td><code>/api/auth/login</code></td><td>Authenticate and obtain JWT bearer token</td><td>No</td></tr>
        <tr><td><span class="method get">GET</span></td><td><code>/api/auth/me</code></td><td>Retrieve logged-in user profile</td><td>Yes (JWT)</td></tr>
        <tr><td><span class="method get">GET</span></td><td><code>/api/notes</code></td><td>Get user notes (search & filter)</td><td>Yes (JWT)</td></tr>
        <tr><td><span class="method post">POST</span></td><td><code>/api/notes</code></td><td>Create a new note in cloud database</td><td>Yes (JWT)</td></tr>
        <tr><td><span class="method put">PUT</span></td><td><code>/api/notes/:id</code></td><td>Update note content, tags or status</td><td>Yes (JWT)</td></tr>
        <tr><td><span class="method delete">DELETE</span></td><td><code>/api/notes/:id</code></td><td>Permanently delete note</td><td>Yes (JWT)</td></tr>
        <tr><td><span class="method get">GET</span></td><td><code>/api/folders</code></td><td>List user folders</td><td>Yes (JWT)</td></tr>
        <tr><td><span class="method post">POST</span></td><td><code>/api/folders</code></td><td>Create/Update folder</td><td>Yes (JWT)</td></tr>
        <tr><td><span class="method get">GET</span></td><td><code>/api/tags</code></td><td>List user tags</td><td>Yes (JWT)</td></tr>
        <tr><td><span class="method post">POST</span></td><td><code>/api/tags</code></td><td>Create/Update tag</td><td>Yes (JWT)</td></tr>
        <tr><td><span class="method post">POST</span></td><td><code>/api/sync/push</code></td><td>Batch upload local notes to cloud</td><td>Yes (JWT)</td></tr>
        <tr><td><span class="method get">GET</span></td><td><code>/api/sync/pull</code></td><td>Pull all cloud notes, folders & tags</td><td>Yes (JWT)</td></tr>
        <tr><td><span class="method post">POST</span></td><td><code>/api/admin/reset-db</code></td><td>Reset database and clear all records</td><td>No</td></tr>
      </tbody>
    </table>
  </div>
</body>
</html>`);
  } catch (err) {
    res.status(500).send('Server Error loading dashboard.');
  }
});

// 404 Handler
app.use((req, res) => {
  res.status(404).json({ success: false, error: 'API endpoint not found.' });
});

// Start Server
app.listen(PORT, '0.0.0.0', () => {
  console.log('====================================================');
  console.log(`🚀 NoteForge Backend running on: http://localhost:${PORT}`);
  console.log(`📱 Reachable on network at: http://0.0.0.0:${PORT}`);
  console.log(`📊 API Dashboard & Docs: http://localhost:${PORT}/`);
  console.log('====================================================');
});
