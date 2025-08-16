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
import '../../../data/services/category_service.dart';

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
    final categoryService =
        Provider.of<CategoryService>(context, listen: false);
    _printService.printSOP(context, sop, categoryService);
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

    // Sort SOPs alphabetically by title
    filteredSOPs
        .sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));

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
                      labelText: 'Search SOPs...',
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
                            crossAxisCount: 4,
                            childAspectRatio: 0.8,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                          ),
                          itemCount: filteredSOPs.length,
                          itemBuilder: (context, index) {
                            final sop = filteredSOPs[index];
                            return Card(
                              key: ValueKey(sop.id),
                              clipBehavior: Clip.antiAlias,
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: _buildSOPCard(context, sop),
                            );
                          },
                        ),
                      ),
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

    final categoryService =
        Provider.of<CategoryService>(context, listen: false);
    final Color departmentColor =
        _getCategoryColor(sop.categoryId, categoryService);

    return InkWell(
      onTap: () async {
        final sopService = Provider.of<SOPService>(context, listen: false);

        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return Dialog(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(width: 20),
                    Text('Loading images for "${sop.title}"...'),
                  ],
                ),
              ),
            );
          },
        );

        await sopService.forcePreloadSOP(sop.id);

        if (context.mounted) {
          Navigator.of(context).pop();

          context.go('/editor/${sop.id}');
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
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
                Expanded(
                  child: Text(
                    sop.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
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
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return CrossPlatformImage(
                  key: ValueKey(imageUrl),
                  imageUrl: imageUrl,
                  width: constraints.maxWidth,
                  height: constraints.maxHeight,
                  fit: BoxFit.cover,
                  errorWidget: _buildImageError(),
                );
              },
            ),
          ),

          // Content section
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                Row(
                  children: [
                    const Icon(
                      Icons.format_list_numbered,
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
                      _formatDate(sop.updatedAt),
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
    );
  }

  Color _getCategoryColor(String categoryId, CategoryService categoryService) {
    if (categoryId.isEmpty) {
      return AppColors.primaryBlue;
    }

    final category = categoryService.getCategoryById(categoryId);
    if (category != null &&
        category.color != null &&
        category.color!.startsWith('#')) {
      try {
        return Color(int.parse('FF${category.color!.substring(1)}', radix: 16));
      } catch (e) {
        return AppColors.primaryBlue;
      }
    }

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
