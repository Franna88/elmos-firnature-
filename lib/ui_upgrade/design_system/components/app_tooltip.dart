import 'package:flutter/material.dart';
import '../colors/app_colors.dart';
import '../typography/app_text_styles.dart';

/// AppTooltip provides a consistent way to display tooltips across the application.
/// It extends the standard Flutter Tooltip with custom styling and additional features.
class AppTooltip extends StatelessWidget {
  /// The message to display in the tooltip.
  final String message;

  /// The child widget that the tooltip will be displayed for.
  final Widget child;

  /// The preferred position of the tooltip relative to the child.
  final TooltipPosition position;

  /// Whether the tooltip should show instantly or with a delay.
  final bool showInstantly;

  /// Optional rich text content for the tooltip.
  final Widget? richContent;

  /// Whether the tooltip should have an arrow pointing to the child.
  final bool showArrow;

  /// Optional maximum width for the tooltip.
  final double? maxWidth;

  const AppTooltip({
    Key? key,
    required this.message,
    required this.child,
    this.position = TooltipPosition.auto,
    this.showInstantly = false,
    this.richContent,
    this.showArrow = true,
    this.maxWidth,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Determine the preferred tooltip position
    AxisDirection preferredDirection;
    switch (position) {
      case TooltipPosition.above:
        preferredDirection = AxisDirection.up;
        break;
      case TooltipPosition.below:
        preferredDirection = AxisDirection.down;
        break;
      case TooltipPosition.left:
        preferredDirection = AxisDirection.left;
        break;
      case TooltipPosition.right:
        preferredDirection = AxisDirection.right;
        break;
      case TooltipPosition.auto:
      default:
        preferredDirection = AxisDirection.down;
        break;
    }

    return Tooltip(
      message: richContent == null ? message : '',
      preferBelow: preferredDirection == AxisDirection.down,
      waitDuration:
          showInstantly ? Duration.zero : const Duration(milliseconds: 500),
      showDuration: const Duration(seconds: 2),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.grey500,
        borderRadius: BorderRadius.circular(4),
      ),
      textStyle: AppTextStyles.bodySmall.copyWith(color: AppColors.white),
      child: richContent == null
          ? child
          : _CustomTooltip(
              message: message,
              content: richContent!,
              position: position,
              showArrow: showArrow,
              maxWidth: maxWidth,
              child: child,
            ),
    );
  }
}

/// Custom tooltip implementation for rich content.
class _CustomTooltip extends StatefulWidget {
  final String message;
  final Widget content;
  final Widget child;
  final TooltipPosition position;
  final bool showArrow;
  final double? maxWidth;

  const _CustomTooltip({
    Key? key,
    required this.message,
    required this.content,
    required this.child,
    required this.position,
    required this.showArrow,
    this.maxWidth,
  }) : super(key: key);

  @override
  _CustomTooltipState createState() => _CustomTooltipState();
}

class _CustomTooltipState extends State<_CustomTooltip> {
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  bool _isTooltipVisible = false;

  @override
  void dispose() {
    _hideTooltip();
    super.dispose();
  }

  void _showTooltip() {
    if (_isTooltipVisible) return;

    _overlayEntry = _createOverlayEntry();
    Overlay.of(context).insert(_overlayEntry!);
    setState(() {
      _isTooltipVisible = true;
    });

    // Auto-hide after 2 seconds
    Future.delayed(const Duration(seconds: 2), () {
      _hideTooltip();
    });
  }

  void _hideTooltip() {
    if (_overlayEntry != null) {
      _overlayEntry!.remove();
      _overlayEntry = null;
      if (mounted) {
        setState(() {
          _isTooltipVisible = false;
        });
      }
    }
  }

  OverlayEntry _createOverlayEntry() {
    return OverlayEntry(
      builder: (context) {
        return Positioned(
          width: widget.maxWidth ?? 250,
          child: CompositedTransformFollower(
            link: _layerLink,
            showWhenUnlinked: false,
            offset: _getOffset(),
            child: Material(
              color: Colors.transparent,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.grey500,
                  borderRadius: BorderRadius.circular(4),
                ),
                padding: const EdgeInsets.all(8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.message.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          widget.message,
                          style: AppTextStyles.labelLarge.copyWith(
                            color: AppColors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    widget.content,
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Offset _getOffset() {
    // Default offset for below position
    Offset offset = const Offset(0, 8);

    switch (widget.position) {
      case TooltipPosition.above:
        offset = const Offset(0, -8);
        break;
      case TooltipPosition.below:
        offset = const Offset(0, 8);
        break;
      case TooltipPosition.left:
        offset = const Offset(-8, 0);
        break;
      case TooltipPosition.right:
        offset = const Offset(8, 0);
        break;
      case TooltipPosition.auto:
        // Auto positioning would need more complex logic based on available space
        offset = const Offset(0, 8);
        break;
    }

    return offset;
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (_isTooltipVisible) {
            _hideTooltip();
          } else {
            _showTooltip();
          }
        },
        child: MouseRegion(
          onEnter: (_) => _showTooltip(),
          onExit: (_) => _hideTooltip(),
          child: widget.child,
        ),
      ),
    );
  }
}

/// Helper widget for displaying an info icon with a tooltip.
class InfoTooltip extends StatelessWidget {
  /// The message to display in the tooltip.
  final String message;

  /// Optional rich content for the tooltip.
  final Widget? richContent;

  /// The size of the info icon.
  final double iconSize;

  /// The color of the info icon.
  final Color? iconColor;

  const InfoTooltip({
    Key? key,
    required this.message,
    this.richContent,
    this.iconSize = 16,
    this.iconColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AppTooltip(
      message: message,
      richContent: richContent,
      child: Icon(
        Icons.info_outline,
        size: iconSize,
        color: iconColor ?? AppColors.info,
      ),
    );
  }
}

/// Defines the position of the tooltip relative to the child widget.
enum TooltipPosition {
  /// Display the tooltip above the child.
  above,

  /// Display the tooltip below the child.
  below,

  /// Display the tooltip to the left of the child.
  left,

  /// Display the tooltip to the right of the child.
  right,

  /// Automatically determine the best position based on available space.
  auto,
}
