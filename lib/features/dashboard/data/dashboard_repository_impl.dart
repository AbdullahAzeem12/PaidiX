/// Defines dashboard repository impl in the dashboard feature's data layer.

import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../../../core/widgets/status_badge.dart';
import '../../payments/data/payments_repository_impl.dart';
import '../../payments/domain/payment_models.dart';
import '../../payments/domain/payments_repository.dart';
import '../../profile/data/user_profile_repository.dart';
import '../../profile/domain/user_profile.dart';
import '../domain/dashboard_models.dart';
import '../domain/dashboard_repository.dart';

class DashboardRepositoryImpl implements DashboardRepository {
  final PaymentsRepository _paymentsRepository;

  DashboardRepositoryImpl(this._paymentsRepository);

  /// Preserves the existing profile projection for compatibility and keeps
  /// the local score estimate available in offline/test mode.
  CustomerScore? customerScoreFor(UserProfile profile) {
    if (AppConfig.hasCustomBackend) {
      final hasServerScore =
          profile.ratingScore != null ||
          profile.ratingTier != null ||
          profile.ratingGrade != null ||
          profile.completedCount != null ||
          profile.totalVolumePkr != null;
      if (!hasServerScore) return null;

      return CustomerScore.fromServer(
        score: profile.ratingScore,
        grade: profile.ratingGrade,
        tier: profile.ratingTier,
        completedCount: profile.completedCount,
        rejectedCount: profile.rejectedCount,
        totalVolumePkr: profile.totalVolumePkr,
      );
    }

    final list = _paymentsRepository.payments;
    final isKycVerified = profile.kycStatus == KycReviewStatus.verified;
    if (list.isEmpty) return CustomerScore.starter();

    final completed = list
        .where((p) => p.status == PaymentStatusType.completed)
        .toList();
    final volume = completed.fold<double>(
      0.0,
      (acc, item) => acc + item.netPkr,
    );
    return CustomerScore.calculate(
      totalTransactions: list.length,
      completedCount: completed.length,
      totalVolumePkr: volume,
      isKycVerified: isKycVerified,
    );
  }

  /// Fetches the authoritative score endpoint in live mode.
  @override
  Future<CustomerScore?> getCustomerScore() async {
    final profile = UserProfileRepository.instance.profile;
    if (!AppConfig.hasCustomBackend) return customerScoreFor(profile);

    final response = await ApiClient.instance.get('/accounts/score/');
    final payload = _extractScorePayload(response);
    final score = CustomerScore.fromJson(payload);
    if (!score.isAvailable) {
      throw const FormatException(
        'The customer score response did not include a valid score.',
      );
    }

    final expectedEmail = profile.email.trim().toLowerCase();
    if (score.userEmail != null &&
        expectedEmail.isNotEmpty &&
        score.userEmail != expectedEmail) {
      throw const FormatException(
        'The customer score response belongs to a different account.',
      );
    }
    return score;
  }

  Map<String, dynamic> _extractScorePayload(Map<String, dynamic> response) {
    dynamic value = response;
    for (var depth = 0; depth < 4; depth++) {
      if (value is List) {
        final records = value.whereType<Map>().toList(growable: false);
        if (records.isEmpty) {
          throw const FormatException(
            'The customer score response did not contain a record.',
          );
        }
        value = records.first;
        continue;
      }
      if (value is! Map) break;

      final map = value.map((key, value) => MapEntry('$key', value));
      if (map['score'] is num || map['score'] is String) return map;

      dynamic nested;
      for (final key in const [
        'data',
        'result',
        'customer_score',
        'customerScore',
        'results',
        'items',
      ]) {
        final candidate = map[key];
        if (candidate is Map || candidate is List) {
          nested = candidate;
          break;
        }
      }
      if (nested == null) return map;
      value = nested;
    }
    throw const FormatException('The customer score response is invalid.');
  }

  /// Uses the authenticated summary endpoint for balances and the refreshed
  /// payment records for the status-specific counts shown on Dashboard.
  FinancialSummary financialSummaryFor(List<PaymentItem> list) {
    final server = _paymentsRepository is PaymentsRepositoryImpl
        ? _paymentsRepository.serverSummary
        : null;

    var pendingReview = 0;
    var awaitingPkr = 0;
    var localCompleted = 0;
    var completedNetPkr = 0.0;
    var localTransferred = 0.0;

    for (final item in list) {
      switch (item.status) {
        case PaymentStatusType.submitted:
        case PaymentStatusType.underReview:
        case PaymentStatusType.pendingReview:
          pendingReview++;
          break;
        case PaymentStatusType.verified:
        case PaymentStatusType.awaitingPkr:
          awaitingPkr++;
          break;
        case PaymentStatusType.pkrSent:
          break;
        case PaymentStatusType.completed:
          localCompleted++;
          completedNetPkr += item.netPkr;
          localTransferred += item.netPkr;
          break;
        case PaymentStatusType.onHold:
        case PaymentStatusType.rejected:
          break;
      }
    }

    final completed = server?.completedCount ?? localCompleted;
    return FinancialSummary(
      pkrReceived: server?.grossPkrReceived ?? completedNetPkr,
      paymentsCompleted: completed,
      totalTransferred: server?.transferred ?? localTransferred,
      awaitingVerificationAmount: null,
      awaitingVerificationCount:
          server?.pendingCount ?? (pendingReview + awaitingPkr),
      transactionsCount: server?.totalCount ?? list.length,
      pendingReviewCount: pendingReview,
      awaitingPkrCount: awaitingPkr,
      completedCount: completed,
    );
  }

  @override
  Future<FinancialSummary> getFinancialSummary() async =>
      financialSummaryFor(_paymentsRepository.payments);
}
