/// Tests the dynamic visibility and retirement of the Onboarding navigation tab
/// across unverified/pending KYC vs server-verified states.

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:paidix/app/router.dart';
import 'package:paidix/app/theme/app_theme.dart';
import 'package:paidix/core/widgets/app_shell.dart';
import 'package:paidix/core/widgets/paidi_x_bottom_nav_bar.dart';
import 'package:paidix/features/profile/data/user_profile_repository.dart';
import 'package:paidix/features/profile/domain/user_profile.dart';

import 'test_fixtures.dart';

Future<void> _pumpShell(WidgetTester tester) async {
  final router = GoRouter(
    initialLocation: '/app/dashboard',
    routes: [
      GoRoute(
        path: '/app/dashboard',
        builder: (context, state) => const AppShell(
          currentPath: '/app/dashboard',
          child: Text('Dashboard Content'),
        ),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    MaterialApp.router(routerConfig: router, theme: AppTheme.darkTheme),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    setupTestState();
  });

  group(
    'Onboarding Navigation Lifecycle & Server Verification Retirement Suite',
    () {
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

          await _pumpShell(tester);

          // Mobile bottom bar must show 4 tabs including Onboarding
          expect(find.byType(PaidiXBottomNavBar), findsOneWidget);
          expect(find.text('Dashboard'), findsOneWidget);
          expect(find.text('Onboarding'), findsOneWidget);
          expect(find.text('My Payments'), findsOneWidget);
          expect(find.text('New Payment'), findsOneWidget);

          // 2. Desktop layout (width: 1024)
          tester.view.physicalSize = const Size(1024, 800);
          await _pumpShell(tester);

          // Sidebar must include Onboarding nav item
          expect(find.text('Dashboard'), findsOneWidget);
          expect(find.text('Onboarding'), findsOneWidget);
          expect(find.text('My Payments'), findsOneWidget);
          expect(find.text('New Payment'), findsOneWidget);
        },
      );

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

          await _pumpShell(tester);

          // Mobile bottom bar must have exactly 3 tabs (Onboarding is completely gone)
          expect(find.byType(PaidiXBottomNavBar), findsOneWidget);
          expect(find.text('Dashboard'), findsOneWidget);
          expect(find.text('My Payments'), findsOneWidget);
          expect(find.text('New Payment'), findsOneWidget);
          expect(find.text('Onboarding'), findsNothing);

          // 2. Desktop layout (width: 1024)
          tester.view.physicalSize = const Size(1024, 800);
          await _pumpShell(tester);

          // Desktop sidebar must not contain Onboarding
          expect(find.text('Dashboard'), findsOneWidget);
          expect(find.text('My Payments'), findsOneWidget);
          expect(find.text('New Payment'), findsOneWidget);
          expect(find.text('Onboarding'), findsNothing);
        },
      );

      testWidgets(
        'Router automatically redirects verified users away from /app/onboarding to /app/dashboard',
        (WidgetTester tester) async {
          UserProfileRepository.instance.approveKycVerification();
          expect(
            UserProfileRepository.instance.profile.kycStatus,
            KycReviewStatus.verified,
          );

          final router = createAppRouter(initialLocation: '/app/onboarding');

          await tester.pumpWidget(
            MaterialApp.router(routerConfig: router, theme: AppTheme.darkTheme),
          );
          await tester.pumpAndSettle();

          // Route must have redirected to dashboard
          expect(
            router.routeInformationProvider.value.uri.path,
            '/app/dashboard',
          );
          expect(find.text('YOUR MONEY, AT A GLANCE'), findsOneWidget);
        },
      );

      testWidgets(
        'KYC resubmit after login keeps Onboarding until server/admin verification',
        (WidgetTester tester) async {
          UserProfileRepository.instance.markKycPendingReview();
          expect(
            UserProfileRepository.instance.profile.kycStatus,
            KycReviewStatus.pendingReview,
          );
          expect(
            UserProfileRepository.instance.profile.hasCompletedKyc,
            isTrue,
          );

          tester.view.physicalSize = const Size(360, 800);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          await _pumpShell(tester);

          expect(find.text('Onboarding'), findsOneWidget);
          expect(find.text('Dashboard'), findsOneWidget);
        },
      );
    },
  );
}
