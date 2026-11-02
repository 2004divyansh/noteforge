const jwt = require('jsonwebtoken');
const db = require('../db');

const JWT_SECRET = process.env.JWT_SECRET || 'noteforge_cpad_secure_jwt_secret_key_2026';

function authenticateToken(req, res, next) {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1]; // Bearer TOKEN

  if (!token) {
    return res.status(401).json({
      success: false,
      error: 'Access denied. No authentication token provided.'
    });
  }

  try {
    const decoded = jwt.verify(token, JWT_SECRET);

    // Auto-heal / ensure user row exists in database (prevents foreign key errors on container redeploys)
    if (decoded && decoded.id) {
      let user = db.prepare('SELECT id, name, email FROM users WHERE id = ?').get(decoded.id);
      if (!user) {
        try {
          db.prepare(`
            INSERT OR IGNORE INTO users (id, name, email, password_hash, created_at)
            VALUES (?, ?, ?, ?, ?)
          `).run(
            decoded.id,
            decoded.name || 'NoteForge User',
            decoded.email || `${decoded.id}@noteforge.cloud`,
            'ephemeral_session_restored',
            new Date().toISOString()
          );
          user = db.prepare('SELECT id, name, email FROM users WHERE id = ?').get(decoded.id);
        } catch (healErr) {
          console.error('Error auto-healing user row:', healErr);
        }
      }
      req.user = user || decoded;
    } else {
      req.user = decoded;
    }

    next();
  } catch (err) {
    return res.status(403).json({
      success: false,
      error: 'Invalid or expired authentication token.'
    });
  }
}

module.exports = {
  authenticateToken,
  JWT_SECRET
};
