import 'package:flutter/material.dart';
import '../colors/app_colors.dart';
import '../typography/app_typography.dart';
import '../responsive/responsive_layout.dart';

/// AppSidebar provides a consistent sidebar navigation component across the application.
/// It supports collapsible state and adapts to different screen sizes.
class AppSidebar extends StatefulWidget {
  final List<AppSidebarItem> items;
  final int selectedIndex;
  final Function(int) onItemSelected;
  final bool isCollapsed;
  final VoidCallback? onToggleCollapsed;
  final Widget? header;
  final Widget? footer;
  final Color backgroundColor;
  final Color selectedItemColor;
  final Color unselectedItemColor;
  final bool showDividers;
  final bool showIcons;
  final double width;
  final double collapsedWidth;

  const AppSidebar({
    Key? key,
    required this.items,
    required this.selectedIndex,
    required this.onItemSelected,
    this.isCollapsed = false,
    this.onToggleCollapsed,
    this.header,
    this.footer,
    this.backgroundColor = Colors.white,
    this.selectedItemColor = AppColors.primary,
    this.unselectedItemColor = AppColors.textSecondary,
    this.showDividers = false,
    this.showIcons = true,
    this.width = 250,
    this.collapsedWidth = 70,
  }) : super(key: key);

  @override
  State<AppSidebar> createState() => _AppSidebarState();
}

class _AppSidebarState extends State<AppSidebar>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _widthAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 200),
    );

    _updateAnimation();

    if (widget.isCollapsed) {
      _animationController.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(AppSidebar oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.isCollapsed != widget.isCollapsed) {
      _updateAnimation();

      if (widget.isCollapsed) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    }
  }

  void _updateAnimation() {
    _widthAnimation = Tween<double>(
      begin: widget.width,
      end: widget.collapsedWidth,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        final isCollapsed = _animationController.value > 0.5;

        return Container(
          width: _widthAnimation.value,
          color: widget.backgroundColor,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.header != null) _buildHeader(isCollapsed),
              if (widget.onToggleCollapsed != null &&
                  !ResponsiveLayout.isMobile(context))
                _buildCollapseButton(isCollapsed),
              Expanded(
                child: ListView.separated(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  itemCount: widget.items.length,
                  separatorBuilder: (context, index) => widget.showDividers
                      ? Divider(
                          height: 1, thickness: 1, color: AppColors.border)
                      : SizedBox(height: 4),
                  itemBuilder: (context, index) => _buildSidebarItem(
                    widget.items[index],
                    index,
                    isCollapsed,
                  ),
                ),
              ),
              if (widget.footer != null) _buildFooter(isCollapsed),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(bool isCollapsed) {
    return Container(
      height: 64,
      padding: EdgeInsets.symmetric(
        horizontal: isCollapsed ? 8 : 16,
        vertical: 8,
      ),
      child: isCollapsed
          ? Center(
              child: widget.header is Image
                  ? widget.header
                  : Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      child: widget.header,
                    ),
            )
          : widget.header,
    );
  }

  Widget _buildFooter(bool isCollapsed) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isCollapsed ? 8 : 16,
        vertical: 16,
      ),
      child: isCollapsed
          ? Center(
              child: Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                child: widget.footer,
              ),
            )
          : widget.footer,
    );
  }

  Widget _buildCollapseButton(bool isCollapsed) {
    return InkWell(
      onTap: widget.onToggleCollapsed,
      child: Container(
        height: 40,
        padding: EdgeInsets.symmetric(horizontal: isCollapsed ? 8 : 16),
        child: Row(
          mainAxisAlignment:
              isCollapsed ? MainAxisAlignment.center : MainAxisAlignment.end,
          children: [
            Icon(
              isCollapsed ? Icons.chevron_right : Icons.chevron_left,
              color: AppColors.grey300,
              size: 20,
            ),
            if (!isCollapsed) ...[
              SizedBox(width: 4),
              Text(
                'Collapse',
                style: AppTypography.labelSmall(color: AppColors.grey300),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSidebarItem(AppSidebarItem item, int index, bool isCollapsed) {
    final isSelected = index == widget.selectedIndex;
    final textColor =
        isSelected ? widget.selectedItemColor : widget.unselectedItemColor;
    final backgroundColor = isSelected
        ? widget.selectedItemColor.withOpacity(0.1)
        : Colors.transparent;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => widget.onItemSelected(index),
        child: Container(
          height: 48,
          padding: EdgeInsets.symmetric(horizontal: isCollapsed ? 8 : 16),
          decoration: BoxDecoration(
            color: backgroundColor,
            border: isSelected
                ? Border(
                    left: BorderSide(
                      color: widget.selectedItemColor,
                      width: 4,
                    ),
                  )
                : null,
          ),
          child: isCollapsed
              ? _buildCollapsedItem(item, textColor)
              : _buildExpandedItem(item, textColor),
        ),
      ),
    );
  }

  Widget _buildCollapsedItem(AppSidebarItem item, Color textColor) {
    return Center(
      child: widget.showIcons && item.icon != null
          ? Icon(
              item.icon,
              color: textColor,
              size: 24,
            )
          : Container(
              width: 24,
              height: 24,
              alignment: Alignment.center,
              child: Text(
                item.label.substring(0, 1),
                style: AppTypography.labelMedium(color: textColor),
              ),
            ),
    );
  }

  Widget _buildExpandedItem(AppSidebarItem item, Color textColor) {
    return Row(
      children: [
        if (widget.showIcons && item.icon != null) ...[
          Icon(
            item.icon,
            color: textColor,
            size: 20,
          ),
          SizedBox(width: 12),
        ],
        Expanded(
          child: Text(
            item.label,
            style: AppTypography.labelLarge(color: textColor),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (item.badge != null) ...[
          SizedBox(width: 8),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              item.badge!,
              style: AppTypography.labelSmall(color: AppColors.white),
            ),
          ),
        ],
      ],
    );
  }
}

/// Model for sidebar items
class AppSidebarItem {
  final String label;
  final IconData? icon;
  final String? badge;
  final List<AppSidebarItem>? children;

  const AppSidebarItem({
    required this.label,
    this.icon,
    this.badge,
    this.children,
  });
}
