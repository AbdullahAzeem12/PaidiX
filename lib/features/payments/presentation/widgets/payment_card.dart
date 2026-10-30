import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../domain/payment_models.dart';

class PaymentCard extends StatelessWidget {
  final PaymentItem item;

  const PaymentCard({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: AppSpacing.radiusLg,
        border: Border.all(color: colors.border, width: 1.2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Reference & Status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  item.reference,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: colors.aquaLight,
                  ),
                ),
                StatusBadge(status: item.status),
              ],
            ),
            const SizedBox(height: 10),

            // Sender
            Text(
              item.sender,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: colors.textPrimary,
              ),
            ),
            if (item.senderCompany.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                item.senderCompany,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w400,
                  color: colors.textSecondary,
                ),
              ),
            ],
            const SizedBox(height: 12),

            // Divider
            Divider(color: colors.divider, height: 1),
            const SizedBox(height: 12),

            // Amounts
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AMOUNT (USD)',
                      style: AppTypography.tableHeader.copyWith(color: colors.textSecondary),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      AppFormatters.formatUsd(item.amount),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: colors.textPrimary,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'NET PKR',
                      style: AppTypography.tableHeader.copyWith(color: colors.textSecondary),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      AppFormatters.formatPkr(item.netPkr),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: colors.aquaLight,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Date & Fee info
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '1 USD = ${item.exchangeRate.toStringAsFixed(2)} • Fee: ${AppFormatters.formatUsd(item.feeAmount)}',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: colors.textMuted,
                  ),
                ),
                Text(
                  AppFormatters.formatDate(item.transactionDate),
                  style: TextStyle(
                    fontSize: 11.5,
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
