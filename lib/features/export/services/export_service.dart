import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:noteforge/core/database/database.dart';

class ExportService {
  /// Convert Quill Delta to basic Markdown
  static String _deltaToMarkdown(Document document) {
    final buffer = StringBuffer();
    final delta = document.toDelta();

    for (final op in delta.toList()) {
      if (op.value is String) {
        String text = op.value as String;
        final attrs = op.attributes;

        if (attrs != null) {
          if (attrs.containsKey('header')) {
            final level = attrs['header'] as int;
            buffer.write('${'#' * level} ');
          }
          if (attrs.containsKey('bold') && attrs['bold'] == true) {
            text = '**$text**';
          }
          if (attrs.containsKey('italic') && attrs['italic'] == true) {
            text = '*$text*';
          }
          if (attrs.containsKey('code') && attrs['code'] == true) {
            text = '`$text`';
          }
          if (attrs.containsKey('link')) {
            text = '[$text](${attrs['link']})';
          }
          if (attrs.containsKey('list')) {
            if (attrs['list'] == 'bullet') {
              text = '- $text';
            } else if (attrs['list'] == 'ordered') {
              text = '1. $text';
            } else if (attrs['list'] == 'checked') {
              text = '- [x] $text';
            } else if (attrs['list'] == 'unchecked') {
              text = '- [ ] $text';
            }
          }
          if (attrs.containsKey('blockquote') &&
              attrs['blockquote'] == true) {
            text = '> $text';
          }
          if (attrs.containsKey('code-block') &&
              attrs['code-block'] == true) {
            text = '```\n$text\n```';
          }
        }
        buffer.write(text);
      }
    }

    return buffer.toString();
  }

  /// Export a single note as Markdown
  static Future<void> exportAsMarkdown({
    required String title,
    required Document document,
    required BuildContext context,
  }) async {
    try {
      final markdown = _deltaToMarkdown(document);
      final content = '# $title\n\n$markdown';
      final fileName =
          '${_sanitizeFileName(title.isEmpty ? 'Untitled' : title)}.md';

      final dir = await getApplicationDocumentsDirectory();
      final exportDir = Directory(p.join(dir.path, 'NoteForge', 'exports'));
      if (!await exportDir.exists()) {
        await exportDir.create(recursive: true);
      }

      final file = File(p.join(exportDir.path, fileName));
      await file.writeAsString(content);

      await Share.shareXFiles(
        [XFile(file.path)],
        subject: title.isEmpty ? 'Untitled Note' : title,
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Exported: $fileName')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    }
  }

  /// Export a single note as plain text
  static Future<void> exportAsText({
    required String title,
    required Document document,
    required BuildContext context,
  }) async {
    try {
      final plainText = document.toPlainText();
      final content = '$title\n\n$plainText';
      final fileName =
          '${_sanitizeFileName(title.isEmpty ? 'Untitled' : title)}.txt';

      final dir = await getApplicationDocumentsDirectory();
      final exportDir = Directory(p.join(dir.path, 'NoteForge', 'exports'));
      if (!await exportDir.exists()) {
        await exportDir.create(recursive: true);
      }

      final file = File(p.join(exportDir.path, fileName));
      await file.writeAsString(content);

      await Share.shareXFiles(
        [XFile(file.path)],
        subject: title.isEmpty ? 'Untitled Note' : title,
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Exported: $fileName')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    }
  }

  /// Export a single note as PDF
  static Future<void> exportAsPdf({
    required String title,
    required Document document,
    required BuildContext context,
  }) async {
    try {
      final plainText = document.toPlainText();

      final pdf = pw.Document();
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          build: (pw.Context pdfContext) {
            return [
              pw.Header(
                level: 0,
                child: pw.Text(
                  title.isEmpty ? 'Untitled' : title,
                  style: const pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 12),
              pw.Text(
                plainText,
                style: const pw.TextStyle(fontSize: 12, lineSpacing: 6),
              ),
            ];
          },
        ),
      );

      await Printing.sharePdf(
        bytes: await pdf.save(),
        filename:
            '${_sanitizeFileName(title.isEmpty ? 'Untitled' : title)}.pdf',
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PDF exported')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF export failed: $e')),
        );
      }
    }
  }

  /// Export all notes as Markdown files
  static Future<void> exportAllNotes(
      BuildContext context, WidgetRef ref) async {
    try {
      final db = ref.read(databaseProvider);
      final notes = await (db.select(db.notes)
            ..where((n) => n.isTrashed.equals(false)))
          .get();

      if (notes.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No notes to export')),
          );
        }
        return;
      }

      final dir = await getApplicationDocumentsDirectory();
      final dateStr = DateFormat('yyyy-MM-dd_HH-mm').format(DateTime.now());
      final exportDir =
          Directory(p.join(dir.path, 'NoteForge', 'exports', 'all_$dateStr'));
      if (!await exportDir.exists()) {
        await exportDir.create(recursive: true);
      }

      final files = <XFile>[];
      for (final note in notes) {
        try {
          final doc = Document.fromJson(jsonDecode(note.content));
          final markdown = _deltaToMarkdown(doc);
          final content = '# ${note.title}\n\n$markdown';
          final fileName =
              '${_sanitizeFileName(note.title.isEmpty ? 'Untitled_${note.id.substring(0, 8)}' : note.title)}.md';

          final file = File(p.join(exportDir.path, fileName));
          await file.writeAsString(content);
          files.add(XFile(file.path));
        } catch (_) {
          // Skip malformed notes
        }
      }

      if (files.isNotEmpty) {
        await Share.shareXFiles(files, subject: 'NoteForge Export');
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Exported ${files.length} notes')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    }
  }

  /// Create a full database backup
  static Future<void> createBackup(
      BuildContext context, WidgetRef ref) async {
    try {
      final db = ref.read(databaseProvider);
      final notes = await db.select(db.notes).get();
      final folders = await db.select(db.folders).get();
      final tags = await db.select(db.tags).get();
      final noteTags = await db.select(db.noteTags).get();

      final backup = {
        'version': 1,
        'createdAt': DateTime.now().toIso8601String(),
        'notes': notes
            .map((n) => {
                  'id': n.id,
                  'title': n.title,
                  'content': n.content,
                  'plainText': n.plainText,
                  'folderId': n.folderId,
                  'isPinned': n.isPinned,
                  'isArchived': n.isArchived,
                  'isTrashed': n.isTrashed,
                  'trashedAt': n.trashedAt?.toIso8601String(),
                  'createdAt': n.createdAt.toIso8601String(),
                  'updatedAt': n.updatedAt.toIso8601String(),
                })
            .toList(),
        'folders': folders
            .map((f) => {
                  'id': f.id,
                  'name': f.name,
                  'color': f.color,
                  'parentId': f.parentId,
                  'sortOrder': f.sortOrder,
                  'createdAt': f.createdAt.toIso8601String(),
                })
            .toList(),
        'tags': tags
            .map((t) => {
                  'id': t.id,
                  'name': t.name,
                  'color': t.color,
                  'createdAt': t.createdAt.toIso8601String(),
                })
            .toList(),
        'noteTags': noteTags
            .map((nt) => {
                  'noteId': nt.noteId,
                  'tagId': nt.tagId,
                })
            .toList(),
      };

      final dir = await getApplicationDocumentsDirectory();
      final dateStr = DateFormat('yyyy-MM-dd_HH-mm').format(DateTime.now());
      final backupDir =
          Directory(p.join(dir.path, 'NoteForge', 'backups'));
      if (!await backupDir.exists()) {
        await backupDir.create(recursive: true);
      }

      final file = File(p.join(backupDir.path, 'noteforge_backup_$dateStr.json'));
      await file.writeAsString(
          const JsonEncoder.withIndent('  ').convert(backup));

      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'NoteForge Backup $dateStr',
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Backup created successfully')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Backup failed: $e')),
        );
      }
    }
  }

  static String _sanitizeFileName(String name) {
    return name
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
        .replaceAll(RegExp(r'\s+'), '_')
        .substring(0, name.length > 50 ? 50 : name.length);
  }
}

