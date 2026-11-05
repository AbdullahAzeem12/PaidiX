import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paidix/app/router.dart';
import 'package:paidix/app/theme/app_theme.dart';
import 'package:paidix/core/services/session_timeout_service.dart';
import 'package:paidix/core/widgets/session_timeout_dialog.dart';

void main() {
  setUp(() {
    SessionTimeoutService.instance.stopSession();
    SessionTimeoutService.instance.timeoutDuration = const Duration(minutes: 5);
  });

  tearDown(() {
    SessionTimeoutService.instance.stopSession();
  });

  group('Active Session Inactivity & Timeout Suite (5-Minute Idle Security)', () {
    testWidgets('SessionTimeoutDialog renders authentic PaidiX security copy, badges & button in Dark Theme',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: const Scaffold(
            body: SessionTimeoutDialog(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('SESSION EXPIRED • 5 MIN INACTIVITY'), findsOneWidget);
      expect(find.text('Session Inactivity Timeout'), findsOneWidget);
      expect(
        find.text(
          'You were idle for 5 minutes. For your security and financial data privacy, your active session was closed. Please sign in again to access your account.',
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          'Your account funds, linked banks, and pending transfers remain 100% secure.',
        ),
        findsOneWidget,
      );
      expect(find.text('Log In Again'), findsOneWidget);
      expect(find.byIcon(Icons.hourglass_bottom_rounded), findsOneWidget);
      expect(find.byIcon(Icons.verified_user_rounded), findsOneWidget);
      expect(find.byIcon(Icons.login_rounded), findsOneWidget);
    });

    testWidgets('SessionTimeoutDialog renders authentic PaidiX security copy, badges & button in Light Theme',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(
            body: SessionTimeoutDialog(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('SESSION EXPIRED • 5 MIN INACTIVITY'), findsOneWidget);
      expect(find.text('Session Inactivity Timeout'), findsOneWidget);
      expect(find.text('Log In Again'), findsOneWidget);
    });

    testWidgets('AppShell idle for 5 minutes triggers Session Inactivity Timeout automatically',
        (WidgetTester tester) async {
      final router = createAppRouter(initialLocation: '/app/dashboard');

      await tester.pumpWidget(
        MaterialApp.router(
          theme: AppTheme.darkTheme,
          routerConfig: router,
        ),
      );
      await tester.pumpAndSettle();

      // Initially on Dashboard, active session running, dialog not showing
      expect(find.text('Dashboard'), findsWidgets);
      expect(SessionTimeoutService.instance.isSessionActive, isTrue);
      expect(find.text('Session Inactivity Timeout'), findsNothing);

      // Advance simulated time by 5 minutes of complete inactivity
      await tester.pump(const Duration(minutes: 5));
      await tester.pumpAndSettle();

      // Dialog must now be visible
      expect(find.text('Session Inactivity Timeout'), findsOneWidget);
      expect(find.text('Log In Again'), findsOneWidget);

      // Tap "Log In Again" -> must log out and route to /signin
      await tester.tap(find.text('Log In Again'));
      await tester.pumpAndSettle();

      expect(find.text('Welcome back.'), findsOneWidget);
      expect(find.text('SIGN IN'), findsOneWidget);
      expect(SessionTimeoutService.instance.isSessionActive, isFalse);
    });

    testWidgets('User interaction within 5 minutes resets idle timer and prevents timeout',
        (WidgetTester tester) async {
      final router = createAppRouter(initialLocation: '/app/dashboard');

      await tester.pumpWidget(
        MaterialApp.router(
          theme: AppTheme.darkTheme,
          routerConfig: router,
        ),
      );
      await tester.pumpAndSettle();

      expect(SessionTimeoutService.instance.isSessionActive, isTrue);

      // Advance 3 minutes (less than 5 min)
      await tester.pump(const Duration(minutes: 3));

      // Simulate user interacting (tap on screen)
      SessionTimeoutService.instance.recordUserActivity();
      await tester.pump();

      // Advance another 3 minutes (total 6 minutes elapsed, but only 3 minutes since last activity)
      await tester.pump(const Duration(minutes: 3));
      await tester.pumpAndSettle();

      // Dialog must NOT be visible yet
      expect(find.text('Session Inactivity Timeout'), findsNothing);

      // Now leave idle for a full 5 minutes
      await tester.pump(const Duration(minutes: 5));
      await tester.pumpAndSettle();

      // Dialog must now appear
      expect(find.text('Session Inactivity Timeout'), findsOneWidget);
    });
  });
}
