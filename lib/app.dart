import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:noteforge/core/router/app_router.dart';
import 'package:noteforge/core/theme/app_theme.dart';
import 'package:noteforge/features/auth/providers/auth_provider.dart';
import 'package:noteforge/features/security/providers/security_provider.dart';
import 'package:noteforge/features/security/screens/app_lock_screen.dart';
import 'package:noteforge/features/settings/providers/settings_provider.dart';

class NoteForgeApp extends ConsumerStatefulWidget {
  const NoteForgeApp({super.key});

  @override
  ConsumerState<NoteForgeApp> createState() => _NoteForgeAppState();
}

class _NoteForgeAppState extends ConsumerState<NoteForgeApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      final security = ref.read(securityProvider);
      // Re-lock app when backgrounded, unless biometric prompt is active
      if (!security.isAuthenticatingBiometrics) {
        ref.read(securityProvider.notifier).lock();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final securityState = ref.watch(securityProvider);
    final authState = ref.watch(authProvider);

    // Lock ONLY IF:
    // 1. Lock is enabled by user
    // 2. User is logged in (authState.isAuthenticated)
    // 3. App is currently locked (!securityState.isUnlocked)
    final isLocked = securityState.isLockEnabled &&
        authState.isAuthenticated &&
        !securityState.isUnlocked;

    return MaterialApp(
      title: 'NoteForge',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      initialRoute: AppRouter.home,
      onGenerateRoute: AppRouter.onGenerateRoute,
      builder: (context, child) {
        if (isLocked) {
          return const AppLockScreen();
        }
        return child ?? const SizedBox.shrink();
      },
    );
  }
}
