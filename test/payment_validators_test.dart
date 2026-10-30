import 'package:flutter_test/flutter_test.dart';
import 'package:paidix/core/utils/validators.dart';

void main() {
  group('PaymentValidators Tests', () {
    test('validateSenderName checks for non-empty and min length', () {
      expect(PaymentValidators.validateSenderName(''), isNotNull);
      expect(PaymentValidators.validateSenderName('   '), isNotNull);
      expect(PaymentValidators.validateSenderName('A'), isNotNull);
      expect(PaymentValidators.validateSenderName('Ward Trucking'), isNull);
    });

    test('validateSenderCompany checks for non-empty and min length', () {
      expect(PaymentValidators.validateSenderCompany(''), isNotNull);
      expect(PaymentValidators.validateSenderCompany('Atlanta Llc'), isNull);
    });

    test('validateConfirmationCode requires at least 4 characters', () {
      expect(PaymentValidators.validateConfirmationCode(''), isNotNull);
      expect(PaymentValidators.validateConfirmationCode('123'), isNotNull);
      expect(PaymentValidators.validateConfirmationCode('CONF1234'), isNull);
    });

    test('validateAmount validates positive numeric strings', () {
      expect(PaymentValidators.validateAmount(''), isNotNull);
      expect(PaymentValidators.validateAmount('abc'), isNotNull);
      expect(PaymentValidators.validateAmount('0'), isNotNull);
      expect(PaymentValidators.validateAmount('-15'), isNotNull);
      expect(PaymentValidators.validateAmount('171.00'), isNull);
      expect(PaymentValidators.validateAmount('\$ 171.00'), isNull);
    });

    test('validateDate requires non-null date', () {
      expect(PaymentValidators.validateDate(null), isNotNull);
      expect(PaymentValidators.validateDate(DateTime.now()), isNull);
    });
  });
}

