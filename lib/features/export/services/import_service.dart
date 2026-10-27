import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:noteforge/core/database/database.dart';

class ImportService {
  /// Import notes from Markdown or text files
  static Future<void> importNotes(BuildContext context, WidgetRef ref) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['md', 'txt', 'markdown'],
        allowMultiple: true,
        dialogTitle: 'Select files to import',
      );

      if (result == null || result.files.isEmpty) return;

      final db = ref.read(databaseProvider);
      int importedCount = 0;

      for (final platformFile in result.files) {
        if (platformFile.path == null) continue;

        try {
          final file = File(platformFile.path!);
          final content = await file.readAsString();
          final fileName = platformFile.name;

          // Parse the file
          String title;
          String body;

          if (fileName.endsWith('.md') || fileName.endsWith('.markdown')) {
            // Try to extract title from first heading
            final lines = content.split('\n');
            if (lines.isNotEmpty && lines[0].startsWith('# ')) {
              title = lines[0].substring(2).trim();
              body = lines.skip(1).join('\n').trim();
            } else {
              title = fileName.replaceAll(RegExp(r'\.(md|markdown)$'), '');
              body = content;
            }
          } else {
            // Plain text - use filename as title
            title = fileName.replaceAll(RegExp(r'\.txt$'), '');
            body = content;
          }

          // Convert plain text to Quill Delta format
          final delta = [
            {'insert': '$body\n'}
          ];

          final noteId = const Uuid().v4();
          await db.notesDao.insertNote(NotesCompanion(
            id: Value(noteId),
            title: Value(title),
            content: Value(jsonEncode(delta)),
            plainText: Value(body),
            createdAt: Value(DateTime.now()),
            updatedAt: Value(DateTime.now()),
          ));

          importedCount++;
        } catch (e) {
          debugPrint('Failed to import ${platformFile.name}: $e');
        }
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Imported $importedCount note${importedCount == 1 ? '' : 's'}'),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import failed: $e')),
        );
      }
    }
  }

  /// Restore from a NoteForge backup file
  static Future<void> restoreBackup(BuildContext context, WidgetRef ref) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        dialogTitle: 'Select backup file',
      );

      if (result == null || result.files.isEmpty || result.files.first.path == null) return;

      final file = File(result.files.first.path!);
      final content = await file.readAsString();
      final backup = jsonDecode(content) as Map<String, dynamic>;

      if (backup['version'] != 1) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Unsupported backup format')),
          );
        }
        return;
      }

      if (!context.mounted) return;

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Restore Backup'),
          content: const Text(
            'This will add all notes, folders, and tags from the backup. '
            'Existing data will not be deleted. Continue?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Restore'),
            ),
          ],
        ),
      );

      if (confirmed != true) return;

      final db = ref.read(databaseProvider);

      // Restore folders
      final foldersData = backup['folders'] as List<dynamic>? ?? [];
      for (final f in foldersData) {
        try {
          await db.foldersDao.insertFolder(FoldersCompanion(
            id: Value(f['id'] as String),
            name: Value(f['name'] as String),
            color: Value(f['color'] as int),
            parentId: Value(f['parentId'] as String?),
            sortOrder: Value(f['sortOrder'] as int? ?? 0),
          ));
        } catch (_) {
          // Skip duplicates
        }
      }

      // Restore tags
      final tagsData = backup['tags'] as List<dynamic>? ?? [];
      for (final t in tagsData) {
        try {
          await db.tagsDao.insertTag(TagsCompanion(
            id: Value(t['id'] as String),
            name: Value(t['name'] as String),
            color: Value(t['color'] as int),
          ));
        } catch (_) {}
      }

      // Restore notes
      final notesData = backup['notes'] as List<dynamic>? ?? [];
      for (final n in notesData) {
        try {
          await db.notesDao.insertNote(NotesCompanion(
            id: Value(n['id'] as String),
            title: Value(n['title'] as String? ?? ''),
            content: Value(n['content'] as String? ?? '[]'),
            plainText: Value(n['plainText'] as String? ?? ''),
            folderId: Value(n['folderId'] as String?),
            isPinned: Value(n['isPinned'] as bool? ?? false),
            isArchived: Value(n['isArchived'] as bool? ?? false),
            isTrashed: Value(n['isTrashed'] as bool? ?? false),
            trashedAt: Value(n['trashedAt'] != null
                ? DateTime.parse(n['trashedAt'] as String)
                : null),
            createdAt: Value(DateTime.parse(n['createdAt'] as String)),
            updatedAt: Value(DateTime.parse(n['updatedAt'] as String)),
          ));
        } catch (_) {}
      }

      // Restore note-tag relationships
      final noteTagsData = backup['noteTags'] as List<dynamic>? ?? [];
      for (final nt in noteTagsData) {
        try {
          await db.notesDao.addTagToNote(
            nt['noteId'] as String,
            nt['tagId'] as String,
          );
        } catch (_) {}
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Restored ${notesData.length} notes, '
              '${foldersData.length} folders, '
              '${tagsData.length} tags',
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Restore failed: $e')),
        );
      }
    }
  }
}

