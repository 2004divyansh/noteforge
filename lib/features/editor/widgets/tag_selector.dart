import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:noteforge/core/database/database.dart';
import 'package:noteforge/features/notes/providers/notes_provider.dart';
import 'package:noteforge/features/tags/providers/tags_provider.dart';

class TagSelector extends ConsumerWidget {
  const TagSelector({super.key, required this.noteId});

  final String noteId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allTagsAsync = ref.watch(tagsProvider);
    final noteTagsAsync = ref.watch(noteTagsProvider(noteId));
    final db = ref.read(databaseProvider);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.label_outline),
              const SizedBox(width: 8),
              Text(
                'Tags',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ],
          ),
          const SizedBox(height: 16),
          allTagsAsync.when(
            data: (allTags) => noteTagsAsync.when(
              data: (noteTags) {
                final noteTagIds = noteTags.map((t) => t.id).toSet();
                
                if (allTags.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('No tags created yet.\nGo to Manage Tags to create some.'),
                    ),
                  );
                }

                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: allTags.map((tag) {
                    final isSelected = noteTagIds.contains(tag.id);
                    return FilterChip(
                      label: Text(tag.name),
                      selected: isSelected,
                      onSelected: (selected) async {
                        if (selected) {
                          await db.notesDao.addTagToNote(noteId, tag.id);
                        } else {
                          await db.notesDao.removeTagFromNote(noteId, tag.id);
                        }
                      },
                      avatar: CircleAvatar(
                        backgroundColor: Color(tag.color),
                        radius: 8,
                      ),
                      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                      selectedColor: Color(tag.color).withValues(alpha: 0.2),
                    );
                  }).toList(),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('Error: $e'),
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Error: $e'),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
