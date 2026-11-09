/// Tests the ApiClient, AuthRepository, and KycRepository backend network integration.

import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:paidix/core/config/app_config.dart';
import 'package:paidix/core/network/api_client.dart';
import 'package:paidix/features/auth/data/auth_repository.dart';
import 'package:paidix/features/auth/domain/auth_models.dart';
import 'package:paidix/features/kyc/data/kyc_repository.dart';
import 'package:paidix/features/kyc/domain/kyc_models.dart';
import 'package:paidix/features/profile/data/user_profile_repository.dart';
import 'package:paidix/features/profile/domain/user_profile.dart';
import 'test_fixtures.dart';

void main() {
  setUp(() {
    setupTestState();
    ApiClient.instance.customHttpClient = null;
  });

  group('ApiClient & Network Architecture Suite', () {
    test('ApiClient builds correct headers including API key and auth token', () async {
      final client = ApiClient.instance;
      await client.setAuthToken('test_jwt_session_token_123');

      final mockHttp = MockClient((request) async {
        if (AppConfig.clientApiKey.isNotEmpty) {
          expect(request.headers['X-Client-Key'], equals(AppConfig.clientApiKey));
        } else {
          expect(request.headers.containsKey('X-Client-Key'), isFalse);
        }
        expect(request.headers['Authorization'], equals('Bearer test_jwt_session_token_123'));
        expect(request.headers['Content-Type'], contains('application/json'));

        return http.Response(
          jsonEncode({'success': true, 'message': 'OK'}),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      client.customHttpClient = mockHttp;
      final response = await client.post('/test', body: {'sample': 'data'});
      expect(response['success'], isTrue);
    });

    test('ApiClient throws structured ApiException on HTTP 401/500 errors', () async {
      final client = ApiClient.instance;

      final mockHttp = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'success': false,
            'message': 'Invalid credentials provided.',
            'errorCode': 'ERR_AUTH_INVALID_CREDENTIALS',
          }),
          401,
          headers: {'content-type': 'application/json'},
        );
      });

      client.customHttpClient = mockHttp;

      expect(
        () => client.post('/auth/signin', body: {'email': 'test@example.com'}),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 401)
              .having((e) => e.errorCode, 'errorCode', 'ERR_AUTH_INVALID_CREDENTIALS'),
        ),
      );
    });

    test('AuthRepository authenticates and syncs user session correctly', () async {
      final authRepo = AuthRepository.instance;
      final result = await authRepo.signIn(
        const SignInRequest(
          email: 'kherool66@gmail.com',
          password: 'password123',
        ),
      );

      expect(result.profile.email, equals('kherool66@gmail.com'));
      expect(result.profile.hasCompletedKyc, isTrue);
    });

    test('AuthRepository simulated 503 error throws structured ApiException', () async {
      final authRepo = AuthRepository.instance;

      expect(
        () => authRepo.signIn(
          const SignInRequest(
            email: '500_gateway_error@paidix.com',
            password: 'password123',
          ),
        ),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 503)
              .having((e) => e.errorCode, 'errorCode', 'ERR_AUTH_503_UNAVAILABLE'),
        ),
      );
    });

    test('KycRepository submits KYC state and marks profile completed', () async {
      final kycRepo = KycRepository.instance;
      const state = KycState(
        currentStep: KycStep.bank,
        personal: PersonalInfo(
          fullName: 'Test User',
          countryCode: '+92',
          phoneNumber: '3001234567',
          city: 'Lahore',
          address: 'Gulberg III',
        ),
        identity: IdentityDocInfo(
          cnicNumber: '35201-1234567-1',
        ),
        bank: BankInfo(
          bankName: 'Meezan Bank Limited',
          beneficiaryTitle: 'Test User',
          accountNumber: '01020304050607',
        ),
      );

      final success = await kycRepo.submitKyc(state);
      expect(success, isTrue);
      expect(UserProfileRepository.instance.profile.hasCompletedKyc, isTrue);
      expect(
        UserProfileRepository.instance.profile.kycStatus,
        KycReviewStatus.pendingReview,
      );
    });

    test('ApiClient handles DELETE requests and PATCH requests', () async {
      final client = ApiClient.instance;

      final mockHttp = MockClient((request) async {
        if (request.method == 'DELETE') {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['current_pin'], equals('1234'));
          return http.Response(jsonEncode({'detail': 'PIN removed.'}), 200);
        } else if (request.method == 'PATCH') {
          return http.Response(jsonEncode({'detail': 'Updated.'}), 200);
        }
        return http.Response('Not Found', 404);
      });

      client.customHttpClient = mockHttp;
      final delRes = await client.delete('/auth/payments-pin/', body: {'current_pin': '1234'});
      expect(delRes['detail'], equals('PIN removed.'));

      final patchRes = await client.patch('/auth/onboarding-step/', body: {'step': 1});
      expect(patchRes['detail'], equals('Updated.'));
    });

    test('ApiClient stores refresh token and executes refreshAccessToken', () async {
      final client = ApiClient.instance;
      await client.setAuthTokens(access: 'expired_access_token', refresh: 'valid_refresh_token_7d');

      expect(client.authToken, equals('expired_access_token'));
      expect(client.refreshToken, equals('valid_refresh_token_7d'));

      final mockHttp = MockClient((request) async {
        if (request.url.path.endsWith('/auth/refresh/')) {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['refresh'], equals('valid_refresh_token_7d'));
          return http.Response(
            jsonEncode({'access': 'brand_new_access_token_60m'}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not Found', 404);
      });

      client.customHttpClient = mockHttp;
      final refreshed = await client.refreshAccessToken();
      expect(refreshed, isTrue);
      expect(client.authToken, equals('brand_new_access_token_60m'));
    });

    test('AppConfig.sanitizeUrl handles malformed prefixes, quotes, and duplicated schemes', () {
      expect(
        AppConfig.sanitizeUrl('https:https://201.79.42.93.nip.io/api/v1/'),
        equals('https://201.79.42.93.nip.io/api/v1'),
      );
      expect(
        AppConfig.sanitizeUrl('https://https://201.79.42.93.nip.io/api/v1'),
        equals('https://201.79.42.93.nip.io/api/v1'),
      );
      expect(
        AppConfig.sanitizeUrl('"https://201.79.42.93.nip.io/api/v1"'),
        equals('https://201.79.42.93.nip.io/api/v1'),
      );
      expect(
        AppConfig.sanitizeUrl("'http://10.0.2.2:8000/'"),
        equals('http://10.0.2.2:8000'),
      );
      expect(
        AppConfig.sanitizeUrl('201.79.42.93.nip.io/api/v1'),
        equals('https://201.79.42.93.nip.io/api/v1'),
      );
    });

    test('ApiClient cleans and normalizes URIs and handles all status codes', () async {
      final client = ApiClient.instance;

      final mockHttp = MockClient((request) async {
        // Assert URI host is correctly parsed without double scheme
        expect(request.url.host, isNotEmpty);
        expect(request.url.scheme, equals('https'));

        if (request.url.path.contains('/status/304')) {
          return http.Response('', 304);
        } else if (request.url.path.contains('/status/429')) {
          return http.Response(
            jsonEncode({'detail': 'Rate limit exceeded.'}),
            429,
            headers: {'retry-after': '30', 'content-type': 'application/json'},
          );
        } else if (request.url.path.contains('/status/502')) {
          return http.Response(
            jsonEncode({'detail': 'Bad gateway upstream.'}),
            502,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response(jsonEncode({'ok': true}), 200);
      });

      client.customHttpClient = mockHttp;

      // 304 Not Modified
      final res304 = await client.get('/status/304');
      expect(res304, isEmpty);

      // 429 Too Many Requests
      expect(
        () => client.get('/status/429'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 429)
              .having((e) => e.retryAfterSeconds, 'retryAfterSeconds', 30)
              .having((e) => e.isRetryable, 'isRetryable', isTrue),
        ),
      );

      // 502 Bad Gateway
      expect(
        () => client.get('/status/502'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 502)
              .having((e) => e.isRetryable, 'isRetryable', isTrue),
        ),
      );
    });
  });
}

