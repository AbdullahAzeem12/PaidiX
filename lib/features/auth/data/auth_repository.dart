/// Authentication repository connecting PaidiX to the backend auth services.

import 'dart:async';
import 'package:http/http.dart' as http;
import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../../profile/data/user_profile_repository.dart';
import '../../profile/domain/user_profile.dart';
import '../domain/auth_models.dart';

/// Encapsulates authentication result with user profile and session token.
class AuthResult {
  final UserProfile profile;
  final String token;

  const AuthResult({
    required this.profile,
    required this.token,
  });
}

class AuthRepository {
  AuthRepository._();
  static final AuthRepository instance = AuthRepository._();

  final ApiClient _client = ApiClient.instance;

  /// Registers a new user account with the backend server.
  Future<AuthResult> signUp(SignUpRequest request) async {
    final now = DateTime.now();
    if (AppConfig.hasCustomBackend) {
      Map<String, dynamic> data;
      try {
        data = await _client.post(
          '/auth/signup/request-otp/',
          body: request.toJson(),
        );
      } on ApiException catch (e) {
        if (e.statusCode == 404) {
          data = await _client.post(
            '/auth/signup',
            body: request.toJson(),
          );
        } else {
          rethrow;
        }
      }

      final access = (data['access'] ?? data['token']) as String? ?? '';
      final refresh = data['refresh'] as String? ?? '';
      if (access.isNotEmpty) {
        await _client.setAuthTokens(access: access, refresh: refresh);
      }

      final userData = data['user'] as Map<String, dynamic>? ?? {};
      final fullName = userData['full_name'] as String? ??
          userData['fullName'] as String? ??
          request.fullName;
      final profile = UserProfile(
        fullName: fullName,
        email: userData['email'] as String? ?? request.email,
        countryCode: '+92',
        phoneNumber: userData['phone'] as String? ?? (request.phone ?? ''),
        cnicNumber: userData['cnic_number'] as String? ??
            userData['cnicNumber'] as String? ??
            '',
        city: userData['city'] as String? ?? '',
        address: userData['address'] as String? ?? '',
        createdAt: now,
        updatedAt: now,
        hasCompletedKyc: userData['hasCompletedKyc'] as bool? ?? false,
        kycStatus: KycReviewStatus.notStarted,
      );

      UserProfileRepository.instance.setActiveUser(profile);
      return AuthResult(profile: profile, token: access);
    }

    // Local offline storage fallback (when no custom backend URL is supplied)
    await Future.delayed(const Duration(milliseconds: 300));
    UserProfileRepository.instance.syncFromSignUp(
      fullName: request.fullName,
      email: request.email,
      countryCode: '+92',
      phoneNumber: request.phone ?? '',
      smsConsent: request.smsConsent,
    );
    final profile = UserProfileRepository.instance.profile;
    const sessionToken = 'local_session_token';
    await _client.setAuthToken(sessionToken);
    return AuthResult(profile: profile, token: sessionToken);
  }

  /// Authenticates an existing user account with the backend server.
  Future<AuthResult> signIn(SignInRequest request) async {
    final inputEmail = request.email.trim().toLowerCase();
    final now = DateTime.now();

    // Simulated error testing hooks
    if (inputEmail.startsWith('error') || inputEmail.startsWith('500')) {
      throw const ApiException(
        statusCode: 503,
        message:
            'Unable to reach the core authentication and settlement cluster. Please retry or verify your network connection.',
        errorCode: 'ERR_AUTH_503_UNAVAILABLE',
      );
    }

    if (AppConfig.hasCustomBackend) {
      Map<String, dynamic> data;
      try {
        data = await _client.post(
          '/auth/login/',
          body: request.toJson(),
        );
      } on ApiException catch (e) {
        if (e.statusCode == 404) {
          data = await _client.post(
            '/auth/signin',
            body: request.toJson(),
          );
        } else {
          rethrow;
        }
      }

      final access = (data['access'] ?? data['token']) as String? ?? '';
      final refresh = data['refresh'] as String? ?? '';
      if (access.isNotEmpty) {
        await _client.setAuthTokens(access: access, refresh: refresh);
      }

      final userData = data['user'] as Map<String, dynamic>? ?? {};
      final kycStatusStr =
          (userData['kyc_status'] as String? ?? '').toLowerCase();
      final isProfileComplete = userData['is_profile_complete'] as bool? ??
          userData['hasCompletedKyc'] as bool? ??
          false;
      final isKycCompleted = isProfileComplete || kycStatusStr == 'approved';

      KycReviewStatus kycStatus;
      if (isKycCompleted) {
        kycStatus = KycReviewStatus.verified;
      } else if (kycStatusStr == 'pending' || kycStatusStr == 'resubmitted') {
        kycStatus = KycReviewStatus.pendingReview;
      } else if (kycStatusStr == 'rejected') {
        kycStatus = KycReviewStatus.rejected;
      } else {
        kycStatus = KycReviewStatus.notStarted;
      }

      final existingProfile = UserProfileRepository.instance.profile;
      final serverName = (userData['full_name'] ?? userData['fullName']) as String?;
      final fullName = (serverName != null && serverName.isNotEmpty)
          ? serverName
          : (existingProfile.fullName.isNotEmpty
              ? existingProfile.fullName
              : inputEmail.split('@').first);

      final serverPhone =
          (userData['phone'] ?? userData['phoneNumber']) as String? ?? '';
      final effectivePhone = serverPhone.isNotEmpty
          ? serverPhone
          : (existingProfile.email.toLowerCase() == inputEmail
              ? existingProfile.phoneNumber
              : '');

      UserProfile profile = UserProfile(
        fullName: fullName,
        email: userData['email'] as String? ?? inputEmail,
        countryCode: '+92',
        phoneNumber: effectivePhone,
        cnicNumber: userData['cnic_number'] as String? ??
            userData['cnicNumber'] as String? ??
            '',
        city: userData['city'] as String? ?? '',
        address: userData['address'] as String? ?? '',
        createdAt: now,
        updatedAt: now,
        hasCompletedKyc: isKycCompleted,
        kycStatus: kycStatus,
      );

      // Fetch /auth/me/ to enrich with verified phone and full profile details
      try {
        final me = await _client.get('/auth/me/');
        if (me.isNotEmpty) {
          final mePhone =
              (me['phone'] ?? me['phoneNumber']) as String? ?? '';
          final meFullName =
              (me['full_name'] ?? me['fullName']) as String? ?? '';
          if (mePhone.isNotEmpty || meFullName.isNotEmpty) {
            profile = profile.copyWith(
              phoneNumber:
                  mePhone.isNotEmpty ? mePhone : profile.phoneNumber,
              fullName:
                  meFullName.isNotEmpty ? meFullName : profile.fullName,
            );
          }
        }
      } catch (_) {}

      UserProfileRepository.instance.setActiveUser(profile);
      return AuthResult(profile: profile, token: access);
    }

    // Local / Offline fallback logic preserving persistent profiles
    await Future.delayed(const Duration(milliseconds: 300));
    final repo = UserProfileRepository.instance;
    final registered =
        await repo.findOrLoadUser(inputEmail) ?? repo.findUser(inputEmail);

    if (registered != null) {
      repo.setActiveUser(registered);
      const token = 'local_session_token';
      await _client.setAuthToken(token);
      return AuthResult(profile: registered, token: token);
    }

    final newUser = UserProfile(
      fullName: inputEmail.split('@').first,
      email: inputEmail,
      countryCode: '+92',
      phoneNumber: '',
      cnicNumber: '',
      city: '',
      address: '',
      createdAt: now,
      updatedAt: now,
      hasCompletedKyc: false,
      kycStatus: KycReviewStatus.notStarted,
    );
    repo.setActiveUser(newUser);
    const token = 'new_user_session_token';
    await _client.setAuthToken(token);
    return AuthResult(profile: newUser, token: token);
  }

  /// Verifies an OTP code for email verification (POST /auth/email/verify/)
  ///
  /// Returns true on success. Also returns true when the backend reports
  /// "Email is already verified" — this means the user signed up previously,
  /// their email is confirmed, and we should proceed straight to sign-in.
  Future<bool> verifyEmailOtp({
    required String email,
    required String code,
  }) async {
    final cleanCode = code.replaceAll(RegExp(r'\D'), '');
    if (AppConfig.hasCustomBackend) {
      try {
        await _client.post(
          '/auth/email/verify/',
          body: {
            'email': email.trim().toLowerCase(),
            'code': cleanCode.isNotEmpty ? cleanCode : code.trim(),
          },
        );
      } on ApiException catch (e) {
        // Backend returns 400 "Email is already verified" when the account's
        // email was already confirmed (e.g. verified during sign-up). Treat
        // this as a successful verification so the sign-in flow can continue.
        final msg = e.message.toLowerCase();
        if (msg.contains('already verified') || msg.contains('already_verified')) {
          return true;
        }
        rethrow;
      }
      return true;
    }
    return true;
  }

  /// Resends a 6-digit email verification OTP (POST /auth/email/resend/)
  ///
  /// Returns true on success. If the backend reports "already verified",
  /// we return true so the dialog can proceed to complete sign-in directly.
  Future<bool> resendEmailOtp({
    required String email,
    required String password,
  }) async {
    if (AppConfig.hasCustomBackend) {
      try {
        await _client.post(
          '/auth/email/resend/',
          body: {
            'email': email.trim().toLowerCase(),
            'password': password,
          },
        );
      } on ApiException catch (e) {
        // If email is already verified, resend is unnecessary but not an error.
        // Return true so the caller can proceed to complete the sign-in.
        final msg = e.message.toLowerCase();
        if (msg.contains('already verified') || msg.contains('already_verified')) {
          return true;
        }
        rethrow;
      }
      return true;
    }
    return true;
  }

  /// Fetches the authenticated user profile and flags from backend (GET /auth/me/)
  Future<Map<String, dynamic>> fetchCurrentUserProfile() async {
    if (AppConfig.hasCustomBackend) {
      final data = await _client.get('/auth/me/');
      return data;
    }
    return {};
  }

  /// Updates personal profile details or avatar (PATCH /auth/me/)
  Future<Map<String, dynamic>> updateCurrentUserProfile({
    String? fullName,
    String? phone,
    List<int>? profilePictureBytes,
    String? fileName,
  }) async {
    if (AppConfig.hasCustomBackend) {
      if (profilePictureBytes != null) {
        final fields = <String, String>{
          if (fullName != null) 'full_name': fullName,
          if (phone != null) 'phone': phone,
        };
        final files = [
          http.MultipartFile.fromBytes(
            'profile_picture',
            profilePictureBytes,
            filename: fileName ?? 'avatar.jpg',
          ),
        ];
        return await _client.postMultipart('/auth/me/', fields: fields, files: files);
      } else {
        final body = <String, dynamic>{
          if (fullName != null) 'full_name': fullName,
          if (phone != null) 'phone': phone,
        };
        return await _client.patch('/auth/me/', body: body);
      }
    }
    return {};
  }

  /// Requests a password reset OTP code (POST /auth/forgot-password/request-otp/)
  Future<bool> requestPasswordResetOtp({required String email}) async {
    if (AppConfig.hasCustomBackend) {
      await _client.post(
        '/auth/forgot-password/request-otp/',
        body: {'email': email.trim().toLowerCase()},
      );
      return true;
    }
    return true;
  }

  /// Resets user password using the 6-digit OTP (POST /auth/forgot-password/reset/)
  Future<bool> resetPasswordWithOtp({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    if (AppConfig.hasCustomBackend) {
      await _client.post(
        '/auth/forgot-password/reset/',
        body: {
          'email': email.trim().toLowerCase(),
          'code': code.trim(),
          'new_password': newPassword,
        },
      );
      return true;
    }
    return true;
  }

  /// Updates account password for an authenticated user (POST /auth/change-password/)
  Future<bool> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    if (AppConfig.hasCustomBackend) {
      await _client.post(
        '/auth/change-password/',
        body: {
          'old_password': oldPassword,
          'new_password': newPassword,
        },
      );
      return true;
    }
    return true;
  }

  /// Checks if Payments PIN is configured (GET /auth/payments-pin/)
  Future<bool> checkPaymentsPinStatus() async {
    if (AppConfig.hasCustomBackend) {
      final res = await _client.get('/auth/payments-pin/');
      return res['is_set'] == true;
    }
    return false;
  }

  /// Sets initial Payments PIN (POST /auth/payments-pin/)
  Future<bool> setPaymentsPin({required String pin}) async {
    if (AppConfig.hasCustomBackend) {
      await _client.post(
        '/auth/payments-pin/',
        body: {'pin': pin},
      );
      return true;
    }
    return true;
  }

  /// Updates existing Payments PIN (POST /auth/payments-pin/)
  Future<bool> updatePaymentsPin({
    required String currentPin,
    required String newPin,
  }) async {
    if (AppConfig.hasCustomBackend) {
      await _client.post(
        '/auth/payments-pin/',
        body: {
          'current_pin': currentPin,
          'pin': newPin,
        },
      );
      return true;
    }
    return true;
  }

  /// Removes Payments PIN (DELETE /auth/payments-pin/)
  Future<bool> removePaymentsPin({required String currentPin}) async {
    if (AppConfig.hasCustomBackend) {
      await _client.delete(
        '/auth/payments-pin/',
        body: {'current_pin': currentPin},
      );
      return true;
    }
    return true;
  }

  /// Verifies Payments PIN before sensitive operations (POST /auth/payments-pin/verify/)
  Future<bool> verifyPaymentsPin({required String pin}) async {
    if (AppConfig.hasCustomBackend) {
      final res = await _client.post(
        '/auth/payments-pin/verify/',
        body: {'pin': pin},
      );
      return res['ok'] == true;
    }
    return true;
  }

  /// Terminates the active session, revokes refresh token on server, and clears secure storage.
  Future<void> signOut() async {
    if (AppConfig.hasCustomBackend) {
      try {
        final refresh = _client.refreshToken;
        if (refresh != null && refresh.isNotEmpty) {
          await _client.post(
            '/auth/logout/',
            body: {'refresh': refresh},
          );
        }
      } catch (_) {
        // Non-blocking logout network error
      }
    }
    await _client.clearSession();
  }
}
