import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:noteforge/features/security/services/security_service.dart';

final securityServiceProvider = Provider<SecurityService>((ref) {
  return SecurityService();
});

class SecurityState {
  const SecurityState({
    this.isInitialized = false,
    this.isLockEnabled = false,
    this.pinHash,
    this.useBiometrics = false,
    this.isBiometricsSupported = false,
    this.isUnlocked = false,
    this.isAuthenticatingBiometrics = false,
  });

  final bool isInitialized;
  final bool isLockEnabled;
  final String? pinHash;
  final bool useBiometrics;
  final bool isBiometricsSupported;
  final bool isUnlocked;
  final bool isAuthenticatingBiometrics;

  bool get hasPin => pinHash != null && pinHash!.isNotEmpty;

  SecurityState copyWith({
    bool? isInitialized,
    bool? isLockEnabled,
    String? pinHash,
    bool? useBiometrics,
    bool? isBiometricsSupported,
    bool? isUnlocked,
    bool? isAuthenticatingBiometrics,
  }) {
    return SecurityState(
      isInitialized: isInitialized ?? this.isInitialized,
      isLockEnabled: isLockEnabled ?? this.isLockEnabled,
      pinHash: pinHash ?? this.pinHash,
      useBiometrics: useBiometrics ?? this.useBiometrics,
      isBiometricsSupported: isBiometricsSupported ?? this.isBiometricsSupported,
      isUnlocked: isUnlocked ?? this.isUnlocked,
      isAuthenticatingBiometrics:
          isAuthenticatingBiometrics ?? this.isAuthenticatingBiometrics,
    );
  }
}

class SecurityNotifier extends StateNotifier<SecurityState> {
  SecurityNotifier(this._service) : super(const SecurityState()) {
    _init();
  }

  final SecurityService _service;

  Future<void> _init() async {
    final data = await _service.loadSecurityData();
    final isSupported = await _service.isBiometricsSupported();

    final isLockEnabled = data['isLockEnabled'] as bool? ?? false;
    final pinHash = data['pinHash'] as String?;
    final useBiometrics = data['useBiometrics'] as bool? ?? false;

    state = state.copyWith(
      isInitialized: true,
      isLockEnabled: isLockEnabled,
      pinHash: pinHash,
      useBiometrics: useBiometrics,
      isBiometricsSupported: isSupported,
      // If lock is enabled, start locked until verified; otherwise unlocked
      isUnlocked: !isLockEnabled,
    );
  }

  bool verifyPin(String pin) {
    if (state.pinHash == null) return false;
    return SecurityService.hashPin(pin) == state.pinHash;
  }

  Future<bool> unlockWithPin(String pin) async {
    if (verifyPin(pin)) {
      state = state.copyWith(isUnlocked: true);
      return true;
    }
    return false;
  }

  Future<bool> unlockWithBiometrics() async {
    if (!state.useBiometrics) return false;

    state = state.copyWith(isAuthenticatingBiometrics: true);
    final success = await _service.authenticateBiometrics();
    state = state.copyWith(
      isAuthenticatingBiometrics: false,
      isUnlocked: success ? true : state.isUnlocked,
    );
    return success;
  }

  Future<void> enableLock({
    required String pin,
    required bool useBiometrics,
  }) async {
    final hash = SecurityService.hashPin(pin);
    await _service.saveSecurityData(
      isLockEnabled: true,
      pinHash: hash,
      useBiometrics: useBiometrics,
    );

    state = state.copyWith(
      isLockEnabled: true,
      pinHash: hash,
      useBiometrics: useBiometrics,
      isUnlocked: true,
    );
  }

  Future<void> disableLock() async {
    await _service.saveSecurityData(
      isLockEnabled: false,
      pinHash: null,
      useBiometrics: false,
    );

    state = state.copyWith(
      isLockEnabled: false,
      pinHash: null,
      useBiometrics: false,
      isUnlocked: true,
    );
  }

  Future<void> changePin(String newPin) async {
    final hash = SecurityService.hashPin(newPin);
    await _service.saveSecurityData(
      isLockEnabled: true,
      pinHash: hash,
      useBiometrics: state.useBiometrics,
    );

    state = state.copyWith(pinHash: hash);
  }

  Future<void> setUseBiometrics(bool enabled) async {
    await _service.saveSecurityData(
      isLockEnabled: state.isLockEnabled,
      pinHash: state.pinHash,
      useBiometrics: enabled,
    );

    state = state.copyWith(useBiometrics: enabled);
  }

  void lock() {
    if (state.isLockEnabled) {
      state = state.copyWith(isUnlocked: false);
    }
  }

  void unlock() {
    state = state.copyWith(isUnlocked: true);
  }
}

final securityProvider =
    StateNotifierProvider<SecurityNotifier, SecurityState>((ref) {
  final service = ref.watch(securityServiceProvider);
  return SecurityNotifier(service);
});
