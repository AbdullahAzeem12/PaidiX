import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';

class FinancialStatCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtext;
  final String description;
  final Widget icon;
  final Color? iconBg;

  const FinancialStatCard({
    super.key,
    required this.title,
    required this.value,
    required this.subtext,
    required this.description,
    required this.icon,
    this.iconBg,
  });

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
        child: Stack(
          children: [
            // Decorative subtle shape on top-right (matching reference)
            Positioned(
              right: -25,
              top: -25,
              child: Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  color: colors.cardHighlight.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          title.toUpperCase(),
                          style: AppTypography.cardTitle.copyWith(
                            color: colors.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: iconBg ?? colors.cardDark,
                          borderRadius: AppSpacing.radiusMd,
                          border: Border.all(
                            color: colors.borderSubtle,
                            width: 1,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: icon,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      value,
                      style: AppTypography.statValueLarge.copyWith(
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtext,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: colors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                      color: colors.textMuted,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
