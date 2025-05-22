import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import '../../../core/theme/app_theme.dart';
import '../../../data/services/auth_service.dart';

class MobileSelectionScreen extends StatelessWidget {
  const MobileSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;
    final bool isLandscape = screenSize.width > screenSize.height;
    final bool isTablet = screenSize.width > 600;
    final bool isLargeTablet = screenSize.width > 900;
    final authService = Provider.of<AuthService>(context);
    final scaffoldKey = GlobalKey<ScaffoldState>();

    return Scaffold(
      key: scaffoldKey,
      appBar: AppBar(
        title: const Text("Elmo's Furniture"),
        centerTitle: true,
        backgroundColor: AppColors.primaryBlue,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () {
            scaffoldKey.currentState!.openDrawer();
          },
        ),
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Image.asset(
                    'assets/images/elmos_logo.png',
                    height: 40,
                    color: Colors.white,
                    errorBuilder: (context, error, stackTrace) => const Icon(
                      Icons.business,
                      size: 40,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Welcome, ${authService.userName ?? 'User'}",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    authService.userEmail ?? '',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.home),
              title: const Text('Home'),
              selected: true,
              onTap: () {
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.article),
              title: const Text('SOPs'),
              onTap: () {
                Navigator.pop(context);
                context.go('/mobile/sops');
              },
            ),
            ListTile(
              leading: const Icon(Icons.category),
              title: const Text('Categories'),
              onTap: () {
                Navigator.pop(context);
                context.go('/mobile/categories');
              },
            ),
            ListTile(
              leading: const Icon(Icons.factory_outlined),
              title: const Text('Factory MES'),
              onTap: () {
                Navigator.pop(context);
                context.go('/mes');
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Logout'),
              onTap: () async {
                await authService.logout();
                if (context.mounted) {
                  context.go('/login');
                }
              },
            ),
            // Version display
            FutureBuilder<PackageInfo>(
              future: PackageInfo.fromPlatform(),
              builder: (context, snapshot) {
                String version = "Version: ";
                if (snapshot.hasData) {
                  version += snapshot.data!.version;
                } else {
                  version += "Loading...";
                }

                return Padding(
                  padding: const EdgeInsets.symmetric(
                      vertical: 16.0, horizontal: 16.0),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline,
                          size: 16, color: Colors.grey),
                      const SizedBox(width: 8),
                      Text(
                        version,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Container(
          color: Colors.grey[100],
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Column(
                children: [
                  // Header - Fixed height with flex to occupy proportional space
                  Flexible(
                    flex: isLandscape ? 2 : 3,
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: isTablet ? 24.0 : 16.0,
                        vertical: isLandscape ? 8.0 : 16.0,
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Logo with maximum height to ensure it doesn't overflow
                            Flexible(
                              child: Center(
                                child: Image.asset(
                                  'assets/images/elmos_logo_icon.png',
                                  height: isLargeTablet
                                      ? 60.0
                                      : isTablet
                                          ? 50.0
                                          : 40.0,
                                  errorBuilder: (context, error, stackTrace) =>
                                      Icon(
                                    Icons.business_outlined,
                                    size: isLargeTablet
                                        ? 60.0
                                        : isTablet
                                            ? 50.0
                                            : 40.0,
                                    color: AppColors.primaryBlue,
                                  ),
                                ),
                              ),
                            ),

                            // Welcome Text
                            Padding(
                              padding: EdgeInsets.only(
                                  top: isLandscape ? 16.0 : 24.0),
                              child: Text(
                                'Welcome to Elmo\'s Furniture',
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blueGrey[800],
                                      fontSize: isLargeTablet
                                          ? 32.0
                                          : isTablet
                                              ? 28.0
                                              : isLandscape
                                                  ? 20.0
                                                  : 24.0,
                                    ),
                                textAlign: TextAlign.center,
                              ),
                            ),

                            // Subtitle
                            Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                'Please select your workspace',
                                style: TextStyle(
                                  fontSize: isLargeTablet
                                      ? 20.0
                                      : isTablet
                                          ? 18.0
                                          : isLandscape
                                              ? 14.0
                                              : 16.0,
                                  color: Colors.blueGrey[600],
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Cards section - Takes available space while ensuring all content fits
                  Flexible(
                    flex: isLandscape ? 3 : 4,
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: isTablet ? 32.0 : 16.0,
                        vertical: isLandscape ? 8.0 : 16.0,
                      ),
                      child: isLandscape
                          ? _buildLandscapeCards(
                              context, isTablet, isLargeTablet)
                          : _buildPortraitCards(
                              context, isTablet, isLargeTablet),
                    ),
                  ),

                  // Debug info
                  if (kDebugMode)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12.0,
                          vertical: 6.0,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(16.0),
                        ),
                        child: Text(
                          'Screen: ${screenSize.width.toStringAsFixed(1)} × ${screenSize.height.toStringAsFixed(1)} - ${isLandscape ? "Landscape" : "Portrait"}${isTablet ? " - Tablet" : ""}${isLargeTablet ? " - Large" : ""}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12.0,
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  // Landscape layout with side-by-side cards
  Widget _buildLandscapeCards(
    BuildContext context,
    bool isTablet,
    bool isLargeTablet,
  ) {
    return Row(
      children: [
        // SOP Card
        Expanded(
          child: _buildSelectionCard(
            context,
            title: 'SOP Manager',
            description:
                'Standard Operating Procedures for furniture manufacturing',
            icon: Icons.description_outlined,
            color: AppColors.primaryBlue,
            onTap: () {
              context.go('/mobile/sops');
            },
            isTablet: isTablet,
            isLargeTablet: isLargeTablet,
            isLandscape: true,
          ),
        ),
        SizedBox(
            width: isLargeTablet
                ? 32.0
                : isTablet
                    ? 24.0
                    : 16.0),
        // Factory (MES) Card
        Expanded(
          child: _buildSelectionCard(
            context,
            title: 'Factory MES',
            description:
                'Manufacturing Execution System for production tracking',
            icon: Icons.factory_outlined,
            color: AppColors.blueAccent,
            onTap: () {
              context.go('/mes');
            },
            isTablet: isTablet,
            isLargeTablet: isLargeTablet,
            isLandscape: true,
          ),
        ),
      ],
    );
  }

  // Portrait layout with stacked cards
  Widget _buildPortraitCards(
    BuildContext context,
    bool isTablet,
    bool isLargeTablet,
  ) {
    return Column(
      children: [
        // SOP Card
        Expanded(
          child: _buildSelectionCard(
            context,
            title: 'SOP Manager',
            description:
                'Standard Operating Procedures for furniture manufacturing',
            icon: Icons.description_outlined,
            color: AppColors.primaryBlue,
            onTap: () {
              context.go('/mobile/sops');
            },
            isTablet: isTablet,
            isLargeTablet: isLargeTablet,
            isLandscape: false,
          ),
        ),
        SizedBox(
            height: isLargeTablet
                ? 24.0
                : isTablet
                    ? 16.0
                    : 12.0),
        // Factory (MES) Card
        Expanded(
          child: _buildSelectionCard(
            context,
            title: 'Factory MES',
            description:
                'Manufacturing Execution System for production tracking',
            icon: Icons.factory_outlined,
            color: AppColors.blueAccent,
            onTap: () {
              context.go('/mes');
            },
            isTablet: isTablet,
            isLargeTablet: isLargeTablet,
            isLandscape: false,
          ),
        ),
      ],
    );
  }

  Widget _buildSelectionCard(
    BuildContext context, {
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required bool isTablet,
    required bool isLargeTablet,
    required bool isLandscape,
  }) {
    // Optimized sizes for different screen configurations - reduced by 50%
    final double iconSize = isLandscape
        ? (isLargeTablet
            ? 32.0
            : isTablet
                ? 28.0
                : 24.0)
        : (isLargeTablet
            ? 36.0
            : isTablet
                ? 32.0
                : 24.0);

    // Text sizes unchanged
    final double titleSize = isLandscape
        ? (isLargeTablet
            ? 24.0
            : isTablet
                ? 22.0
                : 18.0)
        : (isLargeTablet
            ? 28.0
            : isTablet
                ? 24.0
                : 20.0);

    final double descriptionSize = isLandscape
        ? (isLargeTablet
            ? 16.0
            : isTablet
                ? 14.0
                : 12.0)
        : (isLargeTablet
            ? 18.0
            : isTablet
                ? 16.0
                : 14.0);

    // Use custom icons for SOP and MES
    Widget iconWidget;
    if (title == 'SOP Manager') {
      iconWidget = Icon(
        Icons.article_outlined,
        size: iconSize,
        color: color,
      );
    } else if (title == 'Factory MES') {
      iconWidget = Icon(
        Icons.factory_outlined,
        size: iconSize,
        color: color,
      );
    } else {
      iconWidget = Icon(
        icon,
        size: iconSize,
        color: color,
      );
    }

    return Card(
      elevation: 2,
      margin: const EdgeInsets.all(0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: EdgeInsets.all(isLandscape
              ? (isLargeTablet
                  ? 24.0
                  : isTablet
                      ? 16.0
                      : 12.0)
              : (isLargeTablet
                  ? 32.0
                  : isTablet
                      ? 24.0
                      : 16.0)),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              iconWidget,
              const Spacer(flex: 1),
              Text(
                title,
                style: TextStyle(
                  fontSize: titleSize,
                  fontWeight: FontWeight.bold,
                  color: Colors.blueGrey[800],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8.0),
              Text(
                description,
                style: TextStyle(
                  fontSize: descriptionSize,
                  color: Colors.blueGrey[600],
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const Spacer(flex: 1),
            ],
          ),
        ),
      ),
    );
  }
}
