import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:noteforge/core/database/database.dart';
import 'package:noteforge/features/auth/providers/auth_provider.dart';

class AuthDialog extends ConsumerStatefulWidget {
  const AuthDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (context) => const AuthDialog(),
    );
  }

  @override
  ConsumerState<AuthDialog> createState() => _AuthDialogState();
}

class _AuthDialogState extends ConsumerState<AuthDialog> {
  bool _isRegister = false;
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _serverUrlController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final authState = ref.read(authProvider);
    _serverUrlController.text = authState.serverUrl;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _serverUrlController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final authNotifier = ref.read(authProvider.notifier);
    authNotifier.updateServerUrl(_serverUrlController.text.trim());

    bool success;
    if (_isRegister) {
      success = await authNotifier.register(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
    } else {
      success = await authNotifier.login(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (!success) {
          _errorMessage = ref.read(authProvider).statusMessage;
        }
      });

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ref.read(authProvider).statusMessage ?? 'Connected!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authState = ref.watch(authProvider);
    final db = ref.watch(databaseProvider);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 440,
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.cloud_sync_rounded,
                      color: theme.colorScheme.primary,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'NoteForge Cloud Backend',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Integrated REST API & SQLite Sync',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(height: 28),

              // Server Status Bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: authState.isServerOnline
                      ? Colors.green.withValues(alpha: 0.12)
                      : Colors.orange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: authState.isServerOnline
                        ? Colors.green.withValues(alpha: 0.3)
                        : Colors.orange.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      authState.isServerOnline ? Icons.check_circle : Icons.warning_amber_rounded,
                      color: authState.isServerOnline ? Colors.green : Colors.orange,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        authState.isServerOnline
                            ? 'Backend Server: ONLINE (Port 5000)'
                            : 'Backend Server: Checking / Offline',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: authState.isServerOnline ? Colors.green[800] : Colors.orange[800],
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () => ref.read(authProvider.notifier).checkServerHealth(),
                      child: const Padding(
                        padding: EdgeInsets.all(4.0),
                        child: Icon(Icons.refresh, size: 18),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              if (authState.isAuthenticated) ...[
                // Logged In View
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const CircleAvatar(
                            radius: 20,
                            child: Icon(Icons.person),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  authState.userName ?? 'Student User',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  authState.userEmail ?? '',
                                  style: theme.textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (authState.lastSyncTime != null)
                        Text(
                          'Last synced: ${authState.lastSyncTime}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.green,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Sync Now Button
                FilledButton.icon(
                  onPressed: authState.isSyncing
                      ? null
                      : () async {
                          final success = await ref
                              .read(authProvider.notifier)
                              .syncWithBackend(db);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  ref.read(authProvider).statusMessage ??
                                      (success ? 'Synced!' : 'Sync failed'),
                                ),
                                backgroundColor: success ? Colors.green : Colors.red,
                              ),
                            );
                          }
                        },
                  icon: authState.isSyncing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.sync),
                  label: Text(authState.isSyncing ? 'Syncing...' : 'Sync Database Now'),
                ),
                const SizedBox(height: 8),

                OutlinedButton(
                  onPressed: () => ref.read(authProvider.notifier).logout(),
                  child: const Text('Log Out'),
                ),
              ] else ...[
                // Auth Form (Login or Register)
                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_isRegister) ...[
                        TextFormField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            labelText: 'Full Name',
                            prefixIcon: Icon(Icons.person_outline),
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                          validator: (val) => val == null || val.trim().isEmpty ? 'Enter your name' : null,
                        ),
                        const SizedBox(height: 12),
                      ],
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Email Address',
                          prefixIcon: Icon(Icons.email_outlined),
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                        validator: (val) => val == null || !val.contains('@') ? 'Enter a valid email' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Password',
                          prefixIcon: Icon(Icons.lock_outline),
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                        validator: (val) => val == null || val.length < 6 ? 'Password must be at least 6 characters' : null,
                      ),
                      const SizedBox(height: 14),

                      // Server URL Configurable field
                      TextFormField(
                        controller: _serverUrlController,
                        decoration: const InputDecoration(
                          labelText: 'Backend Server URL',
                          prefixIcon: Icon(Icons.dns_outlined),
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          helperText: 'Default: http://localhost:5000 (Desktop) or 10.0.2.2 (Android)',
                        ),
                      ),
                      const SizedBox(height: 16),

                      if (_errorMessage != null) ...[
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(color: Colors.red, fontSize: 13),
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],

                      FilledButton(
                        onPressed: _isLoading ? null : _handleSubmit,
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : Text(_isRegister ? 'Create Account & Connect' : 'Log In & Connect'),
                      ),
                      const SizedBox(height: 10),

                      TextButton(
                        onPressed: () {
                          setState(() {
                            _isRegister = !_isRegister;
                            _errorMessage = null;
                          });
                        },
                        child: Text(
                          _isRegister
                              ? 'Already have an account? Log In'
                              : 'Need an account? Register',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
