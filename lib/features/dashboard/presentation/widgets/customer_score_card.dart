/// Defines customer score card in the dashboard feature's presentation layer.

import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/paidix_toast.dart';
import '../../../settings/domain/fx_display_preferences.dart';
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

    final scoreVal = score?.score?.toString() ?? '50';
    final gradeVal = score?.grade ?? '—';
    final trustVal = score?.trustLabel ?? 'NEW';
    final completedVal = score?.completedTransactions?.toString() ?? '0';
    final rateVal = score?.completionRate != null
        ? '${score!.completionRate!.toStringAsFixed(0)}%'
        : '0%';

    return AnimatedBuilder(
      animation: Listenable.merge([
        FxDisplayPreferences.stealthModeNotifier,
        FxDisplayPreferences.compactFormatNotifier,
        FxDisplayPreferences.dashboardBalanceRevealedNotifier,
      ]),
      builder: (context, _) {
        final isStealth = FxDisplayPreferences.isStealthMode;
        final isRevealed = FxDisplayPreferences.isDashboardBalanceRevealed;

        final double? totalVolume = score?.totalVolumePkr;
        final String volumeVal;
        if (score != null && totalVolume != null) {
          volumeVal = FxDisplayPreferences.formatVolumePkr(
            totalVolume,
          );
        } else if (isStealth && !isRevealed) {
          volumeVal = 'Rs. ••••••••••';
        } else {
          final rawVolume = score?.totalVolumePkr != null
              ? AppFormatters.formatPkr(score!.totalVolumePkr)
              : 'Rs. 0.00';
          volumeVal = rawVolume.startsWith('Rs ')
              ? rawVolume.replaceFirst('Rs ', 'Rs. ')
              : (rawVolume.startsWith('Rs.') ? rawVolume : 'Rs. $rawVolume');
        }

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
                // Decorative circular ambient shape on right edge (matches screenshot)
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
                  padding: const EdgeInsets.symmetric(
                      horizontal: 22, vertical: 22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Eyebrow with calm, steady institutional verification shield
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4.5),
                            decoration: BoxDecoration(
                              color: colors.mintHeroSubtle,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: colors.mintHeroText.withValues(alpha: 0.25),
                                width: 1.0,
                              ),
                            ),
                            child: Icon(
                              Icons.verified_user_outlined,
                              size: 15,
                              color: colors.mintHeroText,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'CUSTOMER SCORE',
                            style: TextStyle(
                              fontFamily: AppTheme.activeFontFamily,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.5,
                              color: colors.mintHeroText,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Big Score & Grade & Trust Label (matches 50 — NEW / 90 A+ EXCELLENT)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            scoreVal,
                            style: TextStyle(
                              fontFamily: AppTheme.activeFontFamily,
                              fontSize: 48,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -1.2,
                              color: colors.mintHeroText,
                              height: 1.0,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                gradeVal,
                                style: TextStyle(
                                  fontFamily: AppTheme.activeFontFamily,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: colors.mintHeroText,
                                  height: 1.1,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                trustVal,
                                style: TextStyle(
                                  fontFamily: AppTheme.activeFontFamily,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 1.2,
                                  color: colors.mintHeroText.withValues(alpha: 0.85),
                                  height: 1.1,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // Divider line on hero card
                      Container(
                        height: 1,
                        color: colors.mintHeroText.withValues(alpha: 0.18),
                      ),
                      const SizedBox(height: 16),

                      // Three metrics with generous vertical gap & perfect alignment
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildMetricCol(
                            label: 'COMPLETED',
                            value: completedVal,
                            textColor: colors.mintHeroText,
                            flex: 3,
                            paddingRight: 10,
                          ),
                          _buildMetricCol(
                            label: 'RATE',
                            value: rateVal,
                            textColor: colors.mintHeroText,
                            flex: 2,
                            paddingRight: 10,
                          ),
                          _buildMetricCol(
                            label: 'VOLUME',
                            value: volumeVal,
                            textColor: colors.mintHeroText,
                            flex: 5,
                            isVolume: true,
                            isStealth: isStealth && !isRevealed,
                            isRevealed: isStealth && isRevealed,
                            onTap: isStealth
                                ? () {
                                    FxDisplayPreferences
                                        .toggleDashboardBalanceRevealed();
                                    final nowRevealed = !isRevealed;
                                    PaidiXToast.showInfo(
                                      context,
                                      nowRevealed
                                          ? 'Balances revealed temporarily.'
                                          : 'Stealth privacy active — balances masked.',
                                    );
                                  }
                                : null,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Builds the metric col section of this interface.
  Widget _buildMetricCol({
    required String label,
    required String value,
    required Color textColor,
    int flex = 1,
    double paddingRight = 0,
    bool isVolume = false,
    bool isStealth = false,
    bool isRevealed = false,
    VoidCallback? onTap,
  }) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontFamily: AppTheme.activeFontFamily,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                  color: textColor.withValues(alpha: 0.85),
                ),
              ),
              if (isVolume && (isStealth || isRevealed)) ...[
                const SizedBox(width: 4),
                Icon(
                  isRevealed
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  size: 11,
                  color: textColor.withValues(alpha: 0.75),
                ),
              ],
            ],
          ),
        ),
        // Premium vertical gap separating title from value
        const SizedBox(height: 10),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            maxLines: 1,
            softWrap: false,
            style: TextStyle(
              fontFamily: AppTheme.activeFontFamily,
              fontSize: isVolume ? 15.5 : 16.5,
              fontWeight: FontWeight.w700,
              letterSpacing: isStealth ? 1.5 : -0.3,
              color: textColor,
            ),
          ),
        ),
      ],
    );

    return Expanded(
      flex: flex,
      child: Padding(
        padding: EdgeInsets.only(right: paddingRight),
        child: onTap != null
            ? GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onTap,
                child: content,
              )
            : content,
      ),
    );
  }
}
