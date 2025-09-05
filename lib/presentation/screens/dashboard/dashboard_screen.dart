import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/services/sop_service.dart';
import '../../../data/models/sop_model.dart';
import '../../../core/theme/app_theme.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/cross_platform_image.dart';
import '../../../data/services/category_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _isLoading = false;

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

    return AppScaffold(
      title: "Dashboard",
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: 'Refresh SOPs',
          onPressed: _refreshSOPs,
        ),
        IconButton(
          icon: const Icon(Icons.add_circle_outline),
          tooltip: 'Add SOP',
          onPressed: () {
            context.go('/editor/new');
          },
        ),
      ],
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildDashboardContent(context, authService, sopService),
    );
  }

  Widget _buildDashboardContent(
      BuildContext context, AuthService authService, SOPService sopService) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome header with elegant styling
          _buildWelcomeHeader(context, authService),

          const SizedBox(height: 32),

          // Quick actions section
          _buildQuickActionsSection(context),

          const SizedBox(height: 32),

          // SOPs section with more professional styling
          _buildSOPsSection(context, sopService),
        ],
      ),
    );
  }

  Widget _buildWelcomeHeader(BuildContext context, AuthService authService) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primaryBlue,
            AppColors.accentTeal,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left side content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome back, ${authService.userName ?? 'User'}',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Manage your furniture manufacturing procedures efficiently with our comprehensive SOP system.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.9),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () {
                    context.go('/editor/new');
                  },
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Create New SOP'),
                  style: ElevatedButton.styleFrom(
                    foregroundColor: AppColors.primaryBlue,
                    backgroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    elevation: 0,
                  ),
                ),
              ],
            ),
          ),

          // Decorative element
          Container(
            margin: const EdgeInsets.only(left: 20),
            child: Icon(
              Icons.auto_awesome,
              size: 64,
              color: Colors.white.withOpacity(0.2),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            _buildActionCard(
              context,
              icon: Icons.add_circle_outline,
              title: 'Create SOP',
              description: 'Design a new procedure',
              color: AppColors.primaryBlue,
              onTap: () => context.go('/editor/new'),
            ),
            const SizedBox(width: 16),
            _buildActionCard(
              context,
              icon: Icons.search,
              title: 'Browse SOPs',
              description: 'View all procedures',
              color: AppColors.accentTeal,
              onTap: () => context.go('/sops'),
            ),
            const SizedBox(width: 16),
            _buildActionCard(
              context,
              icon: Icons.insights,
              title: 'Analytics',
              description: 'View SOP metrics',
              color: AppColors.tealAccent,
              onTap: () => context.go('/analytics'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.divider),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 24,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textLight,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSOPsSection(BuildContext context, SOPService sopService) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent SOPs',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            if (sopService.sops.length > 6)
              TextButton.icon(
                onPressed: () {
                  context.go('/sops');
                },
                icon: const Icon(Icons.arrow_forward, size: 18),
                label: const Text('View All'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.accentTeal,
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        sopService.sops.isEmpty
            ? _buildEmptyState(context)
            : _buildSOPsGrid(context, sopService),
      ],
    );
  }

  Widget _buildSOPsGrid(BuildContext context, SOPService sopService) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 1.2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: sopService.sops.length > 6 ? 6 : sopService.sops.length,
      itemBuilder: (context, index) {
        final sop = sopService.sops[index];
        return _buildSOPCard(context, sop);
      },
    );
  }

  Widget _buildSOPCard(BuildContext context, SOP sop) {
    // Use the SOP thumbnail if available, otherwise fallback to first step image
    final String? imageUrl = sop.thumbnailUrl ??
        (sop.steps.isNotEmpty && sop.steps.first.imageUrl != null
            ? sop.steps.first.imageUrl
            : null);

    // Get category color from the actual category data
    final categoryService =
        Provider.of<CategoryService>(context, listen: false);
    final Color departmentColor =
        _getCategoryColor(sop.categoryId, categoryService);

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () {
          context.go('/editor/${sop.id}');
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Category header at the top
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              decoration: BoxDecoration(
                color: departmentColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    sop.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Rev ${sop.revisionNumber}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Image section
            SizedBox(
              height: 120,
              width: double.infinity,
              child: _buildImage(imageUrl),
            ),

            // Content section
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    "Category | : ${sop.categoryName ?? "Unknown"}",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: Color(0xFF4A5363),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),

                  // Description (if available)
                  if (sop.description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      sop.description,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMedium,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],

                  const SizedBox(height: 8),

                  // Stats in a row
                  Row(
                    children: [
                      const Icon(
                        Icons.checklist,
                        size: 14,
                        color: AppColors.textLight,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${sop.steps.length} steps',
                        style: const TextStyle(
                          color: AppColors.textLight,
                          fontSize: 12,
                        ),
                      ),
                      const Spacer(),
                      const Icon(
                        Icons.calendar_today_outlined,
                        size: 14,
                        color: AppColors.textLight,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        "${sop.createdAt.day}/${sop.createdAt.month}/${sop.createdAt.year}",
                        style: const TextStyle(
                          color: AppColors.textLight,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.accentTeal.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.description_outlined,
              size: 48,
              color: AppColors.accentTeal,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No SOPs Created Yet',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),
          Text(
            'Create your first Standard Operating Procedure to streamline your manufacturing process',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textMedium,
              height: 1.5,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              context.go('/editor/new');
            },
            icon: const Icon(Icons.add),
            label: const Text('Create First SOP'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Color _getCategoryColor(String categoryId, CategoryService categoryService) {
    // Default to a shade of blue if category is empty
    if (categoryId.isEmpty) {
      return AppColors.primaryBlue;
    }

    // Look up the category and get its color
    final category = categoryService.getCategoryById(categoryId);
    if (category != null &&
        category.color != null &&
        category.color!.startsWith('#')) {
      try {
        // Parse hex color string to Color object
        return Color(int.parse('FF${category.color!.substring(1)}', radix: 16));
      } catch (e) {
        // If parsing fails, fall back to default
        return AppColors.primaryBlue;
      }
    }

    // Fallback to a default color if category is not found or has no color
    return AppColors.primaryBlue;
  }

  Widget _buildImage(String? imageUrl) {
    if (imageUrl == null) {
      return Container(
        color: Colors.grey[100],
        child: Center(
          child: Icon(
            Icons.image_not_supported,
            size: 24,
            color: AppColors.textLight.withOpacity(0.5),
          ),
        ),
      );
    }

    return CrossPlatformImage(
      imageUrl: imageUrl,
      fit: BoxFit.cover,
      errorWidget: _buildImageError(),
    );
  }

  Widget _buildImageError() {
    return Container(
      color: Colors.grey[100],
      child: Center(
        child: Icon(
          Icons.broken_image,
          size: 24,
          color: AppColors.textLight.withOpacity(0.5),
        ),
      ),
    );
  }

  void _showDeleteSOPDialog() {
    // State variables for selected SOPs
    List<SOP> selectedSOPs = [];
    final sopService = Provider.of<SOPService>(context, listen: false);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(builder: (context, setState) {
        return AlertDialog(
          title: const Text('Delete SOPs'),
          content: SizedBox(
            width: 500,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Select SOPs to delete:'),
                const SizedBox(height: 16),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: sopService.sops.length,
                    itemBuilder: (context, index) {
                      final sop = sopService.sops[index];
                      final bool isSelected = selectedSOPs.contains(sop);

                      return CheckboxListTile(
                        title: Text(sop.title),
                        subtitle: Text(
                            'Created: ${sop.createdAt.day}/${sop.createdAt.month}/${sop.createdAt.year}'),
                        value: isSelected,
                        onChanged: (bool? value) {
                          setState(() {
                            if (value == true) {
                              selectedSOPs.add(sop);
                            } else {
                              selectedSOPs.remove(sop);
                            }
                          });
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCEL'),
            ),
            ElevatedButton(
              onPressed: selectedSOPs.isEmpty
                  ? null
                  : () async {
                      Navigator.pop(context);

                      // Show loading dialog
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (context) => const AlertDialog(
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(height: 16),
                              Text('Deleting SOPs...'),
                            ],
                          ),
                        ),
                      );

                      try {
                        // Delete each selected SOP
                        for (var sop in selectedSOPs) {
                          await sopService.deleteSop(sop.id);
                        }

                        // Refresh SOPs after deletion
                        await sopService.refreshSOPs();

                        if (context.mounted) {
                          // Close loading dialog
                          Navigator.pop(context);

                          // Show success message
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                  'Successfully deleted ${selectedSOPs.length} SOPs'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          // Close loading dialog
                          Navigator.pop(context);

                          // Show error message
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error deleting SOPs: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('DELETE'),
            ),
          ],
        );
      }),
    );
  }
}
