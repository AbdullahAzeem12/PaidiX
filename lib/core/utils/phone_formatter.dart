import 'dart:math' as math;
import 'package:flutter/services.dart';

enum CountryCodeOption {
  pk(
    name: 'Pakistan',
    dialCode: '+92',
    prefix: 'PK',
    display: 'PK +92',
    flag: '🇵🇰',
    hintText: '300 1234567',
    maxDigits: 10,
  ),
  us(
    name: 'United States',
    dialCode: '+1',
    prefix: 'US',
    display: 'US +1',
    flag: '🇺🇸',
    hintText: '(555) 012-3456',
    maxDigits: 10,
  );

  final String name;
  final String dialCode;
  final String prefix;
  final String display;
  final String flag;
  final String hintText;
  final int maxDigits;

  const CountryCodeOption({
    required this.name,
    required this.dialCode,
    required this.prefix,
    required this.display,
    required this.flag,
    required this.hintText,
    required this.maxDigits,
  });

  bool get isUs => this == CountryCodeOption.us;

  static CountryCodeOption fromCodeOrDisplay(String? val) {
    if (val == null) return CountryCodeOption.pk;
    final upper = val.toUpperCase().trim();
    if (upper.contains('US') || upper == '+1' || upper == '1') {
      return CountryCodeOption.us;
    }
    return CountryCodeOption.pk;
  }
}

enum PhoneValidationStatus {
  empty,
  incomplete,
  valid,
  invalidAreaCode,
  invalidFormat,
}

class PhoneFormatter {
  const PhoneFormatter._();

  /// Strips all non-digit characters.
  static String clean(String raw) => raw.replaceAll(RegExp(r'\D'), '');

  /// Formats digits into North American standard: (XXX) XXX-XXXX
  static String formatUs(String raw) {
    final digits = clean(raw);
    if (digits.isEmpty) return '';

    final len = math.min(10, digits.length);
    final d = digits.substring(0, len);

    if (len <= 3) {
      return '($d';
    } else if (len <= 6) {
      return '(${d.substring(0, 3)}) ${d.substring(3)}';
    } else {
      return '(${d.substring(0, 3)}) ${d.substring(3, 6)}-${d.substring(6)}';
    }
  }

  /// Formats digits into Pakistani standard mobile: XXX XXXXXXX
  static String formatPk(String raw) {
    var digits = clean(raw);
    if (digits.isEmpty) return '';

    // Smart PK prefix stripping:
    // If user enters 03xx (11 digits e.g. 03217649976), strip leading 0
    if (digits.startsWith('0') && digits.length > 1) {
      digits = digits.substring(1);
    }
    // If user enters 923xx (12 digits e.g. 923217649976), strip leading 92
    else if (digits.startsWith('92') && digits.length > 2) {
      digits = digits.substring(2);
    }

    final len = math.min(10, digits.length);
    final d = digits.substring(0, len);

    if (len <= 3) {
      return d;
    } else {
      return '${d.substring(0, 3)} ${d.substring(3)}';
    }
  }

  /// Formats raw string according to country option
  static String format(String raw, {required bool isUs}) {
    return isUs ? formatUs(raw) : formatPk(raw);
  }
}

/// Smart real-time text input formatter for phone fields.
/// Handles typing, pasting, and backspacing gracefully without getting stuck on punctuation.
class PhoneInputFormatter extends TextInputFormatter {
  final bool isUs;

  PhoneInputFormatter({required this.isUs});

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }

    String textToProcess = newValue.text;

    // Handle user backspacing over a formatting character like '(', ')', ' ', or '-'
    if (oldValue.text.length > newValue.text.length) {
      final oldSelectionEnd = oldValue.selection.end;
      if (oldSelectionEnd > 0 && oldSelectionEnd <= oldValue.text.length) {
        final deletedChar = oldValue.text[oldSelectionEnd - 1];
        if (!RegExp(r'\d').hasMatch(deletedChar)) {
          final oldDigits = PhoneFormatter.clean(oldValue.text);
          if (oldDigits.isNotEmpty) {
            textToProcess = oldDigits.substring(0, oldDigits.length - 1);
          }
        }
      }
    }

    var cleanDigits = PhoneFormatter.clean(textToProcess);
    if (!isUs) {
      if (cleanDigits.startsWith('0') && cleanDigits.length > 1) {
        cleanDigits = cleanDigits.substring(1);
      } else if (cleanDigits.startsWith('92') && cleanDigits.length > 2) {
        cleanDigits = cleanDigits.substring(2);
      }
    }
    final maxLen = 10;
    final truncated = cleanDigits.length > maxLen
        ? cleanDigits.substring(0, maxLen)
        : cleanDigits;

    final formatted = isUs
        ? PhoneFormatter.formatUs(truncated)
        : PhoneFormatter.formatPk(truncated);

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class PhoneValidator {
  const PhoneValidator._();

  /// Validates US NANP phone number (10 digits, area code 2-9, exchange code 2-9).
  static bool isValidUs(String raw) {
    final digits = PhoneFormatter.clean(raw);
    if (digits.length != 10) return false;
    // NANP: Area code cannot begin with 0 or 1
    final areaCodeFirst = int.tryParse(digits[0]) ?? 0;
    if (areaCodeFirst < 2) return false;
    // Exchange code (digits[3]) cannot begin with 0 or 1
    final exchangeCodeFirst = int.tryParse(digits[3]) ?? 0;
    if (exchangeCodeFirst < 2) return false;
    return true;
  }

  /// Validates Pakistani mobile number (10 digits starting with 3, e.g. 3000000000).
  static bool isValidPk(String raw) {
    var digits = PhoneFormatter.clean(raw);
    if (digits.startsWith('0') && digits.length > 1) {
      digits = digits.substring(1);
    } else if (digits.startsWith('92') && digits.length > 2) {
      digits = digits.substring(2);
    }
    if (digits.length != 10) {
      return false;
    }
    return digits.startsWith('3');
  }

  /// Validates phone string according to country
  static bool isValid(String raw, {required bool isUs}) {
    return isUs ? isValidUs(raw) : isValidPk(raw);
  }

  /// Evaluates real-time validation status for UI feedback
  static PhoneValidationStatus getStatus(String raw, {required bool isUs}) {
    var digits = PhoneFormatter.clean(raw);
    if (digits.isEmpty) return PhoneValidationStatus.empty;

    if (isUs) {
      if (digits.isNotEmpty) {
        final areaCodeFirst = int.tryParse(digits[0]) ?? 0;
        if (areaCodeFirst < 2) return PhoneValidationStatus.invalidAreaCode;
      }
      if (digits.length < 10) return PhoneValidationStatus.incomplete;
      return isValidUs(raw)
          ? PhoneValidationStatus.valid
          : PhoneValidationStatus.invalidFormat;
    } else {
      if (digits.startsWith('0') && digits.length > 1) {
        digits = digits.substring(1);
      } else if (digits.startsWith('92') && digits.length > 2) {
        digits = digits.substring(2);
      }
      if (digits.length < 10) {
        if (digits.isNotEmpty && !digits.startsWith('3')) {
          return PhoneValidationStatus.invalidFormat;
        }
        return PhoneValidationStatus.incomplete;
      }
      return isValidPk(raw)
          ? PhoneValidationStatus.valid
          : PhoneValidationStatus.invalidFormat;
    }
  }
}
