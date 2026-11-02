import 'package:flutter_test/flutter_test.dart';
import 'package:noteforge/features/security/services/security_service.dart';

void main() {
  group('SecurityService Tests', () {
    test('PIN hashing produces consistent SHA-256 hash with salt', () {
      final hash1 = SecurityService.hashPin('1234');
      final hash2 = SecurityService.hashPin('1234');
      final hash3 = SecurityService.hashPin('5678');

      expect(hash1, equals(hash2));
      expect(hash1, isNot(equals(hash3)));
      expect(hash1.length, 64); // SHA-256 hex length
    });

    test('Different PINs produce different hashes', () {
      final h1 = SecurityService.hashPin('0000');
      final h2 = SecurityService.hashPin('0001');
      expect(h1, isNot(equals(h2)));
    });
  });
}

