import 'package:flutter/services.dart';

enum CnicStatus {
  empty,
  incomplete,
  checking,
  available,
  alreadyRegistered,
  invalidFormat,
}

class CnicInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    final digitsOnly = text.replaceAll(RegExp(r'\D'), '');

    if (digitsOnly.length > 13) {
      return oldValue;
    }

    final buffer = StringBuffer();
    for (int i = 0; i < digitsOnly.length; i++) {
      if (i == 5 || i == 12) {
        buffer.write('-');
      }
      buffer.write(digitsOnly[i]);
    }

    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class CnicValidator {
  const CnicValidator._();

  static String clean(String raw) => raw.replaceAll(RegExp(r'\D'), '');

  static String format(String raw) {
    final digits = clean(raw);
    if (digits.length <= 5) return digits;
    if (digits.length <= 12) {
      return '${digits.substring(0, 5)}-${digits.substring(5)}';
    }
    return '${digits.substring(0, 5)}-${digits.substring(5, 12)}-${digits.substring(12, 13)}';
  }

  static bool isValidFormat(String raw) {
    final digits = clean(raw);
    if (digits.length != 13) return false;
    final firstDigit = int.tryParse(digits[0]) ?? 0;
    // Province codes: 1=KP, 2=FATA, 3=Punjab, 4=Sindh, 5=Balochistan, 6=Islamabad, 7=GB, 8=AJK
    return firstDigit >= 1 && firstDigit <= 8;
  }

  /// Simulated real-time registry check with Nadra / PaidiX database
  static Future<CnicStatus> checkAvailability(String raw) async {
    final digits = clean(raw);
    if (digits.isEmpty) return CnicStatus.empty;
    if (digits.length < 13) return CnicStatus.incomplete;

    if (!isValidFormat(raw)) {
      return CnicStatus.invalidFormat;
    }

    // Blacklisted or already registered demo test cases
    if (digits == '1111111111111' || digits == '3520200000000') {
      return CnicStatus.alreadyRegistered;
    }

    // Realistic network check delay
    await Future.delayed(const Duration(milliseconds: 320));
    return CnicStatus.available;
  }
}

