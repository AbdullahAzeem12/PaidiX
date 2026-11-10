/// Modal dialog for 6-digit email OTP verification with live countdown and auto-paste support.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/widgets/paidix_toast.dart';
import '../../data/auth_repository.dart';
import '../../domain/auth_models.dart';

class EmailOtpDialog extends StatefulWidget {
  final String email;
  final String? password;
  final VoidCallback onVerified;

  const EmailOtpDialog({
    super.key,
    required this.email,
    this.password,
    required this.onVerified,
  });

  /// Opens the OTP verification dialog.
  static Future<void> show(
    BuildContext context, {
    required String email,
    String? password,
    required VoidCallback onVerified,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => EmailOtpDialog(
        email: email,
        password: password,
        onVerified: onVerified,
      ),
    );
  }

  @override
  State<EmailOtpDialog> createState() => _EmailOtpDialogState();
}

class _EmailOtpDialogState extends State<EmailOtpDialog> {
  final TextEditingController _otpController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  Timer? _countdownTimer;
  int _secondsRemaining = 60;
  bool _isVerifying = false;
  bool _isResending = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _otpController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _startTimer() {
    _countdownTimer?.cancel();
    setState(() {
      _secondsRemaining = 60;
      _errorMessage = null;
    });
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        if (mounted) {
          setState(() => _secondsRemaining--);
        }
      } else {
        timer.cancel();
        if (mounted) {
          setState(() {
            _errorMessage =
                'The verification code has expired (codes are valid for 60 seconds). Please tap "Resend Code" to receive a fresh code.';
          });
        }
      }
    });
  }

  /// Sanitizes input, removing any spaces or non-digit characters.
  void _onCodeChanged(String value) {
    final digitsOnly = value.replaceAll(RegExp(r'\D'), '');
    if (digitsOnly != value) {
      _otpController.value = TextEditingValue(
        text: digitsOnly,
        selection: TextSelection.collapsed(offset: digitsOnly.length),
      );
    }
    if (_errorMessage != null) {
      setState(() => _errorMessage = null);
    }
    // Auto-verify as soon as 6 digits are entered
    if (digitsOnly.length == 6 && !_isVerifying) {
      _handleVerify();
    }
  }

  Future<void> _handleVerify() async {
    final code = _otpController.text.replaceAll(RegExp(r'\D'), '');
    if (code.length != 6) {
      setState(() {
        _errorMessage = 'Please enter a valid 6-digit verification code.';
      });
      return;
    }

    if (_secondsRemaining <= 0) {
      setState(() {
        _errorMessage =
            'This code has expired. Please tap "Resend Code" to get a fresh code.';
      });
      return;
    }

    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    try {
      await AuthRepository.instance.verifyEmailOtp(
        email: widget.email,
        code: code,
      );

      if (!mounted) return;
      _countdownTimer?.cancel();
      Navigator.of(context).pop();

      // If password was provided, attempt silent sign-in to populate session tokens
      if (widget.password != null && widget.password!.isNotEmpty) {
        try {
          await AuthRepository.instance.signIn(
            SignInRequest(email: widget.email, password: widget.password!),
          );
        } catch (_) {
          // Silent fallback if credentials need manual entry
        }
      }

      widget.onVerified();
    } on ApiException catch (e) {
      if (!mounted) return;
      final msg = e.message.toLowerCase();
      // "already verified" at this layer means the repository did not catch it —
      // treat it as success and proceed.
      if (msg.contains('already verified') || msg.contains('already_verified')) {
        _countdownTimer?.cancel();
        Navigator.of(context).pop();
        if (widget.password != null && widget.password!.isNotEmpty) {
          try {
            await AuthRepository.instance.signIn(
              SignInRequest(email: widget.email, password: widget.password!),
            );
          } catch (_) {}
        }
        widget.onVerified();
        return;
      }
      setState(() {
        _isVerifying = false;
        if (e.message.toLowerCase().contains('expired')) {
          _errorMessage =
              'This code has expired (codes expire in 60s). Please tap "Resend Code" below.';
        } else if (e.message.toLowerCase().contains('incorrect')) {
          _errorMessage =
              'The code you entered is incorrect. Please check your email and try again.';
        } else {
          _errorMessage = e.message;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isVerifying = false;
        _errorMessage = 'Verification failed: $e';
      });
    }
  }

  Future<void> _handleResend() async {
    setState(() {
      _isResending = true;
      _errorMessage = null;
    });

    try {
      await AuthRepository.instance.resendEmailOtp(
        email: widget.email,
        password: widget.password ?? '',
      );

      if (!mounted) return;
      setState(() {
        _isResending = false;
        _otpController.clear();
      });
      _startTimer();
      _focusNode.requestFocus();
      PaidiXToast.showSuccess(
        context,
        'Fresh 6-digit code sent to ${widget.email}. Valid for 60 seconds.',
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _isResending = false;
        _errorMessage = e.message;
      });
      PaidiXToast.showError(context, e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isResending = false;
        _errorMessage = 'Resend failed: $e';
      });
      PaidiXToast.showError(context, 'Resend failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final timerExpired = _secondsRemaining <= 0;
    final timerExpiringSoon = _secondsRemaining <= 15 && !timerExpired;

    final timerColor = timerExpired
        ? colors.ruby
        : (timerExpiringSoon ? colors.gold : colors.aqua);

    return AlertDialog(
      backgroundColor: colors.card,
      shape: RoundedRectangleBorder(
        borderRadius: AppSpacing.radiusLg,
        side: BorderSide(color: colors.border, width: 1.2),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: colors.aqua.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.mark_email_read_outlined,
              color: colors.aqua,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Verify Your Email',
              style: TextStyle(
                color: colors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 18,
              ),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'A 6-digit verification code was sent to:',
              style: TextStyle(color: colors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 4),
            Text(
              widget.email,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 14),

            // Live Expiration Timer Banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: timerColor.withValues(alpha: 0.1),
                borderRadius: AppSpacing.radiusSm,
                border: Border.all(
                  color: timerColor.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    timerExpired
                        ? Icons.timer_off_outlined
                        : Icons.timer_outlined,
                    size: 16,
                    color: timerColor,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      timerExpired
                          ? 'Code expired (valid for 60s)'
                          : 'Code expires in: 00:${_secondsRemaining.toString().padLeft(2, '0')}',
                      style: TextStyle(
                        color: timerColor,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // OTP Input Field
            TextField(
              controller: _otpController,
              focusNode: _focusNode,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6),
              ],
              autofocus: true,
              onChanged: _onCodeChanged,
              enabled: !_isVerifying,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 22,
                letterSpacing: 8,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                counterText: '',
                hintText: '••••••',
                hintStyle: TextStyle(
                  color: colors.textMuted,
                  letterSpacing: 6,
                ),
                filled: true,
                fillColor: colors.background,
                border: OutlineInputBorder(
                  borderRadius: AppSpacing.radiusMd,
                  borderSide: BorderSide(color: colors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: AppSpacing.radiusMd,
                  borderSide: BorderSide(color: colors.aqua, width: 1.5),
                ),
              ),
            ),

            // Inline Error Banner
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: colors.ruby.withValues(alpha: 0.1),
                  borderRadius: AppSpacing.radiusSm,
                  border: Border.all(
                    color: colors.ruby.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 16,
                      color: colors.ruby,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(
                          color: colors.ruby,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        // Resend Button
        TextButton(
          onPressed: (_isVerifying || _isResending) ? null : _handleResend,
          child: _isResending
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(
                  'Resend Code',
                  style: TextStyle(
                    color: colors.aqua,
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ),

        // Cancel / Verify Later
        TextButton(
          onPressed: _isVerifying
              ? null
              : () {
                  _countdownTimer?.cancel();
                  Navigator.of(context).pop();
                },
          child: Text(
            'Cancel',
            style: TextStyle(color: colors.textSecondary),
          ),
        ),

        // Verify Button
        ElevatedButton(
          onPressed: (_isVerifying || _isResending) ? null : _handleVerify,
          style: ElevatedButton.styleFrom(
            backgroundColor: colors.aqua,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: AppSpacing.radiusMd),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
          child: _isVerifying
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Text(
                  'Verify & Continue',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
        ),
      ],
    );
  }
}
