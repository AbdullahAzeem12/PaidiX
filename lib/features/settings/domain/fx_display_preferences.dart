import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// Supported foreign currencies for live FX calculation & payout breakdown.
class FxCurrency {
  final String code;
  final String name;
  final String symbol;
  final double rateToPkr;
  final String trendPercent;
  final bool isPositiveTrend;

  const FxCurrency({
    required this.code,
    required this.name,
    required this.symbol,
    required this.rateToPkr,
    required this.trendPercent,
    required this.isPositiveTrend,
  });
}

/// Reactive state manager & persistent storage for Financial Display & FX Converter Studio.
class FxDisplayPreferences {
  FxDisplayPreferences._();
  static final FxDisplayPreferences instance = FxDisplayPreferences._();

  static const List<FxCurrency> supportedCurrencies = [
    FxCurrency(
      code: 'USD',
      name: 'US Dollar',
      symbol: '\$',
      rateToPkr: 278.50,
      trendPercent: '+0.42%',
      isPositiveTrend: true,
    ),
    FxCurrency(
      code: 'EUR',
      name: 'Euro',
      symbol: '€',
      rateToPkr: 301.20,
      trendPercent: '+0.18%',
      isPositiveTrend: true,
    ),
    FxCurrency(
      code: 'GBP',
      name: 'British Pound',
      symbol: '£',
      rateToPkr: 352.40,
      trendPercent: '-0.05%',
      isPositiveTrend: false,
    ),
    FxCurrency(
      code: 'AED',
      name: 'UAE Dirham',
      symbol: 'AED',
      rateToPkr: 75.85,
      trendPercent: '+0.10%',
      isPositiveTrend: true,
    ),
  ];

  /// Standard PaidiX cross-border platform fee (12%).
  static const double platformFeePercent = 12.0;

  // ── Reactive Notifiers ──────────────────────────────────────────────────
  static final ValueNotifier<bool> stealthModeNotifier =
      ValueNotifier<bool>(false);

  static final ValueNotifier<bool> compactFormatNotifier =
      ValueNotifier<bool>(false);

  static final ValueNotifier<int> selectedCurrencyIndexNotifier =
      ValueNotifier<int>(0);

  static final ValueNotifier<double> calculatorAmountNotifier =
      ValueNotifier<double>(500.0);

  static bool get isStealthMode => stealthModeNotifier.value;
  static bool get isCompactFormat => compactFormatNotifier.value;
  static int get selectedCurrencyIndex => selectedCurrencyIndexNotifier.value;
  static FxCurrency get selectedCurrency =>
      supportedCurrencies[selectedCurrencyIndex];
  static double get calculatorAmount => calculatorAmountNotifier.value;

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
          compactFormatNotifier.value = data['compact_format'] as bool? ?? false;
        }
        if (data.containsKey('currency_index')) {
          final idx = data['currency_index'] as int? ?? 0;
          if (idx >= 0 && idx < supportedCurrencies.length) {
            selectedCurrencyIndexNotifier.value = idx;
          }
        }
        if (data.containsKey('amount')) {
          final amt = (data['amount'] as num?)?.toDouble() ?? 500.0;
          calculatorAmountNotifier.value = amt.clamp(50.0, 10000.0);
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
    _persist();
  }

  /// Toggle Compact Number Notation with haptics.
  static void toggleCompactFormat() {
    HapticFeedback.lightImpact();
    compactFormatNotifier.value = !compactFormatNotifier.value;
    _persist();
  }

  /// Switch calculator base currency with haptics.
  static void setCurrencyIndex(int index) {
    if (index == selectedCurrencyIndexNotifier.value) return;
    HapticFeedback.selectionClick();
    selectedCurrencyIndexNotifier.value =
        index.clamp(0, supportedCurrencies.length - 1);
    _persist();
  }

  /// Update calculator amount.
  static void setAmount(double amount) {
    calculatorAmountNotifier.value = amount.clamp(50.0, 10000.0);
    _persist();
  }

  /// Calculate net PKR payout based on gross amount, fee, and rate.
  static double calculateNetPkr({double? amount, FxCurrency? currency}) {
    final amt = amount ?? calculatorAmount;
    final curr = currency ?? selectedCurrency;
    final fee = amt * (platformFeePercent / 100.0);
    final netForeign = amt - fee;
    return netForeign * curr.rateToPkr;
  }

  /// Reset all display & FX preferences to defaults.
  static void resetToDefault() {
    HapticFeedback.selectionClick();
    stealthModeNotifier.value = false;
    compactFormatNotifier.value = false;
    selectedCurrencyIndexNotifier.value = 0;
    calculatorAmountNotifier.value = 500.0;
    _persist();
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
        'currency_index': selectedCurrencyIndexNotifier.value,
        'amount': calculatorAmountNotifier.value,
        'updated_at': DateTime.now().toIso8601String(),
      };
      await file.writeAsString(jsonEncode(data), flush: true);
    } catch (_) {
      // Silently ignore in tests or sandboxed environments
    }
  }
}

