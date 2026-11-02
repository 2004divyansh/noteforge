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
    const checkStmt = db.prepare('SELECT id FROM users WHERE email = ?');
    const existing = checkStmt.get(cleanEmail);

    if (existing) {
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
      INSERT INTO users (id, name, email, password_hash, created_at)
      VALUES (?, ?, ?, ?, ?)
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

    const isMatch = await bcrypt.compare(password, user.password_hash);
    if (!isMatch) {
      return res.status(401).json({
        success: false,
        error: 'Invalid email or password.'
      });
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
