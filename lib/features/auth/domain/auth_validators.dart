/// Defines auth validators in the auth feature's domain layer.

class AuthValidators {
  AuthValidators._();

  /// Requires a non-empty name with the minimum supported character count.
  static String? validateFullName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your full name';
    }
    if (value.trim().length < 2) {
      return 'Full name must be at least 2 characters';
    }
    return null;
  }

  /// Checks that the email value has a valid address structure.
  static String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your email';
    }
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value.trim())) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  /// Requires a non-empty password with at least eight characters.
  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your password';
    }
    if (value.length < 8) {
      return 'Password must be at least 8 characters';
    }
    return null;
  }

  /// Accepts an empty optional value; otherwise requires at least six characters.
  static String? validatePhoneOptional(String? value) {
    // Optional field: valid if empty or matches standard phone characters
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    if (value.trim().length < 6) {
      return 'Please enter a valid phone number';
    }
    return null;
  }
}

