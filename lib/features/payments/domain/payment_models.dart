import '../../../core/widgets/status_badge.dart';

enum DateRangeFilter {
  allTime('All time'),
  today('Today'),
  last3Days('Last 3 days'),
  thisWeek('This week'),
  lastWeek('Last week'),
  thisMonth('This month'),
  lastMonth('Last month'),
  last3Months('Last 3 months'),
  thisYear('This year'),
  lastYear('Last year');

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
  static const StatusFilterOption pendingReview = StatusFilterOption.underReview;
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
  final String? proofFileName;

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
    this.proofFileName,
  });

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
        'proofFileName': proofFileName,
      };
}

class PaymentSubmission {
  final String methodId;
  final String senderName;
  final String senderCompany;
  final String confirmationCode;
  final double amount;
  final DateTime transactionDate;
  final String? proofFileName;

  const PaymentSubmission({
    required this.methodId,
    required this.senderName,
    required this.senderCompany,
    required this.confirmationCode,
    required this.amount,
    required this.transactionDate,
    this.proofFileName,
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

  const PaymentFilter({
    this.dateRange = DateRangeFilter.allTime,
    this.currency = CurrencyFilter.all,
    this.status = StatusFilterOption.all,
    this.searchQuery = '',
    this.isBitnexWeek = false,
  });

  PaymentFilter copyWith({
    DateRangeFilter? dateRange,
    CurrencyFilter? currency,
    StatusFilterOption? status,
    String? searchQuery,
    bool? isBitnexWeek,
  }) {
    return PaymentFilter(
      dateRange: dateRange ?? this.dateRange,
      currency: currency ?? this.currency,
      status: status ?? this.status,
      searchQuery: searchQuery ?? this.searchQuery,
      isBitnexWeek: isBitnexWeek ?? this.isBitnexWeek,
    );
  }

  bool get isDefault =>
      !isBitnexWeek &&
      dateRange == DateRangeFilter.allTime &&
      currency == CurrencyFilter.all &&
      status == StatusFilterOption.all &&
      searchQuery.trim().isEmpty;

  int get activeFilterCount {
    int count = 0;
    if (isBitnexWeek) {
      count++;
    } else if (dateRange != DateRangeFilter.allTime) {
      count++;
    }
    if (currency != CurrencyFilter.all) count++;
    if (status != StatusFilterOption.all) count++;
    if (searchQuery.trim().isNotEmpty) count++;
    return count;
  }
}

