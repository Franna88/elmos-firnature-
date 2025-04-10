import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart';
import '../../data/services/auth_service.dart';

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
    final String currentLocation = GoRouterState.of(context).uri.path;

    return Scaffold(
      appBar: AppBar(
        title: title.isEmpty
            ? Row(
                children: [
                  Image.asset(
                    'assets/images/logo.png',
                    height: 32,
                  ),
                  const SizedBox(width: 8),
                  const Text("Elmo's Furniture SOP Manager"),
                ],
              )
            : Text(title),
        automaticallyImplyLeading: false,
        leading: showBackButton
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
        backgroundColor: const Color(0xffB21E1E),
        foregroundColor: Colors.white,
        actions: actions ??
            [
              Padding(
                padding: const EdgeInsets.only(right: 16.0),
                child: Row(
                  children: [
                    if (kDebugMode && authService.isLoggedIn)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.amber),
                        ),
                        child: const Text(
                          'DEV',
                          style: TextStyle(
                            color: Colors.amber,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    Text(
                      authService.userName ?? 'User',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const CircleAvatar(
                      radius: 18,
                      backgroundColor: Colors.white,
                      child: Icon(
                        Icons.person,
                        color: Color(0xffB21E1E),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.notifications_outlined),
                  ],
                ),
              ),
            ],
      ),
      body: Row(
        children: [
          // Static sidebar
          Container(
            width: 250,
            color: Colors.white,
            child: Column(
              children: [
                // Logo
                Container(
                  color: const Color(0xffB21E1E),
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 10),
                      const Text(
                        "elmo's",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Text(
                        "F U R N I T U R E",
                        style: TextStyle(
                          fontSize: 12,
                          letterSpacing: 2,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                // Navigation items
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      _buildNavItem(
                        context,
                        icon: Icons.dashboard,
                        label: 'Dashboard',
                        route: '/',
                        isSelected: currentLocation == '/',
                      ),
                      _buildNavItem(
                        context,
                        icon: Icons.apps,
                        label: 'My SOPs',
                        route: '/sops',
                        isSelected: currentLocation == '/sops',
                      ),
                      _buildNavItem(
                        context,
                        icon: Icons.description,
                        label: 'Templates',
                        route: '/templates',
                        isSelected: currentLocation == '/templates',
                      ),
                      const Divider(),
                      _buildNavItem(
                        context,
                        icon: Icons.stacked_bar_chart,
                        label: 'Analytics',
                        route: '/analytics',
                        isSelected: currentLocation == '/analytics',
                      ),
                      _buildNavItem(
                        context,
                        icon: Icons.settings,
                        label: 'Settings',
                        route: '/settings',
                        isSelected: currentLocation == '/settings',
                      ),
                      const Divider(),
                      _buildNavItem(
                        context,
                        icon: Icons.logout,
                        label: 'Sign Out',
                        onTap: () async {
                          // Use development-friendly logout to enable auto-login on hot reload
                          if (kDebugMode) {
                            await authService.devFriendlyLogout();
                          } else {
                            // In production, use regular logout
                            await authService.logout();
                          }

                          if (context.mounted) {
                            context.go('/login');
                          }
                        },
                      ),
                    ],
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
    return ListTile(
      leading: Icon(
        icon,
        color: isSelected ? const Color(0xffB21E1E) : Colors.grey[700],
      ),
      title: Text(
        label,
        style: TextStyle(
          color: isSelected ? const Color(0xffB21E1E) : Colors.grey[900],
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      onTap: onTap ??
          () {
            if (route != null) {
              context.go(route);
            }
          },
      tileColor: isSelected ? const Color(0xFFFDEDED) : null,
    );
  }
}
