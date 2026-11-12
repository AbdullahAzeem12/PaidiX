/// Tests the widget test behavior and guards its key user-facing and domain expectations.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paidix/app/app.dart';
import 'package:paidix/app/theme/app_theme.dart';
import 'package:paidix/features/auth/presentation/pages/sign_in_page.dart';

/// Configures and launches the application or test suite.
void main() {
  testWidgets('Renders SignIn screen by default with all reference fields and navigates to SignUp with default +92 country code', (WidgetTester tester) async {
    await tester.pumpWidget(const PaidiXApp());
    await tester.pumpAndSettle();

    // Verify Eyebrow & Title
    expect(find.text('SIGN IN'), findsOneWidget);
    expect(find.text('Welcome back.'), findsOneWidget);

    // Verify Fields
    expect(find.text('EMAIL'), findsOneWidget);
    expect(find.text('PASSWORD'), findsOneWidget);

    // Verify Submit Button
    expect(find.text('Sign in'), findsOneWidget);

    // Verify Footer Link
    final createAccountLink = find.text('Create an account');
    expect(createAccountLink, findsOneWidget);

    // Ensure link is visible in scroll view and tap
    await tester.ensureVisible(createAccountLink);
    await tester.pumpAndSettle();
    await tester.tap(createAccountLink);
    await tester.pumpAndSettle();

    expect(find.text('CREATE ACCOUNT'), findsOneWidget);
    expect(find.text('Start sending.'), findsOneWidget);

    // Verify default +92 country code prefix is displayed
    expect(find.text('+92'), findsOneWidget);
    expect(find.text('PHONE (OPTIONAL)'), findsOneWidget);
  });

  testWidgets(
      'Forgot password reset dialog renders with zero pixel overflow across narrow screens and open keyboard',
      (WidgetTester tester) async {
    for (final config in [
      (size: const Size(360, 640), keyboardBottom: 280.0),
      (size: const Size(320, 480), keyboardBottom: 180.0),
      (size: const Size(740, 360), keyboardBottom: 120.0),
    ]) {
      tester.view.physicalSize = config.size;
      tester.view.devicePixelRatio = 1.0;
      tester.view.viewInsets = FakeViewPadding(bottom: config.keyboardBottom);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const SignInPage(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
          find.byType(TextFormField).first, 'abdullahazeem5352@gmail.com');
      final forgotBtn = find.text('Forgot password?');
      await tester.ensureVisible(forgotBtn);
      await tester.tap(forgotBtn);
      await tester.pumpAndSettle();

      expect(find.text('Reset Password'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Send Code'));
      await tester.pumpAndSettle();

      expect(find.text('Enter Reset Code'), findsOneWidget);
      expect(find.text('6-Digit Code'), findsOneWidget);
      expect(find.text('New Password'), findsOneWidget);
      expect(find.text('Update Password'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    }
  });
}
