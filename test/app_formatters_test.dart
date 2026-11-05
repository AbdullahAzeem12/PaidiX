/// Tests the app formatters test behavior and guards its key user-facing and domain expectations.

import 'package:flutter_test/flutter_test.dart';
import 'package:paidix/core/utils/formatters.dart';

/// Configures and launches the application or test suite.
void main() {
  group('AppFormatters Tests', () {
    test('formatUsd formats values correctly with decimals', () {
      expect(AppFormatters.formatUsd(171.0), '\$ 171.00');
      expect(AppFormatters.formatUsd(10.0), '\$ 10.00');
      expect(AppFormatters.formatUsd(1250000.5), '\$ 1,250,000.50');
      expect(AppFormatters.formatUsd(null), '—');
    });

    test('formatPkr formats values correctly with commas', () {
      expect(AppFormatters.formatPkr(41081.04), 'Rs 41,081.04');
      expect(AppFormatters.formatPkr(0.0), 'Rs 0.00');
      expect(AppFormatters.formatPkr(99795.15), 'Rs 99,795.15');
      expect(AppFormatters.formatPkr(null), '—');
    });

    test('formatPercentage formats percentage numbers', () {
      expect(AppFormatters.formatPercentage(12.0), '12.00%');
      expect(AppFormatters.formatPercentage(100.0), '100.00%');
      expect(AppFormatters.formatPercentage(null), '—');
    });

    test('formatDate formats DateTime into readable string', () {
      final date = DateTime(2026, 8, 28);
      expect(AppFormatters.formatDate(date), 'Aug 28, 2026');
      expect(AppFormatters.formatDate(null), '—');
    });

    test('formatDateInput formats DateTime into mm / dd / yyyy', () {
      final date = DateTime(2026, 9, 2);
      expect(AppFormatters.formatDateInput(date), '09 / 02 / 2026');
      expect(AppFormatters.formatDateInput(null), '');
    });
  });
}

