import 'package:flutter/material.dart';
import '../colors/app_colors.dart';
import '../typography/app_text_styles.dart';

/// MessageType defines the different types of messages that can be displayed.
enum MessageType {
  /// Informational message (blue)
  info,

  /// Success message (green)
  success,

  /// Warning message (orange/amber)
  warning,

  /// Error message (red)
  error,
}

/// AppMessage provides a consistent way to display various types of messages.
class AppMessage extends StatelessWidget {
  /// The message to display.
  final String message;

  /// The type of message (info, success, warning, error).
  final MessageType type;

  /// Optional title for the message.
  final String? title;

  /// Optional icon to display.
  final IconData? icon;

  /// Whether the message is dismissible.
  final bool isDismissible;

  /// Optional callback when the message is dismissed.
  final VoidCallback? onDismiss;

  const AppMessage({
    Key? key,
    required this.message,
    this.type = MessageType.info,
    this.title,
    this.icon,
    this.isDismissible = false,
    this.onDismiss,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final messageConfig = _getMessageConfig();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: messageConfig.backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: messageConfig.borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon ?? messageConfig.icon,
            color: messageConfig.iconColor,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (title != null) ...[
                  Text(
                    title!,
                    style: AppTextStyles.labelLarge.copyWith(
                      color: messageConfig.textColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
                Text(
                  message,
                  style: AppTextStyles.body.copyWith(
                    color: messageConfig.textColor,
                  ),
                ),
              ],
            ),
          ),
          if (isDismissible)
            IconButton(
              icon: const Icon(Icons.close, size: 16),
              onPressed: onDismiss,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(
                minWidth: 24,
                minHeight: 24,
              ),
              color: messageConfig.iconColor,
              splashRadius: 20,
            ),
        ],
      ),
    );
  }

  /// Get the configuration for the message based on its type.
  _MessageConfig _getMessageConfig() {
    switch (type) {
      case MessageType.info:
        return _MessageConfig(
          backgroundColor: AppColors.infoLight,
          borderColor: AppColors.infoBorder,
          textColor: AppColors.infoText,
          iconColor: AppColors.info,
          icon: Icons.info_outline,
        );
      case MessageType.success:
        return _MessageConfig(
          backgroundColor: AppColors.successLight,
          borderColor: AppColors.successBorder,
          textColor: AppColors.successText,
          iconColor: AppColors.success,
          icon: Icons.check_circle_outline,
        );
      case MessageType.warning:
        return _MessageConfig(
          backgroundColor: AppColors.warningLight,
          borderColor: AppColors.warningBorder,
          textColor: AppColors.warningText,
          iconColor: AppColors.warning,
          icon: Icons.warning_amber_outlined,
        );
      case MessageType.error:
        return _MessageConfig(
          backgroundColor: AppColors.errorLight,
          borderColor: AppColors.errorBorder,
          textColor: AppColors.errorText,
          iconColor: AppColors.error,
          icon: Icons.error_outline,
        );
    }
  }

  /// Shows a snackbar message.
  static void showSnackbar({
    required BuildContext context,
    required String message,
    MessageType type = MessageType.info,
    String? title,
    Duration duration = const Duration(seconds: 4),
    SnackBarAction? action,
  }) {
    final messageConfig = _getSnackbarConfig(type);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              messageConfig.icon,
              color: messageConfig.iconColor,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: AppTextStyles.body.copyWith(
                  color: messageConfig.textColor,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: messageConfig.backgroundColor,
        duration: duration,
        action: action,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
        ),
        margin: const EdgeInsets.all(8),
      ),
    );
  }

  /// Get the configuration for a snackbar based on its type.
  static _MessageConfig _getSnackbarConfig(MessageType type) {
    switch (type) {
      case MessageType.info:
        return _MessageConfig(
          backgroundColor: AppColors.info,
          borderColor: AppColors.infoBorder,
          textColor: Colors.white,
          iconColor: Colors.white,
          icon: Icons.info_outline,
        );
      case MessageType.success:
        return _MessageConfig(
          backgroundColor: AppColors.success,
          borderColor: AppColors.successBorder,
          textColor: Colors.white,
          iconColor: Colors.white,
          icon: Icons.check_circle_outline,
        );
      case MessageType.warning:
        return _MessageConfig(
          backgroundColor: AppColors.warning,
          borderColor: AppColors.warningBorder,
          textColor: Colors.white,
          iconColor: Colors.white,
          icon: Icons.warning_amber_outlined,
        );
      case MessageType.error:
        return _MessageConfig(
          backgroundColor: AppColors.error,
          borderColor: AppColors.errorBorder,
          textColor: Colors.white,
          iconColor: Colors.white,
          icon: Icons.error_outline,
        );
    }
  }
}

/// Configuration for a message.
class _MessageConfig {
  final Color backgroundColor;
  final Color borderColor;
  final Color textColor;
  final Color iconColor;
  final IconData icon;

  _MessageConfig({
    required this.backgroundColor,
    required this.borderColor,
    required this.textColor,
    required this.iconColor,
    required this.icon,
  });
}
