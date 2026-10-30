import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paidix/app/theme/app_theme.dart';
import 'package:paidix/features/payments/data/payments_repository_impl.dart';
import 'package:paidix/features/payments/presentation/pages/new_payment_page.dart';

void main() {
  testWidgets('NewPaymentPage renders fee banner, methods, inputs and actions',
      (WidgetTester tester) async {
    final repo = PaymentsRepositoryImpl();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: NewPaymentPage(paymentsRepository: repo),
      ),
    );
    await tester.pumpAndSettle();

    // Verify Fee Banner
    expect(find.textContaining('Your processing fee is 12.00%'), findsOneWidget);

    // Verify Payment Method Options
    expect(find.text('Freight Flow Cashapp'), findsOneWidget);
    expect(find.text('UB Zelle'), findsOneWidget);

    // Verify Fields
    expect(find.text('SENDER NAME'), findsOneWidget);
    expect(find.text('SENDER COMPANY'), findsOneWidget);
    expect(find.text('CONFIRMATION CODE'), findsOneWidget);
    expect(find.text('AMOUNT RECEIVED (USD)'), findsOneWidget);
    expect(find.text('TRANSACTION DATE'), findsOneWidget);
    expect(find.text('TRANSACTION SCREENSHOT'), findsOneWidget);

    // Verify Actions
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Submit payment'), findsOneWidget);
  });
}

