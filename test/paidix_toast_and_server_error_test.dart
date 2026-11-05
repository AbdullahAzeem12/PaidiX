import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paidix/app/theme/app_theme.dart';
import 'package:paidix/core/widgets/paidix_toast.dart';
import 'package:paidix/core/widgets/server_error_page.dart';

void main() {
  group('PaidiXToast Feedback & Alert Suite', () {
    testWidgets('PaidiXToast.showSuccess displays emerald checkmark and auto-dismisses',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  PaidiXToast.showSuccess(
                    context,
                    'Payment verified successfully!',
                    duration: const Duration(seconds: 2),
                  );
                },
                child: const Text('Show Success'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Success'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('SUCCESS'), findsOneWidget);
      expect(find.text('Payment verified successfully!'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);

      // Verify auto-dismiss after duration
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(find.text('Payment verified successfully!'), findsNothing);
    });

    testWidgets('PaidiXToast.showWarning displays amber alert icon', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  PaidiXToast.showWarning(
                    context,
                    'Please fill in all required fields.',
                  );
                },
                child: const Text('Show Warning'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Warning'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('ATTENTION'), findsOneWidget);
      expect(find.text('Please fill in all required fields.'), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    });

    testWidgets('PaidiXToast.showServerError displays retry action and triggers callback',
        (tester) async {
      bool retried = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  PaidiXToast.showServerError(
                    context,
                    message: 'Settlement cluster timed out.',
                    errorCode: 'ERR_504',
                    onRetry: () => retried = true,
                  );
                },
                child: const Text('Show Server Error'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Server Error'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('SERVER INTERRUPTED'), findsOneWidget);
      expect(find.text('Settlement cluster timed out. (ERR_504)'), findsOneWidget);
      expect(find.text('RETRY'), findsOneWidget);

      await tester.tap(find.text('RETRY'));
      await tester.pumpAndSettle();
      expect(retried, isTrue);
    });

    testWidgets('PaidiXToast close button dismisses toast immediately', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  PaidiXToast.showInfo(context, 'Stealth Mode Enabled');
                },
                child: const Text('Show Info'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Info'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Stealth Mode Enabled'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Stealth Mode Enabled'), findsNothing);
    });

    testWidgets('PaidiXToast renders at the top of the screen and supports swipe-up to dismiss',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  PaidiXToast.showSuccess(context, 'Top position verified');
                },
                child: const Text('Show Toast'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Toast'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final toastTopLeft = tester.getTopLeft(find.text('Top position verified'));
      // Verifies toast is near the top edge (< 100px from top) rather than bottom (> 500px)
      expect(toastTopLeft.dy, lessThan(100.0));

      // Test swipe-up dismissal
      await tester.drag(find.text('Top position verified'), const Offset(0, -120));
      await tester.pumpAndSettle();

      expect(find.text('Top position verified'), findsNothing);
    });
  });

  group('ServerErrorPage & Dialog Suite', () {
    testWidgets('ServerErrorPage renders diagnostics, retry button, and handles diagnostics expansion',
        (tester) async {
      bool retryCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: ServerErrorPage(
            info: const ServerErrorInfo(
              statusCode: 503,
              title: 'Settlement Engine Offline',
              message: 'Temporary latency connecting to 1-LINK.',
              errorCode: 'ERR_503_TEST',
            ),
            onRetry: () => retryCalled = true,
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Header, Badge & Text
      expect(find.text('503 • SERVER LATENCY DETECTED'), findsOneWidget);
      expect(find.text('Settlement Engine Offline'), findsOneWidget);
      expect(find.text('Temporary latency connecting to 1-LINK.'), findsOneWidget);

      // Expand diagnostics
      expect(find.text('View Diagnostic Details'), findsOneWidget);
      await tester.tap(find.text('View Diagnostic Details'));
      await tester.pumpAndSettle();

      expect(find.text('Hide Diagnostic Details'), findsOneWidget);
      expect(find.text('ERR_503_TEST'), findsOneWidget);
      expect(find.text('Pending SBP Handshake'), findsOneWidget);

      // Retry action
      final retryBtn = find.text('Try Again');
      await tester.ensureVisible(retryBtn);
      await tester.tap(retryBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1400));
      await tester.pumpAndSettle();

      expect(retryCalled, isTrue);
    });

    testWidgets('ServerErrorDialog displays popup alert and handles retry action',
        (tester) async {
      bool dialogRetried = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  ServerErrorDialog.show(
                    context,
                    info: const ServerErrorInfo(
                      statusCode: 500,
                      title: 'Gateway Failure',
                      message: 'Could not submit payment.',
                    ),
                    onRetry: () => dialogRetried = true,
                  );
                },
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('500 • SERVER ERROR'), findsOneWidget);
      expect(find.text('Gateway Failure'), findsOneWidget);
      expect(find.text('Could not submit payment.'), findsOneWidget);
      expect(find.text('Dismiss'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(dialogRetried, isTrue);
      expect(find.text('Gateway Failure'), findsNothing);
    });
  });
}
