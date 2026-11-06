/// Defines brand logo in the application core utilities and reusable widgets.

import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_theme.dart';
import '../../app/theme/app_typography.dart';

class BrandLogo extends StatelessWidget {
  final bool showPlanBadge;
  final bool showTagline;
  final double size;
  final bool forceLightText;

  const BrandLogo({
    super.key,
    this.showPlanBadge = false,
    this.showTagline = true,
    this.size = 38.0,
    this.forceLightText = false,
  });

  /// Builds the widget subtree from its current properties and inherited context.
  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    final titleColor = forceLightText ? Colors.white : colors.textPrimary;
    final taglineMutedColor =
        forceLightText ? AppColors.sidebarMuted : colors.textSecondary;
    final goldColor = colors.gold;
    final markBorder = forceLightText ? AppColors.sidebarLine : colors.border;

    final mark = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFF022F32),
        borderRadius: AppSpacing.radiusMd,
        border: Border.all(color: markBorder, width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: 'P',
              style: TextStyle(
                fontFamily: AppTheme.activeFontFamily,
                color: Colors.white,
                fontSize: size * 0.46,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
              ),
            ),
            TextSpan(
              text: 'X',
              style: TextStyle(
                fontFamily: AppTheme.activeFontFamily,
                color: goldColor,
                fontSize: size * 0.46,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            mark,
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'PaidiX',
                    style: AppTypography.brandTitle.copyWith(color: titleColor),
                  ),
                  if (showTagline) ...[
                    const SizedBox(height: 1),
                    Wrap(
                      children: [
                        Text(
                          'Move Money. ',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w500,
                            color: taglineMutedColor,
                          ),
                        ),
                        Text(
                          'Build Trust.',
                          style: TextStyle(
                            fontFamily: AppTheme.activeFontFamily,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: goldColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}
