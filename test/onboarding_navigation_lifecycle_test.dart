/// Tests the dynamic visibility and retirement of the Onboarding navigation tab
/// across unverified/pending KYC vs server-verified states.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paidix/app/router.dart';
import 'package:paidix/app/theme/app_theme.dart';
import 'package:paidix/core/widgets/app_shell.dart';
import 'package:paidix/core/widgets/paidi_x_bottom_nav_bar.dart';
import 'package:paidix/features/profile/data/user_profile_repository.dart';
import 'package:paidix/features/profile/domain/user_profile.dart';

void main() {
  setUp(() {
    UserProfileRepository.instance.resetToDefault();
  });

  group('Onboarding Navigation Lifecycle & Server Verification Retirement Suite', () {
    testWidgets(
        'Newly registered user with pending KYC review sees Onboarding tab in mobile bottom bar and desktop sidebar',
        (WidgetTester tester) async {
      // Default initial profile has KycReviewStatus.pendingReview
      final profile = UserProfileRepository.instance.profile;
      expect(profile.kycStatus, KycReviewStatus.pendingReview);

      // 1. Mobile layout (width: 360)
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: const AppShell(
            currentPath: '/app/dashboard',
            child: Text('Dashboard Content'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Mobile bottom bar must show 4 tabs including Onboarding
      expect(find.byType(PaidiXBottomNavBar), findsOneWidget);
      expect(find.text('Dashboard'), findsOneWidget);
      expect(find.text('Onboarding'), findsOneWidget);
      expect(find.text('My Payments'), findsOneWidget);
      expect(find.text('New Payment'), findsOneWidget);

      // 2. Desktop layout (width: 1024)
      tester.view.physicalSize = const Size(1024, 800);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: const AppShell(
            currentPath: '/app/dashboard',
            child: Text('Dashboard Content'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Sidebar must include Onboarding nav item
      expect(find.text('Dashboard'), findsOneWidget);
      expect(find.text('Onboarding'), findsOneWidget);
      expect(find.text('My Payments'), findsOneWidget);
      expect(find.text('New Payment'), findsOneWidget);
    });

    testWidgets(
        'Server-verified user does NOT see Onboarding tab in bottom bar or sidebar',
        (WidgetTester tester) async {
      // Approve KYC verification from server side
      UserProfileRepository.instance.approveKycVerification();
      final profile = UserProfileRepository.instance.profile;
      expect(profile.kycStatus, KycReviewStatus.verified);

      // 1. Mobile layout (width: 360)
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: const AppShell(
            currentPath: '/app/dashboard',
            child: Text('Dashboard Content'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Mobile bottom bar must have exactly 3 tabs (Onboarding is completely gone)
      expect(find.byType(PaidiXBottomNavBar), findsOneWidget);
      expect(find.text('Dashboard'), findsOneWidget);
      expect(find.text('My Payments'), findsOneWidget);
      expect(find.text('New Payment'), findsOneWidget);
      expect(find.text('Onboarding'), findsNothing);

      // 2. Desktop layout (width: 1024)
      tester.view.physicalSize = const Size(1024, 800);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: const AppShell(
            currentPath: '/app/dashboard',
            child: Text('Dashboard Content'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Desktop sidebar must not contain Onboarding
      expect(find.text('Dashboard'), findsOneWidget);
      expect(find.text('My Payments'), findsOneWidget);
      expect(find.text('New Payment'), findsOneWidget);
      expect(find.text('Onboarding'), findsNothing);
    });

    testWidgets(
        'Router automatically redirects verified users away from /app/onboarding to /app/dashboard',
        (WidgetTester tester) async {
      UserProfileRepository.instance.approveKycVerification();
      expect(UserProfileRepository.instance.profile.kycStatus,
          KycReviewStatus.verified);

      final router = createAppRouter(initialLocation: '/app/onboarding');

      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: router,
          theme: AppTheme.darkTheme,
        ),
      );
      await tester.pumpAndSettle();

      // Route must have redirected to dashboard
      expect(router.routeInformationProvider.value.uri.path, '/app/dashboard');
      expect(find.text('YOUR MONEY, AT A GLANCE'), findsOneWidget);
    });
  });
}
