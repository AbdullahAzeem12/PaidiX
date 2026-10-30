import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/utils/phone_formatter.dart';
import '../../../../core/widgets/app_button.dart';
import '../../domain/kyc_models.dart';

class Step1PersonalView extends StatefulWidget {
  final PersonalInfo personalInfo;
  final ValueChanged<PersonalInfo> onChanged;
  final VoidCallback onContinue;

  const Step1PersonalView({
    super.key,
    required this.personalInfo,
    required this.onChanged,
    required this.onContinue,
  });

  @override
  State<Step1PersonalView> createState() => _Step1PersonalViewState();
}

class _Step1PersonalViewState extends State<Step1PersonalView> {
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _addressController;
  late final TextEditingController _cityController;
  late bool _smsConsent;
  late CountryCodeOption _selectedCountry;

  @override
  void initState() {
    super.initState();
    _selectedCountry =
        CountryCodeOption.fromCodeOrDisplay(widget.personalInfo.countryCode);

    final initialName = (widget.personalInfo.fullName == 'Abdullah Azeem')
        ? ''
        : widget.personalInfo.fullName;
    _nameController = TextEditingController(text: initialName);

    final rawPhone = (widget.personalInfo.phoneNumber == '+923217649976' ||
            widget.personalInfo.phoneNumber == '923217649976' ||
            widget.personalInfo.phoneNumber == '923 2176499')
        ? ''
        : widget.personalInfo.phoneNumber;
    final formattedPhone = rawPhone.isNotEmpty
        ? PhoneFormatter.format(rawPhone, isUs: _selectedCountry.isUs)
        : '';
    _phoneController = TextEditingController(text: formattedPhone);

    final initialAddress =
        (widget.personalInfo.address == 'Canalberg Housing Society')
            ? ''
            : (widget.personalInfo.address ?? '');
    _addressController = TextEditingController(text: initialAddress);

    final initialCity = (widget.personalInfo.city == 'لاہور')
        ? ''
        : (widget.personalInfo.city ?? '');
    _cityController = TextEditingController(text: initialCity);

    _smsConsent = (widget.personalInfo.fullName == 'Abdullah Azeem')
        ? false
        : widget.personalInfo.smsConsent;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  void _notifyChange() {
    widget.onChanged(
      widget.personalInfo.copyWith(
        fullName: _nameController.text.trim(),
        countryCode: _selectedCountry.display,
        phoneNumber: _phoneController.text.trim(),
        smsConsent: _smsConsent,
        address: _addressController.text.trim(),
        city: _cityController.text.trim(),
      ),
    );
  }

  void _onCountryChanged(CountryCodeOption newCountry) {
    if (newCountry == _selectedCountry) return;
    HapticFeedback.selectionClick();

    final digits = PhoneFormatter.clean(_phoneController.text);
    final reformatted = digits.isNotEmpty
        ? PhoneFormatter.format(digits, isUs: newCountry.isUs)
        : '';

    setState(() {
      _selectedCountry = newCountry;
      _phoneController.value = TextEditingValue(
        text: reformatted,
        selection: TextSelection.collapsed(offset: reformatted.length),
      );
    });

    _notifyChange();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth > 640;

    final cleanPhone = PhoneFormatter.clean(_phoneController.text);
    final isPhoneValid = PhoneValidator.isValid(
      cleanPhone,
      isUs: _selectedCountry.isUs,
    );

    final isFormValid = _nameController.text.trim().length >= 3 &&
        isPhoneValid &&
        _smsConsent;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        Text(
          'STEP 1 OF 4',
          style: TextStyle(
            color: colors.textMuted,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Tell us about you.',
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: 26,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Basic details we\'ll use on your profile.',
          style: TextStyle(
            color: colors.textSecondary,
            fontSize: 13.5,
          ),
        ),
        const SizedBox(height: 24),

        // Main Card Container
        Container(
          padding: EdgeInsets.all(screenWidth < 400 ? 16 : 24),
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: AppSpacing.radiusXl,
            border: Border.all(color: colors.border, width: 1.2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Row 1: Full Name and Phone
              if (isWide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _buildFullNameField(colors)),
                    const SizedBox(width: 16),
                    Expanded(child: _buildPhoneField(colors)),
                  ],
                )
              else ...[
                _buildFullNameField(colors),
                const SizedBox(height: 16),
                _buildPhoneField(colors),
              ],
              const SizedBox(height: 18),

              // SMS Consent Checkbox
              InkWell(
                onTap: () {
                  setState(() {
                    _smsConsent = !_smsConsent;
                  });
                  _notifyChange();
                },
                borderRadius: AppSpacing.radiusSm,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 18,
                        height: 18,
                        margin: const EdgeInsets.only(top: 2),
                        decoration: BoxDecoration(
                          color: _smsConsent
                              ? colors.emerald
                              : colors.inputBackground,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: _smsConsent
                                ? colors.emerald
                                : colors.border.withValues(alpha: 0.8),
                            width: 1.2,
                          ),
                        ),
                        child: _smsConsent
                            ? const Icon(
                                Icons.check_rounded,
                                size: 14,
                                color: Colors.white,
                              )
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final screenWidth = MediaQuery.of(context).size.width;
                            final isVeryNarrow = screenWidth < 360 || constraints.maxWidth < 280;
                            final fontSize = isVeryNarrow ? 10.0 : (screenWidth < 600 ? 11.0 : 11.5);
                            final lineHeight = isVeryNarrow ? 1.40 : 1.48;

                            return Text(
                              'By checking this box, I agree to receive SMS text messages from Paidix Global at the phone number provided, including account and payment notifications, customer care, and marketing messages. Message frequency may vary. Msg & data rates may apply. Reply HELP for help or text HELP to +1 (336) 306-0546. Reply STOP to opt out at any time. Consent is not a condition of purchase. Your phone number will not be shared with third parties for marketing purposes. See our Privacy Policy and Terms of Service.',
                              textAlign: TextAlign.justify,
                              softWrap: true,
                              style: TextStyle(
                                color: colors.textSecondary.withValues(alpha: 0.85),
                                fontSize: fontSize,
                                height: lineHeight,
                                letterSpacing: 0.1,
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Optional Address Field
              _buildAddressField(colors),
              const SizedBox(height: 16),

              // Optional City Field
              _buildCityField(colors),
              const SizedBox(height: 24),

              // Continue Button
              Align(
                alignment: Alignment.centerRight,
                child: AppButton(
                  text: 'Continue',
                  icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                  variant: AppButtonVariant.primary,
                  onPressed: isFormValid
                      ? () {
                          _notifyChange();
                          widget.onContinue();
                        }
                      : null,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFullNameField(PaidiXColorScheme colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'FULL NAME',
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
                color: colors.border.withValues(alpha: 0.8), width: 1.2),
          ),
          child: TextField(
            controller: _nameController,
            style: TextStyle(color: colors.textPrimary, fontSize: 13.5),
            decoration: InputDecoration(
              hintText: 'e.g. John Doe',
              hintStyle: TextStyle(color: colors.textMuted, fontSize: 13.5),
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
            onChanged: (_) => _notifyChange(),
          ),
        ),
      ],
    );
  }

  Widget _buildPhoneField(PaidiXColorScheme colors) {
    final status = PhoneValidator.getStatus(
      _phoneController.text,
      isUs: _selectedCountry.isUs,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'PHONE',
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
        Row(
          children: [
            // Country Code Dropdown (Pakistan & United States)
            Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: colors.inputBackground,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(8),
                  bottomLeft: Radius.circular(8),
                ),
                border: Border.all(
                  color: colors.border.withValues(alpha: 0.8),
                  width: 1.2,
                ),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<CountryCodeOption>(
                  value: _selectedCountry,
                  dropdownColor: colors.cardDark,
                  borderRadius: AppSpacing.radiusMd,
                  elevation: 8,
                  menuWidth: 210,
                  icon: Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 16,
                      color: colors.textSecondary,
                    ),
                  ),
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                  onChanged: (newCountry) {
                    if (newCountry != null) {
                      _onCountryChanged(newCountry);
                    }
                  },
                  selectedItemBuilder: (context) {
                    return CountryCodeOption.values.map((country) {
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            country.flag,
                            style: const TextStyle(fontSize: 14),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            country.display,
                            style: TextStyle(
                              color: colors.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      );
                    }).toList();
                  },
                  items: CountryCodeOption.values.map((country) {
                    final isSelected = country == _selectedCountry;
                    return DropdownMenuItem<CountryCodeOption>(
                      value: country,
                      child: Row(
                        children: [
                          Text(
                            country.flag,
                            style: const TextStyle(fontSize: 15),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              country.name,
                              style: TextStyle(
                                color: isSelected
                                    ? colors.aqua
                                    : colors.textPrimary,
                                fontSize: 13,
                                fontWeight: isSelected
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            country.display,
                            style: TextStyle(
                              color: isSelected
                                  ? colors.aqua
                                  : colors.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (isSelected) ...[
                            const SizedBox(width: 6),
                            Icon(
                              Icons.check_rounded,
                              size: 15,
                              color: colors.aqua,
                            ),
                          ],
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),

            // Real-Time Spaced Phone Input
            Expanded(
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: colors.inputBackground,
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(8),
                    bottomRight: Radius.circular(8),
                  ),
                  border: Border(
                    top: BorderSide(
                        color: colors.border.withValues(alpha: 0.8),
                        width: 1.2),
                    right: BorderSide(
                        color: colors.border.withValues(alpha: 0.8),
                        width: 1.2),
                    bottom: BorderSide(
                        color: colors.border.withValues(alpha: 0.8),
                        width: 1.2),
                  ),
                ),
                child: TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    PhoneInputFormatter(isUs: _selectedCountry.isUs),
                  ],
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 13.5,
                    fontFamily: 'monospace',
                    letterSpacing: 0.6,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    hintText: _selectedCountry.hintText,
                    hintStyle: TextStyle(
                      color: colors.textMuted,
                      fontSize: 13.5,
                      fontFamily: 'monospace',
                      letterSpacing: 0.6,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                  ),
                  onChanged: (_) {
                    setState(() {});
                    _notifyChange();
                  },
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),

        // Real-Time Smart Phone Status Indicator
        _buildPhoneStatusIndicator(status, colors),
      ],
    );
  }

  Widget _buildPhoneStatusIndicator(
      PhoneValidationStatus status, PaidiXColorScheme colors) {
    switch (status) {
      case PhoneValidationStatus.empty:
        return Text(
          _selectedCountry.isUs
              ? 'Enter 10-digit US number (e.g. (555) 012-3456)'
              : 'Enter 10-digit mobile number (e.g. 300 1234567)',
          style: TextStyle(
            color: colors.textMuted,
            fontSize: 10.5,
            fontWeight: FontWeight.w500,
          ),
        );

      case PhoneValidationStatus.incomplete:
        final digits = PhoneFormatter.clean(_phoneController.text);
        return Row(
          children: [
            Icon(
              Icons.info_outline_rounded,
              size: 12,
              color: colors.textMuted,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                'Enter 10-digit ${_selectedCountry.name} number (${digits.length}/10)',
                style: TextStyle(
                  color: colors.textMuted,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        );

      case PhoneValidationStatus.invalidAreaCode:
        return Row(
          children: [
            Icon(
              Icons.cancel_outlined,
              size: 12,
              color: colors.ruby,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                'US area code cannot begin with 0 or 1',
                style: TextStyle(
                  color: colors.ruby,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        );

      case PhoneValidationStatus.invalidFormat:
        return Row(
          children: [
            Icon(
              Icons.cancel_outlined,
              size: 12,
              color: colors.ruby,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                'Invalid ${_selectedCountry.name} number format',
                style: TextStyle(
                  color: colors.ruby,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        );

      case PhoneValidationStatus.valid:
        return Row(
          children: [
            Icon(
              Icons.check_circle_outline_rounded,
              size: 12,
              color: colors.emerald,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                'Valid ${_selectedCountry.name} Phone Number',
                style: TextStyle(
                  color: colors.emerald,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        );
    }
  }

  Widget _buildAddressField(PaidiXColorScheme colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ADDRESS (OPTIONAL)',
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
                color: colors.border.withValues(alpha: 0.8), width: 1.2),
          ),
          child: TextField(
            controller: _addressController,
            maxLines: 2,
            style: TextStyle(color: colors.textPrimary, fontSize: 13.5),
            decoration: InputDecoration(
              hintText: 'Street address, apartment or suite',
              hintStyle: TextStyle(color: colors.textMuted, fontSize: 13.5),
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
            onChanged: (_) => _notifyChange(),
          ),
        ),
      ],
    );
  }

  Widget _buildCityField(PaidiXColorScheme colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'CITY (OPTIONAL)',
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
                color: colors.border.withValues(alpha: 0.8), width: 1.2),
          ),
          child: TextField(
            controller: _cityController,
            style: TextStyle(color: colors.textPrimary, fontSize: 13.5),
            decoration: InputDecoration(
              hintText: 'Lahore, Karachi, Islamabad / New York, Dallas...',
              hintStyle: TextStyle(color: colors.textMuted, fontSize: 13.5),
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
            onChanged: (_) => _notifyChange(),
          ),
        ),
      ],
    );
  }
}
