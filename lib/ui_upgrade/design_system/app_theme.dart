import 'package:flutter/material.dart';
import 'colors/app_colors.dart';
import 'typography/app_typography.dart';

/// AppTheme provides the theme data for the Elmos Furniture application.
/// It combines colors, typography, and component styles into a cohesive theme.
class AppTheme extends ThemeExtension<AppTheme> {
  final ThemeData themeData;
  final AppColors colors;
  final AppTypography typography;

  // Add properties needed for components
  final Color surfaceColor;
  final Color dividerColor;
  final Color primaryColor;

  const AppTheme._({
    required this.themeData,
    required this.colors,
    required this.typography,
    required this.surfaceColor,
    required this.dividerColor,
    required this.primaryColor,
  });

  /// Access the AppTheme from the current context.
  static AppTheme of(BuildContext context) {
    return Theme.of(context).extension<AppTheme>() ??
        AppTheme._(
          themeData: Theme.of(context),
          colors: AppColors(),
          typography: AppTypography(),
          surfaceColor: AppColors.white,
          dividerColor: AppColors.border,
          primaryColor: AppColors.primary,
        );
  }

  @override
  ThemeExtension<AppTheme> copyWith({
    ThemeData? themeData,
    AppColors? colors,
    AppTypography? typography,
    Color? surfaceColor,
    Color? dividerColor,
    Color? primaryColor,
  }) {
    return AppTheme._(
      themeData: themeData ?? this.themeData,
      colors: colors ?? this.colors,
      typography: typography ?? this.typography,
      surfaceColor: surfaceColor ?? this.surfaceColor,
      dividerColor: dividerColor ?? this.dividerColor,
      primaryColor: primaryColor ?? this.primaryColor,
    );
  }

  @override
  ThemeExtension<AppTheme> lerp(ThemeExtension<AppTheme>? other, double t) {
    if (other is! AppTheme) {
      return this;
    }
    return AppTheme._(
      themeData: this.themeData,
      colors: this.colors,
      typography: this.typography,
      surfaceColor: Color.lerp(surfaceColor, other.surfaceColor, t)!,
      dividerColor: Color.lerp(dividerColor, other.dividerColor, t)!,
      primaryColor: Color.lerp(primaryColor, other.primaryColor, t)!,
    );
  }

  // Light Theme
  static ThemeData lightTheme() {
    final themeData = ThemeData(
      // Color Scheme
      colorScheme: ColorScheme(
        brightness: Brightness.light,
        primary: AppColors.primary,
        onPrimary: AppColors.white,
        primaryContainer: AppColors.primaryLight,
        onPrimaryContainer: AppColors.white,
        secondary: AppColors.secondary,
        onSecondary: AppColors.white,
        secondaryContainer: AppColors.secondaryLight,
        onSecondaryContainer: AppColors.white,
        tertiary: AppColors.accent,
        onTertiary: AppColors.white,
        tertiaryContainer: AppColors.accentLight,
        onTertiaryContainer: AppColors.white,
        error: AppColors.error,
        onError: AppColors.white,
        errorContainer: Color(0xFFFDE0E0),
        onErrorContainer: AppColors.error,
        background: AppColors.background,
        onBackground: AppColors.textPrimary,
        surface: AppColors.surface,
        onSurface: AppColors.textPrimary,
        surfaceVariant: AppColors.surfaceLight,
        onSurfaceVariant: AppColors.textSecondary,
        outline: AppColors.border,
        shadow: AppColors.black.withOpacity(0.1),
      ),

      // Scaffolds, Cards, and Surfaces
      scaffoldBackgroundColor: AppColors.background,
      cardTheme: CardTheme(
        color: AppColors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        margin: EdgeInsets.zero,
      ),

      // Text Themes
      textTheme: TextTheme(
        // Display styles
        displayLarge: AppTypography.displayLargeStyle(),
        displayMedium: AppTypography.displayMediumStyle(),
        displaySmall: AppTypography.displaySmallStyle(),

        // Heading styles
        headlineLarge: AppTypography.headingLargeStyle(),
        headlineMedium: AppTypography.headingMediumStyle(),
        headlineSmall: AppTypography.headingSmallStyle(),

        // Body styles
        bodyLarge: AppTypography.bodyLargeStyle(),
        bodyMedium: AppTypography.bodyMediumStyle(),
        bodySmall: AppTypography.bodySmallStyle(),

        // Label styles
        labelLarge: AppTypography.labelLargeStyle(),
        labelMedium: AppTypography.labelMediumStyle(),
        labelSmall: AppTypography.labelSmallStyle(),

        // Other styles
        titleLarge: AppTypography.headingSmallStyle(),
        titleMedium: AppTypography.labelLargeStyle(),
        titleSmall: AppTypography.labelMediumStyle(),
      ),

      // App Bar Theme
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: AppTypography.headingSmallStyle(color: AppColors.white),
        iconTheme: IconThemeData(color: AppColors.white),
      ),

      // Button Themes
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          foregroundColor: AppColors.white,
          backgroundColor: AppColors.primary,
          disabledForegroundColor: AppColors.textDisabled,
          disabledBackgroundColor: AppColors.grey100,
          elevation: 0,
          textStyle: AppTypography.buttonMediumStyle(),
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          backgroundColor: Colors.transparent,
          disabledForegroundColor: AppColors.textDisabled,
          side: BorderSide(color: AppColors.primary, width: 1),
          elevation: 0,
          textStyle: AppTypography.buttonMediumStyle(color: AppColors.primary),
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          backgroundColor: Colors.transparent,
          disabledForegroundColor: AppColors.textDisabled,
          textStyle: AppTypography.buttonMediumStyle(color: AppColors.primary),
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        ),
      ),

      // Input Decoration Theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.white,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: BorderSide(color: AppColors.error, width: 2),
        ),
        labelStyle: AppTypography.labelMediumStyle(),
        hintStyle: AppTypography.bodyMediumStyle(color: AppColors.textTertiary),
        errorStyle: AppTypography.labelSmallStyle(color: AppColors.error),
      ),

      // Checkbox Theme
      checkboxTheme: CheckboxThemeData(
        fillColor: MaterialStateProperty.resolveWith<Color>((states) {
          if (states.contains(MaterialState.disabled)) {
            return AppColors.grey100;
          }
          if (states.contains(MaterialState.selected)) {
            return AppColors.primary;
          }
          return Colors.transparent;
        }),
        checkColor: MaterialStateProperty.all(AppColors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(2),
        ),
        side: BorderSide(color: AppColors.grey300),
      ),

      // Radio Button Theme
      radioTheme: RadioThemeData(
        fillColor: MaterialStateProperty.resolveWith<Color>((states) {
          if (states.contains(MaterialState.disabled)) {
            return AppColors.grey100;
          }
          if (states.contains(MaterialState.selected)) {
            return AppColors.primary;
          }
          return AppColors.grey300;
        }),
      ),

      // Switch Theme
      switchTheme: SwitchThemeData(
        thumbColor: MaterialStateProperty.resolveWith<Color>((states) {
          if (states.contains(MaterialState.disabled)) {
            return AppColors.grey100;
          }
          if (states.contains(MaterialState.selected)) {
            return AppColors.primary;
          }
          return AppColors.white;
        }),
        trackColor: MaterialStateProperty.resolveWith<Color>((states) {
          if (states.contains(MaterialState.disabled)) {
            return AppColors.grey100;
          }
          if (states.contains(MaterialState.selected)) {
            return AppColors.primary.withOpacity(0.5);
          }
          return AppColors.grey200;
        }),
      ),

      // Divider Theme
      dividerTheme: DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 1,
      ),

      // Tab Bar Theme
      tabBarTheme: TabBarTheme(
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.textSecondary,
        indicatorColor: AppColors.primary,
        labelStyle: AppTypography.labelLargeStyle(),
        unselectedLabelStyle: AppTypography.labelLargeStyle(),
      ),

      // Dialog Theme
      dialogTheme: DialogTheme(
        backgroundColor: AppColors.white,
        elevation: 24,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),

      // Tooltip Theme
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: AppColors.grey500,
          borderRadius: BorderRadius.circular(4),
        ),
        textStyle: AppTypography.bodySmallStyle(color: AppColors.white),
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),

      // Snackbar Theme
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.grey500,
        contentTextStyle: AppTypography.bodyMediumStyle(color: AppColors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
        ),
        behavior: SnackBarBehavior.floating,
      ),

      // Progress Indicator Theme
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: AppColors.primary,
        circularTrackColor: AppColors.grey100,
        linearTrackColor: AppColors.grey100,
      ),

      // Icon Theme
      iconTheme: IconThemeData(
        color: AppColors.textSecondary,
        size: 24,
      ),

      // Font Family
      fontFamily: AppTypography.primaryFontFamily,

      // Material 3 Settings
      useMaterial3: true,
    );

    // Add the AppTheme extension to the ThemeData
    return themeData.copyWith(
      extensions: [
        AppTheme._(
          themeData: themeData,
          colors: AppColors(),
          typography: AppTypography(),
          surfaceColor: AppColors.white,
          dividerColor: AppColors.border,
          primaryColor: AppColors.primary,
        ),
      ],
    );
  }

  // Dark Theme (if needed in the future)
  static ThemeData darkTheme() {
    // For now, return the light theme
    // This can be expanded later if dark theme is required
    return lightTheme();
  }
}
