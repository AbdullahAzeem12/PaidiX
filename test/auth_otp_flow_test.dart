/// Verifies live authentication, email OTP dispatch, resend handling,
/// already-verified recovery, and PDF-compliant error parsing.

import 'dart:convert';
import 'dart:typed_data';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:paidix/app/theme/app_theme.dart';
import 'package:paidix/core/config/app_config.dart';
import 'package:paidix/core/network/api_client.dart';
import 'package:paidix/core/widgets/paidix_toast.dart';
import 'package:paidix/features/auth/data/auth_repository.dart';
import 'package:paidix/features/auth/domain/auth_models.dart';
import 'package:paidix/features/auth/presentation/pages/sign_in_page.dart';
import 'package:paidix/features/auth/presentation/widgets/email_otp_dialog.dart';
import 'package:paidix/features/auth/presentation/widgets/admin_web_login_dialog.dart';
import 'package:paidix/features/profile/data/user_profile_repository.dart';
import 'package:paidix/features/profile/domain/user_profile.dart';
import 'test_fixtures.dart';

Future<void> _pumpUntil(WidgetTester tester, bool Function() condition) async {
  for (var frame = 0; frame < 40 && !condition(); frame++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

GoRouter _buildAuthTestRouter({
  required void Function(String) onNavigate,
}) {
  return GoRouter(
    initialLocation: '/signin',
    routes: [
      GoRoute(
        path: '/signin',
        builder: (context, state) => const SignInPage(),
      ),
      GoRoute(
        path: '/kyc',
        builder: (context, state) {
          onNavigate('/kyc');
          return const Scaffold(body: Text('KYC Page'));
        },
      ),
      GoRoute(
        path: '/app/dashboard',
        builder: (context, state) {
          onNavigate('/app/dashboard');
          return const Scaffold(body: Text('Dashboard Page'));
        },
      ),
    ],
  );
}

void main() {
  setUp(() async {
    setupTestState();
    AppConfig.debugOverrideCustomBackend = true;
    ApiClient.instance.customHttpClient = null;
    await ApiClient.instance.clearSession();
  });

  tearDown(() async {
    PaidiXToast.dismissCurrent();
    AppConfig.debugOverrideCustomBackend = null;
    ApiClient.instance.customHttpClient = null;
    await ApiClient.instance.clearSession();
  });

  group('AuthRepository Live API & OTP Verification Flow', () {
    test(
        'Admin role in backend login response is rejected before saving tokens',
        () async {
      await ApiClient.instance.setAuthTokens(
        access: 'previous_user_access',
        refresh: 'previous_user_refresh',
      );
      ApiClient.instance.customHttpClient = MockClient((request) async {
        if (request.url.path.endsWith('/auth/login/')) {
          return http.Response(
            jsonEncode({
              'access': 'admin_access_token',
              'refresh': 'admin_refresh_token',
              'user': {'email': 'admin@example.com', 'role': 'ADMIN'},
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('{}', 200);
      });

      await expectLater(
        AuthRepository.instance.signIn(
          const SignInRequest(
            email: 'admin@example.com',
            password: 'Secret123!',
          ),
        ),
        throwsA(isA<MobileAdminAccessException>()),
      );

      expect(ApiClient.instance.authToken, isNull);
      expect(ApiClient.instance.refreshToken, isNull);
    });

    test('Backend admin web-only denial is preserved as a mobile restriction',
        () async {
      ApiClient.instance.customHttpClient = MockClient((request) async {
        if (request.url.path.endsWith('/auth/login/')) {
          return http.Response(
            jsonEncode({
              'error': {
                'code': 'ADMIN_WEB_ONLY',
                'message': 'Admin accounts must sign in on the web portal.',
              },
            }),
            403,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('{}', 200);
      });

      await expectLater(
        AuthRepository.instance.signIn(
          const SignInRequest(
            email: 'admin@example.com',
            password: 'Secret123!',
          ),
        ),
        throwsA(
          isA<MobileAdminAccessException>().having(
            (error) => error.message,
            'backend message',
            'Admin accounts must sign in on the web portal.',
          ),
        ),
      );
      expect(ApiClient.instance.authToken, isNull);
    });

    test('Public auth endpoints omit stale Authorization Bearer headers',
        () async {
      await ApiClient.instance.setAuthTokens(
        access: 'stale_expired_access_token',
        refresh: 'stale_refresh_token',
      );

      final seenAuthHeaders = <String, bool>{};
      ApiClient.instance.customHttpClient = MockClient((request) async {
        seenAuthHeaders[request.url.path] =
            request.headers.containsKey('Authorization');

        if (request.url.path.endsWith('/auth/login/')) {
          return http.Response(
            jsonEncode({
              'error': 'EMAIL_UNVERIFIED',
              'message': 'Please verify your email to continue.',
            }),
            401,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path.endsWith('/auth/email/resend/')) {
          return http.Response(
            jsonEncode({'detail': 'Verification code sent.'}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path.endsWith('/auth/email/verify/')) {
          return http.Response(
            jsonEncode({'detail': 'Email verified successfully.'}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path.endsWith('/auth/signup/request-otp/')) {
          return http.Response(
            jsonEncode({'detail': 'User created. Verification code sent.'}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('{}', 200);
      });

      await expectLater(
        () => AuthRepository.instance.signIn(
          const SignInRequest(
              email: 'user@example.com', password: 'Secret123!'),
        ),
        throwsA(isA<EmailUnverifiedException>()
            .having((e) => e.otpSent, 'otpSent', isTrue)),
      );

      await AuthRepository.instance.resendEmailOtp(
        email: 'user@example.com',
        password: 'Secret123!',
      );
      await AuthRepository.instance.verifyEmailOtp(
        email: 'user@example.com',
        code: '123456',
      );
      await AuthRepository.instance.signUp(
        const SignUpRequest(
          fullName: 'Test User',
          email: 'new@example.com',
          password: 'Secret123!',
        ),
      );

      expect(seenAuthHeaders['/api/v1/auth/login/'], isFalse);
      expect(seenAuthHeaders['/api/v1/auth/email/resend/'], isFalse);
      expect(seenAuthHeaders['/api/v1/auth/email/verify/'], isFalse);
      expect(seenAuthHeaders['/api/v1/auth/signup/request-otp/'], isFalse);
    });

    test(
        'Already-verified user logs straight in without triggering resend or OTP',
        () async {
      int resendCount = 0;
      ApiClient.instance.customHttpClient = MockClient((request) async {
        if (request.url.path.endsWith('/auth/login/')) {
          return http.Response(
            jsonEncode({
              'access': 'valid_access_jwt',
              'refresh': 'valid_refresh_jwt',
              'user': {
                'email': 'verified@example.com',
                'full_name': 'Verified User',
                'is_profile_complete': true,
                'email_verified': true,
                'kyc_status': 'APPROVED',
              },
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path.endsWith('/auth/me/')) {
          return http.Response(
            jsonEncode({
              'email': 'verified@example.com',
              'full_name': 'Verified User',
              'phone': '+923001234567',
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path.endsWith('/accounts/profile/')) {
          return http.Response(jsonEncode({'status': 'approved'}), 200);
        }
        if (request.url.path.endsWith('/auth/email/resend/')) {
          resendCount++;
          return http.Response(
              jsonEncode({'detail': 'Verification code sent.'}), 200);
        }
        return http.Response('{}', 404);
      });

      final result = await AuthRepository.instance.signIn(
        const SignInRequest(
            email: 'verified@example.com', password: 'Secret123!'),
      );

      expect(resendCount, equals(0));
      expect(result.token, equals('valid_access_jwt'));
      expect(result.profile.hasCompletedKyc, isTrue);
      expect(result.profile.phoneNumber, equals('+923001234567'));
    });

    test(
        'If login returns EMAIL_UNVERIFIED but resend says already verified, retries login and signs in directly',
        () async {
      int loginAttempts = 0;
      ApiClient.instance.customHttpClient = MockClient((request) async {
        if (request.url.path.endsWith('/auth/login/')) {
          loginAttempts++;
          if (loginAttempts == 1) {
            return http.Response(
              jsonEncode({
                'detail': 'Please verify your email to continue.',
                'code': 'EMAIL_UNVERIFIED',
              }),
              401,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response(
            jsonEncode({
              'access': 'recovered_access_jwt',
              'refresh': 'recovered_refresh_jwt',
              'user': {
                'email': 'verified@example.com',
                'full_name': 'Recovered User',
                'is_profile_complete': true,
                'email_verified': true,
                'kyc_status': 'APPROVED',
              },
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path.endsWith('/auth/email/resend/')) {
          return http.Response(
            jsonEncode({'detail': 'Email is already verified.'}),
            400,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path.endsWith('/auth/me/')) {
          return http.Response(jsonEncode({}), 200);
        }
        if (request.url.path.endsWith('/accounts/profile/')) {
          return http.Response(jsonEncode({'status': 'approved'}), 200);
        }
        return http.Response('{}', 404);
      });

      final result = await AuthRepository.instance.signIn(
        const SignInRequest(
            email: 'verified@example.com', password: 'Secret123!'),
      );

      expect(loginAttempts, equals(2));
      expect(result.token, equals('recovered_access_jwt'));
      expect(result.profile.fullName, equals('Recovered User'));
    });

    test(
        'resendEmailOtp throws EmailAlreadyVerifiedException instead of faking OTP delivery',
        () async {
      ApiClient.instance.customHttpClient = MockClient((request) async {
        return http.Response(
          jsonEncode({'detail': 'Email is already verified.'}),
          400,
          headers: {'content-type': 'application/json'},
        );
      });

      await expectLater(
        () => AuthRepository.instance.resendEmailOtp(
          email: 'verified@example.com',
          password: 'Secret123!',
        ),
        throwsA(isA<EmailAlreadyVerifiedException>()),
      );
    });

    test('Profile completion does not count as backend KYC approval', () async {
      ApiClient.instance.customHttpClient = MockClient((request) async {
        if (request.url.path.endsWith('/auth/login/')) {
          return http.Response(
            jsonEncode({
              'access': 'incomplete_kyc_access',
              'user': {
                'email': 'profile-complete@example.com',
                'full_name': 'Profile Complete',
                'is_profile_complete': true,
              },
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('{}', 200);
      });

      final result = await AuthRepository.instance.signIn(
        const SignInRequest(
          email: 'profile-complete@example.com',
          password: 'Secret123!',
        ),
      );

      expect(result.profile.kycStatus, KycReviewStatus.notStarted);
      expect(result.profile.hasCompletedKyc, isFalse);
    });

    test('Login approval is not trusted when the KYC status endpoint is empty',
        () async {
      ApiClient.instance.customHttpClient = MockClient((request) async {
        if (request.url.path.endsWith('/auth/login/')) {
          return http.Response(
            jsonEncode({
              'access': 'unconfirmed_approval_access',
              'user': {
                'email': 'unconfirmed@example.com',
                'kyc_status': 'approved',
              },
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('{}', 200);
      });

      final result = await AuthRepository.instance.signIn(
        const SignInRequest(
          email: 'unconfirmed@example.com',
          password: 'Secret123!',
        ),
      );

      expect(result.profile.kycStatus, KycReviewStatus.notStarted);
      expect(result.profile.hasCompletedKyc, isFalse);
    });

    test('Backend profile approval overrides an older login KYC state',
        () async {
      ApiClient.instance.customHttpClient = MockClient((request) async {
        if (request.url.path.endsWith('/auth/login/')) {
          return http.Response(
            jsonEncode({
              'access': 'approved_access',
              'user': {
                'email': 'approved@example.com',
                'kyc_status': 'pending_review',
              },
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path.endsWith('/accounts/profile/')) {
          return http.Response(
            jsonEncode({'status': 'approved'}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('{}', 200);
      });

      final result = await AuthRepository.instance.signIn(
        const SignInRequest(
          email: 'approved@example.com',
          password: 'Secret123!',
        ),
      );

      expect(result.profile.kycStatus, KycReviewStatus.verified);
      expect(result.profile.hasCompletedKyc, isTrue);
    });

    test(
        'Missing server status preserves same-user details but never cached approval',
        () async {
      final savedProfile = UserProfile(
        fullName: 'Saved Legal Name',
        email: 'saved@example.com',
        phoneNumber: '+923001234567',
        cnicNumber: '35202-1234567-1',
        city: 'Lahore',
        address: 'Saved Street',
        createdAt: DateTime(2024),
        updatedAt: DateTime(2025),
        kycStatus: KycReviewStatus.verified,
        hasCompletedKyc: true,
        cnicFrontBytes: Uint8List.fromList([1, 2, 3]),
        cnicBackBytes: Uint8List.fromList([4, 5, 6]),
        selfieBytes: Uint8List.fromList([7, 8, 9]),
        bankName: 'Meezan Bank Limited',
        bankAccountNumber: '1234567890',
        bankBeneficiary: 'Saved Legal Name',
      );
      UserProfileRepository.instance.setActiveUser(savedProfile);
      ApiClient.instance.customHttpClient = MockClient((request) async {
        if (request.url.path.endsWith('/auth/login/')) {
          return http.Response(
            jsonEncode({
              'access': 'saved_user_access',
              'user': {
                'email': 'saved@example.com',
                'is_profile_complete': true,
              },
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('{}', 200);
      });

      final result = await AuthRepository.instance.signIn(
        const SignInRequest(
          email: 'saved@example.com',
          password: 'Secret123!',
        ),
      );

      expect(result.profile.kycStatus, KycReviewStatus.pendingReview);
      expect(result.profile.hasCompletedKyc, isTrue);
      expect(result.profile.fullName, 'Saved Legal Name');
      expect(result.profile.phoneNumber, '+923001234567');
      expect(result.profile.cnicNumber, '35202-1234567-1');
      expect(result.profile.city, 'Lahore');
      expect(result.profile.address, 'Saved Street');
      expect(result.profile.cnicFrontBytes, [1, 2, 3]);
      expect(result.profile.cnicBackBytes, [4, 5, 6]);
      expect(result.profile.selfieBytes, [7, 8, 9]);
      expect(result.profile.bankAccountNumber, '1234567890');
    });
  });

  group('SignInPage & EmailOtpDialog Live Flows', () {
    testWidgets(
        'Verified server account logs straight to /app/dashboard with NO OTP dialog',
        (tester) async {
      String destination = '';
      ApiClient.instance.customHttpClient = MockClient((request) async {
        if (request.url.path.endsWith('/auth/login/')) {
          return http.Response(
            jsonEncode({
              'access': 'jwt_access',
              'refresh': 'jwt_refresh',
              'user': {
                'email': 'verified@example.com',
                'full_name': 'Abdullah',
                'is_profile_complete': true,
                'email_verified': true,
                'kyc_status': 'APPROVED',
              },
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path.endsWith('/accounts/profile/')) {
          return http.Response(jsonEncode({'status': 'approved'}), 200);
        }
        return http.Response('{}', 200);
      });

      await tester.pumpWidget(
        MaterialApp.router(
          theme: AppTheme.lightTheme,
          routerConfig:
              _buildAuthTestRouter(onNavigate: (loc) => destination = loc),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
          find.byType(TextFormField).at(0), 'verified@example.com');
      await tester.enterText(find.byType(TextFormField).at(1), 'Secret123!');
      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();

      expect(find.text('Verify Your Email'), findsNothing);
      expect(destination, equals('/app/dashboard'));
    });

    testWidgets(
        'Unverified user triggers OTP email, resends cleanly, verifies OTP once, and routes to /kyc',
        (tester) async {
      setupTestState(
        profile: createTestProfile(
          email: 'unverified@example.com',
          kycStatus: KycReviewStatus.notStarted,
          hasCompletedKyc: false,
        ),
      );
      String destination = '';
      bool emailVerifiedOnServer = false;
      String? capturedVerifyCode;
      int resendCalls = 0;
      int loginCalls = 0;

      ApiClient.instance.customHttpClient = MockClient((request) async {
        if (request.url.path.endsWith('/auth/login/')) {
          loginCalls++;
          if (!emailVerifiedOnServer) {
            return http.Response(
              jsonEncode({
                'error': 'EMAIL_UNVERIFIED',
                'message': 'Please verify your email to continue.',
              }),
              401,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response(
            jsonEncode({
              'access': 'jwt_access',
              'refresh': 'jwt_refresh',
              'user': {
                'email': 'unverified@example.com',
                'full_name': 'New User',
                'is_profile_complete': false,
                'email_verified': true,
                'kyc_status': 'DRAFT',
              },
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path.endsWith('/accounts/profile/')) {
          return http.Response(jsonEncode({'status': 'draft'}), 200);
        }
        if (request.url.path.endsWith('/auth/email/resend/')) {
          resendCalls++;
          return http.Response(
            jsonEncode({'detail': 'Verification code sent.'}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path.endsWith('/auth/email/verify/')) {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          capturedVerifyCode = body['code'] as String?;
          emailVerifiedOnServer = true;
          return http.Response(
            jsonEncode({'detail': 'Email verified successfully.'}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('{}', 200);
      });

      await tester.pumpWidget(
        MaterialApp.router(
          theme: AppTheme.lightTheme,
          routerConfig:
              _buildAuthTestRouter(onNavigate: (loc) => destination = loc),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
          find.byType(TextFormField).at(0), 'unverified@example.com');
      await tester.enterText(find.byType(TextFormField).at(1), 'Secret123!');
      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();

      expect(resendCalls, equals(1));
      expect(find.text('Verify Your Email'), findsOneWidget);
      expect(find.text('A 6-digit verification code was sent to:'),
          findsOneWidget);

      await tester.tap(find.text('Resend Code'));
      await tester.pumpAndSettle();
      expect(resendCalls, equals(2));

      final otpField = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      );
      await tester.enterText(otpField, '654321');
      // The OTP dialog owns a periodic countdown timer, so the route never
      // becomes fully idle for pumpAndSettle. Let verification futures and
      // their resulting frame complete without waiting for the timer.
      await _pumpUntil(
        tester,
        () => destination == '/kyc',
      );
      await tester.pump(const Duration(milliseconds: 500));

      expect(capturedVerifyCode, equals('654321'));
      expect(emailVerifiedOnServer, isTrue);
      expect(loginCalls, equals(2));
      expect(find.text('Verify Your Email'), findsNothing);
      expect(destination, equals('/kyc'));
    });

    testWidgets(
        'Tapping Resend Code when email is already verified closes dialog and logs user in directly',
        (tester) async {
      String destination = '';
      bool flipResendToAlreadyVerified = false;

      ApiClient.instance.customHttpClient = MockClient((request) async {
        if (request.url.path.endsWith('/auth/login/')) {
          if (!flipResendToAlreadyVerified) {
            return http.Response(
              jsonEncode({
                'detail': 'Please verify your email to continue.',
                'code': 'EMAIL_UNVERIFIED',
              }),
              401,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response(
            jsonEncode({
              'access': 'jwt_access',
              'refresh': 'jwt_refresh',
              'user': {
                'email': 'verified@example.com',
                'full_name': 'Verified Now',
                'is_profile_complete': true,
                'email_verified': true,
                'kyc_status': 'APPROVED',
              },
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path.endsWith('/accounts/profile/')) {
          return http.Response(jsonEncode({'status': 'approved'}), 200);
        }
        if (request.url.path.endsWith('/auth/email/resend/')) {
          if (!flipResendToAlreadyVerified) {
            return http.Response(
              jsonEncode({'detail': 'Verification code sent.'}),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response(
            jsonEncode({'detail': 'Email is already verified.'}),
            400,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('{}', 200);
      });

      await tester.pumpWidget(
        MaterialApp.router(
          theme: AppTheme.lightTheme,
          routerConfig:
              _buildAuthTestRouter(onNavigate: (loc) => destination = loc),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
          find.byType(TextFormField).at(0), 'verified@example.com');
      await tester.enterText(find.byType(TextFormField).at(1), 'Secret123!');
      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();

      expect(find.text('Verify Your Email'), findsOneWidget);

      flipResendToAlreadyVerified = true;
      await tester.tap(find.text('Resend Code'));
      await tester.pumpAndSettle();

      expect(find.text('Verify Your Email'), findsNothing);
      expect(destination, equals('/app/dashboard'));
    });

    testWidgets(
        '429 rate-limited initial OTP dispatch opens dialog without falsely claiming a new email was sent',
        (tester) async {
      ApiClient.instance.customHttpClient = MockClient((request) async {
        if (request.url.path.endsWith('/auth/login/')) {
          return http.Response(
            jsonEncode({
              'detail': 'Please verify your email to continue.',
              'code': 'EMAIL_UNVERIFIED',
            }),
            401,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path.endsWith('/auth/email/resend/')) {
          return http.Response(
            jsonEncode({
              'detail':
                  'Too many verification requests. Please try again after 10 minutes.',
            }),
            429,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('{}', 200);
      });

      await tester.pumpWidget(
        MaterialApp.router(
          theme: AppTheme.lightTheme,
          routerConfig: _buildAuthTestRouter(onNavigate: (_) {}),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
          find.byType(TextFormField).at(0), 'ratelimited@example.com');
      await tester.enterText(find.byType(TextFormField).at(1), 'Secret123!');
      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();

      expect(find.text('Verify Your Email'), findsOneWidget);
      expect(find.text('Enter the 6-digit verification code for:'),
          findsOneWidget);
      expect(find.textContaining('Too many verification requests'),
          findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    });

    testWidgets(
        'SignUp OTP flow (performSignInOnVerified: true) verifies OTP, stores JWT tokens, then invokes onVerified',
        (tester) async {
      setupTestState(
        profile: createTestProfile(
          email: 'signup@example.com',
          kycStatus: KycReviewStatus.notStarted,
          hasCompletedKyc: false,
        ),
      );
      bool onVerifiedCalled = false;
      int loginCalls = 0;

      ApiClient.instance.customHttpClient = MockClient((request) async {
        if (request.url.path.endsWith('/auth/email/verify/')) {
          return http.Response(
            jsonEncode({'detail': 'Email verified successfully.'}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path.endsWith('/auth/login/')) {
          loginCalls++;
          return http.Response(
            jsonEncode({
              'access': 'signup_access_jwt',
              'refresh': 'signup_refresh_jwt',
              'user': {
                'email': 'signup@example.com',
                'full_name': 'Signup User',
                'is_profile_complete': false,
                'email_verified': true,
                'kyc_status': 'DRAFT',
              },
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('{}', 200);
      });

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Builder(
            builder: (ctx) => Scaffold(
              body: ElevatedButton(
                onPressed: () => EmailOtpDialog.show(
                  ctx,
                  email: 'signup@example.com',
                  password: 'Secret123!',
                  onVerified: () => onVerifiedCalled = true,
                ),
                child: const Text('Open OTP'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open OTP'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '481920');
      // Keep this finite because the OTP dialog countdown timer is periodic.
      await _pumpUntil(tester, () => onVerifiedCalled);
      await tester.pumpAndSettle();

      expect(loginCalls, equals(1));
      expect(ApiClient.instance.authToken, equals('signup_access_jwt'));
      expect(ApiClient.instance.refreshToken, equals('signup_refresh_jwt'));
      expect(onVerifiedCalled, isTrue);
      expect(find.text('Verify Your Email'), findsNothing);
    });
  });

  testWidgets('Admin restriction offers the official web login URL',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () => AdminWebLoginDialog.show(
                context,
                backendMessage: 'Admin accounts must use the web portal.',
              ),
              child: const Text('Show restriction'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Show restriction'));
    await tester.pumpAndSettle();

    expect(find.text('Admin sign-in is web only'), findsOneWidget);
    expect(find.textContaining('https://paidix.com/login'), findsOneWidget);
    expect(find.text('Open Admin Web Login'), findsOneWidget);

    await tester.tap(find.text('Dismiss'));
    await tester.pumpAndSettle();
  });
}
