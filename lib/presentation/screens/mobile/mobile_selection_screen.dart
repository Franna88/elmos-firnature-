import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/services/auth_service.dart';

class MobileSelectionScreen extends StatelessWidget {
  const MobileSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;
    final bool isLandscape = screenSize.width > screenSize.height;
    final bool isTablet = screenSize.width > 600;
    final authService = Provider.of<AuthService>(context);
    final _scaffoldKey = GlobalKey<ScaffoldState>();

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: const Text("Elmo's Furniture"),
        centerTitle: true,
        backgroundColor: AppColors.primaryRed,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () {
            _scaffoldKey.currentState!.openDrawer();
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
                    errorBuilder: (context, error, stackTrace) => Icon(
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
                  version += "${snapshot.data!.version}";
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
      body: Container(
        padding: EdgeInsets.all(isTablet ? 32 : 24),
        color: Colors.grey[100],
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Header
            Padding(
              padding: EdgeInsets.only(bottom: isTablet ? 48 : 32),
              child: Column(
                children: [
                  Image.asset(
                    'assets/images/logo.png',
                    height: isTablet ? 140 : 100,
                    errorBuilder: (context, error, stackTrace) => Icon(
                      Icons.business,
                      size: isTablet ? 140 : 100,
                      color: AppColors.primaryRed,
                    ),
                  ),
                  SizedBox(height: isTablet ? 32 : 24),
                  Text(
                    'Welcome to Elmo\'s Furniture',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                          fontSize: isTablet ? 28 : 24,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Please select your workspace',
                    style: TextStyle(
                      fontSize: isTablet ? 18 : 16,
                      color: AppColors.textMedium,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            // Selection cards
            isLandscape
                ? _buildLandscapeCards(context, isTablet)
                : _buildPortraitCards(context, isTablet),
          ],
        ),
      ),
    );
  }

  // Landscape layout with side-by-side cards
  Widget _buildLandscapeCards(BuildContext context, bool isTablet) {
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
            color: AppColors.primaryRed,
            onTap: () {
              context.go('/mobile/sops');
            },
            isTablet: isTablet,
          ),
        ),
        SizedBox(width: isTablet ? 24 : 16),
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
          ),
        ),
      ],
    );
  }

  // Portrait layout with stacked cards
  Widget _buildPortraitCards(BuildContext context, bool isTablet) {
    return Column(
      children: [
        // SOP Card
        _buildSelectionCard(
          context,
          title: 'SOP Manager',
          description:
              'Standard Operating Procedures for furniture manufacturing',
          icon: Icons.description_outlined,
          color: AppColors.primaryRed,
          onTap: () {
            context.go('/mobile/sops');
          },
          isTablet: isTablet,
        ),
        SizedBox(height: isTablet ? 24 : 16),
        // Factory (MES) Card
        _buildSelectionCard(
          context,
          title: 'Factory MES',
          description: 'Manufacturing Execution System for production tracking',
          icon: Icons.factory_outlined,
          color: AppColors.blueAccent,
          onTap: () {
            context.go('/mes');
          },
          isTablet: isTablet,
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
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: EdgeInsets.all(isTablet ? 32 : 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: isTablet ? 80 : 64,
                color: color,
              ),
              SizedBox(height: isTablet ? 32 : 24),
              Text(
                title,
                style: TextStyle(
                  fontSize: isTablet ? 26 : 22,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                description,
                style: TextStyle(
                  fontSize: isTablet ? 16 : 14,
                  color: AppColors.textMedium,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
