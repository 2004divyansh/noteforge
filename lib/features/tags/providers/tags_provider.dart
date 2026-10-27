import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:noteforge/core/database/database.dart';

// All tags stream
final tagsProvider = StreamProvider<List<Tag>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.tagsDao.watchAllTags();
});

// Note count per tag
final tagNoteCountProvider = StreamProvider.family<int, String>((ref, tagId) {
  final db = ref.watch(databaseProvider);
  return db.tagsDao.watchNoteCountForTag(tagId);
});
