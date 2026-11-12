/// Modal dialog for 6-digit email OTP verification with live countdown and auto-paste support.

import 'dart:async';
import 'package:material_ui/material_ui.dart';
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
  final bool otpSentInitially;
  final String? initialErrorMessage;
  final bool performSignInOnVerified;

  const EmailOtpDialog({
    super.key,
    required this.email,
    this.password,
    required this.onVerified,
    this.otpSentInitially = true,
    this.initialErrorMessage,
    this.performSignInOnVerified = true,
  });

  /// Opens the OTP verification dialog.
  static Future<void> show(
    BuildContext context, {
    required String email,
    String? password,
    required VoidCallback onVerified,
    bool otpSentInitially = true,
    String? initialErrorMessage,
    bool performSignInOnVerified = true,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => EmailOtpDialog(
        email: email,
        password: password,
        onVerified: onVerified,
        otpSentInitially: otpSentInitially,
        initialErrorMessage: initialErrorMessage,
        performSignInOnVerified: performSignInOnVerified,
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
  late bool _codeWasSent;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _codeWasSent = widget.otpSentInitially;
    _errorMessage = widget.initialErrorMessage;
    _beginCountdown();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _otpController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _beginCountdown() {
    _countdownTimer?.cancel();
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

  void _startTimer({String? initialError}) {
    setState(() {
      _secondsRemaining = 60;
      _errorMessage = initialError;
    });
    _beginCountdown();
  }

  /// Completes optional post-OTP sign-in (e.g. from SignUp) while loading,
  /// closes the dialog, and notifies [widget.onVerified].
  Future<void> _completeVerificationAndSignIn() async {
    if (widget.performSignInOnVerified &&
        widget.password != null &&
        widget.password!.isNotEmpty) {
      await AuthRepository.instance.signIn(
        SignInRequest(email: widget.email, password: widget.password!),
      );
    }

    if (!mounted) return;
    _countdownTimer?.cancel();
    Navigator.of(context).pop();
    widget.onVerified();
  }

  /// Shared recovery when backend reports the email is already verified.
  Future<void> _handleAlreadyVerifiedRecovery() async {
    if (!mounted) return;
    setState(() {
      _isResending = false;
      _isVerifying = true;
      _errorMessage = null;
    });
    try {
      await _completeVerificationAndSignIn();
    } on ApiException catch (signInErr) {
      if (!mounted) return;
      setState(() {
        _isVerifying = false;
        _errorMessage = signInErr.message;
      });
    } catch (signInErr) {
      if (!mounted) return;
      setState(() {
        _isVerifying = false;
        _errorMessage = 'Sign-in failed: $signInErr';
      });
    }
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
      _handleVerify(overrideCode: digitsOnly);
    }
  }

  Future<void> _handleVerify({String? overrideCode}) async {
    final code = (overrideCode ?? _otpController.text).replaceAll(RegExp(r'\D'), '');
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

      await _completeVerificationAndSignIn();
    } on ApiException catch (e) {
      if (!mounted) return;
      if (AuthRepository.isAlreadyVerifiedMessage(e.message)) {
        await _handleAlreadyVerifiedRecovery();
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
    final password = widget.password ?? '';
    if (password.isEmpty) {
      setState(() {
        _errorMessage =
            'Please close this dialog and re-enter your password to resend a verification code.';
      });
      return;
    }

    setState(() {
      _isResending = true;
      _errorMessage = null;
    });

    try {
      await AuthRepository.instance.resendEmailOtp(
        email: widget.email,
        password: password,
      );

      if (!mounted) return;
      setState(() {
        _isResending = false;
        _codeWasSent = true;
        _otpController.clear();
      });
      _startTimer();
      _focusNode.requestFocus();
      PaidiXToast.showSuccess(
        context,
        'Fresh 6-digit code sent to ${widget.email}. Valid for 60 seconds.',
      );
    } on EmailAlreadyVerifiedException {
      await _handleAlreadyVerifiedRecovery();
    } on ApiException catch (e) {
      if (!mounted) return;
      if (AuthRepository.isAlreadyVerifiedMessage(e.message)) {
        await _handleAlreadyVerifiedRecovery();
        return;
      }
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
              _codeWasSent
                  ? 'A 6-digit verification code was sent to:'
                  : 'Enter the 6-digit verification code for:',
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
