/// Tests the dashboard page test behavior and guards its key user-facing and domain expectations.

import 'package:paidix/features/settings/domain/fx_display_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paidix/app/theme/app_theme.dart';
import 'package:paidix/features/dashboard/presentation/pages/dashboard_page.dart';
import 'package:paidix/features/payments/data/payments_repository_impl.dart';
import 'package:paidix/features/dashboard/presentation/widgets/status_metric_card.dart';

/// Configures and launches the application or test suite.
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

  testWidgets(
      'Synchronized real-time balance reveal: Customer Score eye icon unmasks and masks below financial cards in sync',
      (WidgetTester tester) async {
    FxDisplayPreferences.resetToDefault();
    // Seed mock data with completed payments so PKR RECEIVED and TOTAL TRANSFERRED are rendered
    final repo = PaymentsRepositoryImpl(seedMockData: true);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: DashboardPage(paymentsRepository: repo),
      ),
    );
    await tester.pumpAndSettle();

    // Verify sections are visible
    expect(find.text('CUSTOMER SCORE'), findsOneWidget);
    expect(find.text('PKR RECEIVED'), findsOneWidget);
    expect(find.text('TOTAL TRANSFERRED TO YOU'), findsOneWidget);

    // Initial state: Stealth mode is OFF, values are shown
    expect(find.text('Rs. ••••••••••'), findsNothing);

    // 1. User enables Stealth Mode in preferences
    FxDisplayPreferences.toggleStealthMode();
    await tester.pumpAndSettle();

    // All financial amounts (Customer Score Volume + below financial cards) are masked
    expect(find.text('Rs. ••••••••••'), findsNWidgets(3));
    expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);

    // 2. User clicks the eye icon on Customer Score VOLUME
    await tester.tap(find.byIcon(Icons.visibility_off_outlined));
    await tester.pumpAndSettle();

    // All sections unmask SIMULTANEOUSLY!
    expect(find.text('Rs. ••••••••••'), findsNothing);
    expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);

    // 3. User clicks the eye icon again to re-mask
    await tester.tap(find.byIcon(Icons.visibility_outlined));
    await tester.pumpAndSettle();

    // All sections mask back to Rs. •••••••••• SIMULTANEOUSLY!
    expect(find.text('Rs. ••••••••••'), findsNWidgets(3));
    expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);

    // 4. Clicking any below card (e.g. PKR RECEIVED) also toggles synchronized reveal
    await tester.ensureVisible(find.text('PKR RECEIVED'));
    await tester.tap(find.text('PKR RECEIVED'));
    await tester.pumpAndSettle();

    expect(find.text('Rs. ••••••••••'), findsNothing);
    expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);

    // Reset preferences cleanly
    FxDisplayPreferences.resetToDefault();
    await tester.pumpAndSettle();
  });
  testWidgets(
      'Interactive status summary cards filter Recent Activity with animations, highlighting, and list transitions',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repo = PaymentsRepositoryImpl(seedMockData: true);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: DashboardPage(paymentsRepository: repo),
      ),
    );
    await tester.pumpAndSettle();

    // 1. Initial State: Counts for converted mock data
    expect(find.text('TRANSACTIONS'), findsOneWidget);
    expect(find.text('32'), findsWidgets); // Transactions count & customer score
    expect(find.text('PENDING REVIEW'), findsOneWidget);
    expect(find.text('3'), findsWidgets); // Pending Review count & Awaiting PKR count
    expect(find.text('AWAITING PKR'), findsOneWidget);
    expect(find.text('COMPLETED'), findsWidgets);
    expect(find.text('18'), findsWidgets); // Completed count
    expect(find.text('6 payments in progress'), findsOneWidget);

    // Initial RECENT ACTIVITY shows top payments (Completed)
    expect(find.text('PBX-2026-001332'), findsOneWidget);
    expect(find.text('ACTIVE'), findsOneWidget); // TRANSACTIONS is active by default

    final pendingCard = find.widgetWithText(StatusMetricCard, 'PENDING REVIEW');
    final awaitingCard = find.widgetWithText(StatusMetricCard, 'AWAITING PKR');
    final completedCard = find.widgetWithText(StatusMetricCard, 'COMPLETED');
    final transactionsCard = find.widgetWithText(StatusMetricCard, 'TRANSACTIONS');

    // 2. Tap PENDING REVIEW card
    await tester.ensureVisible(pendingCard);
    await tester.tap(pendingCard);
    await tester.pumpAndSettle();

    // Active status filter banner appears
    expect(find.text('Showing Pending Review payments (3)'), findsOneWidget);
    // Recent activity list now only shows pending review items!
    expect(find.text('PBX-2026-001329'), findsOneWidget); // Swift Logistics LLC ($350)
    expect(find.text('PBX-2026-001327'), findsOneWidget); // Falcon Express Lines ($240)
    expect(find.text('PBX-2026-001324'), findsOneWidget); // Metro Cargo Corp ($75)
    expect(find.text('PBX-2026-001332'), findsNothing); // Completed item not shown

    // 3. Tap AWAITING PKR card
    await tester.ensureVisible(awaitingCard);
    await tester.tap(awaitingCard);
    await tester.pumpAndSettle();

    // Active status filter banner updates
    expect(find.text('Showing Awaiting PKR payments (3)'), findsOneWidget);
    // Recent activity list now only shows awaiting PKR items!
    expect(find.text('PBX-2026-001328'), findsOneWidget); // Apex Freight Express ($85)
    expect(find.text('PBX-2026-001325'), findsOneWidget); // Titan Haulers LLC ($520)
    expect(find.text('PBX-2026-001322'), findsOneWidget); // Prime Line Dispatch ($310)
    expect(find.text('PBX-2026-001329'), findsNothing); // Pending review item not shown

    // 4. Tap COMPLETED card
    await tester.ensureVisible(completedCard);
    await tester.tap(completedCard);
    await tester.pumpAndSettle();

    expect(find.text('Showing Completed payments (18)'), findsOneWidget);
    expect(find.text('PBX-2026-001332'), findsOneWidget); // Completed item shown again
    expect(find.text('PBX-2026-001328'), findsNothing); // Awaiting PKR item not shown

    // 5. Tap TRANSACTIONS card to reset filter to all
    await tester.ensureVisible(transactionsCard);
    await tester.tap(transactionsCard);
    await tester.pumpAndSettle();

    // Active filter banner is cleared
    expect(find.text('Showing Completed payments (18)'), findsNothing);
    expect(find.text('PBX-2026-001332'), findsOneWidget);

    // 6. Tap active card again to toggle back to all
    await tester.tap(pendingCard);
    await tester.pumpAndSettle();
    expect(find.text('Showing Pending Review payments (3)'), findsOneWidget);

    // Tap PENDING REVIEW again -> toggles back to all
    await tester.tap(pendingCard);
    await tester.pumpAndSettle();
    expect(find.text('Showing Pending Review payments (3)'), findsNothing);
    expect(find.text('PBX-2026-001332'), findsOneWidget);
  });
  testWidgets(
      'Dashboard filters dropdown supports all statuses (On Hold, Submitted, Verified, Rejected) with active banner and matching lists',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repo = PaymentsRepositoryImpl(seedMockData: true);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: DashboardPage(paymentsRepository: repo),
      ),
    );
    await tester.pumpAndSettle();

    // 1. Expand FILTERS bar
    await tester.tap(find.text('FILTERS'));
    await tester.pumpAndSettle();

    // 2. Tap Status dropdown
    await tester.tap(find.text('Status: '));
    await tester.pumpAndSettle();

    // Verify all 8 statuses are available in the dropdown
    expect(find.text('All statuses'), findsWidgets);
    expect(find.text('Submitted'), findsOneWidget);
    expect(find.text('Under Review'), findsOneWidget);
    expect(find.text('Verified'), findsOneWidget);
    expect(find.text('PKR Sent'), findsOneWidget);
    expect(find.text('Completed'), findsWidgets);
    expect(find.text('On Hold'), findsOneWidget);
    expect(find.text('Rejected'), findsOneWidget);

    // 3. Select 'On Hold' (matching user screenshot)
    await tester.tap(find.text('On Hold'));
    await tester.pumpAndSettle();

    // Active status filter banner appears with On Hold
    expect(find.text('Showing On Hold payments (2)'), findsOneWidget);
    // Recent activity list displays the On Hold mock payments
    expect(find.text('PBX-2026-001305'), findsOneWidget); // Blue Star Transport ($260)
    expect(find.text('PBX-2026-001304'), findsOneWidget); // Direct Route Logistics ($175)
    expect(find.text('PBX-2026-001332'), findsNothing); // Completed not shown

    // 4. Select 'Submitted'
    await tester.tap(find.text('Status: '));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Submitted'));
    await tester.pumpAndSettle();

    expect(find.text('Showing Submitted payments (2)'), findsOneWidget);
    expect(find.text('PBX-2026-001309'), findsOneWidget); // Atlas Freight Solutions ($210)
    expect(find.text('PBX-2026-001308'), findsOneWidget); // Pinnacle Transport Inc ($180)

    // 5. Select 'Verified'
    await tester.tap(find.text('Status: '));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Verified'));
    await tester.pumpAndSettle();

    expect(find.text('Showing Verified payments (2)'), findsOneWidget);
    expect(find.text('PBX-2026-001307'), findsOneWidget); // Silverline Logistics LLC ($340)
    expect(find.text('PBX-2026-001306'), findsOneWidget); // Crest Hauling Corp ($125)

    // 6. Select 'Rejected'
    await tester.tap(find.text('Status: '));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rejected'));
    await tester.pumpAndSettle();

    expect(find.text('Showing Rejected payments (2)'), findsOneWidget);
    expect(find.text('PBX-2026-001303'), findsOneWidget); // Continental Express ($380)
    expect(find.text('PBX-2026-001302'), findsOneWidget); // Vanguard Freight ($295)

    // 7. Clear filter via header Reset button
    await tester.tap(find.text('Reset'));
    await tester.pumpAndSettle();

    expect(find.text('Showing Rejected payments (2)'), findsNothing);
    expect(find.text('PBX-2026-001332'), findsOneWidget); // All recent payments restored
  });
}
