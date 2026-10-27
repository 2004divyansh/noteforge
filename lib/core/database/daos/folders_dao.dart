import 'package:drift/drift.dart';
import 'package:noteforge/core/database/database.dart';
import 'package:noteforge/core/database/tables.dart';

part 'folders_dao.g.dart';

@DriftAccessor(tables: [Folders, Notes])
class FoldersDao extends DatabaseAccessor<AppDatabase> with _$FoldersDaoMixin {
  FoldersDao(super.db);

  // Watch all folders
  Stream<List<Folder>> watchAllFolders() {
    return (select(folders)
      ..orderBy([(f) => OrderingTerm(expression: f.sortOrder)]))
        .watch();
  }

  // Get all folders
  Future<List<Folder>> getAllFolders() {
    return (select(folders)
      ..orderBy([(f) => OrderingTerm(expression: f.sortOrder)]))
        .get();
  }

  // Get folder by ID
  Future<Folder?> getFolderById(String id) {
    return (select(folders)..where((f) => f.id.equals(id))).getSingleOrNull();
  }

  // Insert folder
  Future<void> insertFolder(FoldersCompanion folder) {
    return into(folders).insert(folder);
  }

  // Update folder
  Future<void> updateFolder(String id, FoldersCompanion folder) {
    return (update(folders)..where((f) => f.id.equals(id))).write(folder);
  }

  // Delete folder (moves notes to uncategorized)
  Future<void> deleteFolder(String id) async {
    // Move all notes in this folder to uncategorized
    await (update(notes)..where((n) => n.folderId.equals(id))).write(
      const NotesCompanion(folderId: Value(null)),
    );
    // Delete the folder
    await (delete(folders)..where((f) => f.id.equals(id))).go();
  }

  // Get note count for folder
  Stream<int> watchNoteCountForFolder(String folderId) {
    final count = countAll();
    final query = selectOnly(notes)
      ..where(notes.folderId.equals(folderId) & notes.isTrashed.equals(false))
      ..addColumns([count]);
    return query.watchSingle().map((row) => row.read(count) ?? 0);
  }

  // Reorder folders
  Future<void> reorderFolders(List<String> folderIds) async {
    await transaction(() async {
      for (var i = 0; i < folderIds.length; i++) {
        await (update(folders)..where((f) => f.id.equals(folderIds[i]))).write(
          FoldersCompanion(sortOrder: Value(i)),
        );
      }
    });
  }
}
