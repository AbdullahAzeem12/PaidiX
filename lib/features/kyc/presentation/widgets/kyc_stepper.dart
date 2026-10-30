import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../domain/kyc_models.dart';

class KycStepper extends StatelessWidget {
  final KycStep currentStep;
  final ValueChanged<KycStep>? onStepTapped;

  const KycStepper({
    super.key,
    required this.currentStep,
    this.onStepTapped,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        final isCompact = totalWidth < 460;
        final isVeryNarrow = totalWidth < 350;

        return Column(
          children: [
            // Stepper Items
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.symmetric(horizontal: isCompact ? 6 : 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: KycStep.values.map((step) {
                  final isCompleted = step.stepNumber < currentStep.stepNumber;
                  final isActive = step == currentStep;
                  final showLabel = !isVeryNarrow || isActive;

                  return Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: isCompact ? 4 : 8,
                    ),
                    child: InkWell(
                      onTap: isCompleted && onStepTapped != null
                          ? () => onStepTapped!(step)
                          : null,
                      borderRadius: BorderRadius.circular(16),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: isCompact ? 5 : 8,
                          vertical: 4,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Circle Indicator
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeOutCubic,
                              width: isCompact ? 22 : 26,
                              height: isCompact ? 22 : 26,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isCompleted
                                    ? colors.emerald
                                    : isActive
                                        ? (isDark ? Colors.white : colors.brand900)
                                        : Colors.transparent,
                                border: Border.all(
                                  color: isCompleted
                                      ? colors.emerald
                                      : isActive
                                          ? (isDark ? Colors.white : colors.brand900)
                                          : colors.textMuted.withValues(alpha: 0.4),
                                  width: 1.5,
                                ),
                              ),
                              child: Center(
                                child: isCompleted
                                    ? Icon(
                                        Icons.check_rounded,
                                        size: isCompact ? 13 : 16,
                                        color: Colors.white,
                                      )
                                    : Text(
                                        '${step.stepNumber}',
                                        style: TextStyle(
                                          color: isActive
                                              ? (isDark ? const Color(0xFF021B19) : Colors.white)
                                              : colors.textMuted,
                                          fontSize: isCompact ? 10.5 : 12,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                              ),
                            ),
                            if (showLabel) ...[
                              SizedBox(width: isCompact ? 5 : 8),
                              // Step Label
                              Text(
                                step.label,
                                style: TextStyle(
                                  color: isCompleted
                                      ? (isDark ? Colors.white : colors.textPrimary)
                                      : isActive
                                          ? (isDark ? Colors.white : colors.textPrimary)
                                          : colors.textMuted,
                                  fontSize: isCompact ? 11.5 : 13,
                                  fontWeight:
                                      isActive ? FontWeight.w600 : FontWeight.w500,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 10),

            // Bottom Continuous Progress Line with Active Segment Highlight
            Padding(
              padding: EdgeInsets.symmetric(horizontal: isCompact ? 12 : 24),
              child: Stack(
                children: [
                  // Background Track
                  Container(
                    height: 2,
                    width: totalWidth,
                    color: colors.border.withValues(alpha: 0.4),
                  ),
                  // Active Progress Fill
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 350),
                    curve: Curves.easeOutCubic,
                    height: 2,
                    width: ((totalWidth * (currentStep.stepNumber - 0.5) / KycStep.values.length))
                        .clamp(0.0, totalWidth),
                    color: isDark ? Colors.white : colors.brand900,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
