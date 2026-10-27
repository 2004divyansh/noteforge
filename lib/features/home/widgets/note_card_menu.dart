import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:noteforge/core/database/database.dart';
import 'package:noteforge/features/folders/providers/folders_provider.dart';

class NoteCardMenu extends ConsumerWidget {
  const NoteCardMenu({super.key, required this.note});

  final Note note;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.read(databaseProvider);

    return PopupMenuButton<String>(
      iconSize: 20,
      padding: EdgeInsets.zero,
      onSelected: (value) async {
        switch (value) {
          case 'pin':
            await db.notesDao.togglePin(note.id, note.isPinned);
            break;
          case 'archive':
            await db.notesDao.toggleArchive(note.id, note.isArchived);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(note.isArchived ? 'Note unarchived' : 'Note archived'),
                  action: SnackBarAction(
                    label: 'Undo',
                    onPressed: () => db.notesDao.toggleArchive(note.id, !note.isArchived),
                  ),
                ),
              );
            }
            break;
          case 'move':
            if (context.mounted) {
              _showMoveToFolderDialog(context, ref, note);
            }
            break;
          case 'trash':
            await db.notesDao.trashNote(note.id);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Note moved to trash'),
                  action: SnackBarAction(
                    label: 'Undo',
                    onPressed: () => db.notesDao.restoreNote(note.id),
                  ),
                ),
              );
            }
            break;
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'pin',
          child: ListTile(
            leading: Icon(note.isPinned ? Icons.push_pin : Icons.push_pin_outlined),
            title: Text(note.isPinned ? 'Unpin' : 'Pin'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem(
          value: 'archive',
          child: ListTile(
            leading: Icon(note.isArchived ? Icons.unarchive_outlined : Icons.archive_outlined),
            title: Text(note.isArchived ? 'Unarchive' : 'Archive'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        const PopupMenuItem(
          value: 'move',
          child: ListTile(
            leading: Icon(Icons.drive_file_move_outlined),
            title: Text('Move to folder'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        const PopupMenuItem(
          value: 'trash',
          child: ListTile(
            leading: Icon(Icons.delete_outline, color: Colors.red),
            title: Text('Move to trash', style: TextStyle(color: Colors.red)),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
    );
  }

  void _showMoveToFolderDialog(BuildContext context, WidgetRef ref, Note note) {
    final db = ref.read(databaseProvider);
    final foldersAsync = ref.read(foldersProvider);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Move to folder'),
        content: SizedBox(
          width: 300,
          child: foldersAsync.when(
            data: (folders) => ListView(
              shrinkWrap: true,
              children: [
                ListTile(
                  leading: const Icon(Icons.folder_off_outlined),
                  title: const Text('No folder'),
                  selected: note.folderId == null,
                  onTap: () {
                    db.notesDao.moveToFolder(note.id, null);
                    Navigator.pop(context);
                  },
                ),
                ...folders.map(
                  (folder) => ListTile(
                    leading: Icon(Icons.folder, color: Color(folder.color)),
                    title: Text(folder.name),
                    selected: note.folderId == folder.id,
                    onTap: () {
                      db.notesDao.moveToFolder(note.id, folder.id);
                      Navigator.pop(context);
                    },
                  ),
                ),
              ],
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Error: $e'),
          ),
        ),
      ),
    );
  }
}
