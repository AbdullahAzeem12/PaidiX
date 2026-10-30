import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../payments/data/payments_repository_impl.dart';
import '../../../payments/presentation/widgets/payment_card.dart';
import '../../../payments/presentation/widgets/payments_table.dart';
import '../../../profile/data/user_profile_repository.dart';
import '../../data/dashboard_repository_impl.dart';
import '../../domain/dashboard_models.dart';
import '../widgets/customer_score_card.dart';
import '../widgets/financial_stat_card.dart';
import '../widgets/status_metric_card.dart';

class DashboardPage extends StatefulWidget {
  final PaymentsRepositoryImpl paymentsRepository;

  const DashboardPage({super.key, required this.paymentsRepository});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late final DashboardRepositoryImpl _dashboardRepo;

  @override
  void initState() {
    super.initState();
    _dashboardRepo = DashboardRepositoryImpl(widget.paymentsRepository);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: widget.paymentsRepository.paymentsListenable,
      builder: (context, payments, _) {
        return FutureBuilder<(CustomerScore?, FinancialSummary)>(
          future: Future.wait([
            _dashboardRepo.getCustomerScore(),
            _dashboardRepo.getFinancialSummary(),
          ]).then(
              (res) => (res[0] as CustomerScore?, res[1] as FinancialSummary)),
          builder: (context, snapshot) {
            final colors = AppColors.of(context);
            final score = snapshot.data?.$1;
            final summary = snapshot.data?.$2 ?? FinancialSummary.empty();

            return Scaffold(
              backgroundColor: colors.background,
              body: SafeArea(
                child: SingleChildScrollView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header & New Payment button
                      _buildHeader(context),
                      const SizedBox(height: 22),

                      // Customer Score Card (Hero Mint Banner)
                      CustomerScoreCard(score: score),
                      const SizedBox(height: 28),

                      // Section Title: YOUR MONEY, AT A GLANCE
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'YOUR MONEY, AT A GLANCE',
                            style: AppTypography.sectionEyebrow.copyWith(
                              color: colors.textSecondary,
                            ),
                          ),
                          InkWell(
                            onTap: () => context.go('/app/payments'),
                            child: Row(
                              children: [
                                Text(
                                  'View all',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: colors.aqua,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.arrow_outward_rounded,
                                  size: 13,
                                  color: colors.aqua,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // 3 Large Financial Stat Cards
                      _buildLargeFinancialCards(context, summary),
                      const SizedBox(height: 16),

                      // 4 Small Status Metric Cards
                      _buildStatusSummaryGrid(context, summary),
                      const SizedBox(height: 32),

                      // RECENT ACTIVITY Section
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'RECENT ACTIVITY',
                            style: AppTypography.sectionEyebrow.copyWith(
                              color: colors.textSecondary,
                            ),
                          ),
                          if (payments.isNotEmpty)
                            InkWell(
                              onTap: () => context.go('/app/payments'),
                              child: Row(
                                children: [
                                  Text(
                                    'View all payments',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: colors.aqua,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(
                                    Icons.arrow_outward_rounded,
                                    size: 13,
                                    color: colors.aqua,
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Recent activity content
                      if (payments.isEmpty)
                        EmptyStateView(
                          title: 'No recent activity',
                          subtitle:
                              'Submit your first incoming payment to start tracking your balances and transfers.',
                          actionText: 'New payment',
                          onAction: () => context.go('/app/payments/new'),
                        )
                      else
                        LayoutBuilder(
                          builder: (context, constraints) {
                            if (constraints.maxWidth >= 768) {
                              return PaymentsTable(
                                items: payments.take(5).toList(),
                              );
                            }
                            return Column(
                              children: payments
                                  .take(4)
                                  .map((p) => PaymentCard(item: p))
                                  .toList(),
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context) {
    final colors = AppColors.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmall = constraints.maxWidth < 600;

        final userProfile = UserProfileRepository.instance.profile;
        final titleBlock = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'BASIC PLAN',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
                color: colors.gold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Hello, ${userProfile.firstName}.',
              style:
                  AppTypography.pageHeading.copyWith(color: colors.textPrimary),
            ),
            const SizedBox(height: 4),
            Text(
              'Your global balances, side-by-side.',
              style: AppTypography.pageSubtitle
                  .copyWith(color: colors.textSecondary),
            ),
          ],
        );

        final actionBtn = AppButton(
          text: 'New payment',
          icon: Icon(
            Icons.add_circle_outline_rounded,
            size: 18,
            color: colors.primaryButtonText,
          ),
          onPressed: () => context.go('/app/payments/new'),
        );

        if (isSmall) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              titleBlock,
              const SizedBox(height: 16),
              actionBtn,
            ],
          );
        }

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(child: titleBlock),
            const SizedBox(width: 16),
            actionBtn,
          ],
        );
      },
    );
  }

  Widget _buildLargeFinancialCards(
      BuildContext context, FinancialSummary summary) {
    final colors = AppColors.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 850;

        final card1 = FinancialStatCard(
          title: 'PKR RECEIVED',
          value: AppFormatters.formatPkr(summary.pkrReceived),
          subtext: '${summary.paymentsCompleted} payments completed',
          description:
              'Net PKR deposited to your bank account from completed transactions.',
          iconBg: colors.aquaLight,
          icon: Icon(Icons.account_balance_wallet_outlined,
              color: colors.mintHeroText, size: 18),
        );

        final card2 = FinancialStatCard(
          title: 'TOTAL TRANSFERRED TO YOU',
          value: AppFormatters.formatPkr(summary.totalTransferred),
          subtext: 'Lifetime PKR',
          description:
              "Everything we've sent to your bank account since joining PaidiX.",
          iconBg: colors.cardDark,
          icon: Icon(Icons.send_rounded, color: colors.aquaLight, size: 18),
        );

        final card3 = FinancialStatCard(
          title: 'AWAITING VERIFICATION',
          value: summary.awaitingVerificationAmount != null
              ? AppFormatters.formatPkr(summary.awaitingVerificationAmount)
              : '—',
          subtext: '${summary.awaitingVerificationCount} payments in progress',
          description:
              'Payments still being processed. Foreign-currency amounts are shown below.',
          iconBg: colors.gold,
          icon: Icon(Icons.access_time_rounded,
              color: colors.mintHeroText, size: 18),
        );

        if (isWide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: card1),
              const SizedBox(width: 14),
              Expanded(child: card2),
              const SizedBox(width: 14),
              Expanded(child: card3),
            ],
          );
        }

        return Column(
          children: [
            card1,
            const SizedBox(height: 14),
            card2,
            const SizedBox(height: 14),
            card3,
          ],
        );
      },
    );
  }

  Widget _buildStatusSummaryGrid(
      BuildContext context, FinancialSummary summary) {
    final colors = AppColors.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 600;

        final item1 = StatusMetricCard(
          title: 'Transactions',
          count: '${summary.transactionsCount}',
          iconBgColor: colors.aquaLight,
          icon: Icon(Icons.description_outlined,
              color: colors.mintHeroText, size: 16),
        );

        final item2 = StatusMetricCard(
          title: 'Pending Review',
          count: '${summary.pendingReviewCount}',
          iconBgColor: colors.aquaLight,
          icon: Icon(Icons.access_time_rounded,
              color: colors.mintHeroText, size: 16),
        );

        final item3 = StatusMetricCard(
          title: 'Awaiting PKR',
          count: '${summary.awaitingPkrCount}',
          iconBgColor: colors.aquaLight,
          icon: Icon(Icons.arrow_outward_rounded,
              color: colors.mintHeroText, size: 16),
        );

        final item4 = StatusMetricCard(
          title: 'Completed',
          count: '${summary.completedCount}',
          iconBgColor: colors.statusCompletedDot,
          icon: Icon(Icons.check_circle_outline,
              color: colors.mintHeroText, size: 16),
        );

        if (isWide) {
          return Row(
            children: [
              Expanded(child: item1),
              const SizedBox(width: 12),
              Expanded(child: item2),
              const SizedBox(width: 12),
              Expanded(child: item3),
              const SizedBox(width: 12),
              Expanded(child: item4),
            ],
          );
        }

        return Column(
          children: [
            Row(
              children: [
                Expanded(child: item1),
                const SizedBox(width: 10),
                Expanded(child: item2),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: item3),
                const SizedBox(width: 10),
                Expanded(child: item4),
              ],
            ),
          ],
        );
      },
    );
  }
}
