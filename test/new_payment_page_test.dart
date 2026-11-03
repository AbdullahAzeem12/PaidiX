import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paidix/app/theme/app_theme.dart';
import 'package:paidix/features/payments/data/payments_repository_impl.dart';
import 'package:paidix/features/payments/presentation/pages/new_payment_page.dart';

void main() {
  testWidgets('NewPaymentPage renders fee banner, methods, inputs and actions',
      (WidgetTester tester) async {
    final repo = PaymentsRepositoryImpl();

    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: NewPaymentPage(paymentsRepository: repo),
      ),
    );
    await tester.pumpAndSettle();

    // Verify Fee Banner
    expect(
        find.textContaining('Your processing fee is 12.00%'), findsOneWidget);

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

  testWidgets(
      'NewPaymentPage screenshot picker handles browse, displays file name, and allows removal',
      (WidgetTester tester) async {
    final repo = PaymentsRepositoryImpl();

    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: NewPaymentPage(paymentsRepository: repo),
      ),
    );
    await tester.pumpAndSettle();

    // 1. Initial empty file state
    expect(find.text('Choose a file...'), findsOneWidget);
    expect(find.text('BROWSE'), findsOneWidget);

    // 2. Tap BROWSE button
    await tester.tap(find.text('BROWSE'));
    await tester.pumpAndSettle();

    // In test environment, fallback generates a payment_receipt_*.png or proof
    expect(find.textContaining('payment_receipt_'), findsOneWidget);
    expect(find.byIcon(Icons.close_rounded), findsOneWidget);

    // 3. Tap [X] button to clear file
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Choose a file...'), findsOneWidget);
    expect(find.byIcon(Icons.close_rounded), findsNothing);
  });

  testWidgets(
      'NewPaymentPage full submission lifecycle with exact values matching screenshot',
      (WidgetTester tester) async {
    final repo = PaymentsRepositoryImpl();

    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: NewPaymentPage(paymentsRepository: repo),
      ),
    );
    await tester.pumpAndSettle();

    // 1. Select payment method
    await tester.tap(find.text('Freight Flow Cashapp'));
    await tester.pumpAndSettle();

    // 2. Fill in Sender Name
    await tester.enterText(
        find.widgetWithText(TextField, '').first, 'Alice Morgan');
    await tester.pumpAndSettle();

    // 3. Fill in Sender Company
    await tester.enterText(
        find.widgetWithText(TextField, '').at(1), 'Morgan Freight LLC');
    await tester.pumpAndSettle();

    // 4. Fill in Confirmation Code matching screenshot: 5432
    await tester.enterText(
        find.widgetWithText(TextField, '').at(2), '5432');
    await tester.pumpAndSettle();

    // 5. Fill in Amount matching screenshot: 65
    await tester.enterText(
        find.widgetWithText(TextField, '0.00'), '65');
    await tester.pumpAndSettle();

    // 6. Pick Date
    await tester.tap(find.byIcon(Icons.calendar_today_outlined));
    await tester.pumpAndSettle();
    expect(find.text('OK'), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    // 7. Attach screenshot
    await tester.tap(find.text('BROWSE'));
    await tester.pumpAndSettle();
    expect(find.textContaining('payment_receipt_'), findsOneWidget);

    // 8. Submit Payment
    await tester.tap(find.text('Submit payment'));
    await tester.pumpAndSettle();

    // Verify payment was submitted to repo
    expect(repo.payments.length, equals(1));
    final item = repo.payments.first;
    expect(item.sender, equals('Alice Morgan'));
    expect(item.senderCompany, equals('Morgan Freight LLC'));
    expect(item.amount, equals(65.0));
    expect(item.feeAmount, closeTo(7.80, 0.01)); // 12% of $65
    expect(item.netPkr, closeTo(15615.60, 0.01)); // ($65 - $7.80) * 273
    expect(item.proofFileName, isNotNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'NewPaymentPage renders with zero overflow on mobile portrait (360x800) and landscape tilt (740x360)',
      (WidgetTester tester) async {
    final repo = PaymentsRepositoryImpl();

    for (final size in [const Size(360, 800), const Size(740, 360)]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: NewPaymentPage(
            key: ValueKey('new_payment_${size.width}_${size.height}'),
            paymentsRepository: repo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Freight Flow Cashapp'), findsOneWidget);
      expect(find.text('Submit payment'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });
}
