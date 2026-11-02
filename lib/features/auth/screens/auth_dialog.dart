import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:noteforge/core/database/database.dart';
import 'package:noteforge/core/services/api_service.dart';
import 'package:noteforge/features/auth/providers/auth_provider.dart';
import 'package:url_launcher/url_launcher.dart';

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

  Future<void> _launchOAuthUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
    } catch (_) {}
    try {
      if (Platform.isWindows) {
        await Process.run('cmd', ['/c', 'start', '', url]);
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', [url]);
      } else if (Platform.isMacOS) {
        await Process.run('open', [url]);
      }
    } catch (_) {}
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    HttpServer? loopbackServer;
    int? port;

    try {
      loopbackServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      port = loopbackServer.port;
    } catch (e) {
      debugPrint('Could not bind loopback server: $e');
    }

    final authUrl = ApiService.instance.getGoogleOAuthStartUrl(redirectPort: port);

    // Launch browser for Google OAuth flow
    await _launchOAuthUrl(authUrl);

    if (!mounted) {
      loopbackServer?.close(force: true);
      return;
    }

    final codeController = TextEditingController();
    bool dialogOpen = true;

    StreamSubscription<HttpRequest>? loopbackSub;
    if (loopbackServer != null) {
      loopbackSub = loopbackServer.listen((HttpRequest request) async {
        if (request.uri.path == '/callback') {
          final token = request.uri.queryParameters['token'];
          final email = request.uri.queryParameters['email'] ?? 'Google User';
          final name = request.uri.queryParameters['name'] ?? email.split('@')[0];

          request.response.headers.contentType = ContentType.html;
          request.response.write('''
            <!DOCTYPE html>
            <html>
            <head><title>Signed In</title></head>
            <body style="font-family:sans-serif;text-align:center;padding:50px;">
              <h2 style="color:#10b981;">✓ Successfully Signed In!</h2>
              <p>You can close this tab and return to NoteForge.</p>
              <script>setTimeout(function(){ window.close(); }, 1500);</script>
            </body>
            </html>
          ''');
          await request.response.close();

          if (token != null && mounted) {
            final authNotifier = ref.read(authProvider.notifier);
            await authNotifier.loginWithGoogleOAuthToken(
              token: token,
              email: Uri.decodeComponent(email),
              name: Uri.decodeComponent(name),
            );

            final db = ref.read(databaseProvider);
            authNotifier.syncWithBackend(db);

            if (dialogOpen && mounted) {
              Navigator.of(context, rootNavigator: true).pop(true);
            }
          }
        }
      });
    }

    bool isSubmittingCode = false;
    String? dialogError;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            title: const Row(
              children: [
                GoogleLogoIcon(size: 24),
                SizedBox(width: 12),
                Text('Google Sign-In', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'We opened Google Sign-In in your browser. Choose your Google Account there to continue.',
                    style: TextStyle(fontSize: 13, height: 1.4),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(ctx).colorScheme.primaryContainer.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      children: [
                        SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Listening for browser sign-in...',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      const Expanded(child: Divider()),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Text(
                          'OR ENTER CODE',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(ctx).colorScheme.outline,
                          ),
                        ),
                      ),
                      const Expanded(child: Divider()),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'If the browser displayed a 6-digit code, enter it below:',
                    style: TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: codeController,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 22, letterSpacing: 8, fontWeight: FontWeight.bold),
                    decoration: const InputDecoration(
                      hintText: '000000',
                      counterText: '',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                  if (dialogError != null) ...[
                    const SizedBox(height: 8),
                    Text(dialogError!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: isSubmittingCode
                    ? null
                    : () async {
                        final code = codeController.text.trim();
                        if (code.length != 6) {
                          setDialogState(() {
                            dialogError = 'Please enter the 6-digit code from the browser.';
                          });
                          return;
                        }
                        setDialogState(() {
                          isSubmittingCode = true;
                          dialogError = null;
                        });
                        final authNotifier = ref.read(authProvider.notifier);
                        final success = await authNotifier.loginWithGoogleCode(code);
                        if (success) {
                          final db = ref.read(databaseProvider);
                          authNotifier.syncWithBackend(db);
                          if (ctx.mounted) Navigator.pop(ctx, true);
                        } else {
                          setDialogState(() {
                            isSubmittingCode = false;
                            dialogError = ref.read(authProvider).statusMessage ?? 'Invalid code.';
                          });
                        }
                      },
                child: const Text('Verify Code'),
              ),
            ],
          );
        },
      ),
    );

    dialogOpen = false;
    await loopbackSub?.cancel();
    await loopbackServer?.close(force: true);

    if (mounted) {
      setState(() {
        _isLoading = false;
      });

      if (result == true) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Signed in with Google! Notes synced.'),
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
                // Google OAuth Button
                OutlinedButton.icon(
                  onPressed: _isLoading ? null : _handleGoogleSignIn,
                  icon: const GoogleLogoIcon(size: 20),
                  label: const Text(
                    'Continue with Google',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 16),

                // Divider OR
                Row(
                  children: [
                    const Expanded(child: Divider()),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'OR',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.outline,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const Expanded(child: Divider()),
                  ],
                ),
                const SizedBox(height: 16),

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

class GoogleLogoIcon extends StatelessWidget {
  const GoogleLogoIcon({super.key, this.size = 20});
  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _GoogleLogoPainter(),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double s = size.width;
    final center = Offset(s / 2, s / 2);
    final radius = s * 0.44;
    final strokeWidth = s * 0.19;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    final rect = Rect.fromCircle(center: center, radius: radius - strokeWidth / 2);

    // Red (top)
    paint.color = const Color(0xFFEA4335);
    canvas.drawArc(rect, -2.4, 1.35, false, paint);

    // Yellow (left)
    paint.color = const Color(0xFFFBBC05);
    canvas.drawArc(rect, -1.05, 1.15, false, paint);

    // Green (bottom)
    paint.color = const Color(0xFF34A853);
    canvas.drawArc(rect, 0.1, 1.35, false, paint);

    // Blue (right)
    paint.color = const Color(0xFF4285F4);
    canvas.drawArc(rect, 1.45, 0.95, false, paint);

    // Blue horizontal crossbar
    final barPaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.fill;
    canvas.drawRect(
      Rect.fromLTRB(s * 0.46, s * 0.41, s * 0.92, s * 0.59),
      barPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
