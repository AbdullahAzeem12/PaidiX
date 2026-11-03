import 'package:flutter/foundation.dart';
import '../../../core/widgets/status_badge.dart';
import '../domain/payment_models.dart';
import '../domain/payments_repository.dart';

class PaymentsRepositoryImpl implements PaymentsRepository {
  final ValueNotifier<List<PaymentItem>> _paymentsNotifier;

  PaymentsRepositoryImpl({bool seedMockData = false})
      : _paymentsNotifier = ValueNotifier<List<PaymentItem>>(
          seedMockData ? _generateInitialMockPayments() : [],
        );

  ValueListenable<List<PaymentItem>> get paymentsListenable =>
      _paymentsNotifier;

  @override
  List<PaymentItem> get payments => List.unmodifiable(_paymentsNotifier.value);

  /// Seeds or resets repository with mock data from production screenshots.
  void seedMockData() {
    _paymentsNotifier.value = _generateInitialMockPayments();
  }

  /// Clears in-memory payments.
  void clearPayments() {
    _paymentsNotifier.value = [];
  }

  // Authoritative dynamic configuration
  final double _feePercentage = 12.0; // 12% as specified in reference
  final double _usdToPkrRate = 273.0; // Authoritative rate

  int _referenceCounter = 1334;

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

  @override
  Future<double> getFeePercentage() async => _feePercentage;

  @override
  Future<double> getUsdToPkrRate() async => _usdToPkrRate;

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

  /// Initial 24 mockup transactions matching production screenshots.
  /// Top 4 records exactly match screenshots 1 & 2.
  static List<PaymentItem> _generateInitialMockPayments() {
    return [
      PaymentItem(
        id: 'pay_1332',
        reference: 'PBX-2026-001332',
        sender: 'Ward Trucking Atlanta Llc',
        senderCompany: 'Ward Trucking Atlanta Llc',
        amount: 171.00,
        exchangeRate: 273.0,
        feeAmount: 20.52,
        netPkr: 41081.04,
        status: PaymentStatusType.completed,
        transactionDate: DateTime(2026, 8, 28),
        submittedDate: DateTime(2026, 9, 2),
        proofFileName: 'ward_trucking_1332.pdf',
      ),
      PaymentItem(
        id: 'pay_1331',
        reference: 'PBX-2026-001331',
        sender: 'Ward Trucking Atlanta Llc',
        senderCompany: 'Ward Trucking Atlanta Llc',
        amount: 10.00,
        exchangeRate: 273.0,
        feeAmount: 1.20,
        netPkr: 2402.40,
        status: PaymentStatusType.completed,
        transactionDate: DateTime(2026, 8, 24),
        submittedDate: DateTime(2026, 9, 2),
        proofFileName: 'ward_trucking_1331.pdf',
      ),
      PaymentItem(
        id: 'pay_1333',
        reference: 'PBX-2026-001333',
        sender: 'Ward Trucking Atlanta Llc',
        senderCompany: 'Ward Trucking Atlanta Llc',
        amount: 142.00,
        exchangeRate: 273.0,
        feeAmount: 17.04,
        netPkr: 34114.08,
        status: PaymentStatusType.completed,
        transactionDate: DateTime(2026, 8, 22),
        submittedDate: DateTime(2026, 9, 2),
        proofFileName: 'ward_trucking_1333.pdf',
      ),
      PaymentItem(
        id: 'pay_1330',
        reference: 'PBX-2026-001330',
        sender: 'Evolve Transport Inc',
        senderCompany: 'Evolve Transport Inc',
        amount: 92.40,
        exchangeRate: 273.0,
        feeAmount: 11.09,
        netPkr: 22197.63,
        status: PaymentStatusType.completed,
        transactionDate: DateTime(2026, 8, 17),
        submittedDate: DateTime(2026, 9, 2),
        proofFileName: 'evolve_transport_1330.pdf',
      ),
      PaymentItem(
        id: 'pay_1329',
        reference: 'PBX-2026-001329',
        sender: 'Swift Logistics LLC',
        senderCompany: 'Swift Logistics LLC',
        amount: 350.00,
        exchangeRate: 273.0,
        feeAmount: 42.00,
        netPkr: 84084.00,
        status: PaymentStatusType.completed,
        transactionDate: DateTime(2026, 8, 14),
        submittedDate: DateTime(2026, 9, 1),
        proofFileName: 'swift_logistics_1329.pdf',
      ),
      PaymentItem(
        id: 'pay_1328',
        reference: 'PBX-2026-001328',
        sender: 'Apex Freight Express',
        senderCompany: 'Apex Freight Express',
        amount: 85.00,
        exchangeRate: 273.0,
        feeAmount: 10.20,
        netPkr: 20420.40,
        status: PaymentStatusType.completed,
        transactionDate: DateTime(2026, 8, 10),
        submittedDate: DateTime(2026, 8, 28),
        proofFileName: 'apex_freight_1328.pdf',
      ),
      PaymentItem(
        id: 'pay_1327',
        reference: 'PBX-2026-001327',
        sender: 'Falcon Express Lines',
        senderCompany: 'Falcon Express Lines',
        amount: 240.00,
        exchangeRate: 273.0,
        feeAmount: 28.80,
        netPkr: 57657.60,
        status: PaymentStatusType.completed,
        transactionDate: DateTime(2026, 8, 8),
        submittedDate: DateTime(2026, 8, 25),
        proofFileName: 'falcon_express_1327.pdf',
      ),
      PaymentItem(
        id: 'pay_1326',
        reference: 'PBX-2026-001326',
        sender: 'Ward Trucking Atlanta Llc',
        senderCompany: 'Ward Trucking Atlanta Llc',
        amount: 190.00,
        exchangeRate: 273.0,
        feeAmount: 22.80,
        netPkr: 45645.60,
        status: PaymentStatusType.completed,
        transactionDate: DateTime(2026, 8, 5),
        submittedDate: DateTime(2026, 8, 20),
        proofFileName: 'ward_trucking_1326.pdf',
      ),
      PaymentItem(
        id: 'pay_1325',
        reference: 'PBX-2026-001325',
        sender: 'Titan Haulers LLC',
        senderCompany: 'Titan Haulers LLC',
        amount: 520.00,
        exchangeRate: 273.0,
        feeAmount: 62.40,
        netPkr: 124934.40,
        status: PaymentStatusType.completed,
        transactionDate: DateTime(2026, 8, 2),
        submittedDate: DateTime(2026, 8, 18),
        proofFileName: 'titan_haulers_1325.pdf',
      ),
      PaymentItem(
        id: 'pay_1324',
        reference: 'PBX-2026-001324',
        sender: 'Metro Cargo Corp',
        senderCompany: 'Metro Cargo Corp',
        amount: 75.00,
        exchangeRate: 273.0,
        feeAmount: 9.00,
        netPkr: 18018.00,
        status: PaymentStatusType.completed,
        transactionDate: DateTime(2026, 7, 29),
        submittedDate: DateTime(2026, 8, 15),
        proofFileName: 'metro_cargo_1324.pdf',
      ),
      PaymentItem(
        id: 'pay_1323',
        reference: 'PBX-2026-001323',
        sender: 'Evolve Transport Inc',
        senderCompany: 'Evolve Transport Inc',
        amount: 115.00,
        exchangeRate: 273.0,
        feeAmount: 13.80,
        netPkr: 27627.60,
        status: PaymentStatusType.completed,
        transactionDate: DateTime(2026, 7, 25),
        submittedDate: DateTime(2026, 8, 10),
        proofFileName: 'evolve_transport_1323.pdf',
      ),
      PaymentItem(
        id: 'pay_1322',
        reference: 'PBX-2026-001322',
        sender: 'Prime Line Dispatch',
        senderCompany: 'Prime Line Dispatch',
        amount: 310.00,
        exchangeRate: 273.0,
        feeAmount: 37.20,
        netPkr: 74470.80,
        status: PaymentStatusType.completed,
        transactionDate: DateTime(2026, 7, 22),
        submittedDate: DateTime(2026, 8, 5),
        proofFileName: 'prime_line_1322.pdf',
      ),
      PaymentItem(
        id: 'pay_1321',
        reference: 'PBX-2026-001321',
        sender: 'Ward Trucking Atlanta Llc',
        senderCompany: 'Ward Trucking Atlanta Llc',
        amount: 160.00,
        exchangeRate: 273.0,
        feeAmount: 19.20,
        netPkr: 38438.40,
        status: PaymentStatusType.completed,
        transactionDate: DateTime(2026, 7, 18),
        submittedDate: DateTime(2026, 7, 30),
        proofFileName: 'ward_trucking_1321.pdf',
      ),
      PaymentItem(
        id: 'pay_1320',
        reference: 'PBX-2026-001320',
        sender: 'Horizon Hauling Co',
        senderCompany: 'Horizon Hauling Co',
        amount: 95.00,
        exchangeRate: 273.0,
        feeAmount: 11.40,
        netPkr: 22822.80,
        status: PaymentStatusType.completed,
        transactionDate: DateTime(2026, 7, 15),
        submittedDate: DateTime(2026, 7, 28),
        proofFileName: 'horizon_hauling_1320.pdf',
      ),
      PaymentItem(
        id: 'pay_1319',
        reference: 'PBX-2026-001319',
        sender: 'Blue Star Transport',
        senderCompany: 'Blue Star Transport',
        amount: 225.00,
        exchangeRate: 273.0,
        feeAmount: 27.00,
        netPkr: 54054.00,
        status: PaymentStatusType.completed,
        transactionDate: DateTime(2026, 7, 10),
        submittedDate: DateTime(2026, 7, 22),
        proofFileName: 'blue_star_1319.pdf',
      ),
      PaymentItem(
        id: 'pay_1318',
        reference: 'PBX-2026-001318',
        sender: 'Continental Express',
        senderCompany: 'Continental Express',
        amount: 410.00,
        exchangeRate: 273.0,
        feeAmount: 49.20,
        netPkr: 98479.20,
        status: PaymentStatusType.completed,
        transactionDate: DateTime(2026, 7, 5),
        submittedDate: DateTime(2026, 7, 18),
        proofFileName: 'continental_1318.pdf',
      ),
      PaymentItem(
        id: 'pay_1317',
        reference: 'PBX-2026-001317',
        sender: 'Evolve Transport Inc',
        senderCompany: 'Evolve Transport Inc',
        amount: 130.00,
        exchangeRate: 273.0,
        feeAmount: 15.60,
        netPkr: 31231.20,
        status: PaymentStatusType.completed,
        transactionDate: DateTime(2026, 6, 28),
        submittedDate: DateTime(2026, 7, 12),
        proofFileName: 'evolve_transport_1317.pdf',
      ),
      PaymentItem(
        id: 'pay_1316',
        reference: 'PBX-2026-001316',
        sender: 'Ward Trucking Atlanta Llc',
        senderCompany: 'Ward Trucking Atlanta Llc',
        amount: 88.00,
        exchangeRate: 273.0,
        feeAmount: 10.56,
        netPkr: 21141.12,
        status: PaymentStatusType.completed,
        transactionDate: DateTime(2026, 6, 22),
        submittedDate: DateTime(2026, 7, 5),
        proofFileName: 'ward_trucking_1316.pdf',
      ),
      PaymentItem(
        id: 'pay_1315',
        reference: 'PBX-2026-001315',
        sender: 'Summit Cargo Lines',
        senderCompany: 'Summit Cargo Lines',
        amount: 280.00,
        exchangeRate: 273.0,
        feeAmount: 33.60,
        netPkr: 67267.20,
        status: PaymentStatusType.completed,
        transactionDate: DateTime(2026, 6, 18),
        submittedDate: DateTime(2026, 6, 30),
        proofFileName: 'summit_cargo_1315.pdf',
      ),
      PaymentItem(
        id: 'pay_1314',
        reference: 'PBX-2026-001314',
        sender: 'Direct Route Logistics',
        senderCompany: 'Direct Route Logistics',
        amount: 195.00,
        exchangeRate: 273.0,
        feeAmount: 23.40,
        netPkr: 46846.80,
        status: PaymentStatusType.completed,
        transactionDate: DateTime(2026, 6, 12),
        submittedDate: DateTime(2026, 6, 25),
        proofFileName: 'direct_route_1314.pdf',
      ),
      PaymentItem(
        id: 'pay_1313',
        reference: 'PBX-2026-001313',
        sender: 'Ward Trucking Atlanta Llc',
        senderCompany: 'Ward Trucking Atlanta Llc',
        amount: 320.00,
        exchangeRate: 273.0,
        feeAmount: 38.40,
        netPkr: 76876.80,
        status: PaymentStatusType.completed,
        transactionDate: DateTime(2026, 6, 5),
        submittedDate: DateTime(2026, 6, 18),
        proofFileName: 'ward_trucking_1313.pdf',
      ),
      PaymentItem(
        id: 'pay_1312',
        reference: 'PBX-2026-001312',
        sender: 'Evolve Transport Inc',
        senderCompany: 'Evolve Transport Inc',
        amount: 150.00,
        exchangeRate: 273.0,
        feeAmount: 18.00,
        netPkr: 36036.00,
        status: PaymentStatusType.completed,
        transactionDate: DateTime(2026, 5, 28),
        submittedDate: DateTime(2026, 6, 10),
        proofFileName: 'evolve_transport_1312.pdf',
      ),
      PaymentItem(
        id: 'pay_1311',
        reference: 'PBX-2026-001311',
        sender: 'Vanguard Freight',
        senderCompany: 'Vanguard Freight',
        amount: 450.00,
        exchangeRate: 273.0,
        feeAmount: 54.00,
        netPkr: 108108.00,
        status: PaymentStatusType.completed,
        transactionDate: DateTime(2026, 5, 20),
        submittedDate: DateTime(2026, 6, 2),
        proofFileName: 'vanguard_freight_1311.pdf',
      ),
      PaymentItem(
        id: 'pay_1310',
        reference: 'PBX-2026-001310',
        sender: 'Ward Trucking Atlanta Llc',
        senderCompany: 'Ward Trucking Atlanta Llc',
        amount: 65.00,
        exchangeRate: 273.0,
        feeAmount: 7.80,
        netPkr: 15615.60,
        status: PaymentStatusType.completed,
        transactionDate: DateTime(2026, 5, 15),
        submittedDate: DateTime(2026, 5, 28),
        proofFileName: 'ward_trucking_1310.pdf',
      ),
    ];
  }
}
