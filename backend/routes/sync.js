const express = require('express');
const db = require('../db');
const { authenticateToken } = require('../middleware/auth');

const router = express.Router();
router.use(authenticateToken);

// POST /api/sync/push - Batch upload local state to server
router.post('/push', (req, res) => {
  try {
    const userId = req.user.id;
    const {
      folders = [],
      tags = [],
      notes = [],
      noteTags = [],
      deletedNoteIds = []
    } = req.body;

    // Explicitly guarantee user row exists in SQLite before transaction (prevents foreign key errors on container redeploys)
    const existingUser = db.prepare('SELECT id FROM users WHERE id = ?').get(userId);
    if (!existingUser) {
      try {
        db.prepare(`
          INSERT OR IGNORE INTO users (id, name, email, password_hash, created_at)
          VALUES (?, ?, ?, ?, ?)
        `).run(
          userId,
          req.user.name || 'NoteForge User',
          req.user.email || `${userId}@noteforge.cloud`,
          'ephemeral_session_restored',
          new Date().toISOString()
        );
      } catch (insertUserErr) {
        console.error('Failed to ensure user row:', insertUserErr);
      }
    }

    // Use transaction for atomic consistency
    db.exec('BEGIN TRANSACTION;');

    try {
      // 1. Process Permanent Deletions
      if (Array.isArray(deletedNoteIds) && deletedNoteIds.length > 0) {
        const delTagStmt = db.prepare('DELETE FROM note_tags WHERE note_id = ? AND user_id = ?');
        const delNoteStmt = db.prepare('DELETE FROM notes WHERE id = ? AND user_id = ?');
        const recDelStmt = db.prepare(`
          INSERT OR REPLACE INTO deleted_records (id, user_id, entity_type, deleted_at)
          VALUES (?, ?, 'note', ?)
        `);

        for (const delId of deletedNoteIds) {
          delTagStmt.run(delId, userId);
          delNoteStmt.run(delId, userId);
          recDelStmt.run(delId, userId, new Date().toISOString());
        }
      }

      // 2. Sync Folders
      const folderStmt = db.prepare(`
        INSERT OR REPLACE INTO folders (id, user_id, name, color, parent_id, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, ?)
      `);
      for (const f of folders) {
        folderStmt.run(
          f.id,
          userId,
          f.name,
          f.color || 4288585374,
          f.parentId || null,
          f.createdAt || new Date().toISOString(),
          f.updatedAt || new Date().toISOString()
        );
      }

      // 3. Sync Tags
      const tagStmt = db.prepare(`
        INSERT OR REPLACE INTO tags (id, user_id, name, color)
        VALUES (?, ?, ?, ?)
      `);
      for (const t of tags) {
        tagStmt.run(t.id, userId, t.name, t.color || 4288585374);
      }

      // 4. Sync Notes (Conflict-safe with Last-Write-Wins timestamps)
      const noteUpsertStmt = db.prepare(`
        INSERT INTO notes
          (id, user_id, title, content, plain_text, folder_id, is_pinned, is_archived, is_trashed, trashed_at, created_at, updated_at)
        VALUES
          (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(id) DO UPDATE SET
          user_id = excluded.user_id,
          title = CASE WHEN excluded.updated_at >= notes.updated_at THEN excluded.title ELSE notes.title END,
          content = CASE WHEN excluded.updated_at >= notes.updated_at THEN excluded.content ELSE notes.content END,
          plain_text = CASE WHEN excluded.updated_at >= notes.updated_at THEN excluded.plain_text ELSE notes.plain_text END,
          folder_id = CASE WHEN excluded.updated_at >= notes.updated_at THEN excluded.folder_id ELSE notes.folder_id END,
          is_pinned = CASE WHEN excluded.updated_at >= notes.updated_at THEN excluded.is_pinned ELSE notes.is_pinned END,
          is_archived = CASE WHEN excluded.updated_at >= notes.updated_at THEN excluded.is_archived ELSE notes.is_archived END,
          is_trashed = CASE WHEN excluded.updated_at >= notes.updated_at THEN excluded.is_trashed ELSE notes.is_trashed END,
          trashed_at = CASE WHEN excluded.updated_at >= notes.updated_at THEN excluded.trashed_at ELSE notes.trashed_at END,
          updated_at = CASE WHEN excluded.updated_at >= notes.updated_at THEN excluded.updated_at ELSE notes.updated_at END
      `);

      for (const n of notes) {
        // Skip any note that was just permanently deleted
        if (Array.isArray(deletedNoteIds) && deletedNoteIds.includes(n.id)) {
          continue;
        }

        const incomingUpdated = n.updatedAt || new Date().toISOString();

        noteUpsertStmt.run(
          n.id,
          userId,
          n.title || 'Untitled',
          typeof n.content === 'string' ? n.content : JSON.stringify(n.content || ''),
          n.plainText || '',
          n.folderId || null,
          n.isPinned ? 1 : 0,
          n.isArchived ? 1 : 0,
          n.isTrashed ? 1 : 0,
          n.trashedAt || null,
          n.createdAt || new Date().toISOString(),
          incomingUpdated
        );
      }

      // 5. Sync Note Tags
      const noteTagStmt = db.prepare(`
        INSERT OR IGNORE INTO note_tags (note_id, tag_id, user_id)
        VALUES (?, ?, ?)
      `);
      for (const nt of noteTags) {
        noteTagStmt.run(nt.noteId, nt.tagId, userId);
      }

      db.exec('COMMIT;');

      return res.json({
        success: true,
        message: 'Sync push completed successfully.',
        synced: {
          folders: folders.length,
          tags: tags.length,
          notes: notes.length,
          noteTags: noteTags.length,
          deletedNotes: deletedNoteIds.length
        },
        timestamp: new Date().toISOString()
      });
    } catch (innerErr) {
      db.exec('ROLLBACK;');
      throw innerErr;
    }
  } catch (err) {
    console.error('Sync push error:', err);
    return res.status(500).json({ success: false, error: 'Failed to push sync data: ' + err.message });
  }
});

// GET /api/sync/pull - Download complete cloud state for current user
router.get('/pull', (req, res) => {
  try {
    const userId = req.user.id;

    // Ensure user row exists
    const existingUser = db.prepare('SELECT id FROM users WHERE id = ?').get(userId);
    if (!existingUser) {
      try {
        db.prepare(`
          INSERT OR IGNORE INTO users (id, name, email, password_hash, created_at)
          VALUES (?, ?, ?, ?, ?)
        `).run(
          userId,
          req.user.name || 'NoteForge User',
          req.user.email || `${userId}@noteforge.cloud`,
          'ephemeral_session_restored',
          new Date().toISOString()
        );
      } catch (insertUserErr) {
        console.error('Failed to ensure user row:', insertUserErr);
      }
    }

    const folders = db.prepare('SELECT * FROM folders WHERE user_id = ?').all(userId);
    const tags = db.prepare('SELECT * FROM tags WHERE user_id = ?').all(userId);
    const notes = db.prepare('SELECT * FROM notes WHERE user_id = ?').all(userId);
    const noteTags = db.prepare('SELECT * FROM note_tags WHERE user_id = ?').all(userId);
    const deletedRecords = db.prepare("SELECT id FROM deleted_records WHERE user_id = ? AND entity_type = 'note'").all(userId);
    const deletedNoteIds = deletedRecords.map(r => r.id);

    return res.json({
      success: true,
      data: {
        folders,
        tags,
        notes,
        noteTags,
        deletedNoteIds
      },
      count: {
        folders: folders.length,
        tags: tags.length,
        notes: notes.length,
        noteTags: noteTags.length,
        deletedNotes: deletedNoteIds.length
      },
      timestamp: new Date().toISOString()
    });
  } catch (err) {
    console.error('Sync pull error:', err);
    return res.status(500).json({ success: false, error: 'Failed to pull sync data: ' + err.message });
  }
});

module.exports = router;
