/// Defines payments table in the payments feature's presentation layer.

import 'package:material_ui/material_ui.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../../core/widgets/paidix_smooth_scroll_physics.dart';
import '../../domain/payment_models.dart';

class PaymentsTable extends StatelessWidget {
  final List<PaymentItem> items;
  final ValueChanged<PaymentItem>? onItemTap;

  const PaymentsTable({super.key, required this.items, this.onItemTap});

  /// Builds the widget subtree from its current properties and inherited context.
  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Container(
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: AppSpacing.radiusLg,
        border: Border.all(color: colors.border, width: 1.2),
      ),
      child: ClipRRect(
        borderRadius: AppSpacing.radiusLg,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: paidiXSmoothScrollPhysics,
          child: DataTable(
            horizontalMargin: 20,
            columnSpacing: 24,
            headingRowHeight: 46,
            dataRowMinHeight: 52,
            dataRowMaxHeight: 56,
            headingRowColor: WidgetStateProperty.all(colors.cardDark),
            dividerThickness: 1,
            columns: [
              DataColumn(
                label: Text(
                  'REFERENCE',
                  style: AppTypography.tableHeader.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ),
              DataColumn(
                label: Text(
                  'SENDER',
                  style: AppTypography.tableHeader.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ),
              DataColumn(
                label: Text(
                  'AMOUNT',
                  style: AppTypography.tableHeader.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ),
              DataColumn(
                label: Text(
                  'RATE',
                  style: AppTypography.tableHeader.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ),
              DataColumn(
                label: Text(
                  'FEE',
                  style: AppTypography.tableHeader.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ),
              DataColumn(
                label: Text(
                  'NET PKR',
                  style: AppTypography.tableHeader.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ),
              DataColumn(
                label: Text(
                  'STATUS',
                  style: AppTypography.tableHeader.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ),
              DataColumn(
                label: Text(
                  'DATE',
                  style: AppTypography.tableHeader.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ),
              DataColumn(
                label: Text(
                  'SUBMITTED',
                  style: AppTypography.tableHeader.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ),
            ],
            rows: items.map((item) {
              return DataRow(
                cells: [
                  DataCell(
                    Text(
                      item.reference,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
                      ),
                    ),
                    onTap: onItemTap == null ? null : () => onItemTap!(item),
                  ),
                  DataCell(
                    Text(
                      item.sender,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
                      ),
                    ),
                    onTap: onItemTap == null ? null : () => onItemTap!(item),
                  ),
                  DataCell(
                    Text(
                      AppFormatters.formatUsd(item.amount),
                      style: TextStyle(
                        fontFamily: AppTheme.activeFontFamily,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
                      ),
                    ),
                    onTap: onItemTap == null ? null : () => onItemTap!(item),
                  ),
                  DataCell(
                    Text(
                      '1 USD = ${item.exchangeRate.toStringAsFixed(2)}',
                      style: AppTypography.tableCellMuted.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                    onTap: onItemTap == null ? null : () => onItemTap!(item),
                  ),
                  DataCell(
                    Text(
                      AppFormatters.formatUsd(item.feeAmount),
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: colors.textSecondary,
                      ),
                    ),
                    onTap: onItemTap == null ? null : () => onItemTap!(item),
                  ),
                  DataCell(
                    Text(
                      AppFormatters.formatPkr(item.netPkr),
                      style: TextStyle(
                        fontFamily: AppTheme.activeFontFamily,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: colors.aquaLight,
                      ),
                    ),
                    onTap: onItemTap == null ? null : () => onItemTap!(item),
                  ),
                  DataCell(
                    StatusBadge(status: item.status),
                    onTap: onItemTap == null ? null : () => onItemTap!(item),
                  ),
                  DataCell(
                    Text(
                      AppFormatters.formatDate(item.transactionDate),
                      style: TextStyle(
                        fontSize: 12.5,
                        color: colors.textSecondary,
                      ),
                    ),
                    onTap: onItemTap == null ? null : () => onItemTap!(item),
                  ),
                  DataCell(
                    Text(
                      AppFormatters.formatDate(item.submittedDate),
                      style: TextStyle(fontSize: 12, color: colors.textMuted),
                    ),
                    onTap: onItemTap == null ? null : () => onItemTap!(item),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}
