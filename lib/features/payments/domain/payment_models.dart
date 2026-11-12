/// Defines payment models in the payments feature's domain layer.

import 'dart:typed_data';

import '../../../core/widgets/status_badge.dart';

enum DateRangeFilter {
  today('Today'),
  yesterday('Yesterday'),
  last3Days('Last 3 days'),
  thisWeek('This week'),
  lastWeek('Last week'),
  thisMonth('This month'),
  lastMonth('Last month'),
  last3Months('Last 3 months'),
  last6Months('Last 6 months'),
  last12Months('Last 12 months'),
  thisYear('This year'),
  lastYear('Last year'),
  allTime('All time'),
  custom('Custom range...');

  final String label;
  const DateRangeFilter(this.label);
}

enum CurrencyFilter {
  all('All currencies'),
  usd('USD'),
  pkr('PKR');

  final String label;
  const CurrencyFilter(this.label);
}

enum StatusFilterOption {
  all('All statuses'),
  submitted('Submitted'),
  underReview('Under Review'),
  verified('Verified'),
  pkrSent('PKR Sent'),
  completed('Completed'),
  onHold('On Hold'),
  rejected('Rejected');

  final String label;
  const StatusFilterOption(this.label);

  // Backward-compatible aliases
  static const StatusFilterOption pendingReview =
      StatusFilterOption.underReview;
  static const StatusFilterOption awaitingPkr = StatusFilterOption.pkrSent;
}

class PaymentItem {
  final String id;
  final String reference;
  final String sender;
  final String senderCompany;
  final double amount;
  final double exchangeRate;
  final double feeAmount;
  final double netPkr;
  final PaymentStatusType status;
  final DateTime transactionDate;
  final DateTime submittedDate;
  final String currencyCode;
  final String? proofFileName;
  final String? proofFilePath;
  final Uint8List? proofBytes;
  final double? feePercentage;
  final double? netAmountForeign;
  final double? grossPkr;
  final String? paymentMethodCode;
  final String? paymentMethodLabel;
  final String? externalTransactionId;
  final String? screenshotTransactionUrl;
  final String? screenshotEmailUrl;
  final bool autoVerified;
  final bool hasPkrTransfer;
  final List<PaymentStatusHistoryItem> statusHistory;
  final String? verifiedDocumentUrl;
  final String? accountantDocumentUrl;
  final String? verifiedByName;
  final String? verifiedByEmail;
  final DateTime? verifiedAt;
  final String? verifiedNote;
  final String? handledByEmail;
  final String? accountantNotes;
  final double? transferAmountPkr;
  final double? transferDeductionPkr;
  final double? transferOriginalAmountPkr;
  final String? transferBankTransactionId;
  final DateTime? transferDate;
  final DateTime? transferRecordedAt;
  final String? transferNotes;
  final List<String> transferReceiptUrls;
  final String? transferReceiptUrl;
  final String? forceCompletedBy;
  final DateTime? customerConfirmedAt;
  final DateTime? completedAt;

  const PaymentItem({
    required this.id,
    required this.reference,
    required this.sender,
    required this.senderCompany,
    required this.amount,
    required this.exchangeRate,
    required this.feeAmount,
    required this.netPkr,
    required this.status,
    required this.transactionDate,
    required this.submittedDate,
    this.currencyCode = 'USD',
    this.proofFileName,
    this.proofFilePath,
    this.proofBytes,
    this.feePercentage,
    this.netAmountForeign,
    this.grossPkr,
    this.paymentMethodCode,
    this.paymentMethodLabel,
    this.externalTransactionId,
    this.screenshotTransactionUrl,
    this.screenshotEmailUrl,
    this.autoVerified = false,
    this.hasPkrTransfer = false,
    this.statusHistory = const [],
    this.verifiedDocumentUrl,
    this.accountantDocumentUrl,
    this.verifiedByName,
    this.verifiedByEmail,
    this.verifiedAt,
    this.verifiedNote,
    this.handledByEmail,
    this.accountantNotes,
    this.transferAmountPkr,
    this.transferDeductionPkr,
    this.transferOriginalAmountPkr,
    this.transferBankTransactionId,
    this.transferDate,
    this.transferRecordedAt,
    this.transferNotes,
    this.transferReceiptUrls = const [],
    this.transferReceiptUrl,
    this.forceCompletedBy,
    this.customerConfirmedAt,
    this.completedAt,
  });

  /// Serializes this value into the JSON shape used by local storage.
  Map<String, dynamic> toJson() => {
    'id': id,
    'reference': reference,
    'sender': sender,
    'senderCompany': senderCompany,
    'amount': amount,
    'exchangeRate': exchangeRate,
    'feeAmount': feeAmount,
    'netPkr': netPkr,
    'status': status.name,
    'transactionDate': transactionDate.toIso8601String(),
    'submittedDate': submittedDate.toIso8601String(),
    'currencyCode': currencyCode,
    'proofFileName': proofFileName,
    'proofFilePath': proofFilePath,
  };
}

/// A server-recorded payment status transition used by the detail timeline.
class PaymentStatusHistoryItem {
  final String? fromStatus;
  final String toStatus;
  final String? note;
  final DateTime? createdAt;

  const PaymentStatusHistoryItem({
    this.fromStatus,
    required this.toStatus,
    this.note,
    this.createdAt,
  });
}

/// Server-calculated totals returned by GET /transactions/payments/summary/.
/// Nullable fields keep an omitted server value distinct from a real zero.
class PaymentsServerSummary {
  final int? totalCount;
  final double? submittedTotal;
  final double? grossPkrReceived;
  final double? transferred;
  final int? pendingCount;
  final int? completedCount;
  final int? rejectedCount;

  const PaymentsServerSummary({
    this.totalCount,
    this.submittedTotal,
    this.grossPkrReceived,
    this.transferred,
    this.pendingCount,
    this.completedCount,
    this.rejectedCount,
  });
}

class PaymentSubmission {
  final String methodId;
  final String senderName;
  final String senderCompany;
  final String confirmationCode;
  final double amount;
  final DateTime? transactionDate;
  final String currencyCode;
  final String? proofFileName;
  final String? proofFilePath;
  final Uint8List? proofBytes;

  const PaymentSubmission({
    required this.methodId,
    required this.senderName,
    required this.senderCompany,
    required this.confirmationCode,
    required this.amount,
    this.transactionDate,
    this.currencyCode = 'USD',
    this.proofFileName,
    this.proofFilePath,
    this.proofBytes,
  });
}

class PaymentMethodOption {
  final String id;
  final String name;
  final String iconKey; // 'cashapp' or 'zelle'

  const PaymentMethodOption({
    required this.id,
    required this.name,
    required this.iconKey,
  });
}

class PaymentFilter {
  final DateRangeFilter dateRange;
  final CurrencyFilter currency;
  final StatusFilterOption status;
  final String searchQuery;
  final bool isBitnexWeek;
  final DateTime? fromDate;
  final DateTime? toDate;

  const PaymentFilter({
    this.dateRange = DateRangeFilter.allTime,
    this.currency = CurrencyFilter.all,
    this.status = StatusFilterOption.all,
    this.searchQuery = '',
    this.isBitnexWeek = false,
    this.fromDate,
    this.toDate,
  });

  /// Creates a copy while preserving fields that were not supplied.
  PaymentFilter copyWith({
    DateRangeFilter? dateRange,
    CurrencyFilter? currency,
    StatusFilterOption? status,
    String? searchQuery,
    bool? isBitnexWeek,
    DateTime? fromDate,
    DateTime? toDate,
    bool clearDates = false,
  }) {
    return PaymentFilter(
      dateRange: dateRange ?? this.dateRange,
      currency: currency ?? this.currency,
      status: status ?? this.status,
      searchQuery: searchQuery ?? this.searchQuery,
      isBitnexWeek: isBitnexWeek ?? this.isBitnexWeek,
      fromDate: clearDates ? null : (fromDate ?? this.fromDate),
      toDate: clearDates ? null : (toDate ?? this.toDate),
    );
  }

  bool get isDefault =>
      !isBitnexWeek &&
      dateRange == DateRangeFilter.allTime &&
      currency == CurrencyFilter.all &&
      status == StatusFilterOption.all &&
      fromDate == null &&
      toDate == null &&
      searchQuery.trim().isEmpty;

  int get activeFilterCount {
    int count = 0;
    if (isBitnexWeek) {
      count++;
    } else if (dateRange != DateRangeFilter.allTime) {
      count++;
    }
    if (fromDate != null || toDate != null) count++;
    if (currency != CurrencyFilter.all) count++;
    if (status != StatusFilterOption.all) count++;
    if (searchQuery.trim().isNotEmpty) count++;
    return count;
  }
}
