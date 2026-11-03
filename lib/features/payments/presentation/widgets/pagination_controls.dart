import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/widgets/spongy_tap.dart';

/// State-of-the-art interactive pagination footer matching production screenshots.
/// Features:
/// - Real-time "Showing X-Y of Z" calculation
/// - Interactive "Rows" selector chips: 10, 20, 30, 50, 100, and Custom
/// - Full interactive page controls: First (<<), Prev (< Prev), Page X (with direct jump), Next (Next >), Last (>>)
/// - Spongy haptics and zero pixel overflow on all screen sizes
class PaginationControls extends StatelessWidget {
  final int totalCount;
  final int pageSize;
  final int currentPage;
  final ValueChanged<int> onPageSizeChanged;
  final ValueChanged<int> onPageChanged;

  static const List<int> presetPageSizes = [10, 20, 30, 50, 100];

  const PaginationControls({
    super.key,
    required this.totalCount,
    required this.pageSize,
    required this.currentPage,
    required this.onPageSizeChanged,
    required this.onPageChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final totalPages = max(1, (totalCount / pageSize).ceil());
    final start = totalCount == 0 ? 0 : (currentPage - 1) * pageSize + 1;
    final end = min(currentPage * pageSize, totalCount);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 720;

        final showingText = Text(
          'Showing $start–$end of $totalCount',
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: colors.textSecondary,
          ),
        );

        final rowsSelector = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Rows: ',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(width: 4),
            ...presetPageSizes.map((size) {
              return Padding(
                padding: const EdgeInsets.only(right: 4),
                child: _buildSizePill(
                  context,
                  label: '$size',
                  isSelected: size == pageSize,
                  onTap: () => onPageSizeChanged(size),
                  colors: colors,
                  isDark: isDark,
                ),
              );
            }),
            _buildSizePill(
              context,
              label: !presetPageSizes.contains(pageSize)
                  ? 'Custom ($pageSize)'
                  : 'Custom',
              isSelected: !presetPageSizes.contains(pageSize),
              onTap: () => _showCustomRowsDialog(context),
              colors: colors,
              isDark: isDark,
            ),
          ],
        );

        final pageNavControls = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // First page button (<<)
            _buildNavButton(
              context,
              label: '«',
              enabled: currentPage > 1,
              onTap: () => onPageChanged(1),
              tooltip: 'First page',
              colors: colors,
              isDark: isDark,
            ),
            const SizedBox(width: 4),

            // Prev button (< Prev)
            _buildNavButton(
              context,
              label: '< Prev',
              enabled: currentPage > 1,
              onTap: () => onPageChanged(currentPage - 1),
              tooltip: 'Previous page',
              colors: colors,
              isDark: isDark,
            ),
            const SizedBox(width: 4),

            // Page X jump pill
            SpongyTap(
              onTap: () => _showPageJumpDialog(context, totalPages),
              pressScale: 0.94,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isDark ? colors.cardDark : colors.cardHighlight,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: colors.border, width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Page $currentPage',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 3),
                    Icon(
                      Icons.arrow_drop_down_rounded,
                      size: 16,
                      color: colors.textSecondary,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 4),

            // Next button (Next >)
            _buildNavButton(
              context,
              label: 'Next >',
              enabled: currentPage < totalPages,
              onTap: () => onPageChanged(currentPage + 1),
              tooltip: 'Next page',
              colors: colors,
              isDark: isDark,
            ),
            const SizedBox(width: 4),

            // Last page button (>>)
            _buildNavButton(
              context,
              label: '»',
              enabled: currentPage < totalPages,
              onTap: () => onPageChanged(totalPages),
              tooltip: 'Last page',
              colors: colors,
              isDark: isDark,
            ),
          ],
        );

        if (isMobile) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  showingText,
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: rowsSelector,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Center(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: pageNavControls,
                ),
              ),
            ],
          );
        }

        return Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 10,
          children: [
            showingText,
            rowsSelector,
            pageNavControls,
          ],
        );
      },
    );
  }

  Widget _buildSizePill(
    BuildContext context, {
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required PaidiXColorScheme colors,
    required bool isDark,
  }) {
    return SpongyTap(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      pressScale: 0.94,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? const Color(0xFF86E3CE) : colors.aqua)
              : (isDark ? colors.cardDark : colors.cardHighlight),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected
                ? (isDark ? const Color(0xFF86E3CE) : colors.aqua)
                : colors.border,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
            color: isSelected
                ? const Color(0xFF022F32)
                : colors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildNavButton(
    BuildContext context, {
    required String label,
    required bool enabled,
    required VoidCallback onTap,
    required String tooltip,
    required PaidiXColorScheme colors,
    required bool isDark,
  }) {
    return Tooltip(
      message: tooltip,
      child: SpongyTap(
        onTap: enabled
            ? () {
                HapticFeedback.lightImpact();
                onTap();
              }
            : () {},
        pressScale: enabled ? 0.94 : 1.0,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: enabled
                ? (isDark ? colors.cardDark : colors.cardHighlight)
                : colors.cardDark.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: enabled
                  ? colors.border
                  : colors.border.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: enabled
                  ? colors.textPrimary
                  : colors.textMuted.withValues(alpha: 0.45),
            ),
          ),
        ),
      ),
    );
  }

  void _showCustomRowsDialog(BuildContext context) {
    final colors = AppColors.of(context);
    final controller = TextEditingController(text: '$pageSize');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.card,
        shape: RoundedRectangleBorder(
          borderRadius: AppSpacing.radiusLg,
          side: BorderSide(color: colors.border, width: 1.2),
        ),
        title: Text(
          'Custom rows per page',
          style: TextStyle(
            fontSize: 16.5,
            fontWeight: FontWeight.w800,
            color: colors.textPrimary,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select a preset or enter the number of payment rows you want to display per page:',
              style: TextStyle(fontSize: 12.5, color: colors.textSecondary),
            ),
            const SizedBox(height: 14),

            // Quick preset pills
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [5, 15, 25, 40, 75, 150].map((size) {
                return SpongyTap(
                  onTap: () {
                    Navigator.of(ctx).pop();
                    onPageSizeChanged(size);
                  },
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: colors.cardDark,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: colors.border),
                    ),
                    child: Text(
                      '$size',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: colors.aquaLight,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Manual input
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: TextStyle(color: colors.textPrimary, fontSize: 13),
              decoration: InputDecoration(
                labelText: 'NUMBER OF ROWS',
                labelStyle: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: colors.gold,
                  letterSpacing: 1.2,
                ),
                hintText: 'e.g. 15',
                hintStyle: TextStyle(color: colors.textPlaceholder),
                filled: true,
                fillColor: colors.inputFill,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: colors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: colors.aqua, width: 1.5),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: colors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          SpongyTap(
            onTap: () {
              final parsed = int.tryParse(controller.text.trim());
              if (parsed != null && parsed > 0) {
                Navigator.of(ctx).pop();
                onPageSizeChanged(parsed.clamp(1, 500));
              }
            },
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: colors.aqua,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Apply',
                style: TextStyle(
                  color: Color(0xFF022F32),
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showPageJumpDialog(BuildContext context, int totalPages) {
    final colors = AppColors.of(context);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.card,
        shape: RoundedRectangleBorder(
          borderRadius: AppSpacing.radiusLg,
          side: BorderSide(color: colors.border, width: 1.2),
        ),
        title: Text(
          'Jump to page',
          style: TextStyle(
            fontSize: 16.5,
            fontWeight: FontWeight.w800,
            color: colors.textPrimary,
          ),
        ),
        content: SizedBox(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Select any page from 1 to $totalPages:',
                style: TextStyle(fontSize: 12.5, color: colors.textSecondary),
              ),
              const SizedBox(height: 14),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 220),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: List.generate(totalPages, (i) {
                      final p = i + 1;
                      final isCurrent = p == currentPage;
                      return SpongyTap(
                        onTap: () {
                          Navigator.of(ctx).pop();
                          onPageChanged(p);
                        },
                        child: Container(
                          width: 44,
                          height: 40,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isCurrent ? colors.aqua : colors.cardDark,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isCurrent ? colors.aqua : colors.border,
                              width: 1,
                            ),
                          ),
                          child: Text(
                            '$p',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isCurrent
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                              color: isCurrent
                                  ? const Color(0xFF022F32)
                                  : colors.textPrimary,
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Close',
              style: TextStyle(
                color: colors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
