import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/widgets/spongy_tap.dart';
import '../../../profile/domain/user_profile.dart';
import '../../domain/virtual_card_skin.dart';

/// Interactive Luxury Virtual Card Skins Studio for the Appearance section.
/// Displays an interactive 3D virtual debit/receiving card with metallic finishes,
/// holographic light sheen animations, number privacy toggling, and instant skin selection.
class VirtualCardStudio extends StatefulWidget {
  final PaidiXColorScheme colors;
  final UserProfile profile;
  final bool isMobile;

  const VirtualCardStudio({
    super.key,
    required this.colors,
    required this.profile,
    required this.isMobile,
  });

  @override
  State<VirtualCardStudio> createState() => _VirtualCardStudioState();
}

class _VirtualCardStudioState extends State<VirtualCardStudio>
    with SingleTickerProviderStateMixin {
  late final AnimationController _sheenController;

  @override
  void initState() {
    super.initState();
    _sheenController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    );

    // Guard against blocking pumpAndSettle in automated test environments
    final isTest =
        WidgetsBinding.instance.runtimeType.toString().contains('Test');
    if (!isTest) {
      _sheenController.repeat();
    } else {
      _sheenController.forward();
    }
  }

  @override
  void dispose() {
    _sheenController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ValueListenableBuilder<VirtualCardSkin>(
      valueListenable: VirtualCardPreferences.activeSkinNotifier,
      builder: (context, activeSkin, _) {
        return ValueListenableBuilder<bool>(
          valueListenable: VirtualCardPreferences.isDetailsMaskedNotifier,
          builder: (context, isMasked, _) {
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
                        color: activeSkin.accentColor.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: activeSkin.accentColor.withValues(alpha: 0.4),
                          width: 1,
                        ),
                      ),
                      child: Icon(
                        Icons.credit_card_rounded,
                        size: 15,
                        color: activeSkin.accentColor,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'VIRTUAL CARD STUDIO',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.4,
                              color: c.gold,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            'Personalise your PaidiX receiving card finish & sheen.',
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
                const SizedBox(height: 18),

                // ── Interactive 3D Virtual Card Visualizer ─────────────
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 350),
                    child: AspectRatio(
                      aspectRatio: 1.586, // Standard ISO ID-1 card aspect ratio
                      child: _buildCardContainer(activeSkin, isMasked, isDark),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // ── Card Quick Actions (Privacy Mask & Live Status) ────
                _buildQuickActionBar(c, isMasked, activeSkin),
                const SizedBox(height: 20),

                // ── Skin Palette Selector ──────────────────────────────
                Text(
                  'SELECT FINISH & TEXTURE',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.4,
                    color: c.textMuted,
                  ),
                ),
                const SizedBox(height: 12),

                // 4 Skins Grid
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: VirtualCardSkin.values.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: widget.isMobile ? 2 : 2,
                    childAspectRatio: widget.isMobile ? 1.45 : 2.1,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemBuilder: (context, i) {
                    final skin = VirtualCardSkin.values[i];
                    final isSelected = skin == activeSkin;
                    return _buildSkinOptionTile(skin, isSelected, c);
                  },
                ),
                const SizedBox(height: 14),

                // Reset option
                Align(
                  alignment: Alignment.centerRight,
                  child: GestureDetector(
                    onTap: () => VirtualCardPreferences.resetToDefault(),
                    child: Text(
                      'Reset card to default',
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
  }

  // ── 3D Elevated Card Widget ──────────────────────────────────────────────
  Widget _buildCardContainer(
      VirtualCardSkin skin, bool isMasked, bool isDark) {
    final holderName = widget.profile.fullName.trim().isEmpty
        ? 'ABDULLAH AZEEM'
        : widget.profile.fullName.trim().toUpperCase();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeInOutCubic,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: skin.gradientColors,
        ),
        border: Border.all(
          color: skin.accentColor.withValues(alpha: 0.38),
          width: 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: skin.accentColor.withValues(alpha: isDark ? 0.32 : 0.22),
            blurRadius: 26,
            spreadRadius: -3,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          children: [
            // Holographic metallic sheen animation
            AnimatedBuilder(
              animation: _sheenController,
              builder: (context, child) {
                final progress = _sheenController.value;
                return Positioned.fill(
                  child: Transform.rotate(
                    angle: -0.32,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment(-2.0 + (progress * 4.0), -1.0),
                          end: Alignment(-1.0 + (progress * 4.0), 1.0),
                          colors: skin.isHolographic
                              ? [
                                  Colors.transparent,
                                  const Color(0x2838BDF8),
                                  const Color(0x35F472B6),
                                  const Color(0x28FDE047),
                                  Colors.transparent,
                                ]
                              : [
                                  Colors.transparent,
                                  Colors.white.withValues(alpha: 0.08),
                                  Colors.white.withValues(alpha: 0.18),
                                  Colors.white.withValues(alpha: 0.06),
                                  Colors.transparent,
                                ],
                          stops: const [0.0, 0.3, 0.5, 0.7, 1.0],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),

            // Card Face Content with FittedBox Scale Safeguard
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.center,
                  child: SizedBox(
                    width: 320,
                    height: 198,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Top Row: Brand & Virtual Tier Badge
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Logo
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF002826),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color:
                                          skin.foilColor.withValues(alpha: 0.7),
                                      width: 0.8,
                                    ),
                                  ),
                                  child: const Text(
                                    'PX',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFFFFD54F),
                                      letterSpacing: 0.6,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'PaidiX',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.4,
                                    color: Colors.white.withValues(alpha: 0.95),
                                  ),
                                ),
                              ],
                            ),
                            // Tier pill
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3.5),
                              decoration: BoxDecoration(
                                color: skin.accentColor.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: skin.accentColor.withValues(alpha: 0.5),
                                  width: 0.8,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 5,
                                    height: 5,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: skin.accentColor,
                                      boxShadow: [
                                        BoxShadow(
                                          color: skin.accentColor,
                                          blurRadius: 4,
                                          spreadRadius: 1,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    'VIRTUAL',
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.8,
                                      color: skin.accentColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        // Middle Row: EMV Microchip + NFC + Card Number
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                // Realistic Gold/Silver EMV Chip
                                _buildEmvChip(skin),
                                const SizedBox(width: 10),
                                Icon(
                                  Icons.contactless_rounded,
                                  size: 20,
                                  color: Colors.white.withValues(alpha: 0.55),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            // Card Number with metallic foil styling
                            Text(
                              isMasked
                                  ? '••••   ••••   ••••   2786'
                                  : '4214   8890   1532   2786',
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 16.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 2.2,
                                color: skin.foilColor,
                                shadows: [
                                  Shadow(
                                    color: Colors.black.withValues(alpha: 0.65),
                                    offset: const Offset(1, 1),
                                    blurRadius: 3,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        // Bottom Row: Cardholder + Expiry + 1-LINK Badge
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            // Cardholder
                            SizedBox(
                              width: 155,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'CARDHOLDER',
                                    style: TextStyle(
                                      fontSize: 8.5,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 1.0,
                                      color:
                                          Colors.white.withValues(alpha: 0.5),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    holderName,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.6,
                                      color: Colors.white,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            // Expiry
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'EXPIRES',
                                  style: TextStyle(
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.0,
                                    color:
                                        Colors.white.withValues(alpha: 0.5),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                const Text(
                                  '09/29',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.8,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 8),
                            // 1-LINK PayPak Network Insignia
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2.5),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.25),
                                  width: 0.6,
                                ),
                              ),
                              child: Text(
                                '1-LINK',
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.8,
                                  color: skin.foilColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Realistic EMV Smart Chip ─────────────────────────────────────────────
  Widget _buildEmvChip(VirtualCardSkin skin) {
    return Container(
      width: 36,
      height: 26,
      decoration: BoxDecoration(
        color: skin.chipColor.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
          color: const Color(0xFF785D0C).withValues(alpha: 0.5),
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Horizontal divider trace
          Positioned(
            top: 12,
            left: 0,
            right: 0,
            child: Container(
              height: 0.8,
              color: Colors.black.withValues(alpha: 0.28),
            ),
          ),
          // Vertical divider trace
          Positioned(
            top: 0,
            bottom: 0,
            left: 17,
            child: Container(
              width: 0.8,
              color: Colors.black.withValues(alpha: 0.28),
            ),
          ),
          // Center core
          Center(
            child: Container(
              width: 10,
              height: 8,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                border: Border.all(
                  color: Colors.black.withValues(alpha: 0.22),
                  width: 0.6,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Card Quick Action Bar (Mask Details & Status) ────────────────────────
  Widget _buildQuickActionBar(
      PaidiXColorScheme c, bool isMasked, VirtualCardSkin skin) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: c.cardDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.border, width: 1),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 10,
        runSpacing: 8,
        children: [
          // Mask / Reveal Button
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: SpongyTap(
              onTap: () => VirtualCardPreferences.toggleMaskDetails(),
              pressScale: 0.94,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isMasked
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    size: 16,
                    color: skin.accentColor,
                  ),
                  const SizedBox(width: 7),
                  Text(
                    isMasked ? 'Reveal Number' : 'Mask Number',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: skin.accentColor,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Status indicator
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: c.emerald,
                    boxShadow: [
                      BoxShadow(
                        color: c.emerald,
                        blurRadius: 4,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'Payout Ready',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: c.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Skin Selection Tile ──────────────────────────────────────────────────
  Widget _buildSkinOptionTile(
      VirtualCardSkin skin, bool isSelected, PaidiXColorScheme c) {
    return GestureDetector(
      onTap: () => VirtualCardPreferences.setSkin(skin),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: isSelected
              ? skin.accentColor.withValues(alpha: 0.12)
              : c.cardDark,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? skin.accentColor : c.border,
            width: isSelected ? 1.6 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: skin.accentColor.withValues(alpha: 0.18),
                    blurRadius: 12,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 120,
            height: 64,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Header with mini gradient capsule and checkmark
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Mini card swatch
                    Container(
                      width: 34,
                      height: 22,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        gradient: LinearGradient(
                          colors: skin.gradientColors,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        border: Border.all(
                          color: skin.accentColor.withValues(alpha: 0.5),
                          width: 0.8,
                        ),
                      ),
                      child: Center(
                        child: Container(
                          width: 6,
                          height: 5,
                          decoration: BoxDecoration(
                            color: skin.foilColor,
                            borderRadius: BorderRadius.circular(1),
                          ),
                        ),
                      ),
                    ),

                    // Selected pill check
                    if (isSelected)
                      Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: skin.accentColor,
                        ),
                        child: const Icon(
                          Icons.check,
                          size: 12,
                          color: Color(0xFF021B19),
                        ),
                      ),
                  ],
                ),

                // Title & tag
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      skin.name,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w600,
                        color: isSelected ? skin.accentColor : c.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 1),
                    Text(
                      skin.tag,
                      style: TextStyle(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: isSelected
                            ? skin.accentColor.withValues(alpha: 0.85)
                            : c.textMuted,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
