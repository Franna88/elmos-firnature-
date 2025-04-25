import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../data/services/sop_service.dart';
import '../../../data/services/category_service.dart';
import '../../../data/models/sop_model.dart';
import '../../../data/models/category_model.dart';
import '../../../data/models/section_suggestion.dart';
import '../../widgets/app_scaffold.dart';
import 'package:go_router/go_router.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final sopService = Provider.of<SOPService>(context);
    final categoryService = Provider.of<CategoryService>(context);

    // Filter SOPs based on search query
    List<SOP> filteredSOPs = sopService.searchSOPs(_searchQuery);

    // Group SOPs by category
    Map<String, List<SOP>> sopsByCategory = {};

    // Initialize the map with all categories (even empty ones)
    for (var category in categoryService.categories) {
      sopsByCategory[category.id] = [];
    }

    // Group SOPs by categoryId
    for (var sop in filteredSOPs) {
      if (sopsByCategory.containsKey(sop.categoryId)) {
        sopsByCategory[sop.categoryId]!.add(sop);
      }
    }

    // Filter out empty categories when searching
    List<Category> displayCategories = categoryService.categories;
    if (_searchQuery.isNotEmpty) {
      displayCategories = categoryService.categories
          .where(
              (category) => (sopsByCategory[category.id]?.isNotEmpty) ?? false)
          .toList();
    }

    return AppScaffold(
      title: 'SOP Categories',
      actions: [
        // Add Category button
        IconButton(
          icon: const Icon(Icons.add_circle_outline),
          tooltip: 'Add Category',
          onPressed: () => _showAddCategoryDialog(context),
        ),
        IconButton(
          icon: const Icon(Icons.help_outline),
          onPressed: () {
            // Show help dialog
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Categories Help'),
                content: const Text(
                  'This screen shows all SOPs organized by their categories. '
                  'Each category contains all the SOPs that belong to it. '
                  'Use the search bar to find specific SOPs across all categories. '
                  'Click the settings icon on a category to configure which sections are required.',
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
          // Search bar
          Container(
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).colorScheme.surface,
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

          // Categories grid
          Expanded(
            child: categoryService.categories.isEmpty
                ? const Center(
                    child: Text('No categories found.'),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio:
                          0.8, // Adjusted aspect ratio to make cards taller
                    ),
                    itemCount: displayCategories.length,
                    itemBuilder: (context, index) {
                      final category = displayCategories[index];
                      final categorySOPs = sopsByCategory[category.id] ?? [];
                      return _buildCategoryCard(
                          context, category, categorySOPs);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryCard(
      BuildContext context, Category category, List<SOP> sops) {
    // Convert hex color to Color object
    Color categoryColor = Theme.of(context).colorScheme.primary;
    if (category.color != null && category.color!.startsWith('#')) {
      try {
        categoryColor = Color(
          int.parse('FF${category.color!.substring(1)}', radix: 16),
        );
      } catch (e) {
        // Use default color if parsing fails
      }
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Category header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: categoryColor.withOpacity(0.8),
            width: double.infinity,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category.name,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${sops.length} SOPs',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.white.withOpacity(0.9),
                            ),
                      ),
                    ],
                  ),
                ),
                // Settings/gear icon for category settings
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Colors.white),
                  tooltip: 'Category Options',
                  onSelected: (value) {
                    if (value == 'edit') {
                      _showCategorySettingsDialog(context, category);
                    } else if (value == 'delete') {
                      // Get SOPs for this category to check if it's in use
                      final sopService =
                          Provider.of<SOPService>(context, listen: false);
                      final categorySOPs = sopService.sops
                          .where((sop) => sop.categoryId == category.id)
                          .toList();

                      final hasSOPs = categorySOPs.isNotEmpty;

                      // Show confirmation dialog before deleting
                      showDialog(
                        context: context,
                        builder: (context) {
                          return AlertDialog(
                            title: const Text('Delete Category'),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                    'Are you sure you want to delete the category "${category.name}"?'),
                                const SizedBox(height: 8),
                                const Text(
                                  'This action cannot be undone.',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                if (hasSOPs) ...[
                                  const SizedBox(height: 16),
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.shade100,
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                          color: Colors.amber.shade800),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(Icons.warning_amber,
                                                color: Colors.amber.shade800),
                                            const SizedBox(width: 8),
                                            const Text(
                                              'Warning',
                                              style: TextStyle(
                                                  fontWeight: FontWeight.bold),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                            'This category contains ${categorySOPs.length} SOP${categorySOPs.length == 1 ? '' : 's'}. '
                                            'Deleting this category will remove the category assignment from these SOPs.'),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('CANCEL'),
                              ),
                              ElevatedButton(
                                onPressed: () {
                                  final categoryService =
                                      Provider.of<CategoryService>(context,
                                          listen: false);

                                  // First dismiss the confirmation dialog
                                  Navigator.pop(context);

                                  // Delete the category
                                  categoryService.deleteCategory(category.id);

                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                          'Category "${category.name}" deleted'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  foregroundColor: Colors.white,
                                ),
                                child: const Text('DELETE'),
                              ),
                            ],
                          );
                        },
                      );
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem<String>(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit, size: 18),
                          SizedBox(width: 8),
                          Text('Edit Category'),
                        ],
                      ),
                    ),
                    const PopupMenuItem<String>(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, color: Colors.red, size: 18),
                          SizedBox(width: 8),
                          Text('Delete Category',
                              style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Category description if available
          if (category.description != null && category.description!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Text(
                category.description!,
                style: Theme.of(context).textTheme.bodyMedium,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),

          // SOPs list
          Expanded(
            child: sops.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.folder_open,
                            size: 32,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withOpacity(0.3),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'No SOPs in this category',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withOpacity(0.6),
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const ClampingScrollPhysics(),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    itemCount: sops.length,
                    itemBuilder: (context, index) =>
                        _buildSOPListItemCompact(context, sops[index]),
                  ),
          ),

          // Add SOP button
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  context.go('/editor/new?categoryId=${category.id}');
                },
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add SOP'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: categoryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSOPListItemCompact(BuildContext context, SOP sop) {
    return Card(
      margin: const EdgeInsets.only(bottom: 4),
      elevation: 0,
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
        title: Text(
          sop.title,
          style: const TextStyle(fontSize: 13),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: const Icon(Icons.chevron_right, size: 16),
        onTap: () {
          context.go('/editor/${sop.id}');
        },
      ),
    );
  }

  // Keep this method for the bottom sheet if needed later
  void _showCategoryDetails(BuildContext context, Category category,
      List<SOP> sops, Color categoryColor) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: categoryColor.withOpacity(0.9),
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            category.name,
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                    if (category.description != null &&
                        category.description!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          category.description!,
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Colors.white.withOpacity(0.9),
                                  ),
                        ),
                      ),
                    const SizedBox(height: 8),
                    Text(
                      '${sops.length} SOPs',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                          ),
                    ),
                  ],
                ),
              ),

              // SOPs list
              Expanded(
                child: sops.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.folder_open,
                              size: 64,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withOpacity(0.3),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No SOPs in this category',
                              style: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withOpacity(0.6),
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ElevatedButton.icon(
                              onPressed: () {
                                // Navigate to create new SOP in this category
                                Navigator.of(context).pop();
                                context.go(
                                    '/editor/new?categoryId=${category.id}');
                              },
                              icon: const Icon(Icons.add),
                              label: const Text('Create SOP'),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: sops.length,
                        itemBuilder: (context, index) {
                          final sop = sops[index];
                          return _buildSOPListItem(context, sop);
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSOPListItem(BuildContext context, SOP sop) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(sop.title),
        subtitle: Text(
          sop.description,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          // Navigate to SOP editor
          Navigator.of(context).pop(); // Close bottom sheet
          context.go('/editor/${sop.id}');
        },
      ),
    );
  }

  void _showAddCategoryDialog(BuildContext context) {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController descriptionController = TextEditingController();
    final TextEditingController customSectionController =
        TextEditingController();
    String selectedColor = '#4682B4'; // Default color
    Map<String, bool> categorySettings = {};
    List<String> customSections = [];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(builder: (context, setState) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 600,
              maxHeight: MediaQuery.of(context).size.height * 0.8,
            ),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Create Category',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Category Name',
                        hintText: 'Enter a name for the category',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Description (Optional)',
                        hintText: 'Enter a description for the category',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),
                    const Text('Category Color:',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),

                    // Use GridView instead of Wrap for consistent layout
                    GridView.count(
                      crossAxisCount: 4,
                      shrinkWrap: true,
                      childAspectRatio: 0.9,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        _buildColorChoice(
                            '#4682B4', 'Steel Blue', selectedColor, (color) {
                          setState(() => selectedColor = color);
                        }),
                        _buildColorChoice(
                            '#CD853F', 'Peru (Brown)', selectedColor, (color) {
                          setState(() => selectedColor = color);
                        }),
                        _buildColorChoice('#2E8B57', 'Sea Green', selectedColor,
                            (color) {
                          setState(() => selectedColor = color);
                        }),
                        _buildColorChoice('#8B4513', 'Brown', selectedColor,
                            (color) {
                          setState(() => selectedColor = color);
                        }),
                        _buildColorChoice(
                            '#4169E1', 'Royal Blue', selectedColor, (color) {
                          setState(() => selectedColor = color);
                        }),
                        _buildColorChoice('#800000', 'Maroon', selectedColor,
                            (color) {
                          setState(() => selectedColor = color);
                        }),
                        _buildColorChoice(
                            '#9370DB', 'Medium Purple', selectedColor, (color) {
                          setState(() => selectedColor = color);
                        }),
                        _buildColorChoice(
                            '#3CB371', 'Medium Sea Green', selectedColor,
                            (color) {
                          setState(() => selectedColor = color);
                        }),
                      ],
                    ),

                    const SizedBox(height: 24),
                    // Section toggles
                    const Text('Standard Sections:',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),

                    const CheckboxListTile(
                      title: Text('Steps Section'),
                      subtitle: Text('Steps are always required'),
                      value: true,
                      onChanged: null, // Disabled - always required
                    ),

                    const SizedBox(height: 24),
                    // Custom sections
                    const Text('Custom Sections:',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    const Text(
                      'Add custom sections specific to this category:',
                      style: TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 8),

                    // List of selected custom sections
                    if (customSections.isNotEmpty) ...[
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: customSections.length,
                        itemBuilder: (context, index) {
                          return ListTile(
                            dense: true,
                            contentPadding:
                                const EdgeInsets.symmetric(horizontal: 8.0),
                            title: Text(customSections[index]),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () {
                                setState(() {
                                  customSections.removeAt(index);
                                });
                              },
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 8),
                    ],

                    // Add new custom section
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: customSectionController,
                            decoration: const InputDecoration(
                              labelText: 'New Custom Section',
                              hintText: 'Enter section name',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.add_circle),
                          color: Theme.of(context).primaryColor,
                          onPressed: () {
                            final newSection =
                                customSectionController.text.trim();
                            if (newSection.isNotEmpty &&
                                !customSections.contains(newSection)) {
                              setState(() {
                                customSections.add(newSection);
                                customSectionController.clear();
                              });
                            } else if (customSections.contains(newSection)) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('This section already exists'),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            }
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Section suggestions
                    const Text(
                      'Suggested Sections:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),

                    // Instead of using Wrap, let's use a more stable GridView for suggestions
                    Builder(
                      builder: (context) {
                        final suggestions =
                            commonSectionSuggestions.where((suggestion) {
                          // Case insensitive check for existing sections
                          final sectionNameLower =
                              suggestion.name.toLowerCase();
                          final hasCustomSection = customSections
                              .any((s) => s.toLowerCase() == sectionNameLower);

                          // Only filter out Steps and existing custom sections
                          return !hasCustomSection &&
                              suggestion.name != 'Steps';
                        }).toList();

                        if (suggestions.isEmpty) {
                          return const Padding(
                            padding: EdgeInsets.only(bottom: 8.0),
                            child: Text(
                              'No additional suggestions available',
                              style: TextStyle(
                                fontStyle: FontStyle.italic,
                                color: Colors.grey,
                              ),
                            ),
                          );
                        }

                        return Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: suggestions.map((suggestion) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8.0),
                                child: InkWell(
                                  onTap: () {
                                    final sectionName = suggestion.name;
                                    final sectionNameLower =
                                        sectionName.toLowerCase();
                                    final isDuplicate = customSections.any(
                                        (s) =>
                                            s.toLowerCase() ==
                                            sectionNameLower);

                                    if (!isDuplicate) {
                                      setState(() {
                                        customSections.add(sectionName);
                                      });
                                    }
                                  },
                                  borderRadius: BorderRadius.circular(4.0),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 6.0, horizontal: 8.0),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.add_circle_outline,
                                            size: 16),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                suggestion.name,
                                                style: const TextStyle(
                                                    fontWeight:
                                                        FontWeight.bold),
                                              ),
                                              Text(
                                                suggestion.description,
                                                style: const TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        );
                      },
                    ),

                    // Add back the action buttons
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('CANCEL'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () async {
                            // Validate input
                            if (nameController.text.trim().isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content:
                                        Text('Please enter a category name')),
                              );
                              return;
                            }

                            // Create the category
                            final categoryService =
                                Provider.of<CategoryService>(context,
                                    listen: false);

                            // Make sure 'steps' is always included in settings
                            categorySettings['steps'] = true;

                            // Filter out any empty section names
                            final List<String> validSections = customSections
                                .where((section) => section.trim().isNotEmpty)
                                .toList();

                            // Create the category with all settings in one go
                            await categoryService.createCategory(
                              nameController.text.trim(),
                              description:
                                  descriptionController.text.trim().isNotEmpty
                                      ? descriptionController.text.trim()
                                      : null,
                              color: selectedColor,
                              categorySettings: categorySettings,
                              customSections: validSections,
                            );

                            Navigator.pop(context);

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                    'Category "${nameController.text.trim()}" created'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          },
                          child: const Text('CREATE'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildColorChoice(String colorCode, String name, String selectedColor,
      Function(String) onSelect) {
    final Color color =
        Color(int.parse('FF${colorCode.substring(1)}', radix: 16));
    final bool isSelected = colorCode == selectedColor;

    return InkWell(
      onTap: () => onSelect(colorCode),
      child: Container(
        width: 80,
        height: 90,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.2),
          border: Border.all(
            color: isSelected ? color : Colors.transparent,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white70, width: 2),
              ),
              child: isSelected
                  ? const Center(
                      child: Icon(Icons.check, color: Colors.white, size: 20),
                    )
                  : null,
            ),
            const SizedBox(height: 8),
            Text(
              name,
              style: const TextStyle(fontSize: 12, color: Colors.black87),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  void _showCategorySettingsDialog(BuildContext context, Category category) {
    // Create a mutable copy of the category settings
    Map<String, bool> settings = Map.from(category.categorySettings);
    // Initialize with the current color
    String selectedColor = category.color ?? '#4682B4';
    // Create a mutable copy of the custom sections
    List<String> customSections = List.from(category.customSections);
    // Text controller for adding new custom sections
    final TextEditingController customSectionController =
        TextEditingController();
    // Text controller for editing category name
    final TextEditingController nameController =
        TextEditingController(text: category.name);
    // Text controller for editing category description
    final TextEditingController descriptionController =
        TextEditingController(text: category.description ?? '');

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(builder: (context, setState) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 600,
              maxHeight: MediaQuery.of(context).size.height * 0.8,
            ),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Category Settings',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 24),

                    // Category Name and Description
                    const Text('Basic Information:',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Category Name',
                        hintText: 'Enter category name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Description (Optional)',
                        hintText: 'Enter category description',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 24),

                    // Color selector
                    const Text('Category Color:',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),

                    // Use GridView instead of Wrap for consistent layout
                    GridView.count(
                      crossAxisCount: 4,
                      shrinkWrap: true,
                      childAspectRatio: 0.9,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        _buildColorChoice(
                            '#4682B4', 'Steel Blue', selectedColor, (color) {
                          setState(() => selectedColor = color);
                        }),
                        _buildColorChoice(
                            '#CD853F', 'Peru (Brown)', selectedColor, (color) {
                          setState(() => selectedColor = color);
                        }),
                        _buildColorChoice('#2E8B57', 'Sea Green', selectedColor,
                            (color) {
                          setState(() => selectedColor = color);
                        }),
                        _buildColorChoice('#8B4513', 'Brown', selectedColor,
                            (color) {
                          setState(() => selectedColor = color);
                        }),
                        _buildColorChoice(
                            '#4169E1', 'Royal Blue', selectedColor, (color) {
                          setState(() => selectedColor = color);
                        }),
                        _buildColorChoice('#800000', 'Maroon', selectedColor,
                            (color) {
                          setState(() => selectedColor = color);
                        }),
                        _buildColorChoice(
                            '#9370DB', 'Medium Purple', selectedColor, (color) {
                          setState(() => selectedColor = color);
                        }),
                        _buildColorChoice(
                            '#3CB371', 'Medium Sea Green', selectedColor,
                            (color) {
                          setState(() => selectedColor = color);
                        }),
                      ],
                    ),

                    const SizedBox(height: 24),
                    // Section toggles
                    const Text('Standard Sections:',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    const Text(
                      'Only Steps section is required by default:',
                      style: TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 8),

                    const CheckboxListTile(
                      title: Text('Steps Section'),
                      subtitle: Text('Steps are always required'),
                      value: true,
                      onChanged: null, // Disabled - always required
                    ),

                    const SizedBox(height: 24),
                    // Custom sections
                    const Text('Custom Sections:',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    const Text(
                      'Add custom sections specific to this category:',
                      style: TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 8),

                    // List of existing custom sections with delete buttons
                    if (customSections.isNotEmpty) ...[
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: customSections.length,
                        itemBuilder: (context, index) {
                          return ListTile(
                            dense: true,
                            contentPadding:
                                const EdgeInsets.symmetric(horizontal: 8.0),
                            title: Text(customSections[index]),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () {
                                setState(() {
                                  customSections.removeAt(index);
                                });
                              },
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 8),
                    ],

                    // Add new custom section
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: customSectionController,
                            decoration: const InputDecoration(
                              labelText: 'New Custom Section',
                              hintText: 'Enter section name',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.add_circle),
                          color: Theme.of(context).primaryColor,
                          onPressed: () {
                            final newSection =
                                customSectionController.text.trim();
                            if (newSection.isNotEmpty &&
                                !customSections.contains(newSection)) {
                              setState(() {
                                customSections.add(newSection);
                                customSectionController.clear();
                              });
                            } else if (customSections.contains(newSection)) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('This section already exists'),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            }
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Section suggestions
                    const Text(
                      'Suggested Sections:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),

                    // Instead of using Wrap, let's use a more stable GridView for suggestions
                    Builder(
                      builder: (context) {
                        final suggestions =
                            commonSectionSuggestions.where((suggestion) {
                          // Case insensitive check for existing sections
                          final sectionNameLower =
                              suggestion.name.toLowerCase();
                          final hasCustomSection = customSections
                              .any((s) => s.toLowerCase() == sectionNameLower);

                          // Only filter out Steps and existing custom sections
                          return !hasCustomSection &&
                              suggestion.name != 'Steps';
                        }).toList();

                        if (suggestions.isEmpty) {
                          return const Padding(
                            padding: EdgeInsets.only(bottom: 8.0),
                            child: Text(
                              'No additional suggestions available',
                              style: TextStyle(
                                fontStyle: FontStyle.italic,
                                color: Colors.grey,
                              ),
                            ),
                          );
                        }

                        return Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: suggestions.map((suggestion) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8.0),
                                child: InkWell(
                                  onTap: () {
                                    final sectionName = suggestion.name;
                                    final sectionNameLower =
                                        sectionName.toLowerCase();
                                    final isDuplicate = customSections.any(
                                        (s) =>
                                            s.toLowerCase() ==
                                            sectionNameLower);

                                    if (!isDuplicate) {
                                      setState(() {
                                        customSections.add(sectionName);
                                      });
                                    }
                                  },
                                  borderRadius: BorderRadius.circular(4.0),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 6.0, horizontal: 8.0),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.add_circle_outline,
                                            size: 16),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                suggestion.name,
                                                style: const TextStyle(
                                                    fontWeight:
                                                        FontWeight.bold),
                                              ),
                                              Text(
                                                suggestion.description,
                                                style: const TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 8),
                    const Text(
                      'Note: Custom sections will appear as additional tabs when editing SOPs in this category.',
                      style:
                          TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                    ),

                    // Add back the action buttons
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Delete button
                        ElevatedButton.icon(
                          onPressed: () {
                            // Show confirmation dialog before deleting
                            showDialog(
                              context: context,
                              builder: (context) {
                                // Get SOPs for this category to check if it's in use
                                final sopService = Provider.of<SOPService>(
                                    context,
                                    listen: false);
                                final categorySOPs = sopService.sops
                                    .where(
                                        (sop) => sop.categoryId == category.id)
                                    .toList();

                                final hasSOPs = categorySOPs.isNotEmpty;

                                return AlertDialog(
                                  title: const Text('Delete Category'),
                                  content: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                          'Are you sure you want to delete the category "${category.name}"?'),
                                      const SizedBox(height: 8),
                                      const Text(
                                        'This action cannot be undone.',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold),
                                      ),
                                      if (hasSOPs) ...[
                                        const SizedBox(height: 16),
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: Colors.amber.shade100,
                                            borderRadius:
                                                BorderRadius.circular(4),
                                            border: Border.all(
                                                color: Colors.amber.shade800),
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Icon(Icons.warning_amber,
                                                      color: Colors
                                                          .amber.shade800),
                                                  const SizedBox(width: 8),
                                                  const Text(
                                                    'Warning',
                                                    style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 8),
                                              Text(
                                                  'This category contains ${categorySOPs.length} SOP${categorySOPs.length == 1 ? '' : 's'}. '
                                                  'Deleting this category will remove the category assignment from these SOPs.'),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('CANCEL'),
                                    ),
                                    ElevatedButton(
                                      onPressed: () {
                                        final categoryService =
                                            Provider.of<CategoryService>(
                                                context,
                                                listen: false);

                                        // First dismiss the confirmation dialog
                                        Navigator.pop(context);
                                        // Then dismiss the settings dialog
                                        Navigator.pop(context);

                                        // Delete the category
                                        categoryService
                                            .deleteCategory(category.id);

                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text(
                                                'Category "${category.name}" deleted'),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red,
                                        foregroundColor: Colors.white,
                                      ),
                                      child: const Text('DELETE'),
                                    ),
                                  ],
                                );
                              },
                            );
                          },
                          icon: const Icon(Icons.delete),
                          label: const Text('DELETE CATEGORY'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                          ),
                        ),
                        Row(
                          children: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('CANCEL'),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: () {
                                // Validate input
                                if (nameController.text.trim().isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content:
                                          Text('Category name cannot be empty'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                  return;
                                }

                                // Update the category
                                final categoryService =
                                    Provider.of<CategoryService>(context,
                                        listen: false);

                                // Make sure steps is always included
                                settings['steps'] = true;

                                // Filter out any empty section names
                                final List<String> validSections =
                                    customSections
                                        .where((section) =>
                                            section.trim().isNotEmpty)
                                        .toList();

                                final updatedCategory = category.copyWith(
                                  name: nameController.text.trim(),
                                  description: descriptionController.text
                                          .trim()
                                          .isNotEmpty
                                      ? descriptionController.text.trim()
                                      : null,
                                  categorySettings: settings,
                                  color: selectedColor,
                                  customSections: validSections,
                                );

                                categoryService.updateCategory(updatedCategory);
                                Navigator.pop(context);

                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Category settings updated'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              },
                              child: const Text('SAVE'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}
