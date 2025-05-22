import 'package:flutter/material.dart';
import '../colors/app_colors.dart';

/// AppTypography defines the text styles for the Elmos Furniture application.
/// This ensures consistent typography across all UI components.
class AppTypography {
  // Font families
  static const String primaryFontFamily = 'Roboto';
  static const String secondaryFontFamily = 'Roboto Slab';

  // Instance properties for use with AppTheme.of(context).typography
  final TextStyle displayLarge = TextStyle(
    fontFamily: primaryFontFamily,
    fontSize: 32.0,
    fontWeight: FontWeight.bold,
    letterSpacing: -0.5,
    color: AppColors.textPrimary,
    height: 1.2,
  );

  final TextStyle displayMedium = TextStyle(
    fontFamily: primaryFontFamily,
    fontSize: 28.0,
    fontWeight: FontWeight.bold,
    letterSpacing: -0.5,
    color: AppColors.textPrimary,
    height: 1.2,
  );

  final TextStyle displaySmall = TextStyle(
    fontFamily: primaryFontFamily,
    fontSize: 24.0,
    fontWeight: FontWeight.bold,
    letterSpacing: -0.25,
    color: AppColors.textPrimary,
    height: 1.2,
  );

  final TextStyle headingLarge = TextStyle(
    fontFamily: primaryFontFamily,
    fontSize: 22.0,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.25,
    color: AppColors.textPrimary,
    height: 1.3,
  );

  final TextStyle headingMedium = TextStyle(
    fontFamily: primaryFontFamily,
    fontSize: 20.0,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.25,
    color: AppColors.textPrimary,
    height: 1.3,
  );

  final TextStyle headingSmall = TextStyle(
    fontFamily: primaryFontFamily,
    fontSize: 18.0,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.25,
    color: AppColors.textPrimary,
    height: 1.3,
  );

  final TextStyle bodyLarge = TextStyle(
    fontFamily: primaryFontFamily,
    fontSize: 16.0,
    fontWeight: FontWeight.normal,
    letterSpacing: 0.15,
    color: AppColors.textPrimary,
    height: 1.5,
  );

  final TextStyle bodyMedium = TextStyle(
    fontFamily: primaryFontFamily,
    fontSize: 14.0,
    fontWeight: FontWeight.normal,
    letterSpacing: 0.25,
    color: AppColors.textSecondary,
    height: 1.5,
  );

  final TextStyle bodySmall = TextStyle(
    fontFamily: primaryFontFamily,
    fontSize: 12.0,
    fontWeight: FontWeight.normal,
    letterSpacing: 0.4,
    color: AppColors.textSecondary,
    height: 1.5,
  );

  // Alias for bodyMedium
  TextStyle get body => bodyMedium;

  final TextStyle labelLarge = TextStyle(
    fontFamily: primaryFontFamily,
    fontSize: 14.0,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.1,
    color: AppColors.textPrimary,
    height: 1.4,
  );

  final TextStyle labelMedium = TextStyle(
    fontFamily: primaryFontFamily,
    fontSize: 12.0,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.5,
    color: AppColors.textSecondary,
    height: 1.4,
  );

  final TextStyle labelSmall = TextStyle(
    fontFamily: primaryFontFamily,
    fontSize: 11.0,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.5,
    color: AppColors.textTertiary,
    height: 1.4,
  );

  final TextStyle buttonLarge = TextStyle(
    fontFamily: primaryFontFamily,
    fontSize: 16.0,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.5,
    color: AppColors.white,
    height: 1.4,
  );

  final TextStyle buttonMedium = TextStyle(
    fontFamily: primaryFontFamily,
    fontSize: 14.0,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.5,
    color: AppColors.white,
    height: 1.4,
  );

  final TextStyle buttonSmall = TextStyle(
    fontFamily: primaryFontFamily,
    fontSize: 12.0,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.5,
    color: AppColors.white,
    height: 1.4,
  );

  final TextStyle caption = TextStyle(
    fontFamily: primaryFontFamily,
    fontSize: 12.0,
    fontWeight: FontWeight.normal,
    letterSpacing: 0.4,
    color: AppColors.textTertiary,
    height: 1.4,
  );

  final TextStyle overline = TextStyle(
    fontFamily: primaryFontFamily,
    fontSize: 10.0,
    fontWeight: FontWeight.w500,
    letterSpacing: 1.5,
    color: AppColors.textTertiary,
    height: 1.4,
    textBaseline: TextBaseline.alphabetic,
  );

  // Material theme text style aliases
  TextStyle get headline1 => displayLarge;
  TextStyle get headline2 => displayMedium;
  TextStyle get headline3 => displaySmall;
  TextStyle get headline4 => headingLarge;
  TextStyle get headline5 => headingMedium;
  TextStyle get headline6 => headingSmall;
  TextStyle get subtitle1 => labelLarge;
  TextStyle get subtitle2 => labelMedium;

  // Static methods for direct usage without instance
  static TextStyle displayLargeStyle({Color? color}) => TextStyle(
        fontFamily: primaryFontFamily,
        fontSize: 32.0,
        fontWeight: FontWeight.bold,
        letterSpacing: -0.5,
        color: color ?? AppColors.textPrimary,
        height: 1.2,
      );

  static TextStyle displayMediumStyle({Color? color}) => TextStyle(
        fontFamily: primaryFontFamily,
        fontSize: 28.0,
        fontWeight: FontWeight.bold,
        letterSpacing: -0.5,
        color: color ?? AppColors.textPrimary,
        height: 1.2,
      );

  static TextStyle displaySmallStyle({Color? color}) => TextStyle(
        fontFamily: primaryFontFamily,
        fontSize: 24.0,
        fontWeight: FontWeight.bold,
        letterSpacing: -0.25,
        color: color ?? AppColors.textPrimary,
        height: 1.2,
      );

  static TextStyle headingLargeStyle({Color? color}) => TextStyle(
        fontFamily: primaryFontFamily,
        fontSize: 22.0,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.25,
        color: color ?? AppColors.textPrimary,
        height: 1.3,
      );

  static TextStyle headingMediumStyle({Color? color}) => TextStyle(
        fontFamily: primaryFontFamily,
        fontSize: 20.0,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.25,
        color: color ?? AppColors.textPrimary,
        height: 1.3,
      );

  static TextStyle headingSmallStyle({Color? color}) => TextStyle(
        fontFamily: primaryFontFamily,
        fontSize: 18.0,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.25,
        color: color ?? AppColors.textPrimary,
        height: 1.3,
      );

  static TextStyle bodyLargeStyle({Color? color, FontWeight? fontWeight}) =>
      TextStyle(
        fontFamily: primaryFontFamily,
        fontSize: 16.0,
        fontWeight: fontWeight ?? FontWeight.normal,
        letterSpacing: 0.15,
        color: color ?? AppColors.textPrimary,
        height: 1.5,
      );

  static TextStyle bodyMediumStyle({Color? color, FontWeight? fontWeight}) =>
      TextStyle(
        fontFamily: primaryFontFamily,
        fontSize: 14.0,
        fontWeight: fontWeight ?? FontWeight.normal,
        letterSpacing: 0.25,
        color: color ?? AppColors.textSecondary,
        height: 1.5,
      );

  static TextStyle bodySmallStyle({Color? color, FontWeight? fontWeight}) =>
      TextStyle(
        fontFamily: primaryFontFamily,
        fontSize: 12.0,
        fontWeight: fontWeight ?? FontWeight.normal,
        letterSpacing: 0.4,
        color: color ?? AppColors.textSecondary,
        height: 1.5,
      );

  static TextStyle labelLargeStyle({Color? color}) => TextStyle(
        fontFamily: primaryFontFamily,
        fontSize: 14.0,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.1,
        color: color ?? AppColors.textPrimary,
        height: 1.4,
      );

  static TextStyle labelMediumStyle({Color? color}) => TextStyle(
        fontFamily: primaryFontFamily,
        fontSize: 12.0,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
        color: color ?? AppColors.textSecondary,
        height: 1.4,
      );

  static TextStyle labelSmallStyle({Color? color}) => TextStyle(
        fontFamily: primaryFontFamily,
        fontSize: 11.0,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
        color: color ?? AppColors.textTertiary,
        height: 1.4,
      );

  static TextStyle buttonLargeStyle({Color? color}) => TextStyle(
        fontFamily: primaryFontFamily,
        fontSize: 16.0,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
        color: color ?? AppColors.white,
        height: 1.4,
      );

  static TextStyle buttonMediumStyle({Color? color}) => TextStyle(
        fontFamily: primaryFontFamily,
        fontSize: 14.0,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
        color: color ?? AppColors.white,
        height: 1.4,
      );

  static TextStyle buttonSmallStyle({Color? color}) => TextStyle(
        fontFamily: primaryFontFamily,
        fontSize: 12.0,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
        color: color ?? AppColors.white,
        height: 1.4,
      );

  static TextStyle captionStyle({Color? color}) => TextStyle(
        fontFamily: primaryFontFamily,
        fontSize: 12.0,
        fontWeight: FontWeight.normal,
        letterSpacing: 0.4,
        color: color ?? AppColors.textTertiary,
        height: 1.4,
      );

  static TextStyle overlineStyle({Color? color}) => TextStyle(
        fontFamily: primaryFontFamily,
        fontSize: 10.0,
        fontWeight: FontWeight.w500,
        letterSpacing: 1.5,
        color: color ?? AppColors.textTertiary,
        height: 1.4,
        textBaseline: TextBaseline.alphabetic,
      );
}
