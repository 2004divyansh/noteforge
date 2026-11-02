const express = require('express');
const crypto = require('node:crypto');
const db = require('../db');
const { authenticateToken } = require('../middleware/auth');

const router = express.Router();
router.use(authenticateToken);

// GET /api/folders
router.get('/', (req, res) => {
  try {
    const stmt = db.prepare('SELECT * FROM folders WHERE user_id = ? ORDER BY name ASC');
    const folders = stmt.all(req.user.id);
    return res.json({ success: true, count: folders.length, folders });
  } catch (err) {
    return res.status(500).json({ success: false, error: 'Failed to fetch folders.' });
  }
});

// POST /api/folders
router.post('/', (req, res) => {
  try {
    const { id, name, color, parentId } = req.body;
    if (!name) {
      return res.status(400).json({ success: false, error: 'Folder name is required.' });
    }

    const folderId = id || crypto.randomUUID();
    const now = new Date().toISOString();

    const stmt = db.prepare(`
      INSERT OR REPLACE INTO folders (id, user_id, name, color, parent_id, created_at, updated_at)
      VALUES (?, ?, ?, ?, ?, ?, ?)
    `);

    stmt.run(folderId, req.user.id, name.trim(), color || 4288585374, parentId || null, now, now);

    return res.status(201).json({
      success: true,
      message: 'Folder saved successfully.',
      folderId
    });
  } catch (err) {
    return res.status(500).json({ success: false, error: 'Failed to save folder.' });
  }
});

// DELETE /api/folders/:id
router.delete('/:id', (req, res) => {
  try {
    // Unassign folder from notes
    db.prepare('UPDATE notes SET folder_id = NULL WHERE folder_id = ? AND user_id = ?')
      .run(req.params.id, req.user.id);

    const stmt = db.prepare('DELETE FROM folders WHERE id = ? AND user_id = ?');
    const result = stmt.run(req.params.id, req.user.id);

    if (result.changes === 0) {
      return res.status(404).json({ success: false, error: 'Folder not found.' });
    }

    return res.json({ success: true, message: 'Folder deleted.' });
  } catch (err) {
    return res.status(500).json({ success: false, error: 'Failed to delete folder.' });
  }
});

module.exports = router;
