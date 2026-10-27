import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:noteforge/core/database/database.dart';
import 'package:noteforge/core/router/app_router.dart';
import 'package:noteforge/features/home/widgets/note_card_menu.dart';

class NotesListView extends ConsumerWidget {
  const NotesListView({
    super.key,
    required this.notes,
    this.scrollController,
  });

  final List<Note> notes;
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      itemCount: notes.length,
      itemBuilder: (context, index) {
        final note = notes[index];
        return _NoteListTile(note: note);
      },
    );
  }
}

class _NoteListTile extends ConsumerWidget {
  const _NoteListTile({required this.note});

  final Note note;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final dateFormat = DateFormat('MMM d, yyyy');

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 2),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: note.isPinned
            ? Icon(Icons.push_pin, color: colorScheme.primary, size: 20)
            : null,
        title: Text(
          note.title.isEmpty ? 'Untitled' : note.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (note.plainText.isNotEmpty)
              Text(
                note.plainText,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: colorScheme.onSurfaceVariant),
              ),
            const SizedBox(height: 4),
            Text(
              dateFormat.format(note.updatedAt),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: colorScheme.outline,
              ),
            ),
          ],
        ),
        trailing: NoteCardMenu(note: note),
        onTap: () => Navigator.pushNamed(
          context,
          AppRouter.editor,
          arguments: note.id,
        ),
      ),
    );
  }
}
