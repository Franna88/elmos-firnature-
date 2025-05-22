import 'package:flutter/material.dart';
import '../../design_system/design_system.dart';
import '../../design_system/responsive/responsive_layout.dart';

/// SOP Category model
class SOPCategory {
  final String id;
  final String name;
  final String description;
  final Color color;
  final int sopCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  SOPCategory({
    required this.id,
    required this.name,
    required this.description,
    required this.color,
    required this.sopCount,
    required this.createdAt,
    required this.updatedAt,
  });
}

/// SOP Category Management Screen
///
/// Provides functionality to create, edit, and manage SOP categories
/// with responsive layouts for desktop, mobile, and tablet platforms.
class SOPCategoryManagementScreen extends StatefulWidget {
  const SOPCategoryManagementScreen({Key? key}) : super(key: key);

  @override
  State<SOPCategoryManagementScreen> createState() =>
      _SOPCategoryManagementScreenState();
}

class _SOPCategoryManagementScreenState
    extends State<SOPCategoryManagementScreen> {
  bool _isLoading = false;
  String _searchQuery = '';
  final _formKey = GlobalKey<FormState>();

  // Form controllers
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();

  // Currently selected category for editing
  SOPCategory? _selectedCategory;

  // Selected color for new or edited category
  Color _selectedColor = Colors.blue;

  // Sample categories for demonstration
  final List<SOPCategory> _categories = [
    SOPCategory(
      id: 'CAT001',
      name: 'Assembly',
      description: 'Procedures for assembling furniture products',
      color: Colors.blue,
      sopCount: 12,
      createdAt: DateTime(2023, 1, 15),
      updatedAt: DateTime(2023, 10, 5),
    ),
    SOPCategory(
      id: 'CAT002',
      name: 'Quality Control',
      description: 'Quality verification and testing procedures',
      color: Colors.green,
      sopCount: 8,
      createdAt: DateTime(2023, 2, 10),
      updatedAt: DateTime(2023, 9, 22),
    ),
    SOPCategory(
      id: 'CAT003',
      name: 'Packaging',
      description: 'Product packaging and shipping preparation',
      color: Colors.amber,
      sopCount: 6,
      createdAt: DateTime(2023, 3, 5),
      updatedAt: DateTime(2023, 8, 15),
    ),
    SOPCategory(
      id: 'CAT004',
      name: 'Production',
      description: 'Manufacturing and production line procedures',
      color: Colors.red,
      sopCount: 15,
      createdAt: DateTime(2023, 4, 20),
      updatedAt: DateTime(2023, 10, 12),
    ),
    SOPCategory(
      id: 'CAT005',
      name: 'Finishing',
      description: 'Surface treatment and finishing processes',
      color: Colors.purple,
      sopCount: 10,
      createdAt: DateTime(2023, 5, 8),
      updatedAt: DateTime(2023, 9, 30),
    ),
    SOPCategory(
      id: 'CAT006',
      name: 'Safety',
      description: 'Safety protocols and procedures',
      color: Colors.orange,
      sopCount: 7,
      createdAt: DateTime(2023, 6, 15),
      updatedAt: DateTime(2023, 10, 1),
    ),
    SOPCategory(
      id: 'CAT007',
      name: 'Maintenance',
      description: 'Equipment and tool maintenance procedures',
      color: Colors.teal,
      sopCount: 9,
      createdAt: DateTime(2023, 7, 22),
      updatedAt: DateTime(2023, 10, 8),
    ),
    SOPCategory(
      id: 'CAT008',
      name: 'Logistics',
      description: 'Inventory and warehouse operations',
      color: Colors.indigo,
      sopCount: 11,
      createdAt: DateTime(2023, 8, 10),
      updatedAt: DateTime(2023, 10, 15),
    ),
  ];

  List<SOPCategory> get _filteredCategories {
    if (_searchQuery.isEmpty) {
      return _categories;
    }

    final query = _searchQuery.toLowerCase();
    return _categories.where((category) {
      return category.name.toLowerCase().contains(query) ||
          category.description.toLowerCase().contains(query) ||
          category.id.toLowerCase().contains(query);
    }).toList();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _createCategory() {
    _nameController.clear();
    _descriptionController.clear();
    _selectedColor = Colors.blue;
    _selectedCategory = null;

    _showCategoryDialog(isNew: true);
  }

  void _editCategory(SOPCategory category) {
    _nameController.text = category.name;
    _descriptionController.text = category.description;
    _selectedColor = category.color;
    _selectedCategory = category;

    _showCategoryDialog(isNew: false);
  }

  void _deleteCategory(SOPCategory category) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Category'),
        content: RichText(
          text: TextSpan(
            style: DefaultTextStyle.of(context).style,
            children: [
              const TextSpan(
                text: 'Are you sure you want to delete the category ',
              ),
              TextSpan(
                text: category.name,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              TextSpan(
                text:
                    '? This will not delete the ${category.sopCount} SOPs in this category, but they will be unassigned.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                // In a real app, this would call an API
                _categories.removeWhere((c) => c.id == category.id);
              });

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Category "${category.name}" deleted'),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  void _showCategoryDialog({required bool isNew}) {
    final appTheme = AppTheme.of(context);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isNew ? 'Create Category' : 'Edit Category'),
        content: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Category Name',
                    hintText: 'Enter category name',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a category name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    hintText: 'Enter category description',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a description';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                Text(
                  'Category Color',
                  style: appTheme.typography.subtitle1,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Colors.blue,
                    Colors.green,
                    Colors.red,
                    Colors.orange,
                    Colors.purple,
                    Colors.teal,
                    Colors.amber,
                    Colors.indigo,
                    Colors.pink,
                  ].map((color) {
                    return InkWell(
                      onTap: () {
                        setState(() {
                          _selectedColor = color;
                        });
                        Navigator.pop(context);
                        _showCategoryDialog(isNew: isNew);
                      },
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _selectedColor == color
                                ? appTheme.colors.textPrimaryColor
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: _selectedColor == color
                            ? const Icon(Icons.check, color: Colors.white)
                            : null,
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (_formKey.currentState!.validate()) {
                Navigator.pop(context);

                setState(() {
                  if (isNew) {
                    // In a real app, this would call an API to create a new category
                    final newCategory = SOPCategory(
                      id: 'CAT${_categories.length + 1}',
                      name: _nameController.text,
                      description: _descriptionController.text,
                      color: _selectedColor,
                      sopCount: 0,
                      createdAt: DateTime.now(),
                      updatedAt: DateTime.now(),
                    );
                    _categories.add(newCategory);

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Category "${newCategory.name}" created'),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  } else if (_selectedCategory != null) {
                    // In a real app, this would call an API to update the category
                    final index = _categories
                        .indexWhere((c) => c.id == _selectedCategory!.id);

                    if (index != -1) {
                      final updatedCategory = SOPCategory(
                        id: _selectedCategory!.id,
                        name: _nameController.text,
                        description: _descriptionController.text,
                        color: _selectedColor,
                        sopCount: _selectedCategory!.sopCount,
                        createdAt: _selectedCategory!.createdAt,
                        updatedAt: DateTime.now(),
                      );

                      _categories[index] = updatedCategory;

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                              'Category "${updatedCategory.name}" updated'),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                  }
                });
              }
            },
            child: Text(isNew ? 'Create' : 'Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appTheme = AppTheme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Category Management',
            style: appTheme.typography.headingSmall),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () {
              // Show help dialog
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Category Management Help'),
                  content: const Text(
                    'SOP Categories help organize your Standard Operating Procedures '
                    'by department, function, or any other classification that makes sense '
                    'for your organization. Each category can be assigned a color for visual '
                    'identification. Create, edit, or delete categories here.',
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
            tooltip: 'Help',
          ),
        ],
      ),
      body: ResponsiveLayout(
        mobile: _buildMobileLayout(appTheme),
        tablet: _buildTabletLayout(appTheme),
        desktop: _buildDesktopLayout(appTheme),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createCategory,
        child: const Icon(Icons.add),
        tooltip: 'Create New Category',
      ),
    );
  }

  Widget _buildMobileLayout(AppTheme appTheme) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SOP Categories',
            style: appTheme.typography.headingLarge,
          ),
          const SizedBox(height: 16),
          TextField(
            decoration: const InputDecoration(
              hintText: 'Search categories...',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
          ),
          const SizedBox(height: 16),
          Text(
            '${_filteredCategories.length} categories found',
            style: appTheme.typography.caption,
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: _filteredCategories.length,
                    itemBuilder: (context, index) {
                      final category = _filteredCategories[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: category.color,
                            child: Text(
                              category.name.substring(0, 1).toUpperCase(),
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                          title: Text(category.name),
                          subtitle: Text(
                            '${category.sopCount} SOPs • Updated ${_formatDate(category.updatedAt)}',
                          ),
                          trailing: PopupMenuButton<String>(
                            onSelected: (value) {
                              if (value == 'edit') {
                                _editCategory(category);
                              } else if (value == 'delete') {
                                _deleteCategory(category);
                              }
                            },
                            itemBuilder: (BuildContext context) => [
                              const PopupMenuItem<String>(
                                value: 'edit',
                                child: Text('Edit'),
                              ),
                              const PopupMenuItem<String>(
                                value: 'delete',
                                child: Text('Delete'),
                              ),
                            ],
                          ),
                          onTap: () => _editCategory(category),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabletLayout(AppTheme appTheme) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'SOP Categories',
                style: appTheme.typography.headingLarge,
              ),
              ElevatedButton.icon(
                onPressed: _createCategory,
                icon: const Icon(Icons.add),
                label: const Text('New Category'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'Search categories...',
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
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '${_filteredCategories.length} categories found',
            style: appTheme.typography.caption,
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 2.5,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                    ),
                    itemCount: _filteredCategories.length,
                    itemBuilder: (context, index) {
                      final category = _filteredCategories[index];
                      return _buildCategoryCard(category, appTheme);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout(AppTheme appTheme) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'SOP Categories',
                style: appTheme.typography.headingLarge,
              ),
              ElevatedButton.icon(
                onPressed: _createCategory,
                icon: const Icon(Icons.add),
                label: const Text('New Category'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        decoration: const InputDecoration(
                          hintText: 'Search categories...',
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
                    Text(
                      '${_filteredCategories.length} categories found',
                      style: appTheme.typography.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      childAspectRatio: 3,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                    ),
                    itemCount: _filteredCategories.length,
                    itemBuilder: (context, index) {
                      final category = _filteredCategories[index];
                      return _buildCategoryCard(category, appTheme);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryCard(SOPCategory category, AppTheme appTheme) {
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      child: InkWell(
        onTap: () => _editCategory(category),
        child: Column(
          children: [
            // Category color bar
            Container(
              height: 8,
              color: category.color,
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: category.color,
                      radius: 24,
                      child: Text(
                        category.name.substring(0, 1).toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            category.name,
                            style: appTheme.typography.subtitle1.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            category.description,
                            style: appTheme.typography.bodyMedium,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${category.sopCount} SOPs • Updated ${_formatDate(category.updatedAt)}',
                            style: appTheme.typography.caption,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'edit') {
                          _editCategory(category);
                        } else if (value == 'delete') {
                          _deleteCategory(category);
                        }
                      },
                      itemBuilder: (BuildContext context) => [
                        const PopupMenuItem<String>(
                          value: 'edit',
                          child: Text('Edit'),
                        ),
                        const PopupMenuItem<String>(
                          value: 'delete',
                          child: Text('Delete'),
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

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
