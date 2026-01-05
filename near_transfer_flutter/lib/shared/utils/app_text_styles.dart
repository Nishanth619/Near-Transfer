import 'package:flutter/material.dart';
import '../../core/constants.dart';

/// Centralized text styles for consistent UI across the app
/// Ensures proper contrast in both light and dark modes
class AppTextStyles {
  // Get text color based on context (gradient background vs card)
  static Color getTextColorForBackground(BuildContext context, {bool onGradient = true}) {
    if (onGradient) {
      // Text on gradient background should always be white
      return Colors.white;
    }
    // Text on cards follows theme
    return Theme.of(context).brightness == Brightness.dark 
        ? AppColors.darkTextPrimary 
        : AppColors.textPrimary;
  }

  static Color getSecondaryTextColor(BuildContext context, {bool onGradient = true}) {
    if (onGradient) {
      return Colors.white70;
    }
    return Theme.of(context).brightness == Brightness.dark 
        ? AppColors.darkTextSecondary 
        : AppColors.muted;
  }

  // Headings - for screen titles
  static TextStyle heading1(BuildContext context, {bool onGradient = true}) {
    return TextStyle(
      fontSize: 28,
      fontWeight: FontWeight.bold,
      color: getTextColorForBackground(context, onGradient: onGradient),
      letterSpacing: 0.5,
    );
  }

  static TextStyle heading2(BuildContext context, {bool onGradient = true}) {
    return TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.bold,
      color: getTextColorForBackground(context, onGradient: onGradient),
    );
  }

  static TextStyle heading3(BuildContext context, {bool onGradient = true}) {
    return TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w600,
      color: getTextColorForBackground(context, onGradient: onGradient),
    );
  }

  // Body text
  static TextStyle bodyLarge(BuildContext context, {bool onGradient = true}) {
    return TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.normal,
      color: getTextColorForBackground(context, onGradient: onGradient),
      height: 1.5,
    );
  }

  static TextStyle bodyMedium(BuildContext context, {bool onGradient = true}) {
    return TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.normal,
      color: getTextColorForBackground(context, onGradient: onGradient),
      height: 1.4,
    );
  }

  static TextStyle bodySmall(BuildContext context, {bool onGradient = true}) {
    return TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.normal,
      color: getSecondaryTextColor(context, onGradient: onGradient),
      height: 1.3,
    );
  }

  // Labels and captions
  static TextStyle label(BuildContext context, {bool onGradient = true}) {
    return TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w500,
      color: getTextColorForBackground(context, onGradient: onGradient),
    );
  }

  static TextStyle caption(BuildContext context, {bool onGradient = true}) {
    return TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.normal,
      color: getSecondaryTextColor(context, onGradient: onGradient),
    );
  }

  // Button text
  static TextStyle button(BuildContext context, {bool onGradient = true}) {
    return TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: getTextColorForBackground(context, onGradient: onGradient),
      letterSpacing: 0.5,
    );
  }

  // Card title and subtitle (for UI elements on cards/surfaces)
  static TextStyle cardTitle(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.bold,
      color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
    );
  }

  static TextStyle cardSubtitle(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.normal,
      color: isDark ? AppColors.darkTextSecondary : AppColors.muted,
    );
  }

  // Special styles with text shadow for better visibility
  static TextStyle headingWithShadow(BuildContext context, {double fontSize = 28}) {
    return TextStyle(
      fontSize: fontSize,
      fontWeight: FontWeight.bold,
      color: Colors.white,
      shadows: const [
        Shadow(
          color: Colors.black38,
          blurRadius: 4,
          offset: Offset(0, 2),
        ),
      ],
    );
  }

  static TextStyle bodyWithShadow(BuildContext context, {double fontSize = 14}) {
    return TextStyle(
      fontSize: fontSize,
      fontWeight: FontWeight.normal,
      color: Colors.white,
      shadows: const [
        Shadow(
          color: Colors.black26,
          blurRadius: 2,
          offset: Offset(0, 1),
        ),
      ],
    );
  }
}
