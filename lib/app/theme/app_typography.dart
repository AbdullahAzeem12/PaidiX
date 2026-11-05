/// Defines app typography in the application theme system.

import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_theme.dart';

/// Site-wide typography rules adhering to PaidiX brand guidance.
/// Weights are Medium (500) base with Bold (700/800) headings and tabular numbers.
class AppTypography {
  AppTypography._();

  static String? get _font => AppTheme.activeFontFamily;

  static TextStyle get brandTitle => TextStyle(
        fontFamily: _font,
        fontSize: 20,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.3,
        color: AppColors.textPrimary,
      );

  static TextStyle get brandTagline => TextStyle(
        fontFamily: _font,
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: AppColors.textSecondary,
        letterSpacing: 0.2,
      );

  static TextStyle get sectionEyebrow => TextStyle(
        fontFamily: _font,
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.6,
        color: AppColors.textSecondary,
      );

  static TextStyle get pageHeading => TextStyle(
        fontFamily: _font,
        fontSize: 28,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.6,
        color: AppColors.textPrimary,
        height: 1.2,
      );

  static TextStyle get pageSubtitle => TextStyle(
        fontFamily: _font,
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: AppColors.textSecondary,
        height: 1.4,
      );

  static TextStyle get statValueLarge => TextStyle(
        fontFamily: _font,
        fontSize: 30,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.8,
        color: AppColors.textPrimary,
      );

  static TextStyle get statValueScore => TextStyle(
        fontFamily: _font,
        fontSize: 54,
        fontWeight: FontWeight.w900,
        letterSpacing: -1.5,
        color: AppColors.mintHeroText,
        height: 1.0,
      );

  static TextStyle get cardTitle => TextStyle(
        fontFamily: _font,
        fontSize: 12,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.2,
        color: AppColors.textSecondary,
      );

  static TextStyle get label => TextStyle(
        fontFamily: _font,
        fontSize: 11.5,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.1,
        color: AppColors.textLabel,
      );

  static TextStyle get tableHeader => TextStyle(
        fontFamily: _font,
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.2,
        color: AppColors.textSecondary,
      );

  static TextStyle get tableCell => TextStyle(
        fontFamily: _font,
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: AppColors.textPrimary,
      );

  static TextStyle get tableCellMuted => TextStyle(
        fontFamily: _font,
        fontSize: 12.5,
        fontWeight: FontWeight.w400,
        color: AppColors.textSecondary,
      );

  static TextStyle get inputText => TextStyle(
        fontFamily: _font,
        fontSize: 14.5,
        fontWeight: FontWeight.w500,
        color: AppColors.textPrimary,
      );

  static TextStyle get inputPlaceholder => TextStyle(
        fontFamily: _font,
        fontSize: 14.5,
        fontWeight: FontWeight.w400,
        color: AppColors.textPlaceholder,
      );

  static TextStyle get buttonText => TextStyle(
        fontFamily: _font,
        fontSize: 14,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.2,
        color: AppColors.primaryButtonText,
      );

  static TextStyle get buttonTextLight => TextStyle(
        fontFamily: _font,
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
        color: AppColors.textPrimary,
      );

  static TextStyle get badgeText => TextStyle(
        fontFamily: _font,
        fontSize: 11.5,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.3,
      );

  static TextStyle get legalText => TextStyle(
        fontFamily: _font,
        fontSize: 11,
        fontWeight: FontWeight.w400,
        color: AppColors.textSecondary,
        height: 1.45,
      );

  static TextStyle get linkText => TextStyle(
        fontFamily: _font,
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: AppColors.aqua,
      );

  // Contextual helper
  static TextStyle pageHeadingOf(BuildContext context) => TextStyle(
        fontFamily: _font,
        fontSize: 28,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.6,
        color: AppColors.of(context).textPrimary,
        height: 1.2,
      );

  static TextStyle pageSubtitleOf(BuildContext context) => TextStyle(
        fontFamily: _font,
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: AppColors.of(context).textSecondary,
        height: 1.4,
      );
}
