import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/widgets/app_shell.dart';
import '../features/auth/presentation/pages/sign_in_page.dart';
import '../features/auth/presentation/pages/sign_up_page.dart';
import '../features/dashboard/presentation/pages/dashboard_page.dart';
import '../features/kyc/presentation/pages/kyc_page.dart';
import '../features/payments/data/payments_repository_impl.dart';
import '../features/payments/presentation/pages/new_payment_page.dart';
import '../features/payments/presentation/pages/payments_page.dart';
import '../features/profile/presentation/pages/onboarding_profile_page.dart';

// Shared instance of the Payments repository for state synchronization
final sharedPaymentsRepository = PaymentsRepositoryImpl();

GoRouter createAppRouter({String initialLocation = '/signup'}) {
  return GoRouter(
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
          child: const KycPage(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
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
              child: DashboardPage(paymentsRepository: sharedPaymentsRepository),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                return FadeTransition(opacity: animation, child: child);
              },
            ),
          ),
          GoRoute(
            path: '/app/onboarding',
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

final appRouter = createAppRouter(initialLocation: '/signup');
