import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import '../../../../core/utils/formatters.dart';

/// Reactive state manager & persistent storage for Financial Display & Privacy Preferences.
class FxDisplayPreferences {
  FxDisplayPreferences._();
  static final FxDisplayPreferences instance = FxDisplayPreferences._();

  // ── Reactive Notifiers ──────────────────────────────────────────────────
  static final ValueNotifier<bool> stealthModeNotifier =
      ValueNotifier<bool>(false);

  static final ValueNotifier<bool> compactFormatNotifier =
      ValueNotifier<bool>(false);

  /// Synchronized real-time state across Dashboard for unmasking / revealing hidden amounts.
  static final ValueNotifier<bool> dashboardBalanceRevealedNotifier =
      ValueNotifier<bool>(false);

  static bool get isStealthMode => stealthModeNotifier.value;
  static bool get isCompactFormat => compactFormatNotifier.value;
  static bool get isDashboardBalanceRevealed =>
      dashboardBalanceRevealedNotifier.value;

  static bool _isInitialized = false;

  /// Load persisted display preferences from device storage.
  static Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;
    try {
      final file = await _getPrefsFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        final Map<String, dynamic> data = jsonDecode(content);
        if (data.containsKey('stealth_mode')) {
          stealthModeNotifier.value = data['stealth_mode'] as bool? ?? false;
        }
        if (data.containsKey('compact_format')) {
          compactFormatNotifier.value =
              data['compact_format'] as bool? ?? false;
        }
      }
    } catch (_) {
      // Fallback cleanly to defaults
    }
  }

  /// Toggle Balance Stealth Privacy Mode with haptics.
  static void toggleStealthMode() {
    HapticFeedback.lightImpact();
    stealthModeNotifier.value = !stealthModeNotifier.value;
    dashboardBalanceRevealedNotifier.value = false;
    _persist();
  }

  /// Toggle Compact Number Notation with haptics.
  static void toggleCompactFormat() {
    HapticFeedback.lightImpact();
    compactFormatNotifier.value = !compactFormatNotifier.value;
    _persist();
  }

  /// Toggle temporary synchronized balance unmask / peek state across Dashboard.
  static void toggleDashboardBalanceRevealed() {
    HapticFeedback.lightImpact();
    dashboardBalanceRevealedNotifier.value =
        !dashboardBalanceRevealedNotifier.value;
  }

  /// Set temporary synchronized balance unmask / peek state across Dashboard.
  static void setDashboardBalanceRevealed(bool revealed) {
    dashboardBalanceRevealedNotifier.value = revealed;
  }

  /// Reset all display preferences to defaults.
  static void resetToDefault() {
    HapticFeedback.selectionClick();
    stealthModeNotifier.value = false;
    compactFormatNotifier.value = false;
    dashboardBalanceRevealedNotifier.value = false;
    _persist();
  }

  /// Format an amount into compact notation (e.g. 1169570.67 -> "1.17M", 45000 -> "45.0K").
  static String formatCompactNumber(double amount) {
    final abs = amount.abs();
    if (abs >= 1000000000) {
      final val = amount / 1000000000;
      return '${val.toStringAsFixed(2)}B';
    } else if (abs >= 1000000) {
      final val = amount / 1000000;
      return '${val.toStringAsFixed(2)}M';
    } else if (abs >= 1000) {
      final val = amount / 1000;
      final fixed = val.toStringAsFixed(1);
      return fixed.endsWith('.0')
          ? '${fixed.substring(0, fixed.length - 2)}K'
          : '${fixed}K';
    } else {
      return amount.toStringAsFixed(2);
    }
  }

  /// Formats PKR amount according to user's real-time financial display preferences:
  /// - If stealth mode is ON and neither local override nor synchronized dashboard reveal is true: "Rs. ••••••••••"
  /// - Else if compact format is ON: "Rs. 1.17M"
  /// - Otherwise standard full precision: "Rs. 1,169,570.67"
  static String formatVolumePkr(
    double? amount, {
    bool allowStealth = true,
    bool isTemporarilyRevealed = false,
  }) {
    if (amount == null) return 'Rs. 0.00';
    final bool isRevealed =
        isTemporarilyRevealed || dashboardBalanceRevealedNotifier.value;
    if (allowStealth && isStealthMode && !isRevealed) {
      return 'Rs. ••••••••••';
    }
    if (isCompactFormat) {
      return 'Rs. ${formatCompactNumber(amount)}';
    }
    final raw = AppFormatters.formatPkr(amount);
    return raw.startsWith('Rs ')
        ? raw.replaceFirst('Rs ', 'Rs. ')
        : (raw.startsWith('Rs.') ? raw : 'Rs. $raw');
  }

  static Future<File> _getPrefsFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/paidix_fx_display_prefs.json');
  }

  static Future<void> _persist() async {
    try {
      final file = await _getPrefsFile();
      final data = {
        'stealth_mode': stealthModeNotifier.value,
        'compact_format': compactFormatNotifier.value,
        'updated_at': DateTime.now().toIso8601String(),
      };
      await file.writeAsString(jsonEncode(data), flush: true);
    } catch (_) {
      // Silently ignore in tests or sandboxed environments
    }
  }
}
