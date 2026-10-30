class CustomerScore {
  final int? score;
  final String? grade;
  final String? trustLabel;
  final int? completedTransactions;
  final double? completionRate;
  final double? totalVolumePkr;

  const CustomerScore({
    this.score,
    this.grade,
    this.trustLabel,
    this.completedTransactions,
    this.completionRate,
    this.totalVolumePkr,
  });

  bool get isAvailable => score != null;
}

class FinancialSummary {
  final double pkrReceived;
  final int paymentsCompleted;
  final double totalTransferred;
  final double? awaitingVerificationAmount;
  final int awaitingVerificationCount;

  final int transactionsCount;
  final int pendingReviewCount;
  final int awaitingPkrCount;
  final int completedCount;

  const FinancialSummary({
    required this.pkrReceived,
    required this.paymentsCompleted,
    required this.totalTransferred,
    this.awaitingVerificationAmount,
    required this.awaitingVerificationCount,
    required this.transactionsCount,
    required this.pendingReviewCount,
    required this.awaitingPkrCount,
    required this.completedCount,
  });

  factory FinancialSummary.empty() => const FinancialSummary(
        pkrReceived: 0.0,
        paymentsCompleted: 0,
        totalTransferred: 0.0,
        awaitingVerificationAmount: null, // Displays as em dash '—'
        awaitingVerificationCount: 0,
        transactionsCount: 0,
        pendingReviewCount: 0,
        awaitingPkrCount: 0,
        completedCount: 0,
      );
}

