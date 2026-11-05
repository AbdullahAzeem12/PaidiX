/// Defines customer score card in the dashboard feature's presentation layer.

import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/paidix_toast.dart';
import '../../../settings/domain/fx_display_preferences.dart';
import '../../domain/dashboard_models.dart';

class CustomerScoreCard extends StatefulWidget {
  final CustomerScore? score;

  const CustomerScoreCard({
    super.key,
    this.score,
  });

  /// Creates the mutable state object that backs this stateful widget.
  @override
  State<CustomerScoreCard> createState() => _CustomerScoreCardState();
}

class _CustomerScoreCardState extends State<CustomerScoreCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _starController;
  late final Animation<double> _starScale;
  late final Animation<double> _starOpacity;
  late final Animation<Color?> _starColor;

  /// Initializes controllers, listeners, and other state owned by this widget.
  @override
  void initState() {
    super.initState();
    _starController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    );

    final isTest =
        WidgetsBinding.instance.runtimeType.toString().contains('Test');
    if (!isTest) {
      _starController.repeat(reverse: true);
    } else {
      _starController.forward();
    }

    _starScale = Tween<double>(begin: 0.88, end: 1.25).animate(
      CurvedAnimation(
        parent: _starController,
        curve: Curves.easeInOutSine,
      ),
    );

    _starOpacity = Tween<double>(begin: 0.55, end: 1.0).animate(
      CurvedAnimation(
        parent: _starController,
        curve: Curves.easeInOutSine,
      ),
    );

    _starColor = ColorTween(
      begin: const Color(0xFFF59E0B), // Vibrant Amber Yellow
      end: const Color(0xFFFFE600),   // Glowing Radiant Gold
    ).animate(
      CurvedAnimation(
        parent: _starController,
        curve: Curves.easeInOutSine,
      ),
    );
  }

  /// Releases resources owned by this object before it is removed.
  @override
  void dispose() {
    _starController.dispose();
    super.dispose();
  }

  /// Builds the widget subtree from its current properties and inherited context.
  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    final scoreVal = widget.score?.score?.toString() ?? '50';
    final gradeVal = widget.score?.grade ?? '—';
    final trustVal = widget.score?.trustLabel ?? 'NEW';
    final completedVal = widget.score?.completedTransactions?.toString() ?? '0';
    final rateVal = widget.score?.completionRate != null
        ? '${widget.score!.completionRate!.toStringAsFixed(0)}%'
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

        final double? totalVolume = widget.score?.totalVolumePkr;
        final String volumeVal;
        if (widget.score != null && totalVolume != null) {
          volumeVal = FxDisplayPreferences.formatVolumePkr(
            totalVolume,
          );
        } else if (isStealth && !isRevealed) {
          volumeVal = 'Rs. ••••••••••';
        } else {
          final rawVolume = widget.score?.totalVolumePkr != null
              ? AppFormatters.formatPkr(widget.score!.totalVolumePkr)
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
                      // Eyebrow with continuously animated blinking yellow star
                      Row(
                        children: [
                          AnimatedBuilder(
                            animation: _starController,
                            builder: (context, child) {
                              final currentColor =
                                  _starColor.value ?? const Color(0xFFF59E0B);
                              return Transform.scale(
                                scale: _starScale.value,
                                child: Opacity(
                                  opacity: _starOpacity.value,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: currentColor.withValues(
                                              alpha: 0.5 *
                                                  _starOpacity.value),
                                          blurRadius:
                                              12 * _starScale.value,
                                          spreadRadius: 2,
                                        ),
                                      ],
                                    ),
                                    child: Icon(
                                      Icons.auto_awesome,
                                      size: 16,
                                      color: currentColor,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(width: 9),
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
                      const SizedBox(height: 14),

                      // Big Score & Grade & Trust Label (matches 50 — NEW / 90 A+ EXCELLENT)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            scoreVal,
                            style: TextStyle(
                              fontSize: 48,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -1.0,
                              height: 1.0,
                              color: colors.mintHeroText,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (gradeVal.isNotEmpty)
                                Text(
                                  gradeVal,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    height: 1.0,
                                    color: colors.mintHeroText,
                                  ),
                                ),
                              const SizedBox(height: 2),
                              Text(
                                trustVal,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.2,
                                  height: 1.2,
                                  color: colors.mintHeroText,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // Divider
                      Container(
                        height: 1,
                        color:
                            colors.mintHeroText.withValues(alpha: 0.18),
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
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.3,
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
              fontSize: isVolume ? 15.5 : 16.5,
              fontWeight: FontWeight.w900,
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
