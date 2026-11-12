import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:paidix/app/theme/app_theme.dart';
import 'package:paidix/core/config/app_config.dart';
import 'package:paidix/core/network/api_client.dart';
import 'package:paidix/core/widgets/paidix_toast.dart';
import 'package:paidix/features/auth/data/auth_repository.dart';
import 'package:paidix/features/auth/domain/auth_models.dart';
import 'package:paidix/features/kyc/data/kyc_image_validation.dart';
import 'package:paidix/features/kyc/data/kyc_repository.dart';
import 'package:paidix/features/kyc/domain/kyc_models.dart';
import 'package:paidix/features/profile/data/user_profile_repository.dart';
import 'package:paidix/features/profile/domain/user_profile.dart';
import 'package:paidix/features/profile/presentation/widgets/edit_profile_dialog.dart';
import 'test_fixtures.dart';

/// Standard 1x1 RGBA PNG bytes for picker and multipart upload tests.
final Uint8List _validPngBytes = Uint8List.fromList([
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, // PNG signature
  0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, // IHDR
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, // 1x1
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89,
  0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41, 0x54, // IDAT
  0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00, 0x05, 0x00, 0x01,
  0x0D, 0x0A, 0x2D, 0xB4,
  0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, // IEND
  0xAE, 0x42, 0x60, 0x82,
]);

Uint8List _oversizedJpegBytes() {
  final bytes = Uint8List(KycImageValidation.maxFileSizeBytes + 1);
  bytes[0] = 0xFF;
  bytes[1] = 0xD8;
  bytes[2] = 0xFF;
  return bytes;
}

class _ConfigurableImagePickerPlatform extends ImagePickerPlatform {
  Uint8List nextBytes;
  String nextName;
  int calls = 0;

  _ConfigurableImagePickerPlatform({
    required this.nextBytes,
    this.nextName = 'picked.png',
  });

  @override
  Future<XFile?> getImageFromSource({
    required ImageSource source,
    ImagePickerOptions options = const ImagePickerOptions(),
  }) async {
    calls++;
    return XFile.fromData(
      nextBytes,
      name: nextName,
      path: '/mock/$nextName',
    );
  }
}

Map<String, dynamic> _backendResubmittedPayload({
  String email = 'customer@example.com',
  String fullName = 'Abdullah Azeem',
  String phone = '+923217649976',
  String cnic = '35202-0450461-5',
  String city = 'لاہور',
  String address = '9-H Canal Berg Housing Society Lahore',
}) {
  return {
    'id': 'c0a80123-0000-0000-0000-000000000001',
    'user': 'b0a80123-0000-0000-0000-000000000001',
    'user_email': email,
    'full_name': fullName,
    'phone': phone,
    'cnic_number': cnic,
    'address': address,
    'city': city,
    'cnic_front_url': 'https://storage.example.com/profiles/cnic_front.jpg',
    'cnic_back_url': 'https://storage.example.com/profiles/cnic_back.jpg',
    'selfie_url': 'https://storage.example.com/profiles/selfie.jpg',
    'kyc_status': 'resubmitted',
    'kyc_notes': 'Previous rejection reason',
    'kyc_reviewed_at': '2026-11-10T14:20:00Z',
    'kyc_reviewed_by_email': 'admin@example.com',
    'kyc_objections': const [],
    'kyc_objection_round': 1,
    'kyc_approved_at': null,
    'kyc_last_resubmit_at': '2026-11-11T18:41:00Z',
    'kyc_last_resubmit_changes': const ['cnic_front', 'cnic_back', 'selfie'],
    'is_locked': false,
    'created_at': '2026-11-01T10:00:00Z',
    'updated_at': '2026-11-11T18:41:00Z',
  };
}

void main() {
  setUp(() async {
    setupTestState();
    AppConfig.debugOverrideCustomBackend = true;
    ApiClient.instance.customHttpClient = null;
    await ApiClient.instance.setAuthTokens(
      access: 'test_access_token',
      refresh: 'test_refresh_token',
    );
  });

  tearDown(() async {
    PaidiXToast.dismissCurrent();
    AppConfig.debugOverrideCustomBackend = null;
    ApiClient.instance.customHttpClient = null;
    await ApiClient.instance.clearSession();
  });

  group('Max 5 MB image validation', () {
    test('allows images up to 5 MB and rejects images over 5 MB', () async {
      final exactFiveMb = Uint8List(KycImageValidation.maxFileSizeBytes);
      exactFiveMb[0] = 0xFF;
      exactFiveMb[1] = 0xD8;
      exactFiveMb[2] = 0xFF;

      expect(
        () => KycImageValidation.validateForUpload(
          exactFiveMb,
          documentLabel: 'CNIC Front',
        ),
        returnsNormally,
      );

      final tooBig = _oversizedJpegBytes();
      expect(
        () => KycImageValidation.validateForUpload(
          tooBig,
          documentLabel: 'CNIC Front',
        ),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('5 MB'),
          ),
        ),
      );

      await expectLater(
        KycImageValidation.validate(tooBig, documentLabel: 'Selfie'),
        throwsA(isA<FormatException>()),
      );
    });

    test('KycRepository and AuthRepository reject uploads > 5 MB before HTTP',
        () async {
      var httpCallCount = 0;
      ApiClient.instance.customHttpClient = MockClient((_) async {
        httpCallCount++;
        return http.Response('{}', 200);
      });

      final oversized = _oversizedJpegBytes();
      final rejectedProfile = createTestProfile(
        email: 'customer@example.com',
        kycStatus: KycReviewStatus.rejected,
      );

      await expectLater(
        KycRepository.instance.resubmitEditedProfile(
          profile: rejectedProfile,
          selfieBytes: oversized,
          cnicFrontBytes: _validPngBytes,
          cnicBackBytes: _validPngBytes,
        ),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 422)
              .having((e) => e.message, 'message', contains('5 MB')),
        ),
      );

      await expectLater(
        KycRepository.instance.processKycImages(frontBytes: oversized),
        throwsA(isA<FormatException>()),
      );

      await expectLater(
        AuthRepository.instance.updateCurrentUserProfile(
          profilePictureBytes: oversized,
        ),
        throwsA(isA<FormatException>()),
      );

      expect(httpCallCount, 0);
    });
  });

  group('PATCH /accounts/profile/ KYC resubmission API', () {
    test(
        'resubmitEditedProfile sends PATCH multipart without kyc_status or is_resubmission',
        () async {
      final methods = <String>[];
      final paths = <String>[];
      var capturedAuth = '';
      var capturedContentType = '';
      var capturedBody = '';

      ApiClient.instance.customHttpClient = MockClient((request) async {
        methods.add(request.method);
        paths.add(request.url.path);
        capturedAuth = request.headers['Authorization'] ?? '';
        capturedContentType = request.headers['content-type'] ?? '';
        capturedBody = utf8.decode(request.bodyBytes, allowMalformed: true);

        return http.Response(
          jsonEncode(_backendResubmittedPayload()),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final profile = createTestProfile(
        email: 'customer@example.com',
        fullName: 'Abdullah Azeem',
        phoneNumber: '03217649976',
        cnicNumber: '3520204504615',
        city: 'لاہور',
        address: '9-H Canal Berg Housing Society Lahore',
        kycStatus: KycReviewStatus.rejected,
      );

      final response = await KycRepository.instance.resubmitEditedProfile(
        profile: profile,
        selfieBytes: _validPngBytes,
        cnicFrontBytes: _validPngBytes,
        cnicBackBytes: _validPngBytes,
      );

      expect(methods, equals(['PATCH']));
      expect(paths, equals(['/api/v1/accounts/profile/']));
      expect(capturedAuth, equals('Bearer test_access_token'));
      expect(capturedContentType, contains('multipart/form-data'));

      // Must NOT send kyc_status or is_resubmission
      expect(capturedBody.contains('name="kyc_status"'), isFalse);
      expect(capturedBody.contains('name="is_resubmission"'), isFalse);

      // Required schema fields & normalized formats
      expect(capturedBody.contains('name="full_name"'), isTrue);
      expect(capturedBody.contains('Abdullah Azeem'), isTrue);
      expect(capturedBody.contains('name="phone"'), isTrue);
      expect(capturedBody.contains('+923217649976'), isTrue);
      expect(capturedBody.contains('name="cnic_number"'), isTrue);
      expect(capturedBody.contains('35202-0450461-5'), isTrue);
      expect(capturedBody.contains('name="city"'), isTrue);
      expect(capturedBody.contains('لاہور'), isTrue);
      expect(capturedBody.contains('name="address"'), isTrue);
      expect(capturedBody.contains('9-H Canal Berg Housing Society Lahore'),
          isTrue);
      expect(capturedBody.contains('name="cnic_front"'), isTrue);
      expect(capturedBody.contains('name="cnic_back"'), isTrue);
      expect(capturedBody.contains('name="selfie"'), isTrue);
      expect(response['kyc_status'], equals('resubmitted'));
    });

    test(
        'patchMultipart refreshes expired token and rebuilds filesBuilder safely',
        () async {
      await ApiClient.instance.setAuthTokens(
        access: 'expired_access',
        refresh: 'valid_refresh',
      );
      final attempts = <String>[];

      ApiClient.instance.customHttpClient = MockClient((request) async {
        attempts.add('${request.method} ${request.url.path}');
        if (request.url.path.endsWith('/auth/refresh/')) {
          return http.Response(
            jsonEncode({'access': 'fresh_access'}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.headers['Authorization'] == 'Bearer expired_access') {
          return http.Response(
            jsonEncode({'code': 'token_not_valid', 'detail': 'Token expired'}),
            401,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response(
          jsonEncode(_backendResubmittedPayload()),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final profile = createTestProfile(
        email: 'customer@example.com',
        kycStatus: KycReviewStatus.rejected,
      );
      final response = await KycRepository.instance.resubmitEditedProfile(
        profile: profile,
        selfieBytes: _validPngBytes,
      );

      expect(
        attempts,
        equals([
          'PATCH /api/v1/accounts/profile/',
          'POST /api/v1/auth/refresh/',
          'PATCH /api/v1/accounts/profile/',
        ]),
      );
      expect(response['kyc_status'], equals('resubmitted'));
    });

    test(
        'submitKyc uses PATCH /accounts/profile/ when rejected and POST /accounts/profile/ when initial',
        () async {
      final profileRequests =
          <({String method, String path, String body})>[];

      ApiClient.instance.customHttpClient = MockClient((request) async {
        if (request.url.path.endsWith('/accounts/profile/')) {
          profileRequests.add((
            method: request.method,
            path: request.url.path,
            body: utf8.decode(request.bodyBytes, allowMalformed: true),
          ));
          return http.Response(
            jsonEncode(
              request.method == 'PATCH'
                  ? _backendResubmittedPayload()
                  : {'kyc_status': 'PENDING'},
            ),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response(jsonEncode({'ok': true}), 200);
      });

      final kycState = KycState(
        personal: const PersonalInfo(
          fullName: 'Abdullah Azeem',
          countryCode: '+92',
          phoneNumber: '3217649976',
          city: 'لاہور',
          address: '9-H Canal Berg Housing Society Lahore',
          smsConsent: true,
        ),
        identity: IdentityDocInfo(
          cnicNumber: '35202-0450461-5',
          frontBytes: _validPngBytes,
          backBytes: _validPngBytes,
        ),
        photo: PhotoDocInfo(bytes: _validPngBytes),
        bank: const BankInfo(
          bankName: 'Meezan Bank Limited',
          beneficiaryTitle: 'Abdullah Azeem',
          accountNumber: '01010102030405',
        ),
      );

      // 1. Rejected user -> Fix & resubmit uses PATCH without kyc_status/is_resubmission
      UserProfileRepository.instance.setActiveUser(
        createTestProfile(
          email: 'customer@example.com',
          kycStatus: KycReviewStatus.rejected,
        ),
      );
      await KycRepository.instance.submitKyc(kycState);

      expect(profileRequests.length, equals(1));
      expect(profileRequests.first.method, equals('PATCH'));
      expect(profileRequests.first.body.contains('name="kyc_status"'), isFalse);
      expect(profileRequests.first.body.contains('name="is_resubmission"'),
          isFalse);
      expect(UserProfileRepository.instance.profile.hasResubmittedKyc, isTrue);
      expect(
        UserProfileRepository.instance.profile.kycResubmittedAt,
        equals(DateTime.parse('2026-11-11T18:41:00Z')),
      );

      profileRequests.clear();

      // 2. Initial user -> first-time KYC keeps POST /accounts/profile/
      UserProfileRepository.instance.setActiveUser(
        createTestProfile(
          email: 'fresh@example.com',
          kycStatus: KycReviewStatus.notStarted,
          hasCompletedKyc: false,
        ),
      );
      await KycRepository.instance.submitKyc(kycState);

      expect(profileRequests.length, equals(1));
      expect(profileRequests.first.method, equals('POST'));
    });

    test(
        'signIn recognizes backend resubmitted response & kyc_last_resubmit_at',
        () async {
      ApiClient.instance.customHttpClient = MockClient((request) async {
        if (request.url.path.endsWith('/auth/login/')) {
          return http.Response(
            jsonEncode({
              'access': 'jwt_access',
              'refresh': 'jwt_refresh',
              'user': {
                'email': 'customer@example.com',
                'full_name': 'Abdullah Azeem',
                'is_profile_complete': true,
                'email_verified': true,
                'kyc_status': 'resubmitted',
              },
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path.endsWith('/auth/me/')) {
          return http.Response(
            jsonEncode({'email': 'customer@example.com'}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path.endsWith('/accounts/profile/')) {
          return http.Response(
            jsonEncode(_backendResubmittedPayload()),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('{}', 200);
      });

      final auth = await AuthRepository.instance.signIn(
        const SignInRequest(
          email: 'customer@example.com',
          password: 'Password123!',
        ),
      );

      expect(auth.profile.kycStatus, equals(KycReviewStatus.pendingReview));
      expect(auth.profile.hasResubmittedKyc, isTrue);
      expect(
        auth.profile.kycResubmittedAt,
        equals(DateTime.parse('2026-11-11T18:41:00Z')),
      );
      expect(auth.profile.kycRejectionReason, isNull);
    });

    testWidgets(
        'EditProfileDialog enforces 5 MB limit and resubmits rejected profile via PATCH /accounts/profile/',
        (tester) async {
      final picker = _ConfigurableImagePickerPlatform(
        nextBytes: _oversizedJpegBytes(),
        nextName: 'huge_photo.jpg',
      );
      ImagePickerPlatform.instance = picker;

      final methods = <String>[];
      ApiClient.instance.customHttpClient = MockClient((request) async {
        methods.add(request.method);
        return http.Response(
          jsonEncode(_backendResubmittedPayload()),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final rejectedProfile = createTestProfile(
        email: 'customer@example.com',
        cnicNumber: '35202-0450461-5',
        kycStatus: KycReviewStatus.rejected,
      );
      UserProfileRepository.instance.setActiveUser(rejectedProfile);

      tester.view.physicalSize = const Size(900, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Builder(
            builder: (ctx) => Scaffold(
              body: ElevatedButton(
                onPressed: () => EditProfileDialog.show(ctx, rejectedProfile),
                child: const Text('Open Edit'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open Edit'));
      await tester.pumpAndSettle();

      // 1. Oversized (> 5 MB) pick must be rejected without choosing the file
      await tester.ensureVisible(find.text('Choose file').at(0));
      await tester.tap(find.text('Choose file').at(0));
      await tester.pumpAndSettle();
      expect(picker.calls, equals(1));
      expect(find.text('huge_photo.jpg'), findsNothing);
      expect(find.textContaining('must be 5 MB or smaller'), findsOneWidget);
      PaidiXToast.dismissCurrent();
      await tester.pumpAndSettle();

      // 2. Valid <= 5 MB picks succeed for all three KYC documents
      picker.nextBytes = _validPngBytes;
      picker.nextName = 'valid_doc.png';
      for (var i = 0; i < 3; i++) {
        await tester.ensureVisible(find.text('Choose file').at(i));
        await tester.tap(find.text('Choose file').at(i));
        await tester.pumpAndSettle();
      }

      expect(picker.calls, equals(4));
      expect(find.textContaining('valid_doc.png'), findsNWidgets(3));

      // 3. Save & resubmit sends PATCH /accounts/profile/ and transitions profile
      await tester.ensureVisible(find.text('Save & resubmit'));
      await tester.tap(find.text('Save & resubmit'));
      await tester.pumpAndSettle();

      expect(methods, equals(['PATCH']));
      expect(find.byType(EditProfileDialog), findsNothing);
      expect(
        UserProfileRepository.instance.profile.kycStatus,
        equals(KycReviewStatus.pendingReview),
      );
      expect(
        UserProfileRepository.instance.profile.hasResubmittedKyc,
        isTrue,
      );
      expect(
        UserProfileRepository.instance.profile.kycResubmittedAt,
        equals(DateTime.parse('2026-11-11T18:41:00Z')),
      );
      await tester.pump(const Duration(seconds: 5));
    });
  });
}
