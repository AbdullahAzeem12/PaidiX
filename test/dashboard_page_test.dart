import 'package:paidix/features/settings/domain/fx_display_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paidix/app/theme/app_theme.dart';
import 'package:paidix/features/dashboard/presentation/pages/dashboard_page.dart';
import 'package:paidix/features/payments/data/payments_repository_impl.dart';

void main() {
  testWidgets('Dashboard renders clean empty state with accurate metrics',
      (WidgetTester tester) async {
    final repo = PaymentsRepositoryImpl();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: DashboardPage(paymentsRepository: repo),
      ),
    );
    await tester.pumpAndSettle();

    // Verify Brand / Plan & Greeting
    expect(find.text('BASIC PLAN'), findsNothing);
    expect(find.text('Hello, Abdullah.'), findsOneWidget);
    expect(find.text('Your global balances, side-by-side.'), findsOneWidget);

    // Verify Customer Score Section (50 - NEW)
    expect(find.text('CUSTOMER SCORE'), findsOneWidget);
    expect(find.text('50'), findsOneWidget);
    expect(find.text('NEW'), findsOneWidget);

    // Verify FILTERS Bar (Closed by default)
    expect(find.text('FILTERS'), findsOneWidget);
    // When closed, From and — To input labels are not visible
    expect(find.text('— To'), findsNothing);

    // Tap FILTERS to expand
    await tester.tap(find.text('FILTERS'));
    await tester.pumpAndSettle();

    // Verify expanded filter controls
    expect(find.text('From'), findsOneWidget);
    expect(find.text('— To'), findsOneWidget);
    expect(find.text('mm/dd/yyyy'), findsNWidgets(2));

    // Verify Section Title & Empty Transactions State
    expect(find.text('YOUR MONEY, AT A GLANCE'), findsOneWidget);
    expect(find.text('No transactions yet'), findsOneWidget);
    expect(find.text('Submit your first incoming payment to start tracking your money.'),
        findsOneWidget);

    // Verify Status Metric Cards (COMPLETED appears in CustomerScoreCard + StatusMetricCard)
    expect(find.text('TRANSACTIONS'), findsOneWidget);
    expect(find.text('PENDING REVIEW'), findsOneWidget);
    expect(find.text('AWAITING PKR'), findsOneWidget);
    expect(find.text('COMPLETED'), findsWidgets);

    // Verify RECENT ACTIVITY Section & Empty Payments State
    expect(find.text('RECENT ACTIVITY'), findsOneWidget);
    expect(find.text('View all payments'), findsOneWidget);
    expect(find.text('No payments yet'), findsOneWidget);
    expect(find.text('When you submit an incoming payment, it will show up here.'),
        findsOneWidget);
  });

  testWidgets(
      'StatusMetricCard renders completely without overflow across 320px, 360px, 768px, 1200px',
      (WidgetTester tester) async {
    final repo = PaymentsRepositoryImpl();
    for (final width in [320.0, 360.0, 414.0, 768.0, 1200.0]) {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: DashboardPage(paymentsRepository: repo),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('TRANSACTIONS'), findsOneWidget);
      expect(find.text('PENDING REVIEW'), findsOneWidget);
      expect(find.text('AWAITING PKR'), findsOneWidget);
      expect(find.text('COMPLETED'), findsWidgets);
    }
  });

  testWidgets(
      'Dashboard Customer Score blinking yellow star and prominent Filters bar with header Reset button & Currency chips',
      (WidgetTester tester) async {
    final repo = PaymentsRepositoryImpl();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: DashboardPage(paymentsRepository: repo),
      ),
    );
    await tester.pumpAndSettle();

    // 1. Verify Star next to Customer Score
    expect(find.text('CUSTOMER SCORE'), findsOneWidget);
    expect(find.byIcon(Icons.auto_awesome), findsOneWidget);

    // 2. Verify Completed, Rate, Volume labels
    expect(find.text('COMPLETED'), findsWidgets);
    expect(find.text('RATE'), findsOneWidget);
    expect(find.text('VOLUME'), findsOneWidget);

    // 3. Verify prominent Filters bar header with Reset button
    expect(find.text('FILTERS'), findsOneWidget);
    expect(find.byIcon(Icons.filter_list_rounded), findsOneWidget);
    expect(find.text('Reset'), findsOneWidget);

    // 4. Expand Filters bar
    await tester.tap(find.text('FILTERS'));
    await tester.pumpAndSettle();

    // Verify chips: Range, Currency, Status, From, — To
    expect(find.text('Currency: '), findsOneWidget);
    expect(find.text('Status: '), findsOneWidget);
    expect(find.text('From'), findsOneWidget);
    expect(find.text('— To'), findsOneWidget);

    // 5. Tap on Currency chip to apply a filter
    await tester.tap(find.text('Currency: '));
    await tester.pumpAndSettle();

    // Select USD
    await tester.tap(find.text('USD'));
    await tester.pumpAndSettle();

    // Active count badge '1' appears
    expect(find.text('1'), findsOneWidget);

    // 6. Tap header Reset to clear all filters
    await tester.tap(find.text('Reset'));
    await tester.pumpAndSettle();

    // Active count badge is removed
    expect(find.text('1'), findsNothing);
  });

  testWidgets(
      'CustomerScoreCard volume reacts in real-time to Stealth Privacy Mode and Compact Notation preferences',
      (WidgetTester tester) async {
    FxDisplayPreferences.resetToDefault();
    final repo = PaymentsRepositoryImpl();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: DashboardPage(paymentsRepository: repo),
      ),
    );
    await tester.pumpAndSettle();

    // Verify initial volume displays standard PKR (starter score volume is 0.00)
    expect(find.text('VOLUME'), findsOneWidget);
    expect(find.text('Rs. 0.00'), findsOneWidget);

    // 1. Toggle Compact Notation in preferences in real time
    FxDisplayPreferences.toggleCompactFormat();
    await tester.pumpAndSettle();
    expect(find.text('Rs. 0.00'), findsOneWidget); // 0 compactly is 0.00

    // 2. Toggle Stealth Privacy Mode in preferences in real time
    FxDisplayPreferences.toggleStealthMode();
    await tester.pumpAndSettle();

    // Customer Score volume should instantly reflect masked dots
    expect(find.text('Rs. ••••••••••'), findsOneWidget);
    expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);

    // 3. Tap on the masked volume to temporarily reveal / peek it
    await tester.tap(find.text('Rs. ••••••••••'));
    await tester.pumpAndSettle();

    // Unmasked! Peek icon changes to visibility_outlined and number is shown
    expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
    expect(find.text('Rs. 0.00'), findsOneWidget);

    // 4. Tap again to re-mask
    await tester.tap(find.text('Rs. 0.00'));
    await tester.pumpAndSettle();
    expect(find.text('Rs. ••••••••••'), findsOneWidget);
    expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);

    // 5. Reset to defaults
    FxDisplayPreferences.resetToDefault();
    await tester.pumpAndSettle();
    expect(find.text('Rs. 0.00'), findsOneWidget);
    expect(find.byIcon(Icons.visibility_off_outlined), findsNothing);
  });
}
