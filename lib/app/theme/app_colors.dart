import 'package:flutter/material.dart';
import 'app_theme.dart';

/// Semantic design tokens for PaidiX extracted directly from the Tailwind
/// design system (:root for light mode, html.dark for dark mode).
class PaidiXColorScheme {
  final Brightness brightness;

  // Backgrounds & Surfaces
  final Color background;
  final Color card;
  final Color cardDark;
  final Color cardHighlight;
  final Color inputFill;

  // Borders & Dividers
  final Color border;
  final Color borderSubtle;
  final Color borderFocused;
  final Color borderError;
  final Color divider;

  // Typography (Inverted semantically in dark mode)
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color textLabel;
  final Color textPlaceholder;

  // Brand Scale & Buttons
  final Color primaryButton;
  final Color primaryButtonHover;
  final Color primaryButtonText;
  final Color aqua;
  final Color aquaLight;
  final Color aquaDark;

  // Accents
  final Color gold;
  final Color goldMuted;

  // Hero Card (Customer score)
  final Color mintHero;
  final Color mintHeroSubtle;
  final Color mintHeroText;

  // Status Badges
  final Color statusCompletedBg;
  final Color statusCompletedText;
  final Color statusCompletedDot;

  final Color statusPendingBg;
  final Color statusPendingText;
  final Color statusPendingDot;

  final Color statusAwaitingBg;
  final Color statusAwaitingText;
  final Color statusAwaitingDot;

  final Color statusErrorBg;
  final Color statusErrorText;
  final Color statusErrorDot;

  const PaidiXColorScheme({
    required this.brightness,
    required this.background,
    required this.card,
    required this.cardDark,
    required this.cardHighlight,
    required this.inputFill,
    required this.border,
    required this.borderSubtle,
    required this.borderFocused,
    required this.borderError,
    required this.divider,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.textLabel,
    required this.textPlaceholder,
    required this.primaryButton,
    required this.primaryButtonHover,
    required this.primaryButtonText,
    required this.aqua,
    required this.aquaLight,
    required this.aquaDark,
    required this.gold,
    required this.goldMuted,
    required this.mintHero,
    required this.mintHeroSubtle,
    required this.mintHeroText,
    required this.statusCompletedBg,
    required this.statusCompletedText,
    required this.statusCompletedDot,
    required this.statusPendingBg,
    required this.statusPendingText,
    required this.statusPendingDot,
    required this.statusAwaitingBg,
    required this.statusAwaitingText,
    required this.statusAwaitingDot,
    required this.statusErrorBg,
    required this.statusErrorText,
    required this.statusErrorDot,
  });

  // Ergonomic convenience getters
  Color get emerald => statusCompletedDot;
  Color get ruby => borderError;
  Color get inputBackground => inputFill;
  Color get brand800 => aquaDark;
  Color get brand900 => primaryButton;
}

/// ThemeExtension allowing access to PaidiXColorScheme via Theme.of(context)
class PaidiXColorsExtension extends ThemeExtension<PaidiXColorsExtension> {
  final PaidiXColorScheme colors;

  const PaidiXColorsExtension(this.colors);

  @override
  ThemeExtension<PaidiXColorsExtension> copyWith({PaidiXColorScheme? colors}) {
    return PaidiXColorsExtension(colors ?? this.colors);
  }

  @override
  ThemeExtension<PaidiXColorsExtension> lerp(
    covariant ThemeExtension<PaidiXColorsExtension>? other,
    double t,
  ) {
    if (other is! PaidiXColorsExtension) return this;
    // Standard switch on midpoint for discrete palettes
    return t < 0.5 ? this : other;
  }
}

/// Central color access for PaidiX. Provides:
/// 1. [AppColors.of(context)] for theme-reactive colors in any widget.
/// 2. [AppColors.light] & [AppColors.dark] for exact token definitions.
/// 3. Static getters delegating to active theme mode for complete backward compatibility.
/// 4. Fixed sidebar constants that never invert across both themes.
class AppColors {
  AppColors._();

  // ===================================================================
  //  SIDEBAR — FIXED deep-teal identity in BOTH themes (never inverts).
  //  As specified in design tokens: "--c-sidebar: 2 47 50 (#022F32 base)"
  // ===================================================================
  static const Color sidebar = Color(0xFF022F32);
  static const Color sidebarHover = Color(0xFF053B3E);
  static const Color sidebarLine = Color(0xFF0C4649);
  static const Color sidebarText = Color(0xFFC8DAD6);
  static const Color sidebarMuted = Color(0xFF7FA39E);
  static const Color sidebarActive = Color(0xFF56A240);
  static const Color activeNavBg = Color(0xFF0F4134);
  static const Color activeNavIndicator = Color(0xFFE5B35A);

  // ===================================================================
  //  LIGHT THEME COLOR SCHEME (:root)
  //  --c-cream: 239 243 240 (#EFF3F0), --c-paper: 255 255 255 (#FFFFFF)
  // ===================================================================
  static const PaidiXColorScheme light = PaidiXColorScheme(
    brightness: Brightness.light,
    background: Color(0xFFEFF3F0), // --c-cream: 239 243 240
    card: Color(0xFFFFFFFF),       // --c-paper: 255 255 255
    cardDark: Color(0xFFF7F9F8),   // --c-ink-50: 247 249 248 (sunken panel)
    cardHighlight: Color(0xFFE6F0EF), // --c-brand-50: 230 240 239
    inputFill: Color(0xFFFFFFFF),   // clean white input
    border: Color(0xFFE4EAE5),     // --c-ink-100: 228 234 229
    borderSubtle: Color(0xFFBECAC5), // --c-ink-200: 190 202 197
    borderFocused: Color(0xFF0E7C7B), // --c-brand-500: 14 124 123
    borderError: Color(0xFFC0475F),   // --c-accent-ruby: 192 71 95
    divider: Color(0xFFE4EAE5),       // --c-ink-100
    textPrimary: Color(0xFF0A1B19),   // --c-ink-900: 10 27 25
    textSecondary: Color(0xFF384C48), // --c-ink-600: 56 76 72
    textMuted: Color(0xFF4E625E),     // --c-ink-500: 78 98 94
    textLabel: Color(0xFF4E625E),     // --c-ink-500
    textPlaceholder: Color(0xFF627672), // --c-ink-400: 98 118 114
    primaryButton: Color(0xFF022F32), // --c-brand-900: 2 47 50
    primaryButtonHover: Color(0xFF043A3C), // --c-brand-800
    primaryButtonText: Color(0xFFFFFFFF),  // white text on brand-900
    aqua: Color(0xFF0E7C7B),          // --c-brand-500: 14 124 123
    aquaLight: Color(0xFF399493),     // --c-brand-400: 57 148 147
    aquaDark: Color(0xFF022F32),      // --c-brand-900
    gold: Color(0xFFE5B35A),          // --c-accent-gold: 229 179 90
    goldMuted: Color(0x2EE5B35A),     // gold with alpha
    mintHero: Color(0xFFC6DEDC),      // --c-brand-100 hero banner
    mintHeroSubtle: Color(0xFF9DC7C4),// --c-brand-200 decorative ring
    mintHeroText: Color(0xFF022F32),  // deep teal text on mint
    statusCompletedBg: Color(0x2456A240), // --c-accent-green / 0.14
    statusCompletedText: Color(0xFF3B6D2B), // rgb(59 109 43)
    statusCompletedDot: Color(0xFF56A240),
    statusPendingBg: Color(0x2EE5B35A),   // --c-accent-gold / 0.18
    statusPendingText: Color(0xFF855F14), // rgb(133 95 20)
    statusPendingDot: Color(0xFFE5B35A),
    statusAwaitingBg: Color(0x248667CF),  // --c-accent-violet / 0.14
    statusAwaitingText: Color(0xFF533E8D),// rgb(83 62 141)
    statusAwaitingDot: Color(0xFF8667CF),
    statusErrorBg: Color(0x1FC0475F),     // --c-accent-ruby / 0.12
    statusErrorText: Color(0xFFC0475F),
    statusErrorDot: Color(0xFFC0475F),
  );

  // ===================================================================
  //  DARK THEME COLOR SCHEME (html.dark)
  //  --c-cream: 3 20 21 (#031415), --c-paper: 10 49 52 (#0A3134)
  // ===================================================================
  static const PaidiXColorScheme dark = PaidiXColorScheme(
    brightness: Brightness.dark,
    background: Color(0xFF031415), // --c-cream: 3 20 21
    card: Color(0xFF0A3134),       // --c-paper: 10 49 52
    cardDark: Color(0xFF052123),   // --c-ink-50: 5 33 35 (sunken elements)
    cardHighlight: Color(0xFF0E3D41), // raised card highlight
    inputFill: Color(0xFF052123),   // deep sunken surface
    border: Color(0xFF144245),     // --c-ink-100: 20 66 69
    borderSubtle: Color(0xFF123C3F), // --c-ink-200: 18 60 63
    borderFocused: Color(0xFF5FCFC9), // --c-brand-500: 95 207 201
    borderError: Color(0xFFE0788C),   // --c-accent-ruby: 224 120 140
    divider: Color(0xFF144245),       // --c-ink-100
    textPrimary: Color(0xFFEAF2F0),   // --c-ink-900: 234 242 240
    textSecondary: Color(0xFFC4D4D0), // --c-ink-600: 196 212 208
    textMuted: Color(0xFF8CA3A0),     // --c-ink-500: 140 163 160
    textLabel: Color(0xFF8CA3A0),     // --c-ink-500
    textPlaceholder: Color(0xFF5E7572), // --c-ink-400: 94 117 114
    primaryButton: Color(0xFF085656), // --c-brand-200: 8 86 86
    primaryButtonHover: Color(0xFF2A9996), // --c-brand-300
    primaryButtonText: Color(0xFFEAF2F0),  // --c-ink-900
    aqua: Color(0xFF5FCFC9),          // --c-brand-500: 95 207 201
    aquaLight: Color(0xFF95DFDB),     // --c-brand-700: 149 223 219
    aquaDark: Color(0xFF085656),      // --c-brand-200
    gold: Color(0xFFEFC479),          // --c-accent-gold: 239 196 121
    goldMuted: Color(0x33EFC479),     // gold with alpha
    mintHero: Color(0xFF95DFDB),      // --c-brand-700 signature mint banner
    mintHeroSubtle: Color(0xFF78B6B3),// ring shade
    mintHeroText: Color(0xFF041516),  // crisp dark text on mint
    statusCompletedBg: Color(0x2E74C05F), // html.dark .badge-ok (0.18)
    statusCompletedText: Color(0xFF8CCD78),// rgb(140 205 120)
    statusCompletedDot: Color(0xFF74C05F),
    statusPendingBg: Color(0x2EEFC479),   // html.dark .badge-warn (0.18)
    statusPendingText: Color(0xFFEFC479),
    statusPendingDot: Color(0xFFEFC479),
    statusAwaitingBg: Color(0x33A088DB),  // html.dark .badge-info (0.20)
    statusAwaitingText: Color(0xFFB8A5E6),// rgb(184 165 230)
    statusAwaitingDot: Color(0xFFA088DB),
    statusErrorBg: Color(0x2EE0788C),     // html.dark .badge-err (0.18)
    statusErrorText: Color(0xFFE0788C),
    statusErrorDot: Color(0xFFE0788C),
  );

  // ===================================================================
  //  THEME LOOKUP & ADAPTIVE GETTERS
  // ===================================================================

  /// Retrieves the active [PaidiXColorScheme] for the provided [BuildContext].
  static PaidiXColorScheme of(BuildContext context) {
    final ext = Theme.of(context).extension<PaidiXColorsExtension>();
    if (ext != null) return ext.colors;
    return Theme.of(context).brightness == Brightness.dark ? dark : light;
  }

  /// Global current scheme synchronized with [AppTheme.themeModeNotifier].
  static PaidiXColorScheme get current =>
      AppTheme.themeModeNotifier.value == ThemeMode.dark ? dark : light;

  // Adaptive getters delegating to active scheme
  static Color get background => current.background;
  static Color get card => current.card;
  static Color get cardDark => current.cardDark;
  static Color get cardHighlight => current.cardHighlight;
  static Color get inputFill => current.inputFill;

  static Color get border => current.border;
  static Color get borderSubtle => current.borderSubtle;
  static Color get borderFocused => current.borderFocused;
  static Color get borderError => current.borderError;
  static Color get divider => current.divider;

  static Color get textPrimary => current.textPrimary;
  static Color get textSecondary => current.textSecondary;
  static Color get textMuted => current.textMuted;
  static Color get textLabel => current.textLabel;
  static Color get textPlaceholder => current.textPlaceholder;

  static Color get primaryButton => current.primaryButton;
  static Color get primaryButtonHover => current.primaryButtonHover;
  static Color get primaryButtonText => current.primaryButtonText;
  static Color get aqua => current.aqua;
  static Color get aquaLight => current.aquaLight;
  static Color get aquaDark => current.aquaDark;

  static Color get gold => current.gold;
  static Color get goldMuted => current.goldMuted;

  static Color get mintHero => current.mintHero;
  static Color get mintHeroSubtle => current.mintHeroSubtle;
  static Color get mintHeroText => current.mintHeroText;

  static Color get statusCompletedBg => current.statusCompletedBg;
  static Color get statusCompletedText => current.statusCompletedText;
  static Color get statusCompletedDot => current.statusCompletedDot;

  static Color get emerald => current.emerald;
  static Color get ruby => current.ruby;
  static Color get inputBackground => current.inputBackground;
  static Color get brand800 => current.brand800;
  static Color get brand900 => current.brand900;

  static Color get statusPendingBg => current.statusPendingBg;
  static Color get statusPendingText => current.statusPendingText;
  static Color get statusPendingDot => current.statusPendingDot;

  static Color get statusAwaitingBg => current.statusAwaitingBg;
  static Color get statusAwaitingText => current.statusAwaitingText;
  static Color get statusAwaitingDot => current.statusAwaitingDot;

  static Color get statusErrorBg => current.statusErrorBg;
  static Color get statusErrorText => current.statusErrorText;
  static Color get statusErrorDot => current.statusErrorDot;
}
