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

    if (decoded && decoded.id) {
      const user = db.prepare('SELECT id, name, email FROM users WHERE id = ?').get(decoded.id);
      if (!user) {
        return res.status(401).json({
          success: false,
          error: 'Session expired or database was reset. Please log in again.'
        });
      }
      req.user = user;
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
