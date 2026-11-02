const express = require('express');
const crypto = require('node:crypto');
const db = require('../db');
const { authenticateToken } = require('../middleware/auth');

const router = express.Router();
router.use(authenticateToken);

// GET /api/notes - list notes for current user
router.get('/', (req, res) => {
  try {
    const userId = req.user.id;
    const { folderId, isArchived, isTrashed, search } = req.query;

    let query = 'SELECT * FROM notes WHERE user_id = ?';
    const params = [userId];

    if (folderId !== undefined) {
      query += ' AND folder_id = ?';
      params.push(folderId);
    }

    if (isTrashed !== undefined) {
      query += ' AND is_trashed = ?';
      params.push(isTrashed === 'true' || isTrashed === '1' ? 1 : 0);
    } else {
      query += ' AND is_trashed = 0';
    }

    if (isArchived !== undefined) {
      query += ' AND is_archived = ?';
      params.push(isArchived === 'true' || isArchived === '1' ? 1 : 0);
    }

    if (search) {
      query += ' AND (title LIKE ? OR plain_text LIKE ?)';
      params.push(`%${search}%`, `%${search}%`);
    }

    query += ' ORDER BY is_pinned DESC, updated_at DESC';

    const stmt = db.prepare(query);
    const notes = stmt.all(...params);

    return res.json({
      success: true,
      count: notes.length,
      notes
    });
  } catch (err) {
    console.error('Fetch notes error:', err);
    return res.status(500).json({ success: false, error: 'Failed to fetch notes.' });
  }
});

// GET /api/notes/:id - get single note with tags
router.get('/:id', (req, res) => {
  try {
    const stmt = db.prepare('SELECT * FROM notes WHERE id = ? AND user_id = ?');
    const note = stmt.get(req.params.id, req.user.id);

    if (!note) {
      return res.status(404).json({ success: false, error: 'Note not found.' });
    }

    const tagStmt = db.prepare(`
      SELECT t.* FROM tags t
      INNER JOIN note_tags nt ON t.id = nt.tag_id
      WHERE nt.note_id = ? AND nt.user_id = ?
    `);
    const tags = tagStmt.all(note.id, req.user.id);

    return res.json({
      success: true,
      note: {
        ...note,
        tags
      }
    });
  } catch (err) {
    return res.status(500).json({ success: false, error: 'Failed to fetch note.' });
  }
});

// POST /api/notes - create note
router.post('/', (req, res) => {
  try {
    const userId = req.user.id;
    const {
      id,
      title = 'Untitled Note',
      content = '',
      plainText = '',
      folderId = null,
      isPinned = 0,
      isArchived = 0,
      isTrashed = 0,
      createdAt = new Date().toISOString(),
      updatedAt = new Date().toISOString(),
      tagIds = []
    } = req.body;

    const noteId = id || crypto.randomUUID();

    const insertStmt = db.prepare(`
      INSERT OR REPLACE INTO notes
        (id, user_id, title, content, plain_text, folder_id, is_pinned, is_archived, is_trashed, trashed_at, created_at, updated_at)
      VALUES
        (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    `);

    insertStmt.run(
      noteId,
      userId,
      title,
      typeof content === 'string' ? content : JSON.stringify(content),
      plainText,
      folderId,
      isPinned ? 1 : 0,
      isArchived ? 1 : 0,
      isTrashed ? 1 : 0,
      isTrashed ? new Date().toISOString() : null,
      createdAt,
      updatedAt
    );

    // Save tags if provided
    if (Array.isArray(tagIds) && tagIds.length > 0) {
      const tagInsert = db.prepare('INSERT OR IGNORE INTO note_tags (note_id, tag_id, user_id) VALUES (?, ?, ?)');
      for (const tId of tagIds) {
        tagInsert.run(noteId, tId, userId);
      }
    }

    return res.status(201).json({
      success: true,
      message: 'Note created successfully.',
      noteId
    });
  } catch (err) {
    console.error('Create note error:', err);
    return res.status(500).json({ success: false, error: 'Failed to create note.' });
  }
});

// PUT /api/notes/:id - update note
router.put('/:id', (req, res) => {
  try {
    const userId = req.user.id;
    const noteId = req.params.id;
    const {
      title,
      content,
      plainText,
      folderId,
      isPinned,
      isArchived,
      isTrashed,
      tagIds
    } = req.body;

    const existingStmt = db.prepare('SELECT * FROM notes WHERE id = ? AND user_id = ?');
    const existing = existingStmt.get(noteId, userId);

    if (!existing) {
      return res.status(404).json({ success: false, error: 'Note not found.' });
    }

    const updatedAt = new Date().toISOString();
    const updateStmt = db.prepare(`
      UPDATE notes SET
        title = COALESCE(?, title),
        content = COALESCE(?, content),
        plain_text = COALESCE(?, plain_text),
        folder_id = ?,
        is_pinned = COALESCE(?, is_pinned),
        is_archived = COALESCE(?, is_archived),
        is_trashed = COALESCE(?, is_trashed),
        trashed_at = CASE WHEN ? = 1 THEN ? ELSE NULL END,
        updated_at = ?
      WHERE id = ? AND user_id = ?
    `);

    updateStmt.run(
      title !== undefined ? title : null,
      content !== undefined ? (typeof content === 'string' ? content : JSON.stringify(content)) : null,
      plainText !== undefined ? plainText : null,
      folderId !== undefined ? folderId : existing.folder_id,
      isPinned !== undefined ? (isPinned ? 1 : 0) : null,
      isArchived !== undefined ? (isArchived ? 1 : 0) : null,
      isTrashed !== undefined ? (isTrashed ? 1 : 0) : null,
      isTrashed !== undefined ? (isTrashed ? 1 : 0) : existing.is_trashed,
      updatedAt,
      updatedAt,
      noteId,
      userId
    );

    if (Array.isArray(tagIds)) {
      db.prepare('DELETE FROM note_tags WHERE note_id = ? AND user_id = ?').run(noteId, userId);
      const tagInsert = db.prepare('INSERT OR IGNORE INTO note_tags (note_id, tag_id, user_id) VALUES (?, ?, ?)');
      for (const tId of tagIds) {
        tagInsert.run(noteId, tId, userId);
      }
    }

    return res.json({
      success: true,
      message: 'Note updated successfully.',
      updatedAt
    });
  } catch (err) {
    console.error('Update note error:', err);
    return res.status(500).json({ success: false, error: 'Failed to update note.' });
  }
});

// DELETE /api/notes/:id - permanently delete note
router.delete('/:id', (req, res) => {
  try {
    const userId = req.user.id;
    const noteId = req.params.id;

    const delTags = db.prepare('DELETE FROM note_tags WHERE note_id = ? AND user_id = ?');
    delTags.run(noteId, userId);

    const delNote = db.prepare('DELETE FROM notes WHERE id = ? AND user_id = ?');
    const result = delNote.run(noteId, userId);

    if (result.changes === 0) {
      return res.status(404).json({ success: false, error: 'Note not found.' });
    }

    return res.json({ success: true, message: 'Note deleted permanently.' });
  } catch (err) {
    return res.status(500).json({ success: false, error: 'Failed to delete note.' });
  }
});

module.exports = router;

