import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/foundation.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/services/sop_service.dart';
import '../../../data/models/sop_model.dart';
import '../../../core/theme/app_theme.dart';
import '../../widgets/app_scaffold.dart';
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
        IconButton(
          icon: const Icon(Icons.delete_outline),
          tooltip: 'Delete SOPs',
          onPressed: () {
            _showDeleteSOPDialog();
          },
        ),
      ],
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding:
                  const EdgeInsets.only(left: 24.0, right: 24.0, bottom: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Welcome header with stats
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Welcome message
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Welcome back, ${authService.userName ?? 'User'}',
                              style: Theme.of(context).textTheme.headlineMedium,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Manage your furniture manufacturing procedures efficiently.',
                              style: TextStyle(
                                color: AppColors.textMedium,
                                fontSize: 15,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 24),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () {
                                      context.go('/editor/new');
                                    },
                                    icon: const Icon(Icons.add, size: 18),
                                    label: const Text('Create SOP'),
                                    style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 12),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                OutlinedButton.icon(
                                  onPressed: () {
                                    context.go('/analytics');
                                  },
                                  icon: const Icon(Icons.insights_outlined,
                                      size: 18),
                                  label: const Text('Analytics'),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12, horizontal: 16),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 48),
                      // Quick stats
                      Expanded(
                        flex: 2,
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.cardBorder),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Your Activity',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textDark,
                                ),
                              ),
                              const SizedBox(height: 16),
                              _buildStatRow(
                                Icons.description_outlined,
                                '${sopService.sops.length} SOPs',
                                'Created',
                                AppColors.primaryRed,
                              ),
                              const SizedBox(height: 12),
                              _buildStatRow(
                                Icons.category_outlined,
                                '${sopService.templates.length} Categories',
                                'Available',
                                AppColors.blueAccent,
                              ),
                              if (kDebugMode) const SizedBox(height: 12),
                              if (kDebugMode)
                                _buildStatRow(
                                  Icons.person_outline,
                                  'Admin',
                                  'Role',
                                  AppColors.greenAccent,
                                ),
                              if (kDebugMode) const SizedBox(height: 12),
                              if (kDebugMode)
                                ElevatedButton.icon(
                                  onPressed: () async {
                                    try {
                                      final populator = FirebasePopulator(
                                          FirebaseFirestore.instance);
                                      await populator.populateChairSOPs();

                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                                'Successfully added 5 chair SOPs to Firebase!'),
                                            backgroundColor: Colors.green,
                                          ),
                                        );

                                        // Refresh SOP list
                                        final sopService =
                                            Provider.of<SOPService>(context,
                                                listen: false);
                                        // Force refresh by re-initializing data
                                        await sopService.refreshSOPs();
                                      }
                                    } catch (e) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content:
                                                Text('Error adding SOPs: $e'),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                    }
                                  },
                                  icon: const Icon(Icons.add_circle_outline),
                                  label: const Text('Add Chair SOPs'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primaryRed,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),

                  // Section title with action
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Recent SOPs',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      if (sopService.sops.length > 6)
                        TextButton.icon(
                          onPressed: () {
                            context.go('/sops');
                          },
                          icon: const Icon(Icons.arrow_forward, size: 18),
                          label: const Text('View All'),
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
                            childAspectRatio: 3.0,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                          ),
                          itemCount: sopService.sops.length > 6
                              ? 6
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
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.description_outlined,
            size: 48,
            color: AppColors.textLight.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No SOPs created yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create your first SOP to get started with the manufacturing process',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textMedium,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              context.go('/editor/new');
            },
            icon: const Icon(Icons.add),
            label: const Text('Create First SOP'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(IconData icon, String value, String label, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 16,
            color: color,
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textLight,
              ),
            ),
          ],
        ),
      ],
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

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      margin: const EdgeInsets.all(0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: AppColors.cardBorder),
      ),
      child: InkWell(
        onTap: () {
          context.go('/editor/${sop.id}');
        },
        child: Row(
          children: [
            // Image section (35% of width)
            Expanded(
              flex: 35,
              child: Stack(
                children: [
                  SizedBox(
                    height: double.infinity,
                    child: _buildImage(imageUrl),
                  ),
                  // Department badge
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                        color: departmentColor.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        sop.categoryName ?? 'Unknown',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 7,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Content section (65% of width)
            Expanded(
              flex: 65,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Title with Rev number
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            sop.title,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 11,
                              color: AppColors.textDark,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            'Rev ${sop.revisionNumber}',
                            style: TextStyle(
                              color: AppColors.textMedium,
                              fontSize: 7,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Stats in a row
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.checklist,
                          size: 10,
                          color: AppColors.textLight,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          '${sop.steps.length} steps',
                          style: TextStyle(
                            color: AppColors.textLight,
                            fontSize: 8,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.calendar_today_outlined,
                          size: 10,
                          color: AppColors.textLight,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          "${sop.createdAt.day}/${sop.createdAt.month}/${sop.createdAt.year}",
                          style: TextStyle(
                            color: AppColors.textLight,
                            fontSize: 8,
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
        return AppColors.primaryRed;
    }
  }

  Widget _buildImage(String? imageUrl) {
    if (imageUrl == null) {
      return Container(
        color: Colors.grey[100],
        width: double.infinity,
        child: Center(
          child: Icon(
            Icons.image_not_supported,
            size: 14,
            color: AppColors.textLight.withOpacity(0.5),
          ),
        ),
      );
    }

    // Check if this is a data URL
    if (imageUrl.startsWith('data:image/')) {
      try {
        final bytes = base64Decode(imageUrl.split(',')[1]);
        return Image.memory(
          bytes,
          width: double.infinity,
          height: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _buildImageError(),
        );
      } catch (e) {
        debugPrint('Error displaying data URL image: $e');
        return _buildImageError();
      }
    }
    // Check if this is an asset image
    else if (imageUrl.startsWith('assets/')) {
      return Image.asset(
        imageUrl,
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildImageError(),
      );
    }
    // Otherwise, assume it's a network image
    else {
      return Image.network(
        imageUrl,
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildImageError(),
      );
    }
  }

  Widget _buildImageError() {
    return Container(
      width: double.infinity,
      color: Colors.grey[100],
      child: Center(
        child: Icon(
          Icons.broken_image,
          size: 14,
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
