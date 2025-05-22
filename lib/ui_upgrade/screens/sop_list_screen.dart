import 'package:flutter/material.dart';
import '../design_system/design_system.dart';

/// A model class representing a Standard Operating Procedure (SOP)
class SOP {
  final String id;
  final String title;
  final String category;
  final DateTime lastUpdated;
  final String author;
  final int stepCount;
  final String status;

  SOP({
    required this.id,
    required this.title,
    required this.category,
    required this.lastUpdated,
    required this.author,
    required this.stepCount,
    required this.status,
  });
}

/// SOP List/Browse Screen
///
/// This screen displays a list of SOPs with filtering, sorting, and search capabilities.
/// It demonstrates the use of the AppDataTable component.
class SOPListScreen extends StatefulWidget {
  const SOPListScreen({Key? key}) : super(key: key);

  @override
  State<SOPListScreen> createState() => _SOPListScreenState();
}

class _SOPListScreenState extends State<SOPListScreen> {
  bool _isLoading = false;
  String _searchQuery = '';
  String _selectedCategory = 'All Categories';
  String _selectedStatus = 'All Statuses';

  // Sample data for demonstration
  final List<SOP> _sops = [
    SOP(
      id: 'SOP-001',
      title: 'Assembly of Chair Model A',
      category: 'Assembly',
      lastUpdated: DateTime(2023, 5, 15),
      author: 'John Smith',
      stepCount: 12,
      status: 'Published',
    ),
    SOP(
      id: 'SOP-002',
      title: 'Quality Check for Tables',
      category: 'Quality Control',
      lastUpdated: DateTime(2023, 6, 22),
      author: 'Emma Johnson',
      stepCount: 8,
      status: 'Published',
    ),
    SOP(
      id: 'SOP-003',
      title: 'Packaging Guidelines',
      category: 'Packaging',
      lastUpdated: DateTime(2023, 7, 10),
      author: 'Michael Brown',
      stepCount: 6,
      status: 'Draft',
    ),
    SOP(
      id: 'SOP-004',
      title: 'Sofa Upholstery Process',
      category: 'Production',
      lastUpdated: DateTime(2023, 8, 5),
      author: 'Sarah Davis',
      stepCount: 15,
      status: 'Published',
    ),
    SOP(
      id: 'SOP-005',
      title: 'Wood Finishing Techniques',
      category: 'Finishing',
      lastUpdated: DateTime(2023, 8, 18),
      author: 'David Wilson',
      stepCount: 10,
      status: 'Under Review',
    ),
    SOP(
      id: 'SOP-006',
      title: 'Material Handling Safety',
      category: 'Safety',
      lastUpdated: DateTime(2023, 9, 1),
      author: 'Lisa Martinez',
      stepCount: 7,
      status: 'Published',
    ),
    SOP(
      id: 'SOP-007',
      title: 'CNC Machine Operation',
      category: 'Production',
      lastUpdated: DateTime(2023, 9, 12),
      author: 'Robert Taylor',
      stepCount: 14,
      status: 'Draft',
    ),
    SOP(
      id: 'SOP-008',
      title: 'Inventory Management',
      category: 'Logistics',
      lastUpdated: DateTime(2023, 9, 25),
      author: 'Jennifer Anderson',
      stepCount: 9,
      status: 'Published',
    ),
    SOP(
      id: 'SOP-009',
      title: 'Customer Delivery Protocol',
      category: 'Logistics',
      lastUpdated: DateTime(2023, 10, 5),
      author: 'Thomas Clark',
      stepCount: 11,
      status: 'Under Review',
    ),
    SOP(
      id: 'SOP-010',
      title: 'Workspace Organization',
      category: 'Safety',
      lastUpdated: DateTime(2023, 10, 15),
      author: 'Amanda Lewis',
      stepCount: 5,
      status: 'Published',
    ),
    SOP(
      id: 'SOP-011',
      title: 'Tool Maintenance',
      category: 'Maintenance',
      lastUpdated: DateTime(2023, 10, 20),
      author: 'Kevin Moore',
      stepCount: 8,
      status: 'Draft',
    ),
    SOP(
      id: 'SOP-012',
      title: 'Customer Return Processing',
      category: 'Customer Service',
      lastUpdated: DateTime(2023, 10, 28),
      author: 'Melissa White',
      stepCount: 7,
      status: 'Published',
    ),
  ];

  List<String> get _categories {
    final categories = _sops.map((sop) => sop.category).toSet().toList();
    categories.sort();
    return ['All Categories', ...categories];
  }

  List<String> get _statuses {
    final statuses = _sops.map((sop) => sop.status).toSet().toList();
    statuses.sort();
    return ['All Statuses', ...statuses];
  }

  List<SOP> get _filteredSOPs {
    return _sops.where((sop) {
      // Apply category filter
      if (_selectedCategory != 'All Categories' &&
          sop.category != _selectedCategory) {
        return false;
      }

      // Apply status filter
      if (_selectedStatus != 'All Statuses' && sop.status != _selectedStatus) {
        return false;
      }

      // Apply search filter
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        return sop.title.toLowerCase().contains(query) ||
            sop.id.toLowerCase().contains(query) ||
            sop.author.toLowerCase().contains(query);
      }

      return true;
    }).toList();
  }

  void _onSOPTap(SOP sop) {
    // Navigate to SOP details screen
    Navigator.pushNamed(
      context,
      '/sop-viewer',
      arguments: sop.id,
    );
  }

  void _createNewSOP() {
    // Navigate to SOP creation screen
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Create New SOP'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appTheme = AppTheme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('SOP Management', style: appTheme.typography.headingSmall),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () {
              // Show help dialog
            },
            tooltip: 'Help',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header section with title and actions
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Standard Operating Procedures',
                  style: appTheme.typography.headingLarge,
                ),
                ElevatedButton.icon(
                  onPressed: _createNewSOP,
                  icon: const Icon(Icons.add),
                  label: const Text('Create New SOP'),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Filters and search section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Filters', style: appTheme.typography.subtitle1),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        // Search field
                        Expanded(
                          flex: 2,
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

                        // Category filter
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            decoration: const InputDecoration(
                              labelText: 'Category',
                              border: OutlineInputBorder(),
                            ),
                            value: _selectedCategory,
                            items: _categories.map((category) {
                              return DropdownMenuItem<String>(
                                value: category,
                                child: Text(category),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedCategory = value!;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 16),

                        // Status filter
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            decoration: const InputDecoration(
                              labelText: 'Status',
                              border: OutlineInputBorder(),
                            ),
                            value: _selectedStatus,
                            items: _statuses.map((status) {
                              return DropdownMenuItem<String>(
                                value: status,
                                child: Text(status),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedStatus = value!;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Results count
            Text(
              '${_filteredSOPs.length} SOPs found',
              style: appTheme.typography.caption,
            ),
            const SizedBox(height: 8),

            // Data table
            Expanded(
              child: AppDataTable<SOP>(
                columns: [
                  AppDataColumn<SOP>(
                    label: const Text('ID'),
                    onSort: (a, b) => a.id.compareTo(b.id),
                  ),
                  AppDataColumn<SOP>(
                    label: const Text('Title'),
                    onSort: (a, b) => a.title.compareTo(b.title),
                  ),
                  AppDataColumn<SOP>(
                    label: const Text('Category'),
                    onSort: (a, b) => a.category.compareTo(b.category),
                  ),
                  AppDataColumn<SOP>(
                    label: const Text('Last Updated'),
                    onSort: (a, b) => a.lastUpdated.compareTo(b.lastUpdated),
                  ),
                  AppDataColumn<SOP>(
                    label: const Text('Author'),
                    onSort: (a, b) => a.author.compareTo(b.author),
                  ),
                  AppDataColumn<SOP>(
                    label: const Text('Steps'),
                    numeric: true,
                    onSort: (a, b) => a.stepCount.compareTo(b.stepCount),
                  ),
                  AppDataColumn<SOP>(
                    label: const Text('Status'),
                    onSort: (a, b) => a.status.compareTo(b.status),
                  ),
                  AppDataColumn<SOP>(
                    label: const Text('Actions'),
                  ),
                ],
                data: _filteredSOPs,
                rowBuilder: (sop, index) => [
                  DataCell(Text(sop.id)),
                  DataCell(Text(sop.title)),
                  DataCell(Text(sop.category)),
                  DataCell(Text(
                      '${sop.lastUpdated.day}/${sop.lastUpdated.month}/${sop.lastUpdated.year}')),
                  DataCell(Text(sop.author)),
                  DataCell(Text('${sop.stepCount}')),
                  DataCell(_buildStatusChip(sop.status, appTheme)),
                  DataCell(Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.visibility),
                        tooltip: 'View',
                        onPressed: () => _onSOPTap(sop),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit),
                        tooltip: 'Edit',
                        onPressed: () {
                          // Navigate to edit screen
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        tooltip: 'Delete',
                        onPressed: () {
                          // Show delete confirmation
                        },
                      ),
                    ],
                  )),
                ],
                onRowTap: _onSOPTap,
                isLoading: _isLoading,
                initialSortColumnIndex: 0,
                initialSortAscending: true,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status, AppTheme appTheme) {
    Color chipColor;
    Color textColor = Colors.white;

    switch (status) {
      case 'Published':
        chipColor = appTheme.colors.successColor;
        break;
      case 'Draft':
        chipColor = appTheme.colors.grey300Color;
        textColor = appTheme.colors.textPrimaryColor;
        break;
      case 'Under Review':
        chipColor = appTheme.colors.warningColor;
        textColor = appTheme.colors.textPrimaryColor;
        break;
      default:
        chipColor = appTheme.colors.infoColor;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: chipColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status,
        style: appTheme.typography.labelSmall.copyWith(color: textColor),
      ),
    );
  }
}
