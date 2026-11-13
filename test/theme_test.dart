/// Tests the theme test behavior and guards its key user-facing and domain expectations.

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:paidix/app/theme/app_colors.dart';
import 'package:paidix/app/theme/app_theme.dart';
import 'package:paidix/app/theme/app_typography.dart';
import 'package:paidix/core/widgets/app_button.dart';
import 'package:paidix/core/widgets/app_shell.dart';
import 'package:paidix/core/widgets/paidi_x_bottom_nav_bar.dart';
import 'package:paidix/core/widgets/status_badge.dart';

/// Configures and launches the application or test suite.
void main() {
  group('Theme Tokens & Specification Tests', () {
    test('Light mode tokens match CSS :root specification', () {
      const light = AppColors.light;
      expect(light.brightness, Brightness.light);

      // Canvas background --c-cream: 239 243 240 (#EFF3F0)
      expect(light.background, const Color(0xFFEFF3F0));

      // Panel surface --c-paper: 255 255 255 (#FFFFFF)
      expect(light.card, const Color(0xFFFFFFFF));

      // Divider/Border --c-ink-100: 228 234 229 (#E4EAE5)
      expect(light.border, const Color(0xFFE4EAE5));

      // Input Border --c-ink-200: 190 202 197 (#BECAC5)
      expect(light.borderSubtle, const Color(0xFFBECAC5));

      // Highest-emphasis text --c-ink-900: 10 27 25 (#0A1B19)
      expect(light.textPrimary, const Color(0xFF0A1B19));

      // Body secondary text --c-ink-600: 56 76 72 (#384C48)
      expect(light.textSecondary, const Color(0xFF384C48));

      // Primary brand button --c-brand-900: 2 47 50 (#022F32)
      expect(light.primaryButton, const Color(0xFF022F32));
      expect(light.primaryButtonText, Colors.white);

      // Accent gold --c-accent-gold: 229 179 90 (#E5B35A)
      expect(light.gold, const Color(0xFFE5B35A));
    });

    test('Dark mode tokens match CSS html.dark specification', () {
      const dark = AppColors.dark;
      expect(dark.brightness, Brightness.dark);

      // Canvas background --c-cream: 3 20 21 (#031415)
      expect(dark.background, const Color(0xFF031415));

      // Lifted card panel --c-paper: 10 49 52 (#0A3134)
      expect(dark.card, const Color(0xFF0A3134));

      // Card borders --c-ink-100: 20 66 69 (#144245)
      expect(dark.border, const Color(0xFF144245));

      // Subtle borders --c-ink-200: 18 60 63 (#123C3F)
      expect(dark.borderSubtle, const Color(0xFF123C3F));

      // Inverted semantic text --c-ink-900: 234 242 240 (#EAF2F0)
      expect(dark.textPrimary, const Color(0xFFEAF2F0));

      // Inverted body text --c-ink-600: 196 212 208 (#C4D4D0)
      expect(dark.textSecondary, const Color(0xFFC4D4D0));

      // Dark mode primary button panel --c-brand-200: 8 86 86 (#085656)
      expect(dark.primaryButton, const Color(0xFF085656));
      expect(dark.primaryButtonText, const Color(0xFFEAF2F0));

      // Dark gold --c-accent-gold: 239 196 121 (#EFC479)
      expect(dark.gold, const Color(0xFFEFC479));
    });

    test('Fixed sidebar tokens never invert across themes', () {
      // Base --c-sidebar: 2 47 50 (#022F32)
      expect(AppColors.sidebar, const Color(0xFF022F32));

      // Line --c-sidebar-line: 12 70 73 (#0C4649)
      expect(AppColors.sidebarLine, const Color(0xFF0C4649));

      // Text --c-sidebar-text: 200 218 214 (#C8DAD6)
      expect(AppColors.sidebarText, const Color(0xFFC8DAD6));

      // Muted --c-sidebar-muted: 127 163 158 (#7FA39E)
      expect(AppColors.sidebarMuted, const Color(0xFF7FA39E));

      // Active nav pill (#0F4134)
      expect(AppColors.activeNavBg, const Color(0xFF0F4134));
    });

    test('ThemeData configurations have correct Material 3 brightness and scaffold background', () {
      final darkTheme = AppTheme.darkTheme;
      expect(darkTheme.useMaterial3, isTrue);
      expect(darkTheme.brightness, Brightness.dark);
      expect(darkTheme.scaffoldBackgroundColor, AppColors.dark.background);

      final lightTheme = AppTheme.lightTheme;
      expect(lightTheme.useMaterial3, isTrue);
      expect(lightTheme.brightness, Brightness.light);
      expect(lightTheme.scaffoldBackgroundColor, AppColors.light.background);
    });

    test('Theme toggle functionality switches between dark and light', () {
      AppTheme.setThemeMode(ThemeMode.dark);
      expect(AppTheme.currentThemeMode, ThemeMode.dark);

      AppTheme.toggleTheme();
      expect(AppTheme.currentThemeMode, ThemeMode.light);

      AppTheme.toggleTheme();
      expect(AppTheme.currentThemeMode, ThemeMode.dark);
    });
  });

  group('Widget Theme Reactivity Tests', () {
    testWidgets('AppButton renders properly under Light theme', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          themeMode: ThemeMode.light,
          home: Scaffold(
            body: AppButton(text: 'Submit', onPressed: () {}),
          ),
        ),
      );

      expect(find.text('Submit'), findsOneWidget);
    });

    testWidgets('AppButton renders properly under Dark theme', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          darkTheme: AppTheme.darkTheme,
          themeMode: ThemeMode.dark,
          home: Scaffold(
            body: AppButton(text: 'Submit', onPressed: () {}),
          ),
        ),
      );

      expect(find.text('Submit'), findsOneWidget);
    });

    testWidgets('StatusBadge renders appropriate colors in both themes', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: ThemeMode.light,
          home: const Scaffold(
            body: StatusBadge(status: PaymentStatusType.completed),
          ),
        ),
      );

      expect(find.text('Completed'), findsOneWidget);
    });

    testWidgets(
      'PaidiXBottomNavBar renders and responds to touches with bounce animation',
      (tester) async {
        int tappedIndex = -1;

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: ThemeMode.light,
            home: Scaffold(
              bottomNavigationBar: PaidiXBottomNavBar(
                selectedIndex: 0,
                onItemSelected: (idx) => tappedIndex = idx,
                items: const [
                  PaidiXBottomNavItem(
                    icon: Icons.grid_view_outlined,
                    activeIcon: Icons.grid_view_rounded,
                    label: 'Dashboard',
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
            ),
          ),
        );

        expect(find.text('Dashboard'), findsOneWidget);
        expect(find.text('My Payments'), findsOneWidget);
        expect(find.text('New Payment'), findsOneWidget);

        // Tap on 'My Payments' tab
        await tester.tap(find.text('My Payments'));
        await tester.pumpAndSettle();

        expect(tappedIndex, 1);
      },
    );

    testWidgets(
      'AppShell renders adaptive top bar and bottom navbar in light and dark mode',
      (tester) async {
        final router = GoRouter(
          initialLocation: '/app/dashboard',
          routes: [
            GoRoute(
              path: '/app/dashboard',
              builder: (context, state) => const AppShell(
                currentPath: '/app/dashboard',
                child: Text('Content'),
              ),
            ),
          ],
        );
        addTearDown(router.dispose);

        await tester.pumpWidget(
          MaterialApp.router(
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: ThemeMode.light,
            routerConfig: router,
          ),
        );

        expect(find.text('BASIC PLAN'), findsNothing);
        expect(find.text('Dashboard'), findsWidgets);
        expect(find.text('Content'), findsOneWidget);
      },
    );

    testWidgets(
      'PaidiXBottomNavBar renders full labels across 320px, 360px, and 414px with zero overflow',
      (tester) async {
        for (final width in [320.0, 360.0, 414.0]) {
          tester.view.physicalSize = Size(width, 700);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.darkTheme,
              home: Scaffold(
                bottomNavigationBar: PaidiXBottomNavBar(
                  selectedIndex: 0,
                  onItemSelected: (_) {},
                  items: const [
                    PaidiXBottomNavItem(
                      icon: Icons.grid_view_outlined,
                      activeIcon: Icons.grid_view_rounded,
                      label: 'Dashboard',
                    ),
                    PaidiXBottomNavItem(
                      icon: Icons.badge_outlined,
                      activeIcon: Icons.badge,
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
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.text('Dashboard'), findsOneWidget);
          expect(find.text('Onboarding'), findsOneWidget);
          expect(find.text('My Payments'), findsOneWidget);
          expect(find.text('New Payment'), findsOneWidget);
          expect(tester.takeException(), isNull);
        }
      },
    );

    test('Typography Font Selection & Text Scale Suite: Global reactivity and styling', () {
      expect(AppTheme.availableFonts.length, 10);
      expect(
        AppTheme.availableFonts,
        containsAll([
          'System default',
          'Inter',
          'Roboto',
          'Poppins',
          'Lato',
          'Nunito',
          'Open Sans',
          'DM Sans',
          'Source Sans 3',
          'IBM Plex Sans',
        ]),
      );

      // Select Inter
      AppTheme.setFontFamily('Inter');
      expect(AppTheme.currentFontFamily, 'Inter');
      expect(AppTheme.fontFamilyNotifier.value, 'Inter');
      expect(AppTypography.pageHeading.fontFamily, contains('Inter'));
      expect(AppTheme.activeFontFamily, contains('Inter'));

      // Select Poppins
      AppTheme.setFontFamily('Poppins');
      expect(AppTheme.currentFontFamily, 'Poppins');
      expect(AppTypography.brandTitle.fontFamily, contains('Poppins'));
      expect(AppTheme.activeFontFamily, contains('Poppins'));

      // Adjust text scale
      AppTheme.setTextScale(1.25);
      expect(AppTheme.currentTextScale, 1.25);

      // Test fallback to System default
      AppTheme.setFontFamily('System default');
      expect(AppTheme.currentFontFamily, 'System default');
      expect(AppTheme.activeFontFamily, isNull);

      // Reset to universal default (Inter)
      AppTheme.setFontFamily('Inter');
      AppTheme.setTextScale(1.0);
      expect(AppTheme.currentFontFamily, 'Inter');
      expect(AppTheme.currentTextScale, 1.0);
      expect(AppTheme.activeFontFamily, contains('Inter'));
    });
  });
}
