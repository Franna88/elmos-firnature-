import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../data/services/auth_service.dart';
import '../../core/theme/app_theme.dart';

class AppScaffold extends StatelessWidget {
  final Widget body;
  final String title;
  final bool showBackButton;
  final List<Widget>? actions;
  final Widget? floatingActionButton;

  const AppScaffold({
    super.key,
    required this.body,
    required this.title,
    this.showBackButton = false,
    this.actions,
    this.floatingActionButton,
  });

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final GoRouterState routerState = GoRouterState.of(context);
    final String currentLocation = routerState.uri.path;

    // Check if this is a primary screen that should never have a back button
    final bool isDashboard =
        currentLocation == '/' || currentLocation == '/dashboard';
    final bool isSOPs = currentLocation == '/sops';
    final bool shouldShowBackButton =
        showBackButton || (!isDashboard && !isSOPs);

    return Scaffold(
      appBar: AppBar(
        title: title.isEmpty
            ? Row(
                children: [
                  Image.asset(
                    'assets/images/elmos_logo.png',
                    height: 28,
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    "Elmo's Furniture",
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              )
            : Text(title),
        automaticallyImplyLeading: false,
        leading: shouldShowBackButton
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.pop(),
                tooltip: 'Back',
              )
            : null,
        actions: actions ??
            [
              if (kDebugMode && authService.isLoggedIn)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.white.withOpacity(0.5)),
                  ),
                  child: const Text(
                    'DEV',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              // User profile menu
              Padding(
                padding: const EdgeInsets.only(right: 16.0),
                child: PopupMenuButton<String>(
                  offset: const Offset(0, 40),
                  child: Row(
                    children: [
                      Text(
                        authService.userName ?? 'User',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 8),
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: Colors.white.withOpacity(0.3),
                        child: const Icon(
                          Icons.person,
                          size: 18,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'profile',
                      child: Row(
                        children: [
                          Icon(Icons.person_outline, size: 18),
                          SizedBox(width: 8),
                          Text('Profile'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'settings',
                      child: Row(
                        children: [
                          Icon(Icons.settings_outlined, size: 18),
                          SizedBox(width: 8),
                          Text('Settings'),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(),
                    PopupMenuItem(
                      value: 'logout',
                      onTap: () async {
                        if (kDebugMode) {
                          await authService.devFriendlyLogout();
                        } else {
                          await authService.logout();
                        }
                        if (context.mounted) {
                          context.go('/login');
                        }
                      },
                      child: const Row(
                        children: [
                          Icon(Icons.logout_outlined, size: 18),
                          SizedBox(width: 8),
                          Text('Sign Out'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
        elevation: 0,
        scrolledUnderElevation: 2,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: AppColors.divider,
          ),
        ),
      ),
      body: Row(
        children: [
          // Modern sidebar
          Container(
            width: 220,
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 8,
                  offset: const Offset(2, 0),
                ),
              ],
            ),
            child: Column(
              children: [
                // Company header
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: AppColors.divider),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Image.asset(
                            'assets/images/elmos_logo.png',
                            height: 40,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        "SOP Management",
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textLight,
                        ),
                      ),
                    ],
                  ),
                ),

                // Navigation items
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    children: [
                      _buildNavItem(
                        context,
                        icon: Icons.dashboard_outlined,
                        label: 'Dashboard',
                        route: '/',
                        isSelected: currentLocation == '/',
                      ),
                      _buildNavItem(
                        context,
                        icon: Icons.description_outlined,
                        label: 'My SOPs',
                        route: '/sops',
                        isSelected: currentLocation == '/sops',
                      ),
                      _buildNavItem(
                        context,
                        icon: Icons.factory_outlined,
                        label: 'MES',
                        onTap: () {
                          // Launch the tablet MES application
                          const url = '/mes';
                          context.go(url);
                        },
                        isSelected: currentLocation == '/mes',
                      ),
                      _buildNavItem(
                        context,
                        icon: Icons.settings_outlined,
                        label: 'MES Management',
                        route: '/mes-management',
                        isSelected: currentLocation == '/mes-management',
                      ),
                      _buildNavItem(
                        context,
                        icon: Icons.insert_chart_outlined,
                        label: 'MES Reports',
                        route: '/mes-reports',
                        isSelected: currentLocation == '/mes-reports',
                      ),
                      _buildNavItem(
                        context,
                        icon: Icons.category_outlined,
                        label: 'Categories',
                        route: '/categories',
                        isSelected: currentLocation == '/categories',
                      ),
                      const Padding(
                        padding:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Divider(),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        child: Text(
                          'INSIGHTS',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textLight,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      _buildNavItem(
                        context,
                        icon: Icons.insights_outlined,
                        label: 'Analytics',
                        route: '/analytics',
                        isSelected: currentLocation == '/analytics',
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        child: Divider(),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        child: Text(
                          'SETTINGS',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textLight,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      _buildNavItem(
                        context,
                        icon: Icons.settings_outlined,
                        label: 'Settings',
                        route: '/settings',
                        isSelected: currentLocation == '/settings',
                      ),
                    ],
                  ),
                ),

                // Version number at bottom of sidebar
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: FutureBuilder<PackageInfo>(
                    future: PackageInfo.fromPlatform(),
                    builder: (context, snapshot) {
                      String version = "Version: ";
                      if (snapshot.hasData) {
                        version +=
                            "${snapshot.data!.version}+${snapshot.data!.buildNumber}";
                      } else {
                        version += "Loading...";
                      }
                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            vertical: 8, horizontal: 12),
                        decoration: BoxDecoration(
                          color: AppColors.textLight.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                              color: AppColors.textLight.withOpacity(0.1)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 14,
                              color: AppColors.textLight,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              version,
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textLight,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // Main content
          Expanded(
            child: body,
          ),
        ],
      ),
      floatingActionButton: floatingActionButton,
    );
  }

  Widget _buildNavItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    String? route,
    bool isSelected = false,
    VoidCallback? onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap ??
              () {
                if (route != null) {
                  context.go(route);
                }
              },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primaryBlue.withOpacity(0.08)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color:
                      isSelected ? AppColors.primaryBlue : AppColors.textMedium,
                ),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: TextStyle(
                    color:
                        isSelected ? AppColors.primaryBlue : AppColors.textDark,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
