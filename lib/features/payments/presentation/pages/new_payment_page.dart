/// Defines new payment page in the payments feature's presentation layer.

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_back_navigation.dart';
import '../../../../core/widgets/app_date_picker_theme.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/info_banner.dart';
import '../../../../core/widgets/paidix_toast.dart';
import '../../../../core/widgets/selectable_tile.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../../core/config/app_config.dart';
import '../../../kyc/data/kyc_image_validation.dart';
import '../../../profile/data/user_profile_repository.dart';
import '../../../profile/domain/user_profile.dart';
import '../../data/payments_repository_impl.dart';
import '../../domain/payment_models.dart';

class NewPaymentPage extends StatefulWidget {
  final PaymentsRepositoryImpl paymentsRepository;

  const NewPaymentPage({super.key, required this.paymentsRepository});

  /// Creates the mutable state object that backs this stateful widget.
  @override
  State<NewPaymentPage> createState() => _NewPaymentPageState();
}

class _NewPaymentPageState extends State<NewPaymentPage> {
  final _formKey = GlobalKey<FormState>();

  final _senderNameController = TextEditingController();
  final _senderCompanyController = TextEditingController();
  final _confirmationCodeController = TextEditingController();
  final _amountController = TextEditingController();
  final _dateController = TextEditingController();

  final _picker = ImagePicker();
  DateTime? _selectedDate;
  String? _selectedMethodId;
  String? _selectedFileName;
  String? _selectedFilePath;
  Uint8List? _selectedFileBytes;
  bool _isPickingImage = false;
  bool _isSubmitting = false;
  bool _isDiscardDialogOpen = false;
  bool _isDatePickerOpen = false;
  bool _isCheckingKycStatus = false;
  KycReviewStatus? _serverKycStatus;
  double _feePercentage = 12.0;

  bool _isProfileVerifiedForSession(UserProfile profile) {
    if (profile.kycStatus != KycReviewStatus.verified) return false;
    if (!AppConfig.hasCustomBackend) return true;
    return AuthRepository.instance.isServerKycVerifiedFor(profile.email);
  }

  /// Initializes controllers, listeners, and other state owned by this widget.
  @override
  void initState() {
    super.initState();
    _loadFee();
    _checkLostData();
    final profile = UserProfileRepository.instance.profile;
    final alreadyVerified = _isProfileVerifiedForSession(profile);
    if (alreadyVerified) {
      _serverKycStatus = KycReviewStatus.verified;
      _isCheckingKycStatus = false;
    } else if (AppConfig.hasCustomBackend) {
      _serverKycStatus = AuthRepository.instance.serverConfirmedKycStatusFor(
        profile.email,
      );
      _isCheckingKycStatus = true;
    } else {
      _serverKycStatus = profile.kycStatus;
      _isCheckingKycStatus = false;
    }
    UserProfileRepository.instance.profileNotifier.addListener(
      _handleProfileKycStatusChanged,
    );
    AuthRepository.instance.serverKycStatusNotifier.addListener(
      _handleProfileKycStatusChanged,
    );
    if (AppConfig.hasCustomBackend) {
      _refreshKycStatus(background: alreadyVerified);
    }
  }

  void _handleProfileKycStatusChanged() {
    if (!mounted) return;
    final profile = UserProfileRepository.instance.profile;
    final confirmedServerStatus = AppConfig.hasCustomBackend
        ? AuthRepository.instance.serverConfirmedKycStatusFor(profile.email)
        : profile.kycStatus;
    final nextStatus =
        confirmedServerStatus ??
        (_isProfileVerifiedForSession(profile)
            ? KycReviewStatus.verified
            : null);
    if (nextStatus != null &&
        (nextStatus != _serverKycStatus || _isCheckingKycStatus)) {
      setState(() {
        _serverKycStatus = nextStatus;
        _isCheckingKycStatus = false;
      });
    } else if (_isProfileVerifiedForSession(profile) &&
        (_serverKycStatus != KycReviewStatus.verified ||
            _isCheckingKycStatus)) {
      setState(() {
        _serverKycStatus = KycReviewStatus.verified;
        _isCheckingKycStatus = false;
      });
    } else {
      setState(() {});
    }
  }

  Future<bool> _refreshKycStatus({bool background = false}) async {
    if (!mounted) return false;
    if (!AppConfig.hasCustomBackend) {
      final profile = UserProfileRepository.instance.profile;
      setState(() {
        _serverKycStatus = profile.kycStatus;
        _isCheckingKycStatus = false;
      });
      return true;
    }
    if (!background) {
      setState(() => _isCheckingKycStatus = true);
    }
    try {
      final status = await AuthRepository.instance.refreshKycReviewStatus();
      if (!mounted) return false;
      final profile = UserProfileRepository.instance.profile;
      if (status != null) {
        setState(() {
          _serverKycStatus = status;
          _isCheckingKycStatus = false;
        });
      } else if (_isProfileVerifiedForSession(profile)) {
        setState(() {
          _serverKycStatus = KycReviewStatus.verified;
          _isCheckingKycStatus = false;
        });
      } else if (!background) {
        setState(() => _isCheckingKycStatus = false);
      }
      return true;
    } catch (_) {
      if (!mounted) return false;
      final profile = UserProfileRepository.instance.profile;
      if (_isProfileVerifiedForSession(profile)) {
        if (_serverKycStatus != KycReviewStatus.verified ||
            _isCheckingKycStatus) {
          setState(() {
            _serverKycStatus = KycReviewStatus.verified;
            _isCheckingKycStatus = false;
          });
        }
      } else if (!background) {
        setState(() => _isCheckingKycStatus = false);
      }
      return false;
    }
  }

  Future<void> _refreshKycForPull() async {
    final refreshed = await _refreshKycStatus(background: true);
    if (!refreshed && mounted) {
      PaidiXToast.showError(
        context,
        'Could not confirm your KYC status. Please try again.',
      );
    }
  }

  /// Restores image if the Android OS destroyed MainActivity while in external gallery
  Future<void> _checkLostData() async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      final response = await _picker.retrieveLostData();
      if (response.isEmpty) return;
      final file = response.file;
      if (file != null) {
        final pickedFile = file;
        final bytes = await pickedFile.readAsBytes();
        _validatePaymentScreenshot(bytes);
        if (mounted) {
          setState(() {
            _selectedFileName = pickedFile.name.isNotEmpty
                ? pickedFile.name
                : 'payment_proof_${DateTime.now().millisecondsSinceEpoch}.jpg';
            _selectedFilePath = pickedFile.path;
            _selectedFileBytes = bytes;
          });
        }
      }
    } on FormatException catch (e) {
      if (mounted) {
        PaidiXToast.showError(context, e.message);
      }
    } catch (e) {
      debugPrint('NewPaymentPage retrieveLostData error: $e');
    }
  }

  /// Loads the configured fee percentage for the payment form.
  Future<void> _loadFee() async {
    if (AppConfig.hasCustomBackend) return;
    final fee = await widget.paymentsRepository.getFeePercentage();
    if (mounted) {
      setState(() => _feePercentage = fee);
    }
  }

  void _validatePaymentScreenshot(Uint8List bytes) {
    final extension = KycImageValidation.validateForUpload(
      bytes,
      documentLabel: 'Transaction screenshot',
    );
    if (extension == 'webp') {
      throw const FormatException('Choose a JPEG or PNG screenshot.');
    }
  }

  /// Releases resources owned by this object before it is removed.
  @override
  void dispose() {
    UserProfileRepository.instance.profileNotifier.removeListener(
      _handleProfileKycStatusChanged,
    );
    AuthRepository.instance.serverKycStatusNotifier.removeListener(
      _handleProfileKycStatusChanged,
    );
    _senderNameController.dispose();
    _senderCompanyController.dispose();
    _confirmationCodeController.dispose();
    _amountController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  /// Opens a date picker and stores its selected date.
  Future<void> _pickDate() async {
    final now = DateTime.now();
    _isDatePickerOpen = true;
    DateTime? picked;
    try {
      picked = await showDatePicker(
        context: context,
        initialDate: _selectedDate ?? now,
        firstDate: DateTime(2020),
        lastDate: now,
        builder: (context, child) => buildAppDatePickerTheme(context, child!),
      );
    } finally {
      _isDatePickerOpen = false;
    }

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _dateController.text = AppFormatters.formatDateInput(picked);
      });
    }
  }

  /// Gallery picker with Android/Huawei activity reclamation protection
  Future<void> _pickImage() async {
    HapticFeedback.lightImpact();

    // Fast-path in widget test harness where native camera/gallery channels are unavailable
    if (!kIsWeb && Platform.environment.containsKey('FLUTTER_TEST')) {
      _simulateFilePick();
      return;
    }

    setState(() => _isPickingImage = true);

    try {
      XFile? file = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 2400,
        maxHeight: 2400,
        imageQuality: 88,
      );

      // Aggressive Android lifecycle recovery (e.g. Huawei, low memory)
      if (file == null &&
          !kIsWeb &&
          defaultTargetPlatform == TargetPlatform.android) {
        try {
          final lost = await _picker.retrieveLostData();
          if (!lost.isEmpty && lost.file != null) {
            file = lost.file;
          }
        } catch (_) {}
      }

      if (file != null) {
        final pickedFile = file;
        final bytes = await pickedFile.readAsBytes();
        _validatePaymentScreenshot(bytes);
        if (mounted) {
          setState(() {
            _selectedFileName = pickedFile.name.isNotEmpty
                ? pickedFile.name
                : 'payment_proof_${DateTime.now().millisecondsSinceEpoch}.jpg';
            _selectedFilePath = pickedFile.path;
            _selectedFileBytes = bytes;
          });
        }
      }
    } on FormatException catch (e) {
      if (mounted) {
        PaidiXToast.showError(context, e.message);
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
      if (mounted) {
        PaidiXToast.showError(
          context,
          'Could not open the photo gallery. You can try again or submit without a screenshot.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isPickingImage = false);
      }
    }
  }

  /// Supplies a fallback receipt name when the platform file picker is unavailable.
  void _simulateFilePick() {
    // Allows selecting a proof file for verification workflow
    setState(() {
      _selectedFileName =
          'payment_receipt_${DateTime.now().millisecondsSinceEpoch % 10000}.png';
      _selectedFilePath = null;
      _selectedFileBytes = null;
    });
  }

  /// Removes the attached receipt from the form state.
  void _clearFile() {
    HapticFeedback.lightImpact();
    setState(() {
      _selectedFileName = null;
      _selectedFilePath = null;
      _selectedFileBytes = null;
    });
  }

  /// Validates this payment form, submits one payment, and returns to the list.
  Future<void> _handleSubmit() async {
    if (AppConfig.hasCustomBackend) {
      KycReviewStatus? serverStatus;
      try {
        serverStatus = await AuthRepository.instance.refreshKycReviewStatus();
      } catch (_) {
        if (!mounted) return;
        PaidiXToast.showWarning(
          context,
          'Could not confirm KYC approval. Please try again when connected.',
        );
        return;
      }
      if (!mounted) return;
      if (serverStatus != null) {
        _serverKycStatus = serverStatus;
      }
      final currentProfile = UserProfileRepository.instance.profile;
      final effectiveStatus =
          serverStatus ??
          AuthRepository.instance.serverConfirmedKycStatusFor(
            currentProfile.email,
          );
      if (effectiveStatus != KycReviewStatus.verified ||
          currentProfile.kycStatus != KycReviewStatus.verified) {
        setState(() => _isCheckingKycStatus = false);
        PaidiXToast.showWarning(
          context,
          'New payments are available after your KYC is approved.',
        );
        return;
      }
    } else if (UserProfileRepository.instance.profile.kycStatus !=
        KycReviewStatus.verified) {
      setState(() => _isCheckingKycStatus = false);
      PaidiXToast.showWarning(
        context,
        'New payments are available after your KYC is approved.',
      );
      return;
    }

    // Validate method
    if (_selectedMethodId == null) {
      PaidiXToast.showWarning(context, 'Please select a payment method.');
      return;
    }

    if (!(_formKey.currentState?.validate() ?? false)) {
      PaidiXToast.showWarning(context, 'Please verify all payment details.');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final cleanAmount = _amountController.text
          .replaceAll('\$', '')
          .replaceAll(',', '')
          .trim();
      final parsedAmount = double.parse(cleanAmount);

      final submission = PaymentSubmission(
        methodId: _selectedMethodId!,
        senderName: _senderNameController.text.trim(),
        senderCompany: _senderCompanyController.text.trim(),
        confirmationCode: _confirmationCodeController.text.trim(),
        amount: parsedAmount,
        transactionDate: _selectedDate,
        proofFileName: _selectedFileName,
        proofFilePath: _selectedFilePath,
        proofBytes: _selectedFileBytes,
      );

      final created = await widget.paymentsRepository.submitPayment(submission);

      // Trigger local push notification for transaction confirmation
      try {
        await NotificationService.instance.showNotification(
          id: 17,
          title: 'Payment Submitted',
          body:
              'Payment ${created.reference} for ${AppFormatters.formatUsd(created.amount)} has been submitted.',
        );
      } catch (_) {}

      if (!mounted) return;
      setState(() => _isSubmitting = false);

      PaidiXToast.showSuccess(
        context,
        'Payment ${created.reference} submitted successfully!',
      );

      context.go('/app/payments');
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      final failureMessage = e is ApiException ? e.message : '$e';
      PaidiXToast.showServerError(
        context,
        message: 'Payment submission failed: $failureMessage',
      );
    }
  }

  /// Determines whether form dirty.
  bool _isFormDirty() {
    return _senderNameController.text.isNotEmpty ||
        _senderCompanyController.text.isNotEmpty ||
        _confirmationCodeController.text.isNotEmpty ||
        _amountController.text.isNotEmpty ||
        _selectedDate != null ||
        _selectedMethodId != null ||
        _selectedFileName != null ||
        _selectedFileBytes != null;
  }

  /// Returns to the payments list, asking before discarding unsaved form data.
  void _handleCancel() {
    if (_isSubmitting || _isDiscardDialogOpen) return;
    final colors = AppColors.of(context);
    if (_isFormDirty()) {
      _isDiscardDialogOpen = true;
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: colors.card,
          title: Text(
            'Discard Changes?',
            style: TextStyle(color: colors.textPrimary),
          ),
          content: Text(
            'You have unsaved form entries. Are you sure you want to cancel?',
            style: TextStyle(color: colors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(
                'Keep Editing',
                style: TextStyle(color: colors.aquaLight),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                context.pop();
              },
              child: Text(
                'Discard',
                style: TextStyle(color: colors.borderError),
              ),
            ),
          ],
        ),
      ).whenComplete(() => _isDiscardDialogOpen = false);
    } else {
      context.pop();
    }
  }

  Future<bool> _handleAndroidBack() async {
    if (!mounted) return true;
    if (_isDiscardDialogOpen || _isDatePickerOpen) return false;
    if (_isSubmitting) return true;
    _handleCancel();
    return true;
  }

  /// Builds the widget subtree from its current properties and inherited context.
  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return AppBackButtonHandler(
      onBack: (_) => _handleAndroidBack(),
      child: ValueListenableBuilder<UserProfile>(
        valueListenable: UserProfileRepository.instance.profileNotifier,
        builder: (context, profile, _) {
          final effectiveServerStatus =
              _serverKycStatus ??
              (AppConfig.hasCustomBackend
                  ? AuthRepository.instance.serverConfirmedKycStatusFor(
                      profile.email,
                    )
                  : profile.kycStatus);
          final isUnlocked =
              profile.kycStatus == KycReviewStatus.verified &&
              effectiveServerStatus == KycReviewStatus.verified &&
              !_isCheckingKycStatus;

          if (!isUnlocked) {
            return Scaffold(
              backgroundColor: colors.background,
              body: SafeArea(
                child: RefreshIndicator(
                  color: colors.aqua,
                  backgroundColor: colors.card,
                  onRefresh: _refreshKycForPull,
                  child: _buildKycLockedContent(context, profile),
                ),
              ),
            );
          }

          return Scaffold(
            backgroundColor: colors.background,
            body: SafeArea(
              child: RefreshIndicator(
                color: colors.aqua,
                backgroundColor: colors.card,
                onRefresh: _refreshKycForPull,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 24,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 820),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Fee info banner (Screen 1)
                          InfoBanner(
                            title: AppConfig.hasCustomBackend
                                ? 'Your processing fee is calculated by the server.'
                                : 'Your processing fee is ${_feePercentage.toStringAsFixed(2)}% of the received amount.',
                            subtitle: AppConfig.hasCustomBackend
                                ? 'The confirmed fee and PKR amount appear after submission.'
                                : 'Applied at verification before PKR is transferred.',
                          ),
                          const SizedBox(height: 24),

                          // Main Form Container
                          Container(
                            padding: EdgeInsets.all(
                              MediaQuery.of(context).size.width < 400 ? 16 : 24,
                            ),
                            decoration: BoxDecoration(
                              color: colors.card,
                              borderRadius: AppSpacing.radiusXl,
                              border: Border.all(
                                color: colors.border,
                                width: 1.2,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Payment Method Section
                                Row(
                                  children: [
                                    Text(
                                      'PAYMENT METHOD',
                                      style: AppTypography.label.copyWith(
                                        color: colors.textLabel,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '*',
                                      style: TextStyle(
                                        color: colors.borderError,
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'How did the sender pay you?',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: colors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 14),

                                // Method Tiles (Responsive)
                                _buildPaymentMethodTiles(),
                                const SizedBox(height: 24),

                                // Sender Name & Company (2 columns on wide, stacked on narrow)
                                _buildSenderFields(),
                                const SizedBox(height: 20),

                                // Confirmation Code
                                AppTextField(
                                  label: 'CONFIRMATION CODE (OPTIONAL)',
                                  placeholder: '',
                                  subtext: "Optional reference from the sender's bank or payment app. Must be unique if provided.",
                                  controller: _confirmationCodeController,
                                ),
                                const SizedBox(height: 20),

                                // Amount Received & Transaction Date
                                _buildAmountAndDateFields(),
                                const SizedBox(height: 24),

                                // Transaction Screenshot Upload Box
                                _buildUploadArea(),
                                const SizedBox(height: 32),

                                // Bottom Actions: Cancel & Submit Payment
                                _buildFormActions(),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildKycLockedContent(BuildContext context, UserProfile profile) {
    final colors = AppColors.of(context);
    final status = _serverKycStatus ?? profile.kycStatus;
    final isAwaitingCustomer = status == KycReviewStatus.awaitingCustomer;
    final isActionRequired = status.requiresCustomerAction;
    final statusMessage = _isCheckingKycStatus
        ? 'Checking your KYC verification status...'
        : _serverKycStatus == null &&
              profile.kycStatus == KycReviewStatus.verified
        ? 'We could not confirm your KYC approval with the server.'
        : switch (status) {
            KycReviewStatus.rejected => 'Your KYC submission was rejected.',
            KycReviewStatus.awaitingCustomer =>
              'The reviewer requested updates to your KYC.',
            KycReviewStatus.pendingReview =>
              'Your KYC submission is pending review.',
            KycReviewStatus.inProgress || KycReviewStatus.notStarted =>
              'Complete your KYC verification to unlock payments.',
            KycReviewStatus.verified => 'Your KYC is approved.',
          };
    const description =
        'Once your profile is approved, you’ll be able to submit incoming payments.';

    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight - 64),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: colors.gold.withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.lock_outline_rounded,
                      color: colors.gold,
                      size: 24,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'New payments are locked.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    statusMessage,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    description,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: 14,
                      height: 1.45,
                    ),
                  ),
                  if (isActionRequired &&
                      profile.effectiveKycReason != null) ...[
                    const SizedBox(height: 10),
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: isAwaitingCustomer
                                ? 'Requested updates: '
                                : 'Reason: ',
                            style: TextStyle(
                              color: colors.textPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          TextSpan(text: profile.effectiveKycReason!),
                        ],
                      ),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ],
                  const SizedBox(height: 22),
                  LayoutBuilder(
                    builder: (context, buttonConstraints) {
                      final buttons = [
                        AppButton(
                          text: 'Go to profile',
                          icon: const Icon(
                            Icons.person_outline_rounded,
                            size: 18,
                          ),
                          onPressed: () => context.go('/app/onboarding'),
                          variant: AppButtonVariant.primary,
                        ),
                        AppButton(
                          text: 'Bank accounts',
                          icon: const Icon(
                            Icons.account_balance_outlined,
                            size: 18,
                          ),
                          onPressed: () =>
                              context.go('/app/settings?section=bank-accounts'),
                          variant: AppButtonVariant.outline,
                        ),
                      ];
                      if (buttonConstraints.maxWidth < 460) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            buttons[0],
                            const SizedBox(height: 10),
                            buttons[1],
                          ],
                        );
                      }
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          buttons[0],
                          const SizedBox(width: 10),
                          buttons[1],
                        ],
                      );
                    },
                  ),
                  if (_serverKycStatus == null && !_isCheckingKycStatus) ...[
                    const SizedBox(height: 14),
                    TextButton.icon(
                      onPressed: _refreshKycStatus,
                      icon: const Icon(Icons.refresh_rounded, size: 17),
                      label: const Text('Check again'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Builds the payment method tiles section of this interface.
  Widget _buildPaymentMethodTiles() {
    final tile1 = SelectableTile(
      title: 'Freight Flow Cashapp',
      isSelected: _selectedMethodId == 'cashapp_1',
      icon: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: const Color(0xFF00D632),
          borderRadius: AppSpacing.radiusSm,
        ),
        alignment: Alignment.center,
        child: Text(
          '\$',
          style: TextStyle(
            fontFamily: AppTheme.activeFontFamily,
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
      ),
      onTap: () => setState(() => _selectedMethodId = 'cashapp_1'),
    );

    final tile2 = SelectableTile(
      title: 'UB Zelle',
      isSelected: _selectedMethodId == 'zelle_1',
      icon: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: const Color(0xFF7414CA),
          borderRadius: AppSpacing.radiusSm,
        ),
        alignment: Alignment.center,
        child: Text(
          'Z',
          style: TextStyle(
            fontFamily: AppTheme.activeFontFamily,
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
      ),
      onTap: () => setState(() => _selectedMethodId = 'zelle_1'),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 540) {
          return Row(
            children: [
              Expanded(child: tile1),
              const SizedBox(width: 14),
              Expanded(child: tile2),
            ],
          );
        }
        return Column(children: [tile1, const SizedBox(height: 10), tile2]);
      },
    );
  }

  /// Builds the sender fields section of this interface.
  Widget _buildSenderFields() {
    final nameField = AppTextField(
      label: 'SENDER NAME (OPTIONAL)',
      placeholder: '',
      controller: _senderNameController,
    );

    final companyField = AppTextField(
      label: 'SENDER COMPANY',
      placeholder: '',
      controller: _senderCompanyController,
      isRequired: true,
      validator: (value) => value == null || value.trim().isEmpty
          ? 'Please enter sender company'
          : null,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 540) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: nameField),
              const SizedBox(width: 16),
              Expanded(child: companyField),
            ],
          );
        }
        return Column(
          children: [nameField, const SizedBox(height: 18), companyField],
        );
      },
    );
  }

  /// Builds the amount and date fields section of this interface.
  Widget _buildAmountAndDateFields() {
    final colors = AppColors.of(context);
    final amountField = AppTextField(
      label: 'AMOUNT RECEIVED (USD)',
      placeholder: '0.00',
      controller: _amountController,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      isRequired: true,
      validator: PaymentValidators.validateAmount,
    );

    final dateField = AppTextField(
      label: 'TRANSACTION DATE (OPTIONAL)',
      placeholder: 'mm / dd / yyyy',
      subtext: 'Leave blank to use today.',
      controller: _dateController,
      readOnly: true,
      onTap: _pickDate,
      suffix: IconButton(
        icon: Icon(
          Icons.calendar_today_outlined,
          color: colors.textSecondary,
          size: 18,
        ),
        onPressed: _pickDate,
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 540) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: amountField),
              const SizedBox(width: 16),
              Expanded(child: dateField),
            ],
          );
        }
        return Column(
          children: [amountField, const SizedBox(height: 18), dateField],
        );
      },
    );
  }

  /// Builds the upload area section of this interface.
  Widget _buildUploadArea() {
    final colors = AppColors.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'TRANSACTION SCREENSHOT (OPTIONAL)',
          style: AppTypography.label.copyWith(color: colors.textLabel),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: _isPickingImage ? null : _pickImage,
          borderRadius: AppSpacing.radiusMd,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: colors.inputFill,
              borderRadius: AppSpacing.radiusMd,
              border: Border.all(
                color: _selectedFileName != null ? colors.aqua : colors.border,
                width: 1.4,
              ),
            ),
            child: Row(
              children: [
                if (_selectedFileBytes != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(5),
                    child: Image.memory(
                      _selectedFileBytes!,
                      width: 24,
                      height: 24,
                      fit: BoxFit.cover,
                    ),
                  )
                else
                  Icon(
                    _selectedFileName != null
                        ? Icons.image_outlined
                        : Icons.cloud_upload_outlined,
                    color: _selectedFileName != null
                        ? colors.aqua
                        : colors.textSecondary,
                    size: 20,
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _selectedFileName ?? 'Choose a file...',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: _selectedFileName != null
                          ? FontWeight.w600
                          : FontWeight.w400,
                      color: _selectedFileName != null
                          ? colors.textPrimary
                          : colors.textPlaceholder,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (_selectedFileName != null) ...[
                  IconButton(
                    icon: Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: colors.textSecondary,
                    ),
                    tooltip: 'Remove file',
                    onPressed: _clearFile,
                  ),
                  const SizedBox(width: 2),
                ],
                AppButton(
                  text: 'BROWSE',
                  variant: AppButtonVariant.secondary,
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  isLoading: _isPickingImage,
                  onPressed: _isPickingImage ? null : _pickImage,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Add a screenshot to help verify the incoming payment.',
          style: TextStyle(fontSize: 12, color: colors.textSecondary),
        ),
      ],
    );
  }

  /// Builds the form actions section of this interface.
  Widget _buildFormActions() {
    final colors = AppColors.of(context);

    return Wrap(
      alignment: WrapAlignment.end,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 16,
      runSpacing: 10,
      children: [
        TextButton(
          onPressed: _isSubmitting ? null : _handleCancel,
          child: Text(
            'Cancel',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: colors.textSecondary,
            ),
          ),
        ),
        AppButton(
          text: 'Submit payment',
          icon: Icon(Icons.check, size: 18, color: colors.primaryButtonText),
          isLoading: _isSubmitting,
          variant: AppButtonVariant.primary,
          onPressed: _handleSubmit,
        ),
      ],
    );
  }
}
