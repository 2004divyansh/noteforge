import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:noteforge/features/security/providers/security_provider.dart';

class AppLockScreen extends ConsumerStatefulWidget {
  const AppLockScreen({super.key});

  @override
  ConsumerState<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends ConsumerState<AppLockScreen> {
  String _enteredPin = '';
  String? _errorMessage;
  final FocusNode _keyboardFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final securityState = ref.read(securityProvider);
      if (securityState.useBiometrics && securityState.isBiometricsSupported) {
        _triggerBiometricAuth();
      }
      _keyboardFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _keyboardFocusNode.dispose();
    super.dispose();
  }

  Future<void> _triggerBiometricAuth() async {
    final notifier = ref.read(securityProvider.notifier);
    final success = await notifier.unlockWithBiometrics();
    if (!success && mounted) {
      // User can still enter PIN
      _keyboardFocusNode.requestFocus();
    }
  }

  void _onDigitPressed(String digit) {
    if (_enteredPin.length >= 6) return;

    setState(() {
      _errorMessage = null;
      _enteredPin += digit;
    });

    _checkPin();
  }

  void _onBackspacePressed() {
    if (_enteredPin.isEmpty) return;
    setState(() {
      _errorMessage = null;
      _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
    });
  }

  void _onClearPressed() {
    setState(() {
      _errorMessage = null;
      _enteredPin = '';
    });
  }

  Future<void> _checkPin() async {
    // Check if entered pin reaches at least 4 digits
    if (_enteredPin.length >= 4) {
      final notifier = ref.read(securityProvider.notifier);
      final success = await notifier.unlockWithPin(_enteredPin);
      if (success) {
        // App automatically unlocks via provider
      } else {
        // If max length reached or doesn't match
        if (_enteredPin.length == 6) {
          setState(() {
            _errorMessage = 'Incorrect PIN. Please try again.';
            _enteredPin = '';
          });
        }
      }
    }
  }

  void _handleManualSubmit() async {
    if (_enteredPin.isEmpty) return;
    final notifier = ref.read(securityProvider.notifier);
    final success = await notifier.unlockWithPin(_enteredPin);
    if (!success && mounted) {
      setState(() {
        _errorMessage = 'Incorrect PIN. Please try again.';
        _enteredPin = '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final securityState = ref.watch(securityProvider);

    return Scaffold(
      body: KeyboardListener(
        focusNode: _keyboardFocusNode,
        autofocus: true,
        onKeyEvent: (event) {
          if (event is KeyDownEvent) {
            final key = event.logicalKey;
            if (key == LogicalKeyboardKey.backspace) {
              _onBackspacePressed();
            } else if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter) {
              _handleManualSubmit();
            } else if (event.character != null && RegExp(r'^[0-9]$').hasMatch(event.character!)) {
              _onDigitPressed(event.character!);
            }
          }
        },
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Brand Icon & Title
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF6B35), Color(0xFFFFA057)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFF6B35).withValues(alpha: 0.35),
                            blurRadius: 18,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(Icons.lock, color: Colors.white, size: 32),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'NoteForge Locked',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      securityState.useBiometrics && securityState.isBiometricsSupported
                          ? 'Enter your PIN or use biometrics to unlock'
                          : 'Enter your PIN to unlock notes',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 28),

                    // PIN Dots Indicator (up to 6)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(6, (index) {
                        final isFilled = index < _enteredPin.length;
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 7),
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isFilled
                                ? theme.colorScheme.primary
                                : theme.colorScheme.surfaceContainerHighest,
                            border: Border.all(
                              color: isFilled
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.outline.withValues(alpha: 0.5),
                              width: 1.5,
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 20),

                    // Error Message
                    if (_errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.red, fontSize: 13),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ] else
                      const SizedBox(height: 38),

                    // Numeric Keypad
                    _buildKeypad(theme, securityState),

                    const SizedBox(height: 16),

                    // Biometric button banner (if supported)
                    if (securityState.useBiometrics && securityState.isBiometricsSupported) ...[
                      TextButton.icon(
                        onPressed: _triggerBiometricAuth,
                        icon: const Icon(Icons.fingerprint, size: 20),
                        label: const Text('Use Biometrics / Windows Hello'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildKeypad(ThemeData theme, SecurityState securityState) {
    return Column(
      children: [
        _buildKeyRow(theme, ['1', '2', '3']),
        const SizedBox(height: 12),
        _buildKeyRow(theme, ['4', '5', '6']),
        const SizedBox(height: 12),
        _buildKeyRow(theme, ['7', '8', '9']),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Left Action: Biometrics or Clear
            if (securityState.useBiometrics && securityState.isBiometricsSupported)
              _buildActionButton(
                icon: Icons.fingerprint,
                onPressed: _triggerBiometricAuth,
                color: theme.colorScheme.primary,
              )
            else
              _buildActionButton(
                icon: Icons.refresh,
                onPressed: _onClearPressed,
                color: theme.colorScheme.onSurfaceVariant,
              ),

            // Middle: 0
            _buildKeyButton(theme, '0'),

            // Right: Backspace
            _buildActionButton(
              icon: Icons.backspace_outlined,
              onPressed: _onBackspacePressed,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildKeyRow(ThemeData theme, List<String> digits) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: digits.map((d) => _buildKeyButton(theme, d)).toList(),
    );
  }

  Widget _buildKeyButton(ThemeData theme, String digit) {
    return InkWell(
      onTap: () => _onDigitPressed(digit),
      borderRadius: BorderRadius.circular(40),
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
        child: Center(
          child: Text(
            digit,
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required VoidCallback onPressed,
    required Color color,
  }) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(40),
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: 0.1),
        ),
        child: Center(
          child: Icon(icon, color: color, size: 28),
        ),
      ),
    );
  }
}
