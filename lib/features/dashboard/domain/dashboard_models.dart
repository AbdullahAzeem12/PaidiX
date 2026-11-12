/// Defines dashboard models in the dashboard feature's domain layer.

class CustomerScore {
  final int? score;
  final String? grade;
  final String? trustLabel;
  final int? totalTransactions;
  final int? completedTransactions;
  final int? rejectedTransactions;
  final double? completionRate;
  final double? rejectionRate;
  final double? totalVolumePkr;
  final String? userEmail;

  const CustomerScore({
    this.score,
    this.grade,
    this.trustLabel,
    this.totalTransactions,
    this.completedTransactions,
    this.rejectedTransactions,
    this.completionRate,
    this.rejectionRate,
    this.totalVolumePkr,
    this.userEmail,
  });

  bool get isAvailable => score != null;

  /// Mathematical starter score for newly registered users.
  /// Base onboarding score is 50 points as defined by the PaidiX credit system.
  factory CustomerScore.starter() => const CustomerScore(
    score: 50,
    grade: '—',
    trustLabel: 'NEW',
    totalTransactions: 0,
    completedTransactions: 0,
    rejectedTransactions: 0,
    completionRate: 0.0,
    rejectionRate: 0.0,
    totalVolumePkr: 0.0,
  );

  /// Maps the backend's score and tier fields without recomputing its score.
  factory CustomerScore.fromServer({
    required int? score,
    required String? grade,
    required String? tier,
    required int? completedCount,
    required int? rejectedCount,
    required double? totalVolumePkr,
    int? totalTransactions,
    double? completionRate,
    double? rejectionRate,
    String? userEmail,
  }) {
    final total =
        totalTransactions ?? (completedCount ?? 0) + (rejectedCount ?? 0);
    final calculatedRate = total > 0
        ? (completedCount ?? 0) / total * 100
        : 0.0;
    final normalizedTier = tier?.trim().replaceAll('_', '-').toUpperCase();
    final trustLabel = normalizedTier?.isNotEmpty == true
        ? normalizedTier
        : (score != null && score < 40 ? 'HIGH-RISK' : 'NEW');

    return CustomerScore(
      score: score,
      grade: grade?.trim().isNotEmpty == true
          ? grade!.trim().toUpperCase()
          : _gradeFor(score),
      trustLabel: trustLabel,
      totalTransactions: total,
      completedTransactions: completedCount,
      rejectedTransactions: rejectedCount,
      completionRate: completionRate ?? calculatedRate,
      rejectionRate: rejectionRate,
      totalVolumePkr: totalVolumePkr,
      userEmail: userEmail?.trim().toLowerCase(),
    );
  }

  /// Maps the exact values returned by `GET /accounts/score/`.
  factory CustomerScore.fromJson(Map<String, dynamic> json) {
    return CustomerScore.fromServer(
      score: _asInt(json['score']),
      grade: _asString(json['grade']),
      tier: _asString(json['tier']),
      totalTransactions: _asInt(json['total_transactions']),
      completedCount: _asInt(json['completed']),
      rejectedCount: _asInt(json['rejected']),
      completionRate: _asDouble(json['completion_rate']),
      rejectionRate: _asDouble(json['rejection_rate']),
      totalVolumePkr: _asDouble(json['total_volume_pkr']),
      userEmail: _asString(json['user_email']),
    );
  }

  static int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) {
      return int.tryParse(value) ?? double.tryParse(value)?.toInt();
    }
    return null;
  }

  static double? _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static String? _asString(dynamic value) =>
      value is String && value.trim().isNotEmpty ? value.trim() : null;

  static String? _gradeFor(int? score) {
    if (score == null) return null;
    if (score >= 90) return 'A+';
    if (score >= 80) return 'A';
    if (score >= 70) return 'B';
    if (score >= 60) return 'C';
    if (score >= 40) return 'D';
    return 'F';
  }

  /// Computes a professional dynamic trust score based on KYC status,
  /// transaction completion rate, and volume.
  factory CustomerScore.calculate({
    required int totalTransactions,
    required int completedCount,
    required double totalVolumePkr,
    required bool isKycVerified,
  }) {
    // If no completed transactions, return starter score of 50
    if (completedCount == 0) {
      return CustomerScore.starter();
    }

    final double rate = totalTransactions > 0
        ? (completedCount / totalTransactions) * 100.0
        : 0.0;

    // Mathematical scoring algorithm:
    // Base: 50 points (starter baseline)
    // KYC Verified Bonus: +10 points
    // Completion rate weight: up to 25 points (proportional to success rate)
    // Volume weight: up to 15 points (scaled against Rs 500,000 threshold)
    double calculated = 50.0;

    if (isKycVerified) {
      calculated += 10.0;
    }

    calculated += (rate / 100.0) * 25.0;

    if (totalVolumePkr > 0) {
      final volRatio = (totalVolumePkr / 500000.0).clamp(0.0, 1.0);
      calculated += volRatio * 15.0;
    }

    final int finalScore = calculated.round().clamp(0, 100);

    // Determination of credit grade and trust tier
    final String grade;
    final String trustLabel;

    if (finalScore >= 90) {
      grade = 'A+';
      trustLabel = 'EXCELLENT';
    } else if (finalScore >= 80) {
      grade = 'A';
      trustLabel = 'TRUSTED';
    } else if (finalScore >= 70) {
      grade = 'B';
      trustLabel = 'GOOD';
    } else if (finalScore >= 60) {
      grade = 'C';
      trustLabel = 'FAIR';
    } else {
      grade = 'D';
      trustLabel = 'BASIC';
    }

    return CustomerScore(
      score: finalScore,
      grade: grade,
      trustLabel: trustLabel,
      completedTransactions: completedCount,
      completionRate: rate,
      totalVolumePkr: totalVolumePkr,
    );
  }
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
