/// Tests phone pre-population logic, phone parsing, and safe image permissions handling.

import 'dart:typed_data';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paidix/core/utils/permission_helper.dart';
import 'package:paidix/core/utils/phone_formatter.dart';
import 'package:paidix/features/kyc/domain/kyc_models.dart';
import 'package:paidix/features/kyc/presentation/widgets/step1_personal_view.dart';
import 'package:paidix/features/profile/data/user_profile_repository.dart';
import 'package:paidix/features/profile/domain/user_profile.dart';
import 'test_fixtures.dart';

void main() {
  setUp(() {
    setupTestState();
  });

  group('PhoneFormatter.parse Suite', () {
    test('Correctly parses E.164 Pakistani phone number', () {
      final (country, formatted) = PhoneFormatter.parse('+923217649975');
      expect(country, equals(CountryCodeOption.pk));
      expect(formatted, equals('321 7649975'));
    });

    test('Correctly parses spaced Pakistani phone number', () {
      final (country, formatted) = PhoneFormatter.parse('+92 321 7649975');
      expect(country, equals(CountryCodeOption.pk));
      expect(formatted, equals('321 7649975'));
    });

    test('Correctly parses national zero-prefixed Pakistani number', () {
      final (country, formatted) = PhoneFormatter.parse('03217649975');
      expect(country, equals(CountryCodeOption.pk));
      expect(formatted, equals('321 7649975'));
    });

    test('Correctly parses raw 10-digit Pakistani national number', () {
      final (country, formatted) = PhoneFormatter.parse('3217649975');
      expect(country, equals(CountryCodeOption.pk));
      expect(formatted, equals('321 7649975'));
    });

    test('Correctly parses US phone numbers', () {
      final (country, formatted) = PhoneFormatter.parse('+15550123456');
      expect(country, equals(CountryCodeOption.us));
      expect(formatted, equals('(555) 012-3456'));
    });

    test('Returns default country when string is empty', () {
      final (country, formatted) = PhoneFormatter.parse('', defaultCountry: CountryCodeOption.pk);
      expect(country, equals(CountryCodeOption.pk));
      expect(formatted, isEmpty);
    });
  });

  group('Step1PersonalView Phone Pre-population Suite', () {
    testWidgets('Pre-populates phone number from UserProfileRepository fallback', (tester) async {
      // Seed registered user profile with phone number
      UserProfileRepository.instance.setProfileForTesting(
        UserProfile.empty().copyWith(
          fullName: 'Abdullah Azeem',
          email: 'abdullah@example.com',
          phoneNumber: '+923217649975',
          countryCode: '+92',
        ),
      );

      // Create Step1 with empty personalInfo phone
      var personalInfo = const PersonalInfo(
        fullName: 'Abdullah Azeem',
        countryCode: '+92',
        phoneNumber: '',
        smsConsent: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Step1PersonalView(
                personalInfo: personalInfo,
                onChanged: (updated) => personalInfo = updated,
                onContinue: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Controller should have pre-populated formatted number in TextField
      expect(
        find.byWidgetPredicate((w) => w is TextField && w.controller?.text == '321 7649975'),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate((w) => w is TextField && w.controller?.text == 'Abdullah Azeem'),
        findsOneWidget,
      );
    });

    testWidgets('Updates phone when didUpdateWidget receives server draft', (tester) async {
      UserProfileRepository.instance.setProfileForTesting(
        UserProfile.empty().copyWith(
          fullName: 'Initial User',
          email: 'test@example.com',
          phoneNumber: '',
        ),
      );

      var personalInfo = const PersonalInfo(
        fullName: 'Initial User',
        countryCode: '+92',
        phoneNumber: '',
        smsConsent: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: StatefulBuilder(
                builder: (context, setState) {
                  return Step1PersonalView(
                    personalInfo: personalInfo,
                    onChanged: (updated) => personalInfo = updated,
                    onContinue: () {},
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Simulate asynchronous server draft load delivering phone number
      personalInfo = personalInfo.copyWith(phoneNumber: '+923001234567');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: StatefulBuilder(
                builder: (context, setState) {
                  return Step1PersonalView(
                    personalInfo: personalInfo,
                    onChanged: (updated) => personalInfo = updated,
                    onContinue: () {},
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byWidgetPredicate((w) => w is TextField && w.controller?.text == '300 1234567'),
        findsOneWidget,
      );
    });
  });

  group('PermissionHelper Safety Suite', () {
    test('safeDownscaleBytes returns untouched for small or empty byte buffers', () async {
      final empty = Uint8List(0);
      expect(await PermissionHelper.safeDownscaleBytes(empty), equals(empty));

      final small = Uint8List.fromList(List.generate(100, (i) => i));
      expect(await PermissionHelper.safeDownscaleBytes(small), equals(small));
    });
  });
}
