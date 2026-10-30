import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/widgets/spongy_tap.dart';
import '../../domain/payment_models.dart';

/// A sleek, responsive, and animated filter bar for Payments.
/// Features:
/// - Closed by default; smoothly expands/collapses when tapped (`Curves.easeInOutCubic`).
/// - Rotating chevron transition indicating accordion state.
/// - "Bitnex week" text button located at the far right of the header beside the toggle chevron,
///   with high-contrast active checkmark illumination, spongy spring bounce, and active filtering logic.
/// - Side-by-side filter chips arranged on a smooth horizontal slider (`BouncingScrollPhysics`),
///   ensuring zero pixel overflow and preventing downward stacking on mobile screens.
/// - Full suite of 8 status options: All statuses, Submitted, Under Review, Verified, PKR Sent, Completed, On Hold, Rejected.
/// - Tactile spongy click compression and illuminated borders for active filters.
/// - Smooth animated popup dropdown menus anchored right under each chip with active checkmark indicators.
class PaymentsFilterBar extends StatefulWidget {
  final PaymentFilter filter;
  final ValueChanged<PaymentFilter> onFilterChanged;
  final VoidCallback onReset;

  const PaymentsFilterBar({
    super.key,
    required this.filter,
    required this.onFilterChanged,
    required this.onReset,
  });

  @override
  State<PaymentsFilterBar> createState() => _PaymentsFilterBarState();
}

class _PaymentsFilterBarState extends State<PaymentsFilterBar> {
  // Closed by default as per design requirement
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeCount = widget.filter.activeFilterCount;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;
        final headerHPad = isMobile ? 10.0 : 16.0;

        return Container(
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: AppSpacing.radiusLg,
            border: Border.all(color: colors.border, width: 1.2),
          ),
          child: Column(
            children: [
              // Filter toggle header
              InkWell(
                onTap: () => setState(() => _isExpanded = !_isExpanded),
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
                      const SizedBox(width: 5),
                      Text(
                        'FILTERS',
                        style: TextStyle(
                          fontSize: isMobile ? 10.5 : 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: isMobile ? 0.5 : 1.5,
                          color: colors.textSecondary,
                        ),
                      ),
                      if (activeCount > 0) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1.5),
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
                      // "Bitnex week" button at the most right side, just beside the toggle chevron
                      _buildBitnexWeekButton(context, colors, isDark, isMobile),
                      const SizedBox(width: 5),
                      AnimatedRotation(
                        turns: _isExpanded ? 0.5 : 0.0,
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeInOutCubic,
                        child: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: colors.textSecondary,
                          size: 18,
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
                child: _isExpanded
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding:
                                EdgeInsets.symmetric(horizontal: headerHPad),
                            child: Divider(color: colors.divider, height: 1),
                          ),
                          const SizedBox(height: 12),
                          // Smooth horizontal slider: side-by-side chips that never stack downwards
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
                                // Date Range Dropdown Chip
                                _buildFilterChip<DateRangeFilter>(
                                  context: context,
                                  value: widget.filter.dateRange,
                                  defaultValue: DateRangeFilter.allTime,
                                  items: DateRangeFilter.values,
                                  labelPrefix: 'Range: ',
                                  displayValue: widget.filter.isBitnexWeek
                                      ? '—'
                                      : null,
                                  isActiveOverride: widget.filter.isBitnexWeek,
                                  itemLabel: (v) => v.label,
                                  onChanged: (val) {
                                    widget.onFilterChanged(
                                      widget.filter.copyWith(
                                        dateRange: val,
                                        isBitnexWeek: false,
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(width: 10),

                                // Currency Dropdown Chip
                                _buildFilterChip<CurrencyFilter>(
                                  context: context,
                                  value: widget.filter.currency,
                                  defaultValue: CurrencyFilter.all,
                                  items: CurrencyFilter.values,
                                  labelPrefix: 'Currency: ',
                                  itemLabel: (v) => v.label,
                                  onChanged: (val) {
                                    widget.onFilterChanged(
                                      widget.filter.copyWith(currency: val),
                                    );
                                  },
                                ),
                                const SizedBox(width: 10),

                                // Status Dropdown Chip (all 8 statuses)
                                _buildFilterChip<StatusFilterOption>(
                                  context: context,
                                  value: widget.filter.status,
                                  defaultValue: StatusFilterOption.all,
                                  items: StatusFilterOption.values,
                                  labelPrefix: 'Status: ',
                                  itemLabel: (v) => v.label,
                                  onChanged: (val) {
                                    widget.onFilterChanged(
                                      widget.filter.copyWith(status: val),
                                    );
                                  },
                                ),

                                // Reset Button
                                if (!widget.filter.isDefault) ...[
                                  const SizedBox(width: 10),
                                  _buildResetChip(context, colors),
                                ],
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

  Widget _buildBitnexWeekButton(BuildContext context, PaidiXColorScheme colors,
      bool isDark, bool isMobile) {
    final isActive = widget.filter.isBitnexWeek;

    return SpongyTap(
      onTap: () {
        final willBeActive = !isActive;
        widget.onFilterChanged(
          widget.filter.copyWith(
            isBitnexWeek: willBeActive,
            dateRange: willBeActive
                ? DateRangeFilter.allTime
                : widget.filter.dateRange,
          ),
        );
      },
      pressScale: 0.93,
      borderRadius: AppSpacing.radiusPill,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 7 : 10,
          vertical: 3.5,
        ),
        decoration: BoxDecoration(
          color: isActive
              ? colors.aqua
              : (isDark ? colors.cardDark : colors.cardHighlight),
          borderRadius: AppSpacing.radiusPill,
          border: Border.all(
            color: isActive ? colors.aqua : colors.borderSubtle,
            width: 1,
          ),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: colors.aqua.withValues(alpha: 0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isActive) ...[
              const Icon(
                Icons.check_rounded,
                size: 12,
                color: Color(0xFF022F32),
              ),
              const SizedBox(width: 3),
            ],
            Text(
              'Bitnex week',
              style: TextStyle(
                fontSize: isMobile ? 10 : 11,
                fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                color: isActive
                    ? const Color(0xFF022F32)
                    : colors.textSecondary,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

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
                      fontWeight:
                          isItemActive ? FontWeight.w700 : FontWeight.w500,
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

  Widget _buildResetChip(BuildContext context, PaidiXColorScheme colors) {
    return SpongyTap(
      onTap: widget.onReset,
      pressScale: 0.94,
      borderRadius: AppSpacing.radiusMd,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: colors.cardDark,
          borderRadius: AppSpacing.radiusMd,
          border: Border.all(
            color: colors.borderSubtle,
            width: 1.1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.close_rounded,
              size: 14,
              color: colors.textSecondary,
            ),
            const SizedBox(width: 5),
            Text(
              'Reset',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: colors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
