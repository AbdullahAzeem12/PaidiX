import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_date_picker_theme.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/info_banner.dart';
import '../../../../core/widgets/selectable_tile.dart';
import '../../data/payments_repository_impl.dart';
import '../../domain/payment_models.dart';

class NewPaymentPage extends StatefulWidget {
  final PaymentsRepositoryImpl paymentsRepository;

  const NewPaymentPage({super.key, required this.paymentsRepository});

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

  DateTime? _selectedDate;
  String? _selectedMethodId;
  String? _selectedFileName;
  bool _isSubmitting = false;
  double _feePercentage = 12.0;

  @override
  void initState() {
    super.initState();
    _loadFee();
  }

  Future<void> _loadFee() async {
    final fee = await widget.paymentsRepository.getFeePercentage();
    if (mounted) {
      setState(() => _feePercentage = fee);
    }
  }

  @override
  void dispose() {
    _senderNameController.dispose();
    _senderCompanyController.dispose();
    _confirmationCodeController.dispose();
    _amountController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: DateTime(2020),
      lastDate: now,
      builder: (context, child) => buildAppDatePickerTheme(context, child!),
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _dateController.text = AppFormatters.formatDateInput(picked);
      });
    }
  }

  void _simulateFilePick() {
    // Allows selecting a sample proof file for testing workflow
    setState(() {
      _selectedFileName = 'payment_receipt_${DateTime.now().millisecondsSinceEpoch % 10000}.png';
    });
  }

  Future<void> _handleSubmit() async {
    // Validate method
    if (_selectedMethodId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select a payment method.'),
          backgroundColor: AppColors.of(context).borderError,
        ),
      );
      return;
    }

    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select the transaction date.'),
          backgroundColor: AppColors.of(context).borderError,
        ),
      );
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
        transactionDate: _selectedDate!,
        proofFileName: _selectedFileName,
      );

      final created =
          await widget.paymentsRepository.submitPayment(submission);

      if (!mounted) return;
      setState(() => _isSubmitting = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Payment ${created.reference} submitted successfully!'),
          backgroundColor: AppColors.statusCompletedBg,
        ),
      );

      context.go('/app/payments');
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Submission failed: $e'),
          backgroundColor: AppColors.borderError,
        ),
      );
    }
  }

  bool _isFormDirty() {
    return _senderNameController.text.isNotEmpty ||
        _senderCompanyController.text.isNotEmpty ||
        _confirmationCodeController.text.isNotEmpty ||
        _amountController.text.isNotEmpty ||
        _selectedDate != null ||
        _selectedMethodId != null ||
        _selectedFileName != null;
  }

  void _handleCancel() {
    final colors = AppColors.of(context);
    if (_isFormDirty()) {
      showDialog(
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
              child: Text('Keep Editing',
                  style: TextStyle(color: colors.aquaLight)),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                context.pop();
              },
              child: Text('Discard',
                  style: TextStyle(color: colors.borderError)),
            ),
          ],
        ),
      );
    } else {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Fee info banner (Screen 1)
                  InfoBanner(
                    title:
                        'Your processing fee is ${_feePercentage.toStringAsFixed(2)}% of the received amount.',
                    subtitle: 'Applied at verification before PKR is transferred.',
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
                      border: Border.all(color: colors.border, width: 1.2),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Payment Method Section
                        Row(
                          children: [
                            Text(
                              'PAYMENT METHOD',
                              style: AppTypography.label.copyWith(color: colors.textLabel),
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
                          label: 'CONFIRMATION CODE',
                          placeholder: '',
                          subtext:
                              "Reference number from the sender's bank / payment app. Must be unique.",
                          controller: _confirmationCodeController,
                          isRequired: true,
                          validator: PaymentValidators.validateConfirmationCode,
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
    );
  }

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
        child: const Text(
          '\$',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
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
        child: const Text(
          'Z',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
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
        return Column(
          children: [
            tile1,
            const SizedBox(height: 10),
            tile2,
          ],
        );
      },
    );
  }

  Widget _buildSenderFields() {
    final nameField = AppTextField(
      label: 'SENDER NAME',
      placeholder: '',
      controller: _senderNameController,
      isRequired: true,
      validator: PaymentValidators.validateSenderName,
    );

    final companyField = AppTextField(
      label: 'SENDER COMPANY',
      placeholder: '',
      controller: _senderCompanyController,
      isRequired: true,
      validator: PaymentValidators.validateSenderCompany,
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
          children: [
            nameField,
            const SizedBox(height: 18),
            companyField,
          ],
        );
      },
    );
  }

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
      label: 'TRANSACTION DATE',
      placeholder: 'mm / dd / yyyy',
      subtext: 'The date this payment was completed. You must select it.',
      controller: _dateController,
      readOnly: true,
      onTap: _pickDate,
      isRequired: true,
      suffix: IconButton(
        icon: Icon(Icons.calendar_today_outlined,
            color: colors.textSecondary, size: 18),
        onPressed: _pickDate,
      ),
      validator: (_) => PaymentValidators.validateDate(_selectedDate),
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
          children: [
            amountField,
            const SizedBox(height: 18),
            dateField,
          ],
        );
      },
    );
  }

  Widget _buildUploadArea() {
    final colors = AppColors.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'TRANSACTION SCREENSHOT',
          style: AppTypography.label.copyWith(color: colors.textLabel),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: colors.inputFill,
            borderRadius: AppSpacing.radiusMd,
            border: Border.all(
              color: _selectedFileName != null
                  ? colors.aqua
                  : colors.border,
              width: 1.4,
            ),
          ),
          child: Row(
            children: [
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
                    color: _selectedFileName != null
                        ? colors.textPrimary
                        : colors.textPlaceholder,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (_selectedFileName != null)
                IconButton(
                  icon: Icon(Icons.close_rounded,
                      size: 18, color: colors.textSecondary),
                  onPressed: () => setState(() => _selectedFileName = null),
                ),
              const SizedBox(width: 4),
              AppButton(
                text: 'BROWSE',
                variant: AppButtonVariant.secondary,
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                onPressed: _simulateFilePick,
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Required proof of the incoming payment.',
          style: TextStyle(
            fontSize: 12,
            color: colors.textSecondary,
          ),
        ),
      ],
    );
  }

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


