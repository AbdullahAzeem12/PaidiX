import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';

class StatusMetricCard extends StatelessWidget {
  final String title;
  final String count;
  final Widget icon;
  final Color? iconColor;
  final Color? iconBgColor;

  const StatusMetricCard({
    super.key,
    required this.title,
    required this.count,
    required this.icon,
    this.iconColor,
    this.iconBgColor,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: AppSpacing.radiusLg,
        border: Border.all(color: colors.border, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                    color: colors.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: iconBgColor ??
                      (iconColor ?? colors.aqua).withValues(alpha: 0.18),
                  borderRadius: AppSpacing.radiusSm,
                ),
                alignment: Alignment.center,
                child: icon,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            count,
            style: AppTypography.statValueLarge.copyWith(
              fontSize: 24,
              color: colors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
