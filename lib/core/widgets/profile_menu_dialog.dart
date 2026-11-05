/// Defines profile menu dialog in the application core utilities and reusable widgets.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_theme.dart';
import '../../features/profile/data/user_profile_repository.dart';
import '../../features/profile/domain/user_profile.dart';

/// Small popup dialog matching PaidiX design when user taps profile avatar.
/// Displays user info header and options: 'Account Settings', 'Theme Changer', and 'Logout'.
class ProfileMenuDialog extends StatelessWidget {
  final UserProfile userProfile;
  final bool isMobile;

  const ProfileMenuDialog({
    super.key,
    required this.userProfile,
    this.isMobile = true,
  });

  /// Displays the profile menu anchored near top-right on mobile or bottom-left on desktop.
  static Future<void> show({
    required BuildContext context,
    required UserProfile userProfile,
    bool isMobile = true,
  }) {
    HapticFeedback.selectionClick();

    return showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss Profile Menu',
      barrierColor: Colors.black.withValues(alpha: 0.32),
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (ctx, anim1, anim2) {
        return ProfileMenuDialog(
          userProfile: userProfile,
          isMobile: isMobile,
        );
      },
      transitionBuilder: (ctx, anim1, anim2, child) {
        final curve = CurvedAnimation(
          parent: anim1,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curve,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.92, end: 1.0).animate(curve),
            alignment: isMobile ? Alignment.topRight : Alignment.bottomLeft,
            child: child,
          ),
        );
      },
    );
  }

  /// Builds the widget subtree from its current properties and inherited context.
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppTheme.themeModeNotifier,
      builder: (context, themeMode, _) {
        final colors = AppColors.of(context);
        final isDark = themeMode == ThemeMode.dark ||
            (themeMode == ThemeMode.system &&
                MediaQuery.platformBrightnessOf(context) == Brightness.dark);

        final alignment = isMobile ? Alignment.topRight : Alignment.bottomLeft;
        final topMargin = isMobile
            ? (MediaQuery.of(context).padding.top + kToolbarHeight + 4)
            : 0.0;
        final rightMargin = isMobile ? 14.0 : 0.0;
        final bottomMargin = isMobile ? 0.0 : 76.0;
        final leftMargin = isMobile ? 0.0 : 14.0;

        return SafeArea(
          child: Align(
            alignment: alignment,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeInOutCubic,
              width: 250,
              margin: EdgeInsets.only(
                top: topMargin,
                right: rightMargin,
                bottom: bottomMargin,
                left: leftMargin,
              ),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF072120) : colors.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark
                      ? colors.borderFocused.withValues(alpha: 0.45)
                      : colors.border,
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.16),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // User Details Header (Name and Email)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            userProfile.fullName,
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              color: colors.textPrimary,
                              letterSpacing: -0.2,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            userProfile.email,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                              color: colors.textSecondary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),

                    // Separator
                    Divider(
                      height: 1,
                      thickness: 1,
                      color: colors.border.withValues(alpha: isDark ? 0.6 : 0.8),
                    ),

                    // Option 1: Account Settings
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 4),
                      child: _MenuOptionTile(
                        icon: Icons.settings_outlined,
                        label: 'Account Settings',
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Navigator.of(context).pop();
                          context.go('/app/settings');
                        },
                      ),
                    ),

                    // Separator
                    Divider(
                      height: 1,
                      thickness: 1,
                      color: colors.border.withValues(alpha: isDark ? 0.6 : 0.8),
                    ),

                    // Option 2: Theme Changer with smooth transition & switch
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 4),
                      child: _MenuThemeOptionTile(
                        isDark: isDark,
                        onToggle: () {
                          HapticFeedback.mediumImpact();
                          AppTheme.toggleTheme();
                        },
                      ),
                    ),

                    // Separator
                    Divider(
                      height: 1,
                      thickness: 1,
                      color: colors.border.withValues(alpha: isDark ? 0.6 : 0.8),
                    ),

                    // Option 3: Logout / Sign out
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 4),
                      child: _MenuOptionTile(
                        icon: Icons.logout_rounded,
                        label: 'Logout',
                        isDestructive: true,
                        onTap: () {
                          HapticFeedback.mediumImpact();
                          Navigator.of(context).pop();
                          // Execute logout logic: reset repository state and navigate to sign in
                          UserProfileRepository.instance.resetToDefault();
                          context.go('/signin');
                        },
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MenuThemeOptionTile extends StatefulWidget {
  final bool isDark;
  final VoidCallback onToggle;

  const _MenuThemeOptionTile({
    required this.isDark,
    required this.onToggle,
  });

  /// Creates the mutable state object that backs this stateful widget.
  @override
  State<_MenuThemeOptionTile> createState() => _MenuThemeOptionTileState();
}

class _MenuThemeOptionTileState extends State<_MenuThemeOptionTile> {
  bool _isHovered = false;
  bool _isPressed = false;

  /// Builds the widget subtree from its current properties and inherited context.
  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final isDark = widget.isDark;

    final hoverColor = colors.aqua.withValues(alpha: 0.10);
    final activeColor = colors.aqua.withValues(alpha: 0.18);
    final iconColor = _isHovered || _isPressed
        ? colors.aqua
        : (isDark ? colors.gold : colors.textSecondary);
    final textColor = _isHovered || _isPressed
        ? (isDark ? colors.aquaLight : colors.aqua)
        : colors.textPrimary;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: (_) {
          HapticFeedback.lightImpact();
          setState(() => _isPressed = true);
        },
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: widget.onToggle,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: _isPressed
                ? activeColor
                : (_isHovered ? hoverColor : Colors.transparent),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 280),
                transitionBuilder: (child, anim) => RotationTransition(
                  turns: anim,
                  child: FadeTransition(opacity: anim, child: child),
                ),
                child: Icon(
                  isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                  key: ValueKey<bool>(isDark),
                  size: 18,
                  color: iconColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  isDark ? 'Light Mode' : 'Dark Mode',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              // Smooth animated pill switch showing current theme state
              AnimatedContainer(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeInOutCubic,
                width: 38,
                height: 22,
                padding: const EdgeInsets.symmetric(horizontal: 2.5),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: isDark ? colors.aqua : colors.borderSubtle,
                ),
                alignment:
                    isDark ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  width: 17,
                  height: 17,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isDark ? const Color(0xFF021B19) : Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.18),
                        blurRadius: 3,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuOptionTile extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;

  const _MenuOptionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
  });

  /// Creates the mutable state object that backs this stateful widget.
  @override
  State<_MenuOptionTile> createState() => _MenuOptionTileState();
}

class _MenuOptionTileState extends State<_MenuOptionTile> {
  bool _isHovered = false;
  bool _isPressed = false;

  /// Builds the widget subtree from its current properties and inherited context.
  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final hoverColor = widget.isDestructive
        ? colors.ruby.withValues(alpha: 0.12)
        : colors.aqua.withValues(alpha: 0.10);

    final activeColor = widget.isDestructive
        ? colors.ruby.withValues(alpha: 0.20)
        : colors.aqua.withValues(alpha: 0.18);

    final iconColor = widget.isDestructive
        ? (_isHovered || _isPressed ? colors.ruby : colors.textSecondary)
        : (_isHovered || _isPressed ? colors.aqua : colors.textSecondary);

    final textColor = widget.isDestructive
        ? (_isHovered || _isPressed ? colors.ruby : colors.textPrimary)
        : (_isHovered || _isPressed
            ? (isDark ? colors.aquaLight : colors.aqua)
            : colors.textPrimary);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: (_) {
          HapticFeedback.lightImpact();
          setState(() => _isPressed = true);
        },
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: _isPressed
                ? activeColor
                : (_isHovered ? hoverColor : Colors.transparent),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                child: Icon(
                  widget.icon,
                  size: 18,
                  color: iconColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
