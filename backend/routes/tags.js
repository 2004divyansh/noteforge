const express = require('express');
const crypto = require('node:crypto');
const db = require('../db');
const { authenticateToken } = require('../middleware/auth');

const router = express.Router();
router.use(authenticateToken);

// GET /api/tags
router.get('/', (req, res) => {
  try {
    const stmt = db.prepare('SELECT * FROM tags WHERE user_id = ? ORDER BY name ASC');
    const tags = stmt.all(req.user.id);
    return res.json({ success: true, count: tags.length, tags });
  } catch (err) {
    return res.status(500).json({ success: false, error: 'Failed to fetch tags.' });
  }
});

// POST /api/tags
router.post('/', (req, res) => {
  try {
    const { id, name, color } = req.body;
    if (!name) {
      return res.status(400).json({ success: false, error: 'Tag name is required.' });
    }

    const tagId = id || crypto.randomUUID();
    const stmt = db.prepare(`
      INSERT OR REPLACE INTO tags (id, user_id, name, color)
      VALUES (?, ?, ?, ?)
    `);

    stmt.run(tagId, req.user.id, name.trim(), color || 4288585374);

    return res.status(201).json({
      success: true,
      message: 'Tag saved successfully.',
      tagId
    });
  } catch (err) {
    return res.status(500).json({ success: false, error: 'Failed to save tag.' });
  }
});

// DELETE /api/tags/:id
router.delete('/:id', (req, res) => {
  try {
    db.prepare('DELETE FROM note_tags WHERE tag_id = ? AND user_id = ?').run(req.params.id, req.user.id);
    const stmt = db.prepare('DELETE FROM tags WHERE id = ? AND user_id = ?');
    const result = stmt.run(req.params.id, req.user.id);

    if (result.changes === 0) {
      return res.status(404).json({ success: false, error: 'Tag not found.' });
    }

    return res.json({ success: true, message: 'Tag deleted.' });
  } catch (err) {
    return res.status(500).json({ success: false, error: 'Failed to delete tag.' });
  }
});

module.exports = router;

