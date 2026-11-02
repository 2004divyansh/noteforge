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

// Health Check JSON
app.get('/health', (req, res) => {
  res.json({
    status: 'ok',
    service: 'NoteForge REST API Backend',
    database: 'SQLite (WAL Mode)',
    timestamp: new Date().toISOString()
  });
});

// Interactive Dashboard & Documentation Root Page
app.get('/', (req, res) => {
  try {
    const userCount = db.prepare('SELECT COUNT(*) as count FROM users').get().count;
    const noteCount = db.prepare('SELECT COUNT(*) as count FROM notes').get().count;
    const folderCount = db.prepare('SELECT COUNT(*) as count FROM folders').get().count;
    const tagCount = db.prepare('SELECT COUNT(*) as count FROM tags').get().count;

    res.send(`<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>NoteForge Backend API Dashboard</title>
  <style>
    :root {
      --primary: #6750A4;
      --bg: #0f0d15;
      --card: #1a1724;
      --border: #2e283f;
      --text: #f5f2fd;
      --muted: #a69ebd;
      --accent: #4ade80;
    }
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
      background: var(--bg);
      color: var(--text);
      padding: 2rem 1.5rem;
      line-height: 1.6;
    }
    .container { max-width: 900px; margin: 0 auto; }
    header { margin-bottom: 2rem; border-bottom: 1px solid var(--border); padding-bottom: 1.5rem; }
    h1 { font-size: 2rem; display: flex; align-items: center; gap: 0.5rem; }
    .status-badge {
      display: inline-flex;
      align-items: center;
      gap: 0.4rem;
      background: rgba(74, 222, 128, 0.15);
      color: var(--accent);
      border: 1px solid rgba(74, 222, 128, 0.3);
      padding: 0.25rem 0.75rem;
      border-radius: 20px;
      font-size: 0.85rem;
      font-weight: 600;
    }
    .dot { width: 8px; height: 8px; background: var(--accent); border-radius: 50%; }
    .grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(180px, 1fr)); gap: 1rem; margin-bottom: 2rem; }
    .card { background: var(--card); border: 1px solid var(--border); border-radius: 12px; padding: 1.25rem; }
    .card-num { font-size: 1.85rem; font-weight: 700; color: #D0BCFF; }
    .card-label { font-size: 0.85rem; color: var(--muted); text-transform: uppercase; }
    h2 { font-size: 1.3rem; margin-bottom: 1rem; }
    table { width: 100%; border-collapse: collapse; margin-bottom: 2rem; background: var(--card); border-radius: 12px; overflow: hidden; border: 1px solid var(--border); }
    th, td { padding: 0.85rem 1rem; text-align: left; border-bottom: 1px solid var(--border); font-size: 0.9rem; }
    th { background: #15121e; color: var(--muted); }
    .method { font-weight: 700; font-family: monospace; font-size: 0.85rem; padding: 0.2rem 0.5rem; border-radius: 4px; }
    .post { background: #1e3a5f; color: #60a5fa; }
    .get { background: #064e3b; color: #34d399; }
    .put { background: #713f12; color: #fde047; }
    .delete { background: #7f1d1d; color: #f87171; }
    code { font-family: monospace; color: #EADDFF; }
  </style>
</head>
<body>
  <div class="container">
    <header>
      <h1>📝 NoteForge Integrated Backend</h1>
      <p style="color: var(--muted); margin: 0.5rem 0 1rem;">
        Certified CPAD Integrated Backend & SQLite Database for Cross-Platform Application Synchronization.
      </p>
      <div class="status-badge"><span class="dot"></span> Backend Live & Operational on Port ${PORT}</div>
    </header>

    <h2>Database Overview</h2>
    <div class="grid">
      <div class="card"><div class="card-num">${userCount}</div><div class="card-label">Registered Users</div></div>
      <div class="card"><div class="card-num">${noteCount}</div><div class="card-label">Cloud Notes</div></div>
      <div class="card"><div class="card-num">${folderCount}</div><div class="card-label">Cloud Folders</div></div>
      <div class="card"><div class="card-num">${tagCount}</div><div class="card-label">Cloud Tags</div></div>
    </div>

    <h2>RESTful API Endpoints</h2>
    <table>
      <thead>
        <tr><th>Method</th><th>Endpoint</th><th>Description</th><th>Auth Required</th></tr>
      </thead>
      <tbody>
        <tr><td><span class="method get">GET</span></td><td><code>/health</code></td><td>Backend Health Check & Server Status</td><td>No</td></tr>
        <tr><td><span class="method post">POST</span></td><td><code>/api/auth/register</code></td><td>Register new student user account</td><td>No</td></tr>
        <tr><td><span class="method post">POST</span></td><td><code>/api/auth/login</code></td><td>Authenticate and obtain JWT bearer token</td><td>No</td></tr>
        <tr><td><span class="method get">GET</span></td><td><code>/api/auth/me</code></td><td>Retrieve logged-in user profile</td><td>Yes (JWT)</td></tr>
        <tr><td><span class="method get">GET</span></td><td><code>/api/notes</code></td><td>Get user notes (supports search & folder filter)</td><td>Yes (JWT)</td></tr>
        <tr><td><span class="method post">POST</span></td><td><code>/api/notes</code></td><td>Create a new note in cloud database</td><td>Yes (JWT)</td></tr>
        <tr><td><span class="method put">PUT</span></td><td><code>/api/notes/:id</code></td><td>Update note content, tags or status</td><td>Yes (JWT)</td></tr>
        <tr><td><span class="method delete">DELETE</span></td><td><code>/api/notes/:id</code></td><td>Permanently delete note</td><td>Yes (JWT)</td></tr>
        <tr><td><span class="method get">GET</span></td><td><code>/api/folders</code></td><td>List user folders</td><td>Yes (JWT)</td></tr>
        <tr><td><span class="method post">POST</span></td><td><code>/api/folders</code></td><td>Create/Update folder</td><td>Yes (JWT)</td></tr>
        <tr><td><span class="method get">GET</span></td><td><code>/api/tags</code></td><td>List user tags</td><td>Yes (JWT)</td></tr>
        <tr><td><span class="method post">POST</span></td><td><code>/api/tags</code></td><td>Create/Update tag</td><td>Yes (JWT)</td></tr>
        <tr><td><span class="method post">POST</span></td><td><code>/api/sync/push</code></td><td>Batch push local SQLite notes to cloud backend</td><td>Yes (JWT)</td></tr>
        <tr><td><span class="method get">GET</span></td><td><code>/api/sync/pull</code></td><td>Pull all cloud notes, folders & tags to client</td><td>Yes (JWT)</td></tr>
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
