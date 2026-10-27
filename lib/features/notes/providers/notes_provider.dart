import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:noteforge/core/database/database.dart';

// Active notes stream
final activeNotesProvider = StreamProvider<List<Note>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.notesDao.watchActiveNotes();
});

// Notes by folder
final notesByFolderProvider = StreamProvider.family<List<Note>, String>((ref, folderId) {
  final db = ref.watch(databaseProvider);
  return db.notesDao.watchNotesByFolder(folderId);
});

// Archived notes
final archivedNotesProvider = StreamProvider<List<Note>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.notesDao.watchArchivedNotes();
});

// Trashed notes
final trashedNotesProvider = StreamProvider<List<Note>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.notesDao.watchTrashedNotes();
});

// Single note
final noteByIdProvider = StreamProvider.family<Note?, String>((ref, noteId) {
  final db = ref.watch(databaseProvider);
  return db.notesDao.watchNoteById(noteId);
});

// Tags for a note
final noteTagsProvider = StreamProvider.family<List<Tag>, String>((ref, noteId) {
  final db = ref.watch(databaseProvider);
  return db.notesDao.watchTagsForNote(noteId);
});

// Search results
final searchQueryProvider = StateProvider<String>((ref) => '');

final searchResultsProvider = StreamProvider<List<Note>>((ref) {
  final query = ref.watch(searchQueryProvider);
  if (query.isEmpty) return Stream.value([]);
  final db = ref.watch(databaseProvider);
  return db.notesDao.searchNotes(query);
});
