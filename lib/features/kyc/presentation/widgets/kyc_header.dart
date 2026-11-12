/// Defines kyc header in the kyc feature's presentation layer.

import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/widgets/brand_logo.dart';

class KycHeader extends StatelessWidget {
  const KycHeader({super.key});

  /// Builds the widget subtree from its current properties and inherited context.
  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Container(
      decoration: BoxDecoration(
        color: colors.background,
        border: Border(
          bottom: BorderSide(
            color: colors.border.withValues(alpha: 0.6),
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isMobile = constraints.maxWidth < 600;
            final isNarrow = constraints.maxWidth < 370;
            final horizontalPadding = isMobile ? 12.0 : 20.0;

            return Padding(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: isMobile ? 10.0 : 14.0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Brand Logo - compact on mobile without multi-word tagline to prevent overflow
                  Flexible(
                    child: BrandLogo(
                      size: isMobile ? 30 : 36,
                      showTagline: !isMobile,
                      forceLightText: false,
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Actions Group: Account Setup Pill + Log out
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Account Setup Pill Badge
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: isNarrow ? 8 : 10,
                          vertical: isNarrow ? 4 : 5,
                        ),
                        decoration: BoxDecoration(
                          color: colors.aqua.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: colors.aqua.withValues(alpha: 0.35),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 5,
                              height: 5,
                              decoration: BoxDecoration(
                                color: colors.aqua,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              'ACCOUNT SETUP',
                              style: TextStyle(
                                color: colors.aqua,
                                fontSize: isNarrow ? 9.5 : 10.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: isNarrow ? 6 : 10),

                      // Log out action button
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            context.go('/signin');
                          },
                          borderRadius: AppSpacing.radiusSm,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 6,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.logout_rounded,
                                  size: 15,
                                  color: colors.textSecondary,
                                ),
                                if (!isNarrow) ...[
                                  const SizedBox(width: 5),
                                  Text(
                                    'Log out',
                                    style: TextStyle(
                                      color: colors.textSecondary,
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
