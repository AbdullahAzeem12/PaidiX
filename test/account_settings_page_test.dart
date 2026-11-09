/// Tests the account settings page test behavior and guards its key user-facing and domain expectations.

import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paidix/app/router.dart';
import 'package:paidix/app/theme/app_colors.dart';
import 'package:paidix/app/theme/app_theme.dart';
import 'package:paidix/core/widgets/app_shell.dart';
import 'package:paidix/core/widgets/paidi_x_bottom_nav_bar.dart';
import 'package:paidix/features/dashboard/presentation/pages/dashboard_page.dart';
import 'package:paidix/features/profile/data/user_profile_repository.dart';
import 'package:paidix/features/settings/presentation/pages/account_settings_page.dart';
import 'package:paidix/features/settings/domain/fx_display_preferences.dart';
import 'test_fixtures.dart';

/// Configures and launches the application or test suite.
void main() {
  setUp(() {
    setupTestState();
  });

  group('AccountSettingsPage Comprehensive Responsiveness & Zero Overflow Suite', () {
    final screenWidths = [320.0, 360.0, 375.0, 414.0, 768.0, 1024.0, 1200.0];

    for (final width in screenWidths) {
      testWidgets('Zero overflow on ${width}px screen across all 5 tabs',
          (WidgetTester tester) async {
        tester.view.physicalSize = Size(width, 900.0);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: const AccountSettingsPage(),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Profile Tab
        expect(find.text('Profile'), findsWidgets);
        expect(find.text('Abdullah Azeem'), findsWidgets);
        expect(find.text('CUSTOMER'), findsWidgets);

        Future<void> selectTab(String tabName) async {
          final target = find.widgetWithText(GestureDetector, tabName).first;
          if (width < 640) {
            final scrollable = find.byType(Scrollable).first;
            await tester.scrollUntilVisible(target, 50.0, scrollable: scrollable);
          }
          await tester.tap(target);
          await tester.pumpAndSettle();
        }

        // 2. Security Tab
        await selectTab('Security');
        expect(find.text('CURRENT PASSWORD'), findsOneWidget);
        expect(find.text('Update password'), findsOneWidget);

        // 3. Bank Accounts Tab
        await selectTab('Bank Accounts');
        expect(find.text('Bank accounts.'), findsOneWidget);
        expect(find.text('PKR RECEIVING (PAKISTAN)'), findsOneWidget);
        expect(find.text('Add account'), findsOneWidget);
        expect(find.text('JAZZCASH (MOBILINK MICROFINANCE BANK)'), findsOneWidget);
        expect(find.text('Primary'), findsOneWidget);

        // 4. Payments PIN Tab
        await selectTab('Payments PIN');
        expect(find.text('Payments PIN'), findsWidgets);

        // 5. Appearance Tab
        await selectTab('Appearance');
        expect(find.text('Dark'), findsOneWidget);
        expect(find.text('Light'), findsOneWidget);
        expect(find.text('System'), findsOneWidget);
        expect(find.text('FINANCIAL DISPLAY & PRIVACY'), findsOneWidget);
        expect(find.text('Stealth Privacy Mode'), findsOneWidget);
      });
    }

    testWidgets('Payments PIN full lifecycle: Set -> Update (with wrong current PIN error) -> Forgot PIN -> Remove PIN',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(360.0, 900.0);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: const AccountSettingsPage(),
        ),
      );
      await tester.pumpAndSettle();

      // Navigate to Payments PIN tab
      final pinTab = find.widgetWithText(GestureDetector, 'Payments PIN').first;
      final scrollable = find.byType(Scrollable).first;
      await tester.scrollUntilVisible(pinTab, 50.0, scrollable: scrollable);
      await tester.tap(pinTab);
      await tester.pumpAndSettle();

      // If a PIN is not set, set it first to test the full lifecycle
      if (find.text('No PIN set — your payments page is open.').evaluate().isNotEmpty) {
        expect(find.text('Set PIN'), findsOneWidget);

        // Enter initial PIN and confirm PIN
        final textFields = find.byType(TextField);
        await tester.enterText(textFields.at(0), '1234');
        await tester.enterText(textFields.at(1), '1234');

        await tester.tap(find.text('Set PIN'));
        await tester.pump(const Duration(milliseconds: 600));
        await tester.pumpAndSettle();

        // Clear the initial snackbar
        tester.binding.scheduleFrame();
        await tester.pump(const Duration(seconds: 4));
        await tester.pumpAndSettle();
      }

      // Verify the page updated to the "A PIN is currently set." layout matching screenshot
      expect(find.text('A PIN is currently set.'), findsOneWidget);
      expect(find.text('CURRENT PIN'), findsNWidgets(2)); // Card 1 & Card 2
      expect(find.text('NEW PIN'), findsOneWidget);
      expect(find.text('CONFIRM PIN'), findsOneWidget);
      expect(find.text('Forgot PIN? Email me a new one'), findsOneWidget);
      expect(find.text('Update PIN'), findsOneWidget);
      expect(find.text('Remove PIN'), findsWidgets); // Card 2 title + button

      // Test 1: Enter WRONG current PIN and try to update
      final updateTextFields = find.byType(TextField);
      await tester.enterText(updateTextFields.at(0), '9999'); // wrong current PIN
      await tester.enterText(updateTextFields.at(1), '5678'); // new PIN
      await tester.enterText(updateTextFields.at(2), '5678'); // confirm PIN

      // Scroll Update PIN button into view if needed and tap
      final updateBtn = find.text('Update PIN');
      await tester.ensureVisible(updateBtn);
      await tester.tap(updateBtn);
      await tester.pumpAndSettle();

      // Expect smart error message as requested
      expect(
        find.text('Incorrect current PIN. Please enter your correct previous PIN.'),
        findsOneWidget,
      );

      // Dismiss snackbar
      tester.binding.scheduleFrame();
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();

      // Test 2: Enter CORRECT current PIN and update
      await tester.enterText(updateTextFields.at(0), '1234'); // correct current PIN
      await tester.enterText(updateTextFields.at(1), '5678');
      await tester.enterText(updateTextFields.at(2), '5678');

      await tester.ensureVisible(updateBtn);
      await tester.tap(updateBtn);
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();

      expect(find.text('Payments PIN updated successfully.'), findsOneWidget);

      tester.binding.scheduleFrame();
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();

      // Test 3: Forgot PIN dialog flow
      final forgotLink = find.text('Forgot PIN? Email me a new one');
      await tester.ensureVisible(forgotLink);
      await tester.tap(forgotLink);
      await tester.pumpAndSettle();

      expect(find.text('Forgot Payments PIN?'), findsOneWidget);
      expect(find.text('kherool66@gmail.com'), findsOneWidget);
      expect(find.text('Send Reset Email'), findsOneWidget);

      await tester.tap(find.text('Send Reset Email'));
      await tester.pumpAndSettle();

      expect(
        find.text('Temporary PIN (1234) sent to kherool66@gmail.com. Enter it in CURRENT PIN.'),
        findsOneWidget,
      );

      tester.binding.scheduleFrame();
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();

      // Test 4: Remove PIN with WRONG PIN
      final removeTextFields = find.byType(TextField);
      await tester.enterText(removeTextFields.at(3), '0000'); // wrong PIN in remove card
      final removeBtn = find.text('Remove PIN').last;
      await tester.ensureVisible(removeBtn);
      await tester.tap(removeBtn);
      await tester.pumpAndSettle();

      expect(
        find.text('Incorrect current PIN. Please enter your correct previous PIN to remove.'),
        findsOneWidget,
      );

      tester.binding.scheduleFrame();
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();

      // Test 5: Remove PIN with CORRECT PIN (the temporary PIN 1234 from recovery)
      await tester.enterText(removeTextFields.at(3), '1234');
      await tester.ensureVisible(removeBtn);
      await tester.tap(removeBtn);
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();

      expect(
        find.text('PIN removed successfully. Your payments page is now open.'),
        findsOneWidget,
      );

      // Verify page updated back to initial "No PIN set" state
      expect(find.text('No PIN set — your payments page is open.'), findsOneWidget);
      expect(find.text('Set PIN'), findsOneWidget);
    });

    testWidgets('Bank accounts modal sheet opens, renders and dismisses cleanly on 360px',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(360.0, 800.0);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: const AccountSettingsPage(),
        ),
      );
      await tester.pumpAndSettle();

      final bankTab = find.widgetWithText(GestureDetector, 'Bank Accounts').first;
      final scrollable = find.byType(Scrollable).first;
      await tester.scrollUntilVisible(bankTab, 50.0, scrollable: scrollable);
      await tester.tap(bankTab);
      await tester.pumpAndSettle();

      // Open Add account modal
      await tester.tap(find.text('Add account'));
      await tester.pumpAndSettle();

      expect(find.text('Add Pakistani bank account'), findsOneWidget);
      expect(find.text('BANK'), findsOneWidget);
      expect(find.text('ACCOUNT HOLDER *'), findsOneWidget);
      expect(find.text('ACCOUNT NUMBER *'), findsOneWidget);
      expect(find.text('IBAN (OPTIONAL)'), findsOneWidget);

      // Dismiss modal cleanly
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Add Pakistani bank account'), findsNothing);
    });

    testWidgets('Bank accounts full interactive lifecycle: Add -> Set as Primary -> Edit -> Delete with confirmation',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(414.0, 900.0);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: const AccountSettingsPage(),
        ),
      );
      await tester.pumpAndSettle();

      final bankTab =
          find.widgetWithText(GestureDetector, 'Bank Accounts').first;
      final scrollable = find.byType(Scrollable).first;
      await tester.scrollUntilVisible(bankTab, 50.0, scrollable: scrollable);
      await tester.tap(bankTab);
      await tester.pumpAndSettle();

      // 1. Initial State: JazzCash is primary
      expect(
          find.text('JAZZCASH (MOBILINK MICROFINANCE BANK)'), findsOneWidget);
      expect(find.text('•••• •••• 2786'), findsOneWidget);
      expect(find.text('Primary'), findsOneWidget);

      // 2. Add New Bank Account: Meezan Bank Limited
      await tester.tap(find.text('Add account'));
      await tester.pumpAndSettle();

      // Tap bank selector
      await tester.tap(find.text('JazzCash (Mobilink Microfinance Bank)').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Meezan Bank Limited').last);
      await tester.pumpAndSettle();

      // Enter holder name and account number
      final textFields = find.byType(TextField);
      await tester.enterText(textFields.at(0), 'Abdullah Azeem');
      await tester.enterText(textFields.at(1), '03217649976');
      await tester.pumpAndSettle();

      // Save
      await tester.tap(find.text('Add account').last);
      await tester.pumpAndSettle();

      // Now both accounts exist
      expect(
          find.text('JAZZCASH (MOBILINK MICROFINANCE BANK)'), findsOneWidget);
      expect(find.text('MEEZAN BANK LIMITED'), findsOneWidget);
      expect(find.text('•••• •••• 9976'), findsOneWidget);

      // 3. Set Meezan Bank as primary
      final setPrimaryBtn = find.text('Set as primary');
      expect(setPrimaryBtn, findsOneWidget);
      await tester.tap(setPrimaryBtn);
      await tester.pumpAndSettle();

      // Verify Meezan has Primary badge now and JazzCash is secondary
      expect(find.text('Set as primary'), findsOneWidget);

      // 4. Edit JazzCash account
      final editButtons = find.text('Edit');
      await tester.tap(editButtons.first);
      await tester.pumpAndSettle();

      expect(find.text('Edit Pakistani bank account'), findsOneWidget);
      final editFields = find.byType(TextField);
      await tester.enterText(editFields.at(1), '03225359999'); // change number
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();

      // Dismiss snackbar so it does not obscure buttons
      tester.binding.scheduleFrame();
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();

      expect(find.text('•••• •••• 9999'), findsOneWidget);

      // 5. Delete an account with confirmation
      final removeButtons = find.text('Remove');
      await tester.tap(removeButtons.first);
      await tester.pumpAndSettle();

      expect(find.text('Remove bank account'), findsOneWidget);
      final confirmRemove = find.widgetWithText(ElevatedButton, 'Remove');
      await tester.tap(confirmRemove);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.text('Bank account removed.'), findsOneWidget);
      await tester.pumpAndSettle();

      expect(
          find.text('JAZZCASH (MOBILINK MICROFINANCE BANK)'), findsNothing);
      expect(find.text('MEEZAN BANK LIMITED'), findsOneWidget);
    });

    testWidgets('Profile section: Phone has single +92 prefix, documents render with Replace, and Avatar options work',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(375.0, 900.0);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: const AccountSettingsPage(),
        ),
      );
      await tester.pumpAndSettle();

      // Verify single PK +92 indicator and stripped digits in text field
      expect(find.text('PK +92'), findsOneWidget);
      // The text field should contain "3217649976" and NOT duplicate "+92"
      final phoneFieldFinder = find.byWidgetPredicate(
        (w) => w is TextField && w.controller?.text == '3217649976',
      );
      expect(phoneFieldFinder, findsOneWidget);

      // Verify Saved Identity Documents section (Selfie, CNIC Front, CNIC Back)
      final scrollable = find.byType(Scrollable).first;
      final selfieText = find.text('SELFIE');
      await tester.scrollUntilVisible(selfieText, 100.0, scrollable: scrollable);
      expect(selfieText, findsOneWidget);
      expect(find.text('CNIC — FRONT'), findsOneWidget);
      expect(find.text('CNIC — BACK'), findsOneWidget);
      expect(find.text('Replace'), findsNWidgets(3));

      // Scroll back up to the camera icon badge on avatar to open image source picker
      final cameraBadge = find.byIcon(Icons.camera_alt_outlined);
      await tester.ensureVisible(cameraBadge);
      await tester.pumpAndSettle();
      expect(cameraBadge, findsOneWidget);
      await tester.tap(cameraBadge);
      await tester.pumpAndSettle();

      // Modal bottom sheet should appear with options
      expect(find.text('Upload Profile Picture'), findsOneWidget);
      expect(find.text('Take Photo'), findsOneWidget);
      expect(find.text('Choose from Gallery / Storage'), findsOneWidget);

      // Dismiss bottom sheet cleanly
      Navigator.of(tester.element(find.text('Upload Profile Picture'))).pop();
      await tester.pumpAndSettle();

      // Test avatar update and remove flow via repository
      final dummyAvatar = Uint8List.fromList([1, 2, 3, 4, 5]);
      UserProfileRepository.instance.updateProfile(avatarBytes: dummyAvatar);
      await tester.pumpAndSettle();
      expect(UserProfileRepository.instance.profile.hasCustomAvatar, isTrue);

      // Tap avatar with custom photo already set: should open Avatar Options Dialog
      await tester.tap(cameraBadge);
      await tester.pumpAndSettle();

      expect(find.text('Profile Picture'), findsOneWidget);
      expect(find.text('Update Profile Picture'), findsOneWidget);
      expect(find.text('Remove Profile Picture'), findsOneWidget);

      // Tap Remove Profile Picture
      await tester.tap(find.text('Remove Profile Picture'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      expect(UserProfileRepository.instance.profile.hasCustomAvatar, isFalse);
      expect(
        find.text('Profile picture removed. Initial restored.'),
        findsOneWidget,
      );
    });

    testWidgets('Profile Picture dialog renders refined light theme styling without dark background artifacts',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(375.0, 900.0);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      UserProfileRepository.instance.updateProfile(
        avatarBytes: Uint8List.fromList([10, 20, 30]),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const AccountSettingsPage(),
        ),
      );
      await tester.pumpAndSettle();

      final cameraBadge = find.byIcon(Icons.camera_alt_outlined);
      await tester.ensureVisible(cameraBadge);
      await tester.pumpAndSettle();
      await tester.tap(cameraBadge);
      await tester.pumpAndSettle();

      expect(find.text('Profile Picture'), findsOneWidget);
      expect(find.text('Update Profile Picture'), findsOneWidget);
      expect(find.text('Remove Profile Picture'), findsOneWidget);

      final removeTitle = tester.widget<Text>(find.text('Remove Profile Picture'));
      expect(removeTitle.style?.color, const Color(0xFFBE123C));

      final updateTitle = tester.widget<Text>(find.text('Update Profile Picture'));
      expect(
        updateTitle.style?.color,
        AppTheme.lightTheme.extension<PaidiXColorsExtension>()?.colors.textPrimary,
      );
    });

    testWidgets('Selfie document preview renders portrait biometric frame without background ring',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(360.0, 900.0);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      // Provide valid 1x1 PNG dummy selfie bytes
      final dummySelfie = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=',
      );
      UserProfileRepository.instance.updateProfile(selfieBytes: dummySelfie);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: const AccountSettingsPage(),
        ),
      );
      await tester.pumpAndSettle();

      final scrollable = find.byType(Scrollable).first;
      final selfieText = find.text('SELFIE');
      await tester.scrollUntilVisible(selfieText, 100.0, scrollable: scrollable);
      expect(selfieText, findsOneWidget);

      // Verify the portrait frame (width: 118, height: 144) is present
      final portraitFrameFinder = find.byWidgetPredicate((w) {
        if (w is Container && w.constraints != null) {
          final c = w.constraints!;
          return c.minWidth == 118 &&
              c.maxWidth == 118 &&
              c.minHeight == 144 &&
              c.maxHeight == 144;
        }
        return false;
      });
      expect(portraitFrameFinder, findsOneWidget);

      // Verify that no circular 144x144 background ring container exists
      final circularRingFinder = find.byWidgetPredicate((w) {
        if (w is Container && w.decoration is BoxDecoration) {
          final box = w.decoration as BoxDecoration;
          if (box.shape == BoxShape.circle && w.constraints != null) {
            final c = w.constraints!;
            return c.minWidth == 144 && c.maxWidth == 144;
          }
        }
        return false;
      });
      expect(circularRingFinder, findsNothing);
    });

    testWidgets('Appearance Tab: Financial Display & Privacy with Stealth Mode & Compact Notation',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(360.0, 900.0);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      FxDisplayPreferences.resetToDefault();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: const AccountSettingsPage(),
        ),
      );
      await tester.pumpAndSettle();

      // Navigate to Appearance tab (scroll horizontally if needed)
      final appearanceTab = find.widgetWithText(GestureDetector, 'Appearance').first;
      final tabScrollable = find.byType(Scrollable).first;
      await tester.scrollUntilVisible(appearanceTab, 50.0, scrollable: tabScrollable);
      await tester.tap(appearanceTab);
      await tester.pumpAndSettle();

      expect(find.text('FINANCIAL DISPLAY & PRIVACY'), findsOneWidget);
      expect(find.text('Stealth Privacy Mode'), findsOneWidget);
      expect(find.text('Compact Currency Notation'), findsOneWidget);
      expect(find.text('LIVE PREVIEW (CUSTOMER SCORE VOLUME)'), findsOneWidget);
      expect(find.text('Standard Display'), findsOneWidget);
      expect(find.text('Rs. 1,169,570.67'), findsOneWidget);

      // Toggle Stealth Privacy Mode
      final stealthToggle = find.text('Stealth Privacy Mode');
      await tester.ensureVisible(stealthToggle);
      await tester.pumpAndSettle();
      await tester.tap(stealthToggle);
      await tester.pumpAndSettle();
      expect(FxDisplayPreferences.isStealthMode, isTrue);
      expect(find.text('Stealth Active'), findsOneWidget);
      expect(find.text('Rs. ••••••••••'), findsOneWidget);
      expect(
        find.text('Tap any masked balance on the dashboard to reveal temporarily.'),
        findsOneWidget,
      );
      expect(find.textContaining('💡'), findsNothing);

      // Toggle Compact Currency Notation
      final compactToggle = find.text('Compact Currency Notation');
      await tester.ensureVisible(compactToggle);
      await tester.pumpAndSettle();
      await tester.tap(compactToggle);
      await tester.pumpAndSettle();
      expect(FxDisplayPreferences.isCompactFormat, isTrue);

      // Tap 'Reset display to defaults'
      final resetBtn = find.text('Reset display to defaults');
      await tester.ensureVisible(resetBtn);
      await tester.pumpAndSettle();
      await tester.tap(resetBtn);
      await tester.pumpAndSettle();

      expect(FxDisplayPreferences.isStealthMode, isFalse);
      expect(FxDisplayPreferences.isCompactFormat, isFalse);
      expect(find.text('Standard Display'), findsOneWidget);
      expect(find.text('Rs. 1,169,570.67'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Tilted phone orientation (landscape 740x360, 800x360, 850x390, 896x414) renders with zero overflow inside AppShell and across tabs',
        (WidgetTester tester) async {
      final tiltSizes = [
        const Size(740.0, 360.0),
        const Size(800.0, 360.0),
        const Size(850.0, 390.0),
        const Size(896.0, 414.0),
      ];

      for (final size in tiltSizes) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: const AppShell(
              currentPath: '/app/settings',
              child: AccountSettingsPage(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Must not throw any overflow exception (specifically eliminates the 223px overflow)
        expect(tester.takeException(), isNull);
        expect(find.text('Account settings.'), findsOneWidget);

        // Switch to Bank accounts tab in tilt view
        final bankTab = find.widgetWithText(GestureDetector, 'Bank Accounts').first;
        final scrollable = find.byType(Scrollable).first;
        await tester.scrollUntilVisible(bankTab, 50.0, scrollable: scrollable);
        await tester.tap(bankTab);
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('Bank accounts.'), findsOneWidget);
        expect(find.text('PKR RECEIVING (PAKISTAN)'), findsOneWidget);
      }

      tester.view.resetPhysicalSize();
    });

    testWidgets('Account Settings back button navigates to Dashboard with smooth transition',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(360.0, 800.0);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp.router(
          theme: AppTheme.darkTheme,
          routerConfig: appRouter,
        ),
      );
      await tester.pumpAndSettle();

      // Navigate to /app/settings
      appRouter.go('/app/settings');
      await tester.pumpAndSettle();

      expect(find.text('Account settings.'), findsWidgets);

      // Verified: Bottom navigation bar is hidden on mobile Settings to prevent stacked navbars
      expect(find.byType(PaidiXBottomNavBar), findsNothing);

      // Find back button
      final backButton = find.byIcon(Icons.arrow_back_ios_new_rounded).first;
      expect(backButton, findsOneWidget);

      await tester.tap(backButton);
      await tester.pumpAndSettle();

      // Verified: Navigated to Dashboard and bottom navigation bar reappears
      expect(find.text('Hello, Abdullah.'), findsOneWidget);
      expect(find.byType(DashboardPage), findsOneWidget);
      expect(find.byType(PaidiXBottomNavBar), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
