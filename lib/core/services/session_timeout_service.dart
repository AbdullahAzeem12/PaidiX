/// Defines session timeout service in the application core utilities and reusable widgets.

import 'dart:async';
import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';
import '../../app/router.dart';
import '../../features/profile/data/user_profile_repository.dart';
import '../widgets/paidix_toast.dart';
import '../widgets/session_timeout_dialog.dart';

/// Professional Active Session Inactivity Service for PaidiX.
///
/// Automatically tracks user activity (touch, pointer, scroll, gestures, keys)
/// across all authenticated screens. If the user remains completely idle
/// for 5 minutes (default: [timeoutDuration]), the active session expires,
/// presenting an aesthetic [SessionTimeoutDialog].
///
/// When the user confirms by tapping "Log In Again":
/// 1. The session is closed and user credentials are reset.
/// 2. User is immediately navigated to `/signin`.
/// 3. A warning toast is displayed explaining the security timeout.
class SessionTimeoutService {
  SessionTimeoutService._();

  static final SessionTimeoutService instance = SessionTimeoutService._();

  /// Default idle timeout duration for active authenticated banking sessions (5 minutes).
  Duration timeoutDuration = const Duration(minutes: 5);

  Timer? _inactivityTimer;
  bool _isSessionActive = false;
  bool _isDialogShowing = false;
  BuildContext? _boundContext;

  /// Whether an active logged-in session is currently being monitored.
  bool get isSessionActive => _isSessionActive;

  /// Whether the session timeout modal dialog is currently open on screen.
  bool get isDialogShowing => _isDialogShowing;

  /// Starts or restarts the active session idle timer.
  /// Typically called when the authenticated [AppShell] mounts.
  void startSession(BuildContext context) {
    _boundContext = context;
    _isSessionActive = true;
    _isDialogShowing = false;
    recordUserActivity();
  }

  /// Records any user activity (taps, drags, scrolls, keystrokes, gestures)
  /// and resets the 5-minute inactivity countdown.
  void recordUserActivity() {
    if (!_isSessionActive || _isDialogShowing) return;

    _inactivityTimer?.cancel();
    _inactivityTimer = Timer(timeoutDuration, _handleInactivityTimeout);
  }

  /// Stops session monitoring and cancels any pending timer.
  /// Called when user logs out or leaves authenticated routes.
  void stopSession() {
    _inactivityTimer?.cancel();
    _inactivityTimer = null;
    _isSessionActive = false;
    _isDialogShowing = false;
  }

  /// Internal callback invoked when 5 minutes of total user inactivity elapse.
  void _handleInactivityTimeout() {
    if (!_isSessionActive || _isDialogShowing) return;

    _isDialogShowing = true;
    final ctx = rootNavigatorKey.currentContext ?? _boundContext;

    if (ctx != null && ctx.mounted) {
      SessionTimeoutDialog.show(ctx).then((_) {
        _isDialogShowing = false;
      });
    }
  }

  /// Helper to trigger timeout dialog immediately for testing and verification.
  void triggerTimeoutForTesting(BuildContext context) {
    _isSessionActive = true;
    _boundContext = context;
    _handleInactivityTimeout();
  }

  /// Logs the user out cleanly, resets repository states, navigates to `/signin`,
  /// and presents the security toast message.
  void handleLogout(BuildContext context) {
    stopSession();
    UserProfileRepository.instance.resetToDefault();

    try {
      context.go('/signin');
    } catch (_) {
      try {
        GoRouter.of(context).go('/signin');
      } catch (_) {
        rootNavigatorKey.currentState?.pushReplacementNamed('/signin');
      }
    }

    // Display aesthetic security alert banner at the top of the sign-in screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final toastCtx = rootNavigatorKey.currentContext ?? context;
      try {
        PaidiXToast.showWarning(
          toastCtx,
          'Session expired due to 5 minutes of inactivity. Please sign in again.',
          title: 'Session Timed Out',
        );
      } catch (_) {}
    });
  }
}
