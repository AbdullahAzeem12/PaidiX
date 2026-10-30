import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/widgets/app_button.dart';
import '../../domain/kyc_models.dart';

class Step4BankView extends StatefulWidget {
  final BankInfo bankInfo;
  final ValueChanged<BankInfo> onChanged;
  final VoidCallback onSubmit;
  final VoidCallback onBack;

  const Step4BankView({
    super.key,
    required this.bankInfo,
    required this.onChanged,
    required this.onSubmit,
    required this.onBack,
  });

  @override
  State<Step4BankView> createState() => _Step4BankViewState();
}

class _Step4BankViewState extends State<Step4BankView> {
  late final TextEditingController _titleController;
  late final TextEditingController _ibanController;
  late String _selectedBank;

  static const List<String> _pakistaniBanks = [
    'Meezan Bank Limited',
    'Habib Bank Limited (HBL)',
    'Allied Bank Limited (ABL)',
    'MCB Bank Limited',
    'United Bank Limited (UBL)',
    'Bank Alfalah',
    'Standard Chartered Bank Pakistan',
    'Faysal Bank',
    'Askari Bank',
    'Bank of Punjab (BOP)',
    'EasyPaisa (Telenor Bank)',
    'JazzCash (Mobilink Bank)',
    'SadaPay',
    'NayaPay',
  ];

  @override
  void initState() {
    super.initState();
    _selectedBank = widget.bankInfo.bankName.isNotEmpty
        ? widget.bankInfo.bankName
        : _pakistaniBanks.first;
    _titleController =
        TextEditingController(text: widget.bankInfo.beneficiaryTitle);
    final rawIban = widget.bankInfo.iban.trim();
    final initialIban = (rawIban == 'PK00MEZN0000000000000000' ||
            rawIban == 'PK36MEZN0000000000000000')
        ? ''
        : rawIban;
    _ibanController = TextEditingController(text: initialIban);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _ibanController.dispose();
    super.dispose();
  }

  void _notifyChange() {
    widget.onChanged(
      widget.bankInfo.copyWith(
        bankName: _selectedBank,
        beneficiaryTitle: _titleController.text.trim(),
        iban: _ibanController.text.trim().toUpperCase(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    final isFormValid = _titleController.text.trim().length >= 3 &&
        _ibanController.text.trim().length >= 10;

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
            color: colors.textPrimary,
            fontSize: 26,
            fontWeight: FontWeight.w800,
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
          padding: EdgeInsets.all(MediaQuery.of(context).size.width < 400 ? 16 : 24),
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: AppSpacing.radiusXl,
            border: Border.all(color: colors.border, width: 1.2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Bank Name Selector
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
                    value: _pakistaniBanks.contains(_selectedBank)
                        ? _selectedBank
                        : _pakistaniBanks.first,
                    isExpanded: true,
                    dropdownColor: colors.card,
                    icon: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: colors.textSecondary,
                    ),
                    items: _pakistaniBanks.map((b) {
                      return DropdownMenuItem<String>(
                        value: b,
                        child: Text(
                          b,
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w500,
                          ),
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
                    hintText: 'HASSAN AZEEM',
                    hintStyle:
                        TextStyle(color: colors.textMuted, fontSize: 13.5),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                  ),
                  onChanged: (_) => _notifyChange(),
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

              // IBAN / Account Number
              Row(
                children: [
                  Text(
                    'IBAN / ACCOUNT NUMBER',
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
                  controller: _ibanController,
                  textCapitalization: TextCapitalization.characters,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 13.5,
                    fontFamily: 'monospace',
                    letterSpacing: 0.8,
                  ),
                  decoration: InputDecoration(
                    hintText: 'PK00MEZN0000000000000000',
                    hintStyle:
                        TextStyle(color: colors.textMuted, fontSize: 13.5),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                  ),
                  onChanged: (_) => _notifyChange(),
                ),
              ),
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
            onTap: widget.onBack,
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
}
