/// Defines dashboard page in the dashboard feature's presentation layer.

import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/widgets/paidix_toast.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_date_picker_theme.dart';
import '../../../../core/widgets/payments_pin_lock_scope.dart';
import '../../../../core/widgets/spongy_tap.dart';
import '../../../payments/data/payments_repository_impl.dart';
import '../../../payments/domain/payment_models.dart';
import '../../../payments/presentation/widgets/payment_card.dart';
import '../../../payments/presentation/widgets/payments_table.dart';
import '../../../payments/presentation/widgets/smooth_animated_list_item.dart';
import '../../../profile/data/user_profile_repository.dart';
import '../../../profile/domain/user_profile.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../settings/domain/fx_display_preferences.dart';
import '../../data/dashboard_repository_impl.dart';
import '../../domain/dashboard_models.dart';
import '../widgets/customer_score_card.dart';
import '../widgets/financial_stat_card.dart';
import '../widgets/status_metric_card.dart';

class DashboardPage extends StatefulWidget {
  final PaymentsRepositoryImpl paymentsRepository;

  const DashboardPage({super.key, required this.paymentsRepository});

  /// Creates the mutable state object that backs this stateful widget.
  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage>
    with WidgetsBindingObserver {
  late final DashboardRepositoryImpl _dashboardRepo;
  VoidCallback? _releasePaymentPolling;
  final ValueNotifier<CustomerScore?> _customerScoreNotifier = ValueNotifier(
    null,
  );
  Timer? _customerScoreTimer;
  Future<bool>? _customerScoreRefresh;
  String _scoreAccountEmail = '';

  // Filters section is closed by default as per requirement
  bool _isFiltersExpanded = false;
  DateRangeFilter _selectedRange = DateRangeFilter.allTime;
  CurrencyFilter _selectedCurrency = CurrencyFilter.all;
  StatusFilterOption _selectedStatus = StatusFilterOption.all;
  DateTime? _fromDate;
  DateTime? _toDate;

  /// Initializes controllers, listeners, and other state owned by this widget.
  @override
  void initState() {
    super.initState();
    _dashboardRepo = DashboardRepositoryImpl(widget.paymentsRepository);
    WidgetsBinding.instance.addObserver(this);
    _scoreAccountEmail = _currentAccountEmail;
    _customerScoreNotifier.addListener(_onCustomerScoreChanged);
    if (AppConfig.hasCustomBackend) {
      UserProfileRepository.instance.profileNotifier.addListener(
        _onProfileChanged,
      );
      _startCustomerScorePolling();
      unawaited(_refreshCustomerScore());
    } else {
      _customerScoreNotifier.value = _dashboardRepo.customerScoreFor(
        UserProfileRepository.instance.profile,
      );
    }
    _startPaymentPolling();
  }

  String get _currentAccountEmail =>
      UserProfileRepository.instance.profile.email.trim().toLowerCase();

  void _onCustomerScoreChanged() {
    if (mounted) setState(() {});
  }

  void _onProfileChanged() {
    final email = _currentAccountEmail;
    if (email == _scoreAccountEmail) return;
    _scoreAccountEmail = email;
    _customerScoreNotifier.value = null;
    final inFlight = _customerScoreRefresh;
    if (inFlight == null) {
      unawaited(_refreshCustomerScore());
    } else {
      unawaited(
        inFlight.whenComplete(() {
          if (mounted && email == _currentAccountEmail) {
            unawaited(_refreshCustomerScore());
          }
        }),
      );
    }
  }

  void _startCustomerScorePolling() {
    if (!AppConfig.hasCustomBackend || _customerScoreTimer != null) return;
    _customerScoreTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => unawaited(_refreshCustomerScore()),
    );
  }

  void _stopCustomerScorePolling() {
    _customerScoreTimer?.cancel();
    _customerScoreTimer = null;
  }

  Future<bool> _refreshCustomerScore() {
    final current = _customerScoreRefresh;
    if (current != null) return current;

    final requestedEmail = _currentAccountEmail;
    final request = _dashboardRepo
        .getCustomerScore()
        .then((score) {
          if (score == null || !score.isAvailable) return false;
          if (!mounted || requestedEmail != _currentAccountEmail) return false;
          if (score.userEmail != null && score.userEmail != requestedEmail) {
            return false;
          }
          _customerScoreNotifier.value = score;
          return true;
        })
        .catchError((Object _) => false);
    _customerScoreRefresh = request;
    return request.whenComplete(() {
      if (identical(_customerScoreRefresh, request)) {
        _customerScoreRefresh = null;
      }
    });
  }

  void _startPaymentPolling() {
    _releasePaymentPolling ??= widget.paymentsRepository.watchServerUpdates();
  }

  void _stopPaymentPolling() {
    _releasePaymentPolling?.call();
    _releasePaymentPolling = null;
  }

  Future<void> _refreshDashboard() async {
    try {
      final tasks = <Future<bool>>[
        widget.paymentsRepository.refreshServerDataWithResult(),
      ];
      if (AppConfig.hasCustomBackend) {
        tasks.add(_refreshCustomerScore());
        tasks.add(
          AuthRepository.instance.refreshKycReviewStatus().then((_) => true),
        );
      }
      final results = await Future.wait(tasks);
      if (mounted && results.any((success) => !success)) {
        PaidiXToast.showError(
          context,
          'Some dashboard data could not be refreshed. Showing the latest saved data.',
        );
      }
    } catch (_) {
      if (mounted) {
        PaidiXToast.showError(
          context,
          'Could not refresh dashboard data. Please try again.',
        );
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startPaymentPolling();
      _startCustomerScorePolling();
      if (AppConfig.hasCustomBackend) {
        unawaited(_refreshCustomerScore());
      }
    } else {
      _stopPaymentPolling();
      _stopCustomerScorePolling();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopPaymentPolling();
    _stopCustomerScorePolling();
    if (AppConfig.hasCustomBackend) {
      UserProfileRepository.instance.profileNotifier.removeListener(
        _onProfileChanged,
      );
    }
    _customerScoreNotifier
      ..removeListener(_onCustomerScoreChanged)
      ..dispose();
    super.dispose();
  }

  PaymentFilter get _currentFilter => PaymentFilter(
    dateRange: _selectedRange,
    currency: _selectedCurrency,
    status: _selectedStatus,
    fromDate: _fromDate,
    toDate: _toDate,
  );

  /// Aggregates the supplied payment list into dashboard counts and balances.
  FinancialSummary _computeSummary(List<PaymentItem> list) {
    return _dashboardRepo.financialSummaryFor(list);
  }

  /// Builds the widget subtree from its current properties and inherited context.
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: widget.paymentsRepository.paymentsListenable,
      builder: (context, payments, _) {
        return ValueListenableBuilder<UserProfile>(
          valueListenable: UserProfileRepository.instance.profileNotifier,
          builder: (context, userProfile, _) {
            return ValueListenableBuilder<PaymentsServerSummary?>(
              valueListenable:
                  widget.paymentsRepository.serverSummaryListenable,
              builder: (context, serverSummary, _) {
                final colors = AppColors.of(context);
                final score = AppConfig.hasCustomBackend
                    ? (_customerScoreNotifier.value?.userEmail == null ||
                              _customerScoreNotifier.value?.userEmail ==
                                  userProfile.email.trim().toLowerCase()
                          ? _customerScoreNotifier.value
                          : null)
                    : _dashboardRepo.customerScoreFor(userProfile);
                final isKycApproved =
                    userProfile.kycStatus == KycReviewStatus.verified;

                // Unfiltered by status for category metrics cards
                final statusUnfilteredPayments = widget.paymentsRepository
                    .filterPayments(
                      _currentFilter.copyWith(status: StatusFilterOption.all),
                    );
                final summary = _computeSummary(statusUnfilteredPayments);

                // Filtered payments taking all filters (including status) into account
                final filteredPayments = widget.paymentsRepository
                    .filterPayments(_currentFilter);
                final isRepoEmpty = serverSummary?.totalCount != null
                    ? serverSummary!.totalCount == 0
                    : widget.paymentsRepository.payments.isEmpty;
                final isInitialPaymentsLoad =
                    AppConfig.hasCustomBackend &&
                    !widget.paymentsRepository.hasLoadedFromServer &&
                    payments.isEmpty;

                return Scaffold(
                  backgroundColor: colors.background,
                  body: SafeArea(
                    child: RefreshIndicator(
                      color: colors.aqua,
                      backgroundColor: colors.card,
                      onRefresh: _refreshDashboard,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(
                          parent: BouncingScrollPhysics(),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 24,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header (Greeting & New Payment button / Locked indicator)
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

                            // If payments repository is truly empty (clean onboarding state)
                            if (isInitialPaymentsLoad) ...[
                              _buildPaymentsLoadingCard(colors),
                            ] else if (isRepoEmpty) ...[
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

                              // Active Filter Notification Banner
                              if (_selectedStatus != StatusFilterOption.all)
                                _buildActiveStatusFilterBanner(
                                  colors,
                                  Theme.of(context).brightness ==
                                      Brightness.dark,
                                  filteredPayments.length,
                                ),

                              // Filtered empty state or payments list
                              if (filteredPayments.isEmpty)
                                _buildFilteredEmptyState(colors)
                              else
                                AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 280),
                                  switchInCurve: Curves.easeOutCubic,
                                  switchOutCurve: Curves.easeInCubic,
                                  child: KeyedSubtree(
                                    key: ValueKey(
                                      'recent_${_selectedStatus.name}_${filteredPayments.length}',
                                    ),
                                    child: LayoutBuilder(
                                      builder: (context, constraints) {
                                        if (constraints.maxWidth >= 768) {
                                          return PaymentsTable(
                                            items: filteredPayments
                                                .take(5)
                                                .toList(),
                                          );
                                        }
                                        final recentList = filteredPayments
                                            .take(4)
                                            .toList();
                                        return Column(
                                          children: List.generate(
                                            recentList.length,
                                            (idx) => SmoothAnimatedListItem(
                                              index: idx,
                                              child: PaymentCard(
                                                item: recentList[idx],
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                            ],
                          ],
                        ),
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

  Widget _buildPaymentsLoadingCard(PaidiXColorScheme colors) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 42, horizontal: 20),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: AppSpacing.radiusXl,
        border: Border.all(color: colors.border),
      ),
      child: Center(child: CircularProgressIndicator(color: colors.aqua)),
    );
  }

  /// Builds the header section of this interface.
  Widget _buildHeader(
    BuildContext context,
    UserProfile userProfile,
    bool isKycApproved,
  ) {
    final colors = AppColors.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmall = constraints.maxWidth < 600;
        final pinLockScope = PaymentsPinLockScope.maybeOf(context);

        final titleBlock = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    'Hello, ${userProfile.firstName}.',
                    style: TextStyle(
                      fontFamily: AppTheme.activeFontFamily,
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                      color: colors.textPrimary,
                    ),
                  ),
                ),
                if (pinLockScope?.isConfigured == true)
                  IconButton(
                    tooltip: 'Lock dashboard',
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      pinLockScope!.onLockDashboard();
                    },
                    icon: const Icon(Icons.lock_outline_rounded),
                    color: colors.textSecondary,
                    style: IconButton.styleFrom(
                      backgroundColor: colors.card.withValues(alpha: .72),
                      side: BorderSide(color: colors.border),
                    ),
                  ),
              ],
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
            children: [titleBlock, const SizedBox(height: 16), actionWidget],
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
    final isRejected = userProfile.kycStatus == KycReviewStatus.rejected;
    final isResubmitted =
        userProfile.hasResubmittedKyc &&
        userProfile.kycStatus == KycReviewStatus.pendingReview;
    const resubmittedColor = Color(0xFF3B82F6);
    final accent = isRejected
        ? colors.ruby
        : isResubmitted
        ? resubmittedColor
        : colors.gold;
    final backgroundColor = isRejected || isResubmitted
        ? accent.withValues(alpha: 0.08)
        : colors.cardDark;
    final borderColor = isRejected || isResubmitted
        ? accent.withValues(alpha: 0.35)
        : colors.border.withValues(alpha: 0.9);
    final statusIcon = isRejected
        ? Icons.error_outline_rounded
        : isResubmitted
        ? Icons.sync_rounded
        : Icons.warning_amber_rounded;
    final statusMessage = switch (userProfile.kycStatus) {
      KycReviewStatus.rejected =>
        'You can update your information and resubmit.',
      KycReviewStatus.pendingReview =>
        isResubmitted
            ? 'New payments stay locked until approval. You wll see another update here if the reviewer raises objections or approves your account.'
            : 'Current KYC status: Pending review. You can still add or edit your bank accounts in the meantime.',
      KycReviewStatus.inProgress => 'Current KYC status: In progress. Complete your profile to unlock payments.',
      KycReviewStatus.notStarted =>
        'Complete KYC verification to unlock new payments.',
      KycReviewStatus.verified => '',
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: AppSpacing.radiusXl,
        border: Border.all(color: borderColor, width: 1.2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(statusIcon, color: accent, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isRejected
                      ? 'Your KYC submission was rejected.'
                      : isResubmitted
                      ? 'Thanks, your updated information is awaiting review.'
                      : 'New payments are locked until your profile is approved.',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  statusMessage,
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.45,
                    color: colors.textSecondary,
                  ),
                ),
                if (isRejected &&
                    userProfile.kycRejectionReason?.isNotEmpty == true) ...[
                  const SizedBox(height: 4),
                  Text(
                    userProfile.kycRejectionReason!,
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.4,
                      color: colors.textSecondary,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                // "Go to Profile -->" with animated color transition & navigation
                AnimatedProfileLink(onTap: () => context.go('/app/onboarding')),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Collapsible FILTERS bar (Closed by default, expanding to reveal Range, From/To Calendar pickers, and Status dropdowns)
  Widget _buildFiltersBar(PaidiXColorScheme colors) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeCount = _currentFilter.activeFilterCount;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;
        final headerHPad = isMobile ? 12.0 : 16.0;

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
                onTap: () =>
                    setState(() => _isFiltersExpanded = !_isFiltersExpanded),
                borderRadius: AppSpacing.radiusLg,
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: headerHPad,
                    vertical: 10.5,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.filter_list_rounded,
                        size: isMobile ? 15 : 18,
                        color: colors.aqua,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'FILTERS',
                        style: TextStyle(
                          fontFamily: AppTheme.activeFontFamily,
                          fontSize: isMobile ? 10.5 : 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: isMobile ? 0.8 : 1.5,
                          color: colors.textSecondary,
                        ),
                      ),
                      if (activeCount > 0) ...[
                        const SizedBox(width: 5),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: colors.aquaDark,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '$activeCount',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: colors.aquaLight,
                            ),
                          ),
                        ),
                      ],
                      const Spacer(),
                      // Prominent 'Bitnex week' button just beside toggle chevron
                      _buildHeaderResetButton(
                        context,
                        colors,
                        isDark,
                        isMobile,
                      ),
                      const SizedBox(width: 6),
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

              // Collapsible filter body with smooth size transition
              AnimatedSize(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeInOutCubic,
                child: _isFiltersExpanded
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: headerHPad,
                            ),
                            child: Divider(
                              color: colors.divider.withValues(alpha: 0.6),
                              height: 1,
                            ),
                          ),
                          const SizedBox(height: 12),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            padding: EdgeInsets.fromLTRB(
                              headerHPad,
                              0,
                              headerHPad,
                              14,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // 1. Range Dropdown Chip
                                _buildFilterChip<DateRangeFilter>(
                                  context: context,
                                  value: _selectedRange,
                                  defaultValue: DateRangeFilter.allTime,
                                  items: DateRangeFilter.values,
                                  labelPrefix: 'Range: ',
                                  itemLabel: (v) => v.label,
                                  onChanged: (val) {
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
                                ),
                                const SizedBox(width: 10),

                                // 2. Currency Dropdown Chip (prominent styling matching Picture 2)
                                _buildFilterChip<CurrencyFilter>(
                                  context: context,
                                  value: _selectedCurrency,
                                  defaultValue: CurrencyFilter.all,
                                  items: CurrencyFilter.values,
                                  labelPrefix: 'Currency: ',
                                  itemLabel: (v) => v.label,
                                  onChanged: (val) {
                                    setState(() {
                                      _selectedCurrency = val;
                                    });
                                  },
                                ),
                                const SizedBox(width: 10),

                                // 3. Status Dropdown Chip
                                _buildFilterChip<StatusFilterOption>(
                                  context: context,
                                  value: _selectedStatus,
                                  defaultValue: StatusFilterOption.all,
                                  items: StatusFilterOption.values,
                                  labelPrefix: 'Status: ',
                                  itemLabel: (v) => v.label,
                                  onChanged: (val) {
                                    setState(() {
                                      _selectedStatus = val;
                                    });
                                  },
                                ),
                                const SizedBox(width: 10),

                                // 4. From Label + Input with Calendar Icon
                                _buildDateInput(
                                  context: context,
                                  label: 'From',
                                  date: _fromDate,
                                  onTap: () => _pickFromDate(context, colors),
                                  onClear: () {
                                    setState(() {
                                      _fromDate = null;
                                      if (_toDate == null) {
                                        _selectedRange =
                                            DateRangeFilter.allTime;
                                      }
                                    });
                                  },
                                  colors: colors,
                                ),
                                const SizedBox(width: 10),

                                // 5. — To Label + Input with Calendar Icon
                                _buildDateInput(
                                  context: context,
                                  label: '— To',
                                  date: _toDate,
                                  onTap: () => _pickToDate(context, colors),
                                  onClear: () {
                                    setState(() {
                                      _toDate = null;
                                      if (_fromDate == null) {
                                        _selectedRange =
                                            DateRangeFilter.allTime;
                                      }
                                    });
                                  },
                                  colors: colors,
                                ),
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
      },
    );
  }

  /// Builds the active status filter banner section of this interface.
  Widget _buildActiveStatusFilterBanner(
    PaidiXColorScheme colors,
    bool isDark,
    int count,
  ) {
    String statusLabel = 'Filtered';
    Color chipColor = colors.aqua;

    switch (_selectedStatus) {
      case StatusFilterOption.submitted:
        statusLabel = 'Submitted';
        chipColor = const Color(0xFF38BDF8);
        break;
      case StatusFilterOption.underReview:
        statusLabel = 'Pending Review';
        chipColor = isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706);
        break;
      case StatusFilterOption.verified:
        statusLabel = 'Verified';
        chipColor = colors.aqua;
        break;
      case StatusFilterOption.pkrSent:
        statusLabel = 'Awaiting PKR';
        chipColor = isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7);
        break;
      case StatusFilterOption.completed:
        statusLabel = 'Completed';
        chipColor = isDark ? const Color(0xFF34D399) : const Color(0xFF059669);
        break;
      case StatusFilterOption.onHold:
        statusLabel = 'On Hold';
        chipColor = isDark ? const Color(0xFFFB923C) : const Color(0xFFEA580C);
        break;
      case StatusFilterOption.rejected:
        statusLabel = 'Rejected';
        chipColor = colors.statusErrorDot;
        break;
      case StatusFilterOption.all:
        statusLabel = 'All';
        chipColor = colors.aqua;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: chipColor.withValues(alpha: isDark ? 0.15 : 0.08),
        borderRadius: AppSpacing.radiusMd,
        border: Border.all(
          color: chipColor.withValues(alpha: isDark ? 0.45 : 0.35),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: chipColor,
              boxShadow: [
                BoxShadow(
                  color: chipColor.withValues(alpha: 0.6),
                  blurRadius: 4,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Showing $statusLabel payments ($count)',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: chipColor,
              ),
            ),
          ),
          SpongyTap(
            onTap: () {
              HapticFeedback.lightImpact();
              setState(() {
                _selectedStatus = StatusFilterOption.all;
              });
            },
            pressScale: 0.90,
            borderRadius: AppSpacing.radiusPill,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: chipColor.withValues(alpha: isDark ? 0.25 : 0.15),
                borderRadius: AppSpacing.radiusPill,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.close_rounded, size: 12, color: chipColor),
                  const SizedBox(width: 3),
                  Text(
                    'Clear',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: chipColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the filtered empty state section of this interface.
  Widget _buildFilteredEmptyState(PaidiXColorScheme colors) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
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
            Icons.filter_list_off_rounded,
            size: 32,
            color: colors.textSecondary,
          ),
          const SizedBox(height: 12),
          Text(
            'No payments match this filter',
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Try clearing filters or selecting another status to see your payments.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: colors.textSecondary),
          ),
          const SizedBox(height: 16),
          SpongyTap(
            onTap: () {
              HapticFeedback.lightImpact();
              setState(() {
                _selectedStatus = StatusFilterOption.all;
                _selectedRange = DateRangeFilter.allTime;
                _selectedCurrency = CurrencyFilter.all;
                _fromDate = null;
                _toDate = null;
              });
            },
            pressScale: 0.94,
            borderRadius: AppSpacing.radiusPill,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: colors.aqua,
                borderRadius: AppSpacing.radiusPill,
              ),
              child: Text(
                'Show all payments',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: colors.mintHeroText,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the header reset button section of this interface.
  Widget _buildHeaderResetButton(
    BuildContext context,
    PaidiXColorScheme colors,
    bool isDark,
    bool isMobile,
  ) {
    final hasActiveFilters = !_currentFilter.isDefault;

    return SpongyTap(
      onTap: () {
        setState(() {
          _selectedRange = DateRangeFilter.allTime;
          _selectedCurrency = CurrencyFilter.all;
          _selectedStatus = StatusFilterOption.all;
          _fromDate = null;
          _toDate = null;
        });
      },
      pressScale: 0.93,
      borderRadius: AppSpacing.radiusPill,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 8 : 11,
          vertical: 4,
        ),
        decoration: BoxDecoration(
          color: hasActiveFilters
              ? (isDark
                    ? colors.aquaDark.withValues(alpha: 0.35)
                    : colors.cardHighlight)
              : (isDark ? colors.cardDark : colors.cardHighlight),
          borderRadius: AppSpacing.radiusPill,
          border: Border.all(
            color: hasActiveFilters ? colors.aqua : colors.borderSubtle,
            width: 1,
          ),
          boxShadow: hasActiveFilters
              ? [
                  BoxShadow(
                    color: colors.aqua.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.rotate_left_rounded,
              size: isMobile ? 12 : 14,
              color: hasActiveFilters ? colors.aqua : colors.textSecondary,
            ),
            const SizedBox(width: 4),
            Text(
              'Reset',
              style: TextStyle(
                fontFamily: AppTheme.activeFontFamily,
                fontSize: isMobile ? 10 : 11,
                fontWeight: hasActiveFilters
                    ? FontWeight.w700
                    : FontWeight.w500,
                color: hasActiveFilters ? colors.aqua : colors.textSecondary,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds the filter chip section of this interface.
  Widget _buildFilterChip<T>({
    required BuildContext context,
    required T value,
    required T defaultValue,
    required List<T> items,
    required String labelPrefix,
    required String Function(T) itemLabel,
    required ValueChanged<T> onChanged,
    String? displayValue,
    bool? isActiveOverride,
  }) {
    final colors = AppColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isActive = isActiveOverride ?? (value != defaultValue);
    final shownValue = displayValue ?? itemLabel(value);

    return Theme(
      data: Theme.of(context).copyWith(
        popupMenuTheme: PopupMenuThemeData(
          color: colors.cardDark,
          shape: RoundedRectangleBorder(
            borderRadius: AppSpacing.radiusMd,
            side: BorderSide(
              color: colors.aqua.withValues(alpha: 0.35),
              width: 1.2,
            ),
          ),
          elevation: 10,
          shadowColor: isDark
              ? Colors.black.withValues(alpha: 0.6)
              : const Color(0xFF022F32).withValues(alpha: 0.15),
        ),
      ),
      child: PopupMenuButton<T>(
        initialValue: value,
        tooltip: '',
        offset: const Offset(0, 42),
        elevation: 10,
        color: colors.cardDark,
        shape: RoundedRectangleBorder(
          borderRadius: AppSpacing.radiusMd,
          side: BorderSide(
            color: colors.aqua.withValues(alpha: 0.35),
            width: 1.2,
          ),
        ),
        onSelected: onChanged,
        itemBuilder: (ctx) {
          return items.map((item) {
            final isItemActive = item == value;
            return PopupMenuItem<T>(
              value: item,
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isItemActive
                        ? Icons.check_circle_rounded
                        : Icons.circle_outlined,
                    size: 16,
                    color: isItemActive
                        ? colors.aqua
                        : colors.textMuted.withValues(alpha: 0.4),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    itemLabel(item),
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: isItemActive
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: isItemActive
                          ? colors.aquaLight
                          : colors.textPrimary,
                    ),
                  ),
                ],
              ),
            );
          }).toList();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isActive
                ? (isDark
                      ? colors.aquaDark.withValues(alpha: 0.3)
                      : colors.cardHighlight)
                : colors.inputFill,
            borderRadius: AppSpacing.radiusMd,
            border: Border.all(
              color: isActive
                  ? colors.aqua
                  : colors.border.withValues(alpha: 0.9),
              width: 1.2,
            ),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: colors.aqua.withValues(alpha: 0.12),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                labelPrefix,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: colors.textSecondary,
                ),
              ),
              Text(
                shownValue,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isActive ? colors.aqua : colors.textPrimary,
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 16,
                color: isActive ? colors.aqua : colors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds the date input section of this interface.
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
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: colors.textSecondary,
          ),
        ),
        const SizedBox(width: 7),
        InkWell(
          onTap: onTap,
          borderRadius: AppSpacing.radiusMd,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7.5),
            decoration: BoxDecoration(
              color: hasDate ? colors.cardHighlight : colors.inputFill,
              borderRadius: AppSpacing.radiusMd,
              border: Border.all(
                color: hasDate
                    ? colors.aqua
                    : colors.border.withValues(alpha: 0.9),
                width: 1.2,
              ),
              boxShadow: hasDate
                  ? [
                      BoxShadow(
                        color: colors.aqua.withValues(alpha: 0.12),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  dateText,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: hasDate ? FontWeight.w700 : FontWeight.w400,
                    color: hasDate
                        ? colors.aqua
                        : colors.textSecondary.withValues(alpha: 0.7),
                    letterSpacing: hasDate ? 0.3 : 0.8,
                  ),
                ),
                const SizedBox(width: 10),
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
                    size: 14,
                    color: colors.textSecondary,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Calendar picker for "From" date
  Future<void> _pickFromDate(
    BuildContext context,
    PaidiXColorScheme colors,
  ) async {
    final now = DateTime.now();
    final initial = _fromDate ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isAfter(DateTime(2035)) ? now : initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      builder: (context, child) => buildAppDatePickerTheme(context, child!),
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
  Future<void> _pickToDate(
    BuildContext context,
    PaidiXColorScheme colors,
  ) async {
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
      builder: (context, child) => buildAppDatePickerTheme(context, child!),
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
      builder: (context, child) => buildAppDatePickerTheme(context, child!),
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

  /// Builds the empty transactions card section of this interface.
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
          Icon(Icons.description_outlined, size: 34, color: colors.aqua),
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
            style: TextStyle(fontSize: 12.5, color: colors.textSecondary),
          ),
        ],
      ),
    );
  }

  /// Builds the empty recent activity card section of this interface.
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
          Icon(Icons.description_outlined, size: 34, color: colors.aqua),
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
            style: TextStyle(fontSize: 12.5, color: colors.textSecondary),
          ),
        ],
      ),
    );
  }

  /// Builds the section header section of this interface.
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
              Icon(Icons.arrow_outward_rounded, size: 13, color: colors.aqua),
            ],
          ),
        ),
      ],
    );
  }

  /// Builds the large financial cards section of this interface.
  Widget _buildLargeFinancialCards(
    BuildContext context,
    FinancialSummary summary,
  ) {
    final colors = AppColors.of(context);

    return AnimatedBuilder(
      animation: Listenable.merge([
        FxDisplayPreferences.stealthModeNotifier,
        FxDisplayPreferences.compactFormatNotifier,
        FxDisplayPreferences.dashboardBalanceRevealedNotifier,
      ]),
      builder: (context, _) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 850;

            final card1 = FinancialStatCard(
              title: 'PKR RECEIVED',
              value: FxDisplayPreferences.formatVolumePkr(summary.pkrReceived),
              subtext: '${summary.paymentsCompleted} payments completed',
              description: 'Net PKR deposited to your bank account from completed transactions.',
              iconBg: colors.aquaLight,
              icon: Icon(
                Icons.account_balance_wallet_outlined,
                color: colors.mintHeroText,
                size: 18,
              ),
              onTap: FxDisplayPreferences.isStealthMode
                  ? () => FxDisplayPreferences.toggleDashboardBalanceRevealed()
                  : null,
            );

            final card2 = FinancialStatCard(
              title: 'TOTAL TRANSFERRED TO YOU',
              value: FxDisplayPreferences.formatVolumePkr(
                summary.totalTransferred,
              ),
              subtext: 'Lifetime PKR',
              description: "Everything we've sent to your bank account since joining PaidiX.",
              iconBg: colors.cardDark,
              icon: Icon(Icons.send_rounded, color: colors.aquaLight, size: 18),
              onTap: FxDisplayPreferences.isStealthMode
                  ? () => FxDisplayPreferences.toggleDashboardBalanceRevealed()
                  : null,
            );

            final card3 = FinancialStatCard(
              title: 'AWAITING VERIFICATION',
              value: summary.awaitingVerificationAmount != null
                  ? FxDisplayPreferences.formatVolumePkr(
                      summary.awaitingVerificationAmount,
                    )
                  : '${summary.awaitingVerificationCount}',
              subtext:
                  '${summary.awaitingVerificationCount} payments in progress',
              description: 'Payments still being processed. Foreign-currency amounts are shown below.',
              iconBg: colors.gold,
              icon: Icon(
                Icons.access_time_rounded,
                color: colors.mintHeroText,
                size: 18,
              ),
              onTap: FxDisplayPreferences.isStealthMode
                  ? () => FxDisplayPreferences.toggleDashboardBalanceRevealed()
                  : () {
                      HapticFeedback.selectionClick();
                      setState(() {
                        if (_selectedStatus == StatusFilterOption.underReview ||
                            _selectedStatus == StatusFilterOption.pkrSent) {
                          _selectedStatus = StatusFilterOption.all;
                        } else {
                          _selectedStatus = StatusFilterOption.underReview;
                        }
                      });
                    },
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
      },
    );
  }

  /// Builds the status summary grid section of this interface.
  Widget _buildStatusSummaryGrid(
    BuildContext context,
    FinancialSummary summary,
  ) {
    final colors = AppColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final isAllSelected = _selectedStatus == StatusFilterOption.all;
    final isPendingSelected =
        _selectedStatus == StatusFilterOption.underReview ||
        _selectedStatus == StatusFilterOption.pendingReview;
    final isAwaitingSelected =
        _selectedStatus == StatusFilterOption.pkrSent ||
        _selectedStatus == StatusFilterOption.awaitingPkr;
    final isCompletedSelected = _selectedStatus == StatusFilterOption.completed;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 600;

        final item1 = StatusMetricCard(
          title: 'TRANSACTIONS',
          count: '${summary.transactionsCount}',
          iconBgColor: colors.aquaLight,
          icon: Icon(
            Icons.description_outlined,
            color: colors.mintHeroText,
            size: 16,
          ),
          isSelected: isAllSelected,
          activeColor: colors.aqua,
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() {
              _selectedStatus = StatusFilterOption.all;
            });
          },
        );

        final item2 = StatusMetricCard(
          title: 'PENDING REVIEW',
          count: '${summary.pendingReviewCount}',
          iconBgColor: colors.aquaLight,
          icon: Icon(
            Icons.access_time_rounded,
            color: colors.mintHeroText,
            size: 16,
          ),
          isSelected: isPendingSelected,
          activeColor: isDark
              ? const Color(0xFFFBBF24)
              : const Color(0xFFD97706),
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() {
              if (isPendingSelected) {
                _selectedStatus = StatusFilterOption.all;
              } else {
                _selectedStatus = StatusFilterOption.underReview;
              }
            });
          },
        );

        final item3 = StatusMetricCard(
          title: 'AWAITING PKR',
          count: '${summary.awaitingPkrCount}',
          iconBgColor: colors.aquaLight,
          icon: Icon(
            Icons.arrow_outward_rounded,
            color: colors.mintHeroText,
            size: 16,
          ),
          isSelected: isAwaitingSelected,
          activeColor: isDark
              ? const Color(0xFF38BDF8)
              : const Color(0xFF0284C7),
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() {
              if (isAwaitingSelected) {
                _selectedStatus = StatusFilterOption.all;
              } else {
                _selectedStatus = StatusFilterOption.pkrSent;
              }
            });
          },
        );

        final item4 = StatusMetricCard(
          title: 'COMPLETED',
          count: '${summary.completedCount}',
          iconBgColor: colors.statusCompletedDot,
          icon: Icon(
            Icons.check_circle_outline,
            color: colors.mintHeroText,
            size: 16,
          ),
          isSelected: isCompletedSelected,
          activeColor: isDark
              ? const Color(0xFF34D399)
              : const Color(0xFF059669),
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() {
              if (isCompletedSelected) {
                _selectedStatus = StatusFilterOption.all;
              } else {
                _selectedStatus = StatusFilterOption.completed;
              }
            });
          },
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

  /// Creates the mutable state object that backs this stateful widget.
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

  /// Initializes controllers, listeners, and other state owned by this widget.
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
    _slideAnimation = Tween<double>(
      begin: 0.0,
      end: 5.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
  }

  /// Releases resources owned by this object before it is removed.
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Runs the profile link action and its press feedback.
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

  /// Builds the widget subtree from its current properties and inherited context.
  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final normalColor = colors.aqua;
    final activeColor = Colors.white;

    final targetColor = _isTapped
        ? activeColor
        : (_isHovered ? colors.aquaLight : normalColor);

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
