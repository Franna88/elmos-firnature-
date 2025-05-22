import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/foundation.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/services/sop_service.dart';
import '../../../data/models/sop_model.dart';
import '../../../core/theme/app_theme.dart';
import '../../design_system/components/app_button.dart';
import '../../design_system/components/app_card.dart';
import '../../design_system/layouts/app_scaffold.dart';
import '../../design_system/components/app_sidebar.dart';
import '../../design_system/components/app_header.dart';
import '../../widgets/cross_platform_image.dart';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../utils/populate_firebase.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _isLoading = false;
  int _selectedSidebarIndex = 0;

  @override
  void initState() {
    super.initState();
    // Refresh SOPs when the screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshSOPs();
    });
  }

  Future<void> _refreshSOPs() async {
    setState(() {
      _isLoading = true;
    });

    final sopService = Provider.of<SOPService>(context, listen: false);
    await sopService.refreshSOPs();

    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final sopService = Provider.of<SOPService>(context);

    // Define sidebar items
    final List<AppSidebarItem> sidebarItems = [
      AppSidebarItem(
        label: 'Dashboard',
        icon: Icons.dashboard_outlined,
      ),
      AppSidebarItem(
        label: 'My SOPs',
        icon: Icons.description_outlined,
      ),
      AppSidebarItem(
        label: 'MES',
        icon: Icons.factory_outlined,
      ),
      AppSidebarItem(
        label: 'MES Management',
        icon: Icons.settings_outlined,
      ),
      AppSidebarItem(
        label: 'MES Reports',
        icon: Icons.insert_chart_outlined,
      ),
      AppSidebarItem(
        label: 'Categories',
        icon: Icons.category_outlined,
      ),
      AppSidebarItem(
        label: 'Analytics',
        icon: Icons.insights_outlined,
      ),
      AppSidebarItem(
        label: 'Settings',
        icon: Icons.settings_outlined,
      ),
    ];

    // Define header actions
    final List<AppHeaderAction> headerActions = [
      AppHeaderAction(
        icon: Icons.refresh,
        label: 'Refresh',
        onPressed: _refreshSOPs,
      ),
      AppHeaderAction(
        icon: Icons.add_circle_outline,
        label: 'Create SOP',
        onPressed: () => context.go('/editor/new'),
        showAsButton: true,
      ),
    ];

    return AppScaffold(
      title: "Dashboard",
      sidebarItems: sidebarItems,
      selectedSidebarIndex: _selectedSidebarIndex,
      onSidebarItemSelected: (index) {
        setState(() {
          _selectedSidebarIndex = index;
        });

        // Navigate based on selected index
        switch (index) {
          case 0: // Dashboard
            context.go('/dashboard');
            break;
          case 1: // My SOPs
            context.go('/sops');
            break;
          case 2: // MES
            context.go('/mes');
            break;
          case 3: // MES Management
            context.go('/mes-management');
            break;
          case 4: // MES Reports
            context.go('/mes-reports');
            break;
          case 5: // Categories
            context.go('/categories');
            break;
          case 6: // Analytics
            context.go('/analytics');
            break;
          case 7: // Settings
            context.go('/settings');
            break;
        }
      },
      actions: headerActions,
      sidebarHeader: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Image.asset(
              'assets/images/elmos_logo.png',
              height: 40,
            ),
            const SizedBox(height: 8),
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.only(
                  left: 24.0, right: 24.0, top: 16.0, bottom: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Welcome header
                  AppCard(
                    variant: CardVariant.flat,
                    padding: EdgeInsets.all(24),
                    content: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Welcome back, ${authService.userName ?? 'User'}',
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Manage your furniture manufacturing procedures efficiently.',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        AppButton(
                          label: 'Create SOP',
                          variant: ButtonVariant.primary,
                          leadingIcon: Icons.add,
                          onPressed: () {
                            context.go('/editor/new');
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Section title
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Standard Operating Procedures',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      if (sopService.sops.length > 6)
                        AppButton(
                          label: 'View All',
                          variant: ButtonVariant.tertiary,
                          trailingIcon: Icons.arrow_forward,
                          onPressed: () {
                            context.go('/sops');
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // SOP cards grid
                  sopService.sops.isEmpty
                      ? _buildEmptyState(context)
                      : GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            childAspectRatio: 2.5,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                          ),
                          itemCount: sopService.sops.length > 9
                              ? 9
                              : sopService.sops.length,
                          itemBuilder: (context, index) {
                            final sop = sopService.sops[index];
                            return _buildSOPCard(context, sop);
                          },
                        ),
                ],
              ),
            ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.all(32),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.description_outlined,
            size: 48,
            color: AppColors.textTertiary.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No SOPs created yet',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Create your first SOP to get started with the manufacturing process',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          AppButton(
            label: 'Create First SOP',
            variant: ButtonVariant.primary,
            leadingIcon: Icons.add,
            onPressed: () {
              context.go('/editor/new');
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSOPCard(BuildContext context, SOP sop) {
    // Use the SOP thumbnail if available, otherwise fallback to first step image
    final String? imageUrl = sop.thumbnailUrl ??
        (sop.steps.isNotEmpty && sop.steps.first.imageUrl != null
            ? sop.steps.first.imageUrl
            : null);

    // Get department color
    final Color departmentColor =
        _getDepartmentColor(sop.categoryName ?? 'Unknown');

    return AppCard(
      variant: CardVariant.outlined,
      hasShadow: false,
      onTap: () {
        context.go('/editor/${sop.id}');
      },
      content: Row(
        children: [
          // Image section (30% of width)
          Expanded(
            flex: 30,
            child: Stack(
              children: [
                SizedBox(
                  height: 100,
                  child: _buildImage(imageUrl),
                ),
                // Department badge
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: departmentColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      sop.categoryName ?? 'Unknown',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Content section (70% of width)
          Expanded(
            flex: 70,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Title with Rev number
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          sop.title,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceLight,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Text(
                          'Rev ${sop.revisionNumber}',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Description (if available)
                  if (sop.description.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      sop.description,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],

                  // Stats in a row
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        Icons.checklist,
                        size: 14,
                        color: AppColors.textTertiary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${sop.steps.length} steps',
                        style: TextStyle(
                          color: AppColors.textTertiary,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(
                        Icons.calendar_today_outlined,
                        size: 14,
                        color: AppColors.textTertiary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        "${sop.createdAt.day}/${sop.createdAt.month}/${sop.createdAt.year}",
                        style: TextStyle(
                          color: AppColors.textTertiary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getDepartmentColor(String department) {
    switch (department.toLowerCase()) {
      case 'assembly':
        return AppColors.blueAccent;
      case 'finishing':
        return AppColors.greenAccent;
      case 'machinery':
        return AppColors.orangeAccent;
      case 'quality':
        return AppColors.purpleAccent;
      case 'upholstery':
        return Colors.redAccent;
      default:
        return AppColors.primary;
    }
  }

  Widget _buildImage(String? imageUrl) {
    if (imageUrl == null) {
      return Container(
        color: AppColors.surfaceLight,
        width: 120,
        height: 100,
        child: Center(
          child: Icon(
            Icons.image_not_supported,
            size: 20,
            color: AppColors.textTertiary.withOpacity(0.5),
          ),
        ),
      );
    }

    return CrossPlatformImage(
      imageUrl: imageUrl,
      height: 100,
      width: 120,
      fit: BoxFit.cover,
      errorWidget: _buildImageError(),
    );
  }

  Widget _buildImageError() {
    return Container(
      width: 120,
      height: 100,
      color: AppColors.surfaceLight,
      child: Center(
        child: Icon(
          Icons.broken_image,
          size: 20,
          color: AppColors.textTertiary.withOpacity(0.5),
        ),
      ),
    );
  }
}
