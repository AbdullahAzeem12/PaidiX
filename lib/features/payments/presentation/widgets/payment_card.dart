/// Defines payment card in the payments feature's presentation layer.

import 'package:material_ui/material_ui.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/spongy_tap.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../domain/payment_models.dart';

class PaymentCard extends StatelessWidget {
  final PaymentItem item;
  final VoidCallback? onTap;

  const PaymentCard({super.key, required this.item, this.onTap});

  /// Builds the widget subtree from its current properties and inherited context.
  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Semantics(
      button: onTap != null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          borderRadius: AppSpacing.radiusLg,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(
                alpha: colors.brightness == Brightness.dark ? 0.25 : 0.05,
              ),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: SpongyTap(
          onTap: onTap,
          pressScale: 0.975,
          pressDuration: const Duration(milliseconds: 75),
          releaseDuration: const Duration(milliseconds: 210),
          borderRadius: AppSpacing.radiusLg,
          backgroundColor: colors.card,
          border: Border.all(color: colors.border, width: 1.2),
          splashColor: colors.aqua.withValues(alpha: 0.16),
          highlightColor: colors.aqua.withValues(alpha: 0.06),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Reference & Status
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        item.reference,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                          color: colors.aquaLight,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
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
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'AMOUNT (USD)',
                            style: AppTypography.tableHeader.copyWith(
                              color: colors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 3),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              AppFormatters.formatUsd(item.amount),
                              style: TextStyle(
                                fontFamily: AppTheme.activeFontFamily,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: colors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'NET PKR',
                            style: AppTypography.tableHeader.copyWith(
                              color: colors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 3),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerRight,
                            child: Text(
                              AppFormatters.formatPkr(item.netPkr),
                              style: TextStyle(
                                fontFamily: AppTheme.activeFontFamily,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: colors.aquaLight,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Date & Fee info
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        '1 USD = ${item.exchangeRate.toStringAsFixed(2)} • Fee: ${AppFormatters.formatUsd(item.feeAmount)}',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: colors.textMuted,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
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
        ),
      ),
    );
  }
}
