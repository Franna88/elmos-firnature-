import 'package:flutter/material.dart';
import '../colors/app_colors.dart';
import 'app_typography.dart';

/// AppTextStyles provides a convenient way to access typography styles.
/// This is a simplified wrapper around AppTypography to make it easier to use in components.
class AppTextStyles {
  // Display styles
  static TextStyle get displayLarge => AppTypography.displayLargeStyle();
  static TextStyle get displayMedium => AppTypography.displayMediumStyle();
  static TextStyle get displaySmall => AppTypography.displaySmallStyle();

  // Heading styles
  static TextStyle get h1 => AppTypography.headingLargeStyle();
  static TextStyle get h2 => AppTypography.headingMediumStyle();
  static TextStyle get h3 => AppTypography.headingSmallStyle();

  // Body styles
  static TextStyle get bodyLarge => AppTypography.bodyLargeStyle();
  static TextStyle get body => AppTypography.bodyMediumStyle();
  static TextStyle get bodySmall => AppTypography.bodySmallStyle();

  // Label styles
  static TextStyle get labelLarge => AppTypography.labelLargeStyle();
  static TextStyle get label => AppTypography.labelMediumStyle();
  static TextStyle get labelSmall => AppTypography.labelSmallStyle();

  // Button styles
  static TextStyle get buttonLarge => AppTypography.buttonLargeStyle();
  static TextStyle get button => AppTypography.buttonMediumStyle();
  static TextStyle get buttonSmall => AppTypography.buttonSmallStyle();

  // Other styles
  static TextStyle get caption => AppTypography.captionStyle();
  static TextStyle get overline => AppTypography.overlineStyle();
}
