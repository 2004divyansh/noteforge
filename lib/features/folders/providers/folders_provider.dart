import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:noteforge/core/database/database.dart';

// All folders stream
final foldersProvider = StreamProvider<List<Folder>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.foldersDao.watchAllFolders();
});

// Note count per folder
final folderNoteCountProvider = StreamProvider.family<int, String>((ref, folderId) {
  final db = ref.watch(databaseProvider);
  return db.foldersDao.watchNoteCountForFolder(folderId);
});
