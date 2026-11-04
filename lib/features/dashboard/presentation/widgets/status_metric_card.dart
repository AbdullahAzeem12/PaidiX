import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/widgets/spongy_tap.dart';

class StatusMetricCard extends StatelessWidget {
  final String title;
  final String count;
  final Widget icon;
  final Color? iconColor;
  final Color? iconBgColor;
  final bool isSelected;
  final VoidCallback? onTap;
  final Color? activeColor;

  const StatusMetricCard({
    super.key,
    required this.title,
    required this.count,
    required this.icon,
    this.iconColor,
    this.iconBgColor,
    this.isSelected = false,
    this.onTap,
    this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isCompact = screenWidth < 600;
    final horizontalPadding = isCompact ? 12.0 : 16.0;
    final verticalPadding = isCompact ? 12.0 : 14.0;
    final badgeSize = isCompact ? 26.0 : 28.0;
    final letterSpacing = isCompact ? 0.4 : 0.8;
    final fontSize = isCompact ? 9.8 : 10.5;

    final effectiveActiveColor = activeColor ?? colors.aqua;

    final cardContent = AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: verticalPadding,
      ),
      decoration: BoxDecoration(
        color: isSelected
            ? (isDark
                ? effectiveActiveColor.withValues(alpha: 0.14)
                : effectiveActiveColor.withValues(alpha: 0.08))
            : colors.card,
        borderRadius: AppSpacing.radiusLg,
        border: Border.all(
          color: isSelected ? effectiveActiveColor : colors.border,
          width: isSelected ? 1.8 : 1.2,
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: effectiveActiveColor.withValues(
                    alpha: isDark ? 0.35 : 0.20,
                  ),
                  blurRadius: 10,
                  spreadRadius: 0.5,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
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
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title.toUpperCase(),
                        style: TextStyle(
                          fontSize: fontSize,
                          fontWeight:
                              isSelected ? FontWeight.w900 : FontWeight.w800,
                          letterSpacing: letterSpacing,
                          color: isSelected
                              ? effectiveActiveColor
                              : colors.textSecondary,
                        ),
                      ),
                      if (isSelected) ...[
                        const SizedBox(width: 5),
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: effectiveActiveColor,
                            boxShadow: [
                              BoxShadow(
                                color: effectiveActiveColor.withValues(alpha: 0.8),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                width: badgeSize,
                height: badgeSize,
                decoration: BoxDecoration(
                  color: isSelected
                      ? effectiveActiveColor
                      : (iconBgColor ??
                          (iconColor ?? colors.aqua).withValues(alpha: 0.18)),
                  borderRadius: AppSpacing.radiusSm,
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: effectiveActiveColor.withValues(alpha: 0.4),
                            blurRadius: 6,
                          ),
                        ]
                      : null,
                ),
                alignment: Alignment.center,
                child: IconTheme(
                  data: IconThemeData(
                    size: isCompact ? 15.0 : 16.0,
                    color: isSelected ? colors.mintHeroText : null,
                  ),
                  child: icon,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.bottomLeft,
                  child: Text(
                    count,
                    style: AppTypography.statValueLarge.copyWith(
                      fontSize: isCompact ? 22 : 24,
                      fontWeight:
                          isSelected ? FontWeight.w900 : FontWeight.w800,
                      color: isSelected
                          ? effectiveActiveColor
                          : colors.textPrimary,
                    ),
                  ),
                ),
              ),
              if (isSelected) ...[
                const SizedBox(width: 6),
                AnimatedOpacity(
                  opacity: 1.0,
                  duration: const Duration(milliseconds: 200),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: effectiveActiveColor
                          .withValues(alpha: isDark ? 0.25 : 0.15),
                      borderRadius: AppSpacing.radiusPill,
                    ),
                    child: Text(
                      'ACTIVE',
                      style: TextStyle(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: effectiveActiveColor,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );

    if (onTap != null) {
      return SpongyTap(
        onTap: onTap,
        pressScale: 0.94,
        borderRadius: AppSpacing.radiusLg,
        child: cardContent,
      );
    }

    return cardContent;
  }
}
