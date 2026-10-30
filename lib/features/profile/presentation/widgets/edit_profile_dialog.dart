import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/spongy_tap.dart';
import '../../data/user_profile_repository.dart';
import '../../domain/user_profile.dart';

/// Modal dialog for modifying personal profile details and re-uploading
/// KYC identity document assets (Selfie, CNIC Front, CNIC Back) from phone gallery.
class EditProfileDialog extends StatefulWidget {
  final UserProfile profile;

  const EditProfileDialog({super.key, required this.profile});

  static Future<void> show(BuildContext context, UserProfile profile) {
    return showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (ctx) => EditProfileDialog(profile: profile),
    );
  }

  @override
  State<EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends State<EditProfileDialog> {
  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();

  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _cnicController;
  late final TextEditingController _cityController;
  late final TextEditingController _addressController;

  // Re-uploaded document state
  Uint8List? _selfieBytes;
  String? _selfieFileName;
  String? _selfiePath;

  Uint8List? _cnicFrontBytes;
  String? _cnicFrontFileName;
  String? _cnicFrontPath;

  Uint8List? _cnicBackBytes;
  String? _cnicBackFileName;
  String? _cnicBackPath;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.profile.fullName);
    _phoneController = TextEditingController(text: widget.profile.phoneNumber);
    _cnicController = TextEditingController(text: widget.profile.cnicNumber);
    _cityController = TextEditingController(text: widget.profile.city);
    _addressController = TextEditingController(text: widget.profile.address);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _cnicController.dispose();
    _cityController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _pickDocument({
    required String typeLabel,
    required void Function(Uint8List bytes, String name, String path) onPicked,
  }) async {
    HapticFeedback.lightImpact();

    try {
      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        await Permission.photos.request();
      }

      final xFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1200,
        imageQuality: 92,
      );

      if (xFile != null) {
        final bytes = await xFile.readAsBytes();
        final fileName = xFile.name.isNotEmpty
            ? xFile.name
            : '${typeLabel.toLowerCase().replaceAll(' ', '_')}.jpg';

        setState(() {
          onPicked(bytes, fileName, xFile.path);
        });

        HapticFeedback.selectionClick();
      }
    } catch (_) {
      // Graceful error handling for cancelled or denied permissions
    }
  }

  Future<void> _handleSave() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isSaving = true);

    final messenger = ScaffoldMessenger.of(context);
    final hasNewDocs = _selfieBytes != null ||
        _cnicFrontBytes != null ||
        _cnicBackBytes != null;

    UserProfileRepository.instance.updateProfile(
      fullName: _nameController.text.trim(),
      phoneNumber: _phoneController.text.trim(),
      cnicNumber: _cnicController.text.trim(),
      city: _cityController.text.trim(),
      address: _addressController.text.trim(),
      selfieBytes: _selfieBytes,
      selfieFilePath: _selfiePath,
      cnicFrontBytes: _cnicFrontBytes,
      cnicFrontFilePath: _cnicFrontPath,
      cnicBackBytes: _cnicBackBytes,
      cnicBackFilePath: _cnicBackPath,
    );

    if (hasNewDocs) {
      await NotificationService.instance.showNotification(
        id: 15,
        title: 'Profile Documents Updated',
        body: 'New identity documents and photos have been updated on your file.',
      );
    }

    if (!mounted) return;
    Navigator.of(context).pop();

    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                hasNewDocs
                    ? 'Profile and documents updated successfully'
                    : 'Profile updated successfully',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF0E7C7B),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final size = MediaQuery.of(context).size;
    final isNarrow = size.width < 560;

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: isNarrow ? size.width * 0.94 : 640,
          constraints: BoxConstraints(
            maxHeight: size.height * 0.90,
            maxWidth: 680,
          ),
          margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
          padding: EdgeInsets.all(isNarrow ? 18 : 24),
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: AppSpacing.radiusXl,
            border: Border.all(color: colors.border, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.55),
                blurRadius: 32,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title Header Block
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Edit profile',
                              style: TextStyle(
                                color: colors.textPrimary,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Update your verified contact and address information',
                              style: TextStyle(
                                color: colors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close_rounded, color: colors.textMuted),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Full Name
                  _buildLabel('FULL NAME', colors),
                  _buildInput(
                    controller: _nameController,
                    hint: 'Your full name',
                    colors: colors,
                    validator: (val) {
                      if (val == null || val.trim().length < 3) {
                        return 'Full name must be at least 3 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),

                  // Phone
                  _buildLabel('PHONE', colors),
                  _buildInput(
                    controller: _phoneController,
                    hint: '+923217649976 or (336) 306-0546',
                    colors: colors,
                    validator: (val) {
                      if (val == null || val.trim().length < 7) {
                        return 'Enter a valid phone number';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),

                  // CNIC Number
                  _buildLabel('CNIC NUMBER', colors),
                  _buildInput(
                    controller: _cnicController,
                    hint: '35202-04504615',
                    colors: colors,
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'CNIC number is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),

                  // City and Address Row on wide, stacked on mobile
                  if (isNarrow) ...[
                    _buildLabel('CITY', colors),
                    _buildInput(
                      controller: _cityController,
                      hint: 'e.g. Lahore / لاہور',
                      colors: colors,
                    ),
                    const SizedBox(height: 14),
                    _buildLabel('ADDRESS', colors),
                    _buildInput(
                      controller: _addressController,
                      hint: 'Street, sector, housing society',
                      colors: colors,
                    ),
                  ] else ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLabel('CITY', colors),
                              _buildInput(
                                controller: _cityController,
                                hint: 'e.g. Lahore / لاہور',
                                colors: colors,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLabel('ADDRESS', colors),
                              _buildInput(
                                controller: _addressController,
                                hint: 'Street address, housing society',
                                colors: colors,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 20),

                  // Re-Upload Documents Section Header
                  Text(
                    'RE-UPLOAD DOCUMENTS (OPTIONAL — LEAVE EMPTY TO KEEP CURRENT)',
                    style: TextStyle(
                      color: colors.textMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 3 Document Pickers
                  if (isNarrow) ...[
                    _buildDocPicker(
                      label: 'SELFIE',
                      fileName: _selfieFileName,
                      hasCustomBytes: _selfieBytes != null,
                      colors: colors,
                      onTap: () => _pickDocument(
                        typeLabel: 'Selfie',
                        onPicked: (bytes, name, path) {
                          _selfieBytes = bytes;
                          _selfieFileName = name;
                          _selfiePath = path;
                        },
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildDocPicker(
                      label: 'CNIC FRONT',
                      fileName: _cnicFrontFileName,
                      hasCustomBytes: _cnicFrontBytes != null,
                      colors: colors,
                      onTap: () => _pickDocument(
                        typeLabel: 'CNIC Front',
                        onPicked: (bytes, name, path) {
                          _cnicFrontBytes = bytes;
                          _cnicFrontFileName = name;
                          _cnicFrontPath = path;
                        },
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildDocPicker(
                      label: 'CNIC BACK',
                      fileName: _cnicBackFileName,
                      hasCustomBytes: _cnicBackBytes != null,
                      colors: colors,
                      onTap: () => _pickDocument(
                        typeLabel: 'CNIC Back',
                        onPicked: (bytes, name, path) {
                          _cnicBackBytes = bytes;
                          _cnicBackFileName = name;
                          _cnicBackPath = path;
                        },
                      ),
                    ),
                  ] else ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _buildDocPicker(
                            label: 'SELFIE',
                            fileName: _selfieFileName,
                            hasCustomBytes: _selfieBytes != null,
                            colors: colors,
                            onTap: () => _pickDocument(
                              typeLabel: 'Selfie',
                              onPicked: (bytes, name, path) {
                                _selfieBytes = bytes;
                                _selfieFileName = name;
                                _selfiePath = path;
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildDocPicker(
                            label: 'CNIC FRONT',
                            fileName: _cnicFrontFileName,
                            hasCustomBytes: _cnicFrontBytes != null,
                            colors: colors,
                            onTap: () => _pickDocument(
                              typeLabel: 'CNIC Front',
                              onPicked: (bytes, name, path) {
                                _cnicFrontBytes = bytes;
                                _cnicFrontFileName = name;
                                _cnicFrontPath = path;
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildDocPicker(
                            label: 'CNIC BACK',
                            fileName: _cnicBackFileName,
                            hasCustomBytes: _cnicBackBytes != null,
                            colors: colors,
                            onTap: () => _pickDocument(
                              typeLabel: 'CNIC Back',
                              onPicked: (bytes, name, path) {
                                _cnicBackBytes = bytes;
                                _cnicBackFileName = name;
                                _cnicBackPath = path;
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 24),

                  // Action Buttons Footer
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            color: colors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      AppButton(
                        text: _isSaving ? 'Saving...' : 'Save & resubmit',
                        variant: AppButtonVariant.primary,
                        icon: const Icon(Icons.check_rounded, size: 16),
                        onPressed: _isSaving ? null : _handleSave,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDocPicker({
    required String label,
    required String? fileName,
    required bool hasCustomBytes,
    required PaidiXColorScheme colors,
    required VoidCallback onTap,
  }) {
    final hasChosen = fileName != null && fileName.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: colors.textMuted,
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color: colors.inputBackground,
            borderRadius: AppSpacing.radiusMd,
            border: Border.all(
              color: hasChosen
                  ? colors.emerald.withValues(alpha: 0.6)
                  : colors.border.withValues(alpha: 0.8),
              width: 1.2,
            ),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 185;

              final chooseButton = SpongyTap(
                onTap: onTap,
                pressScale: 0.94,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 5.5),
                  decoration: BoxDecoration(
                    color: colors.cardDark,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: colors.borderSubtle,
                      width: 1,
                    ),
                  ),
                  child: Text(
                    'Choose file',
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              );

              final statusRow = Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (hasChosen)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Icon(
                        Icons.check_circle_rounded,
                        size: 13,
                        color: colors.emerald,
                      ),
                    ),
                  Flexible(
                    child: Text(
                      hasChosen ? fileName : 'No file chosen',
                      style: TextStyle(
                        color: hasChosen ? colors.emerald : colors.textMuted,
                        fontSize: 11,
                        fontWeight:
                            hasChosen ? FontWeight.w600 : FontWeight.w400,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ],
              );

              if (isCompact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    chooseButton,
                    const SizedBox(height: 6),
                    statusRow,
                  ],
                );
              }

              return Row(
                children: [
                  chooseButton,
                  const SizedBox(width: 8),
                  Expanded(child: statusRow),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildLabel(String text, PaidiXColorScheme colors) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: TextStyle(
          color: colors.textMuted,
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildInput({
    required TextEditingController controller,
    required String hint,
    required PaidiXColorScheme colors,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      style: TextStyle(color: colors.textPrimary, fontSize: 13.5),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: colors.textMuted, fontSize: 13.5),
        filled: true,
        fillColor: colors.inputBackground,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: AppSpacing.radiusMd,
          borderSide:
              BorderSide(color: colors.border.withValues(alpha: 0.8), width: 1.2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppSpacing.radiusMd,
          borderSide:
              BorderSide(color: colors.border.withValues(alpha: 0.8), width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppSpacing.radiusMd,
          borderSide: BorderSide(color: colors.aqua, width: 1.4),
        ),
      ),
    );
  }
}
