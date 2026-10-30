import 'package:flutter_test/flutter_test.dart';
import 'package:paidix/features/auth/domain/auth_validators.dart';

void main() {
  group('AuthValidators Unit Tests', () {
    test('validateFullName returns error on empty', () {
      expect(AuthValidators.validateFullName(''), isNotNull);
      expect(AuthValidators.validateFullName('   '), isNotNull);
      expect(AuthValidators.validateFullName('A'), isNotNull);
      expect(AuthValidators.validateFullName('John Doe'), isNull);
    });

    test('validateEmail validates correctly', () {
      expect(AuthValidators.validateEmail(''), isNotNull);
      expect(AuthValidators.validateEmail('invalid-email'), isNotNull);
      expect(AuthValidators.validateEmail('user@test'), isNotNull);
      expect(AuthValidators.validateEmail('user@example.com'), isNull);
    });

    test('validatePassword requires at least 8 characters', () {
      expect(AuthValidators.validatePassword(''), isNotNull);
      expect(AuthValidators.validatePassword('1234567'), isNotNull);
      expect(AuthValidators.validatePassword('12345678'), isNull);
    });

    test('validatePhoneOptional handles optional values', () {
      expect(AuthValidators.validatePhoneOptional(''), isNull);
      expect(AuthValidators.validatePhoneOptional(null), isNull);
      expect(AuthValidators.validatePhoneOptional('+92 300 1234567'), isNull);
    });
  });
}

