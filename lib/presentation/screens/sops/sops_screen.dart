import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../data/services/sop_service.dart';
import '../../../data/services/print_service.dart';
import '../../../data/models/sop_model.dart';
import '../../widgets/app_scaffold.dart';
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
          .where((sop) => sop.department == _selectedDepartment)
          .toList();
    }

    // Get unique departments for filter dropdown
    final departments = [
      'All',
      ...sopService.sops.map((sop) => sop.department).toSet()
    ];

    return AppScaffold(
      title: 'My SOPs',
      actions: [
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
                      labelText: 'Department',
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

          // SOPs list
          Expanded(
            child: filteredSOPs.isEmpty
                ? const Center(
                    child: Text('No SOPs found.'),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredSOPs.length,
                    itemBuilder: (context, index) {
                      final sop = filteredSOPs[index];
                      return _buildSOPCard(context, sop);
                    },
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
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // SOP header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        sop.title,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onPrimaryContainer,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Department: ${sop.department} • Rev: ${sop.revisionNumber}',
                        style: TextStyle(
                          color: Theme.of(context)
                              .colorScheme
                              .onPrimaryContainer
                              .withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Last updated: ${_formatDate(sop.updatedAt)}',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // SOP description
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              sop.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // SOP image (if available)
          if (sop.steps.isNotEmpty && sop.steps.first.imageUrl != null) ...[
            const SizedBox(height: 16),
            _buildImage(sop.steps.first.imageUrl),
          ],

          // Add buttons for actions
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: const Icon(Icons.print),
                  tooltip: 'Print SOP',
                  onPressed: () => _printSOP(sop),
                ),
                IconButton(
                  icon: const Icon(Icons.edit),
                  tooltip: 'Edit SOP',
                  onPressed: () {
                    context.go('/editor/${sop.id}');
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.visibility),
                  tooltip: 'View SOP',
                  onPressed: () {
                    context.go('/editor/${sop.id}');
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImage(String? imageUrl) {
    if (imageUrl == null) {
      return Container(
        color: Colors.grey[300],
        height: 120,
        child: const Center(
          child: Icon(Icons.image_not_supported, size: 40, color: Colors.grey),
        ),
      );
    }

    // Check if this is a data URL
    if (imageUrl.startsWith('data:image/')) {
      try {
        final bytes = base64Decode(imageUrl.split(',')[1]);
        return Image.memory(
          bytes,
          height: 120,
          width: double.infinity,
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
        height: 120,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildImageError(),
      );
    }
    // Otherwise, assume it's a network image
    else {
      return Image.network(
        imageUrl,
        height: 120,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildImageError(),
      );
    }
  }

  Widget _buildImageError() {
    return Container(
      height: 120,
      color: Colors.grey[200],
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.broken_image,
              size: 30,
              color: Colors.grey,
            ),
            SizedBox(height: 4),
            Text(
              'Image not available',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }
}
