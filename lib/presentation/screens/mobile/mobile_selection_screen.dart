import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';

class MobileSelectionScreen extends StatelessWidget {
  const MobileSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;
    final bool isLandscape = screenSize.width > screenSize.height;
    final bool isTablet = screenSize.width > 600;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Elmo's Furniture"),
        centerTitle: true,
        backgroundColor: AppColors.primaryRed,
        foregroundColor: Colors.white,
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
