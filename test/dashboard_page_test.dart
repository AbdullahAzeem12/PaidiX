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

    // Verify Customer Score Section
    expect(find.text('CUSTOMER SCORE'), findsOneWidget);

    // Verify Financial Section
    expect(find.text('YOUR MONEY, AT A GLANCE'), findsOneWidget);
    expect(find.text('PKR RECEIVED'), findsOneWidget);
    expect(find.text('TOTAL TRANSFERRED TO YOU'), findsOneWidget);
    expect(find.text('AWAITING VERIFICATION'), findsOneWidget);

    // Verify Empty Activity State
    expect(find.text('No recent activity'), findsOneWidget);
  });
}

