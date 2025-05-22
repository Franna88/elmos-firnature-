import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

/// AppCard provides a consistent card component across the application.
/// It supports different variants and can include headers, footers, and various content layouts.
class AppCard extends StatelessWidget {
  final Widget? header;
  final Widget content;
  final Widget? footer;
  final CardVariant variant;
  final double? width;
  final double? height;
  final EdgeInsets padding;
  final EdgeInsets margin;
  final BorderRadius? borderRadius;
  final bool hasShadow;
  final bool hasBorder;
  final VoidCallback? onTap;
  final bool isLoading;

  const AppCard({
    Key? key,
    this.header,
    required this.content,
    this.footer,
    this.variant = CardVariant.elevated,
    this.width,
    this.height,
    this.padding = const EdgeInsets.all(16),
    this.margin = const EdgeInsets.all(0),
    this.borderRadius,
    this.hasShadow = true,
    this.hasBorder = true,
    this.onTap,
    this.isLoading = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final effectiveBorderRadius = borderRadius ?? BorderRadius.circular(8);

    // Determine card decoration based on variant
    BoxDecoration decoration;
    switch (variant) {
      case CardVariant.elevated:
        decoration = BoxDecoration(
          color: AppColors.white,
          borderRadius: effectiveBorderRadius,
          border: hasBorder ? Border.all(color: AppColors.border) : null,
          boxShadow: hasShadow
              ? [
                  BoxShadow(
                    color: AppColors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ]
              : null,
        );
        break;
      case CardVariant.flat:
        decoration = BoxDecoration(
          color: AppColors.white,
          borderRadius: effectiveBorderRadius,
          border: hasBorder ? Border.all(color: AppColors.border) : null,
        );
        break;
      case CardVariant.outlined:
        decoration = BoxDecoration(
          color: AppColors.white,
          borderRadius: effectiveBorderRadius,
          border: Border.all(color: AppColors.border, width: 1),
        );
        break;
      case CardVariant.filled:
        decoration = BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: effectiveBorderRadius,
          border: hasBorder ? Border.all(color: AppColors.border) : null,
        );
        break;
    }

    // Build card content
    Widget cardContent = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (header != null) ...[
          header!,
          Divider(height: 1, thickness: 1, color: AppColors.border),
        ],
        Padding(
          padding: padding,
          child: content,
        ),
        if (footer != null) ...[
          Divider(height: 1, thickness: 1, color: AppColors.border),
          footer!,
        ],
      ],
    );

    // Add loading state if needed
    if (isLoading) {
      cardContent = Stack(
        children: [
          cardContent,
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.white.withOpacity(0.7),
                borderRadius: effectiveBorderRadius,
              ),
              child: Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              ),
            ),
          ),
        ],
      );
    }

    // Wrap in InkWell if onTap is provided
    Widget finalCard = Container(
      width: width,
      height: height,
      margin: margin,
      decoration: decoration,
      clipBehavior: Clip.antiAlias,
      child: cardContent,
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: effectiveBorderRadius,
          child: finalCard,
        ),
      );
    }

    return finalCard;
  }
}

/// Standard card header with title and optional action
class AppCardHeader extends StatelessWidget {
  final String title;
  final Widget? action;
  final EdgeInsets padding;

  const AppCardHeader({
    Key? key,
    required this.title,
    this.action,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleLarge,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (action != null) action!,
        ],
      ),
    );
  }
}

/// Standard card footer with actions
class AppCardFooter extends StatelessWidget {
  final List<Widget> actions;
  final MainAxisAlignment alignment;
  final EdgeInsets padding;

  const AppCardFooter({
    Key? key,
    required this.actions,
    this.alignment = MainAxisAlignment.end,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        mainAxisAlignment: alignment,
        children: actions.map((action) {
          final index = actions.indexOf(action);
          return Padding(
            padding: EdgeInsets.only(
              left: index > 0 ? 8 : 0,
            ),
            child: action,
          );
        }).toList(),
      ),
    );
  }
}

/// Card variants for different use cases
enum CardVariant {
  elevated, // Card with shadow and border
  flat, // Card with no shadow
  outlined, // Card with border only
  filled, // Card with background color
}
