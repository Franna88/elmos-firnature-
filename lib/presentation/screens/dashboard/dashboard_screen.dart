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
      ],
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Simplified header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome back, ${authService.userName ?? 'User'}',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Manage your furniture manufacturing procedures efficiently.',
                            style: TextStyle(
                              color: AppColors.textMedium,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      ElevatedButton.icon(
                        onPressed: () {
                          context.go('/editor/new');
                        },
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Create SOP'),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Section title
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Standard Operating Procedures',
                        style: Theme.of(context).textTheme.titleMedium,
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
                  const SizedBox(height: 12),

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
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
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
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
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
      elevation: 1,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: AppColors.cardBorder.withOpacity(0.5)),
      ),
      child: InkWell(
        onTap: () {
          context.go('/editor/${sop.id}');
        },
        child: Row(
          children: [
            // Image section (30% of width)
            Expanded(
              flex: 30,
              child: Stack(
                children: [
                  SizedBox(
                    height: double.infinity,
                    child: _buildImage(imageUrl),
                  ),
                  // Department badge
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
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
                              color: AppColors.textDark,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(4),
                            border:
                                Border.all(color: Colors.grey.withOpacity(0.3)),
                          ),
                          child: Text(
                            'Rev ${sop.revisionNumber}',
                            style: TextStyle(
                              color: AppColors.textMedium,
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
                          color: AppColors.textMedium,
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
                          color: AppColors.textLight,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${sop.steps.length} steps',
                          style: TextStyle(
                            color: AppColors.textLight,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(
                          Icons.calendar_today_outlined,
                          size: 14,
                          color: AppColors.textLight,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          "${sop.createdAt.day}/${sop.createdAt.month}/${sop.createdAt.year}",
                          style: TextStyle(
                            color: AppColors.textLight,
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
    if (kDebugMode) {
      print('Building image with URL: $imageUrl');
    }

    if (imageUrl == null) {
      if (kDebugMode) {
        print('Image URL is null, displaying placeholder');
      }
      return Container(
        color: Colors.grey[100],
        width: double.infinity,
        child: Center(
          child: Icon(
            Icons.image_not_supported,
            size: 20,
            color: AppColors.textLight.withOpacity(0.5),
          ),
        ),
      );
    }

    // Check if this is a data URL
    if (imageUrl.startsWith('data:image/')) {
      if (kDebugMode) {
        print('Processing data URL image');
      }
      try {
        final bytes = base64Decode(imageUrl.split(',')[1]);
        return Image.memory(
          bytes,
          width: double.infinity,
          height: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            if (kDebugMode) {
              print('Error displaying data URL image: $error');
            }
            return _buildImageError();
          },
        );
      } catch (e) {
        debugPrint('Error displaying data URL image: $e');
        return _buildImageError();
      }
    }
    // Check if this is an asset image
    else if (imageUrl.startsWith('assets/')) {
      if (kDebugMode) {
        print('Processing asset image: $imageUrl');
      }
      return Image.asset(
        imageUrl,
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          if (kDebugMode) {
            print('Error displaying asset image: $error');
          }
          return _buildImageError();
        },
      );
    }
    // Otherwise, assume it's a network image
    else {
      if (kDebugMode) {
        print('Processing network image: $imageUrl');
      }
      return Image.network(
        imageUrl,
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          if (kDebugMode) {
            print('Error displaying network image: $error');
            print('Network error details: $error');
          }
          return _buildImageError();
        },
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
          size: 20,
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
