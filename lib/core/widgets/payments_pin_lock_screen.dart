import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import '../../app/theme/app_colors.dart';

/// Blocks a protected app page until the backend verifies the user's PIN.
class PaymentsPinLockScreen extends StatefulWidget {
  final String title;
  final Future<bool> Function(String pin) onUnlock;
  final VoidCallback onForgotPin;

  const PaymentsPinLockScreen({
    super.key,
    this.title = 'Dashboard is locked.',
    required this.onUnlock,
    required this.onForgotPin,
  });

  @override
  State<PaymentsPinLockScreen> createState() => _PaymentsPinLockScreenState();
}

class _PaymentsPinLockScreenState extends State<PaymentsPinLockScreen> {
  final _pinController = TextEditingController();
  bool _isSubmitting = false;
  String? _error;

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _unlock() async {
    final pin = _pinController.text.trim();
    if (pin.length < 4 || pin.length > 8) {
      setState(() => _error = 'Enter your 4–8 digit Payments PIN.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    try {
      if (await widget.onUnlock(pin)) {
        _pinController.clear();
      } else if (mounted) {
        setState(() => _error = 'That PIN is incorrect. Please try again.');
        _pinController.clear();
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error =
              'We could not verify your PIN. Check your connection and retry.';
        });
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return ColoredBox(
      color: colors.background,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
              decoration: BoxDecoration(
                color: colors.card,
                border: Border.all(color: colors.border),
                borderRadius: BorderRadius.circular(28),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: colors.gold.withValues(alpha: .14),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.lock_outline_rounded,
                        color: colors.gold, size: 34),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    widget.title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Enter your Payments PIN to continue on this device.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: colors.textSecondary, fontSize: 16),
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: 240,
                    child: TextField(
                      controller: _pinController,
                      autofocus: true,
                      obscureText: true,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(8),
                      ],
                      textAlign: TextAlign.center,
                      onSubmitted: (_) => _isSubmitting ? null : _unlock(),
                      decoration: InputDecoration(
                        hintText: '••••',
                        filled: true,
                        fillColor: colors.card,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: colors.statusErrorText),
                    ),
                  ],
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _isSubmitting ? null : _unlock,
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.lock_open_rounded),
                    label: Text(_isSubmitting ? 'Checking…' : 'Unlock'),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: widget.onForgotPin,
                    child: const Text('Forgot your PIN?'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
