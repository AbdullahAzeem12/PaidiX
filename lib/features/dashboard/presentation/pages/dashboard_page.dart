import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_date_picker_theme.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../payments/data/payments_repository_impl.dart';
import '../../../payments/domain/payment_models.dart';
import '../../../payments/presentation/widgets/payment_card.dart';
import '../../../payments/presentation/widgets/payments_table.dart';
import '../../../profile/data/user_profile_repository.dart';
import '../../../profile/domain/user_profile.dart';
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

  // Filters section is closed by default as per requirement
  bool _isFiltersExpanded = false;
  DateRangeFilter _selectedRange = DateRangeFilter.thisMonth;
  StatusFilterOption _selectedStatus = StatusFilterOption.all;
  DateTime? _fromDate;
  DateTime? _toDate;

  @override
  void initState() {
    super.initState();
    _dashboardRepo = DashboardRepositoryImpl(widget.paymentsRepository);
  }

  PaymentFilter get _currentFilter => PaymentFilter(
        dateRange: _selectedRange,
        status: _selectedStatus,
        fromDate: _fromDate,
        toDate: _toDate,
      );

  FinancialSummary _computeSummary(List<PaymentItem> list) {
    if (list.isEmpty) {
      return FinancialSummary.empty();
    }

    int pendingReview = 0;
    int awaitingPkr = 0;
    int completed = 0;
    double pkrReceived = 0.0;
    double totalTransferred = 0.0;
    double awaitingVerificationAmount = 0.0;

    for (final item in list) {
      switch (item.status) {
        case PaymentStatusType.completed:
          completed++;
          pkrReceived += item.netPkr;
          totalTransferred += item.amount;
          break;
        case PaymentStatusType.underReview:
        case PaymentStatusType.pendingReview:
          pendingReview++;
          awaitingVerificationAmount += item.amount;
          break;
        case PaymentStatusType.pkrSent:
        case PaymentStatusType.awaitingPkr:
          awaitingPkr++;
          awaitingVerificationAmount += item.amount;
          break;
        case PaymentStatusType.submitted:
        case PaymentStatusType.verified:
        case PaymentStatusType.onHold:
        case PaymentStatusType.rejected:
          break;
      }
    }

    return FinancialSummary(
      pkrReceived: pkrReceived,
      paymentsCompleted: completed,
      totalTransferred: totalTransferred,
      awaitingVerificationAmount: (pendingReview + awaitingPkr) > 0
          ? awaitingVerificationAmount
          : null,
      awaitingVerificationCount: pendingReview + awaitingPkr,
      transactionsCount: list.length,
      pendingReviewCount: pendingReview,
      awaitingPkrCount: awaitingPkr,
      completedCount: completed,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: widget.paymentsRepository.paymentsListenable,
      builder: (context, payments, _) {
        return ValueListenableBuilder<UserProfile>(
          valueListenable: UserProfileRepository.instance.profileNotifier,
          builder: (context, userProfile, _) {
            return FutureBuilder<CustomerScore?>(
              future: _dashboardRepo.getCustomerScore(),
              builder: (context, snapshot) {
                final colors = AppColors.of(context);
                final score = snapshot.data;
                final isKycApproved =
                    userProfile.kycStatus == KycReviewStatus.verified;

                // Reactive real-time filtered payments & summary
                final filteredPayments =
                    widget.paymentsRepository.filterPayments(_currentFilter);
                final summary = _computeSummary(filteredPayments);

                return Scaffold(
                  backgroundColor: colors.background,
                  body: SafeArea(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header (Greeting, Basic Plan & New Payment button / Locked indicator)
                          _buildHeader(context, userProfile, isKycApproved),
                          const SizedBox(height: 18),

                          // KYC Pending Lock Warning Banner (when profile is not yet approved)
                          if (!isKycApproved) ...[
                            _buildKycLockBanner(context, userProfile, colors),
                            const SizedBox(height: 22),
                          ],

                          // Customer Score Card (Hero 50 — NEW for starter / dynamic for activity)
                          CustomerScoreCard(score: score),
                          const SizedBox(height: 24),

                          // FILTERS Bar (Closed by default, expandable with Range, From/To calendar, Status)
                          _buildFiltersBar(colors),
                          const SizedBox(height: 28),

                          // Section Title: YOUR MONEY, AT A GLANCE
                          _buildSectionHeader(
                            title: 'YOUR MONEY, AT A GLANCE',
                            actionText: 'View all',
                            onAction: () => context.go('/app/payments'),
                            colors: colors,
                          ),
                          const SizedBox(height: 14),

                          // If payments are empty (Initial state shown in screenshot)
                          if (filteredPayments.isEmpty) ...[
                            // Empty Transactions Card Container
                            _buildEmptyTransactionsCard(colors),
                            const SizedBox(height: 20),

                            // 4 Small Status Metric Cards
                            _buildStatusSummaryGrid(context, summary),
                            const SizedBox(height: 32),

                            // RECENT ACTIVITY Section
                            _buildSectionHeader(
                              title: 'RECENT ACTIVITY',
                              actionText: 'View all payments',
                              onAction: () => context.go('/app/payments'),
                              colors: colors,
                            ),
                            const SizedBox(height: 14),

                            // Empty Recent Activity Card matching Screenshot 1
                            _buildEmptyRecentActivityCard(colors),
                          ] else ...[
                            // 3 Large Financial Stat Cards
                            _buildLargeFinancialCards(context, summary),
                            const SizedBox(height: 16),

                            // 4 Small Status Metric Cards
                            _buildStatusSummaryGrid(context, summary),
                            const SizedBox(height: 32),

                            // RECENT ACTIVITY Section
                            _buildSectionHeader(
                              title: 'RECENT ACTIVITY',
                              actionText: 'View all payments',
                              onAction: () => context.go('/app/payments'),
                              colors: colors,
                            ),
                            const SizedBox(height: 14),

                            // Payments table or cards
                            LayoutBuilder(
                              builder: (context, constraints) {
                                if (constraints.maxWidth >= 768) {
                                  return PaymentsTable(
                                    items: filteredPayments.take(5).toList(),
                                  );
                                }
                                return Column(
                                  children: filteredPayments
                                      .take(4)
                                      .map((p) => PaymentCard(item: p))
                                      .toList(),
                                );
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildHeader(
    BuildContext context,
    UserProfile userProfile,
    bool isKycApproved,
  ) {
    final colors = AppColors.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmall = constraints.maxWidth < 600;

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
            const SizedBox(height: 4),
            Text(
              'Hello, ${userProfile.firstName}.',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Your global balances, side-by-side.',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
                color: colors.textSecondary,
              ),
            ),
          ],
        );

        final actionWidget = !isKycApproved
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.lock_outline_rounded,
                    size: 15,
                    color: colors.textSecondary.withValues(alpha: 0.8),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'New payment locked',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: colors.textSecondary.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              )
            : AppButton(
                text: 'New Payment',
                variant: AppButtonVariant.primary,
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
              actionWidget,
            ],
          );
        }

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(child: titleBlock),
            const SizedBox(width: 16),
            actionWidget,
          ],
        );
      },
    );
  }

  /// Warning banner displayed when KYC verification is pending review
  Widget _buildKycLockBanner(
    BuildContext context,
    UserProfile userProfile,
    PaidiXColorScheme colors,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: colors.cardDark,
        borderRadius: AppSpacing.radiusXl,
        border: Border.all(
          color: colors.border.withValues(alpha: 0.9),
          width: 1.2,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
              Icons.warning_amber_rounded,
              color: colors.gold,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'New payments are locked until your profile is approved.',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Current KYC status: Pending review. You can still add or edit your bank accounts in the meantime.',
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.45,
                    color: colors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                // "Go to Profile -->" with animated color transition & navigation
                AnimatedProfileLink(
                  onTap: () => context.go('/app/onboarding'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Collapsible FILTERS bar (Closed by default, expanding to reveal Range, From/To Calendar pickers, and Status dropdowns)
  Widget _buildFiltersBar(PaidiXColorScheme colors) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: AppSpacing.radiusLg,
        border: Border.all(
          color: colors.border.withValues(alpha: 0.8),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Filter toggle header (tapping expands/collapses)
          InkWell(
            onTap: () => setState(() => _isFiltersExpanded = !_isFiltersExpanded),
            borderRadius: AppSpacing.radiusLg,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.tune_rounded,
                        size: 15,
                        color: colors.textSecondary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'FILTERS',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  AnimatedRotation(
                    turns: _isFiltersExpanded ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOutCubic,
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 18,
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Collapsible filter body
          AnimatedSize(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeInOutCubic,
            child: _isFiltersExpanded
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Divider(
                          color: colors.divider.withValues(alpha: 0.6),
                          height: 1,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // 1. Range Dropdown Button
                            _buildRangeDropdown(context, colors),
                            const SizedBox(width: 14),

                            // 2. From Label + Input with Calendar Icon
                            _buildDateInput(
                              context: context,
                              label: 'From',
                              date: _fromDate,
                              onTap: () => _pickFromDate(context, colors),
                              onClear: () {
                                setState(() {
                                  _fromDate = null;
                                  if (_toDate == null) {
                                    _selectedRange = DateRangeFilter.thisMonth;
                                  }
                                });
                              },
                              colors: colors,
                            ),
                            const SizedBox(width: 14),

                            // 3. — To Label + Input with Calendar Icon
                            _buildDateInput(
                              context: context,
                              label: '— To',
                              date: _toDate,
                              onTap: () => _pickToDate(context, colors),
                              onClear: () {
                                setState(() {
                                  _toDate = null;
                                  if (_fromDate == null) {
                                    _selectedRange = DateRangeFilter.thisMonth;
                                  }
                                });
                              },
                              colors: colors,
                            ),
                            const SizedBox(width: 14),

                            // 4. Status Dropdown Button
                            _buildStatusDropdown(context, colors),
                          ],
                        ),
                      ),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  /// Range Dropdown button showing Range: selected and opening full 14 options
  Widget _buildRangeDropdown(BuildContext context, PaidiXColorScheme colors) {
    return Theme(
      data: Theme.of(context).copyWith(
        popupMenuTheme: PopupMenuThemeData(
          color: colors.cardDark,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(
              color: colors.border.withValues(alpha: 0.9),
              width: 1.1,
            ),
          ),
          elevation: 10,
        ),
      ),
      child: PopupMenuButton<DateRangeFilter>(
        tooltip: '',
        offset: const Offset(0, 42),
        color: colors.cardDark,
        elevation: 10,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: colors.border.withValues(alpha: 0.9),
            width: 1.1,
          ),
        ),
        onSelected: (val) {
          if (val == DateRangeFilter.custom) {
            _pickCustomRange(context, colors);
          } else {
            setState(() {
              _selectedRange = val;
              _fromDate = null;
              _toDate = null;
            });
          }
        },
        itemBuilder: (ctx) {
          return DateRangeFilter.values.map((range) {
            final isSelected = range == _selectedRange && _fromDate == null && _toDate == null ||
                (range == DateRangeFilter.custom && (_fromDate != null || _toDate != null));
            return PopupMenuItem<DateRangeFilter>(
              value: range,
              height: 38,
              padding: EdgeInsets.zero,
              child: Container(
                width: double.infinity,
                height: 38,
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                color: isSelected
                    ? colors.cardHighlight
                    : Colors.transparent,
                child: Text(
                  range.label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight:
                        isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? colors.aquaLight : colors.textPrimary,
                  ),
                ),
              ),
            );
          }).toList();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7.5),
          decoration: BoxDecoration(
            color: colors.cardDark,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: colors.border.withValues(alpha: 0.9),
              width: 1.1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: 'Range: ',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: colors.aqua,
                      ),
                    ),
                    TextSpan(
                      text: _selectedRange.label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: colors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 16,
                color: colors.aqua,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Date picker input displaying From/To [ mm/dd/yyyy ] with interactive calendar
  Widget _buildDateInput({
    required BuildContext context,
    required String label,
    required DateTime? date,
    required VoidCallback onTap,
    required VoidCallback onClear,
    required PaidiXColorScheme colors,
  }) {
    final hasDate = date != null;
    final dateText = hasDate
        ? '${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}/${date.year}'
        : 'mm/dd/yyyy';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: colors.textSecondary,
          ),
        ),
        const SizedBox(width: 8),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7.5),
            decoration: BoxDecoration(
              color: colors.cardDark,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: hasDate
                    ? colors.aqua.withValues(alpha: 0.6)
                    : colors.border.withValues(alpha: 0.9),
                width: 1.1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  dateText,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: hasDate ? FontWeight.w600 : FontWeight.w400,
                    color: hasDate
                        ? colors.textPrimary
                        : colors.textSecondary.withValues(alpha: 0.7),
                    letterSpacing: hasDate ? 0.3 : 0.8,
                  ),
                ),
                const SizedBox(width: 12),
                if (hasDate)
                  GestureDetector(
                    onTap: onClear,
                    child: Icon(
                      Icons.close_rounded,
                      size: 14,
                      color: colors.textSecondary,
                    ),
                  )
                else
                  Icon(
                    Icons.calendar_today_outlined,
                    size: 15,
                    color: colors.textSecondary,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Status Dropdown button showing Status: selected and opening 8 statuses
  Widget _buildStatusDropdown(BuildContext context, PaidiXColorScheme colors) {
    return Theme(
      data: Theme.of(context).copyWith(
        popupMenuTheme: PopupMenuThemeData(
          color: colors.cardDark,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(
              color: colors.border.withValues(alpha: 0.9),
              width: 1.1,
            ),
          ),
          elevation: 10,
        ),
      ),
      child: PopupMenuButton<StatusFilterOption>(
        tooltip: '',
        offset: const Offset(0, 42),
        color: colors.cardDark,
        elevation: 10,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: colors.border.withValues(alpha: 0.9),
            width: 1.1,
          ),
        ),
        onSelected: (val) {
          setState(() {
            _selectedStatus = val;
          });
        },
        itemBuilder: (ctx) {
          return StatusFilterOption.values.map((status) {
            final isSelected = status == _selectedStatus;
            return PopupMenuItem<StatusFilterOption>(
              value: status,
              height: 38,
              padding: EdgeInsets.zero,
              child: Container(
                width: double.infinity,
                height: 38,
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                color: isSelected
                    ? colors.cardHighlight
                    : Colors.transparent,
                child: Text(
                  status.label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight:
                        isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? colors.aquaLight : colors.textPrimary,
                  ),
                ),
              ),
            );
          }).toList();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7.5),
          decoration: BoxDecoration(
            color: colors.cardDark,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: colors.border.withValues(alpha: 0.9),
              width: 1.1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: 'Status: ',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: colors.aqua,
                      ),
                    ),
                    TextSpan(
                      text: _selectedStatus.label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: colors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 16,
                color: colors.aqua,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Calendar picker for "From" date
  Future<void> _pickFromDate(BuildContext context, PaidiXColorScheme colors) async {
    final now = DateTime.now();
    final initial = _fromDate ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isAfter(DateTime(2035)) ? now : initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      builder: (context, child) =>
          buildAppDatePickerTheme(context, child!),
      helpText: 'SELECT FROM DATE',
      confirmText: 'SELECT',
      cancelText: 'CANCEL',
    );
    if (picked != null) {
      setState(() {
        _fromDate = picked;
        // Reset "To" date immediately so the user can easily select a fresh date
        _toDate = null;
        _selectedRange = DateRangeFilter.custom;
      });
    }
  }

  /// Calendar picker for "To" date
  Future<void> _pickToDate(BuildContext context, PaidiXColorScheme colors) async {
    final now = DateTime.now();
    final firstDate = _fromDate ?? DateTime(2020);
    final lastDate = DateTime(2035);

    // Starts from today's date so the user can easily select from their own choice
    DateTime initial = _toDate ?? now;
    if (initial.isBefore(firstDate)) {
      initial = firstDate;
    } else if (initial.isAfter(lastDate)) {
      initial = lastDate;
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: firstDate,
      lastDate: lastDate,
      builder: (context, child) =>
          buildAppDatePickerTheme(context, child!),
      helpText: 'SELECT TO DATE',
      confirmText: 'SELECT',
      cancelText: 'CANCEL',
    );
    if (picked != null) {
      setState(() {
        _toDate = picked;
        _selectedRange = DateRangeFilter.custom;
      });
    }
  }

  /// Calendar picker for custom date range
  Future<void> _pickCustomRange(
    BuildContext context,
    PaidiXColorScheme colors,
  ) async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      initialDateRange: (_fromDate != null && _toDate != null)
          ? DateTimeRange(start: _fromDate!, end: _toDate!)
          : DateTimeRange(
              start: DateTime(now.year, now.month, 1),
              end: DateTime(now.year, now.month, now.day),
            ),
      builder: (context, child) =>
          buildAppDatePickerTheme(context, child!),
      helpText: 'SELECT DATE RANGE',
      saveText: 'APPLY',
    );
    if (picked != null) {
      setState(() {
        _fromDate = picked.start;
        _toDate = picked.end;
        _selectedRange = DateRangeFilter.custom;
      });
    }
  }

  Widget _buildEmptyTransactionsCard(PaidiXColorScheme colors) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: AppSpacing.radiusXl,
        border: Border.all(
          color: colors.border.withValues(alpha: 0.8),
          width: 1.2,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.description_outlined,
            size: 34,
            color: colors.aqua,
          ),
          const SizedBox(height: 14),
          Text(
            'No transactions yet',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Submit your first incoming payment to start tracking your money.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              color: colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyRecentActivityCard(PaidiXColorScheme colors) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: AppSpacing.radiusXl,
        border: Border.all(
          color: colors.border.withValues(alpha: 0.8),
          width: 1.2,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.description_outlined,
            size: 34,
            color: colors.aqua,
          ),
          const SizedBox(height: 14),
          Text(
            'No payments yet',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'When you submit an incoming payment, it will show up here.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              color: colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader({
    required String title,
    required String actionText,
    required VoidCallback onAction,
    required PaidiXColorScheme colors,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.sectionEyebrow.copyWith(
              color: colors.textSecondary,
            ),
          ),
        ),
        const SizedBox(width: 8),
        InkWell(
          onTap: onAction,
          borderRadius: BorderRadius.circular(4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                actionText,
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
          title: 'TRANSACTIONS',
          count: '${summary.transactionsCount}',
          iconBgColor: colors.aquaLight,
          icon: Icon(Icons.description_outlined,
              color: colors.mintHeroText, size: 16),
        );

        final item2 = StatusMetricCard(
          title: 'PENDING REVIEW',
          count: '${summary.pendingReviewCount}',
          iconBgColor: colors.aquaLight,
          icon: Icon(Icons.access_time_rounded,
              color: colors.mintHeroText, size: 16),
        );

        final item3 = StatusMetricCard(
          title: 'AWAITING PKR',
          count: '${summary.awaitingPkrCount}',
          iconBgColor: colors.aquaLight,
          icon: Icon(Icons.arrow_outward_rounded,
              color: colors.mintHeroText, size: 16),
        );

        final item4 = StatusMetricCard(
          title: 'COMPLETED',
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

/// Interactive link for "Go to profile →" with color flash transition,
/// soft spongy scale compression, arrow translation, and haptic feedback.
class AnimatedProfileLink extends StatefulWidget {
  final VoidCallback onTap;

  const AnimatedProfileLink({super.key, required this.onTap});

  @override
  State<AnimatedProfileLink> createState() => _AnimatedProfileLinkState();
}

class _AnimatedProfileLinkState extends State<AnimatedProfileLink>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _slideAnimation;
  bool _isHovered = false;
  bool _isTapped = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 140),
      reverseDuration: const Duration(milliseconds: 260),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.94).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInCubic,
        reverseCurve: Curves.easeOutBack,
      ),
    );
    _slideAnimation = Tween<double>(begin: 0.0, end: 5.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    HapticFeedback.lightImpact();
    setState(() => _isTapped = true);
    _controller.forward().then((_) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          _controller.reverse();
          Future.delayed(const Duration(milliseconds: 220), () {
            if (mounted) setState(() => _isTapped = false);
          });
        }
      });
    });

    // Provide brief window for user to witness the color & motion transition before route transition
    Future.delayed(const Duration(milliseconds: 180), () {
      widget.onTap();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final normalColor = colors.aqua;
    final activeColor = Colors.white;

    final targetColor =
        _isTapped ? activeColor : (_isHovered ? colors.aquaLight : normalColor);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: _handleTap,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              alignment: Alignment.centerLeft,
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: targetColor,
                  letterSpacing: 0.2,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Go to profile'),
                    const SizedBox(width: 6),
                    Transform.translate(
                      offset: Offset(_slideAnimation.value, 0),
                      child: Icon(
                        Icons.arrow_forward_rounded,
                        size: 14,
                        color: targetColor,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
