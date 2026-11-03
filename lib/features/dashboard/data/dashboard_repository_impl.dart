import '../../../core/widgets/status_badge.dart';
import '../../payments/domain/payments_repository.dart';
import '../../profile/data/user_profile_repository.dart';
import '../../profile/domain/user_profile.dart';
import '../domain/dashboard_models.dart';
import '../domain/dashboard_repository.dart';

class DashboardRepositoryImpl implements DashboardRepository {
  final PaymentsRepository _paymentsRepository;

  DashboardRepositoryImpl(this._paymentsRepository);

  @override
  Future<CustomerScore?> getCustomerScore() async {
    final list = _paymentsRepository.payments;
    final profile = UserProfileRepository.instance.profile;
    final isKycVerified = profile.kycStatus == KycReviewStatus.verified;

    if (list.isEmpty) {
      // First-time sign up / fresh account: initial 50 points
      return CustomerScore.starter();
    }

    final completed =
        list.where((p) => p.status == PaymentStatusType.completed).toList();
    final volume =
        completed.fold<double>(0.0, (acc, item) => acc + item.netPkr);

    return CustomerScore.calculate(
      totalTransactions: list.length,
      completedCount: completed.length,
      totalVolumePkr: volume,
      isKycVerified: isKycVerified,
    );
  }

  @override
  Future<FinancialSummary> getFinancialSummary() async {
    final list = _paymentsRepository.payments;
    if (list.isEmpty) {
      return FinancialSummary.empty();
    }

    int pendingReview = 0;
    int awaitingPkr = 0;
    int completed = 0;

    for (final item in list) {
      switch (item.status) {
        case PaymentStatusType.completed:
          completed++;
          break;
        case PaymentStatusType.underReview:
        case PaymentStatusType.pendingReview:
          pendingReview++;
          break;
        case PaymentStatusType.pkrSent:
        case PaymentStatusType.awaitingPkr:
          awaitingPkr++;
          break;
        case PaymentStatusType.submitted:
        case PaymentStatusType.verified:
        case PaymentStatusType.onHold:
        case PaymentStatusType.rejected:
          break;
      }
    }

    return FinancialSummary(
      pkrReceived: 0.0,
      paymentsCompleted: 0,
      totalTransferred: 0.0,
      awaitingVerificationAmount: null, // em dash
      awaitingVerificationCount: pendingReview + awaitingPkr,
      transactionsCount: list.length,
      pendingReviewCount: pendingReview,
      awaitingPkrCount: awaitingPkr,
      completedCount: completed,
    );
  }
}
