import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:noteforge/core/database/database.dart';
import 'package:noteforge/core/router/app_router.dart';
import 'package:noteforge/features/home/widgets/notes_list_view.dart';
import 'package:noteforge/features/home/widgets/notes_grid_view.dart';
import 'package:noteforge/features/home/widgets/app_drawer.dart';
import 'package:noteforge/features/notes/providers/notes_provider.dart';
import 'package:noteforge/features/settings/providers/settings_provider.dart';
import 'package:noteforge/features/folders/providers/folders_provider.dart';
import 'package:noteforge/features/auth/providers/auth_provider.dart';
import 'package:noteforge/features/auth/screens/auth_dialog.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _hasPromptedAuth = false;

  @override
  Widget build(BuildContext context) {
    final selectedFolder = ref.watch(selectedFolderProvider);
    final viewMode = ref.watch(viewModeProvider);
    final notesAsync = selectedFolder != null
        ? ref.watch(notesByFolderProvider(selectedFolder))
        : ref.watch(activeNotesProvider);
    final foldersAsync = ref.watch(foldersProvider);
    final authState = ref.watch(authProvider);
    final db = ref.watch(databaseProvider);

    // Prompt user to sign in or create account on app launch if not authenticated
    if (authState.isInitialized && !authState.isAuthenticated && !_hasPromptedAuth) {
      _hasPromptedAuth = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !ref.read(authProvider).isAuthenticated) {
          AuthDialog.show(context);
        }
      });
    }

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
          // 1. Dedicated Sync Button
          IconButton(
            icon: authState.isSyncing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync),
            tooltip: 'Sync Notes',
            onPressed: authState.isSyncing
                ? null
                : () async {
                    if (authState.isAuthenticated) {
                      final success = await ref
                          .read(authProvider.notifier)
                          .syncWithBackend(db);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(success ? 'Notes synced!' : 'Sync failed. Check connection.'),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      }
                    } else {
                      AuthDialog.show(context);
                    }
                  },
          ),

          // 2. Dedicated My Account Button
          IconButton(
            icon: Icon(
              authState.isAuthenticated
                  ? Icons.account_circle
                  : Icons.account_circle_outlined,
              color: authState.isAuthenticated
                  ? Theme.of(context).colorScheme.primary
                  : null,
            ),
            tooltip: 'My Account',
            onPressed: () {
              AuthDialog.show(context);
            },
          ),

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
              ref.read(viewModeProvider.notifier).toggle();
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
                    Icons.note_alt_outlined,
                    size: 64,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No notes yet',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap the button below to create your first note',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                  ),
                ],
              ),
            );
          }

          return viewMode == ViewMode.grid
              ? NotesGridView(notes: notes)
              : NotesListView(notes: notes);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Text('Error loading notes: $error'),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.pushNamed(
            context,
            AppRouter.editor,
          );
        },
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
        maxChildSize: 0.9,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) {
          return Consumer(
            builder: (context, ref, child) {
              final archivedNotesAsync = ref.watch(archivedNotesProvider);
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      'Archived Notes',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  Expanded(
                    child: archivedNotesAsync.when(
                      data: (notes) {
                        if (notes.isEmpty) {
                          return const Center(child: Text('No archived notes'));
                        }
                        return ListView.builder(
                          controller: scrollController,
                          itemCount: notes.length,
                          itemBuilder: (context, index) {
                            final note = notes[index];
                            return ListTile(
                              title: Text(note.title),
                              subtitle: Text(
                                note.plainText,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.unarchive_outlined),
                                onPressed: () {
                                  final db = ref.read(databaseProvider);
                                  db.notesDao.unarchiveNote(note.id);
                                },
                              ),
                            );
                          },
                        );
                      },
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (error, _) => Center(child: Text('Error: $error')),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
