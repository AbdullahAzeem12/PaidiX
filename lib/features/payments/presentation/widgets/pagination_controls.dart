import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';

class PaginationControls extends StatelessWidget {
  final int totalCount;
  final int pageSize;
  final int currentPage;
  final ValueChanged<int> onPageSizeChanged;
  final ValueChanged<int> onPageChanged;

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
    final totalPages = (totalCount / pageSize).ceil().clamp(1, 9999);
    final start = totalCount == 0 ? 0 : (currentPage - 1) * pageSize + 1;
    final end = (currentPage * pageSize).clamp(0, totalCount);

    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 16,
      runSpacing: 12,
      children: [
        // Showing X-Y of Z
        Text(
          'Showing $start–$end of $totalCount',
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: colors.textSecondary,
          ),
        ),

        // Rows selector: 10, 20, 30, 50, 100
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Rows: ',
              style: TextStyle(
                fontSize: 12,
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(width: 4),
            for (final size in [10, 20, 30, 50, 100]) ...[
              _buildSizePill(context, size),
              const SizedBox(width: 4),
            ],
          ],
        ),

        // Navigation controls
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left, size: 20),
              color: currentPage > 1
                  ? colors.textPrimary
                  : colors.textPlaceholder,
              onPressed: currentPage > 1
                  ? () => onPageChanged(currentPage - 1)
                  : null,
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: colors.cardDark,
                borderRadius: AppSpacing.radiusSm,
                border: Border.all(color: colors.border, width: 1),
              ),
              child: Text(
                'Page $currentPage / $totalPages',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: colors.textPrimary,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right, size: 20),
              color: currentPage < totalPages
                  ? colors.textPrimary
                  : colors.textPlaceholder,
              onPressed: currentPage < totalPages
                  ? () => onPageChanged(currentPage + 1)
                  : null,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSizePill(BuildContext context, int size) {
    final colors = AppColors.of(context);
    final isSelected = size == pageSize;

    return GestureDetector(
      onTap: () => onPageSizeChanged(size),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? colors.aqua : colors.cardDark,
          borderRadius: AppSpacing.radiusSm,
          border: Border.all(
            color: isSelected ? colors.aqua : colors.border,
            width: 1,
          ),
        ),
        child: Text(
          '$size',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: isSelected ? Colors.white : colors.textSecondary,
          ),
        ),
      ),
    );
  }
}
