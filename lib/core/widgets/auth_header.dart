/// Defines auth header in the application core utilities and reusable widgets.

import 'package:flutter/material.dart';
import '../../app/theme/app_typography.dart';
import 'brand_logo.dart';

class AuthHeader extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String subtitle;

  const AuthHeader({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
  });

  /// Builds the widget subtree from its current properties and inherited context.
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const BrandLogo(showPlanBadge: false, size: 38),
        const SizedBox(height: 24),
        Text(
          eyebrow.toUpperCase(),
          style: AppTypography.sectionEyebrow,
        ),
        const SizedBox(height: 8),
        Text(
          title,
          style: AppTypography.pageHeading,
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: AppTypography.pageSubtitle,
        ),
      ],
    );
  }
}
