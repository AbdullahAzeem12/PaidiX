/// Defines app shell in the application core utilities and reusable widgets.

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_motion.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_theme.dart';
import '../../features/profile/data/user_profile_repository.dart';
import '../../features/profile/domain/user_profile.dart';
import '../services/session_timeout_service.dart';
import 'brand_logo.dart';
import 'paidi_x_bottom_nav_bar.dart';
import 'profile_menu_dialog.dart';

class AppShell extends StatefulWidget {
  final Widget child;
  final String currentPath;

  const AppShell({
    super.key,
    required this.child,
    required this.currentPath,
  });

  /// Creates the mutable state object that backs this stateful widget.
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  bool _isSidebarCollapsed = false;

  /// Initializes controllers, listeners, and other state owned by this widget.
  @override
  void initState() {
    super.initState();
    SessionTimeoutService.instance.startSession(context);
  }

  /// Synchronizes local state when the parent supplies updated widget properties.
  @override
  void didUpdateWidget(covariant AppShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentPath != oldWidget.currentPath) {
      SessionTimeoutService.instance.recordUserActivity();
    }
  }

  /// Releases resources owned by this object before it is removed.
  @override
  void dispose() {
    SessionTimeoutService.instance.stopSession();
    super.dispose();
  }

  /// Maps the current route to the selected navigation destination.
  int _calculateSelectedIndex(bool showOnboarding) {
    final p = widget.currentPath;
    if (showOnboarding) {
      if (p.startsWith('/app/payments/new')) return 3;
      if (p.startsWith('/app/payments')) return 2;
      if (p.startsWith('/app/onboarding')) return 1;
      return 0; // dashboard
    } else {
      if (p.startsWith('/app/payments/new')) return 2;
      if (p.startsWith('/app/payments')) return 1;
      return 0; // dashboard
    }
  }

  /// Navigates to the route represented by the selected app destination.
  void _onDestinationSelected(int index, bool showOnboarding) {
    if (showOnboarding) {
      switch (index) {
        case 0:
          context.go('/app/dashboard');
          break;
        case 1:
          context.go('/app/onboarding');
          break;
        case 2:
          context.go('/app/payments');
          break;
        case 3:
          context.go('/app/payments/new');
          break;
      }
    } else {
      switch (index) {
        case 0:
          context.go('/app/dashboard');
          break;
        case 1:
          context.go('/app/payments');
          break;
        case 2:
          context.go('/app/payments/new');
          break;
      }
    }
  }

  /// Builds the widget subtree from its current properties and inherited context.
  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => SessionTimeoutService.instance.recordUserActivity(),
      onPointerMove: (_) => SessionTimeoutService.instance.recordUserActivity(),
      onPointerHover: (_) => SessionTimeoutService.instance.recordUserActivity(),
      child: Focus(
        onKeyEvent: (node, event) {
          SessionTimeoutService.instance.recordUserActivity();
          return KeyEventResult.ignored;
        },
        child: ValueListenableBuilder<UserProfile>(
      valueListenable: UserProfileRepository.instance.profileNotifier,
      builder: (context, userProfile, _) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final isWide =
                constraints.maxWidth >= 768 && constraints.maxHeight >= 520;

            if (isWide) {
              return Scaffold(
                backgroundColor: colors.background,
                body: Row(
                  children: [
                    _buildSidebar(userProfile),
                    Expanded(
                      child: widget.child,
                    ),
                  ],
                ),
              );
            }

            // Mobile layout
            final showOnboarding =
                userProfile.kycStatus != KycReviewStatus.verified;
            final selectedIndex = _calculateSelectedIndex(showOnboarding);
            final isNarrowPhone = constraints.maxWidth < 360;
            final isSettings = widget.currentPath.startsWith('/app/settings');

            final navItems = showOnboarding
                ? const [
                    PaidiXBottomNavItem(
                      icon: Icons.grid_view_outlined,
                      activeIcon: Icons.grid_view_rounded,
                      label: 'Dashboard',
                    ),
                    PaidiXBottomNavItem(
                      icon: Icons.badge_outlined,
                      activeIcon: Icons.badge,
                      label: 'Onboarding',
                    ),
                    PaidiXBottomNavItem(
                      icon: Icons.receipt_long_outlined,
                      activeIcon: Icons.receipt_long_rounded,
                      label: 'My Payments',
                    ),
                    PaidiXBottomNavItem(
                      icon: Icons.add_circle_outline_rounded,
                      activeIcon: Icons.add_circle_rounded,
                      label: 'New Payment',
                    ),
                  ]
                : const [
                    PaidiXBottomNavItem(
                      icon: Icons.grid_view_outlined,
                      activeIcon: Icons.grid_view_rounded,
                      label: 'Dashboard',
                    ),
                    PaidiXBottomNavItem(
                      icon: Icons.receipt_long_outlined,
                      activeIcon: Icons.receipt_long_rounded,
                      label: 'My Payments',
                    ),
                    PaidiXBottomNavItem(
                      icon: Icons.add_circle_outline_rounded,
                      activeIcon: Icons.add_circle_rounded,
                      label: 'New Payment',
                    ),
                  ];

            return Scaffold(
              backgroundColor: colors.background,
              appBar: isSettings
                  ? null
                  : AppBar(
                      backgroundColor: colors.card,
                      elevation: 0,
                      titleSpacing: isNarrowPhone ? 10 : 16,
                      title: const BrandLogo(
                        size: 30,
                        showPlanBadge: false,
                        showTagline: false,
                      ),
                      actions: [
                        InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => ProfileMenuDialog.show(
                            context: context,
                            userProfile: userProfile,
                            isMobile: true,
                          ),
                          child: _buildUserAvatar(
                            isSidebar: false,
                            userProfile: userProfile,
                          ),
                        ),
                        SizedBox(width: isNarrowPhone ? 10 : 16),
                      ],
                      bottom: PreferredSize(
                        preferredSize: const Size.fromHeight(1),
                        child: Container(color: colors.border, height: 1),
                      ),
                    ),
              body: widget.child,
              bottomNavigationBar: isSettings
                  ? null
                  : PaidiXBottomNavBar(
                      selectedIndex: selectedIndex,
                      onItemSelected: (idx) =>
                          _onDestinationSelected(idx, showOnboarding),
                      items: navItems,
                    ),
            );
          },
        );
      },
    ),
  ),
);
  }

  /// Builds the theme toggle button section of this interface.
  Widget _buildThemeToggleButton({bool isCompact = false, bool isSidebar = false}) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppTheme.themeModeNotifier,
      builder: (context, mode, _) {
        final isDark = mode == ThemeMode.dark;
        final colors = AppColors.of(context);

        final iconColor = isSidebar
            ? (isDark ? AppColors.gold : AppColors.sidebarText)
            : (isDark ? colors.gold : colors.textPrimary);

        return IconButton(
          icon: AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            transitionBuilder: (child, anim) => RotationTransition(
              turns: anim,
              child: FadeTransition(opacity: anim, child: child),
            ),
            child: Icon(
              isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              key: ValueKey<bool>(isDark),
              color: iconColor,
              size: isCompact ? 18 : 20,
            ),
          ),
          tooltip: isDark ? 'Switch to Light Theme' : 'Switch to Dark Theme',
          onPressed: () => AppTheme.toggleTheme(),
        );
      },
    );
  }

  /// Builds the sidebar section of this interface.
  Widget _buildSidebar(UserProfile userProfile) {
    final showOnboarding =
        userProfile.kycStatus != KycReviewStatus.verified;
    final selectedIndex = _calculateSelectedIndex(showOnboarding);
    final sidebarWidth = _isSidebarCollapsed ? 76.0 : 240.0;

    return AnimatedContainer(
      duration: AppMotion.normal,
      curve: Curves.easeOutCubic,
      width: sidebarWidth,
      decoration: const BoxDecoration(
        color: AppColors.sidebar,
        border: Border(right: BorderSide(color: AppColors.sidebarLine, width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Logo & Actions (theme toggle + collapse)
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 20, 8, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (!_isSidebarCollapsed)
                  const Expanded(
                    child: BrandLogo(showPlanBadge: false, forceLightText: true),
                  )
                else
                  const BrandLogo(
                    showPlanBadge: false,
                    showTagline: false,
                    size: 36,
                    forceLightText: true,
                  ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildThemeToggleButton(isCompact: true, isSidebar: true),
                    IconButton(
                      icon: Icon(
                        _isSidebarCollapsed
                            ? Icons.chevron_right
                            : Icons.chevron_left,
                        color: AppColors.sidebarMuted,
                        size: 20,
                      ),
                      onPressed: () =>
                          setState(() => _isSidebarCollapsed = !_isSidebarCollapsed),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Nav Items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              children: [
                _buildNavItem(
                  icon: Icons.dashboard_outlined,
                  activeIcon: Icons.dashboard,
                  title: 'Dashboard',
                  isSelected: selectedIndex == 0,
                  onTap: () => _onDestinationSelected(0, showOnboarding),
                ),
                if (showOnboarding) ...[
                  const SizedBox(height: 4),
                  _buildNavItem(
                    icon: Icons.assignment_ind_outlined,
                    activeIcon: Icons.assignment_ind,
                    title: 'Onboarding',
                    isSelected: selectedIndex == 1,
                    onTap: () => _onDestinationSelected(1, showOnboarding),
                  ),
                ],
                const SizedBox(height: 20),
                if (!_isSidebarCollapsed)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    child: Text(
                      'PAYMENTS',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                        color: AppColors.sidebarMuted,
                      ),
                    ),
                  ),
                _buildNavItem(
                  icon: Icons.receipt_long_outlined,
                  activeIcon: Icons.receipt_long,
                  title: 'My Payments',
                  isSelected: selectedIndex == (showOnboarding ? 2 : 1),
                  onTap: () =>
                      _onDestinationSelected(showOnboarding ? 2 : 1, showOnboarding),
                ),
                const SizedBox(height: 4),
                _buildNavItem(
                  icon: Icons.add_circle_outline_rounded,
                  activeIcon: Icons.add_circle_rounded,
                  title: 'New Payment',
                  isSelected: selectedIndex == (showOnboarding ? 3 : 2),
                  onTap: () =>
                      _onDestinationSelected(showOnboarding ? 3 : 2, showOnboarding),
                ),
              ],
            ),
          ),

          // User Profile footer
          _buildUserProfileFooter(userProfile),
        ],
      ),
    );
  }

  /// Builds the nav item section of this interface.
  Widget _buildNavItem({
    required IconData icon,
    required IconData activeIcon,
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        color: isSelected ? AppColors.activeNavBg : Colors.transparent,
        borderRadius: AppSpacing.radiusMd,
        border: Border.all(
          color: isSelected ? AppColors.sidebarLine : Colors.transparent,
          width: 0.8,
        ),
      ),
      child: ClipRRect(
        borderRadius: AppSpacing.radiusMd,
        child: Stack(
          children: [
            if (isSelected)
              Positioned(
                left: 0,
                top: 6,
                bottom: 6,
                child: Container(
                  width: 3.5,
                  decoration: BoxDecoration(
                    color: AppColors.activeNavIndicator,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            Material(
              color: Colors.transparent,
              child: ListTile(
                dense: true,
                leading: Icon(
                  isSelected ? activeIcon : icon,
                  color: isSelected ? const Color(0xFF95DFDB) : AppColors.sidebarMuted,
                  size: 20,
                ),
                title: _isSidebarCollapsed
                    ? null
                    : Text(
                        title,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected ? Colors.white : AppColors.sidebarText,
                        ),
                      ),
                shape: RoundedRectangleBorder(borderRadius: AppSpacing.radiusMd),
                onTap: onTap,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds the user profile footer section of this interface.
  Widget _buildUserProfileFooter(UserProfile userProfile) {
    return InkWell(
      onTap: () => ProfileMenuDialog.show(
        context: context,
        userProfile: userProfile,
        isMobile: false,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.sidebarLine, width: 1)),
        ),
        child: Row(
          children: [
            _buildUserAvatar(
              isSidebar: true,
              userProfile: userProfile,
            ),
            if (!_isSidebarCollapsed) ...[
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      userProfile.fullName,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.sidebarText,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      userProfile.email,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                        color: AppColors.sidebarMuted,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.keyboard_arrow_down,
                color: AppColors.sidebarMuted,
                size: 18,
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Builds the user avatar section of this interface.
  Widget _buildUserAvatar({
    required bool isSidebar,
    required UserProfile userProfile,
  }) {
    final colors = AppColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (userProfile.hasCustomAvatar) {
      if (userProfile.avatarBytes != null &&
          userProfile.avatarBytes!.isNotEmpty) {
        return ClipOval(
          child: Image.memory(
            userProfile.avatarBytes!,
            width: 32,
            height: 32,
            fit: BoxFit.cover,
            alignment: Alignment.center,
            errorBuilder: (_, __, ___) => _buildFallbackAvatar(
              isSidebar: isSidebar,
              initial: userProfile.avatarInitial,
              colors: colors,
              isDark: isDark,
            ),
          ),
        );
      } else if (userProfile.avatarFilePath != null &&
          userProfile.avatarFilePath!.isNotEmpty &&
          !kIsWeb) {
        final file = File(userProfile.avatarFilePath!);
        if (file.existsSync()) {
          return ClipOval(
            child: Image.file(
              file,
              width: 32,
              height: 32,
              fit: BoxFit.cover,
              alignment: Alignment.center,
              errorBuilder: (_, __, ___) => _buildFallbackAvatar(
                isSidebar: isSidebar,
                initial: userProfile.avatarInitial,
                colors: colors,
                isDark: isDark,
              ),
            ),
          );
        }
      }
    }

    return _buildFallbackAvatar(
      isSidebar: isSidebar,
      initial: userProfile.avatarInitial,
      colors: colors,
      isDark: isDark,
    );
  }

  /// Builds the fallback avatar section of this interface.
  Widget _buildFallbackAvatar({
    required bool isSidebar,
    required String initial,
    required PaidiXColorScheme colors,
    required bool isDark,
  }) {
    Color bg;
    Color fg;

    if (isSidebar) {
      bg = const Color(0xFF0E7C7B);
      fg = Colors.white;
    } else {
      bg = isDark ? colors.aqua : colors.primaryButton;
      fg = isDark ? const Color(0xFF031415) : Colors.white;
    }

    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          color: fg,
          fontWeight: FontWeight.w800,
          fontSize: 14,
        ),
      ),
    );
  }
}
