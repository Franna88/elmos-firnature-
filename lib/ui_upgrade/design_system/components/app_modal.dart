import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../colors/app_colors.dart';
import '../typography/app_text_styles.dart';
import 'app_button.dart';

/// A customizable modal dialog component that follows the Elmos Furniture design system.
///
/// This component provides a consistent way to display modal dialogs across the application,
/// with support for different sizes, content types, and action buttons.
class AppModal extends StatelessWidget {
  /// The title of the modal dialog.
  final String title;

  /// The main content of the modal dialog.
  final Widget content;

  /// Optional footer actions (typically buttons).
  final List<Widget>? actions;

  /// Controls the width of the modal.
  final AppModalSize size;

  /// Whether the modal can be dismissed by clicking outside or pressing escape.
  final bool isDismissible;

  /// Optional icon to display in the header.
  final IconData? headerIcon;

  /// Optional color for the header icon.
  final Color? headerIconColor;

  /// Optional callback when the modal is closed.
  final VoidCallback? onClose;

  const AppModal({
    Key? key,
    required this.title,
    required this.content,
    this.actions,
    this.size = AppModalSize.medium,
    this.isDismissible = true,
    this.headerIcon,
    this.headerIconColor,
    this.onClose,
  }) : super(key: key);

  /// Shows a modal dialog using the AppModal component.
  static Future<T?> show<T>({
    required BuildContext context,
    required String title,
    required Widget content,
    List<Widget>? actions,
    AppModalSize size = AppModalSize.medium,
    bool isDismissible = true,
    IconData? headerIcon,
    Color? headerIconColor,
    VoidCallback? onClose,
  }) {
    return showDialog<T>(
      context: context,
      barrierDismissible: isDismissible,
      builder: (BuildContext context) {
        return AppModal(
          title: title,
          content: content,
          actions: actions,
          size: size,
          isDismissible: isDismissible,
          headerIcon: headerIcon,
          headerIconColor: headerIconColor,
          onClose: onClose,
        );
      },
    );
  }

  /// Shows a confirmation dialog with customizable buttons.
  static Future<bool?> showConfirmation({
    required BuildContext context,
    required String title,
    required String message,
    String confirmText = 'Confirm',
    String cancelText = 'Cancel',
    bool isDanger = false,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AppModal(
          title: title,
          content: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              message,
              style: AppTextStyles.body,
            ),
          ),
          actions: [
            AppButton(
              label: cancelText,
              variant: ButtonVariant.tertiary,
              onPressed: () => Navigator.of(context).pop(false),
            ),
            AppButton(
              label: confirmText,
              variant: isDanger ? ButtonVariant.danger : ButtonVariant.primary,
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
          size: AppModalSize.small,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appTheme = AppTheme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
      ),
      elevation: 8,
      backgroundColor: AppColors.white,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: _getModalWidth(context),
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(context),
            Flexible(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24.0, vertical: 16.0),
                  child: content,
                ),
              ),
            ),
            if (actions != null && actions!.isNotEmpty) _buildFooter(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12.0),
          topRight: Radius.circular(12.0),
        ),
        border: Border(
          bottom: BorderSide(
            color: AppColors.border,
            width: 1.0,
          ),
        ),
      ),
      child: Row(
        children: [
          if (headerIcon != null)
            Padding(
              padding: const EdgeInsets.only(right: 12.0),
              child: Icon(
                headerIcon,
                color: headerIconColor ?? AppColors.primary,
                size: 24.0,
              ),
            ),
          Expanded(
            child: Text(
              title,
              style: AppTextStyles.h3,
            ),
          ),
          if (isDismissible)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                if (onClose != null) {
                  onClose!();
                }
                Navigator.of(context).pop();
              },
              color: AppColors.grey400,
              splashRadius: 20.0,
              tooltip: 'Close',
            ),
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(12.0),
          bottomRight: Radius.circular(12.0),
        ),
        border: Border(
          top: BorderSide(
            color: AppColors.border,
            width: 1.0,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: actions!.map((action) {
          return Padding(
            padding: const EdgeInsets.only(left: 8.0),
            child: action,
          );
        }).toList(),
      ),
    );
  }

  double _getModalWidth(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    switch (size) {
      case AppModalSize.small:
        return screenWidth < 600 ? screenWidth * 0.9 : 400;
      case AppModalSize.medium:
        return screenWidth < 900 ? screenWidth * 0.8 : 600;
      case AppModalSize.large:
        return screenWidth < 1200 ? screenWidth * 0.85 : 800;
      case AppModalSize.fullWidth:
        return screenWidth * 0.95;
    }
  }
}

/// Defines the available sizes for the AppModal component.
enum AppModalSize {
  /// Small modal dialog (400px).
  small,

  /// Medium modal dialog (600px).
  medium,

  /// Large modal dialog (800px).
  large,

  /// Full width modal dialog (95% of screen width).
  fullWidth,
}
