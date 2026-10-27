import 'package:drift/drift.dart';
import 'package:noteforge/core/database/database.dart';
import 'package:noteforge/core/database/tables.dart';

part 'tags_dao.g.dart';

@DriftAccessor(tables: [Tags, NoteTags])
class TagsDao extends DatabaseAccessor<AppDatabase> with _$TagsDaoMixin {
  TagsDao(super.db);

  // Watch all tags
  Stream<List<Tag>> watchAllTags() {
    return (select(tags)
      ..orderBy([(t) => OrderingTerm(expression: t.name)]))
        .watch();
  }

  // Get all tags
  Future<List<Tag>> getAllTags() {
    return (select(tags)
      ..orderBy([(t) => OrderingTerm(expression: t.name)]))
        .get();
  }

  // Get tag by ID
  Future<Tag?> getTagById(String id) {
    return (select(tags)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  // Insert tag
  Future<void> insertTag(TagsCompanion tag) {
    return into(tags).insert(tag);
  }

  // Update tag
  Future<void> updateTag(String id, TagsCompanion tag) {
    return (update(tags)..where((t) => t.id.equals(id))).write(tag);
  }

  // Delete tag
  Future<void> deleteTag(String id) async {
    await (delete(noteTags)..where((nt) => nt.tagId.equals(id))).go();
    await (delete(tags)..where((t) => t.id.equals(id))).go();
  }

  // Get note count for tag
  Stream<int> watchNoteCountForTag(String tagId) {
    final count = countAll();
    final query = selectOnly(noteTags)
      ..where(noteTags.tagId.equals(tagId))
      ..addColumns([count]);
    return query.watchSingle().map((row) => row.read(count) ?? 0);
  }
}
