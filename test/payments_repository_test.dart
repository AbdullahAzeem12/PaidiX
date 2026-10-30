import 'package:flutter_test/flutter_test.dart';
import 'package:paidix/core/widgets/status_badge.dart';
import 'package:paidix/features/payments/data/payments_repository_impl.dart';
import 'package:paidix/features/payments/domain/payment_models.dart';

void main() {
  group('PaymentsRepositoryImpl Tests', () {
    late PaymentsRepositoryImpl repo;

    setUp(() {
      repo = PaymentsRepositoryImpl();
    });

    test('initial state has zero payments (clean empty state)', () {
      expect(repo.payments, isEmpty);
    });

    test('submitPayment calculates fee and net PKR correctly', () async {
      final submission = PaymentSubmission(
        methodId: 'cashapp_1',
        senderName: 'Ward Trucking Atlanta Llc',
        senderCompany: 'Atlanta Llc',
        confirmationCode: 'WT-9921',
        amount: 171.0, // $171.00
        transactionDate: DateTime(2026, 8, 28),
      );

      final item = await repo.submitPayment(submission);

      expect(item.reference, startsWith('PBX-2026-'));
      expect(item.amount, 171.0);
      expect(item.feeAmount, 20.52); // 12% of 171 = 20.52
      expect(item.exchangeRate, 273.0);
      // Net USD = 171 - 20.52 = 150.48. Net PKR = 150.48 * 273 = 41081.04
      expect(item.netPkr, closeTo(41081.04, 0.01));
      expect(item.status, PaymentStatusType.completed);
      expect(repo.payments.length, 1);
    });

    test('filterPayments matches search query', () async {
      await repo.submitPayment(PaymentSubmission(
        methodId: 'cashapp_1',
        senderName: 'Ward Trucking Atlanta Llc',
        senderCompany: 'Atlanta Llc',
        confirmationCode: 'WT-001',
        amount: 171.0,
        transactionDate: DateTime.now(),
      ));
      await repo.submitPayment(PaymentSubmission(
        methodId: 'zelle_1',
        senderName: 'Evolve Transport Inc',
        senderCompany: 'Evolve Inc',
        confirmationCode: 'EV-002',
        amount: 92.4,
        transactionDate: DateTime.now(),
      ));

      final matchWard = repo.filterPayments(
          const PaymentFilter(searchQuery: 'Ward'));
      expect(matchWard.length, 1);
      expect(matchWard.first.sender, 'Ward Trucking Atlanta Llc');

      final matchEvolve = repo.filterPayments(
          const PaymentFilter(searchQuery: 'Evolve'));
      expect(matchEvolve.length, 1);
      expect(matchEvolve.first.sender, 'Evolve Transport Inc');

      final noMatch = repo.filterPayments(
          const PaymentFilter(searchQuery: 'NonExistent'));
      expect(noMatch, isEmpty);
    });
  });
}

