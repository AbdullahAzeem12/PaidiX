/// Defines app date picker theme in the application core utilities and reusable widgets.

import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_theme.dart';

/// Provides a unified, high-contrast, beautiful dark-teal date picker theme
/// for all date pickers across PaidiX.
///
/// Ensures selected day, selected year, and today's indicators have crystal-clear
/// visibility with bold high-contrast text against active aqua highlights.
Widget buildAppDatePickerTheme(BuildContext context, Widget child) {
  final colors = AppColors.of(context);
  final isDark = Theme.of(context).brightness == Brightness.dark;
  const onSelectedColor = Color(0xFF022020);

  return Theme(
    data: Theme.of(context).copyWith(
      colorScheme: isDark
          ? ColorScheme.dark(
              primary: colors.aqua,
              onPrimary: onSelectedColor,
              surface: colors.cardDark,
              onSurface: colors.textPrimary,
              onSurfaceVariant: colors.aquaLight,
              secondary: colors.aquaLight,
              onSecondary: onSelectedColor,
            )
          : ColorScheme.light(
              primary: colors.aqua,
              onPrimary: onSelectedColor,
              surface: colors.card,
              onSurface: colors.textPrimary,
              onSurfaceVariant: colors.aqua,
            ),
      dialogTheme: DialogThemeData(
        backgroundColor: isDark ? colors.cardDark : colors.card,
      ),
      textTheme: TextTheme(
        titleSmall: TextStyle(
          fontFamily: AppTheme.activeFontFamily,
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: colors.textPrimary,
        ),
        bodyMedium: TextStyle(
          fontFamily: AppTheme.activeFontFamily,
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: colors.textPrimary,
        ),
        bodyLarge: TextStyle(
          fontFamily: AppTheme.activeFontFamily,
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: colors.textPrimary,
        ),
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: isDark ? colors.cardDark : colors.card,
        headerBackgroundColor: colors.card,
        headerForegroundColor: colors.aqua,
        headerHeadlineStyle: TextStyle(
          fontFamily: AppTheme.activeFontFamily,
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: colors.aqua,
        ),
        headerHelpStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
          color: colors.textSecondary,
        ),
        dividerColor: colors.border.withValues(alpha: 0.6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: colors.aqua.withValues(alpha: 0.35),
            width: 1.2,
          ),
        ),

        // Day label styling & colors
        dayStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
        dayForegroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return onSelectedColor; // Clear dark text on aqua circle
          }
          if (states.contains(WidgetState.disabled)) {
            return colors.textMuted.withValues(alpha: 0.35);
          }
          return colors.textPrimary; // Crisp white
        }),
        dayBackgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colors.aqua;
          }
          return null;
        }),

        // Today indicator styling (crucial for current day & current year)
        todayBorder: BorderSide(color: colors.aqua, width: 1.6),
        todayForegroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return onSelectedColor; // Clear dark text when today is selected
          }
          return colors.aqua; // Vibrant aqua text when unselected
        }),
        todayBackgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colors.aqua;
          }
          return null;
        }),

        // Year selector styling (crucial for year picker modal)
        yearStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
        yearForegroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return onSelectedColor; // Clear dark text on aqua stadium pill
          }
          if (states.contains(WidgetState.disabled)) {
            return colors.textMuted.withValues(alpha: 0.35);
          }
          return colors.textPrimary; // Crisp white
        }),
        yearBackgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colors.aqua;
          }
          return null;
        }),

        // Weekday header styling (S M T W T F S)
        weekdayStyle: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: colors.aquaLight,
        ),

        // Action buttons
        cancelButtonStyle: TextButton.styleFrom(
          foregroundColor: colors.textSecondary,
          textStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
        confirmButtonStyle: TextButton.styleFrom(
          foregroundColor: colors.aqua,
          textStyle: TextStyle(
            fontFamily: AppTheme.activeFontFamily,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
          ),
        ),
      ),
    ),
    child: child,
  );
}

