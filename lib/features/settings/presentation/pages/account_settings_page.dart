import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/utils/cnic_formatter.dart';
import '../../../../core/widgets/spongy_tap.dart';
import '../../../kyc/data/kyc_image_processor.dart';
import '../../../profile/presentation/widgets/document_viewer_dialog.dart';
import '../../../../features/profile/data/user_profile_repository.dart';
import '../../../../features/profile/domain/bank_account_item.dart';
import '../../../../features/profile/domain/user_profile.dart';

// ============================================================
//  Account Settings Page — PaidiX
//  5 tabs: Profile · Security · Payments PIN · Appearance · Bank Accounts
// ============================================================

enum _SettingsTab { profile, security, paymentsPin, appearance, bankAccounts }

class AccountSettingsPage extends StatefulWidget {
  const AccountSettingsPage({super.key});

  @override
  State<AccountSettingsPage> createState() => _AccountSettingsPageState();
}

class _AccountSettingsPageState extends State<AccountSettingsPage>
    with TickerProviderStateMixin {
  _SettingsTab _activeTab = _SettingsTab.profile;
  late final AnimationController _contentController;
  late Animation<double> _contentFade;
  late Animation<Offset> _contentSlide;

  @override
  void initState() {
    super.initState();
    _contentController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _contentFade = CurvedAnimation(
      parent: _contentController,
      curve: Curves.easeOutCubic,
    );
    _contentSlide = Tween<Offset>(
      begin: const Offset(0.0, 0.025),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _contentController,
      curve: Curves.easeOutCubic,
    ));
    _contentController.forward();
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  void _switchTab(_SettingsTab tab) {
    if (tab == _activeTab) return;
    HapticFeedback.selectionClick();
    _contentController.reverse().then((_) {
      if (mounted) {
        setState(() => _activeTab = tab);
        _contentController.forward();
      }
    });
  }

  void _navigateBackToDashboard(BuildContext context) {
    HapticFeedback.lightImpact();
    context.go('/app/dashboard');
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final size = MediaQuery.of(context).size;
    final isWide = size.width >= 768 && size.height >= 520;

    return ValueListenableBuilder<UserProfile>(
      valueListenable: UserProfileRepository.instance.profileNotifier,
      builder: (context, profile, _) {
        return Scaffold(
          backgroundColor: colors.background,
          body: isWide
              ? _buildWideLayout(colors, profile)
              : _buildMobileLayout(colors, profile),
        );
      },
    );
  }

  // ── Wide / Tablet layout ────────────────────────────────────────────────
  Widget _buildWideLayout(PaidiXColorScheme colors, UserProfile profile) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left sidebar nav
        SizedBox(
          width: 240,
          child: _buildSideNav(colors, isMobile: false),
        ),
        Container(width: 1, color: colors.border),
        // Main content area
        Expanded(
          child: _buildMainContent(colors, profile, isMobile: false),
        ),
      ],
    );
  }

  // ── Mobile layout ────────────────────────────────────────────────────────
  Widget _buildMobileLayout(PaidiXColorScheme colors, UserProfile profile) {
    return Column(
      children: [
        _buildMobileTopBar(colors),
        _buildMobileTabBar(colors),
        Expanded(
          child: _buildMainContent(colors, profile, isMobile: true),
        ),
      ],
    );
  }

  // ── Top bar (mobile only) ────────────────────────────────────────────────
  Widget _buildMobileTopBar(PaidiXColorScheme colors) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        left: 16,
        right: 16,
        bottom: 12,
      ),
      decoration: BoxDecoration(
        color: colors.card,
        border: Border(bottom: BorderSide(color: colors.border, width: 1)),
      ),
      child: Row(
        children: [
          SpongyTap(
            onTap: () => _navigateBackToDashboard(context),
            pressScale: 0.90,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: colors.cardDark,
                shape: BoxShape.circle,
                border: Border.all(color: colors.border, width: 1),
              ),
              child: Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 16,
                color: colors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SETTINGS',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.6,
                    color: colors.gold,
                  ),
                ),
                Text(
                  'Account settings.',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                    color: colors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Mobile horizontal tab bar ────────────────────────────────────────────
  Widget _buildMobileTabBar(PaidiXColorScheme colors) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: colors.card,
        border: Border(bottom: BorderSide(color: colors.border, width: 1)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          children: _SettingsTab.values.map((tab) {
            final isActive = tab == _activeTab;
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: GestureDetector(
                onTap: () => _switchTab(tab),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: isActive
                        ? colors.aqua.withValues(alpha: 0.15)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isActive ? colors.aqua : colors.border,
                      width: isActive ? 1.5 : 1,
                    ),
                  ),
                  child: Text(
                    _tabLabel(tab),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight:
                          isActive ? FontWeight.w700 : FontWeight.w500,
                      color: isActive ? colors.aqua : colors.textSecondary,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ── Wide sidebar navigation ──────────────────────────────────────────────
  Widget _buildSideNav(PaidiXColorScheme colors, {required bool isMobile}) {
    return Container(
      color: colors.card,
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with back button
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 16, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      SpongyTap(
                        onTap: () => _navigateBackToDashboard(context),
                        pressScale: 0.90,
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: colors.cardDark,
                            shape: BoxShape.circle,
                            border: Border.all(color: colors.border, width: 1),
                          ),
                          child: Icon(
                            Icons.arrow_back_ios_new_rounded,
                            size: 14,
                            color: colors.textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'SETTINGS',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.6,
                          color: colors.gold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Account settings.',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Your profile, bank accounts,\nand personal preferences.',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: colors.textSecondary,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
            Divider(height: 1, thickness: 1, color: colors.border),
            const SizedBox(height: 8),
            // Nav items
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSideNavItem(
                    colors: colors,
                    tab: _SettingsTab.profile,
                    icon: Icons.person_outline_rounded,
                    activeIcon: Icons.person_rounded,
                  ),
                  _buildSideNavItem(
                    colors: colors,
                    tab: _SettingsTab.security,
                    icon: Icons.lock_outline_rounded,
                    activeIcon: Icons.lock_rounded,
                  ),
                  _buildSideNavItem(
                    colors: colors,
                    tab: _SettingsTab.paymentsPin,
                    icon: Icons.tag_rounded,
                    activeIcon: Icons.tag_rounded,
                  ),
                  _buildSideNavItem(
                    colors: colors,
                    tab: _SettingsTab.appearance,
                    icon: Icons.palette_outlined,
                    activeIcon: Icons.palette_rounded,
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    child: Text(
                      'MY DATA',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.4,
                        color: colors.textMuted,
                      ),
                    ),
                  ),
                  _buildSideNavItem(
                    colors: colors,
                    tab: _SettingsTab.bankAccounts,
                    icon: Icons.account_balance_outlined,
                    activeIcon: Icons.account_balance_rounded,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSideNavItem({
    required PaidiXColorScheme colors,
    required _SettingsTab tab,
    required IconData icon,
    required IconData activeIcon,
  }) {
    final isSelected = _activeTab == tab;
    return GestureDetector(
      onTap: () => _switchTab(tab),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        margin: const EdgeInsets.symmetric(vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? colors.aqua.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? colors.aqua.withValues(alpha: 0.3)
                : Colors.transparent,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? activeIcon : icon,
              size: 18,
              color: isSelected ? colors.aqua : colors.textMuted,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _tabLabel(tab),
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? colors.aqua : colors.textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Main content area ────────────────────────────────────────────────────
  Widget _buildMainContent(
    PaidiXColorScheme colors,
    UserProfile profile, {
    required bool isMobile,
  }) {
    return FadeTransition(
      opacity: _contentFade,
      child: SlideTransition(
        position: _contentSlide,
        child: _buildTabBody(colors, profile, isMobile: isMobile),
      ),
    );
  }

  Widget _buildTabBody(
    PaidiXColorScheme colors,
    UserProfile profile, {
    required bool isMobile,
  }) {
    switch (_activeTab) {
      case _SettingsTab.profile:
        return _ProfileSection(
            colors: colors, profile: profile, isMobile: isMobile);
      case _SettingsTab.security:
        return _SecuritySection(colors: colors, isMobile: isMobile);
      case _SettingsTab.paymentsPin:
        return _PaymentsPinSection(colors: colors, isMobile: isMobile);
      case _SettingsTab.appearance:
        return _AppearanceSection(colors: colors, isMobile: isMobile);
      case _SettingsTab.bankAccounts:
        return _BankAccountsSection(
            colors: colors, profile: profile, isMobile: isMobile);
    }
  }

  String _tabLabel(_SettingsTab tab) {
    switch (tab) {
      case _SettingsTab.profile:
        return 'Profile';
      case _SettingsTab.security:
        return 'Security';
      case _SettingsTab.paymentsPin:
        return 'Payments PIN';
      case _SettingsTab.appearance:
        return 'Appearance';
      case _SettingsTab.bankAccounts:
        return 'Bank Accounts';
    }
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  PROFILE SECTION
// ════════════════════════════════════════════════════════════════════════════
class _ProfileSection extends StatefulWidget {
  final PaidiXColorScheme colors;
  final UserProfile profile;
  final bool isMobile;

  const _ProfileSection({
    required this.colors,
    required this.profile,
    required this.isMobile,
  });

  @override
  State<_ProfileSection> createState() => _ProfileSectionState();
}

class _ProfileSectionState extends State<_ProfileSection> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _cnicCtrl;
  late final TextEditingController _cityCtrl;
  late final TextEditingController _addressCtrl;
  bool _saving = false;
  bool _isUploadingPhoto = false;

  static String _stripPkCode(String raw) {
    var s = raw.trim();
    if (s.startsWith('PK')) {
      s = s.substring(2).trim();
    }
    if (s.startsWith('+92')) {
      s = s.substring(3).trim();
    } else if (s.startsWith('92')) {
      s = s.substring(2).trim();
    } else if (s.startsWith('0')) {
      s = s.substring(1).trim();
    }
    return s;
  }

  @override
  void initState() {
    super.initState();
    final p = widget.profile;
    _nameCtrl = TextEditingController(text: p.fullName);
    _phoneCtrl = TextEditingController(text: _stripPkCode(p.phoneNumber));
    _cnicCtrl = TextEditingController(text: p.cnicNumber);
    _cityCtrl = TextEditingController(text: p.city);
    _addressCtrl = TextEditingController(text: p.address);
    _checkAndRetrieveLostImage();
  }

  @override
  void didUpdateWidget(covariant _ProfileSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profile != widget.profile) {
      final p = widget.profile;
      if (_nameCtrl.text != p.fullName) _nameCtrl.text = p.fullName;
      final stripped = _stripPkCode(p.phoneNumber);
      if (_phoneCtrl.text != stripped) _phoneCtrl.text = stripped;
      if (_cnicCtrl.text != p.cnicNumber) _cnicCtrl.text = p.cnicNumber;
      if (_cityCtrl.text != p.city) _cityCtrl.text = p.city;
      if (_addressCtrl.text != p.address) _addressCtrl.text = p.address;
    }
  }

  Future<void> _checkAndRetrieveLostImage() async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      try {
        final picker = ImagePicker();
        final response = await picker.retrieveLostData();
        if (!response.isEmpty && response.file != null) {
          final file = response.file!;
          await _processPickedFile(file, isAvatar: true);
        }
      } catch (e) {
        debugPrint('retrieveLostData error: $e');
      }
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _cnicCtrl.dispose();
    _cityCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  void _showToast(PaidiXColorScheme c, String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
        backgroundColor: isError ? c.borderError : c.statusCompletedDot,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _saveProfile() async {
    if (_saving) return;
    HapticFeedback.mediumImpact();
    setState(() => _saving = true);
    await Future.delayed(const Duration(milliseconds: 600));

    final cleanPhone = _stripPkCode(_phoneCtrl.text);
    UserProfileRepository.instance.updateProfile(
      fullName: _nameCtrl.text,
      phoneNumber: cleanPhone.isNotEmpty ? '+92$cleanPhone' : '',
      cnicNumber: _cnicCtrl.text,
      city: _cityCtrl.text,
      address: _addressCtrl.text,
    );
    if (mounted) {
      setState(() => _saving = false);
      _showToast(widget.colors, 'Profile updated successfully.');
    }
  }

  void _handleAvatarTap(UserProfile p) {
    HapticFeedback.lightImpact();
    if (p.hasCustomAvatar) {
      _showAvatarOptionsDialog(p);
    } else {
      _showImageSourceSheet(isAvatar: true);
    }
  }

  static Future<Uint8List> _safeDownscaleBytes(
    Uint8List rawBytes, {
    int maxDimension = 512,
  }) async {
    try {
      final codec = await ui.instantiateImageCodec(
        rawBytes,
        targetWidth: maxDimension,
      );
      final frameInfo = await codec.getNextFrame();
      final image = frameInfo.image;
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      // Explicitly dispose native Skia GPU texture handles to prevent memory leaks on Huawei
      image.dispose();
      codec.dispose();
      if (byteData != null) {
        return byteData.buffer.asUint8List();
      }
    } catch (e) {
      debugPrint('Downscale fallback: $e');
    }
    return rawBytes;
  }

  Widget _buildSourceOptionTile({
    required PaidiXColorScheme colors,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return SpongyTap(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      pressScale: 0.965,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isDestructive ? const Color(0xFF261014) : colors.cardDark,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDestructive
                ? const Color(0xFFEF4444).withValues(alpha: 0.6)
                : colors.border.withValues(alpha: 0.9),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.22),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isDestructive
                    ? const Color(0xFFEF4444).withValues(alpha: 0.15)
                    : colors.aqua.withValues(alpha: 0.14),
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDestructive
                      ? const Color(0xFFEF4444).withValues(alpha: 0.4)
                      : colors.aqua.withValues(alpha: 0.35),
                  width: 1.2,
                ),
              ),
              alignment: Alignment.center,
              child: Icon(
                icon,
                size: 22,
                color: isDestructive ? const Color(0xFFEF4444) : colors.aqua,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: isDestructive
                          ? const Color(0xFFEF4444)
                          : colors.textPrimary,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDestructive
                          ? colors.textMuted
                          : colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 13,
              color: isDestructive
                  ? const Color(0xFFEF4444).withValues(alpha: 0.6)
                  : colors.textMuted,
            ),
          ],
        ),
      ),
    );
  }

  void _showAvatarOptionsDialog(UserProfile p) {
    final c = widget.colors;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: c.border.withValues(alpha: 0.9), width: 1.2),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: c.aqua.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.account_circle_outlined, size: 22, color: c.aqua),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Profile Picture',
                style: TextStyle(
                  fontSize: 17.5,
                  fontWeight: FontWeight.w800,
                  color: c.textPrimary,
                  letterSpacing: -0.3,
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
                'Update your profile photo or remove it to restore your name initial "${p.avatarInitial}".',
                style: TextStyle(
                  fontSize: 13,
                  color: c.textSecondary,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 18),
              _buildSourceOptionTile(
                colors: c,
                icon: Icons.photo_camera_rounded,
                title: 'Update Profile Picture',
                subtitle: 'Take photo or choose from gallery/storage',
                onTap: () {
                  Navigator.of(ctx).pop();
                  _showImageSourceSheet(isAvatar: true);
                },
              ),
              const SizedBox(height: 12),
              _buildSourceOptionTile(
                colors: c,
                icon: Icons.delete_outline_rounded,
                title: 'Remove Profile Picture',
                subtitle: 'Revert back to initial letter "${p.avatarInitial}"',
                isDestructive: true,
                onTap: () {
                  Navigator.of(ctx).pop();
                  _removeAvatar(p);
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: c.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _removeAvatar(UserProfile p) {
    HapticFeedback.mediumImpact();
    UserProfileRepository.instance.updateProfile(clearAvatar: true);
    _showToast(widget.colors, 'Profile picture removed. Initial restored.');
  }

  void _showImageSourceSheet({
    required bool isAvatar,
    String? documentType,
  }) {
    final c = widget.colors;
    showModalBottomSheet(
      context: context,
      backgroundColor: c.card,
      elevation: 16,
      barrierColor: Colors.black.withValues(alpha: 0.65),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4.5,
                    decoration: BoxDecoration(
                      color: c.border.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  isAvatar
                      ? 'Upload Profile Picture'
                      : 'Replace ${documentType?.replaceAll('_', ' ').toUpperCase()}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: c.textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Select camera to snap a photo or choose from device storage/gallery.',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: c.textSecondary,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 20),
                _buildSourceOptionTile(
                  colors: c,
                  icon: Icons.camera_alt_rounded,
                  title: 'Take Photo',
                  subtitle: 'Capture using physical phone camera',
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _pickAndProcessImage(
                      ImageSource.camera,
                      isAvatar: isAvatar,
                      documentType: documentType,
                    );
                  },
                ),
                const SizedBox(height: 12),
                _buildSourceOptionTile(
                  colors: c,
                  icon: Icons.photo_library_rounded,
                  title: 'Choose from Gallery / Storage',
                  subtitle: 'Select image file from phone storage',
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _pickAndProcessImage(
                      ImageSource.gallery,
                      isAvatar: isAvatar,
                      documentType: documentType,
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _processPickedFile(
    XFile picked, {
    required bool isAvatar,
    String? documentType,
  }) async {
    final c = widget.colors;
    try {
      HapticFeedback.selectionClick();
      final rawBytes = await picked.readAsBytes();

      // Downscale safely in memory using Skia engine to prevent GPU OOM crash
      final safeBytes = await _safeDownscaleBytes(
        rawBytes,
        maxDimension: isAvatar ? 512 : 1024,
      );

      // Auto crop and enhance via KycImageProcessor
      const processor = KycImageProcessor();
      final result = await processor.enhanceDocument(
        rawBytes: safeBytes,
        fileName: picked.name,
        isSelfie: isAvatar || documentType == 'selfie',
      );

      final finalBytes = result.processedBytes ?? safeBytes;

      if (isAvatar) {
        UserProfileRepository.instance.updateProfile(
          avatarBytes: finalBytes,
          avatarFilePath: picked.path,
        );
        _showToast(c, 'Profile picture auto-cropped, enhanced & saved permanently.');
      } else if (documentType == 'selfie') {
        UserProfileRepository.instance.updateProfile(
          selfieBytes: finalBytes,
          selfieFilePath: picked.path,
        );
        _showToast(c, 'Selfie replaced and enhanced successfully.');
      } else if (documentType == 'cnic_front') {
        UserProfileRepository.instance.updateProfile(
          cnicFrontBytes: finalBytes,
          cnicFrontFilePath: picked.path,
        );
        _showToast(c, 'CNIC — FRONT replaced and enhanced successfully.');
      } else if (documentType == 'cnic_back') {
        UserProfileRepository.instance.updateProfile(
          cnicBackBytes: finalBytes,
          cnicBackFilePath: picked.path,
        );
        _showToast(c, 'CNIC — BACK replaced and enhanced successfully.');
      }
    } catch (e) {
      debugPrint('Error processing picked file: $e');
      _showToast(c, 'Failed to process picked image.', isError: true);
    }
  }

  Future<void> _pickAndProcessImage(
    ImageSource source, {
    required bool isAvatar,
    String? documentType,
  }) async {
    final c = widget.colors;
    try {
      // 1. Huawei & Android runtime permissions check
      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        if (source == ImageSource.camera) {
          final camStatus = await Permission.camera.request();
          if (camStatus.isPermanentlyDenied) {
            _showToast(c, 'Camera permission permanently denied. Please grant in Settings.', isError: true);
            return;
          }
        } else {
          // Huawei EMUI checks storage on Android <= 32 and photos on Android >= 33
          if (await Permission.photos.isDenied) {
            await Permission.photos.request();
          }
          if (await Permission.storage.isDenied) {
            await Permission.storage.request();
          }
        }
      }

      if (mounted) setState(() => _isUploadingPhoto = true);

      // 2. Pick image without aggressive native constraints to avoid native Java OOM on Huawei 48MP/64MP images
      final picker = ImagePicker();
      XFile? picked;
      try {
        picked = await picker.pickImage(source: source);
      } catch (e) {
        debugPrint('pickImage error: $e');
      }

      // 3. Check for lost data in case Huawei OS killed the activity while browsing gallery
      if (picked == null && !kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        try {
          final lostData = await picker.retrieveLostData();
          if (!lostData.isEmpty && lostData.file != null) {
            picked = lostData.file;
          }
        } catch (_) {}
      }

      if (picked == null) {
        if (mounted) setState(() => _isUploadingPhoto = false);
        return;
      }

      await _processPickedFile(
        picked,
        isAvatar: isAvatar,
        documentType: documentType,
      );
    } catch (e) {
      debugPrint('Error picking image: $e');
      _showToast(
        c,
        'Could not access image. Please grant camera/storage permissions.',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() => _isUploadingPhoto = false);
      }
    }
  }

  Widget _buildAvatarWithCamera(PaidiXColorScheme c, UserProfile p, double radius) {
    final double avatarSize = radius * 2;
    final double badgeSize = widget.isMobile ? 26 : 28;

    return SpongyTap(
      onTap: () => _handleAvatarTap(p),
      pressScale: 0.95,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Enhanced Avatar Frame with Outer Aqua Ambient Halo & Double Ring
          Container(
            width: avatarSize,
            height: avatarSize,
            decoration: BoxDecoration(
              color: c.cardDark,
              shape: BoxShape.circle,
              border: Border.all(
                color: c.aqua.withValues(alpha: 0.85),
                width: 2.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: c.aqua.withValues(alpha: 0.28),
                  blurRadius: 14,
                  spreadRadius: 1,
                  offset: const Offset(0, 3),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.45),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: ClipOval(
              child: _isUploadingPhoto
                  ? Center(
                      child: SizedBox(
                        width: 26,
                        height: 26,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(c.aqua),
                        ),
                      ),
                    )
                  : _buildAvatarImageOrInitial(c, p, avatarSize),
            ),
          ),

          // Floating Elevated High-Contrast Camera Icon Badge
          Positioned(
            bottom: -2,
            right: -2,
            child: Container(
              width: badgeSize,
              height: badgeSize,
              decoration: BoxDecoration(
                color: c.aqua,
                shape: BoxShape.circle,
                border: Border.all(color: c.cardDark, width: 2.2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.45),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.camera_alt_outlined,
                size: 14,
                color: Color(0xFF031415),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarImageOrInitial(PaidiXColorScheme c, UserProfile p, double size) {
    if (p.hasCustomAvatar) {
      if (p.avatarBytes != null && p.avatarBytes!.isNotEmpty) {
        return Image.memory(
          p.avatarBytes!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          alignment: const Alignment(0.0, -0.22),
          cacheWidth: 400,
          cacheHeight: 400,
          errorBuilder: (_, __, ___) => _avatarInitialText(c, p.avatarInitial, size),
        );
      }
      if (p.avatarFilePath != null && p.avatarFilePath!.isNotEmpty && !kIsWeb) {
        final file = File(p.avatarFilePath!);
        if (file.existsSync()) {
          return Image.file(
            file,
            width: size,
            height: size,
            fit: BoxFit.cover,
            alignment: const Alignment(0.0, -0.22),
            cacheWidth: 400,
            cacheHeight: 400,
            errorBuilder: (_, __, ___) => _avatarInitialText(c, p.avatarInitial, size),
          );
        }
      }
    }
    return _avatarInitialText(c, p.avatarInitial, size);
  }

  Widget _avatarInitialText(PaidiXColorScheme c, String initial, double size) {
    return Center(
      child: Text(
        initial,
        style: TextStyle(
          color: c.aqua,
          fontWeight: FontWeight.w800,
          fontSize: size * 0.42,
        ),
      ),
    );
  }

  Widget _buildSavedDocumentsSection(PaidiXColorScheme c, UserProfile p) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Identity documents',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: c.textPrimary,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Your verified identity documents on file. Tap Replace to update any document.',
          style: TextStyle(
            fontSize: 12.5,
            color: c.textSecondary,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 14),

        // Enhanced Identity Documents Preview Banner (matches KYC Step 2 & 3)
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: c.emerald.withValues(alpha: 0.12),
            borderRadius: AppSpacing.radiusMd,
            border: Border.all(
              color: c.emerald.withValues(alpha: 0.35),
              width: 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.check_circle_outline_rounded,
                size: 18,
                color: c.emerald,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Enhanced Identity Documents Preview',
                      style: TextStyle(
                        color: c.emerald,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Your KYC identity documents and biometric photo have been auto-aligned, glare-removed, and contrast-enhanced. Tap any image to inspect details.',
                      style: TextStyle(
                        color: c.textSecondary,
                        fontSize: 11.5,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 600;
            if (isWide) {
              return Row(
                children: [
                  Expanded(
                    child: _buildDocCard(
                      c,
                      label: 'SELFIE',
                      docType: 'selfie',
                      bytes: p.selfieBytes,
                      filePath: p.selfieFilePath,
                      isSelfie: true,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _buildDocCard(
                      c,
                      label: 'CNIC — FRONT',
                      docType: 'cnic_front',
                      bytes: p.cnicFrontBytes,
                      filePath: p.cnicFrontFilePath,
                      isSelfie: false,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _buildDocCard(
                      c,
                      label: 'CNIC — BACK',
                      docType: 'cnic_back',
                      bytes: p.cnicBackBytes,
                      filePath: p.cnicBackFilePath,
                      isSelfie: false,
                    ),
                  ),
                ],
              );
            } else {
              return Column(
                children: [
                  _buildDocCard(
                    c,
                    label: 'SELFIE',
                    docType: 'selfie',
                    bytes: p.selfieBytes,
                    filePath: p.selfieFilePath,
                    isSelfie: true,
                  ),
                  const SizedBox(height: 14),
                  _buildDocCard(
                    c,
                    label: 'CNIC — FRONT',
                    docType: 'cnic_front',
                    bytes: p.cnicFrontBytes,
                    filePath: p.cnicFrontFilePath,
                    isSelfie: false,
                  ),
                  const SizedBox(height: 14),
                  _buildDocCard(
                    c,
                    label: 'CNIC — BACK',
                    docType: 'cnic_back',
                    bytes: p.cnicBackBytes,
                    filePath: p.cnicBackFilePath,
                    isSelfie: false,
                  ),
                ],
              );
            }
          },
        ),
      ],
    );
  }

  Widget _buildDocCard(
    PaidiXColorScheme c, {
    required String label,
    required String docType,
    required Uint8List? bytes,
    required String? filePath,
    required bool isSelfie,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: c.cardDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.border.withValues(alpha: 0.8), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Row with Title and Green ✓ Enhanced Badge (matches KYC Step 2 & 3)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: c.textPrimary,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: c.emerald.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: c.emerald.withValues(alpha: 0.4),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_rounded,
                        size: 11,
                        color: c.emerald,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        'Enhanced',
                        style: TextStyle(
                          color: c.emerald,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Divider
          Container(height: 1, color: c.border.withValues(alpha: 0.7)),

          // Preview area (tappable to inspect in high resolution with floating zoom lens button)
          SpongyTap(
            onTap: () {
              DocumentViewerDialog.show(
                context,
                title: label,
                subtitle: 'Verified regulatory identity document on file',
                bytes: bytes,
                filePath: filePath,
                isSelfie: isSelfie,
              );
            },
            pressScale: 0.98,
            child: Stack(
              alignment: Alignment.bottomRight,
              children: [
                Container(
                  height: 155,
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: Color(0xFF021B19),
                  ),
                  child: ClipRect(
                    child: _buildDocPreview(c, label, bytes, filePath, isSelfie),
                  ),
                ),
                // Floating semi-transparent zoom badge overlay
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3),
                      ),
                    ),
                    child: const Icon(
                      Icons.zoom_in_rounded,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Divider
          Container(height: 1, color: c.border.withValues(alpha: 0.7)),

          // Bottom Bar: Inspect hint on left, Replace spongy action on right
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: SpongyTap(
                    onTap: () {
                      DocumentViewerDialog.show(
                        context,
                        title: label,
                        subtitle: 'Verified regulatory identity document on file',
                        bytes: bytes,
                        filePath: filePath,
                        isSelfie: isSelfie,
                      );
                    },
                    pressScale: 0.98,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.zoom_in_rounded, size: 13, color: c.aqua),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            'Tap to inspect in detail',
                            style: TextStyle(
                              fontSize: 11,
                              color: c.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SpongyTap(
                  onTap: () => _showImageSourceSheet(
                    isAvatar: false,
                    documentType: docType,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 4, vertical: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.sync_rounded, size: 12.5, color: c.aqua),
                        const SizedBox(width: 4),
                        Text(
                          'Replace',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: c.aqua,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocPreview(
    PaidiXColorScheme c,
    String label,
    Uint8List? bytes,
    String? filePath,
    bool isSelfie,
  ) {
    // 1. High-fidelity Biometric Portrait Presentation for Selfie
    if (isSelfie) {
      final hasRealImage = (bytes != null && bytes.isNotEmpty) ||
          (filePath != null && filePath.isNotEmpty && !kIsWeb && File(filePath).existsSync());

      if (hasRealImage) {
        final ImageProvider imageProvider = (bytes != null && bytes.isNotEmpty)
            ? MemoryImage(bytes)
            : FileImage(File(filePath!)) as ImageProvider;

        return Stack(
          fit: StackFit.expand,
          alignment: Alignment.center,
          children: [
            // Ambient atmospheric backdrop matching image lighting & hues
            Image(
              image: imageProvider,
              fit: BoxFit.cover,
              alignment: Alignment.center,
            ),
            // Frosted blur scrim to prevent clash with foreground
            ClipRect(
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  color: const Color(0xFF021B19).withValues(alpha: 0.82),
                ),
              ),
            ),

            // Perfectly Framed Natural Portrait Frame (Head & Face fully centered!)
            Center(
              child: Container(
                width: 118,
                height: 144,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: c.emerald,
                    width: 2.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: c.emerald.withValues(alpha: 0.35),
                      blurRadius: 16,
                      spreadRadius: 1,
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image(
                    image: imageProvider,
                    fit: BoxFit.cover,
                    alignment: const Alignment(0.0, -0.22),
                  ),
                ),
              ),
            ),

            // Biometric verified indicator pill in top-left
            Positioned(
              top: 8,
              left: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                decoration: BoxDecoration(
                  color: const Color(0xFF062320).withValues(alpha: 0.90),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: c.emerald.withValues(alpha: 0.5),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.face_retouching_natural_rounded,
                      size: 11,
                      color: c.emerald,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'PORTRAIT BIOMETRIC',
                      style: TextStyle(
                        color: c.emerald,
                        fontSize: 8.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.7,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      }
    }

    // 2. Regulatory CNIC Documents (Front & Back) — Landscape View
    if (bytes != null && bytes.isNotEmpty) {
      return Image.memory(
        bytes,
        fit: BoxFit.cover,
        alignment: Alignment.center,
        width: double.infinity,
        height: 155,
        cacheWidth: 800,
      );
    }
    if (filePath != null && filePath.isNotEmpty && !kIsWeb) {
      final file = File(filePath);
      if (file.existsSync()) {
        return Image.file(
          file,
          fit: BoxFit.cover,
          alignment: Alignment.center,
          width: double.infinity,
          height: 155,
          cacheWidth: 800,
        );
      }
    }

    // High fidelity synthetic document preview matching KYC steps
    if (isSelfie) {
      return Container(
        color: const Color(0xFF072B2B),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: c.cardHighlight,
                  border: Border.all(
                    color: c.emerald,
                    width: 2.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: c.emerald.withValues(alpha: 0.25),
                      blurRadius: 12,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.person_rounded,
                  color: c.emerald,
                  size: 32,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F3A35),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: c.emerald, width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_rounded, size: 10, color: c.emerald),
                    const SizedBox(width: 3),
                    Text(
                      'BIOMETRIC VERIFIED',
                      style: TextStyle(
                        color: c.emerald,
                        fontSize: 8.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    final isBack = label.contains('BACK');
    final displayCnic = widget.profile.cnicNumber.isNotEmpty
        ? CnicValidator.format(widget.profile.cnicNumber)
        : '35202-0450461-5';

    return Container(
      color: const Color(0xFF072B2B),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: c.emerald.withValues(alpha: 0.2),
                        border: Border.all(color: c.emerald, width: 1),
                      ),
                      child: Center(
                        child: Text(
                          'PK',
                          style: TextStyle(
                            color: c.emerald,
                            fontSize: 7.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'GOVERNMENT OF PAKISTAN',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 8.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            isBack
                                ? 'NATIONAL IDENTITY CARD (BACK)'
                                : 'NATIONAL IDENTITY CARD (FRONT)',
                            style: TextStyle(
                              color: c.aqua,
                              fontSize: 7.5,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Container(
                width: 20,
                height: 14,
                decoration: BoxDecoration(
                  color: const Color(0xFFB5933C).withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(2),
                  border: Border.all(color: const Color(0xFF8B6F27), width: 0.8),
                ),
              ),
            ],
          ),
          if (!isBack) ...[
            Row(
              children: [
                Container(
                  width: 32,
                  height: 38,
                  decoration: BoxDecoration(
                    color: c.cardDark,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: c.aqua.withValues(alpha: 0.35),
                      width: 1,
                    ),
                  ),
                  child: Icon(Icons.person, size: 22, color: c.aquaLight.withValues(alpha: 0.6)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(height: 5, width: 85, decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(2))),
                      const SizedBox(height: 4),
                      Container(height: 5, width: 60, decoration: BoxDecoration(color: c.border.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(2))),
                      const SizedBox(height: 4),
                      Container(height: 5, width: 110, decoration: BoxDecoration(color: c.border.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(2))),
                    ],
                  ),
                ),
              ],
            ),
          ] else ...[
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(height: 4, width: double.infinity, color: c.border),
                const SizedBox(height: 4),
                Container(height: 4, width: 140, color: c.border.withValues(alpha: 0.6)),
                const SizedBox(height: 4),
                Container(height: 4, width: 190, color: c.border.withValues(alpha: 0.4)),
              ],
            ),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  displayCnic,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                    fontFamily: 'monospace',
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                'NADRA VERIFIED',
                style: TextStyle(
                  color: c.emerald,
                  fontSize: 7.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.colors;
    final p = widget.profile;
    final pad = widget.isMobile ? 16.0 : 32.0;

    return SingleChildScrollView(
      padding: EdgeInsets.all(pad),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section heading
          _sectionHeader(c, 'Profile', 'How you appear across PaidiX.'),
          const SizedBox(height: 20),

          // Profile card
          _SettingsCard(
            colors: c,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar + name + email
                Row(
                  children: [
                    _buildAvatarWithCamera(c, p, widget.isMobile ? 38 : 44),
                    SizedBox(width: widget.isMobile ? 14 : 18),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p.fullName,
                            style: TextStyle(
                              fontSize: widget.isMobile ? 16 : 17,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                              color: c.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            p.email,
                            style: TextStyle(
                              fontSize: widget.isMobile ? 12.5 : 13,
                              color: c.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: c.aqua.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                  color: c.aqua.withValues(alpha: 0.3),
                                  width: 1),
                            ),
                            child: Text(
                              'CUSTOMER',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.2,
                                color: c.aqua,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Divider(height: 1, color: c.border),
                const SizedBox(height: 20),

                // Full Name + Phone row
                _fieldRow(
                  isMobile: widget.isMobile,
                  left: _labeledField(
                    c,
                    label: 'FULL NAME',
                    controller: _nameCtrl,
                  ),
                  right: _labeledField(
                    c,
                    label: 'PHONE',
                    controller: _phoneCtrl,
                    prefix: Text(
                      'PK +92',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: c.textSecondary,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),
                // Identity details
                Text(
                  'Identity details',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: c.textPrimary,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Keep your identity details accurate. Saving any change will resubmit them for review.',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: c.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),

                // CNIC + City row
                _fieldRow(
                  isMobile: widget.isMobile,
                  left: _labeledField(
                    c,
                    label: 'CNIC NUMBER',
                    controller: _cnicCtrl,
                    hint: '00000-0000000-0',
                  ),
                  right: _labeledField(
                    c,
                    label: 'CITY',
                    controller: _cityCtrl,
                  ),
                ),
                const SizedBox(height: 14),
                _labeledField(
                  c,
                  label: 'ADDRESS',
                  controller: _addressCtrl,
                ),
                const SizedBox(height: 24),

                // Saved Identity Documents section (Selfie, CNIC Front, CNIC Back)
                _buildSavedDocumentsSection(c, p),
                const SizedBox(height: 24),

                // Save button
                Align(
                  alignment: Alignment.centerRight,
                  child: _SettingsButton(
                    colors: c,
                    label: 'Save changes',
                    icon: Icons.check_rounded,
                    loading: _saving,
                    onTap: _saveProfile,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  SECURITY SECTION
// ════════════════════════════════════════════════════════════════════════════
class _SecuritySection extends StatefulWidget {
  final PaidiXColorScheme colors;
  final bool isMobile;

  const _SecuritySection({required this.colors, required this.isMobile});

  @override
  State<_SecuritySection> createState() => _SecuritySectionState();
}

class _SecuritySectionState extends State<_SecuritySection> {
  final _currentPassCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  bool _showCurrent = false;
  bool _showNew = false;
  bool _showConfirm = false;
  bool _loading = false;

  @override
  void dispose() {
    _currentPassCtrl.dispose();
    _newPassCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  void _updatePassword() async {
    final c = widget.colors;
    if (_currentPassCtrl.text.isEmpty ||
        _newPassCtrl.text.isEmpty ||
        _confirmPassCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please fill in all fields.'),
          backgroundColor: c.borderError,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(16),
        ),
      );
      return;
    }
    if (_newPassCtrl.text != _confirmPassCtrl.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('New passwords do not match.'),
          backgroundColor: c.borderError,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(16),
        ),
      );
      return;
    }
    HapticFeedback.mediumImpact();
    setState(() => _loading = true);
    await Future.delayed(const Duration(milliseconds: 700));
    if (mounted) {
      setState(() => _loading = false);
      _currentPassCtrl.clear();
      _newPassCtrl.clear();
      _confirmPassCtrl.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Password updated successfully.'),
          backgroundColor: c.statusCompletedDot,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.colors;
    final pad = widget.isMobile ? 16.0 : 32.0;

    return SingleChildScrollView(
      padding: EdgeInsets.all(pad),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(
              c, 'Security', 'Choose a strong password and change it periodically.'),
          const SizedBox(height: 20),
          _SettingsCard(
            colors: c,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _passwordField(
                  c,
                  label: 'CURRENT PASSWORD',
                  controller: _currentPassCtrl,
                  show: _showCurrent,
                  onToggle: () => setState(() => _showCurrent = !_showCurrent),
                ),
                const SizedBox(height: 16),
                _passwordField(
                  c,
                  label: 'NEW PASSWORD',
                  controller: _newPassCtrl,
                  show: _showNew,
                  onToggle: () => setState(() => _showNew = !_showNew),
                ),
                const SizedBox(height: 16),
                _passwordField(
                  c,
                  label: 'CONFIRM NEW PASSWORD',
                  controller: _confirmPassCtrl,
                  show: _showConfirm,
                  onToggle: () => setState(() => _showConfirm = !_showConfirm),
                ),
                const SizedBox(height: 24),
                Align(
                  alignment: Alignment.centerRight,
                  child: _SettingsButton(
                    colors: c,
                    label: 'Update password',
                    icon: Icons.lock_rounded,
                    loading: _loading,
                    onTap: _updatePassword,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _passwordField(
    PaidiXColorScheme c, {
    required String label,
    required TextEditingController controller,
    required bool show,
    required VoidCallback onToggle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.1,
            color: c.textLabel,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: c.inputFill,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: c.border, width: 1.2),
          ),
          child: TextField(
            controller: controller,
            obscureText: !show,
            style: TextStyle(
              fontSize: 14,
              color: c.textPrimary,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              hintText: '••••••••',
              hintStyle: TextStyle(color: c.textPlaceholder, fontSize: 14),
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              suffixIcon: GestureDetector(
                onTap: onToggle,
                child: Icon(
                  show ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  size: 20,
                  color: c.textMuted,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  PAYMENTS PIN SECTION
// ════════════════════════════════════════════════════════════════════════════
class _PaymentsPinSection extends StatefulWidget {
  final PaidiXColorScheme colors;
  final bool isMobile;

  const _PaymentsPinSection({required this.colors, required this.isMobile});

  @override
  State<_PaymentsPinSection> createState() => _PaymentsPinSectionState();
}

class _PaymentsPinSectionState extends State<_PaymentsPinSection> {
  // Process-memory stored PIN (persists across tab switches)
  static String? _globalStoredPin;

  // Controllers for initial Set PIN
  final _initialPinCtrl = TextEditingController();
  final _initialConfirmPinCtrl = TextEditingController();

  // Controllers for Update PIN
  final _currentPinUpdateCtrl = TextEditingController();
  final _newPinUpdateCtrl = TextEditingController();
  final _confirmPinUpdateCtrl = TextEditingController();

  // Controller for Remove PIN
  final _currentPinRemoveCtrl = TextEditingController();

  bool _showPin = false;
  bool _loadingSet = false;
  bool _loadingUpdate = false;
  bool _loadingRemove = false;

  bool get _pinIsSet =>
      _globalStoredPin != null && _globalStoredPin!.trim().isNotEmpty;

  @override
  void dispose() {
    _initialPinCtrl.dispose();
    _initialConfirmPinCtrl.dispose();
    _currentPinUpdateCtrl.dispose();
    _newPinUpdateCtrl.dispose();
    _confirmPinUpdateCtrl.dispose();
    _currentPinRemoveCtrl.dispose();
    super.dispose();
  }

  void _showSnack(PaidiXColorScheme c, String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
        backgroundColor: isError ? c.borderError : c.statusCompletedDot,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _setInitialPin() async {
    final c = widget.colors;
    final pin = _initialPinCtrl.text.trim();
    final confirm = _initialConfirmPinCtrl.text.trim();

    if (pin.isEmpty || confirm.isEmpty) {
      _showSnack(c, 'Please fill in both PIN fields.', isError: true);
      return;
    }
    if (pin.length < 4 || pin.length > 8) {
      _showSnack(c, 'PIN must be 4–8 digits.', isError: true);
      return;
    }
    if (pin != confirm) {
      _showSnack(c, 'PINs do not match.', isError: true);
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() => _loadingSet = true);
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) {
      setState(() {
        _loadingSet = false;
        _globalStoredPin = pin;
        _initialPinCtrl.clear();
        _initialConfirmPinCtrl.clear();
      });
      _showSnack(c, 'Payments PIN set. Your payments page is now locked.');
    }
  }

  void _updatePin() async {
    final c = widget.colors;
    final current = _currentPinUpdateCtrl.text.trim();
    final newPin = _newPinUpdateCtrl.text.trim();
    final confirm = _confirmPinUpdateCtrl.text.trim();

    if (current.isEmpty) {
      _showSnack(c, 'Please enter your current PIN.', isError: true);
      return;
    }
    if (current != _globalStoredPin) {
      _showSnack(
        c,
        'Incorrect current PIN. Please enter your correct previous PIN.',
        isError: true,
      );
      return;
    }
    if (newPin.isEmpty || confirm.isEmpty) {
      _showSnack(c, 'Please enter and confirm your new PIN.', isError: true);
      return;
    }
    if (newPin.length < 4 || newPin.length > 8) {
      _showSnack(c, 'New PIN must be 4–8 digits.', isError: true);
      return;
    }
    if (newPin != confirm) {
      _showSnack(c, 'New PIN and Confirm PIN do not match.', isError: true);
      return;
    }
    if (newPin == _globalStoredPin) {
      _showSnack(
        c,
        'New PIN must be different from current PIN.',
        isError: true,
      );
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() => _loadingUpdate = true);
    await Future.delayed(const Duration(milliseconds: 600));
    if (mounted) {
      setState(() {
        _loadingUpdate = false;
        _globalStoredPin = newPin;
        _currentPinUpdateCtrl.clear();
        _newPinUpdateCtrl.clear();
        _confirmPinUpdateCtrl.clear();
      });
      _showSnack(c, 'Payments PIN updated successfully.');
    }
  }

  void _forgotPin() {
    final c = widget.colors;
    final profile = UserProfileRepository.instance.profile;
    final email =
        profile.email.isNotEmpty ? profile.email : 'kherool66@gmail.com';

    HapticFeedback.lightImpact();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: c.border, width: 1.2),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: c.aqua.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.mark_email_read_outlined,
                size: 20,
                color: c.aqua,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Forgot Payments PIN?',
                style: TextStyle(
                  fontSize: 16.5,
                  fontWeight: FontWeight.w800,
                  color: c.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'We will dispatch a secure temporary PIN code to your registered email address:',
              style: TextStyle(
                fontSize: 13,
                color: c.textSecondary,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: c.cardDark,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: c.border, width: 1),
              ),
              child: Text(
                email,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: c.aqua,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Use the temporary PIN in the "CURRENT PIN" field to set your new PIN.',
              style: TextStyle(
                fontSize: 12,
                color: c.textMuted,
                height: 1.4,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: c.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: c.primaryButton,
              foregroundColor: c.primaryButtonText,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              HapticFeedback.mediumImpact();
              // Assign temporary PIN code for recovery
              _globalStoredPin = '1234';
              _showSnack(
                c,
                'Temporary PIN (1234) sent to $email. Enter it in CURRENT PIN.',
              );
            },
            child: const Text(
              'Send Reset Email',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  void _removePin() async {
    final c = widget.colors;
    final current = _currentPinRemoveCtrl.text.trim();

    if (current.isEmpty) {
      _showSnack(
        c,
        'Please enter your current PIN to remove protection.',
        isError: true,
      );
      return;
    }
    if (current != _globalStoredPin) {
      _showSnack(
        c,
        'Incorrect current PIN. Please enter your correct previous PIN to remove.',
        isError: true,
      );
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() => _loadingRemove = true);
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) {
      setState(() {
        _loadingRemove = false;
        _globalStoredPin = null;
        _currentPinRemoveCtrl.clear();
      });
      _showSnack(
        c,
        'PIN removed successfully. Your payments page is now open.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.colors;
    final pad = widget.isMobile ? 16.0 : 32.0;

    return SingleChildScrollView(
      padding: EdgeInsets.all(pad),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(c, 'Payments PIN', ''),
          const SizedBox(height: 8),
          Text(
            'Lock your My Payments page behind a PIN so your transactions aren\'t visible to anyone who opens your screen. The PIN is asked for once per browser — sign in from a new browser or device and it stays locked until you enter the PIN. Use the Lock button on the page to re-lock at any time.',
            style: TextStyle(
              fontSize: 13,
              color: c.textSecondary,
              height: 1.55,
            ),
          ),
          const SizedBox(height: 20),

          if (!_pinIsSet) ...[
            // ── Form when NO PIN is set ──────────────────────────────────
            _SettingsCard(
              colors: c,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status banner
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: c.statusPendingBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: c.statusPendingDot.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.lock_open_rounded,
                          size: 16,
                          color: c.statusPendingText,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'No PIN set — your payments page is open.',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: c.statusPendingText,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  _fieldRow(
                    isMobile: widget.isMobile,
                    left: _pinInputField(
                      c,
                      label: 'PIN',
                      controller: _initialPinCtrl,
                      hintText: '4–8 digits',
                    ),
                    right: _pinInputField(
                      c,
                      label: 'CONFIRM PIN',
                      controller: _initialConfirmPinCtrl,
                      hintText: 'Re-enter PIN',
                    ),
                  ),
                  const SizedBox(height: 20),
                  Align(
                    alignment: Alignment.centerRight,
                    child: _SettingsButton(
                      colors: c,
                      label: 'Set PIN',
                      icon: Icons.lock_rounded,
                      loading: _loadingSet,
                      onTap: _setInitialPin,
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            // ── Card 1: When PIN is set (Update PIN) ─────────────────────
            _SettingsCard(
              colors: c,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status indicator (matching screenshot)
                  Row(
                    children: [
                      Icon(
                        Icons.shield_outlined,
                        size: 16,
                        color: c.aqua,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'A PIN is currently set.',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: c.aqua,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  _pinInputField(
                    c,
                    label: 'CURRENT PIN',
                    controller: _currentPinUpdateCtrl,
                    hintText: 'Required to change PIN',
                  ),
                  const SizedBox(height: 16),

                  _fieldRow(
                    isMobile: widget.isMobile,
                    left: _pinInputField(
                      c,
                      label: 'NEW PIN',
                      controller: _newPinUpdateCtrl,
                      hintText: '4–8 digits',
                    ),
                    right: _pinInputField(
                      c,
                      label: 'CONFIRM PIN',
                      controller: _confirmPinUpdateCtrl,
                      hintText: 'Re-enter PIN',
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Bottom action row: Forgot link on left, Update PIN button on right
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      GestureDetector(
                        onTap: _forgotPin,
                        child: Text(
                          'Forgot PIN? Email me a new one',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: c.aqua,
                            decoration: TextDecoration.underline,
                            decorationColor: c.aqua.withValues(alpha: 0.6),
                          ),
                        ),
                      ),
                      _SettingsButton(
                        colors: c,
                        label: 'Update PIN',
                        icon: Icons.lock_rounded,
                        loading: _loadingUpdate,
                        onTap: _updatePin,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 4),

            // ── Card 2: Remove PIN ────────────────────────────────────────
            _SettingsCard(
              colors: c,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Remove PIN',
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                      color: c.textPrimary,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Removing the PIN makes your payments page open again on every device.',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: c.textSecondary,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 16),

                  _pinInputField(
                    c,
                    label: 'CURRENT PIN',
                    controller: _currentPinRemoveCtrl,
                    hintText: 'Enter current PIN',
                  ),
                  const SizedBox(height: 20),

                  Align(
                    alignment: Alignment.centerRight,
                    child: _SettingsButton(
                      colors: c,
                      label: 'Remove PIN',
                      icon: Icons.delete_outline_rounded,
                      loading: _loadingRemove,
                      onTap: _removePin,
                      isDestructive: true,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _pinInputField(
    PaidiXColorScheme c, {
    required String label,
    required TextEditingController controller,
    String hintText = '4–8 digits',
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.1,
            color: c.textLabel,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: c.inputFill,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: c.border, width: 1.2),
          ),
          child: TextField(
            controller: controller,
            obscureText: !_showPin,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(8),
            ],
            style: TextStyle(
              fontSize: 16,
              color: c.textPrimary,
              fontWeight: FontWeight.w700,
              letterSpacing: 3,
            ),
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: TextStyle(
                color: c.textPlaceholder,
                fontSize: 13,
                letterSpacing: 0,
                fontWeight: FontWeight.w400,
              ),
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              suffixIcon: GestureDetector(
                onTap: () => setState(() => _showPin = !_showPin),
                child: Icon(
                  _showPin
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: 18,
                  color: c.textMuted,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  APPEARANCE SECTION
// ════════════════════════════════════════════════════════════════════════════
class _AppearanceSection extends StatefulWidget {
  final PaidiXColorScheme colors;
  final bool isMobile;

  const _AppearanceSection({required this.colors, required this.isMobile});

  @override
  State<_AppearanceSection> createState() => _AppearanceSectionState();
}

class _AppearanceSectionState extends State<_AppearanceSection> {
  ThemeMode _selectedMode = AppTheme.themeModeNotifier.value;
  int _selectedFont = 0;
  double _textScale = 100.0;

  static const _fonts = AppTheme.availableFonts;

  @override
  void initState() {
    super.initState();
    _selectedMode = AppTheme.currentThemeMode;
    final idx = _fonts.indexOf(AppTheme.currentFontFamily);
    _selectedFont = idx != -1 ? idx : 0;
    _textScale = (AppTheme.currentTextScale * 100.0).clamp(80.0, 140.0);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _selectedMode = AppTheme.currentThemeMode;
    final idx = _fonts.indexOf(AppTheme.currentFontFamily);
    if (idx != -1 && idx != _selectedFont) {
      _selectedFont = idx;
    }
    _textScale = (AppTheme.currentTextScale * 100.0).clamp(80.0, 140.0);
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.colors;
    final pad = widget.isMobile ? 16.0 : 32.0;

    return SingleChildScrollView(
      padding: EdgeInsets.all(pad),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(c, 'Appearance', 'Personalise how PaidiX looks for you.'),
          const SizedBox(height: 20),

          // Theme picker
          _SettingsCard(
            colors: c,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _cardSectionLabel(c, 'THEME'),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                        child: _themeCard(c, ThemeMode.dark, 'Dark',
                            Icons.dark_mode_rounded)),
                    const SizedBox(width: 10),
                    Expanded(
                        child: _themeCard(c, ThemeMode.light, 'Light',
                            Icons.light_mode_rounded)),
                    const SizedBox(width: 10),
                    Expanded(
                        child: _themeCard(c, ThemeMode.system, 'System',
                            Icons.phone_android_rounded)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Typography card
          _SettingsCard(
            colors: c,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _cardSectionLabel(c, 'TYPOGRAPHY'),
                const SizedBox(height: 14),
                // Font grid
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _fonts.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: widget.isMobile ? 2 : 3,
                    childAspectRatio: widget.isMobile ? 2.2 : 2.6,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemBuilder: (_, i) {
                    final isSelected = _selectedFont == i;
                    return GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _selectedFont = i);
                        AppTheme.setFontFamily(_fonts[i]);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOutCubic,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? c.aqua.withValues(alpha: 0.12)
                              : c.cardDark,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected
                                ? c.aqua
                                : c.border,
                            width: isSelected ? 1.5 : 1,
                          ),
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Aa Bb Cc',
                                style: AppTheme.getFontStyle(
                                  _fonts[i],
                                  baseStyle: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: isSelected ? c.aqua : c.textPrimary,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _fonts[i],
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                  color: isSelected
                                      ? c.aqua.withValues(alpha: 0.85)
                                      : c.textMuted,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),

                // Text size slider
                _cardSectionLabel(c, 'TEXT SIZE'),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Text(
                      '80%',
                      style: TextStyle(fontSize: 11, color: c.textMuted),
                    ),
                    Expanded(
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 3,
                          thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 8),
                          overlayShape:
                              const RoundSliderOverlayShape(overlayRadius: 16),
                          activeTrackColor: c.aqua,
                          inactiveTrackColor: c.border,
                          thumbColor: c.aqua,
                          overlayColor: c.aqua.withValues(alpha: 0.15),
                        ),
                        child: Slider(
                          value: _textScale,
                          min: 80,
                          max: 140,
                          divisions: 12,
                          onChanged: (v) {
                            setState(() => _textScale = v);
                            AppTheme.setTextScale(v / 100.0);
                          },
                        ),
                      ),
                    ),
                    Text(
                      '140%',
                      style: TextStyle(fontSize: 11, color: c.textMuted),
                    ),
                  ],
                ),
                // Live preview
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: c.cardDark,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: c.border, width: 1),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Send USD, receive PKR.',
                      style: AppTheme.getFontStyle(
                        _fonts[_selectedFont],
                        baseStyle: TextStyle(
                          fontSize: (14 * _textScale / 100).clamp(9.0, 22.0),
                          fontWeight: FontWeight.w600,
                          color: c.textPrimary,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Reset + current scale indicator
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    Text(
                      '${_textScale.round()}%',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: c.aqua,
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() {
                          _selectedFont = 0;
                          _textScale = 100.0;
                          _selectedMode = ThemeMode.light;
                        });
                        AppTheme.setThemeMode(ThemeMode.light);
                        AppTheme.setFontFamily('System default');
                        AppTheme.setTextScale(1.0);
                      },
                      child: Text(
                        'Reset to defaults',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: c.textSecondary,
                          decoration: TextDecoration.underline,
                          decorationColor: c.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _themeCard(
      PaidiXColorScheme c, ThemeMode mode, String label, IconData icon) {
    final isSelected = _selectedMode == mode;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _selectedMode = mode);
        if (mode != ThemeMode.system) {
          AppTheme.setThemeMode(mode);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        decoration: BoxDecoration(
          color: isSelected ? c.aqua.withValues(alpha: 0.12) : c.cardDark,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? c.aqua : c.border,
            width: isSelected ? 1.8 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 20,
                color: isSelected ? c.aqua : c.textMuted),
            const SizedBox(height: 5),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? c.aqua : c.textSecondary,
                ),
              ),
            ),
            if (isSelected) ...[
              const SizedBox(height: 3),
              Icon(Icons.check_circle_rounded, size: 13, color: c.aqua),
            ],
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  BANK ACCOUNTS SECTION
// ════════════════════════════════════════════════════════════════════════════
class _BankAccountsSection extends StatefulWidget {
  final PaidiXColorScheme colors;
  final UserProfile profile;
  final bool isMobile;

  const _BankAccountsSection({
    required this.colors,
    required this.profile,
    required this.isMobile,
  });

  @override
  State<_BankAccountsSection> createState() => _BankAccountsSectionState();
}

class _BankAccountsSectionState extends State<_BankAccountsSection> {
  late List<BankAccountItem> _accounts;

  @override
  void initState() {
    super.initState();
    _accounts = UserProfileRepository.instance
        .getBankAccountsSync(widget.profile.email);
    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    final list = await UserProfileRepository.instance
        .loadBankAccounts(widget.profile.email);
    if (mounted) {
      setState(() {
        _accounts = list;
      });
    }
  }

  Future<void> _persistAccounts() async {
    await UserProfileRepository.instance
        .saveBankAccounts(widget.profile.email, _accounts);
  }

  void _confirmRemoveAccount(BuildContext context, int index) {
    HapticFeedback.mediumImpact();
    final c = widget.colors;
    final acc = _accounts[index];

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.65),
      builder: (ctx) => AlertDialog(
        backgroundColor: c.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: c.border, width: 1),
        ),
        title: Text(
          'Remove bank account',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: c.textPrimary,
            letterSpacing: -0.2,
          ),
        ),
        content: Text(
          'Are you sure you want to remove your ${acc.bankName} account ending in ${acc.last4}? This action cannot be undone.',
          style: TextStyle(
            fontSize: 13.5,
            color: c.textSecondary,
            height: 1.45,
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: c.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: c.borderError,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 0,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _removeAccount(index);
            },
            child: const Text(
              'Remove',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  void _removeAccount(int index) {
    HapticFeedback.heavyImpact();
    setState(() {
      final removed = _accounts.removeAt(index);
      if (removed.isPrimary && _accounts.isNotEmpty) {
        _accounts[0] = _accounts[0].copyWith(isPrimary: true);
      }
    });
    _persistAccounts();
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Bank account removed.'),
        backgroundColor: widget.colors.borderError,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _setAsPrimary(int index) {
    HapticFeedback.lightImpact();
    setState(() {
      for (int i = 0; i < _accounts.length; i++) {
        _accounts[i] = _accounts[i].copyWith(isPrimary: i == index);
      }
    });
    _persistAccounts();
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${_accounts[index].bankName} set as primary account.'),
        backgroundColor: widget.colors.statusCompletedDot,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _openAddAccountDialog(BuildContext context) {
    HapticFeedback.lightImpact();
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.65),
      builder: (ctx) => _BankDetailsDialog(
        colors: widget.colors,
        isMobile: widget.isMobile,
        isEditing: false,
        onSave: (newAcc) {
          setState(() {
            if (_accounts.isEmpty) {
              _accounts.add(newAcc.copyWith(isPrimary: true));
            } else {
              _accounts.add(newAcc);
            }
          });
          _persistAccounts();
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Bank account added successfully.'),
              backgroundColor: widget.colors.statusCompletedDot,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              margin: const EdgeInsets.all(16),
              duration: const Duration(seconds: 2),
            ),
          );
        },
      ),
    );
  }

  void _openEditAccountDialog(BuildContext context, int index) {
    HapticFeedback.lightImpact();
    final acc = _accounts[index];
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.65),
      builder: (ctx) => _BankDetailsDialog(
        colors: widget.colors,
        isMobile: widget.isMobile,
        isEditing: true,
        initialAccount: acc,
        onSave: (updatedAcc) {
          setState(() {
            _accounts[index] = updatedAcc;
          });
          _persistAccounts();
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Bank account updated successfully.'),
              backgroundColor: widget.colors.statusCompletedDot,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              margin: const EdgeInsets.all(16),
              duration: const Duration(seconds: 2),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.colors;
    final pad = widget.isMobile ? 16.0 : 32.0;

    return SingleChildScrollView(
      padding: EdgeInsets.all(pad),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(
            c,
            'Bank accounts.',
            'Pakistani bank accounts where PKR will be transferred to you.',
            eyebrow: 'ACCOUNTS',
          ),
          const SizedBox(height: 20),

          // Security & Audit notice banner (matching Screenshot 1)
          Container(
            padding: const EdgeInsets.all(14),
            margin: const EdgeInsets.only(bottom: 22),
            decoration: BoxDecoration(
              color: c.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: c.aqua.withValues(alpha: 0.25),
                width: 1,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: c.aqua.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.payments_outlined,
                    size: 20,
                    color: c.aqua,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "All additions, edits and removals on this page are logged and shared with our support team for your protection. You can set any account as your primary — the one we'll use by default when sending PKR.",
                    style: TextStyle(
                      fontSize: 12.5,
                      color: c.textSecondary,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Section header row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'PKR RECEIVING (PAKISTAN)',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                    color: c.textLabel,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              SpongyTap(
                onTap: () => _openAddAccountDialog(context),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: c.aqua.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: c.aqua.withValues(alpha: 0.35),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add_circle_outline_rounded,
                          size: 15, color: c.aqua),
                      const SizedBox(width: 6),
                      Text(
                        'Add account',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: c.aqua,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (_accounts.isEmpty)
            _SettingsCard(
              colors: c,
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.account_balance_outlined,
                          size: 38, color: c.textMuted),
                      const SizedBox(height: 12),
                      Text(
                        'No bank accounts linked.',
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: c.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Add a PKR receiving account to receive payouts.',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: c.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              )
          else
            ...List.generate(
              _accounts.length,
              (i) => _buildAccountCard(c, i),
            ),
        ],
      ),
    );
  }

  Widget _buildAccountCard(PaidiXColorScheme c, int i) {
    final acc = _accounts[i];

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.all(widget.isMobile ? 16 : 22),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: acc.isPrimary
              ? c.aqua.withValues(alpha: 0.45)
              : c.border,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: c.brightness == Brightness.dark ? 0.2 : 0.06,
            ),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: Bank name uppercase & Primary badge / Set as primary
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  acc.bankName.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: c.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              if (acc.isPrimary)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                  decoration: BoxDecoration(
                    color: c.aqua.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: c.aqua.withValues(alpha: 0.35),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.star_outline_rounded,
                          size: 13, color: c.aqua),
                      const SizedBox(width: 4),
                      Text(
                        'Primary',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: c.aqua,
                        ),
                      ),
                    ],
                  ),
                )
              else
                SpongyTap(
                  onTap: () => _setAsPrimary(i),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                    decoration: BoxDecoration(
                      color: c.cardDark,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: c.border, width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.star_outline_rounded,
                            size: 13, color: c.textMuted),
                        const SizedBox(width: 4),
                        Text(
                          'Set as primary',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: c.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),

          // Account holder name (prominent)
          Text(
            acc.holder,
            style: TextStyle(
              fontSize: widget.isMobile ? 19 : 21,
              fontWeight: FontWeight.w800,
              color: c.textPrimary,
              letterSpacing: -0.3,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),

          // Masked account number: •••• •••• 2786
          Text(
            acc.maskedDisplay,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.5,
              color: c.textSecondary,
            ),
          ),
          const SizedBox(height: 14),

          // Horizontal Divider
          Divider(
            color: c.border.withValues(alpha: 0.6),
            height: 1,
            thickness: 1,
          ),
          const SizedBox(height: 12),

          // Bottom Action Row: Edit and Remove
          Row(
            children: [
              SpongyTap(
                onTap: () => _openEditAccountDialog(context, i),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.edit_outlined,
                          size: 15, color: c.textPrimary),
                      const SizedBox(width: 6),
                      Text(
                        'Edit',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: c.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 24),
              SpongyTap(
                onTap: () => _confirmRemoveAccount(context, i),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.delete_outline_rounded,
                          size: 15, color: const Color(0xFFF87171)),
                      const SizedBox(width: 6),
                      Text(
                        'Remove',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFF87171),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Bank Account Edit & Add Modal Dialog (Matching Screenshot 2) ─────────────
class _BankDetailsDialog extends StatefulWidget {
  final PaidiXColorScheme colors;
  final bool isMobile;
  final bool isEditing;
  final BankAccountItem? initialAccount;
  final void Function(BankAccountItem) onSave;

  const _BankDetailsDialog({
    required this.colors,
    required this.isMobile,
    required this.isEditing,
    this.initialAccount,
    required this.onSave,
  });

  @override
  State<_BankDetailsDialog> createState() => _BankDetailsDialogState();
}

class _BankDetailsDialogState extends State<_BankDetailsDialog> {
  late String _selectedBank;
  late final TextEditingController _holderCtrl;
  late final TextEditingController _accountNumberCtrl;
  late final TextEditingController _ibanCtrl;

  @override
  void initState() {
    super.initState();
    final init = widget.initialAccount;
    _selectedBank = init?.bankName ?? 'JazzCash (Mobilink Microfinance Bank)';
    _holderCtrl = TextEditingController(text: init?.holder ?? '');
    _accountNumberCtrl =
        TextEditingController(text: init?.accountNumber ?? '');
    _ibanCtrl = TextEditingController(text: init?.iban ?? '');
  }

  @override
  void dispose() {
    _holderCtrl.dispose();
    _accountNumberCtrl.dispose();
    _ibanCtrl.dispose();
    super.dispose();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: widget.colors.borderError,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _submit() {
    final holder = _holderCtrl.text.trim();
    if (holder.isEmpty) {
      _showError('Account holder name is required.');
      return;
    }
    // Letters, spaces, dots, hyphens only
    if (!RegExp(r"^[a-zA-Z\s\.\-']+$").hasMatch(holder)) {
      _showError(
          'Account holder must contain letters only (numbers and symbols are not allowed).');
      return;
    }

    final accNum = _accountNumberCtrl.text.trim();
    if (accNum.isEmpty) {
      _showError('Account number is required.');
      return;
    }
    final digitsOnly = accNum.replaceAll(RegExp(r'[\s\-]'), '');
    if (!RegExp(r'^[0-9]+$').hasMatch(digitsOnly)) {
      _showError(
          'Account number must contain digits only (letters are not allowed).');
      return;
    }
    if (digitsOnly.length < 8) {
      _showError('Account number must be at least 8 digits.');
      return;
    }

    final saved = BankAccountItem(
      id: widget.initialAccount?.id ??
          'bank_${DateTime.now().millisecondsSinceEpoch}',
      bankName: _selectedBank,
      holder: holder,
      accountNumber: accNum,
      iban: _ibanCtrl.text.trim(),
      isPrimary: widget.initialAccount?.isPrimary ?? false,
    );

    widget.onSave(saved);
    Navigator.pop(context);
  }

  void _openBankSelector() {
    HapticFeedback.lightImpact();
    final c = widget.colors;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (pickerCtx) {
        String searchQuery = '';
        return StatefulBuilder(
          builder: (context, setPickerState) {
            final filtered = kPakistaniBanks
                .where((b) =>
                    b.toLowerCase().contains(searchQuery.toLowerCase()))
                .toList();

            return Material(
              color: c.card,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
              clipBehavior: Clip.antiAlias,
              child: Container(
                height: MediaQuery.of(context).size.height * 0.7,
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: c.border, width: 1)),
                ),
                child: Column(
                  children: [
                  const SizedBox(height: 12),
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: c.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Select Bank',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: c.textPrimary,
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close_rounded,
                              size: 20, color: c.textMuted),
                          onPressed: () => Navigator.pop(pickerCtx),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      height: 42,
                      decoration: BoxDecoration(
                        color: c.inputFill,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: c.border),
                      ),
                      child: TextField(
                        onChanged: (val) {
                          setPickerState(() => searchQuery = val);
                        },
                        style: TextStyle(fontSize: 13, color: c.textPrimary),
                        decoration: InputDecoration(
                          hintText: 'Search Pakistani bank or wallet...',
                          hintStyle: TextStyle(
                              color: c.textPlaceholder, fontSize: 13),
                          prefixIcon: Icon(Icons.search_rounded,
                              size: 18, color: c.textMuted),
                          border: InputBorder.none,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => Divider(
                          color: c.border.withValues(alpha: 0.4), height: 1),
                      itemBuilder: (context, idx) {
                        final bank = filtered[idx];
                        final isSelected = bank == _selectedBank;
                        return ListTile(
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 8),
                          leading: Icon(
                            bank.contains('JazzCash') ||
                                    bank.contains('EasyPaisa') ||
                                    bank.contains('SadaPay') ||
                                    bank.contains('NayaPay')
                                ? Icons.phone_android_rounded
                                : Icons.account_balance_rounded,
                            size: 20,
                            color: isSelected ? c.aqua : c.textMuted,
                          ),
                          title: Text(
                            bank,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: isSelected ? c.aqua : c.textPrimary,
                            ),
                          ),
                          trailing: isSelected
                              ? Icon(Icons.check_circle_rounded,
                                  size: 18, color: c.aqua)
                              : null,
                          onTap: () {
                            setState(() => _selectedBank = bank);
                            Navigator.pop(pickerCtx);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.colors;
    final isEditing = widget.isEditing;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: 480,
          maxHeight: MediaQuery.of(context).size.height * 0.92,
        ),
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.border, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.45),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            22,
            20,
            22,
            MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with Title and Close Button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      isEditing
                          ? 'Edit Pakistani bank account'
                          : 'Add Pakistani bank account',
                      style: TextStyle(
                        fontSize: 17.5,
                        fontWeight: FontWeight.w800,
                        color: c.textPrimary,
                        letterSpacing: -0.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded,
                        size: 20, color: c.textMuted),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Notice Box matching Screenshot 2
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: c.cardDark,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: c.border, width: 1),
                ),
                child: Text(
                  'Any changes you make here will be logged and shared with the support team — both the previous values and the new ones.',
                  style: TextStyle(
                    fontSize: 12,
                    color: c.textSecondary,
                    height: 1.45,
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // BANK Dropdown
              Text(
                'BANK',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                  color: c.textLabel,
                ),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _openBankSelector,
                child: Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: c.inputFill,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: c.border, width: 1.2),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _selectedBank,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w500,
                            color: c.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 20,
                        color: c.textSecondary,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ACCOUNT HOLDER *
              Text(
                'ACCOUNT HOLDER *',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                  color: c.textLabel,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: c.inputFill,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: c.border, width: 1.2),
                ),
                child: TextField(
                  controller: _holderCtrl,
                  style: TextStyle(
                    fontSize: 14,
                    color: c.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    hintText: 'e.g. Abdullah Azeem',
                    hintStyle: TextStyle(
                      color: c.textPlaceholder,
                      fontSize: 13.5,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 13,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Letters only — numbers and symbols are not allowed',
                style: TextStyle(
                  fontSize: 11.5,
                  color: c.textMuted,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 16),

              // ACCOUNT NUMBER *
              Text(
                'ACCOUNT NUMBER *',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                  color: c.textLabel,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: c.inputFill,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: c.border, width: 1.2),
                ),
                child: TextField(
                  controller: _accountNumberCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  style: TextStyle(
                    fontSize: 14,
                    color: c.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    hintText: 'e.g. 03225352786',
                    hintStyle: TextStyle(
                      color: c.textPlaceholder,
                      fontSize: 13.5,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 13,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Digits only — letters are not allowed',
                style: TextStyle(
                  fontSize: 11.5,
                  color: c.textMuted,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 16),

              // IBAN (OPTIONAL)
              Text(
                'IBAN (OPTIONAL)',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                  color: c.textLabel,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: c.inputFill,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: c.border, width: 1.2),
                ),
                child: TextField(
                  controller: _ibanCtrl,
                  textCapitalization: TextCapitalization.characters,
                  style: TextStyle(
                    fontSize: 14,
                    color: c.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    hintText: 'PK00 XXXX 0000 0000 0000 0000',
                    hintStyle: TextStyle(
                      color: c.textPlaceholder,
                      fontSize: 13.5,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 13,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Bottom Actions: Cancel & Submit (Wrap prevents any overflow)
              Align(
                alignment: Alignment.centerRight,
                child: Wrap(
                  alignment: WrapAlignment.end,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: c.textSecondary,
                        ),
                      ),
                    ),
                    SpongyTap(
                      onTap: _submit,
                      child: Container(
                        height: 44,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        decoration: BoxDecoration(
                          color: c.primaryButton,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          isEditing ? 'Save changes' : 'Add account',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: c.primaryButtonText,
                          ),
                        ),
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
}


// ════════════════════════════════════════════════════════════════════════════
//  SHARED HELPERS & WIDGETS
// ════════════════════════════════════════════════════════════════════════════

Widget _sectionHeader(PaidiXColorScheme c, String title, String subtitle,
    {String? eyebrow}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (eyebrow != null && eyebrow.isNotEmpty) ...[
        Text(
          eyebrow,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.4,
            color: c.gold,
          ),
        ),
        const SizedBox(height: 6),
      ],
      Text(
        title,
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
          color: c.textPrimary,
        ),
      ),
      if (subtitle.isNotEmpty) ...[
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 13.5,
            color: c.textSecondary,
            height: 1.4,
          ),
        ),
      ],
    ],
  );
}

Widget _cardSectionLabel(PaidiXColorScheme c, String label) {
  return Text(
    label,
    style: TextStyle(
      fontSize: 10.5,
      fontWeight: FontWeight.w800,
      letterSpacing: 1.2,
      color: c.textLabel,
    ),
  );
}

Widget _labeledField(
  PaidiXColorScheme c, {
  required String label,
  required TextEditingController controller,
  String? hint,
  Widget? prefix,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
          color: c.textLabel,
        ),
      ),
      const SizedBox(height: 8),
      Container(
        decoration: BoxDecoration(
          color: c.inputFill,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: c.border, width: 1.2),
        ),
        child: Row(
          children: [
            if (prefix != null) ...[
              Padding(
                padding: const EdgeInsets.only(left: 14),
                child: prefix,
              ),
              Container(
                  width: 1,
                  height: 20,
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  color: c.border),
            ],
            Expanded(
              child: TextField(
                controller: controller,
                style: TextStyle(
                  fontSize: 14,
                  color: c.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
                decoration: InputDecoration(
                  hintText: hint,
                  hintStyle:
                      TextStyle(color: c.textPlaceholder, fontSize: 13.5),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: prefix != null ? 0 : 14,
                    vertical: 13,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

Widget _fieldRow({
  required bool isMobile,
  required Widget left,
  required Widget right,
}) {
  if (isMobile) {
    return Column(
      children: [
        left,
        const SizedBox(height: 14),
        right,
      ],
    );
  }
  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(child: left),
      const SizedBox(width: 16),
      Expanded(child: right),
    ],
  );
}

// ── Reusable settings card wrapper ───────────────────────────────────────────
class _SettingsCard extends StatelessWidget {
  final PaidiXColorScheme colors;
  final Widget child;
  final EdgeInsetsGeometry? padding;

  const _SettingsCard({
    required this.colors,
    required this.child,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final isNarrow = MediaQuery.of(context).size.width < 380;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: padding ?? EdgeInsets.all(isNarrow ? 14 : 20),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
                alpha:
                    colors.brightness == Brightness.dark ? 0.18 : 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

// ── Animated Settings Button ─────────────────────────────────────────────────
class _SettingsButton extends StatefulWidget {
  final PaidiXColorScheme colors;
  final String label;
  final IconData icon;
  final bool loading;
  final VoidCallback onTap;
  final bool isDestructive;

  const _SettingsButton({
    required this.colors,
    required this.label,
    required this.icon,
    required this.loading,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  State<_SettingsButton> createState() => _SettingsButtonState();
}

class _SettingsButtonState extends State<_SettingsButton>
    with SingleTickerProviderStateMixin {
  bool _pressed = false;
  late final AnimationController _scaleCtrl;

  @override
  void initState() {
    super.initState();
    _scaleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 80),
      lowerBound: 0.93,
      upperBound: 1.0,
      value: 1.0,
    );
  }

  @override
  void dispose() {
    _scaleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.colors;
    final bg = widget.isDestructive
        ? (c.brightness == Brightness.dark
            ? const Color(0xFF1B1417)
            : const Color(0xFFFDE8EC))
        : c.primaryButton;
    final fg = widget.isDestructive ? c.borderError : c.primaryButtonText;
    final border = widget.isDestructive
        ? Border.all(
            color: c.borderError.withValues(alpha: 0.45),
            width: 1.2,
          )
        : null;

    return GestureDetector(
      onTapDown: (_) {
        setState(() => _pressed = true);
        _scaleCtrl.reverse();
      },
      onTapUp: (_) {
        setState(() => _pressed = false);
        _scaleCtrl.forward().then((_) => widget.onTap());
      },
      onTapCancel: () {
        setState(() => _pressed = false);
        _scaleCtrl.forward();
      },
      child: ScaleTransition(
        scale: _scaleCtrl,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          decoration: BoxDecoration(
            color: _pressed ? bg.withValues(alpha: 0.8) : bg,
            borderRadius: BorderRadius.circular(12),
            border: border,
          ),
          child: widget.loading
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: fg,
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(widget.icon, size: 16, color: fg),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        widget.label,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: fg,
                          letterSpacing: -0.1,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}


