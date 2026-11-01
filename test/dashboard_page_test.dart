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
    expect(find.text('BASIC PLAN'), findsWidgets);
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
}
