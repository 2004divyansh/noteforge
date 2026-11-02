import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class SecurityService {
  SecurityService({LocalAuthentication? localAuth})
      : _localAuth = localAuth ?? LocalAuthentication();

  final LocalAuthentication _localAuth;

  static String hashPin(String pin) {
    final bytes = utf8.encode('noteforge_secure_pin_salt_$pin');
    return sha256.convert(bytes).toString();
  }

  Future<File> _getFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File(p.join(dir.path, 'NoteForge', 'security.json'));
  }

  Future<Map<String, dynamic>> loadSecurityData() async {
    try {
      final file = await _getFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        return json.decode(content) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('Error loading security data: $e');
    }
    return {
      'isLockEnabled': false,
      'pinHash': null,
      'useBiometrics': false,
    };
  }

  Future<void> saveSecurityData({
    required bool isLockEnabled,
    String? pinHash,
    required bool useBiometrics,
  }) async {
    try {
      final file = await _getFile();
      if (!await file.parent.exists()) {
        await file.parent.create(recursive: true);
      }
      final data = {
        'isLockEnabled': isLockEnabled,
        'pinHash': pinHash,
        'useBiometrics': useBiometrics,
      };
      await file.writeAsString(json.encode(data));
    } catch (e) {
      debugPrint('Error saving security data: $e');
    }
  }

  Future<bool> isBiometricsSupported() async {
    try {
      final isSupported = await _localAuth.isDeviceSupported();
      final canCheck = await _localAuth.canCheckBiometrics;
      return isSupported && canCheck;
    } catch (e) {
      debugPrint('Biometrics check error: $e');
      return false;
    }
  }

  Future<bool> authenticateBiometrics() async {
    try {
      return await _localAuth.authenticate(
        localizedReason: 'Authenticate to access NoteForge',
        biometricOnly: false,
        persistAcrossBackgrounding: true,
      );
    } catch (e) {
      debugPrint('Biometric authentication error: $e');
      return false;
    }
  }
}
