import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:noteforge/core/router/app_router.dart';
import 'package:noteforge/features/folders/providers/folders_provider.dart';
import 'package:noteforge/features/settings/providers/settings_provider.dart';

class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final foldersAsync = ref.watch(foldersProvider);
    final selectedFolder = ref.watch(selectedFolderProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return NavigationDrawer(
      selectedIndex: _getSelectedIndex(selectedFolder),
      onDestinationSelected: (index) {
        Navigator.pop(context); // Close drawer
        foldersAsync.whenData((folders) {
          if (index == 0) {
            ref.read(selectedFolderProvider.notifier).state = null;
          } else if (index <= folders.length) {
            ref.read(selectedFolderProvider.notifier).state = folders[index - 1].id;
          }
        });
      },
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 16, 16, 10),
          child: Row(
            children: [
              Icon(Icons.auto_awesome, color: colorScheme.primary, size: 28),
              const SizedBox(width: 12),
              Text(
                'NoteForge',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const Divider(indent: 28, endIndent: 28),
        const NavigationDrawerDestination(
          icon: Icon(Icons.notes_outlined),
          selectedIcon: Icon(Icons.notes),
          label: Text('All Notes'),
        ),
        ...foldersAsync.when(
          data: (folders) => folders.map(
            (folder) => NavigationDrawerDestination(
              icon: Icon(Icons.folder_outlined, color: Color(folder.color)),
              selectedIcon: Icon(Icons.folder, color: Color(folder.color)),
              label: Text(folder.name),
            ),
          ),
          loading: () => [const SizedBox.shrink()],
          error: (_, __) => [const SizedBox.shrink()],
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 28),
          child: Divider(),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: ListTile(
            leading: const Icon(Icons.create_new_folder_outlined),
            title: const Text('Manage Folders'),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, AppRouter.folders);
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: ListTile(
            leading: const Icon(Icons.label_outline),
            title: const Text('Manage Tags'),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, AppRouter.tags);
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: ListTile(
            leading: const Icon(Icons.delete_outline),
            title: const Text('Trash'),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, AppRouter.trash);
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: ListTile(
            leading: const Icon(Icons.settings_outlined),
            title: const Text('Settings'),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, AppRouter.settings);
            },
          ),
        ),
      ],
    );
  }

  int _getSelectedIndex(String? selectedFolder) {
    if (selectedFolder == null) return 0;
    return -1; // Will be calculated dynamically
  }
}
