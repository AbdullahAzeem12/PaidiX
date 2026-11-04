import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/widgets/spongy_tap.dart';
import '../../../profile/domain/user_profile.dart';
import '../../domain/fx_display_preferences.dart';

/// Interactive Live FX Rates & Net Payout Calculator Studio with Display Privacy Controls.
class FxConverterStudio extends StatefulWidget {
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
  State<FxConverterStudio> createState() => _FxConverterStudioState();
}

class _FxConverterStudioState extends State<FxConverterStudio> {
  static const List<double> _presetAmounts = [100.0, 500.0, 1000.0, 2500.0, 5000.0];

  @override
  Widget build(BuildContext context) {
    final c = widget.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ValueListenableBuilder<int>(
      valueListenable: FxDisplayPreferences.selectedCurrencyIndexNotifier,
      builder: (context, currencyIdx, _) {
        return ValueListenableBuilder<double>(
          valueListenable: FxDisplayPreferences.calculatorAmountNotifier,
          builder: (context, amount, _) {
            return ValueListenableBuilder<bool>(
              valueListenable: FxDisplayPreferences.stealthModeNotifier,
              builder: (context, isStealth, _) {
                return ValueListenableBuilder<bool>(
                  valueListenable: FxDisplayPreferences.compactFormatNotifier,
                  builder: (context, isCompact, _) {
                    final currency =
                        FxDisplayPreferences.supportedCurrencies[currencyIdx];
                    final netPkr = FxDisplayPreferences.calculateNetPkr(
                      amount: amount,
                      currency: currency,
                    );
                    final feeAmount =
                        amount * (FxDisplayPreferences.platformFeePercent / 100.0);

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Section Header
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
                                Icons.currency_exchange_rounded,
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
                                    'LIVE FX & PAYOUT ESTIMATOR',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1.4,
                                      color: c.gold,
                                    ),
                                  ),
                                  const SizedBox(height: 1),
                                  Text(
                                    'Real-time interbank conversion & net bank payout.',
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

                        // ── Currency Selector Chips ────────────────────────
                        Text(
                          'SELECT SENDING CURRENCY',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.4,
                            color: c.textMuted,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _buildCurrencyRow(c, currencyIdx),
                        const SizedBox(height: 18),

                        // ── Amount Selector & Slider ───────────────────────
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                'TRANSFER AMOUNT',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.4,
                                  color: c.textMuted,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 3.5),
                              decoration: BoxDecoration(
                                color: c.aqua.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: c.aqua.withValues(alpha: 0.35),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                '${currency.symbol} ${amount.toStringAsFixed(0)}',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: c.aqua,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Preset chips
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: _presetAmounts.map((preset) {
                              final isSelected = amount == preset;
                              return Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: GestureDetector(
                                  onTap: () =>
                                      FxDisplayPreferences.setAmount(preset),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 180),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? c.aqua.withValues(alpha: 0.2)
                                          : c.cardDark,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: isSelected ? c.aqua : c.border,
                                        width: isSelected ? 1.4 : 1,
                                      ),
                                    ),
                                    child: Text(
                                      '${currency.symbol}${preset.toStringAsFixed(0)}',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: isSelected
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                        color: isSelected
                                            ? c.aqua
                                            : c.textSecondary,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Interactive Amount Slider
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 3,
                            thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 8),
                            overlayShape: const RoundSliderOverlayShape(
                                overlayRadius: 16),
                            activeTrackColor: c.aqua,
                            inactiveTrackColor: c.border,
                            thumbColor: c.aqua,
                            overlayColor: c.aqua.withValues(alpha: 0.15),
                          ),
                          child: Slider(
                            value: amount,
                            min: 50.0,
                            max: 5000.0,
                            divisions: 99,
                            onChanged: (val) {
                              FxDisplayPreferences.setAmount(val);
                            },
                          ),
                        ),
                        const SizedBox(height: 14),

                        // ── Guaranteed Net Payout Breakdown Box ────────────
                        _buildPayoutCard(
                          c: c,
                          currency: currency,
                          amount: amount,
                          feeAmount: feeAmount,
                          netPkr: netPkr,
                          isDark: isDark,
                        ),
                        const SizedBox(height: 16),

                        // CTA Button: Create Payment
                        SpongyTap(
                          onTap: () {
                            context.go('/app/payments/new');
                          },
                          pressScale: 0.97,
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 12),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [c.aqua, c.emerald],
                              ),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: c.aqua.withValues(alpha: 0.28),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.add_circle_outline_rounded,
                                    size: 16,
                                    color: Color(0xFF021B19),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Send ${currency.symbol}${amount.toStringAsFixed(0)} with Guaranteed Rate',
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.2,
                                      color: Color(0xFF021B19),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 22),

                        // Divider
                        Divider(color: c.border, height: 1),
                        const SizedBox(height: 18),

                        // ── Financial Display & Privacy Preferences ────────
                        Text(
                          'FINANCIAL DISPLAY & PRIVACY',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.4,
                            color: c.textMuted,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Stealth Balance Privacy Mode
                        _buildSwitchTile(
                          c: c,
                          icon: isStealth
                              ? Icons.visibility_off_rounded
                              : Icons.visibility_rounded,
                          title: 'Stealth Privacy Mode',
                          subtitle:
                              'Hide balance totals on Dashboard until tapped.',
                          value: isStealth,
                          onToggle: () =>
                              FxDisplayPreferences.toggleStealthMode(),
                        ),
                        const SizedBox(height: 10),

                        // Compact Numbers Mode
                        _buildSwitchTile(
                          c: c,
                          icon: Icons.compress_rounded,
                          title: 'Compact Currency Notation',
                          subtitle:
                              'Display amounts as Rs. 1.17M instead of full precision.',
                          value: isCompact,
                          onToggle: () =>
                              FxDisplayPreferences.toggleCompactFormat(),
                        ),
                        const SizedBox(height: 16),

                        // Live Privacy Preview Card
                        _buildLivePreviewCard(c, isStealth, isCompact),
                        const SizedBox(height: 14),

                        // Reset to defaults
                        Align(
                          alignment: Alignment.centerRight,
                          child: GestureDetector(
                            onTap: () => FxDisplayPreferences.resetToDefault(),
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
                      ],
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  // ── Currency Row ─────────────────────────────────────────────────────────
  Widget _buildCurrencyRow(PaidiXColorScheme c, int selectedIdx) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: FxDisplayPreferences.supportedCurrencies
            .asMap()
            .entries
            .map((entry) {
          final idx = entry.key;
          final curr = entry.value;
          final isSelected = idx == selectedIdx;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => FxDisplayPreferences.setCurrencyIndex(idx),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? c.aqua.withValues(alpha: 0.14)
                      : c.cardDark,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected ? c.aqua : c.border,
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          curr.code,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: isSelected ? c.aqua : c.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: curr.isPositiveTrend
                                ? c.emerald.withValues(alpha: 0.15)
                                : Colors.red.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            curr.trendPercent,
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: curr.isPositiveTrend
                                  ? c.emerald
                                  : Colors.redAccent,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Rs. ${curr.rateToPkr.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w500,
                        color: isSelected
                            ? c.aqua.withValues(alpha: 0.85)
                            : c.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Guaranteed Net Payout Breakdown Box ──────────────────────────────────
  Widget _buildPayoutCard({
    required PaidiXColorScheme c,
    required FxCurrency currency,
    required double amount,
    required double feeAmount,
    required double netPkr,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF04211E) : c.cardDark,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: c.aqua.withValues(alpha: 0.35),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: c.aqua.withValues(alpha: 0.10),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Gross + Rate
          _buildSummaryLine(
            c: c,
            label: 'Gross Transfer',
            value: '${currency.symbol} ${amount.toStringAsFixed(2)} ${currency.code}',
          ),
          const SizedBox(height: 6),
          _buildSummaryLine(
            c: c,
            label: 'Interbank Rate',
            value: '1 ${currency.code} = ${currency.rateToPkr.toStringAsFixed(2)} PKR',
          ),
          const SizedBox(height: 6),
          _buildSummaryLine(
            c: c,
            label: 'PaidiX Fee (12%)',
            value: '- ${currency.symbol} ${feeAmount.toStringAsFixed(2)}',
            valueColor: Colors.amber,
          ),
          const SizedBox(height: 8),
          Divider(color: c.border, height: 1),
          const SizedBox(height: 8),

          // Row 2: Net Deposited
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 6,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'ESTIMATED NET BANK PAYOUT',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                      color: c.gold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatPkr(netPkr),
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: c.emerald,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 7, vertical: 3.5),
                decoration: BoxDecoration(
                  color: c.emerald.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: c.emerald.withValues(alpha: 0.4),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.bolt_rounded,
                      size: 13,
                      color: c.emerald,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '1-LINK Fast',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: c.emerald,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryLine({
    required PaidiXColorScheme c,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w400,
              color: c.textSecondary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: valueColor ?? c.textPrimary,
          ),
        ),
      ],
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
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
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: value
                    ? c.aqua.withValues(alpha: 0.16)
                    : c.card,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                size: 15,
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
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: c.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 10,
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
              width: 36,
              height: 20,
              padding: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: value ? c.aqua : c.borderSubtle,
              ),
              alignment:
                  value ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                width: 16,
                height: 16,
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
    final previewValue = isStealth
        ? 'Rs. ••••••••••'
        : (isCompact ? 'Rs. 1.17M' : 'Rs. 1,169,570.67');

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.cardDark,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.border, width: 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'LIVE PREVIEW',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                    color: c.textMuted,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  previewValue,
                  style: TextStyle(
                    fontSize: 13.5,
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
              color: isStealth
                  ? Colors.amber.withValues(alpha: 0.15)
                  : c.aqua.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              isStealth ? 'Stealth Active' : 'Normal Display',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: isStealth ? Colors.amber : c.aqua,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatPkr(double amount) {
    final intPart = amount.floor();
    final str = intPart.toString();
    final buffer = StringBuffer();
    int count = 0;
    for (int i = str.length - 1; i >= 0; i--) {
      buffer.write(str[i]);
      count++;
      if (count % 3 == 0 && i != 0) {
        buffer.write(',');
      }
    }
    final formatted = buffer.toString().split('').reversed.join('');
    return 'Rs. $formatted.00';
  }
}
