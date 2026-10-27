import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:noteforge/core/database/database.dart';
import 'package:noteforge/features/editor/widgets/editor_toolbar.dart';
import 'package:noteforge/features/editor/widgets/tag_selector.dart';
import 'package:noteforge/features/export/services/export_service.dart';

class EditorScreen extends ConsumerStatefulWidget {
  const EditorScreen({super.key, this.noteId});

  final String? noteId;

  @override
  ConsumerState<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends ConsumerState<EditorScreen> {
  late QuillController _quillController;
  late TextEditingController _titleController;
  late String _noteId;
  bool _isNewNote = true;
  bool _hasUnsavedChanges = false;
  final FocusNode _editorFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _noteId = widget.noteId ?? const Uuid().v4();
    _isNewNote = widget.noteId == null;
    _titleController = TextEditingController();
    _quillController = QuillController.basic();

    _titleController.addListener(_onContentChanged);
    _quillController.addListener(_onContentChanged);

    if (!_isNewNote) {
      _loadNote();
    }
  }

  void _onContentChanged() {
    if (!_hasUnsavedChanges) {
      setState(() => _hasUnsavedChanges = true);
    }
  }

  Future<void> _loadNote() async {
    final db = ref.read(databaseProvider);
    final note = await db.notesDao.getNoteById(_noteId);
    if (note != null && mounted) {
      setState(() {
        _titleController.text = note.title;
        try {
          final doc = Document.fromJson(jsonDecode(note.content));
          _quillController.dispose();
          _quillController = QuillController(
            document: doc,
            selection: const TextSelection.collapsed(offset: 0),
          );
          _quillController.addListener(_onContentChanged);
        } catch (_) {
          // If content can't be parsed, start with empty document
        }
        _hasUnsavedChanges = false;
      });
    }
  }

  Future<void> _saveNote() async {
    final db = ref.read(databaseProvider);
    final content = jsonEncode(_quillController.document.toDelta().toJson());
    final plainText = _quillController.document.toPlainText().trim();
    final title = _titleController.text.trim();

    if (title.isEmpty && plainText.isEmpty && _isNewNote) {
      return; // Don't save empty new notes
    }

    final noteData = NotesCompanion(
      id: Value(_noteId),
      title: Value(title),
      content: Value(content),
      plainText: Value(plainText),
      updatedAt: Value(DateTime.now()),
    );

    if (_isNewNote) {
      await db.notesDao.insertNote(NotesCompanion(
        id: Value(_noteId),
        title: Value(title),
        content: Value(content),
        plainText: Value(plainText),
        createdAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
      ));
      _isNewNote = false;
    } else {
      await db.notesDao.updateNote(_noteId, noteData);
    }

    setState(() => _hasUnsavedChanges = false);
  }

  @override
  void dispose() {
    if (_hasUnsavedChanges) {
      _saveNote();
    }
    _titleController.dispose();
    _quillController.dispose();
    _editorFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (_hasUnsavedChanges) {
          _saveNote();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isNewNote ? 'New Note' : 'Edit Note'),
          actions: [
            if (_hasUnsavedChanges)
              TextButton.icon(
                onPressed: () {
                  _saveNote();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Note saved'),
                        duration: Duration(seconds: 1)),
                  );
                },
                icon: const Icon(Icons.save_outlined, size: 20),
                label: const Text('Save'),
              ),
            if (!_isNewNote)
              IconButton(
                icon: const Icon(Icons.label_outline),
                onPressed: () => _showTagSelector(context),
                tooltip: 'Tags',
              ),
            PopupMenuButton<String>(
              onSelected: (value) => _handleMenuAction(value, context),
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'export_md',
                  child: ListTile(
                    leading: Icon(Icons.description_outlined),
                    title: Text('Export as Markdown'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuItem(
                  value: 'export_txt',
                  child: ListTile(
                    leading: Icon(Icons.text_snippet_outlined),
                    title: Text('Export as Text'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuItem(
                  value: 'export_pdf',
                  child: ListTile(
                    leading: Icon(Icons.picture_as_pdf_outlined),
                    title: Text('Export as PDF'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                if (!_isNewNote) ...[
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                    value: 'delete',
                    child: ListTile(
                      leading: Icon(Icons.delete_outline, color: Colors.red),
                      title: Text('Move to trash',
                          style: TextStyle(color: Colors.red)),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
        body: Column(
          children: [
            // Title field
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: TextField(
                controller: _titleController,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                decoration: const InputDecoration(
                  hintText: 'Title',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
                maxLines: null,
                textInputAction: TextInputAction.next,
                onSubmitted: (_) => _editorFocusNode.requestFocus(),
              ),
            ),
            const Divider(indent: 16, endIndent: 16),
            // Quill editor
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: QuillEditor(
                  controller: _quillController,
                  focusNode: _editorFocusNode,
                  scrollController: _scrollController,
                  config: QuillEditorConfig(
                    placeholder: 'Start writing...',
                    padding: const EdgeInsets.all(8),
                    autoFocus: _isNewNote,
                    expands: true,
                  ),
                ),
              ),
            ),
            // Toolbar
            EditorToolbar(controller: _quillController),
          ],
        ),
      ),
    );
  }

  void _showTagSelector(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => TagSelector(noteId: _noteId),
    );
  }

  void _handleMenuAction(String action, BuildContext context) async {
    await _saveNote();
    if (!context.mounted) return;
    switch (action) {
      case 'export_md':
        await ExportService.exportAsMarkdown(
          title: _titleController.text,
          document: _quillController.document,
          context: context,
        );
        break;
      case 'export_txt':
        await ExportService.exportAsText(
          title: _titleController.text,
          document: _quillController.document,
          context: context,
        );
        break;
      case 'export_pdf':
        await ExportService.exportAsPdf(
          title: _titleController.text,
          document: _quillController.document,
          context: context,
        );
        break;
      case 'delete':
        final db = ref.read(databaseProvider);
        await db.notesDao.trashNote(_noteId);
        if (context.mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Note moved to trash')),
          );
        }
        break;
    }
  }
}
