/// Defines payments page in the payments feature's presentation layer.

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/payments_pin_lock_scope.dart';
import '../../../../core/widgets/paidix_toast.dart';
import '../../../../core/widgets/paidix_smooth_scroll_physics.dart';
import '../../data/payments_repository_impl.dart';
import '../../domain/payment_models.dart';
// import '../widgets/bulk_add_payments_dialog.dart';
import '../widgets/pagination_controls.dart';
import '../widgets/payment_card.dart';
import '../widgets/payments_filter_bar.dart';
import '../widgets/payments_table.dart';
import '../widgets/smooth_animated_list_item.dart';

class PaymentsPage extends StatefulWidget {
  final PaymentsRepositoryImpl paymentsRepository;

  const PaymentsPage({super.key, required this.paymentsRepository});

  /// Creates the mutable state object that backs this stateful widget.
  @override
  State<PaymentsPage> createState() => _PaymentsPageState();
}

class _PaymentsPageState extends State<PaymentsPage>
    with WidgetsBindingObserver {
  final _searchController = TextEditingController();
  PaymentFilter _filter = const PaymentFilter();
  int _pageSize = 20;
  int _currentPage = 1;
  VoidCallback? _releasePaymentPolling;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startPaymentPolling();
  }

  void _startPaymentPolling() {
    _releasePaymentPolling ??= widget.paymentsRepository.watchServerUpdates();
  }

  void _stopPaymentPolling() {
    _releasePaymentPolling?.call();
    _releasePaymentPolling = null;
  }

  Future<void> _refreshPayments() async {
    try {
      final refreshed = await widget.paymentsRepository
          .refreshServerDataWithResult();
      if (!refreshed && mounted) {
        PaidiXToast.showError(
          context,
          'Could not refresh all payment data. Showing the latest saved data.',
        );
      }
    } catch (_) {
      if (mounted) {
        PaidiXToast.showError(
          context,
          'Could not refresh payments. Please try again.',
        );
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startPaymentPolling();
    } else {
      _stopPaymentPolling();
    }
  }

  /// Releases resources owned by this object before it is removed.
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopPaymentPolling();
    _searchController.dispose();
    super.dispose();
  }

  /// Applies the updated search text to the visible payments.
  void _onSearchChanged(String query) {
    setState(() {
      _filter = _filter.copyWith(searchQuery: query);
      _currentPage = 1;
    });
  }

  /// Applies the selected status, currency, and date filters.
  void _onFilterChanged(PaymentFilter newFilter) {
    setState(() {
      _filter = newFilter;
      _currentPage = 1;
    });
  }

  /// Restores all payment filters and search state to their defaults.
  void _onResetFilters() {
    _searchController.clear();
    setState(() {
      _filter = const PaymentFilter();
      _currentPage = 1;
    });
  }

  /// Builds the widget subtree from its current properties and inherited context.
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<PaymentItem>>(
      valueListenable: widget.paymentsRepository.paymentsListenable,
      builder: (context, allPayments, _) {
        final colors = AppColors.of(context);
        final filteredList = widget.paymentsRepository.filterPayments(_filter);
        final totalCount = filteredList.length;

        // Paginate
        final startIndex = (_currentPage - 1) * _pageSize;
        final paginatedList = filteredList
            .skip(startIndex)
            .take(_pageSize)
            .toList();

        return Scaffold(
          backgroundColor: colors.background,
          body: SafeArea(
            child: RefreshIndicator(
              color: colors.aqua,
              backgroundColor: colors.card,
              onRefresh: _refreshPayments,
              child: SingleChildScrollView(
                physics: paidiXRefreshScrollPhysics,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 24,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Page Header & Actions
                    _buildHeader(context),
                    const SizedBox(height: 20),

                    // Filters Section (Expandable Accordion)
                    PaymentsFilterBar(
                      filter: _filter,
                      onFilterChanged: _onFilterChanged,
                      onReset: _onResetFilters,
                    ),
                    const SizedBox(height: 14),

                    // Search Bar
                    AppTextField(
                      label: 'SEARCH',
                      placeholder:
                          'Search by reference, sender, transaction ID...',
                      controller: _searchController,
                      onChanged: _onSearchChanged,
                      prefix: Icon(
                        Icons.search_rounded,
                        color: colors.textSecondary,
                        size: 20,
                      ),
                      suffix: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: Icon(
                                Icons.clear_rounded,
                                size: 18,
                                color: colors.textSecondary,
                              ),
                              onPressed: () {
                                _searchController.clear();
                                _onSearchChanged('');
                              },
                            )
                          : null,
                    ),
                    const SizedBox(height: 20),

                    // Payments List or Empty State
                    if (paginatedList.isEmpty &&
                        AppConfig.hasCustomBackend &&
                        !widget.paymentsRepository.hasLoadedFromServer)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 56),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (paginatedList.isEmpty)
                      EmptyStateView(
                        title: 'No payments match this filter',
                        subtitle:
                            'Try clearing filters or submit a new payment.',
                        actionText: 'New payment',
                        onAction: () => context.go('/app/payments/new'),
                      )
                    else ...[
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 320),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        transitionBuilder: (child, animation) {
                          return FadeTransition(
                            opacity: animation,
                            child: SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(0.0, 0.03),
                                end: Offset.zero,
                              ).animate(animation),
                              child: child,
                            ),
                          );
                        },
                        child: KeyedSubtree(
                          key: ValueKey(
                            '$_currentPage-$_pageSize-${_filter.searchQuery}-${_filter.status}-${_filter.dateRange}-${_filter.isBitnexWeek}',
                          ),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              if (constraints.maxWidth >= 768) {
                                return PaymentsTable(
                                  items: paginatedList,
                                  onItemTap: _openPayment,
                                );
                              }
                              return Column(
                                children: List.generate(
                                  paginatedList.length,
                                  (idx) => SmoothAnimatedListItem(
                                    index: idx,
                                    child: PaymentCard(
                                      item: paginatedList[idx],
                                      onTap: () =>
                                          _openPayment(paginatedList[idx]),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Pagination Controls (Showing, Rows, Page)
                      PaginationControls(
                        totalCount: totalCount,
                        pageSize: _pageSize,
                        currentPage: _currentPage,
                        onPageSizeChanged: (newSize) {
                          setState(() {
                            _pageSize = newSize;
                            _currentPage = 1;
                          });
                        },
                        onPageChanged: (newPage) {
                          setState(() => _currentPage = newPage);
                        },
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
  }

  void _openPayment(PaymentItem payment) {
    context.push(
      '/app/payments/${Uri.encodeComponent(payment.id)}',
      extra: payment,
    );
  }

  /// Builds the header section of this interface.
  Widget _buildHeader(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmall = constraints.maxWidth < 600;

        final colors = AppColors.of(context);
        final pinLockScope = PaymentsPinLockScope.maybeOf(context);

        final titleBlock = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'PAYMENTS',
              style: AppTypography.sectionEyebrow.copyWith(
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    'My payments',
                    style: AppTypography.pageHeading.copyWith(
                      color: colors.textPrimary,
                    ),
                  ),
                ),
                if (pinLockScope?.isConfigured == true)
                  IconButton(
                    tooltip: 'Lock My Payments',
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      pinLockScope!.onLockPayments();
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
              "Every incoming payment you've submitted.",
              style: AppTypography.pageSubtitle.copyWith(
                color: colors.textSecondary,
              ),
            ),
          ],
        );
        final actions = Wrap(
          spacing: 10,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            // Bulk Add action commented out as per requirement
            /*
            AppButton(
              text: 'Bulk add',
              icon: Icon(Icons.playlist_add_rounded,
                  size: 18, color: colors.aquaLight),
              variant: AppButtonVariant.secondary,
              onPressed: () => BulkAddPaymentsDialog.show(
                context,
                widget.paymentsRepository,
              ),
            ),
            const SizedBox(width: 10),
            */
            AppButton(
              text: 'New payment',
              icon: Icon(
                Icons.add_circle_outline_rounded,
                size: 18,
                color: colors.primaryButtonText,
              ),
              variant: AppButtonVariant.primary,
              onPressed: () => context.go('/app/payments/new'),
            ),
          ],
        );

        if (isSmall) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              titleBlock,
              const SizedBox(height: 16),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: paidiXSmoothScrollPhysics,
                child: actions,
              ),
            ],
          );
        }

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(child: titleBlock),
            const SizedBox(width: 16),
            actions,
          ],
        );
      },
    );
  }
}
