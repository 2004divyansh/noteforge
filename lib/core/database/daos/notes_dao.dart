import 'package:drift/drift.dart';
import 'package:noteforge/core/database/database.dart';
import 'package:noteforge/core/database/tables.dart';

part 'notes_dao.g.dart';

@DriftAccessor(tables: [Notes, NoteTags, Tags, Folders])
class NotesDao extends DatabaseAccessor<AppDatabase> with _$NotesDaoMixin {
  NotesDao(super.db);

  // Get all active notes (not trashed or archived)
  Stream<List<Note>> watchActiveNotes() {
    return (select(notes)
      ..where((n) => n.isTrashed.equals(false) & n.isArchived.equals(false))
      ..orderBy([
        (n) => OrderingTerm(expression: n.isPinned, mode: OrderingMode.desc),
        (n) => OrderingTerm(expression: n.updatedAt, mode: OrderingMode.desc),
      ]))
        .watch();
  }

  // Get notes by folder
  Stream<List<Note>> watchNotesByFolder(String folderId) {
    return (select(notes)
      ..where((n) => n.folderId.equals(folderId) & n.isTrashed.equals(false) & n.isArchived.equals(false))
      ..orderBy([
        (n) => OrderingTerm(expression: n.isPinned, mode: OrderingMode.desc),
        (n) => OrderingTerm(expression: n.updatedAt, mode: OrderingMode.desc),
      ]))
        .watch();
  }

  // Get archived notes
  Stream<List<Note>> watchArchivedNotes() {
    return (select(notes)
      ..where((n) => n.isArchived.equals(true) & n.isTrashed.equals(false))
      ..orderBy([(n) => OrderingTerm(expression: n.updatedAt, mode: OrderingMode.desc)]))
        .watch();
  }

  // Get trashed notes
  Stream<List<Note>> watchTrashedNotes() {
    return (select(notes)
      ..where((n) => n.isTrashed.equals(true))
      ..orderBy([(n) => OrderingTerm(expression: n.trashedAt, mode: OrderingMode.desc)]))
        .watch();
  }

  // Get a single note by ID
  Future<Note?> getNoteById(String id) {
    return (select(notes)..where((n) => n.id.equals(id))).getSingleOrNull();
  }

  // Watch a single note
  Stream<Note?> watchNoteById(String noteId) {
    return (select(notes)..where((n) => n.id.equals(noteId)))
        .watchSingleOrNull();
  }

  // Insert a new note
  Future<void> insertNote(NotesCompanion note) {
    return into(notes).insert(note);
  }

  // Update a note
  Future<void> updateNote(String id, NotesCompanion note) {
    return (update(notes)..where((n) => n.id.equals(id))).write(note);
  }

  // Move note to trash
  Future<void> trashNote(String id) {
    return (update(notes)..where((n) => n.id.equals(id))).write(
      NotesCompanion(
        isTrashed: const Value(true),
        trashedAt: Value(DateTime.now()),
      ),
    );
  }

  // Restore note from trash
  Future<void> restoreNote(String id) {
    return (update(notes)..where((n) => n.id.equals(id))).write(
      const NotesCompanion(
        isTrashed: Value(false),
        trashedAt: Value(null),
      ),
    );
  }

  // Permanently delete a note
  Future<void> deleteNote(String id) async {
    await (delete(noteTags)..where((nt) => nt.noteId.equals(id))).go();
    await (delete(notes)..where((n) => n.id.equals(id))).go();
  }

  // Empty trash (delete all trashed notes)
  Future<void> emptyTrash() async {
    final trashedNotes = await (select(notes)..where((n) => n.isTrashed.equals(true))).get();
    for (final note in trashedNotes) {
      await deleteNote(note.id);
    }
  }

  // Toggle pin
  Future<void> togglePin(String id, bool isPinned) {
    return (update(notes)..where((n) => n.id.equals(id))).write(
      NotesCompanion(isPinned: Value(!isPinned)),
    );
  }

  // Toggle archive
  Future<void> toggleArchive(String id, bool isArchived) {
    return (update(notes)..where((n) => n.id.equals(id))).write(
      NotesCompanion(isArchived: Value(!isArchived)),
    );
  }

  // Move note to folder
  Future<void> moveToFolder(String noteId, String? folderId) {
    return (update(notes)..where((n) => n.id.equals(noteId))).write(
      NotesCompanion(folderId: Value(folderId)),
    );
  }

  // Search notes by text
  Stream<List<Note>> searchNotes(String query) {
    final pattern = '%$query%';
    return (select(notes)
      ..where((n) => 
        n.isTrashed.equals(false) &
        (n.title.like(pattern) | n.plainText.like(pattern)))
      ..orderBy([(n) => OrderingTerm(expression: n.updatedAt, mode: OrderingMode.desc)]))
        .watch();
  }

  // Get tags for a note
  Future<List<Tag>> getTagsForNote(String noteId) {
    final query = select(tags).join([
      innerJoin(noteTags, noteTags.tagId.equalsExp(tags.id)),
    ])..where(noteTags.noteId.equals(noteId));
    
    return query.map((row) => row.readTable(tags)).get();
  }

  // Watch tags for a note
  Stream<List<Tag>> watchTagsForNote(String noteId) {
    final query = select(tags).join([
      innerJoin(noteTags, noteTags.tagId.equalsExp(tags.id)),
    ])..where(noteTags.noteId.equals(noteId));
    
    return query.map((row) => row.readTable(tags)).watch();
  }

  // Add tag to note
  Future<void> addTagToNote(String noteId, String tagId) {
    return into(noteTags).insert(
      NoteTagsCompanion(
        noteId: Value(noteId),
        tagId: Value(tagId),
      ),
      mode: InsertMode.insertOrIgnore,
    );
  }

  // Remove tag from note
  Future<void> removeTagFromNote(String noteId, String tagId) {
    return (delete(noteTags)
      ..where((nt) => nt.noteId.equals(noteId) & nt.tagId.equals(tagId)))
        .go();
  }

  // Get note count
  Future<int> getNoteCount() async {
    final count = countAll();
    final query = selectOnly(notes)
      ..where(notes.isTrashed.equals(false))
      ..addColumns([count]);
    final result = await query.getSingle();
    return result.read(count) ?? 0;
  }
}
