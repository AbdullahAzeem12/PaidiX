/// Defines payments repository impl in the payments feature's data layer.

import 'package:flutter/foundation.dart';
import '../../../core/widgets/status_badge.dart';
import '../domain/payment_models.dart';
import '../domain/payments_repository.dart';

class PaymentsRepositoryImpl implements PaymentsRepository {
  final ValueNotifier<List<PaymentItem>> _paymentsNotifier;

  PaymentsRepositoryImpl([List<PaymentItem>? initialPayments])
      : _paymentsNotifier = ValueNotifier<List<PaymentItem>>(
          initialPayments != null ? List.from(initialPayments) : [],
        );

  ValueListenable<List<PaymentItem>> get paymentsListenable =>
      _paymentsNotifier;

  @override
  List<PaymentItem> get payments => List.unmodifiable(_paymentsNotifier.value);

  /// Clears in-memory payments.
  void clearPayments() {
    _paymentsNotifier.value = [];
  }

  // Authoritative dynamic configuration
  final double _feePercentage = 12.0; // 12% as specified in reference
  final double _usdToPkrRate = 273.0; // Authoritative rate

  int _referenceCounter = 1334;

  /// Returns the payment methods currently offered by the in-memory repository.
  @override
  Future<List<PaymentMethodOption>> getPaymentMethods() async {
    return const [
      PaymentMethodOption(
        id: 'cashapp_1',
        name: 'Freight Flow Cashapp',
        iconKey: 'cashapp',
      ),
      PaymentMethodOption(
        id: 'zelle_1',
        name: 'UB Zelle',
        iconKey: 'zelle',
      ),
    ];
  }

  /// Returns the configured fee percentage used by [submitPayment].
  @override
  Future<double> getFeePercentage() async => _feePercentage;

  /// Returns the configured USD-to-PKR rate used to calculate net PKR.
  @override
  Future<double> getUsdToPkrRate() async => _usdToPkrRate;

  /// Calculates the fee and net PKR, creates a completed payment, and inserts
  /// it at the front of the shared list so listening screens refresh.
  @override
  Future<PaymentItem> submitPayment(PaymentSubmission submission) async {
    final feeAmount = (submission.amount * _feePercentage) / 100.0;
    final netUsd = submission.amount - feeAmount;
    final netPkr = netUsd * _usdToPkrRate;

    final refNumber = 'PBX-2026-00${_referenceCounter++}';
    final now = DateTime.now();

    final newPayment = PaymentItem(
      id: 'pay_${now.millisecondsSinceEpoch}',
      reference: refNumber,
      sender: submission.senderName,
      senderCompany: submission.senderCompany,
      amount: submission.amount,
      exchangeRate: _usdToPkrRate,
      feeAmount: feeAmount,
      netPkr: netPkr,
      status: PaymentStatusType.completed,
      transactionDate: submission.transactionDate,
      submittedDate: now,
      proofFileName: submission.proofFileName,
      proofFilePath: submission.proofFilePath,
      proofBytes: submission.proofBytes,
    );

    final updated = List<PaymentItem>.from(_paymentsNotifier.value)
      ..insert(0, newPayment);
    _paymentsNotifier.value = updated;

    return newPayment;
  }

  /// Applies text search, status, and date-range filters to the current list.
  @override
  List<PaymentItem> filterPayments(PaymentFilter filter) {
    var result = List<PaymentItem>.from(_paymentsNotifier.value);

    // Search query filter
    if (filter.searchQuery.trim().isNotEmpty) {
      final q = filter.searchQuery.trim().toLowerCase();
      result = result.where((item) {
        return item.reference.toLowerCase().contains(q) ||
            item.sender.toLowerCase().contains(q) ||
            item.senderCompany.toLowerCase().contains(q) ||
            item.amount.toString().contains(q);
      }).toList();
    }

    // Status filter
    if (filter.status != StatusFilterOption.all) {
      PaymentStatusType? targetType;
      switch (filter.status) {
        case StatusFilterOption.submitted:
          targetType = PaymentStatusType.submitted;
          break;
        case StatusFilterOption.underReview:
          targetType = PaymentStatusType.underReview;
          break;
        case StatusFilterOption.verified:
          targetType = PaymentStatusType.verified;
          break;
        case StatusFilterOption.pkrSent:
          targetType = PaymentStatusType.pkrSent;
          break;
        case StatusFilterOption.completed:
          targetType = PaymentStatusType.completed;
          break;
        case StatusFilterOption.onHold:
          targetType = PaymentStatusType.onHold;
          break;
        case StatusFilterOption.rejected:
          targetType = PaymentStatusType.rejected;
          break;
        case StatusFilterOption.all:
          targetType = null;
          break;
      }
      if (targetType != null) {
        result = result.where((item) {
          if (targetType == PaymentStatusType.underReview) {
            return item.status == PaymentStatusType.underReview ||
                item.status == PaymentStatusType.pendingReview;
          }
          if (targetType == PaymentStatusType.pkrSent) {
            return item.status == PaymentStatusType.pkrSent ||
                item.status == PaymentStatusType.awaitingPkr;
          }
          return item.status == targetType;
        }).toList();
      }
    }

    // Date range filter / Custom dates / Bitnex week
    final now = DateTime.now();
    if (filter.fromDate != null || filter.toDate != null) {
      if (filter.fromDate != null) {
        final start = DateTime(
          filter.fromDate!.year,
          filter.fromDate!.month,
          filter.fromDate!.day,
          0,
          0,
          0,
        );
        result = result
            .where((item) => !item.transactionDate.isBefore(start))
            .toList();
      }
      if (filter.toDate != null) {
        final end = DateTime(
          filter.toDate!.year,
          filter.toDate!.month,
          filter.toDate!.day,
          23,
          59,
          59,
        );
        result = result
            .where((item) => !item.transactionDate.isAfter(end))
            .toList();
      }
    } else if (filter.isBitnexWeek) {
      // Bitnex settlement week (Monday 00:00:00 through Sunday 23:59:59)
      final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
      final startOfDay =
          DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
      result = result
          .where((item) => item.transactionDate.isAfter(startOfDay))
          .toList();
    } else {
      switch (filter.dateRange) {
        case DateRangeFilter.today:
          result = result
              .where((item) =>
                  item.transactionDate.year == now.year &&
                  item.transactionDate.month == now.month &&
                  item.transactionDate.day == now.day)
              .toList();
          break;
        case DateRangeFilter.yesterday:
          final y = now.subtract(const Duration(days: 1));
          result = result
              .where((item) =>
                  item.transactionDate.year == y.year &&
                  item.transactionDate.month == y.month &&
                  item.transactionDate.day == y.day)
              .toList();
          break;
        case DateRangeFilter.last3Days:
          final cutoff = now.subtract(const Duration(days: 3));
          result = result
              .where((item) => item.transactionDate.isAfter(cutoff))
              .toList();
          break;
        case DateRangeFilter.thisWeek:
          final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
          final startOfDay =
              DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
          result = result
              .where((item) => item.transactionDate.isAfter(startOfDay))
              .toList();
          break;
        case DateRangeFilter.lastWeek:
          final startOfLastWeek =
              now.subtract(Duration(days: now.weekday - 1 + 7));
          final endOfLastWeek = now.subtract(Duration(days: now.weekday));
          result = result
              .where((item) =>
                  item.transactionDate.isAfter(startOfLastWeek) &&
                  item.transactionDate.isBefore(endOfLastWeek))
              .toList();
          break;
        case DateRangeFilter.thisMonth:
          result = result
              .where((item) =>
                  item.transactionDate.year == now.year &&
                  item.transactionDate.month == now.month)
              .toList();
          break;
        case DateRangeFilter.lastMonth:
          final prevMonth = now.month == 1 ? 12 : now.month - 1;
          final prevYear = now.month == 1 ? now.year - 1 : now.year;
          result = result
              .where((item) =>
                  item.transactionDate.year == prevYear &&
                  item.transactionDate.month == prevMonth)
              .toList();
          break;
        case DateRangeFilter.last3Months:
          final cutoff = DateTime(now.year, now.month - 3, now.day);
          result = result
              .where((item) => item.transactionDate.isAfter(cutoff))
              .toList();
          break;
        case DateRangeFilter.last6Months:
          final cutoff = DateTime(now.year, now.month - 6, now.day);
          result = result
              .where((item) => item.transactionDate.isAfter(cutoff))
              .toList();
          break;
        case DateRangeFilter.last12Months:
          final cutoff = DateTime(now.year, now.month - 12, now.day);
          result = result
              .where((item) => item.transactionDate.isAfter(cutoff))
              .toList();
          break;
        case DateRangeFilter.thisYear:
          result = result
              .where((item) => item.transactionDate.year == now.year)
              .toList();
          break;
        case DateRangeFilter.lastYear:
          result = result
              .where((item) => item.transactionDate.year == now.year - 1)
              .toList();
          break;
        case DateRangeFilter.allTime:
        case DateRangeFilter.custom:
          break;
      }
    }

    return result;
  }

}
