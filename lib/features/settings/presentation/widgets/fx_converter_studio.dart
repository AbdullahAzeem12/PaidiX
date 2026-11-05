import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/widgets/paidix_toast.dart';
import '../../../../core/widgets/spongy_tap.dart';
import '../../../profile/domain/user_profile.dart';
import '../../domain/fx_display_preferences.dart';

/// Financial Display & Privacy Settings Studio.
/// Controls Stealth Balance Privacy Mode and Compact Currency Notation
/// with real-time reactivity on Dashboard and Customer Score Card.
class FxConverterStudio extends StatelessWidget {
  final PaidiXColorScheme colors;
  final UserProfile profile;
  final bool isMobile;

  const FxConverterStudio({
    super.key,
    required this.colors,
    required this.profile,
    required this.isMobile,
  });

  @override
  Widget build(BuildContext context) {
    final c = colors;

    return ValueListenableBuilder<bool>(
      valueListenable: FxDisplayPreferences.stealthModeNotifier,
      builder: (context, isStealth, _) {
        return ValueListenableBuilder<bool>(
          valueListenable: FxDisplayPreferences.compactFormatNotifier,
          builder: (context, isCompact, _) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Section Header ──────────────────────────────────────────
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: c.aqua.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: c.aqua.withValues(alpha: 0.4),
                          width: 1,
                        ),
                      ),
                      child: Icon(
                        Icons.visibility_outlined,
                        size: 15,
                        color: c.aqua,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'FINANCIAL DISPLAY & PRIVACY',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.4,
                              color: c.gold,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            'Balance masking and compact currency formatting.',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                              color: c.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // ── Stealth Privacy Mode ────────────────────────────────────
                _buildSwitchTile(
                  c: c,
                  icon: isStealth
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                  title: 'Stealth Privacy Mode',
                  subtitle: 'Hide balance totals on Dashboard until tapped.',
                  value: isStealth,
                  onToggle: () {
                    FxDisplayPreferences.toggleStealthMode();
                    PaidiXToast.showInfo(
                      context,
                      !isStealth
                          ? 'Stealth Privacy Mode enabled.'
                          : 'Stealth Privacy Mode disabled.',
                    );
                  },
                ),
                const SizedBox(height: 10),

                // ── Compact Currency Notation ──────────────────────────────
                _buildSwitchTile(
                  c: c,
                  icon: Icons.compress_rounded,
                  title: 'Compact Currency Notation',
                  subtitle:
                      'Display amounts as Rs. 1.17M instead of full precision.',
                  value: isCompact,
                  onToggle: () {
                    FxDisplayPreferences.toggleCompactFormat();
                    PaidiXToast.showInfo(
                      context,
                      !isCompact
                          ? 'Compact Currency Notation enabled.'
                          : 'Standard Currency Notation enabled.',
                    );
                  },
                ),
                const SizedBox(height: 16),

                // ── Live Preview Card ───────────────────────────────────────
                _buildLivePreviewCard(c, isStealth, isCompact),
                const SizedBox(height: 14),

                // ── Reset to defaults ───────────────────────────────────────
                Align(
                  alignment: Alignment.centerRight,
                  child: SpongyTap(
                    onTap: () {
                      FxDisplayPreferences.resetToDefault();
                      PaidiXToast.showSuccess(
                        context,
                        'Display settings reset to system defaults.',
                      );
                    },
                    pressScale: 0.94,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 4, horizontal: 2),
                      child: Text(
                        'Reset display to defaults',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: c.textSecondary,
                          decoration: TextDecoration.underline,
                          decorationColor: c.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ── Switch Tile ──────────────────────────────────────────────────────────
  Widget _buildSwitchTile({
    required PaidiXColorScheme c,
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required VoidCallback onToggle,
  }) {
    return GestureDetector(
      onTap: onToggle,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: c.cardDark,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: value ? c.aqua.withValues(alpha: 0.4) : c.border,
            width: value ? 1.4 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: value ? c.aqua.withValues(alpha: 0.16) : c.card,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                size: 16,
                color: value ? c.aqua : c.textMuted,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: c.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 1.5),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w400,
                      color: c.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Pill Switch
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeInOutCubic,
              width: 38,
              height: 22,
              padding: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: value ? c.aqua : c.borderSubtle,
              ),
              alignment: value ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: value ? const Color(0xFF021B19) : Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: 3,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Live Preview Card ────────────────────────────────────────────────────
  Widget _buildLivePreviewCard(
      PaidiXColorScheme c, bool isStealth, bool isCompact) {
    const sampleVolume = 1169570.67;
    final previewValue = FxDisplayPreferences.formatVolumePkr(sampleVolume);

    final String statusBadgeText;
    final Color statusColor;
    if (isStealth) {
      statusBadgeText = 'Stealth Active';
      statusColor = Colors.amber;
    } else if (isCompact) {
      statusBadgeText = 'Compact Active';
      statusColor = c.aqua;
    } else {
      statusBadgeText = 'Standard Display';
      statusColor = c.emerald;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.cardDark,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'LIVE PREVIEW (CUSTOMER SCORE VOLUME)',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                        color: c.textMuted,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      previewValue,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: isStealth ? c.textMuted : c.textPrimary,
                        letterSpacing: isStealth ? 1.5 : -0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: statusColor.withValues(alpha: 0.35),
                    width: 0.8,
                  ),
                ),
                child: Text(
                  statusBadgeText,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          if (isStealth) ...[
            const SizedBox(height: 8),
            Text(
              '💡 Tap anywhere on the masked volume in Dashboard to temporarily reveal.',
              style: TextStyle(
                fontSize: 10,
                color: c.textSecondary,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
