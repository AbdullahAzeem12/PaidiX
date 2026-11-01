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
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isCompact = screenWidth < 600;
    final horizontalPadding = isCompact ? 12.0 : 16.0;
    final verticalPadding = isCompact ? 12.0 : 14.0;
    final badgeSize = isCompact ? 26.0 : 28.0;
    final letterSpacing = isCompact ? 0.4 : 0.8;
    final fontSize = isCompact ? 9.8 : 10.5;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: verticalPadding,
      ),
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
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    title.toUpperCase(),
                    style: TextStyle(
                      fontSize: fontSize,
                      fontWeight: FontWeight.w800,
                      letterSpacing: letterSpacing,
                      color: colors.textSecondary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                width: badgeSize,
                height: badgeSize,
                decoration: BoxDecoration(
                  color: iconBgColor ??
                      (iconColor ?? colors.aqua).withValues(alpha: 0.18),
                  borderRadius: AppSpacing.radiusSm,
                ),
                alignment: Alignment.center,
                child: IconTheme(
                  data: IconThemeData(size: isCompact ? 15.0 : 16.0),
                  child: icon,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            count,
            style: AppTypography.statValueLarge.copyWith(
              fontSize: isCompact ? 22 : 24,
              color: colors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
