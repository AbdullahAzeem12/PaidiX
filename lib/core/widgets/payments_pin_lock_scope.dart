import 'package:flutter/widgets.dart';

/// Exposes the authenticated Payments PIN state and page lock action to app pages.
class PaymentsPinLockScope extends InheritedWidget {
  final bool isConfigured;
  final VoidCallback onLockDashboard;
  final VoidCallback onLockPayments;

  const PaymentsPinLockScope({
    super.key,
    required this.isConfigured,
    required this.onLockDashboard,
    required this.onLockPayments,
    required super.child,
  });

  static PaymentsPinLockScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<PaymentsPinLockScope>();
  }

  @override
  bool updateShouldNotify(PaymentsPinLockScope oldWidget) {
    return isConfigured != oldWidget.isConfigured ||
        onLockDashboard != oldWidget.onLockDashboard ||
        onLockPayments != oldWidget.onLockPayments;
  }
}
