/// Defines kyc stepper in the kyc feature's presentation layer.

import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme.dart';
import '../../domain/kyc_models.dart';

class KycStepper extends StatelessWidget {
  final KycStep currentStep;
  final ValueChanged<KycStep>? onStepTapped;

  const KycStepper({
    super.key,
    required this.currentStep,
    this.onStepTapped,
  });

  /// Builds the widget subtree from its current properties and inherited context.
  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final steps = KycStep.values;
    const circleSize = 32.0;
    const circleRadius = circleSize / 2;

    // Theme palette
    final activeColor = isDark ? colors.aquaLight : colors.aqua;
    final completedColor = colors.emerald;
    final inactiveBorderColor = colors.border.withValues(alpha: 0.7);
    final inactiveLineColor = colors.border.withValues(alpha: 0.45);

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        final isCompact = totalWidth < 460;
        final isVeryNarrow = totalWidth < 350;

        // Outer horizontal padding
        final horizontalPadding = isCompact ? 10.0 : 20.0;
        const columnPadding = 4.0;
        // Exact center X of the first and last circles relative to the padded container
        const firstCircleCenterX = columnPadding + circleRadius;

        return Padding(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          child: Stack(
            children: [
              // 1. Prominent Connecting Lines Layer (Centered at circle Y = 16)
              Positioned(
                top: circleRadius - 1.5,
                left: firstCircleCenterX,
                right: firstCircleCenterX,
                child: Row(
                  children: [
                    for (int i = 0; i < steps.length - 1; i++) ...[
                      Expanded(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 320),
                          curve: Curves.easeOutCubic,
                          height: steps[i].stepNumber < currentStep.stepNumber ? 3.2 : 2.0,
                          decoration: BoxDecoration(
                            color: steps[i].stepNumber < currentStep.stepNumber
                                ? completedColor
                                : inactiveLineColor,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // 2. Interactive Circles & Step Labels Layer
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: steps.map((step) {
                  final isCompleted = step.stepNumber < currentStep.stepNumber;
                  final isActive = step == currentStep;
                  final canTap = isCompleted && onStepTapped != null;

                  return InkWell(
                    onTap: canTap ? () => onStepTapped!(step) : null,
                    borderRadius: BorderRadius.circular(24),
                    splashColor: activeColor.withValues(alpha: 0.15),
                    highlightColor: Colors.transparent,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: columnPadding),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Step Circle:
                          // - Completed: FILLED solid with checkmark
                          // - Active: HOLLOW with thick prominent border for user to fill
                          // - Inactive: Subtle hollow circle
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 280),
                            curve: Curves.easeOutCubic,
                            width: circleSize,
                            height: circleSize,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isCompleted
                                  ? completedColor
                                  : colors.background,
                              border: Border.all(
                                color: isCompleted
                                    ? completedColor
                                    : isActive
                                        ? activeColor
                                        : inactiveBorderColor,
                                width: isActive ? 3.0 : (isCompleted ? 1.5 : 1.5),
                              ),
                              boxShadow: isActive
                                  ? [
                                      BoxShadow(
                                        color: activeColor.withValues(alpha: 0.35),
                                        blurRadius: 8,
                                        spreadRadius: 1,
                                      ),
                                    ]
                                  : (isCompleted
                                      ? [
                                          BoxShadow(
                                            color: completedColor.withValues(alpha: 0.25),
                                            blurRadius: 6,
                                          ),
                                        ]
                                      : null),
                            ),
                            child: Center(
                              child: isCompleted
                                  ? const Icon(
                                      Icons.check_rounded,
                                      size: 18,
                                      color: Colors.white,
                                    )
                                  : Text(
                                      '${step.stepNumber}',
                                      style: TextStyle(
                                        fontFamily: AppTheme.activeFontFamily,
                                        color: isActive
                                            ? (isDark ? colors.aquaLight : activeColor)
                                            : colors.textMuted,
                                        fontSize: 13,
                                        fontWeight: isActive
                                            ? FontWeight.w700
                                            : FontWeight.w600,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 7),

                          // Step Label
                          SizedBox(
                            width: isVeryNarrow ? 58 : (isCompact ? 68 : 84),
                            child: Text(
                              step.label,
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: AppTheme.activeFontFamily,
                                fontSize: isVeryNarrow ? 10.5 : (isCompact ? 11.5 : 12.5),
                                fontWeight: isActive
                                    ? FontWeight.w700
                                    : (isCompleted ? FontWeight.w600 : FontWeight.w500),
                                color: isActive
                                    ? colors.textPrimary
                                    : (isCompleted
                                        ? colors.textPrimary
                                        : colors.textMuted),
                                letterSpacing: isActive ? -0.2 : 0,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }
}
