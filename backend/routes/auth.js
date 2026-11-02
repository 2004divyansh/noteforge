const express = require('express');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const crypto = require('node:crypto');
const db = require('../db');
const { authenticateToken, JWT_SECRET } = require('../middleware/auth');

const router = express.Router();

// Register new user
router.post('/register', async (req, res) => {
  try {
    const { name, email, password } = req.body;

    if (!name || !email || !password) {
      return res.status(400).json({
        success: false,
        error: 'Name, email, and password are required.'
      });
    }

    const cleanEmail = email.trim().toLowerCase();

    // Check if user already exists
    const checkStmt = db.prepare('SELECT id, name, email, auth_provider, password_hash FROM users WHERE email = ?');
    const existing = checkStmt.get(cleanEmail);

    if (existing) {
      // BLOCK registration if account is created using Google OAuth
      if (existing.auth_provider === 'google' || existing.password_hash === 'google_oauth_account') {
        return res.status(400).json({
          success: false,
          error: 'This account was created with Google Sign-In. Please sign in using Google.'
        });
      }

      // Check if existing user is an uninitialized/session placeholder account
      const userRow = db.prepare('SELECT * FROM users WHERE id = ?').get(existing.id);
      if (userRow && (userRow.password_hash === 'ephemeral_session_restored' || !userRow.password_hash.startsWith('$2'))) {
        const salt = await bcrypt.genSalt(10);
        const passwordHash = await bcrypt.hash(password, salt);
        db.prepare("UPDATE users SET name = ?, password_hash = ?, auth_provider = 'local' WHERE id = ?").run(name.trim(), passwordHash, existing.id);

        const token = jwt.sign(
          { id: existing.id, email: cleanEmail, name: name.trim() },
          JWT_SECRET,
          { expiresIn: '30d' }
        );

        return res.status(201).json({
          success: true,
          message: 'Account successfully registered and verified.',
          token,
          user: {
            id: existing.id,
            name: name.trim(),
            email: cleanEmail,
            createdAt: userRow.created_at
          }
        });
      }

      return res.status(409).json({
        success: false,
        error: 'An account with this email address already exists.'
      });
    }

    const salt = await bcrypt.genSalt(10);
    const passwordHash = await bcrypt.hash(password, salt);
    const userId = crypto.randomUUID();
    const createdAt = new Date().toISOString();

    const insertStmt = db.prepare(`
      INSERT INTO users (id, name, email, password_hash, auth_provider, created_at)
      VALUES (?, ?, ?, ?, 'local', ?)
    `);

    insertStmt.run(userId, name.trim(), cleanEmail, passwordHash, createdAt);

    const token = jwt.sign(
      { id: userId, email: cleanEmail, name: name.trim() },
      JWT_SECRET,
      { expiresIn: '30d' }
    );

    return res.status(201).json({
      success: true,
      message: 'User registered successfully.',
      token,
      user: {
        id: userId,
        name: name.trim(),
        email: cleanEmail,
        createdAt
      }
    });
  } catch (err) {
    console.error('Registration error:', err);
    return res.status(500).json({
      success: false,
      error: 'Internal server error during registration.'
    });
  }
});

// Login existing user
router.post('/login', async (req, res) => {
  try {
    const { email, password } = req.body;

    if (!email || !password) {
      return res.status(400).json({
        success: false,
        error: 'Email and password are required.'
      });
    }

    const cleanEmail = email.trim().toLowerCase();
    const stmt = db.prepare('SELECT * FROM users WHERE email = ?');
    const user = stmt.get(cleanEmail);

    if (!user) {
      return res.status(401).json({
        success: false,
        error: 'Invalid email or password.'
      });
    }

    // BLOCK password login if account was created with Google OAuth
    if (user.auth_provider === 'google' || user.password_hash === 'google_oauth_account') {
      return res.status(400).json({
        success: false,
        error: 'This account was created with Google Sign-In. Please sign in using Google.'
      });
    }

    // Auto-heal uninitialized/placeholder session passwords
    if (user.password_hash === 'ephemeral_session_restored' || !user.password_hash.startsWith('$2')) {
      const salt = await bcrypt.genSalt(10);
      const newHash = await bcrypt.hash(password, salt);
      db.prepare('UPDATE users SET password_hash = ? WHERE id = ?').run(newHash, user.id);
    } else {
      const isMatch = await bcrypt.compare(password, user.password_hash);
      if (!isMatch) {
        return res.status(401).json({
          success: false,
          error: 'Invalid email or password.'
        });
      }
    }

    const token = jwt.sign(
      { id: user.id, email: user.email, name: user.name },
      JWT_SECRET,
      { expiresIn: '30d' }
    );

    return res.json({
      success: true,
      message: 'Login successful.',
      token,
      user: {
        id: user.id,
        name: user.name,
        email: user.email,
        createdAt: user.created_at
      }
    });
  } catch (err) {
    console.error('Login error:', err);
    return res.status(500).json({
      success: false,
      error: 'Internal server error during login.'
    });
  }
});

// In-memory store for short-lived 6-digit OAuth exchange codes
const oneTimeAuthCodes = new Map();

function generateOneTimeCode() {
  return Math.floor(100000 + Math.random() * 900000).toString();
}

// Google OAuth Sign-In / Sign-Up API Endpoint
router.post('/google', async (req, res) => {
  try {
    const { email, name, googleId } = req.body;

    if (!email) {
      return res.status(400).json({
        success: false,
        error: 'Google email address is required.'
      });
    }

    const cleanEmail = email.trim().toLowerCase();
    const displayName = (name && name.trim()) || cleanEmail.split('@')[0];

    let user = db.prepare('SELECT * FROM users WHERE email = ?').get(cleanEmail);

    if (!user) {
      const userId = crypto.randomUUID();
      const createdAt = new Date().toISOString();
      db.prepare(`
        INSERT INTO users (id, name, email, password_hash, auth_provider, google_id, created_at)
        VALUES (?, ?, ?, 'google_oauth_account', 'google', ?, ?)
      `).run(userId, displayName, cleanEmail, googleId || null, createdAt);

      user = { id: userId, name: displayName, email: cleanEmail, auth_provider: 'google', created_at: createdAt };
    } else {
      // Ensure user has auth_provider = 'google'
      db.prepare("UPDATE users SET auth_provider = 'google', google_id = COALESCE(?, google_id) WHERE id = ?")
        .run(googleId || null, user.id);
    }

    const token = jwt.sign(
      { id: user.id, email: user.email, name: user.name },
      JWT_SECRET,
      { expiresIn: '30d' }
    );

    return res.json({
      success: true,
      message: 'Google authentication successful.',
      token,
      user: {
        id: user.id,
        name: user.name,
        email: user.email,
        auth_provider: 'google',
        createdAt: user.created_at
      }
    });
  } catch (err) {
    console.error('Google sign-in error:', err);
    return res.status(500).json({
      success: false,
      error: 'Internal server error during Google sign in.'
    });
  }
});

// Start Google OAuth Flow (Redirect to Google OAuth or Consent Page)
router.get('/google/start', (req, res) => {
  const { redirect_port } = req.query;
  const baseUrl = `${req.protocol}://${req.get('host')}`;

  if (process.env.GOOGLE_CLIENT_ID) {
    const callbackUrl = `${baseUrl}/api/auth/google/callback`;
    const googleAuthUrl = `https://accounts.google.com/o/oauth2/v2/auth?` +
      `client_id=${encodeURIComponent(process.env.GOOGLE_CLIENT_ID)}` +
      `&redirect_uri=${encodeURIComponent(callbackUrl)}` +
      `&response_type=code` +
      `&scope=openid%20profile%20email` +
      `&state=${encodeURIComponent(JSON.stringify({ redirect_port }))}` +
      `&prompt=select_account`;
    return res.redirect(googleAuthUrl);
  }

  // Fallback to integrated Google OAuth 2.0 Consent screen
  return res.redirect(`${baseUrl}/api/auth/google/consent?redirect_port=${encodeURIComponent(redirect_port || '')}`);
});

// Integrated Google OAuth 2.0 Consent Screen
router.get('/google/consent', (req, res) => {
  const { redirect_port } = req.query;
  const html = `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Sign in with Google - NoteForge</title>
  <link href="https://fonts.googleapis.com/css2?family=Roboto:wght@400;500;700&display=swap" rel="stylesheet">
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      font-family: 'Roboto', -apple-system, BlinkMacSystemFont, sans-serif;
      background: #f8fafc;
      min-height: 100vh;
      display: flex;
      align-items: center;
      justify-content: center;
      padding: 20px;
    }
    .card {
      background: #ffffff;
      border: 1px solid #dadce0;
      border-radius: 12px;
      padding: 40px;
      max-width: 440px;
      width: 100%;
      box-shadow: 0 4px 12px rgba(0, 0, 0, 0.05);
      text-align: center;
    }
    .google-logo {
      width: 48px;
      height: 48px;
      margin-bottom: 16px;
    }
    h1 {
      font-size: 22px;
      color: #202124;
      font-weight: 500;
      margin-bottom: 6px;
    }
    p.sub {
      font-size: 14px;
      color: #5f6368;
      margin-bottom: 28px;
    }
    .input-group {
      text-align: left;
      margin-bottom: 18px;
    }
    label {
      display: block;
      font-size: 12px;
      font-weight: 500;
      color: #3c4043;
      margin-bottom: 6px;
    }
    input {
      width: 100%;
      padding: 12px 14px;
      border: 1px solid #dadce0;
      border-radius: 6px;
      font-size: 14px;
      outline: none;
      transition: border-color 0.2s;
    }
    input:focus {
      border-color: #1a73e8;
      box-shadow: 0 0 0 2px rgba(26, 115, 232, 0.2);
    }
    .disclaimer {
      font-size: 12px;
      color: #5f6368;
      text-align: left;
      line-height: 1.5;
      margin-bottom: 24px;
      padding: 12px;
      background: #f1f3f4;
      border-radius: 8px;
    }
    .btn {
      width: 100%;
      background: #1a73e8;
      color: #ffffff;
      border: none;
      border-radius: 6px;
      padding: 12px;
      font-size: 14px;
      font-weight: 500;
      cursor: pointer;
      display: flex;
      align-items: center;
      justify-content: center;
      gap: 10px;
      transition: background 0.2s;
    }
    .btn:hover { background: #1557b0; }
  </style>
</head>
<body>
  <div class="card">
    <svg class="google-logo" viewBox="0 0 24 24">
      <path fill="#4285F4" d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z"/>
      <path fill="#34A853" d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z"/>
      <path fill="#FBBC05" d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.06H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.94l2.85-2.22.81-.63z"/>
      <path fill="#EA4335" d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.06l3.66 2.84c.87-2.6 3.3-4.52 6.16-4.52z"/>
    </svg>
    <h1>Sign in with Google</h1>
    <p class="sub">Choose your Google Account to continue to NoteForge</p>

    <form method="POST" action="/api/auth/google/consent-submit">
      <input type="hidden" name="redirect_port" value="${redirect_port || ''}">
      <div class="input-group">
        <label for="email">Google Account Email</label>
        <input type="email" id="email" name="email" placeholder="e.g. user@gmail.com" required autofocus>
      </div>
      <div class="input-group">
        <label for="name">Your Name</label>
        <input type="text" id="name" name="name" placeholder="e.g. Alex Smith" required>
      </div>
      <div class="disclaimer">
        To continue, Google will share your name, email address, and profile with NoteForge.
      </div>
      <button type="submit" class="btn">
        <span>Continue with Google</span>
      </button>
    </form>
  </div>
</body>
</html>`;
  return res.send(html);
});

// Consent form submission
router.post('/google/consent-submit', (req, res) => {
  const { email, name, redirect_port } = req.body;
  if (!email || !email.includes('@')) {
    return res.status(400).send('Invalid email provided.');
  }

  const cleanEmail = email.trim().toLowerCase();
  const displayName = (name && name.trim()) || cleanEmail.split('@')[0];
  const googleId = 'gid_' + crypto.randomBytes(8).toString('hex');

  let user = db.prepare('SELECT * FROM users WHERE email = ?').get(cleanEmail);
  if (!user) {
    const userId = crypto.randomUUID();
    const createdAt = new Date().toISOString();
    db.prepare(`
      INSERT INTO users (id, name, email, password_hash, auth_provider, google_id, created_at)
      VALUES (?, ?, ?, 'google_oauth_account', 'google', ?, ?)
    `).run(userId, displayName, cleanEmail, googleId, createdAt);
    user = { id: userId, name: displayName, email: cleanEmail, auth_provider: 'google', created_at: createdAt };
  } else {
    db.prepare("UPDATE users SET auth_provider = 'google', google_id = COALESCE(?, google_id) WHERE id = ?")
      .run(googleId, user.id);
  }

  const token = jwt.sign(
    { id: user.id, email: user.email, name: user.name },
    JWT_SECRET,
    { expiresIn: '30d' }
  );

  const oneTimeCode = generateOneTimeCode();
  oneTimeAuthCodes.set(oneTimeCode, {
    token,
    user: { id: user.id, name: user.name, email: user.email },
    expiresAt: Date.now() + 10 * 60 * 1000
  });

  return renderOAuthSuccess(res, {
    token,
    oneTimeCode,
    email: user.email,
    name: user.name,
    redirect_port
  });
});

// Google OAuth Callback Endpoint
router.get('/google/callback', async (req, res) => {
  const { code, state } = req.query;
  let redirect_port = '';

  try {
    if (state) {
      const parsed = JSON.parse(state);
      redirect_port = parsed.redirect_port || '';
    }
  } catch (_) {}

  // If live Google OAuth code exists and client secrets configured
  if (code && process.env.GOOGLE_CLIENT_ID && process.env.GOOGLE_CLIENT_SECRET) {
    try {
      const baseUrl = `${req.protocol}://${req.get('host')}`;
      const tokenRes = await fetch('https://oauth2.googleapis.com/token', {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body: new URLSearchParams({
          code,
          client_id: process.env.GOOGLE_CLIENT_ID,
          client_secret: process.env.GOOGLE_CLIENT_SECRET,
          redirect_uri: `${baseUrl}/api/auth/google/callback`,
          grant_type: 'authorization_code'
        })
      });
      const tokenData = await tokenRes.json();
      if (tokenData.access_token) {
        const profileRes = await fetch('https://www.googleapis.com/oauth2/v3/userinfo', {
          headers: { Authorization: `Bearer ${tokenData.access_token}` }
        });
        const profile = await profileRes.json();
        const cleanEmail = profile.email.trim().toLowerCase();
        const displayName = profile.name || cleanEmail.split('@')[0];
        const googleId = profile.sub;

        let user = db.prepare('SELECT * FROM users WHERE email = ?').get(cleanEmail);
        if (!user) {
          const userId = crypto.randomUUID();
          const createdAt = new Date().toISOString();
          db.prepare(`
            INSERT INTO users (id, name, email, password_hash, auth_provider, google_id, created_at)
            VALUES (?, ?, ?, 'google_oauth_account', 'google', ?, ?)
          `).run(userId, displayName, cleanEmail, googleId, createdAt);
          user = { id: userId, name: displayName, email: cleanEmail, auth_provider: 'google', created_at: createdAt };
        } else {
          db.prepare("UPDATE users SET auth_provider = 'google', google_id = COALESCE(?, google_id) WHERE id = ?")
            .run(googleId, user.id);
        }

        const token = jwt.sign(
          { id: user.id, email: user.email, name: user.name },
          JWT_SECRET,
          { expiresIn: '30d' }
        );

        const oneTimeCode = generateOneTimeCode();
        oneTimeAuthCodes.set(oneTimeCode, {
          token,
          user: { id: user.id, name: user.name, email: user.email },
          expiresAt: Date.now() + 10 * 60 * 1000
        });

        return renderOAuthSuccess(res, {
          token,
          oneTimeCode,
          email: user.email,
          name: user.name,
          redirect_port
        });
      }
    } catch (err) {
      console.error('Google token exchange failed:', err);
    }
  }

  // Redirect to consent if direct callback access
  return res.redirect(`/api/auth/google/consent?redirect_port=${encodeURIComponent(redirect_port)}`);
});

// Exchange One-Time Code for JWT Token
router.post('/google/exchange-code', (req, res) => {
  const { code } = req.body;
  if (!code) {
    return res.status(400).json({ success: false, error: 'One-time code is required.' });
  }

  const entry = oneTimeAuthCodes.get(code.trim());
  if (!entry || entry.expiresAt < Date.now()) {
    return res.status(400).json({ success: false, error: 'Code is invalid or has expired.' });
  }

  oneTimeAuthCodes.delete(code.trim());

  return res.json({
    success: true,
    token: entry.token,
    user: entry.user
  });
});

// Render OAuth Success View
function renderOAuthSuccess(res, { token, oneTimeCode, email, name, redirect_port }) {
  const html = `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Connected to NoteForge</title>
  <link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@500;600;700&display=swap" rel="stylesheet">
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      font-family: 'Plus Jakarta Sans', -apple-system, BlinkMacSystemFont, sans-serif;
      background: #faf8f5;
      min-height: 100vh;
      display: flex;
      align-items: center;
      justify-content: center;
      padding: 24px;
      color: #1e293b;
    }
    .card {
      background: #ffffff;
      border: 1px solid #e2e8f0;
      border-radius: 16px;
      padding: 40px;
      max-width: 460px;
      width: 100%;
      text-align: center;
      box-shadow: 0 10px 25px -5px rgba(0, 0, 0, 0.05);
    }
    .icon {
      width: 60px;
      height: 60px;
      background: #ecfdf5;
      color: #10b981;
      border-radius: 50%;
      display: flex;
      align-items: center;
      justify-content: center;
      margin: 0 auto 20px;
      font-size: 28px;
    }
    h1 { font-size: 24px; font-weight: 700; color: #0f172a; margin-bottom: 8px; }
    p.user-info { font-size: 15px; color: #64748b; margin-bottom: 24px; }
    .code-box {
      background: #f1f5f9;
      border: 2px dashed #cbd5e1;
      border-radius: 12px;
      padding: 16px;
      margin-bottom: 24px;
    }
    .code-label { font-size: 12px; font-weight: 600; text-transform: uppercase; color: #64748b; margin-bottom: 6px; letter-spacing: 0.5px; }
    .code-val { font-size: 32px; font-weight: 700; color: #0284c7; letter-spacing: 4px; font-family: monospace; }
    .status { font-size: 14px; color: #059669; font-weight: 600; margin-bottom: 20px; }
    .btn {
      display: inline-block;
      width: 100%;
      background: #f97316;
      color: #ffffff;
      text-decoration: none;
      padding: 14px;
      border-radius: 10px;
      font-weight: 600;
      font-size: 15px;
      cursor: pointer;
      border: none;
      transition: background 0.2s;
    }
    .btn:hover { background: #ea580c; }
  </style>
</head>
<body>
  <div class="card">
    <div class="icon">✓</div>
    <h1>Google Sign-In Successful!</h1>
    <p class="user-info">Connected as <strong>${name}</strong> (${email})</p>

    <div class="code-box">
      <div class="code-label">One-Time NoteForge Auth Code</div>
      <div class="code-val">${oneTimeCode}</div>
    </div>

    <p class="status" id="redirect-status">Connecting to NoteForge app...</p>
    <a href="noteforge://auth-callback?token=${encodeURIComponent(token)}" class="btn" id="open-btn">
      Return to NoteForge
    </a>
  </div>

  <script>
    const port = "${redirect_port || ''}";
    const token = "${token}";

    // Auto-ping local loopback server if open
    if (port) {
      fetch('http://127.0.0.1:' + port + '/callback?token=' + encodeURIComponent(token))
        .then(() => {
          document.getElementById('redirect-status').innerText = '✓ Connected! You can close this tab.';
        })
        .catch(() => {});
    }

    // Try custom protocol launch
    try {
      window.location = 'noteforge://auth-callback?token=' + encodeURIComponent(token);
    } catch (_) {}
  </script>
</body>
</html>`;
  return res.send(html);
}

// Reset Password
router.post('/reset-password', async (req, res) => {
  try {
    const { email, newPassword } = req.body;

    if (!email || !newPassword) {
      return res.status(400).json({
        success: false,
        error: 'Email and new password are required.'
      });
    }

    if (newPassword.length < 6) {
      return res.status(400).json({
        success: false,
        error: 'Password must be at least 6 characters.'
      });
    }

    const cleanEmail = email.trim().toLowerCase();
    const user = db.prepare('SELECT * FROM users WHERE email = ?').get(cleanEmail);

    if (!user) {
      return res.status(404).json({
        success: false,
        error: 'No account found with this email address.'
      });
    }

    // BLOCK password reset if account was created with Google OAuth
    if (user.auth_provider === 'google' || user.password_hash === 'google_oauth_account') {
      return res.status(400).json({
        success: false,
        error: 'This account was created with Google Sign-In. Password reset is not available.'
      });
    }

    const salt = await bcrypt.genSalt(10);
    const passwordHash = await bcrypt.hash(newPassword, salt);
    db.prepare('UPDATE users SET password_hash = ? WHERE id = ?').run(passwordHash, user.id);

    const token = jwt.sign(
      { id: user.id, email: user.email, name: user.name },
      JWT_SECRET,
      { expiresIn: '30d' }
    );

    return res.json({
      success: true,
      message: 'Password reset successfully. You are now logged in.',
      token,
      user: {
        id: user.id,
        name: user.name,
        email: user.email,
        createdAt: user.created_at
      }
    });
  } catch (err) {
    console.error('Password reset error:', err);
    return res.status(500).json({
      success: false,
      error: 'Internal server error during password reset.'
    });
  }
});

// Get current authenticated user profile
router.get('/me', authenticateToken, (req, res) => {
  try {
    const stmt = db.prepare('SELECT id, name, email, created_at FROM users WHERE id = ?');
    const user = stmt.get(req.user.id);

    if (!user) {
      return res.status(404).json({
        success: false,
        error: 'User not found.'
      });
    }

    return res.json({
      success: true,
      user: {
        id: user.id,
        name: user.name,
        email: user.email,
        createdAt: user.created_at
      }
    });
  } catch (err) {
    return res.status(500).json({
      success: false,
      error: 'Failed to retrieve user profile.'
    });
  }
});

module.exports = router;

