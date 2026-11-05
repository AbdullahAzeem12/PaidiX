/// Defines validators in the application core utilities and reusable widgets.

class PaymentValidators {
  PaymentValidators._();

  /// Requires a non-empty sender name with at least two trimmed characters.
  /// Returns the first user-facing error, or `null` when the value is valid.
  static String? validateSenderName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter sender name';
    }
    if (value.trim().length < 2) {
      return 'Sender name must be at least 2 characters';
    }
    return null;
  }

  /// Requires a non-empty company name with at least two trimmed characters.
  /// Returns the first user-facing error, or `null` when the value is valid.
  static String? validateSenderCompany(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter sender company';
    }
    if (value.trim().length < 2) {
      return 'Sender company must be at least 2 characters';
    }
    return null;
  }

  /// Requires a confirmation code containing at least four non-whitespace
  /// characters and returns an error message when it does not.
  static String? validateConfirmationCode(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Confirmation code is required';
    }
    final trimmed = value.trim();
    if (trimmed.length < 4) {
      return 'Code must be at least 4 characters';
    }
    return null;
  }

  /// Removes currency symbols and grouping commas, then requires a positive
  /// numeric amount. Returns the first validation error or `null`.
  static String? validateAmount(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Amount is required';
    }
    final clean = value.replaceAll('\$', '').replaceAll(',', '').trim();
    final parsed = double.tryParse(clean);
    if (parsed == null) {
      return 'Please enter a valid numeric amount';
    }
    if (parsed <= 0) {
      return 'Amount must be greater than 0';
    }
    return null;
  }

  /// Requires a transaction date to be selected before submission.
  static String? validateDate(DateTime? date) {
    if (date == null) {
      return 'The date this payment was completed. You must select it.';
    }
    return null;
  }
}

