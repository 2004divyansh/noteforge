import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:noteforge/core/router/app_router.dart';
import 'package:noteforge/features/home/widgets/notes_list_view.dart';
import 'package:noteforge/features/home/widgets/notes_grid_view.dart';
import 'package:noteforge/features/home/widgets/app_drawer.dart';
import 'package:noteforge/features/notes/providers/notes_provider.dart';
import 'package:noteforge/features/settings/providers/settings_provider.dart';
import 'package:noteforge/features/folders/providers/folders_provider.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedFolder = ref.watch(selectedFolderProvider);
    final viewMode = ref.watch(viewModeProvider);
    final notesAsync = selectedFolder != null
        ? ref.watch(notesByFolderProvider(selectedFolder))
        : ref.watch(activeNotesProvider);
    final foldersAsync = ref.watch(foldersProvider);

    // Get folder name for title
    String title = 'All Notes';
    if (selectedFolder != null) {
      foldersAsync.whenData((folders) {
        final folder = folders.where((f) => f.id == selectedFolder).firstOrNull;
        if (folder != null) title = folder.name;
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => Navigator.pushNamed(context, AppRouter.search),
            tooltip: 'Search notes',
          ),
          IconButton(
            icon: Icon(
              viewMode == ViewMode.grid ? Icons.view_list : Icons.grid_view,
            ),
            onPressed: () {
              ref.read(viewModeProvider.notifier).state =
                  viewMode == ViewMode.grid ? ViewMode.list : ViewMode.grid;
            },
            tooltip: viewMode == ViewMode.grid ? 'List view' : 'Grid view',
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'archived':
                  _showArchivedNotes(context);
                  break;
                case 'settings':
                  Navigator.pushNamed(context, AppRouter.settings);
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'archived',
                child: ListTile(
                  leading: Icon(Icons.archive_outlined),
                  title: Text('Archived'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'settings',
                child: ListTile(
                  leading: Icon(Icons.settings_outlined),
                  title: Text('Settings'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      drawer: const AppDrawer(),
      body: notesAsync.when(
        data: (notes) {
          if (notes.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.note_add_outlined,
                    size: 80,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No notes yet',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap + to create your first note',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                ],
              ),
            );
          }

          if (viewMode == ViewMode.grid) {
            return NotesGridView(notes: notes);
          }
          return NotesListView(notes: notes);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Text('Error loading notes: $error'),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.pushNamed(context, AppRouter.editor),
        icon: const Icon(Icons.add),
        label: const Text('New Note'),
      ),
    );
  }

  void _showArchivedNotes(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Consumer(
          builder: (context, ref, _) {
            final archivedAsync = ref.watch(archivedNotesProvider);
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(Icons.archive_outlined),
                      const SizedBox(width: 8),
                      Text(
                        'Archived Notes',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ],
                  ),
                ),
                const Divider(),
                Expanded(
                  child: archivedAsync.when(
                    data: (notes) {
                      if (notes.isEmpty) {
                        return const Center(child: Text('No archived notes'));
                      }
                      return NotesListView(
                        notes: notes,
                        scrollController: scrollController,
                      );
                    },
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(child: Text('Error: $e')),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
