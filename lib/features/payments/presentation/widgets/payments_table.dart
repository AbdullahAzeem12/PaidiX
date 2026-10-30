import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../domain/payment_models.dart';

class PaymentsTable extends StatelessWidget {
  final List<PaymentItem> items;

  const PaymentsTable({super.key, required this.items});

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
                label: Text('REFERENCE',
                    style: AppTypography.tableHeader.copyWith(color: colors.textSecondary)),
              ),
              DataColumn(
                label: Text('SENDER',
                    style: AppTypography.tableHeader.copyWith(color: colors.textSecondary)),
              ),
              DataColumn(
                label: Text('AMOUNT',
                    style: AppTypography.tableHeader.copyWith(color: colors.textSecondary)),
              ),
              DataColumn(
                label: Text('RATE',
                    style: AppTypography.tableHeader.copyWith(color: colors.textSecondary)),
              ),
              DataColumn(
                label: Text('FEE',
                    style: AppTypography.tableHeader.copyWith(color: colors.textSecondary)),
              ),
              DataColumn(
                label: Text('NET PKR',
                    style: AppTypography.tableHeader.copyWith(color: colors.textSecondary)),
              ),
              DataColumn(
                label: Text('STATUS',
                    style: AppTypography.tableHeader.copyWith(color: colors.textSecondary)),
              ),
              DataColumn(
                label: Text('DATE',
                    style: AppTypography.tableHeader.copyWith(color: colors.textSecondary)),
              ),
              DataColumn(
                label: Text('SUBMITTED',
                    style: AppTypography.tableHeader.copyWith(color: colors.textSecondary)),
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
                  ),
                  DataCell(
                    Text(
                      AppFormatters.formatUsd(item.amount),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                  DataCell(
                    Text(
                      '1 USD = ${item.exchangeRate.toStringAsFixed(2)}',
                      style: AppTypography.tableCellMuted.copyWith(color: colors.textSecondary),
                    ),
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
                  ),
                  DataCell(
                    Text(
                      AppFormatters.formatPkr(item.netPkr),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: colors.aquaLight,
                      ),
                    ),
                  ),
                  DataCell(
                    StatusBadge(status: item.status),
                  ),
                  DataCell(
                    Text(
                      AppFormatters.formatDate(item.transactionDate),
                      style: TextStyle(
                        fontSize: 12.5,
                        color: colors.textSecondary,
                      ),
                    ),
                  ),
                  DataCell(
                    Text(
                      AppFormatters.formatDate(item.submittedDate),
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.textMuted,
                      ),
                    ),
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
