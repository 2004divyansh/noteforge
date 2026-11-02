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
  bool _isResetPassword = false;
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final authNotifier = ref.read(authProvider.notifier);

    bool success;
    if (_isResetPassword) {
      success = await authNotifier.resetPassword(
        email: _emailController.text.trim(),
        newPassword: _passwordController.text,
      );
    } else if (_isRegister) {
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
          _errorMessage = ref.read(authProvider).statusMessage ?? 'Authentication failed.';
        }
      });

      if (success) {
        final db = ref.read(databaseProvider);
        authNotifier.syncWithBackend(db);

        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isResetPassword
                  ? 'Password reset successfully! Notes synced.'
                  : (_isRegister ? 'Account created! Notes synced.' : 'Signed in! Notes synced.'),
            ),
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

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 420,
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
                      authState.isAuthenticated
                          ? Icons.account_circle
                          : (_isResetPassword
                              ? Icons.lock_reset
                              : (_isRegister ? Icons.person_add_alt_1 : Icons.lock_outline)),
                      color: theme.colorScheme.primary,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          authState.isAuthenticated
                              ? 'My Account'
                              : (_isResetPassword
                                  ? 'Reset Password'
                                  : (_isRegister ? 'Create Account' : 'Sign In')),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          authState.isAuthenticated
                              ? 'Manage your NoteForge account'
                              : (_isResetPassword
                                  ? 'Choose a new password for your account'
                                  : (_isRegister
                                      ? 'Sync notes across all your devices'
                                      : 'Sign in to access your notes')),
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

              if (authState.isAuthenticated) ...[
                // Logged In View
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: Colors.white,
                        child: Text(
                          (authState.userName != null && authState.userName!.isNotEmpty)
                              ? authState.userName![0].toUpperCase()
                              : 'U',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              authState.userName ?? 'User',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              authState.userEmail ?? '',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            if (authState.lastSyncTime != null) ...[
                              const SizedBox(height: 6),
                              Text(
                                'Last synced at ${authState.lastSyncTime}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.green[700],
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Log Out Button
                OutlinedButton.icon(
                  onPressed: () async {
                    await ref.read(authProvider.notifier).logout();
                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Logged out successfully.')),
                      );
                    }
                  },
                  icon: const Icon(Icons.logout, color: Colors.red),
                  label: const Text('Log Out', style: TextStyle(color: Colors.red)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ] else ...[
                // Auth Form (Login, Register, or Reset Password)
                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_isRegister && !_isResetPassword) ...[
                        TextFormField(
                          controller: _nameController,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(
                            labelText: 'Full Name',
                            prefixIcon: Icon(Icons.person_outline),
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                          validator: (val) =>
                              val == null || val.trim().isEmpty ? 'Please enter your name' : null,
                        ),
                        const SizedBox(height: 14),
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
                        validator: (val) =>
                            val == null || !val.contains('@') ? 'Enter a valid email address' : null,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: _isResetPassword ? 'New Password' : 'Password',
                          prefixIcon: const Icon(Icons.lock_outline),
                          border: const OutlineInputBorder(),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                        validator: (val) =>
                            val == null || val.length < 6 ? 'Password must be at least 6 characters' : null,
                      ),

                      if (!_isRegister && !_isResetPassword) ...[
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () {
                              setState(() {
                                _isResetPassword = true;
                                _errorMessage = null;
                              });
                            },
                            style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.only(top: 4, bottom: 4),
                            ),
                            child: const Text('Forgot password?', style: TextStyle(fontSize: 12)),
                          ),
                        ),
                      ] else ...[
                        const SizedBox(height: 16),
                      ],

                      if (_errorMessage != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
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
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : Text(
                                _isResetPassword
                                    ? 'Reset Password & Sign In'
                                    : (_isRegister ? 'Create Account' : 'Sign In'),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                      ),
                      const SizedBox(height: 12),

                      if (_isResetPassword) ...[
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _isResetPassword = false;
                              _errorMessage = null;
                            });
                          },
                          child: const Text('Back to Sign In'),
                        ),
                      ] else ...[
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _isRegister = !_isRegister;
                              _errorMessage = null;
                            });
                          },
                          child: Text(
                            _isRegister
                                ? 'Already have an account? Sign In'
                                : 'Need an account? Register',
                          ),
                        ),
                      ],
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
