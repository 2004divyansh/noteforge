import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:noteforge/core/constants/app_constants.dart';
import 'package:noteforge/core/database/database.dart';
import 'package:noteforge/features/auth/providers/auth_provider.dart';
import 'package:noteforge/features/auth/screens/auth_dialog.dart';
import 'package:noteforge/features/export/services/export_service.dart';
import 'package:noteforge/features/export/services/import_service.dart';
import 'package:noteforge/features/security/providers/security_provider.dart';
import 'package:noteforge/features/security/widgets/app_lock_setup_dialog.dart';
import 'package:noteforge/features/settings/providers/settings_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final themeMode = ref.watch(themeModeProvider);
    final securityState = ref.watch(securityProvider);
    final authState = ref.watch(authProvider);
    final db = ref.watch(databaseProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          // Account & Cloud Sync Section
          const _SectionHeader(title: 'Account & Cloud Sync'),
          ListTile(
            leading: Icon(
              authState.isAuthenticated ? Icons.account_circle : Icons.account_circle_outlined,
              color: authState.isAuthenticated ? Theme.of(context).colorScheme.primary : null,
              size: 28,
            ),
            title: Text(
              authState.isAuthenticated ? (authState.userName ?? 'User') : 'My Account',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              authState.isAuthenticated
                  ? (authState.userEmail ?? '')
                  : 'Sign in or create account to sync notes',
            ),
            trailing: Chip(
              label: Text(
                authState.isAuthenticated ? 'Signed In' : 'Sign In',
                style: const TextStyle(fontSize: 11),
              ),
              backgroundColor: authState.isAuthenticated
                  ? Colors.green.withValues(alpha: 0.15)
                  : Theme.of(context).colorScheme.surfaceContainerHighest,
            ),
            onTap: () => AuthDialog.show(context),
          ),
          if (authState.isAuthenticated)
            ListTile(
              leading: authState.isSyncing
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.sync),
              title: const Text('Sync Notes'),
              subtitle: Text(
                authState.lastSyncTime != null
                    ? 'Last synced at ${authState.lastSyncTime}'
                    : 'Tap to sync latest changes',
              ),
              onTap: authState.isSyncing
                  ? null
                  : () async {
                      final success = await ref
                          .read(authProvider.notifier)
                          .syncWithBackend(db);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(success ? 'Notes synced!' : 'Sync failed. Check connection.'),
                            backgroundColor: success ? Colors.green : Colors.red,
                          ),
                        );
                      }
                    },
            ),
          const Divider(),

          // Appearance section
          const _SectionHeader(title: 'Appearance'),
          ListTile(
            leading: const Icon(Icons.brightness_6),
            title: const Text('Theme'),
            subtitle: Text(_themeModeName(themeMode)),
            onTap: () => _showThemeDialog(context, ref, themeMode),
          ),
          const Divider(),
          // Security section
          const _SectionHeader(title: 'Security'),
          ListTile(
            leading: Icon(
              Icons.fingerprint,
              color: securityState.isLockEnabled ? theme.colorScheme.primary : null,
              size: 28,
            ),
            title: const Text(
              'App Lock',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              securityState.isLockEnabled
                  ? (securityState.useBiometrics && securityState.isBiometricsSupported
                      ? 'Protected with PIN & Biometrics (Windows Hello / Fingerprint)'
                      : 'Protected with PIN Lock')
                  : 'Require biometric or PIN to open app',
            ),
            trailing: Switch(
              value: securityState.isLockEnabled,
              onChanged: (val) {
                if (val) {
                  AppLockSetupDialog.show(context);
                } else {
                  AppLockManageDialog.show(context);
                }
              },
            ),
            onTap: () {
              if (securityState.isLockEnabled) {
                AppLockManageDialog.show(context);
              } else {
                AppLockSetupDialog.show(context);
              }
            },
          ),
          const Divider(),
          // Data section
          const _SectionHeader(title: 'Data'),
          ListTile(
            leading: const Icon(Icons.file_upload_outlined),
            title: const Text('Import Notes'),
            subtitle: const Text('Import from Markdown or text files'),
            onTap: () => ImportService.importNotes(context, ref),
          ),
          ListTile(
            leading: const Icon(Icons.file_download_outlined),
            title: const Text('Export All Notes'),
            subtitle: const Text('Export all notes as Markdown files'),
            onTap: () => ExportService.exportAllNotes(context, ref),
          ),
          ListTile(
            leading: const Icon(Icons.backup_outlined),
            title: const Text('Create Backup'),
            subtitle: const Text('Save a local backup of all data'),
            onTap: () => ExportService.createBackup(context, ref),
          ),
          const Divider(),
          // About section
          const _SectionHeader(title: 'About'),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text(AppConstants.appName),
            subtitle: Text('Version ${AppConstants.appVersion}'),
          ),
        ],
      ),
    );
  }

  String _themeModeName(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
      case ThemeMode.system:
        return 'System default';
    }
  }

  void _showThemeDialog(
      BuildContext context, WidgetRef ref, ThemeMode current) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choose Theme'),
        content: RadioGroup<ThemeMode>(
          groupValue: current,
          onChanged: (value) {
            if (value != null) {
              ref.read(themeModeProvider.notifier).setThemeMode(value);
              Navigator.pop(context);
            }
          },
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<ThemeMode>(
                title: Text('System default'),
                value: ThemeMode.system,
              ),
              RadioListTile<ThemeMode>(
                title: Text('Light'),
                value: ThemeMode.light,
              ),
              RadioListTile<ThemeMode>(
                title: Text('Dark'),
                value: ThemeMode.dark,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

