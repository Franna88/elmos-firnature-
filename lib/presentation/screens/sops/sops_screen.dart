import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../data/services/sop_service.dart';
import '../../../data/services/print_service.dart';
import '../../../data/models/sop_model.dart';
import '../../widgets/app_scaffold.dart';
import '../../../core/theme/app_theme.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kDebugMode;
import '../../widgets/cross_platform_image.dart';

class SOPsScreen extends StatefulWidget {
  const SOPsScreen({super.key});

  @override
  State<SOPsScreen> createState() => _SOPsScreenState();
}

class _SOPsScreenState extends State<SOPsScreen> {
  String _searchQuery = '';
  String _selectedDepartment = 'All';
  final _printService = PrintService();
  bool _isLoading = true;

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

  // Method to handle printing an SOP
  void _printSOP(SOP sop) {
    _printService.printSOP(context, sop);
  }

  @override
  Widget build(BuildContext context) {
    final sopService = Provider.of<SOPService>(context);

    // Filter SOPs based on search query and department
    List<SOP> filteredSOPs = sopService.searchSOPs(_searchQuery);
    if (_selectedDepartment != 'All') {
      filteredSOPs = filteredSOPs
          .where((sop) => sop.categoryName == _selectedDepartment)
          .toList();
    }

    // Get unique departments for filter dropdown
    final departments = [
      'All',
      ...sopService.sops
          .map((sop) => sop.categoryName ?? 'Unknown')
          .toSet()
          .toList()
    ];

    return AppScaffold(
      title: 'My SOPs',
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
          tooltip: 'Delete Selected SOPs',
          onPressed: () {
            // Show dialog to confirm deletion
            _showDeleteSOPDialog();
          },
        ),
        IconButton(
          icon: const Icon(Icons.help_outline),
          onPressed: () {
            // Show help dialog
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Furniture SOPs Help'),
                content: const Text(
                  'Standard Operating Procedures (SOPs) document the standard processes '
                  'for your furniture manufacturing operations. Here you can manage SOPs for wood finishing, '
                  'assembly, upholstery, and CNC operations to ensure consistent quality in all your products.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('OK'),
                  ),
                ],
              ),
            );
          },
        ),
      ],
      body: Column(
        children: [
          // Search and filter bar
          Container(
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).colorScheme.surface,
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: 'Search SOPs...',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      border: OutlineInputBorder(),
                    ),
                    value: _selectedDepartment,
                    items: departments.map((department) {
                      return DropdownMenuItem<String>(
                        value: department,
                        child: Text(department),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _selectedDepartment = value;
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
          ),

          // SOPs grid view (matching dashboard style)
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(),
                  )
                : filteredSOPs.isEmpty
                    ? const Center(
                        child: Text('No SOPs found.'),
                      )
                    : Padding(
                        padding: const EdgeInsets.all(16),
                        child: GridView.builder(
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            childAspectRatio: 3.0,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                          ),
                          itemCount: filteredSOPs.length,
                          itemBuilder: (context, index) {
                            final sop = filteredSOPs[index];
                            return _buildSOPCard(context, sop);
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          context.go('/editor/new');
        },
        backgroundColor: const Color(0xffB21E1E),
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
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
      elevation: 2, // Increased elevation for better visibility
      margin: const EdgeInsets.all(4), // Added small margin
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
                    height: 100,
                    child: _buildImage(imageUrl),
                  ),
                  // Department badge
                  Positioned(
                    top: 6, // Increased slightly
                    right: 6, // Increased slightly
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 3), // Increased padding
                      decoration: BoxDecoration(
                        color: departmentColor.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        sop.categoryName ?? 'Unknown',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9, // Increased from 7
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
                              fontSize: 14, // Increased from 11
                              color: AppColors.textDark,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 2), // Increased padding
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            'Rev ${sop.revisionNumber}',
                            style: TextStyle(
                              color: AppColors.textMedium,
                              fontSize: 9, // Increased from 7
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Description (new addition)
                    const SizedBox(height: 4),
                    Text(
                      sop.description,
                      style: TextStyle(
                        color: AppColors.textMedium,
                        fontSize: 10, // Readable size for description
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),

                    // Stats in a row
                    const SizedBox(height: 8), // Increased spacing
                    Row(
                      children: [
                        Icon(
                          Icons.format_list_numbered,
                          size: 12, // Increased from 10
                          color: AppColors.textLight,
                        ),
                        const SizedBox(width: 4), // Increased spacing
                        Text(
                          '${sop.steps.length} steps',
                          style: TextStyle(
                            color: AppColors.textLight,
                            fontSize: 10, // Increased from 8
                          ),
                        ),
                        const SizedBox(width: 12), // Increased spacing
                        Icon(
                          Icons.calendar_today_outlined,
                          size: 12, // Increased from 10
                          color: AppColors.textLight,
                        ),
                        const SizedBox(width: 4), // Increased spacing
                        Text(
                          _formatDate(sop.updatedAt), // Changed to updated date
                          style: TextStyle(
                            color: AppColors.textLight,
                            fontSize: 10, // Increased from 8
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
        width: 140,
        height: 100,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.image_not_supported,
                size: 24,
                color: AppColors.textLight.withOpacity(0.7),
              ),
              const SizedBox(height: 6),
              Text(
                "No Thumbnail",
                style: TextStyle(
                  fontSize: 10,
                  color: AppColors.textLight.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return CrossPlatformImage(
      imageUrl: imageUrl,
      width: 140,
      height: 100,
      fit: BoxFit.cover,
      errorWidget: _buildImageError(),
    );
  }

  Widget _buildImageError() {
    return Container(
      width: 140,
      height: 100,
      color: Colors.grey[100],
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.broken_image,
              size: 24,
              color: AppColors.textLight.withOpacity(0.7),
            ),
            const SizedBox(height: 6),
            Text(
              "Image Error",
              style: TextStyle(
                fontSize: 10,
                color: AppColors.textLight.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return "${date.day}/${date.month}/${date.year}";
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
                        subtitle:
                            Text('Created: ${_formatDate(sop.createdAt)}'),
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
