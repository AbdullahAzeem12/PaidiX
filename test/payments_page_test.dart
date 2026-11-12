/// Tests the payments page test behavior and guards its key user-facing and domain expectations.

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paidix/app/theme/app_theme.dart';
import 'package:paidix/features/payments/data/payments_repository_impl.dart';
import 'package:paidix/features/payments/domain/payment_models.dart';
import 'package:paidix/features/payments/presentation/pages/payments_page.dart';
import 'test_fixtures.dart';
// import 'package:paidix/features/payments/presentation/widgets/bulk_add_payments_dialog.dart';
import 'package:paidix/features/payments/presentation/widgets/payments_filter_bar.dart';

/// Configures and launches the application or test suite.
void main() {
  testWidgets('PaymentsPage renders header, filters, search and empty state',
      (WidgetTester tester) async {
    final repo = PaymentsRepositoryImpl();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: PaymentsPage(paymentsRepository: repo),
      ),
    );
    await tester.pumpAndSettle();

    // Verify Title & Subtitle
    expect(find.text('My payments'), findsOneWidget);
    expect(find.text("Every incoming payment you've submitted."), findsOneWidget);

    // Verify Actions (Bulk add commented out as per requirement)
    expect(find.text('Bulk add'), findsNothing);
    expect(find.text('New payment'), findsWidgets);

    // Verify Filter and Search
    expect(find.text('FILTERS'), findsOneWidget);
    expect(find.text('SEARCH'), findsOneWidget);

    // Verify Empty State
    expect(find.text('No payments match this filter'), findsOneWidget);
    expect(find.text('Try clearing filters or submit a new payment.'),
        findsOneWidget);
  });

  testWidgets(
      'PaymentsPage filters section is closed by default, expands on tap with side-by-side chips slider and dropdown selection',
      (WidgetTester tester) async {
    final repo = PaymentsRepositoryImpl();

    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: PaymentsPage(paymentsRepository: repo),
      ),
    );
    await tester.pumpAndSettle();

    // 1. Closed by default: chips not visible
    expect(find.text('Range: '), findsNothing);
    expect(find.text('Currency: '), findsNothing);
    expect(find.text('Status: '), findsNothing);

    // 2. Tap FILTERS to expand
    await tester.tap(find.text('FILTERS'));
    await tester.pumpAndSettle();

    // 3. Side-by-side chips are now visible in the horizontal slider
    expect(find.text('Range: '), findsOneWidget);
    expect(find.text('All time'), findsOneWidget);
    expect(find.text('Currency: '), findsOneWidget);
    expect(find.text('All currencies'), findsOneWidget);
    expect(find.text('Status: '), findsOneWidget);
    expect(find.text('All statuses'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // 4. Tap on 'Range: ' chip which is on screen
    await tester.tap(find.text('Range: '));
    await tester.pumpAndSettle();

    // 5. Dropdown options appear with animated checkmarks
    expect(find.text('This month'), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);

    // 6. Select 'This month'
    await tester.tap(find.text('This month'));
    await tester.pumpAndSettle();

    // 7. Range chip now displays 'This month' and active badge appears
    expect(find.text('This month'), findsOneWidget);
    expect(find.text('Reset'), findsOneWidget);
    expect(find.text('1'), findsOneWidget); // active count

    // 8. Tap Reset button in the header
    await tester.tap(find.text('Reset'));
    await tester.pumpAndSettle();
    expect(find.text('All time'), findsOneWidget);
    expect(find.text('1'), findsNothing);

    // 9. Tap FILTERS to collapse
    await tester.tap(find.text('FILTERS'));
    await tester.pumpAndSettle();
    expect(find.text('Range: '), findsNothing);
  });

  testWidgets('Check PaymentsFilterBar only at 320px', (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: PaymentsFilterBar(
              filter: const PaymentFilter(),
              onFilterChanged: (_) {},
              onReset: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('FILTERS'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'PaymentsPage filters section renders smoothly across 360px, 768px, and 1200px widths with 0 overflow',
      (WidgetTester tester) async {
    final repo = PaymentsRepositoryImpl();

    for (final width in [360.0, 768.0, 1200.0]) {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: PaymentsPage(
            key: ValueKey(width),
            paymentsRepository: repo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap FILTERS to expand
      await tester.tap(find.text('FILTERS'));
      await tester.pumpAndSettle();

      expect(find.text('Range: '), findsOneWidget);
      expect(find.text('Currency: '), findsOneWidget);
      expect(find.text('Status: '), findsOneWidget);
      // No takeException so Flutter prints the full error
      // expect(ex, isNull);
    }
  });

  // ===========================================================================
  // BULK ADD TESTS (COMMENTED OUT)
  // The Bulk Add dialog and functionality are commented out as requested.
  // ===========================================================================
  /*
  testWidgets(
      'Tapping Bulk add opens BulkAddPaymentsDialog with exact controls, computes totals, adds rows, and submits batch payments',
      (WidgetTester tester) async {
    final repo = PaymentsRepositoryImpl();

    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: PaymentsPage(paymentsRepository: repo),
      ),
    );
    await tester.pumpAndSettle();

    // 1. Tap Bulk add
    await tester.tap(find.text('Bulk add'));
    await tester.pumpAndSettle();

    // 2. Dialog elements are shown
    expect(find.text('Add several payments at once'), findsOneWidget);
    expect(
        find.text(
            'Use the duplicate icon to copy a row, then change the txn ID + screenshot.'),
        findsOneWidget);
    expect(find.text('+ Add row'), findsOneWidget);
    expect(find.text('+5 rows'), findsOneWidget);
    expect(find.text('+10 rows'), findsOneWidget);
    expect(find.text('Rows: 1'), findsOneWidget);
    expect(find.text('Total amount: \$ 0.00'), findsOneWidget);

    // 3. Tap + Add row to add a second row
    await tester.tap(find.text('+ Add row'));
    await tester.pumpAndSettle();
    expect(find.text('Rows: 2'), findsOneWidget);

    // 4. Fill in sender name, confirmation code, and amount on first row
    final dialogFinder = find.byType(BulkAddPaymentsDialog);
    final textFields = find.descendant(
      of: dialogFinder,
      matching: find.byType(TextField),
    );
    expect(textFields, findsWidgets);

    // Enter Sender name
    await tester.enterText(textFields.at(0), 'Alice Morgan');
    await tester.pumpAndSettle();

    // Enter Sender company
    await tester.enterText(textFields.at(1), 'Morgan Corp');
    await tester.pumpAndSettle();

    // Enter Confirmation Code
    await tester.enterText(textFields.at(2), 'TXN-998877');
    await tester.pumpAndSettle();

    // Enter Amount
    await tester.enterText(textFields.at(3), '250.50');
    await tester.pumpAndSettle();

    // Total amount dynamically updates to $ 250.50
    expect(find.text('Total amount: \$ 250.50'), findsOneWidget);

    // 5. Submit payments
    await tester.tap(find.text('Submit payments'));
    await tester.pumpAndSettle();

    // Dialog closes
    expect(find.text('Add several payments at once'), findsNothing);

    // Check payment item exists in repository
    final submittedList = repo.payments;
    expect(submittedList.any((p) => p.sender == 'Alice Morgan'), isTrue);
  });

  testWidgets(
      'BulkAddPaymentsDialog renders smoothly on mobile (360px) and wide (1024px) without overflows',
      (WidgetTester tester) async {
    final repo = PaymentsRepositoryImpl();

    for (final width in [360.0, 1024.0]) {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: PaymentsPage(
            key: ValueKey('bulk_$width'),
            paymentsRepository: repo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Bulk add'));
      await tester.pumpAndSettle();

      expect(find.text('Add several payments at once'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Close dialog
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(find.text('Add several payments at once'), findsNothing);
    }
  });

  testWidgets(
      'BulkAddPaymentsDialog tilt mode and landscape orientations render with zero pixel overflow',
      (WidgetTester tester) async {
    final repo = PaymentsRepositoryImpl();
    for (final size in [
      const Size(740, 360),
      const Size(800, 360),
      const Size(850, 390),
      const Size(896, 414),
      const Size(640, 320),
    ]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: PaymentsPage(
            key: ValueKey('page_${size.width}_${size.height}'),
            paymentsRepository: repo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Bulk add'));
      await tester.pumpAndSettle();

      expect(find.text('Add several payments at once'), findsOneWidget);
      expect(find.text('Submit payments'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Close dialog
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(find.text('Add several payments at once'), findsNothing);
    }
  });
  */

  testWidgets(
      'PaymentsPage mock data, recycler view animation, and interactive Showing Rows Page pagination controls',
      (WidgetTester tester) async {
    final repo = PaymentsRepositoryImpl(createTestPayments());

    expect(repo.payments.length, equals(32));
    expect(repo.payments[0].reference, equals('PBX-2026-001332'));
    expect(repo.payments[0].sender, equals('Ward Trucking Atlanta Llc'));
    expect(repo.payments[1].reference, equals('PBX-2026-001331'));
    expect(repo.payments[2].reference, equals('PBX-2026-001333'));
    expect(repo.payments[3].reference, equals('PBX-2026-001330'));

    // 1. Wide Viewport (1024x1800)
    tester.view.physicalSize = const Size(1024, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: PaymentsPage(paymentsRepository: repo),
      ),
    );
    await tester.pumpAndSettle();

    // Verify initial pagination state
    expect(find.text('Showing 1–20 of 32'), findsOneWidget);
    expect(find.text('Rows: '), findsOneWidget);
    expect(find.text('10'), findsOneWidget);
    expect(find.text('20'), findsOneWidget);
    expect(find.text('30'), findsOneWidget);
    expect(find.text('50'), findsOneWidget);
    expect(find.text('100'), findsOneWidget);
    expect(find.text('Custom'), findsOneWidget);

    // 2. Change rows to 10
    await tester.tap(find.text('10'));
    await tester.pumpAndSettle();
    expect(find.text('Showing 1–10 of 32'), findsOneWidget);

    // 3. Navigate forward to Page 2
    await tester.tap(find.text('Next >'));
    await tester.pumpAndSettle();
    expect(find.text('Showing 11–20 of 32'), findsOneWidget);

    // 4. Navigate to last page via double arrow
    await tester.tap(find.text('»'));
    await tester.pumpAndSettle();
    expect(find.text('Showing 31–32 of 32'), findsOneWidget);

    // 5. Navigate to first page via double arrow
    await tester.tap(find.text('«'));
    await tester.pumpAndSettle();
    expect(find.text('Showing 1–10 of 32'), findsOneWidget);

    // 6. Tap Custom chip to open custom rows dialog
    await tester.tap(find.text('Custom'));
    await tester.pumpAndSettle();
    expect(find.text('Custom rows per page'), findsOneWidget);

    // Tap quick preset '5' in dialog
    await tester.tap(find.text('5'));
    await tester.pumpAndSettle();
    expect(find.text('Showing 1–5 of 32'), findsOneWidget);

    // 7. Mobile Viewport (360x800) with animated recycler list
    tester.view.physicalSize = const Size(360, 800);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: PaymentsPage(paymentsRepository: repo),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('PBX-2026-001332'), findsOneWidget);
    expect(find.text('Showing 1–5 of 32'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
