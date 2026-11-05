/// Defines fx display preferences in the settings feature's domain layer.

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

  /// Loads saved preferences once and leaves default values in place if storage cannot be read.
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

  /// Toggles balance masking, resets the temporary reveal state, and persists the preference.
  static void toggleStealthMode() {
    HapticFeedback.lightImpact();
    stealthModeNotifier.value = !stealthModeNotifier.value;
    dashboardBalanceRevealedNotifier.value = false;
    _persist();
  }

  /// Toggles compact currency notation and persists the preference.
  static void toggleCompactFormat() {
    HapticFeedback.lightImpact();
    compactFormatNotifier.value = !compactFormatNotifier.value;
    _persist();
  }

  /// Toggles the shared temporary reveal state used by dashboard balance cards.
  static void toggleDashboardBalanceRevealed() {
    HapticFeedback.lightImpact();
    dashboardBalanceRevealedNotifier.value =
        !dashboardBalanceRevealedNotifier.value;
  }

  /// Sets the shared temporary reveal state used by dashboard balance cards.
  static void setDashboardBalanceRevealed(bool revealed) {
    dashboardBalanceRevealedNotifier.value = revealed;
  }

  /// Restores the display preferences and temporary balance reveal state to their defaults.
  static void resetToDefault() {
    HapticFeedback.selectionClick();
    stealthModeNotifier.value = false;
    compactFormatNotifier.value = false;
    dashboardBalanceRevealedNotifier.value = false;
    _persist();
  }

  /// Formats a number with compact K, M, or B notation while keeping useful precision.
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
  /// Formats a PKR amount using the active privacy and compact-display preferences.
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

/// Resolves the app-documents path used to store display and privacy preferences.
  static Future<File> _getPrefsFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/paidix_fx_display_prefs.json');
  }

/// Writes the current display and privacy preference values to local JSON storage.
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
