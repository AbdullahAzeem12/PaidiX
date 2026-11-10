/// Defines step4 bank view in the kyc feature's presentation layer.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/utils/bank_account_validator.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/bank_selector_sheet.dart';
import '../../../profile/domain/pakistan_banks.dart';
import '../../domain/kyc_models.dart';

class Step4BankView extends StatefulWidget {
  final BankInfo bankInfo;
  final ValueChanged<BankInfo> onChanged;
  final VoidCallback onSubmit;
  final VoidCallback onBack;
  final bool isSubmitting;
  final double submitProgress;
  final String? submitStatusLabel;

  const Step4BankView({
    super.key,
    required this.bankInfo,
    required this.onChanged,
    required this.onSubmit,
    required this.onBack,
    this.isSubmitting = false,
    this.submitProgress = 0.0,
    this.submitStatusLabel,
  });

  /// Creates the mutable state object that backs this stateful widget.
  @override
  State<Step4BankView> createState() => _Step4BankViewState();
}

class _Step4BankViewState extends State<Step4BankView> {
  late final TextEditingController _titleController;
  late final TextEditingController _accountNumberController;
  late final TextEditingController _ibanController;
  late String _selectedBank;

  /// Initializes controllers, listeners, and other state owned by this widget.
  @override
  void initState() {
    super.initState();
    final initial = widget.bankInfo.bankName.isNotEmpty
        ? widget.bankInfo.bankName
        : 'Meezan Bank Limited';
    _selectedBank = findPakistaniBank(initial).name;
    _titleController =
        TextEditingController(text: widget.bankInfo.beneficiaryTitle);

    // Initial Account Number (extract digits if legacy iban was passed, or use accountNumber)
    final initialAccountNum = widget.bankInfo.accountNumber.isNotEmpty
        ? widget.bankInfo.accountNumber
        : (widget.bankInfo.iban.isNotEmpty &&
                !widget.bankInfo.iban.startsWith('PK00MEZN') &&
                !widget.bankInfo.iban.startsWith('PK36MEZN'))
            ? BankAccountValidator.cleanDigits(widget.bankInfo.iban)
            : '';
    _accountNumberController =
        TextEditingController(text: initialAccountNum);

    final rawIban = widget.bankInfo.iban.trim();
    final initialIban = (rawIban == 'PK00MEZN0000000000000000' ||
            rawIban == 'PK36MEZN0000000000000000')
        ? ''
        : rawIban;
    _ibanController = TextEditingController(text: initialIban);
  }

  /// Releases resources owned by this object before it is removed.
  @override
  void dispose() {
    _titleController.dispose();
    _accountNumberController.dispose();
    _ibanController.dispose();
    super.dispose();
  }

  /// Sends the current form model to the parent KYC page.
  void _notifyChange() {
    widget.onChanged(
      widget.bankInfo.copyWith(
        bankName: _selectedBank,
        beneficiaryTitle: _titleController.text.trim(),
        accountNumber: _accountNumberController.text.trim(),
        iban: _ibanController.text.trim().toUpperCase(),
      ),
    );
  }

  /// Builds the widget subtree from its current properties and inherited context.
  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final rule = BankAccountValidator.getRule(_selectedBank);

    final isTitleValid = _titleController.text.trim().length >= 3;
    final isAccountValid = BankAccountValidator.isAccountNumberValid(
      _selectedBank,
      _accountNumberController.text,
    );
    final rawIban = _ibanController.text.trim();
    final isIbanValid = rawIban.isEmpty ||
        BankAccountValidator.isIbanValid(rawIban);

    final isFormValid = isTitleValid && isAccountValid && isIbanValid;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        Text(
          'STEP 4 OF 4',
          style: TextStyle(
            color: colors.textMuted,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Link your Pakistani Bank Account.',
          style: TextStyle(
            fontFamily: AppTheme.activeFontFamily,
            color: colors.textPrimary,
            fontSize: 26,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Where you want your PKR payouts deposited upon payment verification.',
          style: TextStyle(
            color: colors.textSecondary,
            fontSize: 13.5,
          ),
        ),
        const SizedBox(height: 24),

        // Main Card Container
        Container(
          padding: EdgeInsets.all(
              MediaQuery.of(context).size.width < 400 ? 16 : 24),
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: AppSpacing.radiusXl,
            border: Border.all(color: colors.border, width: 1.2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Bank Name Selector Header with "Browse all 39" action
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(
                        'PAKISTANI BANK',
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '*',
                        style: TextStyle(
                          color: colors.ruby,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  GestureDetector(
                    onTap: () async {
                      HapticFeedback.lightImpact();
                      final picked = await BankSelectorSheet.show(
                        context,
                        selectedBankName: _selectedBank,
                      );
                      if (picked != null && mounted) {
                        setState(() => _selectedBank = picked.name);
                        _notifyChange();
                      }
                    },
                    child: Row(
                      children: [
                        Icon(Icons.search_rounded,
                            size: 13, color: colors.aqua),
                        const SizedBox(width: 4),
                        Text(
                          'Browse all 39',
                          style: TextStyle(
                            color: colors.aqua,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: colors.inputBackground,
                  borderRadius: AppSpacing.radiusMd,
                  border: Border.all(
                    color: colors.border.withValues(alpha: 0.8),
                    width: 1.2,
                  ),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: kAllPakistaniBanks
                            .any((b) => b.name == _selectedBank)
                        ? _selectedBank
                        : kAllPakistaniBanks.first.name,
                    isExpanded: true,
                    dropdownColor: colors.card,
                    icon: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: colors.textSecondary,
                    ),
                    selectedItemBuilder: (ctx) {
                      return kAllPakistaniBanks.map((b) {
                        return Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            b.name,
                            style: TextStyle(
                              color: colors.textPrimary,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList();
                    },
                    items: kAllPakistaniBanks.map((b) {
                      return DropdownMenuItem<String>(
                        value: b.name,
                        child: Text(
                          b.name,
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _selectedBank = val);
                        _notifyChange();
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Beneficiary Account Title
              Row(
                children: [
                  Text(
                    'BENEFICIARY ACCOUNT TITLE',
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '*',
                    style: TextStyle(
                      color: colors.ruby,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Container(
                decoration: BoxDecoration(
                  color: colors.inputBackground,
                  borderRadius: AppSpacing.radiusMd,
                  border: Border.all(
                    color: colors.border.withValues(alpha: 0.8),
                    width: 1.2,
                  ),
                ),
                child: TextField(
                  controller: _titleController,
                  style: TextStyle(color: colors.textPrimary, fontSize: 13.5),
                  decoration: InputDecoration(
                    hintText: 'e.g. As shown on bank statement',
                    hintStyle:
                        TextStyle(color: colors.textMuted, fontSize: 13.5),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                  ),
                  onChanged: (_) {
                    setState(() {});
                    _notifyChange();
                  },
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Must match your CNIC full name exactly for SBP 1-LINK clearance.',
                style: TextStyle(
                  color: colors.textMuted,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 18),

              // ─── ACCOUNT NUMBER * (Required) ───────────────────────────
              Row(
                children: [
                  Text(
                    'ACCOUNT NUMBER',
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '*',
                    style: TextStyle(
                      color: colors.ruby,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Container(
                decoration: BoxDecoration(
                  color: colors.inputBackground,
                  borderRadius: AppSpacing.radiusMd,
                  border: Border.all(
                    color: isAccountValid
                        ? colors.emerald.withValues(alpha: 0.6)
                        : (_accountNumberController.text.isNotEmpty &&
                                !isAccountValid)
                            ? colors.ruby.withValues(alpha: 0.8)
                            : colors.border.withValues(alpha: 0.8),
                    width: 1.2,
                  ),
                ),
                child: TextField(
                  controller: _accountNumberController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(rule.maxDigits),
                  ],
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 14,
                    fontFamily: 'monospace',
                    letterSpacing: 0.8,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    hintText: rule.hintText,
                    hintStyle: TextStyle(
                      color: colors.textMuted.withValues(alpha: 0.5),
                      fontSize: 13.5,
                      fontFamily: 'monospace',
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                  ),
                  onChanged: (_) {
                    setState(() {});
                    _notifyChange();
                  },
                ),
              ),
              const SizedBox(height: 6),
              _buildRealtimeAccountNumberStatus(colors, rule),
              const SizedBox(height: 18),

              // ─── IBAN (OPTIONAL) ─────────────────────────────────────────
              Text(
                'IBAN (OPTIONAL)',
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                decoration: BoxDecoration(
                  color: colors.inputBackground,
                  borderRadius: AppSpacing.radiusMd,
                  border: Border.all(
                    color: (rawIban.isNotEmpty && isIbanValid)
                        ? colors.emerald.withValues(alpha: 0.6)
                        : (rawIban.isNotEmpty && !isIbanValid)
                            ? colors.ruby.withValues(alpha: 0.8)
                            : colors.border.withValues(alpha: 0.8),
                    width: 1.2,
                  ),
                ),
                child: TextField(
                  controller: _ibanController,
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                        RegExp(r'[a-zA-Z0-9\s]')),
                    LengthLimitingTextInputFormatter(29), // 24 chars + 5 spaces
                  ],
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 13.5,
                    fontFamily: 'monospace',
                    letterSpacing: 0.8,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    hintText: 'PK00 ${rule.ibanBankCode} 0000 0000 0000 0000',
                    hintStyle: TextStyle(
                      color: colors.textMuted.withValues(alpha: 0.5),
                      fontSize: 13.5,
                      fontFamily: 'monospace',
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                  ),
                  onChanged: (_) {
                    setState(() {});
                    _notifyChange();
                  },
                ),
              ),
              const SizedBox(height: 6),
              _buildRealtimeIbanStatus(colors, rule),
              const SizedBox(height: 20),

              // 1-LINK / PRISM Verification Notice Card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: colors.emerald.withValues(alpha: 0.08),
                  borderRadius: AppSpacing.radiusMd,
                  border: Border.all(
                    color: colors.emerald.withValues(alpha: 0.35),
                    width: 1,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.verified_user_rounded,
                      size: 20,
                      color: colors.emerald,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '1-LINK & PRISM Real-time Direct Clearing',
                            style: TextStyle(
                              color: colors.emerald,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Your bank account is validated against State Bank of Pakistan 1-LINK directory to ensure swift, zero-failure PKR payouts.',
                            style: TextStyle(
                              color: colors.textSecondary,
                              fontSize: 11,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Complete Setup & Submit Verification Button
              if (widget.isSubmitting)
                _SubmitProgressButton(
                  progress: widget.submitProgress,
                  statusLabel: widget.submitStatusLabel ?? 'Submitting Verification...',
                )
              else
                Align(
                  alignment: Alignment.centerRight,
                  child: AppButton(
                    text: MediaQuery.of(context).size.width < 400
                        ? 'Submit Verification'
                        : 'Complete Setup & Submit Verification',
                    icon: const Icon(Icons.check_circle_rounded, size: 16),
                    variant: AppButtonVariant.primary,
                    onPressed: isFormValid
                        ? () {
                            _notifyChange();
                            widget.onSubmit();
                          }
                        : null,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Under Card: Back Link
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.isSubmitting ? null : widget.onBack,
            borderRadius: AppSpacing.radiusSm,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.arrow_back_rounded,
                    size: 14,
                    color: colors.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Back',
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Real-time status display for the required Account Number field.
  Widget _buildRealtimeAccountNumberStatus(
    PaidiXColorScheme colors,
    BankAccountRule rule,
  ) {
    final raw = _accountNumberController.text.trim();
    final status =
        BankAccountValidator.validateAccountNumber(_selectedBank, raw);
    final digitsCount = BankAccountValidator.cleanDigits(raw).length;

    switch (status) {
      case AccountNumberStatus.empty:
        return Row(
          children: [
            Icon(
              Icons.info_outline_rounded,
              size: 13,
              color: colors.textMuted,
            ),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                '${rule.bankName}: ${rule.helperText}',
                style: TextStyle(
                  color: colors.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        );

      case AccountNumberStatus.incomplete:
        return Row(
          children: [
            Icon(
              Icons.info_outline_rounded,
              size: 13,
              color: colors.textMuted,
            ),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                'Enter complete ${rule.lengthLabel} account number ($digitsCount/${rule.typicalDigits} digits)',
                style: TextStyle(
                  color: colors.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        );

      case AccountNumberStatus.invalidWalletPrefix:
        return Row(
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 13,
              color: colors.ruby,
            ),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                'Mobile wallet account number must start with 03 (e.g. 0300 1234567)',
                style: TextStyle(
                  color: colors.ruby,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );

      case AccountNumberStatus.tooLong:
        return Row(
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 13,
              color: colors.ruby,
            ),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                'Account number exceeds maximum ${rule.maxDigits} digits',
                style: TextStyle(
                  color: colors.ruby,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );

      case AccountNumberStatus.valid:
        return AnimatedOpacity(
          opacity: 1.0,
          duration: const Duration(milliseconds: 250),
          child: Row(
            children: [
              Icon(
                Icons.check_circle_outline_rounded,
                size: 13,
                color: colors.emerald,
              ),
              const SizedBox(width: 5),
              Text(
                'Valid Account Number',
                style: TextStyle(
                  color: colors.emerald,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: colors.emerald.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${rule.bankCode} • $digitsCount Digits',
                  style: TextStyle(
                    color: colors.emerald,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        );
    }
  }

  /// Real-time status display for the optional IBAN field.
  Widget _buildRealtimeIbanStatus(
    PaidiXColorScheme colors,
    BankAccountRule rule,
  ) {
    final raw = _ibanController.text.trim();
    if (raw.isEmpty) {
      return Row(
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 13,
            color: colors.textMuted,
          ),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              'Optional: Enter 24-character Pakistani IBAN, or leave blank',
              style: TextStyle(
                color: colors.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      );
    }

    final clean = BankAccountValidator.cleanIban(raw);
    final status = BankAccountValidator.validateIban(clean);

    switch (status) {
      case IbanStatus.empty:
        return const SizedBox.shrink();

      case IbanStatus.invalidPrefix:
        return Row(
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 13,
              color: colors.ruby,
            ),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                'Pakistani IBAN must begin with country code "PK"',
                style: TextStyle(
                  color: colors.ruby,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );

      case IbanStatus.incomplete:
        return Row(
          children: [
            Icon(
              Icons.info_outline_rounded,
              size: 13,
              color: colors.textMuted,
            ),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                'Incomplete IBAN (${clean.length}/24 characters)',
                style: TextStyle(
                  color: colors.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        );

      case IbanStatus.invalidCharacters:
        return Row(
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 13,
              color: colors.ruby,
            ),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                'IBAN must be exactly 24 alphanumeric characters',
                style: TextStyle(
                  color: colors.ruby,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );

      case IbanStatus.valid:
        return AnimatedOpacity(
          opacity: 1.0,
          duration: const Duration(milliseconds: 250),
          child: Row(
            children: [
              Icon(
                Icons.check_circle_outline_rounded,
                size: 13,
                color: colors.emerald,
              ),
              const SizedBox(width: 5),
              Text(
                'Valid Pakistani IBAN',
                style: TextStyle(
                  color: colors.emerald,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: colors.emerald.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '24 Alphanumeric • Verified',
                  style: TextStyle(
                    color: colors.emerald,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        );
    }
  }
}

/// Renders the Step 4 submit button as a smooth real-time progress bar
/// (`0%` -> `100%`) while regulatory KYC upload and bank linking execute.
class _SubmitProgressButton extends StatelessWidget {
  final double progress;
  final String statusLabel;

  const _SubmitProgressButton({
    required this.progress,
    required this.statusLabel,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final clampedTarget = progress.clamp(0.0, 1.0);

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: clampedTarget),
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      builder: (context, animatedProgress, _) {
        final pct = (animatedProgress * 100).round().clamp(0, 100);
        return Container(
          width: double.infinity,
          height: 46.0,
          decoration: BoxDecoration(
            color: colors.primaryButton,
            borderRadius: AppSpacing.radiusMd,
            border: Border.all(
              color: colors.aqua.withValues(alpha: 0.55),
              width: 1.1,
            ),
          ),
          child: ClipRRect(
            borderRadius: AppSpacing.radiusMd,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Smooth horizontal fill sweep across the button body
                Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: animatedProgress,
                    heightFactor: 1.0,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            colors.aqua.withValues(alpha: 0.28),
                            colors.emerald.withValues(alpha: 0.34),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                // Crisp 3px bottom progress indicator rail
                Align(
                  alignment: Alignment.bottomLeft,
                  child: FractionallySizedBox(
                    widthFactor: animatedProgress,
                    child: Container(
                      height: 3.0,
                      color: colors.aquaLight,
                    ),
                  ),
                ),
                // Centered status indicator + stage label + live percentage
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 15,
                        height: 15,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.0,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            colors.primaryButtonText,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          statusLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.buttonText.copyWith(
                            color: colors.primaryButtonText,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$pct%',
                        style: AppTypography.buttonText.copyWith(
                          color: colors.aquaLight,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
