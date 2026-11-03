import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paidix/app/theme/app_theme.dart';
import 'package:paidix/core/widgets/paidi_x_bottom_nav_bar.dart';

void main() {
  group('PaidiXBottomNavBar Zero Regression Navigation & Shadow Blur Suite', () {
    testWidgets(
        'Backward and forward navigation between tabs does not throw non-negative blurRadius assertion during animation',
        (WidgetTester tester) async {
      int activeIndex = 3; // Start on New Payment (index 3)

      Widget buildNavBar() {
        return MaterialApp(
          theme: AppTheme.darkTheme,
          home: StatefulBuilder(
            builder: (context, setState) {
              return Scaffold(
                bottomNavigationBar: PaidiXBottomNavBar(
                  selectedIndex: activeIndex,
                  onItemSelected: (idx) {
                    setState(() => activeIndex = idx);
                  },
                  items: const [
                    PaidiXBottomNavItem(
                      icon: Icons.grid_view_outlined,
                      activeIcon: Icons.grid_view_rounded,
                      label: 'Dashboard',
                    ),
                    PaidiXBottomNavItem(
                      icon: Icons.badge_outlined,
                      activeIcon: Icons.badge_rounded,
                      label: 'Onboarding',
                    ),
                    PaidiXBottomNavItem(
                      icon: Icons.receipt_long_outlined,
                      activeIcon: Icons.receipt_long_rounded,
                      label: 'My Payments',
                    ),
                    PaidiXBottomNavItem(
                      icon: Icons.add_circle_outline_rounded,
                      activeIcon: Icons.add_circle_rounded,
                      label: 'New Payment',
                    ),
                  ],
                ),
              );
            },
          ),
        );
      }

      await tester.pumpWidget(buildNavBar());
      await tester.pumpAndSettle();

      // Backward navigation: New Payment (3) -> My Payments (2)
      await tester.tap(find.text('My Payments'));
      // Step through intermediate animation frames (critical for catching non-negative assertion)
      for (int i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 40));
        expect(tester.takeException(), isNull);
      }
      await tester.pumpAndSettle();
      expect(activeIndex, 2);

      // Backward navigation: My Payments (2) -> Onboarding (1)
      await tester.tap(find.text('Onboarding'));
      for (int i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 40));
        expect(tester.takeException(), isNull);
      }
      await tester.pumpAndSettle();
      expect(activeIndex, 1);

      // Backward navigation: Onboarding (1) -> Dashboard (0)
      await tester.tap(find.text('Dashboard'));
      for (int i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 40));
        expect(tester.takeException(), isNull);
      }
      await tester.pumpAndSettle();
      expect(activeIndex, 0);

      // Forward navigation: Dashboard (0) -> New Payment (3)
      await tester.tap(find.text('New Payment'));
      for (int i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 40));
        expect(tester.takeException(), isNull);
      }
      await tester.pumpAndSettle();
      expect(activeIndex, 3);

      // Forward navigation: New Payment (3) -> Dashboard (0) -> My Payments (2) -> New Payment (3)
      await tester.tap(find.text('Dashboard'));
      for (int i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 40));
        expect(tester.takeException(), isNull);
      }
      await tester.pumpAndSettle();

      await tester.tap(find.text('My Payments'));
      for (int i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 40));
        expect(tester.takeException(), isNull);
      }
      await tester.pumpAndSettle();

      await tester.tap(find.text('New Payment'));
      for (int i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 40));
        expect(tester.takeException(), isNull);
      }
      await tester.pumpAndSettle();

      expect(activeIndex, 3);
      expect(tester.takeException(), isNull);
    });
  });
}

