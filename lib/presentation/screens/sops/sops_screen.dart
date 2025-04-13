import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../data/services/sop_service.dart';
import '../../../data/services/print_service.dart';
import '../../../data/models/sop_model.dart';
import '../../widgets/app_scaffold.dart';
import '../../../core/theme/app_theme.dart';
import 'dart:convert';

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
    // Get primary image for the card
    final String? imageUrl =
        sop.steps.isNotEmpty && sop.steps.first.imageUrl != null
            ? sop.steps.first.imageUrl
            : null;

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
                          _formatDate(sop.createdAt),
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

  String _formatDate(DateTime date) {
    return "${date.day}/${date.month}/${date.year}";
  }
}
