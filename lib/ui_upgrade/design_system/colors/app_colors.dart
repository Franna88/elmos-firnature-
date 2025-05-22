import 'package:flutter/material.dart';

/// AppColors defines the color palette for the Elmos Furniture application.
/// This centralized color system ensures consistency across all UI components.
class AppColors {
  // Primary Colors
  static const Color primary = Color(0xFF1A365D); // Deep blue
  static const Color primaryLight = Color(0xFF2A4A80); // Lighter blue
  static const Color primaryDark = Color(0xFF0F2942); // Darker blue

  // Secondary Colors
  static const Color secondary = Color(0xFF2C7A7B); // Teal
  static const Color secondaryLight = Color(0xFF38B2AC); // Light teal
  static const Color secondaryDark = Color(0xFF285E61); // Dark teal

  // Accent Colors
  static const Color accent = Color(0xFFDD6B20); // Orange
  static const Color accentLight = Color(0xFFED8936); // Light orange
  static const Color accentDark = Color(0xFFC05621); // Dark orange

  // Neutral Colors
  static const Color white = Color(0xFFFFFFFF);
  static const Color background = Color(0xFFF7FAFC);
  static const Color surfaceLight = Color(0xFFEDF2F7);
  static const Color surface = Color(0xFFE2E8F0);
  static const Color grey100 = Color(0xFFCBD5E0);
  static const Color grey200 = Color(0xFFA0AEC0);
  static const Color grey300 = Color(0xFF718096);
  static const Color grey400 = Color(0xFF4A5568);
  static const Color grey500 = Color(0xFF2D3748);
  static const Color black = Color(0xFF1A202C);

  // Semantic Colors
  static const Color success = Color(0xFF38A169); // Green
  static const Color warning = Color(0xFFECC94B); // Yellow
  static const Color error = Color(0xFFE53E3E); // Red
  static const Color info = Color(0xFF3182CE); // Blue

  // Message Colors
  static const Color infoLight = Color(0xFFEBF8FF); // Light blue background
  static const Color infoBorder = Color(0xFFBEE3F8); // Blue border
  static const Color infoText = Color(0xFF2C5282); // Dark blue text

  static const Color successLight = Color(0xFFF0FFF4); // Light green background
  static const Color successBorder = Color(0xFFC6F6D5); // Green border
  static const Color successText = Color(0xFF276749); // Dark green text

  static const Color warningLight =
      Color(0xFFFFFBEB); // Light yellow background
  static const Color warningBorder = Color(0xFFFEF3C7); // Yellow border
  static const Color warningText = Color(0xFF975A16); // Dark yellow/brown text

  static const Color errorLight = Color(0xFFFFF5F5); // Light red background
  static const Color errorBorder = Color(0xFFFED7D7); // Red border
  static const Color errorText = Color(0xFF9B2C2C); // Dark red text

  // Text Colors
  static const Color textPrimary = Color(0xFF1A202C); // Near black
  static const Color textSecondary = Color(0xFF4A5568); // Dark grey
  static const Color textTertiary = Color(0xFF718096); // Medium grey
  static const Color textDisabled = Color(0xFFA0AEC0); // Light grey

  // Border Colors
  static const Color border = Color(0xFFE2E8F0);
  static const Color borderDark = Color(0xFFCBD5E0);

  // Overlay Colors
  static const Color overlay = Color(0x801A202C); // 50% opacity black

  // Gradient Colors
  static const List<Color> primaryGradient = [
    Color(0xFF1A365D),
    Color(0xFF2A4A80),
  ];

  static const List<Color> secondaryGradient = [
    Color(0xFF2C7A7B),
    Color(0xFF38B2AC),
  ];

  // Status Colors for MES Module
  static const Color statusActive = Color(0xFF38A169); // Green
  static const Color statusIdle = Color(0xFFECC94B); // Yellow
  static const Color statusDown = Color(0xFFE53E3E); // Red
  static const Color statusMaintenance = Color(0xFF3182CE); // Blue
  static const Color statusOffline = Color(0xFF718096); // Grey

  // Instance properties for use with AppTheme.of(context).colors
  Color get primaryColor => primary;
  Color get primaryLightColor => primaryLight;
  Color get primaryDarkColor => primaryDark;

  Color get secondaryColor => secondary;
  Color get secondaryLightColor => secondaryLight;
  Color get secondaryDarkColor => secondaryDark;

  Color get accentColor => accent;
  Color get accentLightColor => accentLight;
  Color get accentDarkColor => accentDark;

  Color get whiteColor => white;
  Color get backgroundColor => background;
  Color get surfaceLightColor => surfaceLight;
  Color get surfaceColor => surface;
  Color get grey100Color => grey100;
  Color get grey200Color => grey200;
  Color get grey300Color => grey300;
  Color get grey400Color => grey400;
  Color get grey500Color => grey500;
  Color get blackColor => black;

  Color get successColor => success;
  Color get warningColor => warning;
  Color get errorColor => error;
  Color get infoColor => info;

  // Message color getters
  Color get infoLightColor => infoLight;
  Color get infoBorderColor => infoBorder;
  Color get infoTextColor => infoText;

  Color get successLightColor => successLight;
  Color get successBorderColor => successBorder;
  Color get successTextColor => successText;

  Color get warningLightColor => warningLight;
  Color get warningBorderColor => warningBorder;
  Color get warningTextColor => warningText;

  Color get errorLightColor => errorLight;
  Color get errorBorderColor => errorBorder;
  Color get errorTextColor => errorText;

  Color get textPrimaryColor => textPrimary;
  Color get textSecondaryColor => textSecondary;
  Color get textTertiaryColor => textTertiary;
  Color get textDisabledColor => textDisabled;

  Color get borderColor => border;
  Color get borderDarkColor => borderDark;

  Color get overlayColor => overlay;

  List<Color> get primaryGradientColors => primaryGradient;
  List<Color> get secondaryGradientColors => secondaryGradient;

  Color get statusActiveColor => statusActive;
  Color get statusIdleColor => statusIdle;
  Color get statusDownColor => statusDown;
  Color get statusMaintenanceColor => statusMaintenance;
  Color get statusOfflineColor => statusOffline;
}
