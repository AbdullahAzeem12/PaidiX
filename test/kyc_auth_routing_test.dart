/// Tests the kyc auth routing test behavior and guards its key user-facing and domain expectations.

import 'dart:typed_data';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:paidix/app/theme/app_theme.dart';
import 'package:paidix/core/widgets/app_shell.dart';
import 'package:paidix/features/auth/presentation/pages/sign_in_page.dart';
import 'package:paidix/features/kyc/domain/kyc_models.dart';
import 'package:paidix/features/profile/data/user_profile_repository.dart';
import 'package:paidix/features/profile/domain/user_profile.dart';
import 'test_fixtures.dart';

/// Configures and launches the application or test suite.
void main() {
  setUp(() {
    setupTestState();
  });

  group('One-Time KYC Verification Routing & Persistence Suite', () {
    testWidgets(
        'Onboarding navigation stays visible until the profile is verified',
        (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const AppShell(
            currentPath: '/app/dashboard',
            child: Scaffold(body: Text('Dashboard')),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Onboarding'), findsOneWidget);

      UserProfileRepository.instance.setActiveUser(
        UserProfileRepository.instance.profile.copyWith(
          hasCompletedKyc: true,
          kycStatus: KycReviewStatus.verified,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Onboarding'), findsNothing);
    });

    test('Default user has completed KYC and is registered in memory', () {
      final repo = UserProfileRepository.instance;
      expect(repo.profile.hasCompletedKyc, isTrue);
      expect(repo.profile.email, equals('kherool66@gmail.com'));

      final registered = repo.findUser('kherool66@gmail.com');
      expect(registered, isNotNull);
      expect(registered!.hasCompletedKyc, isTrue);

      final alias = repo.findUser('kheroali66@gmail.com');
      expect(alias, isNotNull);
      expect(alias!.hasCompletedKyc, isTrue);
    });

    test(
        'New user registration sets hasCompletedKyc = false and stores in registry',
        () {
      final repo = UserProfileRepository.instance;
      repo.syncFromSignUp(
        fullName: 'Zainab Tariq',
        email: 'zainab@example.com',
        phoneNumber: '03001234567',
        smsConsent: true,
      );

      expect(repo.profile.fullName, equals('Zainab Tariq'));
      expect(repo.profile.email, equals('zainab@example.com'));
      expect(repo.profile.hasCompletedKyc, isFalse);
      expect(repo.profile.kycStatus, equals(KycReviewStatus.notStarted));

      final savedUser = repo.findUser('zainab@example.com');
      expect(savedUser, isNotNull);
      expect(savedUser!.hasCompletedKyc, isFalse);
    });

    test(
        'syncFromKyc with submission marks hasCompletedKyc = true and saves all details permanently',
        () {
      final repo = UserProfileRepository.instance;
      repo.syncFromSignUp(
        fullName: 'Zainab Tariq',
        email: 'zainab@example.com',
        phoneNumber: '03001234567',
      );

      final kycState = KycState(
        currentStep: KycStep.bank,
        isSubmitted: true,
        personal: const PersonalInfo(
          fullName: 'Zainab Tariq',
          countryCode: '+92',
          phoneNumber: '3001234567',
          city: 'Karachi',
          address: 'Clifton Block 4',
          smsConsent: true,
        ),
        identity: const IdentityDocInfo(
          cnicNumber: '42201-1234567-1',
          frontFileName: 'cnic_f.jpg',
          backFileName: 'cnic_b.jpg',
        ),
        photo: const PhotoDocInfo(
          fileName: 'selfie.jpg',
        ),
        bank: const BankInfo(
          bankName: 'Habib Bank Limited',
          beneficiaryTitle: 'Zainab Tariq',
          iban: 'PK36HABB0001234567890123',
        ),
      );

      repo.syncFromKyc(kycState);

      expect(repo.profile.hasCompletedKyc, isTrue);
      expect(repo.profile.cnicNumber, equals('42201-1234567-1'));
      expect(repo.profile.city, equals('Karachi'));
      expect(repo.profile.address, equals('Clifton Block 4'));
      expect(repo.profile.bankName, equals('Habib Bank Limited'));
      expect(repo.profile.bankIban, equals('PK36HABB0001234567890123'));
      expect(repo.profile.kycStatus, equals(KycReviewStatus.pendingReview));

      // Check permanence in registered users map
      final saved = repo.findUser('zainab@example.com');
      expect(saved, isNotNull);
      expect(saved!.hasCompletedKyc, isTrue);
      expect(saved.city, equals('Karachi'));
    });

    testWidgets(
        'SignIn routes already verified user directly to /app/dashboard',
        (tester) async {
      String navigatedLocation = '';
      final testRouter = GoRouter(
        initialLocation: '/signin',
        routes: [
          GoRoute(
            path: '/signin',
            builder: (context, state) => const SignInPage(),
          ),
          GoRoute(
            path: '/kyc',
            builder: (context, state) {
              navigatedLocation = '/kyc';
              return const Scaffold(body: Text('KYC Page'));
            },
          ),
          GoRoute(
            path: '/app/dashboard',
            builder: (context, state) {
              navigatedLocation = '/app/dashboard';
              return const Scaffold(body: Text('Dashboard Page'));
            },
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp.router(
          theme: AppTheme.darkTheme,
          routerConfig: testRouter,
        ),
      );
      await tester.pumpAndSettle();

      // Enter Abdullah Azeem's email (already completed KYC)
      await tester.enterText(
          find.byType(TextFormField).at(0), 'kherool66@gmail.com');
      await tester.enterText(find.byType(TextFormField).at(1), 'password123');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sign in'));
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();

      // Must navigate straight to /app/dashboard, NOT /kyc
      expect(navigatedLocation, equals('/app/dashboard'));
    });

    testWidgets('SignIn routes newly registered unverified user to /kyc',
        (tester) async {
      // Register new user first
      UserProfileRepository.instance.syncFromSignUp(
        fullName: 'New Customer',
        email: 'newbie@gmail.com',
        phoneNumber: '03211112233',
      );

      String navigatedLocation = '';
      final testRouter = GoRouter(
        initialLocation: '/signin',
        routes: [
          GoRoute(
            path: '/signin',
            builder: (context, state) => const SignInPage(),
          ),
          GoRoute(
            path: '/kyc',
            builder: (context, state) {
              navigatedLocation = '/kyc';
              return const Scaffold(body: Text('KYC Page'));
            },
          ),
          GoRoute(
            path: '/app/dashboard',
            builder: (context, state) {
              navigatedLocation = '/app/dashboard';
              return const Scaffold(body: Text('Dashboard Page'));
            },
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp.router(
          theme: AppTheme.darkTheme,
          routerConfig: testRouter,
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
          find.byType(TextFormField).at(0), 'newbie@gmail.com');
      await tester.enterText(find.byType(TextFormField).at(1), 'password123');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sign in'));
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();

      // Must navigate to /kyc because hasCompletedKyc is false
      expect(navigatedLocation, equals('/kyc'));
    });

    testWidgets(
        'After completing KYC, user login routes straight to /app/dashboard without re-applying',
        (tester) async {
      final repo = UserProfileRepository.instance;
      repo.syncFromSignUp(
        fullName: 'Bilal Ahmad',
        email: 'bilal@gmail.com',
        phoneNumber: '03219876543',
      );

      // User completes KYC
      repo.markKycCompleted();

      String navigatedLocation = '';
      final testRouter = GoRouter(
        initialLocation: '/signin',
        routes: [
          GoRoute(
            path: '/signin',
            builder: (context, state) => const SignInPage(),
          ),
          GoRoute(
            path: '/kyc',
            builder: (context, state) {
              navigatedLocation = '/kyc';
              return const Scaffold(body: Text('KYC Page'));
            },
          ),
          GoRoute(
            path: '/app/dashboard',
            builder: (context, state) {
              navigatedLocation = '/app/dashboard';
              return const Scaffold(body: Text('Dashboard Page'));
            },
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp.router(
          theme: AppTheme.darkTheme,
          routerConfig: testRouter,
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
          find.byType(TextFormField).at(0), 'bilal@gmail.com');
      await tester.enterText(find.byType(TextFormField).at(1), 'password123');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sign in'));
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();

      // Must navigate straight to /app/dashboard
      expect(navigatedLocation, equals('/app/dashboard'));
    });

    test(
        'Updating profile details, documents, and avatar persists in registry and syncs across aliases',
        () {
      final repo = UserProfileRepository.instance;
      final dummyAvatar = Uint8List.fromList([10, 20, 30]);
      final dummySelfie = Uint8List.fromList([40, 50, 60]);
      final dummyFront = Uint8List.fromList([70, 80, 90]);
      final dummyBack = Uint8List.fromList([100, 110, 120]);

      repo.updateProfile(
        fullName: 'Abdullah Azeem Updated',
        phoneNumber: '+923217649976',
        cnicNumber: '35202-04504615',
        city: 'Lahore Model Town',
        address: 'House 42, Street 7',
        avatarBytes: dummyAvatar,
        selfieBytes: dummySelfie,
        cnicFrontBytes: dummyFront,
        cnicBackBytes: dummyBack,
      );

      // Verify active profile
      expect(repo.profile.fullName, equals('Abdullah Azeem Updated'));
      expect(repo.profile.city, equals('Lahore Model Town'));
      expect(repo.profile.address, equals('House 42, Street 7'));
      expect(repo.profile.avatarBytes, equals(dummyAvatar));
      expect(repo.profile.selfieBytes, equals(dummySelfie));
      expect(repo.profile.cnicFrontBytes, equals(dummyFront));
      expect(repo.profile.cnicBackBytes, equals(dummyBack));

      // Verify updated user in registry
      final userOol = repo.findUser('kherool66@gmail.com');
      expect(userOol, isNotNull);
      expect(userOol!.fullName, equals('Abdullah Azeem Updated'));
      expect(userOol.city, equals('Lahore Model Town'));
      expect(userOol.avatarBytes, equals(dummyAvatar));
    });

    testWidgets(
        'Re-login with kherool66@gmail.com restores all updated details, documents and routes to /app/dashboard',
        (tester) async {
      final repo = UserProfileRepository.instance;
      final dummyAvatar = Uint8List.fromList([1, 2, 3]);
      final dummySelfie = Uint8List.fromList([4, 5, 6]);

      repo.updateProfile(
        fullName: 'Abdullah Azeem (Verified Pro)',
        phoneNumber: '+923217649976',
        cnicNumber: '35202-04504615',
        city: 'Lahore Cantt',
        address: 'Phase 5 DHA',
        avatarBytes: dummyAvatar,
        selfieBytes: dummySelfie,
      );

      // Simulate logout: reset active profile to default blank/canonical
      repo.resetToDefault();

      String navigatedLocation = '';
      final testRouter = GoRouter(
        initialLocation: '/signin',
        routes: [
          GoRoute(
            path: '/signin',
            builder: (context, state) => const SignInPage(),
          ),
          GoRoute(
            path: '/kyc',
            builder: (context, state) {
              navigatedLocation = '/kyc';
              return const Scaffold(body: Text('KYC Page'));
            },
          ),
          GoRoute(
            path: '/app/dashboard',
            builder: (context, state) {
              navigatedLocation = '/app/dashboard';
              return const Scaffold(body: Text('Dashboard Page'));
            },
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp.router(
          theme: AppTheme.darkTheme,
          routerConfig: testRouter,
        ),
      );
      await tester.pumpAndSettle();

      // Enter kherool66@gmail.com and sign in
      await tester.enterText(
          find.byType(TextFormField).at(0), 'kherool66@gmail.com');
      await tester.enterText(find.byType(TextFormField).at(1), 'password123');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sign in'));
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();

      // Must navigate straight to /app/dashboard without re-applying KYC
      expect(navigatedLocation, equals('/app/dashboard'));

      // Active profile must restore all saved details and documents
      expect(repo.profile.fullName, equals('Abdullah Azeem (Verified Pro)'));
      expect(repo.profile.city, equals('Lahore Cantt'));
      expect(repo.profile.address, equals('Phase 5 DHA'));
      expect(repo.profile.avatarBytes, equals(dummyAvatar));
      expect(repo.profile.selfieBytes, equals(dummySelfie));
      expect(repo.profile.hasCompletedKyc, isTrue);
    });

    test(
        'UserProfile toJson and fromJson serialization roundtrip preserves all fields',
        () {
      final now = DateTime.now();
      final original = UserProfile(
        fullName: 'Abdullah Azeem',
        email: 'kheroali66@gmail.com',
        countryCode: '+92',
        phoneNumber: '+923217649976',
        cnicNumber: '35202-04504615',
        city: 'لاہور',
        address: 'Canalberg Housing Society',
        createdAt: now,
        updatedAt: now,
        kycStatus: KycReviewStatus.verified,
        hasCompletedKyc: true,
        smsConsent: true,
        selfieFilePath:
            '/data/user/0/com.paidix.paidix/users/kheroali66_gmail_com/selfie.jpg',
        cnicFrontFilePath:
            '/data/user/0/com.paidix.paidix/users/kheroali66_gmail_com/cnic_front.jpg',
        cnicBackFilePath:
            '/data/user/0/com.paidix.paidix/users/kheroali66_gmail_com/cnic_back.jpg',
        avatarFilePath:
            '/data/user/0/com.paidix.paidix/users/kheroali66_gmail_com/avatar.jpg',
        bankName: 'Meezan Bank Limited',
        bankIban: 'PK00MEZN0000000000000000',
        bankBeneficiary: 'Abdullah Azeem',
      );

      final json = original.toJson();
      final restored = UserProfile.fromJson(json);

      expect(restored.fullName, equals(original.fullName));
      expect(restored.email, equals(original.email));
      expect(restored.countryCode, equals(original.countryCode));
      expect(restored.phoneNumber, equals(original.phoneNumber));
      expect(restored.cnicNumber, equals(original.cnicNumber));
      expect(restored.city, equals(original.city));
      expect(restored.address, equals(original.address));
      expect(restored.kycStatus, equals(KycReviewStatus.verified));
      expect(restored.hasCompletedKyc, isTrue);
      expect(restored.selfieFilePath, equals(original.selfieFilePath));
      expect(restored.cnicFrontFilePath, equals(original.cnicFrontFilePath));
      expect(restored.cnicBackFilePath, equals(original.cnicBackFilePath));
      expect(restored.avatarFilePath, equals(original.avatarFilePath));
      expect(restored.bankName, equals(original.bankName));
      expect(restored.bankIban, equals(original.bankIban));
      expect(restored.bankBeneficiary, equals(original.bankBeneficiary));
    });
  });
}
