/// Defines profile info card in the profile feature's presentation layer.

import 'package:material_ui/material_ui.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/widgets/profile_menu_dialog.dart';
import '../../domain/user_profile.dart';

/// Card displaying the user's verified personal profile details,
/// identity credentials, address, and live synchronization timestamps.
class ProfileInfoCard extends StatelessWidget {
  final UserProfile profile;

  const ProfileInfoCard({super.key, required this.profile});

  /// Builds the widget subtree from its current properties and inherited context.
  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: AppSpacing.radiusXl,
        border: Border.all(
          color: colors.border,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // User Header: Avatar Circle + Name + Phone
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Large Avatar Circle with Teal Background matching screenshot
              GestureDetector(
                onTap: () => ProfileMenuDialog.show(
                  context: context,
                  userProfile: profile,
                  isMobile: MediaQuery.of(context).size.width < 768,
                ),
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF95DFDB),
                    border: Border.all(
                      color: colors.aqua.withValues(alpha: 0.4),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF95DFDB).withValues(alpha: 0.25),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    profile.avatarInitial,
                    style: TextStyle(
                      fontFamily: AppTheme.activeFontFamily,
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF031415),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),

              // Name and Primary Phone
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.fullName,
                      style: TextStyle(
                        fontFamily: AppTheme.activeFontFamily,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: colors.textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      profile.displayPhone,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),
          Divider(color: colors.border.withValues(alpha: 0.7), height: 1),
          const SizedBox(height: 20),

          // Row 1: CNIC Number & Phone
          _buildTwoColRow(
            col1Title: 'CNIC NUMBER',
            col1Value: profile.displayCnic,
            col2Title: 'PHONE',
            col2Value: profile.displayPhone,
            colors: colors,
          ),
          const SizedBox(height: 20),

          // Row 2: City
          _buildField(
            title: 'CITY',
            value: profile.displayCity,
            colors: colors,
          ),
          const SizedBox(height: 20),

          // Row 3: Address
          _buildField(
            title: 'ADDRESS',
            value: profile.displayAddress,
            colors: colors,
          ),
          const SizedBox(height: 20),

          // Row 4: Profile Created & Last Updated
          _buildTwoColRow(
            col1Title: 'PROFILE CREATED',
            col1Value: profile.formattedCreatedAt,
            col2Title: 'LAST UPDATED',
            col2Value: profile.formattedUpdatedAt,
            colors: colors,
          ),
        ],
      ),
    );
  }

  /// Builds the field section of this interface.
  Widget _buildField({
    required String title,
    required String value,
    required PaidiXColorScheme colors,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontFamily: AppTheme.activeFontFamily,
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
            color: colors.textMuted,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          value,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            color: colors.textPrimary,
          ),
        ),
      ],
    );
  }

  /// Builds the two col row section of this interface.
  Widget _buildTwoColRow({
    required String col1Title,
    required String col1Value,
    required String col2Title,
    required String col2Value,
    required PaidiXColorScheme colors,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 280) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildField(
                title: col1Title,
                value: col1Value,
                colors: colors,
              ),
              const SizedBox(height: 16),
              _buildField(
                title: col2Title,
                value: col2Value,
                colors: colors,
              ),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildField(
                title: col1Title,
                value: col1Value,
                colors: colors,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildField(
                title: col2Title,
                value: col2Value,
                colors: colors,
              ),
            ),
          ],
        );
      },
    );
  }
}

