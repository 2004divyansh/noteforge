import 'package:drift/native.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:noteforge/core/database/database.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('NotesDao Tests', () {
    test('Can insert and retrieve notes', () async {
      await db.notesDao.insertNote(
        NotesCompanion(
          id: const Value('note-1'),
          title: const Value('Study Plan: Algorithms'),
          plainText: const Value('Binary Search, Graph traversal, DP'),
          content: const Value('[{"insert":"Binary Search, Graph traversal, DP\\n"}]'),
          createdAt: Value(DateTime.now()),
          updatedAt: Value(DateTime.now()),
        ),
      );

      final note = await db.notesDao.getNoteById('note-1');
      expect(note, isNotNull);
      expect(note!.title, 'Study Plan: Algorithms');
      expect(note.plainText, contains('Binary Search'));
      expect(note.isPinned, false);
      expect(note.isTrashed, false);
    });

    test('Can pin and unpin notes', () async {
      await db.notesDao.insertNote(
        NotesCompanion(
          id: const Value('note-2'),
          title: const Value('Important Formula Sheet'),
          createdAt: Value(DateTime.now()),
          updatedAt: Value(DateTime.now()),
        ),
      );

      await db.notesDao.togglePin('note-2', false);
      var note = await db.notesDao.getNoteById('note-2');
      expect(note!.isPinned, true);

      await db.notesDao.togglePin('note-2', true);
      note = await db.notesDao.getNoteById('note-2');
      expect(note!.isPinned, false);
    });

    test('Can trash and restore notes', () async {
      await db.notesDao.insertNote(
        NotesCompanion(
          id: const Value('note-3'),
          title: const Value('Old Draft'),
          createdAt: Value(DateTime.now()),
          updatedAt: Value(DateTime.now()),
        ),
      );

      await db.notesDao.trashNote('note-3');
      var note = await db.notesDao.getNoteById('note-3');
      expect(note!.isTrashed, true);
      expect(note.trashedAt, isNotNull);

      await db.notesDao.restoreNote('note-3');
      note = await db.notesDao.getNoteById('note-3');
      expect(note!.isTrashed, false);
      expect(note.trashedAt, isNull);
    });

    test('Can archive and unarchive notes', () async {
      await db.notesDao.insertNote(
        NotesCompanion(
          id: const Value('note-4'),
          title: const Value('Semester 1 Archive'),
          createdAt: Value(DateTime.now()),
          updatedAt: Value(DateTime.now()),
        ),
      );

      await db.notesDao.toggleArchive('note-4', false);
      var note = await db.notesDao.getNoteById('note-4');
      expect(note!.isArchived, true);

      await db.notesDao.toggleArchive('note-4', true);
      note = await db.notesDao.getNoteById('note-4');
      expect(note!.isArchived, false);
    });
  });

  group('FoldersDao Tests', () {
    test('Can create, update, and list folders', () async {
      await db.foldersDao.insertFolder(
        const FoldersCompanion(
          id: Value('folder-1'),
          name: Value('Computer Science'),
          color: Value(0xFF6750A4),
        ),
      );

      final folder = await db.foldersDao.getFolderById('folder-1');
      expect(folder, isNotNull);
      expect(folder!.name, 'Computer Science');

      await db.foldersDao.updateFolder(
        'folder-1',
        const FoldersCompanion(name: Value('CS & Engineering')),
      );

      final updated = await db.foldersDao.getFolderById('folder-1');
      expect(updated!.name, 'CS & Engineering');
    });

    test('Deleting folder moves notes to uncategorized', () async {
      await db.foldersDao.insertFolder(
        const FoldersCompanion(
          id: Value('folder-del'),
          name: Value('Temp Folder'),
        ),
      );

      await db.notesDao.insertNote(
        NotesCompanion(
          id: const Value('note-in-folder'),
          title: const Value('Physics Lecture 1'),
          folderId: const Value('folder-del'),
          createdAt: Value(DateTime.now()),
          updatedAt: Value(DateTime.now()),
        ),
      );

      await db.foldersDao.deleteFolder('folder-del');

      final folder = await db.foldersDao.getFolderById('folder-del');
      expect(folder, isNull);

      final note = await db.notesDao.getNoteById('note-in-folder');
      expect(note, isNotNull);
      expect(note!.folderId, isNull);
    });
  });

  group('TagsDao Tests', () {
    test('Can create tags and associate with notes', () async {
      await db.tagsDao.insertTag(
        const TagsCompanion(
          id: Value('tag-exam'),
          name: Value('Exam Prep'),
          color: Value(0xFFEF5350),
        ),
      );

      await db.notesDao.insertNote(
        NotesCompanion(
          id: const Value('note-tagged'),
          title: const Value('Chemistry Midterm Review'),
          createdAt: Value(DateTime.now()),
          updatedAt: Value(DateTime.now()),
        ),
      );

      await db.notesDao.addTagToNote('note-tagged', 'tag-exam');

      final tags = await db.notesDao.getTagsForNote('note-tagged');
      expect(tags.length, 1);
      expect(tags.first.name, 'Exam Prep');

      await db.notesDao.removeTagFromNote('note-tagged', 'tag-exam');
      final tagsAfter = await db.notesDao.getTagsForNote('note-tagged');
      expect(tagsAfter, isEmpty);
    });
  });
}
