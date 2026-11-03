import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'app_colors.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

class AppTheme {
  AppTheme._();

  static bool _fontsConfigured = false;

  static void ensureFontsConfigured() {
    if (_fontsConfigured) return;
    _fontsConfigured = true;
    try {
      if (!kIsWeb && Platform.environment.containsKey('FLUTTER_TEST')) {
        GoogleFonts.config.allowRuntimeFetching = false;
      }
    } catch (_) {}
  }

  /// Global reactive theme mode notifier (default: Light theme matching preference).
  static final ValueNotifier<ThemeMode> themeModeNotifier =
      ValueNotifier<ThemeMode>(ThemeMode.light);

  /// Global reactive font family notifier (default: System default).
  static final ValueNotifier<String> fontFamilyNotifier =
      ValueNotifier<String>('System default');

  /// Global reactive text scale notifier (default: 1.0 = 100%).
  static final ValueNotifier<double> textScaleNotifier =
      ValueNotifier<double>(1.0);

  static ThemeMode get currentThemeMode => themeModeNotifier.value;
  static String get currentFontFamily => fontFamilyNotifier.value;
  static double get currentTextScale => textScaleNotifier.value;

  static bool _initialized = false;

  /// Initializes appearance state and restores saved preferences from disk
  static void init() {
    ensureFontsConfigured();
    if (_initialized) return;
    _initialized = true;
    _loadPreferences();
  }

  static Future<void> _loadPreferences() async {
    if (kIsWeb) return;
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final file = File('${appDir.path}/paidix_appearance.json');
      if (file.existsSync()) {
        final content = await file.readAsString();
        final map = jsonDecode(content) as Map<String, dynamic>;
        if (map['font'] != null && map['font'] is String) {
          final font = map['font'] as String;
          if (availableFonts.contains(font)) {
            fontFamilyNotifier.value = font;
          }
        }
        if (map['scale'] != null && map['scale'] is num) {
          final scale = (map['scale'] as num).toDouble();
          textScaleNotifier.value = scale.clamp(0.8, 1.4);
        }
        if (map['theme'] != null && map['theme'] is String) {
          final t = map['theme'] as String;
          if (t == 'light') {
            themeModeNotifier.value = ThemeMode.light;
          } else if (t == 'dark') {
            themeModeNotifier.value = ThemeMode.dark;
          } else if (t == 'system') {
            themeModeNotifier.value = ThemeMode.system;
          }
        }
      }
    } catch (_) {}
  }

  static Future<void> _savePreferences() async {
    if (kIsWeb) return;
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final file = File('${appDir.path}/paidix_appearance.json');
      final map = {
        'font': fontFamilyNotifier.value,
        'scale': textScaleNotifier.value,
        'theme': themeModeNotifier.value.name,
      };
      await file.writeAsString(jsonEncode(map), flush: true);
    } catch (_) {}
  }

  /// Supported Typography Fonts
  static const List<String> availableFonts = [
    'System default',
    'Inter',
    'Roboto',
    'Poppins',
    'Lato',
    'Nunito',
    'Open Sans',
    'DM Sans',
    'Source Sans 3',
    'IBM Plex Sans',
  ];

  /// Toggles between Dark and Light mode.
  static void toggleTheme() {
    final next = themeModeNotifier.value == ThemeMode.dark
        ? ThemeMode.light
        : ThemeMode.dark;
    setThemeMode(next);
  }

  /// Explicitly sets the desired [ThemeMode].
  static void setThemeMode(ThemeMode mode) {
    themeModeNotifier.value = mode;
    _savePreferences();
  }

  /// Explicitly sets the desired font family across all app typography.
  static void setFontFamily(String fontName) {
    fontFamilyNotifier.value = fontName;
    _savePreferences();
  }

  /// Explicitly sets the desired text scale factor (0.80 to 1.40).
  static void setTextScale(double scale) {
    textScaleNotifier.value = scale.clamp(0.8, 1.4);
    _savePreferences();
  }

  /// Returns whether the provided context is currently rendering dark mode.
  static bool isDark(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark;
  }

  /// Resolves a [TextStyle] for the specified font name.
  static TextStyle getFontStyle(String fontName, {TextStyle? baseStyle}) {
    ensureFontsConfigured();
    final style = baseStyle ?? const TextStyle();
    if (fontName == 'System default' || fontName.isEmpty) {
      return style;
    }
    try {
      switch (fontName) {
        case 'Inter':
          return GoogleFonts.inter(textStyle: style);
        case 'Roboto':
          return GoogleFonts.roboto(textStyle: style);
        case 'Poppins':
          return GoogleFonts.poppins(textStyle: style);
        case 'Lato':
          return GoogleFonts.lato(textStyle: style);
        case 'Nunito':
          return GoogleFonts.nunito(textStyle: style);
        case 'Open Sans':
          return GoogleFonts.openSans(textStyle: style);
        case 'DM Sans':
          return GoogleFonts.dmSans(textStyle: style);
        case 'Source Sans 3':
          return GoogleFonts.sourceSans3(textStyle: style);
        case 'IBM Plex Sans':
          return GoogleFonts.ibmPlexSans(textStyle: style);
        default:
          return style;
      }
    } catch (_) {
      return style;
    }
  }

  /// Resolves the raw font family name string for font inheritance.
  static String? fontFamilyOrNull(String fontName) {
    ensureFontsConfigured();
    if (fontName == 'System default' || fontName.isEmpty) return null;
    try {
      return getFontStyle(fontName).fontFamily;
    } catch (_) {
      return null;
    }
  }

  /// Returns active font family string for current selection.
  static String? get activeFontFamily => fontFamilyOrNull(currentFontFamily);

  /// Dark Theme (html.dark)
  static ThemeData get darkTheme => getDarkTheme(currentFontFamily);

  /// Light Theme (:root)
  static ThemeData get lightTheme => getLightTheme(currentFontFamily);

  /// Builds Dark Theme styled with the given [font].
  static ThemeData getDarkTheme([String? font]) {
    final fontName = font ?? currentFontFamily;
    const colors = AppColors.dark;
    final fontFam = fontFamilyOrNull(fontName);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: fontFam,
      scaffoldBackgroundColor: colors.background,
      colorScheme: ColorScheme.dark(
        primary: colors.aqua,
        onPrimary: colors.background,
        secondary: colors.aquaLight,
        onSecondary: colors.background,
        surface: colors.card,
        onSurface: colors.textPrimary,
        error: colors.borderError,
        onError: Colors.white,
      ),
      dividerColor: colors.divider,
      dividerTheme: DividerThemeData(
        color: colors.divider,
        thickness: 1,
        space: 1,
      ),
      extensions: const [
        PaidiXColorsExtension(colors),
      ],
      cardTheme: CardThemeData(
        color: colors.card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: AppSpacing.radiusLg,
          side: BorderSide(color: colors.border, width: 1.2),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.inputFill,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: AppTypography.inputPlaceholder,
        labelStyle: AppTypography.label,
        enabledBorder: OutlineInputBorder(
          borderRadius: AppSpacing.radiusMd,
          borderSide: BorderSide(color: colors.border, width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppSpacing.radiusMd,
          borderSide: BorderSide(color: colors.borderFocused, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppSpacing.radiusMd,
          borderSide: BorderSide(color: colors.borderError, width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppSpacing.radiusMd,
          borderSide: BorderSide(color: colors.borderError, width: 1.5),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: colors.cardDark,
        contentTextStyle: TextStyle(color: colors.textPrimary),
        shape: RoundedRectangleBorder(
          borderRadius: AppSpacing.radiusMd,
          side: BorderSide(color: colors.border, width: 1),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Builds Light Theme styled with the given [font].
  static ThemeData getLightTheme([String? font]) {
    final fontName = font ?? currentFontFamily;
    const colors = AppColors.light;
    final fontFam = fontFamilyOrNull(fontName);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: fontFam,
      scaffoldBackgroundColor: colors.background,
      colorScheme: ColorScheme.light(
        primary: colors.aqua,
        onPrimary: Colors.white,
        secondary: colors.aquaLight,
        onSecondary: Colors.white,
        surface: colors.card,
        onSurface: colors.textPrimary,
        error: colors.borderError,
        onError: Colors.white,
      ),
      dividerColor: colors.divider,
      dividerTheme: DividerThemeData(
        color: colors.divider,
        thickness: 1,
        space: 1,
      ),
      extensions: const [
        PaidiXColorsExtension(colors),
      ],
      cardTheme: CardThemeData(
        color: colors.card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: AppSpacing.radiusLg,
          side: BorderSide(color: colors.border, width: 1.2),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.inputFill,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: AppTypography.inputPlaceholder,
        labelStyle: AppTypography.label,
        enabledBorder: OutlineInputBorder(
          borderRadius: AppSpacing.radiusMd,
          borderSide: BorderSide(color: colors.border, width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppSpacing.radiusMd,
          borderSide: BorderSide(color: colors.borderFocused, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppSpacing.radiusMd,
          borderSide: BorderSide(color: colors.borderError, width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppSpacing.radiusMd,
          borderSide: BorderSide(color: colors.borderError, width: 1.5),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: colors.card,
        contentTextStyle: TextStyle(color: colors.textPrimary),
        shape: RoundedRectangleBorder(
          borderRadius: AppSpacing.radiusMd,
          side: BorderSide(color: colors.border, width: 1),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
