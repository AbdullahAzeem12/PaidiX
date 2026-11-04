import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:paidix/app/theme/app_theme.dart';
import 'package:paidix/core/widgets/profile_menu_dialog.dart';
import 'package:paidix/features/profile/data/user_profile_repository.dart';
import 'package:paidix/features/profile/domain/user_profile.dart';

void main() {
  testWidgets('ProfileMenuDialog displays user header and options, logout navigates to /signin',
      (WidgetTester tester) async {
    final profile = UserProfile(
      fullName: 'Hassan Azeem',
      email: 'hassnazeem560@gmail.com',
      phoneNumber: '+923001234567',
      cnicNumber: '35202-0450461-5',
      city: 'Lahore',
      address: 'Canalberg',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    UserProfileRepository.instance.profileNotifier.value = profile;

    bool navigatedToSignIn = false;
    final router = GoRouter(
      initialLocation: '/test',
      routes: [
        GoRoute(
          path: '/test',
          builder: (context, state) => Scaffold(
            body: Center(
              child: Builder(
                builder: (ctx) => ElevatedButton(
                  onPressed: () {
                    ProfileMenuDialog.show(
                      context: ctx,
                      userProfile: profile,
                      isMobile: true,
                    );
                  },
                  child: const Text('Open Menu'),
                ),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/signin',
          builder: (context, state) {
            navigatedToSignIn = true;
            return const Scaffold(body: Text('Sign In Page'));
          },
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp.router(
        theme: AppTheme.darkTheme,
        routerConfig: router,
      ),
    );
    await tester.pumpAndSettle();

    // Tap button to open profile menu
    await tester.tap(find.text('Open Menu'));
    await tester.pumpAndSettle();

    // Verify user information header
    expect(find.text('Hassan Azeem'), findsOneWidget);
    expect(find.text('hassnazeem560@gmail.com'), findsOneWidget);

    // Verify options
    expect(find.text('Account Settings'), findsOneWidget);
    expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
    expect(find.text('Logout'), findsOneWidget);
    expect(find.byIcon(Icons.logout_rounded), findsOneWidget);

    // Tap Logout
    await tester.tap(find.text('Logout'));
    await tester.pumpAndSettle();

    // Verify navigation to sign in and dialog closed
    expect(navigatedToSignIn, isTrue);
    expect(find.text('Sign In Page'), findsOneWidget);
  });

  testWidgets('ProfileMenuDialog contains theme changer option and toggles theme smoothly',
      (WidgetTester tester) async {
    final profile = UserProfile(
      fullName: 'Hassan Azeem',
      email: 'hassnazeem560@gmail.com',
      phoneNumber: '+923001234567',
      cnicNumber: '35202-0450461-5',
      city: 'Lahore',
      address: 'Canalberg',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    AppTheme.setThemeMode(ThemeMode.light);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        home: Scaffold(
          body: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () {
                ProfileMenuDialog.show(
                  context: ctx,
                  userProfile: profile,
                  isMobile: true,
                );
              },
              child: const Text('Open Profile Menu'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open Profile Menu'));
    await tester.pumpAndSettle();

    // Verify Dark Mode tile is displayed initially under light theme
    expect(find.text('Dark Mode'), findsOneWidget);
    expect(find.byIcon(Icons.dark_mode_rounded), findsOneWidget);

    // Tap theme toggle option
    await tester.tap(find.text('Dark Mode'));
    await tester.pumpAndSettle();

    // Verify theme changed to dark mode and tile displays Light Mode option
    expect(AppTheme.currentThemeMode, ThemeMode.dark);
    expect(find.text('Light Mode'), findsOneWidget);
    expect(find.byIcon(Icons.light_mode_rounded), findsOneWidget);

    // Toggle back to light mode
    await tester.tap(find.text('Light Mode'));
    await tester.pumpAndSettle();
    expect(AppTheme.currentThemeMode, ThemeMode.light);
    expect(find.text('Dark Mode'), findsOneWidget);
  });
}
