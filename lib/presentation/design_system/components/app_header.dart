import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../responsive/responsive_layout.dart';

/// AppHeader provides a consistent header/navigation bar across the application.
/// It adapts to different screen sizes and includes navigation elements.
class AppHeader extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<AppHeaderAction>? actions;
  final Widget? leading;
  final bool automaticallyImplyLeading;
  final bool centerTitle;
  final Widget? flexibleSpace;
  final PreferredSizeWidget? bottom;
  final double elevation;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final bool showSearchBar;
  final Function(String)? onSearch;
  final VoidCallback? onMenuPressed;

  const AppHeader({
    Key? key,
    required this.title,
    this.actions,
    this.leading,
    this.automaticallyImplyLeading = true,
    this.centerTitle = false,
    this.flexibleSpace,
    this.bottom,
    this.elevation = 0,
    this.backgroundColor,
    this.foregroundColor,
    this.showSearchBar = false,
    this.onSearch,
    this.onMenuPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveLayout.isTabletOrDesktop(context);

    return AppBar(
      title: Text(
        title,
        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: foregroundColor ?? AppColors.white,
            ),
      ),
      centerTitle: centerTitle,
      backgroundColor: backgroundColor ?? AppColors.primary,
      foregroundColor: foregroundColor ?? AppColors.white,
      elevation: elevation,
      automaticallyImplyLeading: automaticallyImplyLeading,
      leading: _buildLeading(context),
      actions: _buildActions(context, isDesktop),
      flexibleSpace: flexibleSpace,
      bottom: bottom != null
          ? PreferredSize(
              preferredSize: bottom!.preferredSize,
              child: bottom!,
            )
          : showSearchBar
              ? _buildSearchBar()
              : null,
    );
  }

  Widget? _buildLeading(BuildContext context) {
    if (leading != null) {
      return leading;
    }

    if (!ResponsiveLayout.isTabletOrDesktop(context) && onMenuPressed != null) {
      return IconButton(
        icon: Icon(Icons.menu),
        onPressed: onMenuPressed,
        tooltip: 'Menu',
      );
    }

    return null;
  }

  List<Widget>? _buildActions(BuildContext context, bool isDesktop) {
    if (actions == null || actions!.isEmpty) {
      return null;
    }

    return actions!.map((action) {
      // For desktop, show full buttons with text
      if (isDesktop && action.label != null) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Center(
            child: action.showAsButton
                ? ElevatedButton.icon(
                    icon: Icon(action.icon, size: 18),
                    label: Text(action.label!),
                    onPressed: action.onPressed,
                    style: ElevatedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      backgroundColor: AppColors.white,
                    ),
                  )
                : TextButton.icon(
                    icon: Icon(action.icon, size: 18),
                    label: Text(action.label!),
                    onPressed: action.onPressed,
                    style: TextButton.styleFrom(
                      foregroundColor: foregroundColor ?? AppColors.white,
                    ),
                  ),
          ),
        );
      }

      // For mobile, show icon buttons
      return IconButton(
        icon: Icon(action.icon),
        onPressed: action.onPressed,
        tooltip: action.label,
      );
    }).toList();
  }

  PreferredSizeWidget _buildSearchBar() {
    return PreferredSize(
      preferredSize: Size.fromHeight(56),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: TextField(
          onChanged: onSearch,
          style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Search...',
            hintStyle: TextStyle(color: AppColors.textTertiary, fontSize: 14),
            filled: true,
            fillColor: AppColors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: BorderSide.none,
            ),
            prefixIcon: Icon(Icons.search, color: AppColors.grey300),
            contentPadding: EdgeInsets.symmetric(vertical: 0, horizontal: 16),
          ),
        ),
      ),
    );
  }

  @override
  Size get preferredSize {
    double height = kToolbarHeight;

    if (bottom != null) {
      height += bottom!.preferredSize.height;
    } else if (showSearchBar) {
      height += 56;
    }

    return Size.fromHeight(height);
  }
}

/// Model for header action items
class AppHeaderAction {
  final IconData icon;
  final String? label;
  final VoidCallback onPressed;
  final bool showAsButton;

  const AppHeaderAction({
    required this.icon,
    this.label,
    required this.onPressed,
    this.showAsButton = false,
  });
}
