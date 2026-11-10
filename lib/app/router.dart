/// Defines application routes, page transitions, and shared route-level dependencies.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/widgets/app_shell.dart';
import '../core/widgets/server_error_page.dart';
import '../features/auth/presentation/pages/sign_in_page.dart';
import '../features/auth/presentation/pages/sign_up_page.dart';
import '../features/dashboard/presentation/pages/dashboard_page.dart';
import '../features/kyc/presentation/pages/kyc_page.dart';
import '../features/payments/data/payments_repository_impl.dart';
import '../features/payments/presentation/pages/new_payment_page.dart';
import '../features/payments/presentation/pages/payments_page.dart';
import '../features/profile/data/user_profile_repository.dart';
import '../features/profile/domain/user_profile.dart';
import '../features/profile/presentation/pages/onboarding_profile_page.dart';
import '../features/settings/presentation/pages/account_settings_page.dart';

// Shared instance of the Payments repository for state synchronization (clean empty state)
final sharedPaymentsRepository = PaymentsRepositoryImpl();

/// Root navigator key for modal overlays, global toasts, and security timeout dialogs
final rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'rootNavigator');

/// Creates the router with public routes, app-shell routes, and page transitions.
GoRouter createAppRouter({String initialLocation = '/signin'}) {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/signin',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const SignInPage(),
          // Slide up + fade — elegant upward reveal with cubic easing
          transitionDuration: const Duration(milliseconds: 380),
          reverseTransitionDuration: const Duration(milliseconds: 300),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final slideAnim = Tween<Offset>(
              begin: const Offset(0.0, 0.06),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            ));
            final fadeAnim = CurvedAnimation(
              parent: animation,
              curve: const Interval(0.0, 0.75, curve: Curves.easeOut),
            );
            return SlideTransition(
              position: slideAnim,
              child: FadeTransition(opacity: fadeAnim, child: child),
            );
          },
        ),
      ),
      GoRoute(
        path: '/signup',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const SignUpPage(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      ),
      GoRoute(
        path: '/kyc',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: KycPage(
            resubmission: state.uri.queryParameters['resubmit'] == 'true',
          ),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      ),
      GoRoute(
        path: '/server-error',
        pageBuilder: (context, state) {
          final info = state.extra is ServerErrorInfo
              ? state.extra as ServerErrorInfo
              : const ServerErrorInfo();
          return CustomTransitionPage(
            key: state.pageKey,
            child: ServerErrorPage(info: info),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
          );
        },
      ),
      ShellRoute(
        builder: (context, state, child) {
          return AppShell(
            currentPath: state.matchedLocation,
            child: child,
          );
        },
        routes: [
          GoRoute(
            path: '/app/dashboard',
            pageBuilder: (context, state) => CustomTransitionPage(
              key: state.pageKey,
              child:
                  DashboardPage(paymentsRepository: sharedPaymentsRepository),
              transitionDuration: const Duration(milliseconds: 320),
              reverseTransitionDuration: const Duration(milliseconds: 260),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                final curve = CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOutCubic,
                  reverseCurve: Curves.easeInCubic,
                );
                final slideAnim = Tween<Offset>(
                  begin: const Offset(-0.06, 0.0),
                  end: Offset.zero,
                ).animate(curve);
                return SlideTransition(
                  position: slideAnim,
                  child: FadeTransition(opacity: curve, child: child),
                );
              },
            ),
          ),
          GoRoute(
            path: '/app/onboarding',
            redirect: (context, state) {
              final profile = UserProfileRepository.instance.profile;
              if (profile.kycStatus == KycReviewStatus.verified) {
                return '/app/dashboard';
              }
              return null;
            },
            pageBuilder: (context, state) => CustomTransitionPage(
              key: state.pageKey,
              child: const OnboardingProfilePage(),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                return FadeTransition(opacity: animation, child: child);
              },
            ),
          ),
          GoRoute(
            path: '/app/settings',
            pageBuilder: (context, state) => CustomTransitionPage(
              key: state.pageKey,
              child: const AccountSettingsPage(),
              transitionDuration: const Duration(milliseconds: 340),
              reverseTransitionDuration: const Duration(milliseconds: 260),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                final slideAnim = Tween<Offset>(
                  begin: const Offset(1.0, 0.0),
                  end: Offset.zero,
                ).animate(CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOutCubic,
                ));
                final fadeAnim = CurvedAnimation(
                  parent: animation,
                  curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
                );
                return SlideTransition(
                  position: slideAnim,
                  child: FadeTransition(opacity: fadeAnim, child: child),
                );
              },
            ),
          ),
          GoRoute(
            path: '/app/payments',
            pageBuilder: (context, state) => CustomTransitionPage(
              key: state.pageKey,
              child: PaymentsPage(paymentsRepository: sharedPaymentsRepository),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                return FadeTransition(opacity: animation, child: child);
              },
            ),
            routes: [
              GoRoute(
                path: 'new',
                pageBuilder: (context, state) => CustomTransitionPage(
                  key: state.pageKey,
                  child: NewPaymentPage(
                      paymentsRepository: sharedPaymentsRepository),
                  transitionsBuilder:
                      (context, animation, secondaryAnimation, child) {
                    return SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0.05, 0),
                        end: Offset.zero,
                      ).animate(CurvedAnimation(
                          parent: animation, curve: Curves.easeOutCubic)),
                      child: FadeTransition(opacity: animation, child: child),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

final appRouter = createAppRouter(initialLocation: '/signin');
