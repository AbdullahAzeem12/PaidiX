/// Defines auth models in the auth feature's domain layer.

class SignUpRequest {
  final String fullName;
  final String email;
  final String? phone;
  final String password;
  final bool smsConsent;

  const SignUpRequest({
    required this.fullName,
    required this.email,
    this.phone,
    required this.password,
    this.smsConsent = false,
  });

  /// Serializes this value into the JSON shape used by local storage.
  Map<String, dynamic> toJson() => {
        'fullName': fullName,
        'email': email,
        if (phone != null && phone!.isNotEmpty) 'phone': phone,
        'password': password,
        'smsConsent': smsConsent,
      };
}

class SignInRequest {
  final String email;
  final String password;

  const SignInRequest({
    required this.email,
    required this.password,
  });

  /// Serializes this value into the JSON shape used by local storage.
  Map<String, dynamic> toJson() => {
        'email': email,
        'password': password,
      };
}

class AuthResponse {
  final bool success;
  final String? token;
  final String? message;
  final bool verificationRequired;

  const AuthResponse({
    required this.success,
    this.token,
    this.message,
    this.verificationRequired = false,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) => AuthResponse(
        success: json['success'] as bool? ?? false,
        token: json['token'] as String?,
        message: json['message'] as String?,
        verificationRequired: json['verificationRequired'] as bool? ?? false,
      );
}

