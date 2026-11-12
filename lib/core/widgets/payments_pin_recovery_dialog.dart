import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../app/theme/app_colors.dart';
import '../network/api_client.dart';

/// Opens the shared, responsive Payments PIN recovery dialog.
Future<void> showPaymentsPinRecoveryDialog({
  required BuildContext context,
  required String email,
  required Future<String> Function(String email) onSend,
  bool validateEmail = true,
  String introText =
      'We will email a temporary 8-digit Payments PIN to your registered email address. This will not change your account password.',
  String instructionText =
      'Enter the temporary PIN on the lock screen to unlock, then change your PIN in Payments settings.',
}) {
  return showDialog<void>(
    context: context,
    useSafeArea: true,
    builder: (_) => _PaymentsPinRecoveryDialog(
      email: email,
      onSend: onSend,
      validateEmail: validateEmail,
      introText: introText,
      instructionText: instructionText,
    ),
  );
}

class _PaymentsPinRecoveryDialog extends StatefulWidget {
  final String email;
  final Future<String> Function(String email) onSend;
  final bool validateEmail;
  final String introText;
  final String instructionText;

  const _PaymentsPinRecoveryDialog({
    required this.email,
    required this.onSend,
    required this.validateEmail,
    required this.introText,
    required this.instructionText,
  });

  @override
  State<_PaymentsPinRecoveryDialog> createState() =>
      _PaymentsPinRecoveryDialogState();
}

class _PaymentsPinRecoveryDialogState
    extends State<_PaymentsPinRecoveryDialog> {
  bool _isSending = false;
  bool _sent = false;
  String? _message;
  String? _error;

  Future<void> _send() async {
    if (widget.validateEmail &&
        (!widget.email.contains('@') || widget.email.trim().isEmpty)) {
      setState(() => _error = 'Your registered email is unavailable.');
      return;
    }
    HapticFeedback.mediumImpact();
    setState(() {
      _isSending = true;
      _error = null;
      _message = null;
    });
    try {
      final detail = await widget.onSend(widget.email);
      if (!mounted) return;
      setState(() {
        _sent = true;
        _message = detail;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error is ApiException
            ? error.message
            : error.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final screen = MediaQuery.sizeOf(context);
    final compact = screen.width < 400;
    final horizontalPadding = compact ? 20.0 : 32.0;
    final verticalInset = screen.height < 480 ? 12.0 : 24.0;
    final maxHeight =
        (screen.height - verticalInset * 2).clamp(160.0, 820.0).toDouble();

    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: compact ? 16 : 28,
        vertical: verticalInset,
      ),
      backgroundColor: colors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(compact ? 24 : 28),
        side: BorderSide(color: colors.border, width: 1),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 560, maxHeight: maxHeight),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            compact ? 24 : 30,
            horizontalPadding,
            compact ? 20 : 26,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (compact)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _buildMailIcon(colors, compact: true),
                        const Spacer(),
                        IconButton(
                          tooltip: 'Close',
                          onPressed: _isSending
                              ? null
                              : () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close_rounded),
                          color: colors.textSecondary,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Forgot Payments PIN?',
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 21,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -.35,
                      ),
                    ),
                  ],
                )
              else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _buildMailIcon(colors),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        'Forgot Payments PIN?',
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -.35,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed:
                          _isSending ? null : () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                      color: colors.textSecondary,
                    ),
                  ],
                ),
              SizedBox(height: compact ? 20 : 26),
              Text(
                widget.introText,
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: compact ? 15 : 17,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: colors.inputFill,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: colors.border),
                ),
                child: SelectableText(
                  widget.email,
                  style: TextStyle(
                    color: colors.aqua,
                    fontSize: compact ? 15 : 17,
                    fontWeight: FontWeight.w700,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                widget.instructionText,
                style: TextStyle(
                  color: colors.textMuted,
                  fontSize: compact ? 13 : 14,
                  height: 1.5,
                ),
              ),
              if (_message != null) ...[
                const SizedBox(height: 16),
                _statusMessage(
                  context,
                  color: colors.statusCompletedText,
                  icon: Icons.check_circle_outline_rounded,
                  message: _message!,
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 16),
                _statusMessage(
                  context,
                  color: colors.statusErrorText,
                  icon: Icons.error_outline_rounded,
                  message: _error!,
                ),
              ],
              const SizedBox(height: 24),
              Align(
                alignment: Alignment.centerRight,
                child: Wrap(
                  alignment: WrapAlignment.end,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 10,
                  children: [
                    TextButton(
                      onPressed:
                          _isSending ? null : () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    FilledButton.icon(
                      onPressed: _isSending
                          ? null
                          : _sent
                              ? () => Navigator.of(context).pop()
                              : _send,
                      icon: _isSending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(_sent
                              ? Icons.check_rounded
                              : Icons.mark_email_read_outlined),
                      label: Text(
                        _isSending
                            ? 'Sending…'
                            : _sent
                                ? 'Done'
                                : 'Send Reset Email',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusMessage(
    BuildContext context, {
    required Color color,
    required IconData icon,
    required String message,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: .25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: color, height: 1.4, fontSize: 13.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMailIcon(PaidiXColorScheme colors, {bool compact = false}) {
    final size = compact ? 54.0 : 64.0;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: colors.aqua.withValues(alpha: .13),
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.mark_email_read_outlined,
        color: colors.aqua,
        size: compact ? 27 : 32,
      ),
    );
  }
}
