import 'package:flutter/material.dart';
import '../components/app_header.dart';
import '../components/app_sidebar.dart';
import '../responsive/responsive_layout.dart';

/// AppScaffold provides a consistent layout structure across the application.
/// It combines the header and sidebar components into a responsive layout.
class AppScaffold extends StatefulWidget {
  final String title;
  final List<AppSidebarItem> sidebarItems;
  final int selectedSidebarIndex;
  final Function(int) onSidebarItemSelected;
  final Widget body;
  final List<AppHeaderAction>? actions;
  final Widget? sidebarHeader;
  final Widget? sidebarFooter;
  final bool showSearchBar;
  final Function(String)? onSearch;
  final PreferredSizeWidget? bottomAppBar;
  final bool extendBodyBehindAppBar;
  final Color? backgroundColor;
  final bool resizeToAvoidBottomInset;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final Widget? bottomNavigationBar;

  const AppScaffold({
    Key? key,
    required this.title,
    required this.sidebarItems,
    required this.selectedSidebarIndex,
    required this.onSidebarItemSelected,
    required this.body,
    this.actions,
    this.sidebarHeader,
    this.sidebarFooter,
    this.showSearchBar = false,
    this.onSearch,
    this.bottomAppBar,
    this.extendBodyBehindAppBar = false,
    this.backgroundColor,
    this.resizeToAvoidBottomInset = true,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.bottomNavigationBar,
  }) : super(key: key);

  @override
  State<AppScaffold> createState() => _AppScaffoldState();
}

class _AppScaffoldState extends State<AppScaffold> {
  bool _isSidebarCollapsed = false;
  bool _isSidebarVisible = false;

  @override
  void initState() {
    super.initState();
    // On mobile, sidebar starts hidden
    // On tablet/desktop, sidebar starts expanded
    _isSidebarCollapsed = false;
  }

  void _toggleSidebar() {
    setState(() {
      _isSidebarCollapsed = !_isSidebarCollapsed;
    });
  }

  void _toggleMobileSidebar() {
    setState(() {
      _isSidebarVisible = !_isSidebarVisible;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveLayout.isTabletOrDesktop(context);

    return Scaffold(
      appBar: AppHeader(
        title: widget.title,
        actions: widget.actions,
        showSearchBar: widget.showSearchBar,
        onSearch: widget.onSearch,
        bottom: widget.bottomAppBar,
        onMenuPressed: isDesktop ? null : _toggleMobileSidebar,
      ),
      body: _buildBody(isDesktop),
      extendBodyBehindAppBar: widget.extendBodyBehindAppBar,
      backgroundColor: widget.backgroundColor,
      resizeToAvoidBottomInset: widget.resizeToAvoidBottomInset,
      floatingActionButton: widget.floatingActionButton,
      floatingActionButtonLocation: widget.floatingActionButtonLocation,
      bottomNavigationBar: !isDesktop ? widget.bottomNavigationBar : null,
      drawer: !isDesktop ? _buildMobileSidebar() : null,
    );
  }

  Widget _buildBody(bool isDesktop) {
    if (isDesktop) {
      return Row(
        children: [
          AppSidebar(
            items: widget.sidebarItems,
            selectedIndex: widget.selectedSidebarIndex,
            onItemSelected: widget.onSidebarItemSelected,
            isCollapsed: _isSidebarCollapsed,
            onToggleCollapsed: _toggleSidebar,
            header: widget.sidebarHeader,
            footer: widget.sidebarFooter,
          ),
          Expanded(
            child: widget.body,
          ),
        ],
      );
    } else {
      return widget.body;
    }
  }

  Widget _buildMobileSidebar() {
    return Drawer(
      child: AppSidebar(
        items: widget.sidebarItems,
        selectedIndex: widget.selectedSidebarIndex,
        onItemSelected: (index) {
          widget.onSidebarItemSelected(index);
          Navigator.pop(context); // Close drawer after selection
        },
        isCollapsed: false,
        header: widget.sidebarHeader,
        footer: widget.sidebarFooter,
      ),
    );
  }
}
