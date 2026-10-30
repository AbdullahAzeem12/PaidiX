import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paidix/app/theme/app_theme.dart';
import 'package:paidix/core/widgets/app_button.dart';
import 'package:paidix/core/widgets/auth_primary_button.dart';
import 'package:paidix/core/widgets/spongy_tap.dart';

void main() {
  group('Spongy Buttons & Animations Tests', () {
    testWidgets('AppButton squishes on press and springs back on release',
        (tester) async {
      int pressCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: Center(
              child: AppButton(
                text: 'Create Account',
                onPressed: () => pressCount++,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Create Account'), findsOneWidget);

      final buttonTransformFinder = find.descendant(
        of: find.byType(AppButton),
        matching: find.byType(Transform),
      );

      for (final w in tester.widgetList<Transform>(buttonTransformFinder)) {
        debugPrint('Found transform: ${w.transform.getMaxScaleOnAxis()}');
      }

      // Press down
      final gesture =
          await tester.startGesture(tester.getCenter(find.byType(AppButton)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));

      for (final w in tester.widgetList<Transform>(buttonTransformFinder)) {
        debugPrint('After press transform: ${w.transform.getMaxScaleOnAxis()}');
      }

      // Release
      await gesture.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 90));
      await tester.pump(const Duration(milliseconds: 300));

      expect(pressCount, 1);
    });

    testWidgets('AuthPrimaryButton renders with arrow icon and receives tap',
        (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: Center(
              child: AuthPrimaryButton(
                text: 'Sign in',
                onPressed: () => tapped = true,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Sign in'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_forward_rounded), findsOneWidget);

      await tester.tap(find.byType(AuthPrimaryButton));
      await tester.pumpAndSettle();

      expect(tapped, true);
    });

    testWidgets('SpongyLinkButton triggers tap callback properly',
        (tester) async {
      bool linkTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: Center(
              child: SpongyLinkButton(
                text: 'Forgot password?',
                onTap: () => linkTapped = true,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Forgot password?'), findsOneWidget);

      await tester.tap(find.text('Forgot password?'));
      await tester.pumpAndSettle();

      expect(linkTapped, true);
    });
  });
}
