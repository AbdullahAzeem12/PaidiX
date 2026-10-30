import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../domain/dashboard_models.dart';

class CustomerScoreCard extends StatelessWidget {
  final CustomerScore? score;

  const CustomerScoreCard({
    super.key,
    this.score,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    final scoreVal = score?.score?.toString() ?? '—';
    final gradeVal = score?.grade ?? '';
    final trustVal = score?.trustLabel ?? 'TRUSTED';
    final completedVal = score?.completedTransactions?.toString() ?? '—';
    final rateVal = score?.completionRate != null
        ? '${score!.completionRate!.toStringAsFixed(0)}%'
        : '—';
    final volumeVal = score?.totalVolumePkr != null
        ? AppFormatters.formatPkr(score!.totalVolumePkr)
        : '—';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: colors.mintHero,
        borderRadius: AppSpacing.radiusXl,
        boxShadow: [
          BoxShadow(
            color: colors.aqua.withValues(alpha: 0.12),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: AppSpacing.radiusXl,
        child: Stack(
          children: [
            // Decorative circular shape on right edge (matches screenshot 5)
            Positioned(
              right: -30,
              top: -30,
              bottom: -30,
              child: Container(
                width: 140,
                decoration: BoxDecoration(
                  color: colors.mintHeroSubtle,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Eyebrow
                  Row(
                    children: [
                      Icon(
                        Icons.auto_awesome,
                        size: 15,
                        color: colors.mintHeroText,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'CUSTOMER SCORE',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                          color: colors.mintHeroText,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Big Score & Grade
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        scoreVal,
                        style: AppTypography.statValueScore.copyWith(
                          color: colors.mintHeroText,
                        ),
                      ),
                      if (gradeVal.isNotEmpty) ...[
                        const SizedBox(width: 10),
                        Text(
                          gradeVal,
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: colors.mintHeroText,
                          ),
                        ),
                      ],
                      const SizedBox(width: 6),
                      Text(
                        trustVal,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                          color: colors.mintHeroText,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Divider
                  Container(
                    height: 1,
                    color: colors.mintHeroText.withValues(alpha: 0.16),
                  ),
                  const SizedBox(height: 14),

                  // Three metrics
                  Row(
                    children: [
                      _buildMetricCol('COMPLETED', completedVal, colors.mintHeroText),
                      _buildMetricCol('RATE', rateVal, colors.mintHeroText),
                      _buildMetricCol('VOLUME', volumeVal, colors.mintHeroText),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCol(String label, String value, Color textColor) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: textColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}
