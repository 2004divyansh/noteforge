import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class DeletionTracker {
  static Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File(p.join(dir.path, 'NoteForge', 'deleted_sync.json'));
  }

  static Future<List<String>> getDeletedNoteIds() async {
    try {
      final file = await _file();
      if (await file.exists()) {
        final content = await file.readAsString();
        final list = json.decode(content) as List<dynamic>;
        return list.map((e) => e.toString()).toList();
      }
    } catch (_) {}
    return [];
  }

  static Future<void> trackDeletedNoteId(String id) async {
    try {
      final current = await getDeletedNoteIds();
      if (!current.contains(id)) {
        current.add(id);
        final file = await _file();
        if (!await file.parent.exists()) {
          await file.parent.create(recursive: true);
        }
        await file.writeAsString(json.encode(current));
      }
    } catch (_) {}
  }

  static Future<void> clearDeletedNoteIds(List<String> idsToRemove) async {
    try {
      final current = await getDeletedNoteIds();
      current.removeWhere((id) => idsToRemove.contains(id));
      final file = await _file();
      if (await file.exists()) {
        await file.writeAsString(json.encode(current));
      }
    } catch (_) {}
  }
}
