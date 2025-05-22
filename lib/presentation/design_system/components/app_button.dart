import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

/// AppButton provides consistent button styles across the application.
/// It supports primary, secondary, and tertiary button variants with different sizes.
class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final ButtonVariant variant;
  final ButtonSize size;
  final bool isFullWidth;
  final bool isLoading;
  final IconData? leadingIcon;
  final IconData? trailingIcon;

  const AppButton({
    Key? key,
    required this.label,
    this.onPressed,
    this.variant = ButtonVariant.primary,
    this.size = ButtonSize.medium,
    this.isFullWidth = false,
    this.isLoading = false,
    this.leadingIcon,
    this.trailingIcon,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Determine button style based on variant and size
    final buttonStyle = _getButtonStyle();

    // Determine text style based on size
    final textStyle = _getTextStyle();

    // Determine padding based on size
    final padding = _getPadding();

    // Create button content with optional loading indicator and icons
    Widget buttonContent = Row(
      mainAxisSize: isFullWidth ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isLoading) ...[
          SizedBox(
            width: _getLoadingSize(),
            height: _getLoadingSize(),
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(_getLoadingColor()),
            ),
          ),
          SizedBox(width: 8),
        ] else if (leadingIcon != null) ...[
          Icon(leadingIcon, size: _getIconSize()),
          SizedBox(width: 8),
        ],
        Text(label, style: textStyle),
        if (trailingIcon != null && !isLoading) ...[
          SizedBox(width: 8),
          Icon(trailingIcon, size: _getIconSize()),
        ],
      ],
    );

    // Create the button with appropriate style
    Widget button;
    switch (variant) {
      case ButtonVariant.primary:
      case ButtonVariant.success:
      case ButtonVariant.danger:
        button = ElevatedButton(
          onPressed: isLoading ? null : onPressed,
          style: buttonStyle,
          child: buttonContent,
        );
        break;
      case ButtonVariant.secondary:
        button = OutlinedButton(
          onPressed: isLoading ? null : onPressed,
          style: buttonStyle,
          child: buttonContent,
        );
        break;
      case ButtonVariant.tertiary:
        button = TextButton(
          onPressed: isLoading ? null : onPressed,
          style: buttonStyle,
          child: buttonContent,
        );
        break;
    }

    // Apply full width if needed
    if (isFullWidth) {
      return SizedBox(width: double.infinity, child: button);
    }

    return button;
  }

  // Helper methods
  ButtonStyle _getButtonStyle() {
    switch (variant) {
      case ButtonVariant.primary:
        return ElevatedButton.styleFrom(
          foregroundColor: AppColors.white,
          backgroundColor: AppColors.primary,
          disabledForegroundColor: AppColors.textDisabled,
          disabledBackgroundColor: AppColors.grey100,
          padding: _getPadding(),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
          ),
        );
      case ButtonVariant.secondary:
        return OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          disabledForegroundColor: AppColors.textDisabled,
          padding: _getPadding(),
          side: BorderSide(color: AppColors.primary),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
          ),
        );
      case ButtonVariant.tertiary:
        return TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          disabledForegroundColor: AppColors.textDisabled,
          padding: _getPadding(),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
          ),
        );
      case ButtonVariant.success:
        return ElevatedButton.styleFrom(
          foregroundColor: AppColors.white,
          backgroundColor: AppColors.success,
          disabledForegroundColor: AppColors.textDisabled,
          disabledBackgroundColor: AppColors.grey100,
          padding: _getPadding(),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
          ),
        );
      case ButtonVariant.danger:
        return ElevatedButton.styleFrom(
          foregroundColor: AppColors.white,
          backgroundColor: AppColors.error,
          disabledForegroundColor: AppColors.textDisabled,
          disabledBackgroundColor: AppColors.grey100,
          padding: _getPadding(),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
          ),
        );
    }
  }

  TextStyle _getTextStyle() {
    Color textColor;
    switch (variant) {
      case ButtonVariant.primary:
      case ButtonVariant.success:
      case ButtonVariant.danger:
        textColor = AppColors.white;
        break;
      case ButtonVariant.secondary:
      case ButtonVariant.tertiary:
        textColor = AppColors.primary;
        break;
    }

    switch (size) {
      case ButtonSize.small:
        return TextStyle(
          color: textColor,
          fontSize: 12,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.5,
        );
      case ButtonSize.medium:
        return TextStyle(
          color: textColor,
          fontSize: 14,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.5,
        );
      case ButtonSize.large:
        return TextStyle(
          color: textColor,
          fontSize: 16,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.5,
        );
    }
  }

  EdgeInsets _getPadding() {
    switch (size) {
      case ButtonSize.small:
        return EdgeInsets.symmetric(horizontal: 12, vertical: 8);
      case ButtonSize.medium:
        return EdgeInsets.symmetric(horizontal: 16, vertical: 12);
      case ButtonSize.large:
        return EdgeInsets.symmetric(horizontal: 24, vertical: 16);
    }
  }

  double _getIconSize() {
    switch (size) {
      case ButtonSize.small:
        return 16;
      case ButtonSize.medium:
        return 20;
      case ButtonSize.large:
        return 24;
    }
  }

  double _getLoadingSize() {
    switch (size) {
      case ButtonSize.small:
        return 14;
      case ButtonSize.medium:
        return 18;
      case ButtonSize.large:
        return 22;
    }
  }

  Color _getLoadingColor() {
    switch (variant) {
      case ButtonVariant.primary:
      case ButtonVariant.success:
      case ButtonVariant.danger:
        return AppColors.white;
      case ButtonVariant.secondary:
      case ButtonVariant.tertiary:
        return AppColors.primary;
    }
  }
}

/// Button variants for different use cases
enum ButtonVariant {
  primary, // Main actions
  secondary, // Secondary actions
  tertiary, // Subtle actions
  success, // Positive actions
  danger, // Destructive actions
}

/// Button sizes for different contexts
enum ButtonSize {
  small, // Compact UI elements
  medium, // Standard UI elements
  large, // Prominent UI elements
}
