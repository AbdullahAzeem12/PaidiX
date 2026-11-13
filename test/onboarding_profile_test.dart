/// Tests the onboarding profile test behavior and guards its key user-facing and domain expectations.

import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:paidix/app/theme/app_theme.dart';
import 'package:paidix/features/profile/data/user_profile_repository.dart';
import 'package:paidix/features/profile/domain/user_profile.dart';
import 'package:paidix/features/profile/presentation/pages/onboarding_profile_page.dart';
import 'package:paidix/features/profile/presentation/widgets/document_viewer_dialog.dart';
import 'package:paidix/features/profile/presentation/widgets/edit_profile_dialog.dart';
import 'package:paidix/core/widgets/spongy_tap.dart';
import 'test_fixtures.dart';

final Uint8List _validPickerPng = Uint8List.fromList([
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
  0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89,
  0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41, 0x54,
  0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00, 0x05, 0x00, 0x01,
  0x0D, 0x0A, 0x2D, 0xB4,
  0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44,
  0xAE, 0x42, 0x60, 0x82,
]);

Future<void> _tapPicker(WidgetTester tester, Finder picker) async {
  debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
  try {
    await tester.ensureVisible(picker);
    await tester.tap(picker);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();
  } finally {
    debugDefaultTargetPlatformOverride = null;
  }
}

class MockImagePickerPlatform extends ImagePickerPlatform {
  /// Returns the test image-picker result for the requested source.
  @override
  Future<XFile?> getImageFromSource({
    required ImageSource source,
    ImagePickerOptions options = const ImagePickerOptions(),
  }) async {
    return XFile.fromData(
      _validPickerPng,
      name: 'mock_uploaded_doc.jpg',
      path: '/mock/path/mock_uploaded_doc.jpg',
    );
  }
}

/// Configures and launches the application or test suite.
void main() {
  setUp(() {
    ImagePickerPlatform.instance = MockImagePickerPlatform();
    setupTestState();
  });

  group('UserProfile & UserProfileRepository Tests', () {
    test(
        'Initial repository profile matches verified screenshot specifications',
        () {
      final p = UserProfileRepository.instance.profile;
      expect(p.fullName, 'Abdullah Azeem');
      expect(p.email, 'kherool66@gmail.com');
      expect(p.phoneNumber, '+923217649976');
      expect(p.cnicNumber, '35202-04504615');
      expect(p.city, 'لاہور');
      expect(p.address, 'Canalberg Housing Society');
      expect(p.avatarInitial, 'A');
      expect(p.firstName, 'Abdullah');
      expect(p.kycStatus, KycReviewStatus.pendingReview);
      expect(p.formattedCreatedAt, 'Oct 29, 2026, 01:09 AM');
      expect(p.formattedUpdatedAt, 'Oct 29, 2026, 09:33 PM');
    });

    test('syncFromSignUp updates name and email in real time', () {
      UserProfileRepository.instance.syncFromSignUp(
        fullName: 'Hassan Tariq',
        email: 'hassan@paidix.global',
        phoneNumber: '+923001234567',
      );

      final p = UserProfileRepository.instance.profile;
      expect(p.fullName, 'Hassan Tariq');
      expect(p.email, 'hassan@paidix.global');
      expect(p.phoneNumber, '+923001234567');
      expect(p.firstName, 'Hassan');
      expect(p.avatarInitial, 'H');
    });

    test('updateProfile modifies personal details and bumps timestamp', () {
      final beforeUpdate = UserProfileRepository.instance.profile.updatedAt;

      UserProfileRepository.instance.updateProfile(
        fullName: 'Abdullah Azeem Khan',
        phoneNumber: '+923219999999',
        city: 'Islamabad',
        address: 'Sector F-7/2',
      );

      final p = UserProfileRepository.instance.profile;
      expect(p.fullName, 'Abdullah Azeem Khan');
      expect(p.phoneNumber, '+923219999999');
      expect(p.city, 'Islamabad');
      expect(p.address, 'Sector F-7/2');
      expect(p.updatedAt.isAfter(beforeUpdate) || p.updatedAt == beforeUpdate,
          isTrue);
    });
  });

  group('OnboardingProfilePage Presentation & Widget Tests', () {
    testWidgets(
        'Renders all header elements and verified data fields accurately',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: const OnboardingProfilePage(),
        ),
      );
      await tester.pumpAndSettle();

      // Header Elements
      expect(find.text('PROFILE'), findsOneWidget);
      expect(find.text('Your profile & identity.'), findsOneWidget);
      expect(find.text('Personal information and KYC documents on file.'),
          findsOneWidget);
      expect(find.text('Edit profile'), findsOneWidget);

      // Left Profile Card
      expect(find.text('Abdullah Azeem'), findsOneWidget);
      expect(find.text('+923217649976'), findsWidgets);
      expect(find.text('CNIC NUMBER'), findsOneWidget);
      expect(find.text('35202-04504615'), findsOneWidget);
      expect(find.text('CITY'), findsOneWidget);
      expect(find.text('لاہور'), findsOneWidget);
      expect(find.text('ADDRESS'), findsOneWidget);
      expect(find.text('Canalberg Housing Society'), findsOneWidget);
      expect(find.text('PROFILE CREATED'), findsOneWidget);
      expect(find.text('Oct 29, 2026, 01:09 AM'), findsOneWidget);
      expect(find.text('LAST UPDATED'), findsOneWidget);

      // Right KYC Review Card
      expect(find.text('KYC REVIEW'), findsOneWidget);
      expect(find.text('Pending Review'), findsOneWidget);
      expect(find.text('SELFIE'), findsOneWidget);
      expect(find.text('CNIC — FRONT'), findsOneWidget);
      expect(find.text('CNIC — BACK'), findsOneWidget);
    });

    testWidgets(
        'Tapping document thumbnail opens high-resolution DocumentViewerDialog',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1024, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: const Scaffold(body: OnboardingProfilePage()),
        ),
      );
      await tester.pumpAndSettle();

      // Tap on CNIC — FRONT tile
      await tester.tap(find.text('CNIC — FRONT'));
      await tester.pumpAndSettle();

      // Verify DocumentViewerDialog is displayed
      expect(find.byType(DocumentViewerDialog), findsOneWidget);
      expect(find.text('CNIC Front Document'), findsWidgets);
      expect(find.textContaining('State Bank KYC Compliance'), findsOneWidget);
      expect(find.text('Close Inspector'), findsOneWidget);

      // Close Dialog
      await tester.tap(find.text('Close Inspector'));
      await tester.pumpAndSettle();
      expect(find.byType(DocumentViewerDialog), findsNothing);
    });

    testWidgets(
        'Tapping Edit profile opens modal and updates profile reactively',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1024, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: const Scaffold(body: OnboardingProfilePage()),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Edit Profile Button
      await tester.tap(find.text('Edit profile'));
      await tester.pumpAndSettle();

      // Verify EditProfileDialog appears
      expect(find.byType(EditProfileDialog), findsOneWidget);
      expect(find.text('Save & resubmit'), findsOneWidget);
      expect(find.text('RE-UPLOAD DOCUMENTS (OPTIONAL — LEAVE EMPTY TO KEEP CURRENT)'),
          findsOneWidget);
      expect(find.text('Choose file'), findsNWidgets(3));

      // Re-upload selfie document
      final dialogPickers = find.descendant(
        of: find.byType(EditProfileDialog),
        matching: find.byType(SpongyTap),
      );
      await _tapPicker(tester, dialogPickers.first);

      // Enter new name and city
      final nameField = find.byType(TextFormField).at(0);
      expect(nameField, findsOneWidget);
      await tester.enterText(nameField, 'Hamza Tariq');

      final cityField = find.byType(TextFormField).at(3);
      expect(cityField, findsOneWidget);
      await tester.enterText(cityField, 'Karachi');

      // Tap Save & resubmit
      await tester.tap(find.text('Save & resubmit'));
      await tester.pumpAndSettle();

      // Verify Dialog closed and UI reactively displays updated values
      expect(find.byType(EditProfileDialog), findsNothing);
      expect(find.text('Hamza Tariq'), findsOneWidget);
      expect(find.text('Karachi'), findsOneWidget);

      // Verify repository profile documents were updated in real time
      expect(UserProfileRepository.instance.profile.selfieBytes, isNotNull);
    });

    testWidgets('Zero overflow test on narrow 320px phone screen',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: const Scaffold(body: OnboardingProfilePage()),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Your profile & identity.'), findsOneWidget);
      expect(find.text('Abdullah Azeem'), findsOneWidget);
      expect(find.text('KYC REVIEW'), findsOneWidget);
    });
  });
}
