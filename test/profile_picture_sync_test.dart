import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:paidix/app/theme/app_theme.dart';
import 'package:paidix/core/config/app_config.dart';
import 'package:paidix/core/network/api_client.dart';
import 'package:paidix/features/auth/data/auth_repository.dart';
import 'package:paidix/features/auth/domain/auth_models.dart';
import 'package:paidix/features/profile/data/user_profile_repository.dart';
import 'package:paidix/features/profile/domain/user_profile.dart';
import 'package:paidix/features/settings/presentation/pages/account_settings_page.dart';
import 'test_fixtures.dart';

final _samplePngBytes = Uint8List.fromList([
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
  0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
]);

void main() {
  setUp(() {
    AppConfig.debugOverrideCustomBackend = null;
    ApiClient.instance.customHttpClient = null;
    setupTestState(
      profile: createTestProfile(
        email: 'abdullahazeem5352@gmail.com',
        kycStatus: KycReviewStatus.verified,
      ),
      banks: const [],
    );
  });

  tearDown(() {
    AppConfig.debugOverrideCustomBackend = null;
    ApiClient.instance.customHttpClient = null;
  });

  group('Server-side profile picture sync (/auth/me/)', () {
    test(
        'updateCurrentUserProfile uploads profile_picture via PATCH /auth/me/ and updates UserProfileRepository in realtime',
        () async {
      AppConfig.debugOverrideCustomBackend = true;
      final calls = <String>[];
      String? capturedAuth;
      String? capturedContentType;
      String? capturedBody;

      ApiClient.instance.customHttpClient = MockClient((request) async {
        calls.add('${request.method} ${request.url.path}');
        capturedAuth = request.headers['Authorization'];
        capturedContentType = request.headers['content-type'];
        capturedBody = latin1.decode(request.bodyBytes);
        if (request.method == 'PATCH' &&
            request.url.path.endsWith('/auth/me/')) {
          return http.Response(
            jsonEncode({
              'email': 'abdullahazeem5352@gmail.com',
              'profile_picture': 'https://cdn.example.com/avatars/u1_v1.png',
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('{}', 404);
      });
      await ApiClient.instance.setAuthTokens(access: 'test_token');

      final res = await AuthRepository.instance.updateCurrentUserProfile(
        profilePictureBytes: _samplePngBytes,
        fileName: 'avatar.png',
      );

      expect(calls, ['PATCH /api/v1/auth/me/']);
      expect(capturedAuth, 'Bearer test_token');
      expect(capturedContentType, contains('multipart/form-data'));
      expect(capturedBody, contains('name="profile_picture"'));
      expect(capturedBody, contains('filename="avatar.png"'));
      expect(
        res['profile_picture'],
        'https://cdn.example.com/avatars/u1_v1.png',
      );

      final updated = UserProfileRepository.instance.profile;
      expect(updated.avatarBytes, equals(_samplePngBytes));
      expect(
        updated.avatarUrl,
        'https://cdn.example.com/avatars/u1_v1.png',
      );
      expect(updated.hasCustomAvatar, isTrue);
    });

    test(
        'updateCurrentUserProfile falls back to POST /auth/me/ multipart when PATCH returns 405',
        () async {
      AppConfig.debugOverrideCustomBackend = true;
      final calls = <String>[];

      ApiClient.instance.customHttpClient = MockClient((request) async {
        calls.add('${request.method} ${request.url.path}');
        if (request.method == 'PATCH' &&
            request.url.path.endsWith('/auth/me/')) {
          return http.Response(
            jsonEncode({'detail': 'Method "PATCH" not allowed.'}),
            405,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.method == 'POST' &&
            request.url.path.endsWith('/auth/me/')) {
          return http.Response(
            jsonEncode({
              'email': 'abdullahazeem5352@gmail.com',
              'profile_picture_url': 'https://cdn.example.com/avatars/u1_v2.png',
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('{}', 404);
      });
      await ApiClient.instance.setAuthTokens(access: 'test_token');

      await AuthRepository.instance.updateCurrentUserProfile(
        profilePictureBytes: _samplePngBytes,
      );

      expect(calls, [
        'PATCH /api/v1/auth/me/',
        'POST /api/v1/auth/me/',
      ]);
      expect(
        UserProfileRepository.instance.profile.avatarUrl,
        'https://cdn.example.com/avatars/u1_v2.png',
      );
    });

    test(
        'fetchCurrentUserProfile and signIn sync remote profile_picture URL and replace stale local bytes when server URL changes',
        () async {
      AppConfig.debugOverrideCustomBackend = true;
      UserProfileRepository.instance.updateProfile(
        avatarBytes: _samplePngBytes,
        avatarUrl: 'https://cdn.example.com/avatars/u1_v1.png',
      );

      var remoteUrl = 'https://cdn.example.com/avatars/u1_v2.png';

      ApiClient.instance.customHttpClient = MockClient((request) async {
        if (request.method == 'GET' && request.url.path.endsWith('/auth/me/')) {
          return http.Response(
            jsonEncode({
              'email': 'abdullahazeem5352@gmail.com',
              'profile_picture': remoteUrl,
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.method == 'POST' &&
            request.url.path.endsWith('/auth/login/')) {
          return http.Response(
            jsonEncode({
              'access': 'jwt_access',
              'refresh': 'jwt_refresh',
              'user': {
                'email': 'abdullahazeem5352@gmail.com',
                'full_name': 'Abdullah Azeem',
                'is_profile_complete': true,
                'email_verified': true,
                'kyc_status': 'approved',
                'profile_picture': remoteUrl,
              },
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path.endsWith('/accounts/profile/')) {
          return http.Response(
            jsonEncode({'kyc_status': 'approved'}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path.endsWith('/banking/bank-accounts/')) {
          return http.Response('[]', 200);
        }
        return http.Response('{}', 200);
      });
      await ApiClient.instance.setAuthTokens(access: 'test_token');

      await AuthRepository.instance.fetchCurrentUserProfile();
      expect(UserProfileRepository.instance.profile.avatarUrl, remoteUrl);
      expect(UserProfileRepository.instance.profile.avatarBytes, isNull);

      remoteUrl = 'https://cdn.example.com/avatars/u1_v3.png';
      final result = await AuthRepository.instance.signIn(
        const SignInRequest(
          email: 'abdullahazeem5352@gmail.com',
          password: 'Password123!',
        ),
      );
      expect(result.profile.avatarUrl, remoteUrl);
      expect(result.profile.hasCustomAvatar, isTrue);
    });

    testWidgets(
        'AccountSettingsPage Remove Profile Picture syncs null profile_picture via PATCH /auth/me/',
        (WidgetTester tester) async {
      AppConfig.debugOverrideCustomBackend = true;
      Map<String, dynamic>? patchBody;

      ApiClient.instance.customHttpClient = MockClient((request) async {
        if (request.method == 'GET' && request.url.path.endsWith('/auth/me/')) {
          return http.Response(
            jsonEncode({'email': 'abdullahazeem5352@gmail.com'}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.method == 'PATCH' &&
            request.url.path.endsWith('/auth/me/')) {
          patchBody = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({
              'email': 'abdullahazeem5352@gmail.com',
              'profile_picture': null,
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path.endsWith('/banking/bank-accounts/')) {
          return http.Response('[]', 200);
        }
        return http.Response('{}', 200);
      });
      await ApiClient.instance.setAuthTokens(access: 'test_token');

      UserProfileRepository.instance.updateProfile(
        avatarBytes: _samplePngBytes,
        avatarUrl: 'https://cdn.example.com/avatars/u1_v1.png',
      );

      tester.view.physicalSize = const Size(412, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const AccountSettingsPage(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.camera_alt_outlined));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Remove Profile Picture'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      expect(patchBody, {'profile_picture': null});
      expect(UserProfileRepository.instance.profile.hasCustomAvatar, isFalse);
      expect(UserProfileRepository.instance.profile.avatarUrl, isNull);
      expect(
        find.text('Profile picture removed. Initial restored.'),
        findsOneWidget,
      );
    });
  });
}

