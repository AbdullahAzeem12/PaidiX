/// Defines onboarding profile page in the profile feature's presentation layer.

import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/widgets/paidix_toast.dart';
import '../../../../core/widgets/spongy_tap.dart';
import '../../../auth/data/auth_repository.dart';
import '../../data/user_profile_repository.dart';
import '../../domain/user_profile.dart';
import '../widgets/edit_profile_dialog.dart';
import '../widgets/kyc_review_card.dart';
import '../widgets/profile_info_card.dart';

/// Onboarding & Profile Page for PaidiX.
///
/// Provides real-time synchronization between Sign-Up, regulatory KYC flow,
/// and live account profile. Matches design system and screenshot specifications.
class OnboardingProfilePage extends StatelessWidget {
  const OnboardingProfilePage({super.key});

  Future<void> _refreshProfile(BuildContext context) async {
    try {
      await Future.wait<Object?>([
        AuthRepository.instance.fetchCurrentUserProfile(),
        AuthRepository.instance.refreshKycReviewStatus(),
      ]);
    } catch (_) {
      if (context.mounted) {
        PaidiXToast.showError(
          context,
          'Could not refresh your profile. Please try again.',
        );
      }
    }
  }

  /// Builds the widget subtree from its current properties and inherited context.
  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: ValueListenableBuilder<UserProfile>(
          valueListenable: UserProfileRepository.instance.profileNotifier,
          builder: (context, profile, _) {
            return LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 900;
                final isNarrow = constraints.maxWidth < 400;

                return RefreshIndicator(
                  color: colors.aqua,
                  backgroundColor: colors.card,
                  onRefresh: () => _refreshProfile(context),
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    padding: EdgeInsets.symmetric(
                      horizontal: isNarrow ? 16 : 24,
                      vertical: 24,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header Section: Eyebrow + Title + Subtitle + Edit Profile Action
                        _buildHeader(context, profile, isNarrow, colors),
                        if (profile.kycStatus.requiresCustomerAction ||
                            (profile.kycStatus ==
                                    KycReviewStatus.pendingReview &&
                                profile.hasResubmittedKyc)) ...[
                          const SizedBox(height: 18),
                          _buildKycStatusBanner(profile, colors),
                        ],
                        const SizedBox(height: 24),

                        // Main Cards: Two-column grid on wide displays, vertical on mobile
                        if (isWide)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 6,
                                child: ProfileInfoCard(profile: profile),
                              ),
                              const SizedBox(width: 20),
                              Expanded(
                                flex: 5,
                                child: KycReviewCard(profile: profile),
                              ),
                            ],
                          )
                        else
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              ProfileInfoCard(profile: profile),
                              const SizedBox(height: 20),
                              KycReviewCard(profile: profile),
                            ],
                          ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  /// Builds the header section of this interface.
  Widget _buildHeader(
    BuildContext context,
    UserProfile profile,
    bool isNarrow,
    PaidiXColorScheme colors,
  ) {
    final titleBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'PROFILE',
          style: AppTypography.sectionEyebrow.copyWith(
            color: colors.gold,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Your profile & identity.',
          style: AppTypography.pageHeading.copyWith(
            color: colors.textPrimary,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Personal information and KYC documents on file.',
          style: AppTypography.pageSubtitle.copyWith(
            color: colors.textSecondary,
          ),
        ),
      ],
    );

    final editButton = SpongyTap(
      onTap: () => EditProfileDialog.show(context, profile),
      pressScale: 0.92,
      borderRadius: AppSpacing.radiusMd,
      backgroundColor: colors.card,
      activeBackgroundColor: colors.cardDark,
      border: Border.all(color: colors.aqua.withValues(alpha: 0.6), width: 1.2),
      activeBorder: Border.all(color: colors.aqua, width: 1.2),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      splashColor: colors.aquaLight.withValues(alpha: 0.28),
      highlightColor: colors.aqua.withValues(alpha: 0.12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.edit_outlined, size: 15, color: colors.aqua),
          const SizedBox(width: 8),
          Text(
            'Edit profile',
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );

    final headerActions = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (profile.kycStatus.requiresCustomerAction)
          SpongyTap(
            onTap: () => context.go('/kyc?resubmit=true'),
            pressScale: 0.94,
            borderRadius: AppSpacing.radiusMd,
            backgroundColor: const Color(0xFF022F32),
            activeBackgroundColor: colors.cardDark,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.edit_note_rounded,
                  size: 17,
                  color: Colors.white,
                ),
                const SizedBox(width: 8),
                Text(
                  'Fix & resubmit',
                  style: TextStyle(
                    color: Colors.white,
                    fontFamily: AppTheme.activeFontFamily,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        editButton,
      ],
    );

    if (isNarrow) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [titleBlock, const SizedBox(height: 16), headerActions],
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(child: titleBlock),
        const SizedBox(width: 16),
        headerActions,
      ],
    );
  }

  Widget _buildKycStatusBanner(UserProfile profile, PaidiXColorScheme colors) {
    const rejection = Color(0xFFBE123C);
    const resubmitted = Color(0xFF3B82F6);
    const updateRequired = Color(0xFFB7791F);
    final isResubmitted =
        profile.hasResubmittedKyc &&
        profile.kycStatus == KycReviewStatus.pendingReview;
    final isAwaitingCustomer =
        profile.kycStatus == KycReviewStatus.awaitingCustomer;
    final accent = isResubmitted
        ? resubmitted
        : isAwaitingCustomer
        ? updateRequired
        : rejection;
    final feedback = profile.effectiveKycReason;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        border: Border.all(color: accent.withValues(alpha: 0.30)),
        borderRadius: AppSpacing.radiusLg,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(
              isResubmitted
                  ? Icons.sync_rounded
                  : isAwaitingCustomer
                  ? Icons.edit_note_rounded
                  : Icons.warning_amber_rounded,
              size: 19,
              color: accent,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isResubmitted
                      ? 'Thanks, your updated information is awaiting review.'
                      : isAwaitingCustomer
                      ? 'The reviewer requested updates to your KYC.'
                      : 'Your KYC submission was rejected.',
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                if (isResubmitted)
                  Text(
                    "You'll see an update here after review.",
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: 12.5,
                      height: 1.35,
                    ),
                  )
                else if (feedback != null)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(top: 5),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: accent.withValues(alpha: 0.16)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isAwaitingCustomer ? 'Requested updates:' : 'Reason:',
                          style: TextStyle(
                            color: accent,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          feedback,
                          style: TextStyle(
                            color: colors.textSecondary,
                            fontSize: 12.5,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Text(
                    isAwaitingCustomer
                        ? 'Please correct the items below and resubmit your KYC.'
                        : 'Update the requested information and resubmit your documents.',
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: 12.5,
                      height: 1.35,
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
