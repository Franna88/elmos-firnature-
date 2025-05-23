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
        categoryColor =
            Color(int.parse('FF${category.color!.substring(1)}', radix: 16));
      } catch (e) {
        // Keep default color on error
      }
    }

    // Get only the active sections for this category
    List<String> activeSections = [];

    // Add standard sections if they're enabled in category settings
    if (category.categorySettings['tools'] == true) {
      activeSections.add('Tools');
    }
    if (category.categorySettings['safety'] == true) {
      activeSections.add('Safety');
    }
    if (category.categorySettings['cautions'] == true) {
      activeSections.add('Cautions');
    }

    // Add custom sections
    activeSections.addAll(category.customSections);

    // Steps are always included
    activeSections.add('Steps');

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Category header with color and name - reduced padding
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: categoryColor,
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
                    category.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  '${sops.length} SOPs',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert,
                      color: Colors.white, size: 20),
                  padding: EdgeInsets.zero,
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
                        builder: (context) => AlertDialog(
                          title: const Text('Delete Category?'),
                          content: Text(
                            hasSOPs
                                ? 'This category contains ${categorySOPs.length} SOPs. If you delete it, these SOPs will be moved to "Uncategorized".'
                                : 'Are you sure you want to delete this category?',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.pop(context);
                                final categoryService =
                                    Provider.of<CategoryService>(context,
                                        listen: false);
                                categoryService.deleteCategory(category.id);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content: Text(
                                          'Category "${category.name}" deleted')),
                                );
                              },
                              style: TextButton.styleFrom(
                                  foregroundColor: Colors.red),
                              child: const Text('Delete'),
                            ),
                          ],
                        ),
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

          // Category description if available - more compact
          if (category.description != null && category.description!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(
                category.description!,
                style: Theme.of(context).textTheme.bodySmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),

          // Divider - reduced vertical padding
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Divider(height: 1),
          ),

          // Sections list - more compact
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Sections:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: activeSections.map((section) {
                          IconData iconData;

                          // Assign appropriate icon based on section type
                          switch (section.toLowerCase()) {
                            case 'tools':
                              iconData = Icons.build;
                              break;
                            case 'safety':
                              iconData = Icons.security;
                              break;
                            case 'cautions':
                              iconData = Icons.warning;
                              break;
                            case 'steps':
                              iconData = Icons.format_list_numbered;
                              break;
                            default:
                              iconData = Icons.article;
                          }

                          // Use a consistent color for all chips
                          return Chip(
                            avatar:
                                Icon(iconData, size: 14, color: categoryColor),
                            label: Text(section),
                            backgroundColor: categoryColor.withOpacity(0.1),
                            visualDensity: VisualDensity.compact,
                            labelStyle: TextStyle(
                              fontSize: 11.0,
                              color: categoryColor,
                              fontWeight: FontWeight.w500,
                            ),
                            padding: EdgeInsets.zero,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // SOPs count and view button - more compact
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total SOPs: ${sops.length}',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[700],
                    fontSize: 12,
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    // Navigate to SOPs screen with category filter
                    context.go('/sops', extra: {'categoryId': category.id});
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: categoryColor,
                    foregroundColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    textStyle: const TextStyle(fontSize: 12),
                    minimumSize: const Size(80, 28),
                  ),
                  child: const Text('View SOPs'),
                ),
              ],
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header row that stays fixed
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 8, 0),
                  child: Row(
                    children: [
                      Text(
                        'Create Category',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                // Content that scrolls
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Category Name and Description
                        const Text('Basic Information:',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 7,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Category Name:',
                                      style: TextStyle(fontSize: 13)),
                                  const SizedBox(height: 4),
                                  TextField(
                                    controller: nameController,
                                    decoration: const InputDecoration(
                                      hintText: 'Enter category name',
                                      border: OutlineInputBorder(),
                                      contentPadding: EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 12),
                                      isDense: true,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  const Text('Description:',
                                      style: TextStyle(fontSize: 13)),
                                  const SizedBox(height: 4),
                                  TextField(
                                    controller: descriptionController,
                                    decoration: const InputDecoration(
                                      hintText:
                                          'Enter category description (optional)',
                                      border: OutlineInputBorder(),
                                      contentPadding: EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 12),
                                      isDense: true,
                                    ),
                                    maxLines: 2,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 3,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Category Color:',
                                      style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500)),
                                  const SizedBox(height: 8),
                                  InkWell(
                                    onTap: () => _showColorPickerPopup(
                                        context, selectedColor, (color) {
                                      setState(() => selectedColor = color);
                                    }),
                                    child: Container(
                                      height: 50,
                                      decoration: BoxDecoration(
                                        color: Color(int.parse(
                                            'FF${selectedColor.substring(1)}',
                                            radix: 16)),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                            color: Colors.grey.shade300,
                                            width: 1),
                                      ),
                                      child: const Center(
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.color_lens,
                                                color: Colors.white),
                                            SizedBox(width: 8),
                                            Text(
                                              'Select Color',
                                              style: TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),
                        const CheckboxListTile(
                          dense: true,
                          title: Text('Steps Section'),
                          subtitle: Text('Steps are always required'),
                          value: true,
                          onChanged: null, // Disabled - always required
                        ),

                        const SizedBox(height: 12),
                        // Custom sections
                        const Text('Custom Sections:',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        const Text(
                          'Add custom sections specific to this category:',
                          style: TextStyle(fontSize: 14),
                        ),
                        const SizedBox(height: 12),

                        // Suggested sections as chips
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: commonSectionSuggestions
                              .where((suggestion) {
                                // Case insensitive check for existing sections
                                final sectionNameLower =
                                    suggestion.name.toLowerCase();
                                final hasCustomSection = customSections.any(
                                    (s) => s.toLowerCase() == sectionNameLower);

                                // Only filter out Steps and existing custom sections
                                return !hasCustomSection &&
                                    suggestion.name != 'Steps';
                              })
                              .map((suggestion) => ActionChip(
                                    label: Text(suggestion.name),
                                    tooltip: suggestion.description,
                                    avatar: const Icon(Icons.add, size: 16),
                                    backgroundColor: Theme.of(context)
                                        .colorScheme
                                        .surfaceVariant,
                                    side: BorderSide(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary
                                            .withOpacity(0.3)),
                                    onPressed: () {
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
                                  ))
                              .toList(),
                        ),

                        const SizedBox(height: 12),
                        // Add new custom section
                        const Text('Add New Section:',
                            style: TextStyle(fontSize: 13)),
                        const SizedBox(height: 4),
                        TextField(
                          controller: customSectionController,
                          decoration: InputDecoration(
                            hintText: 'Enter new section name',
                            border: const OutlineInputBorder(),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 12),
                            isDense: true,
                            suffixIcon: IconButton(
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
                                } else if (customSections
                                    .contains(newSection)) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content:
                                          Text('This section already exists'),
                                      duration: Duration(seconds: 2),
                                    ),
                                  );
                                }
                              },
                            ),
                          ),
                          onSubmitted: (newSection) {
                            if (newSection.isNotEmpty &&
                                !customSections.contains(newSection)) {
                              setState(() {
                                customSections.add(newSection);
                                customSectionController.clear();
                              });
                            }
                          },
                        ),

                        // List of selected custom sections in the Add Category dialog
                        if (customSections.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Container(
                            height: 150,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: ListView.builder(
                              shrinkWrap: true,
                              itemCount: customSections.length,
                              itemBuilder: (context, index) {
                                return ListTile(
                                  dense: true,
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 8.0),
                                  title: Text(customSections[index]),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.delete,
                                        color: Colors.red, size: 20),
                                    onPressed: () {
                                      setState(() {
                                        customSections.removeAt(index);
                                      });
                                    },
                                  ),
                                );
                              },
                            ),
                          ),
                        ],

                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
                // Footer with buttons that stays fixed
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Row(
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
                          final categoryService = Provider.of<CategoryService>(
                              context,
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
                ),
              ],
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header row that stays fixed
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 8, 0),
                  child: Row(
                    children: [
                      Text(
                        'Category Settings',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                // Content that scrolls
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Category Name and Description
                        const Text('Basic Information:',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 7,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Category Name:',
                                      style: TextStyle(fontSize: 13)),
                                  const SizedBox(height: 4),
                                  TextField(
                                    controller: nameController,
                                    decoration: const InputDecoration(
                                      hintText: 'Enter category name',
                                      border: OutlineInputBorder(),
                                      contentPadding: EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 12),
                                      isDense: true,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  const Text('Description:',
                                      style: TextStyle(fontSize: 13)),
                                  const SizedBox(height: 4),
                                  TextField(
                                    controller: descriptionController,
                                    decoration: const InputDecoration(
                                      hintText:
                                          'Enter category description (optional)',
                                      border: OutlineInputBorder(),
                                      contentPadding: EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 12),
                                      isDense: true,
                                    ),
                                    maxLines: 2,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 3,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Category Color:',
                                      style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500)),
                                  const SizedBox(height: 8),
                                  InkWell(
                                    onTap: () => _showColorPickerPopup(
                                        context, selectedColor, (color) {
                                      setState(() => selectedColor = color);
                                    }),
                                    child: Container(
                                      height: 50,
                                      decoration: BoxDecoration(
                                        color: Color(int.parse(
                                            'FF${selectedColor.substring(1)}',
                                            radix: 16)),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                            color: Colors.grey.shade300,
                                            width: 1),
                                      ),
                                      child: const Center(
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.color_lens,
                                                color: Colors.white),
                                            SizedBox(width: 8),
                                            Text(
                                              'Select Color',
                                              style: TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),
                        const CheckboxListTile(
                          dense: true,
                          title: Text('Steps Section'),
                          subtitle: Text('Steps are always required'),
                          value: true,
                          onChanged: null, // Disabled - always required
                        ),

                        const SizedBox(height: 12),
                        // Custom sections
                        const Text('Custom Sections:',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        const Text(
                          'Add custom sections specific to this category:',
                          style: TextStyle(fontSize: 14),
                        ),
                        const SizedBox(height: 12),

                        // Suggested sections as chips
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: commonSectionSuggestions
                              .where((suggestion) {
                                // Case insensitive check for existing sections
                                final sectionNameLower =
                                    suggestion.name.toLowerCase();
                                final hasCustomSection = customSections.any(
                                    (s) => s.toLowerCase() == sectionNameLower);

                                // Only filter out Steps and existing custom sections
                                return !hasCustomSection &&
                                    suggestion.name != 'Steps';
                              })
                              .map((suggestion) => ActionChip(
                                    label: Text(suggestion.name),
                                    tooltip: suggestion.description,
                                    avatar: const Icon(Icons.add, size: 16),
                                    backgroundColor: Theme.of(context)
                                        .colorScheme
                                        .surfaceVariant,
                                    side: BorderSide(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary
                                            .withOpacity(0.3)),
                                    onPressed: () {
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
                                  ))
                              .toList(),
                        ),

                        const SizedBox(height: 12),
                        // Add new custom section
                        const Text('Add New Section:',
                            style: TextStyle(fontSize: 13)),
                        const SizedBox(height: 4),
                        TextField(
                          controller: customSectionController,
                          decoration: InputDecoration(
                            hintText: 'Enter new section name',
                            border: const OutlineInputBorder(),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 12),
                            isDense: true,
                            suffixIcon: IconButton(
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
                                } else if (customSections
                                    .contains(newSection)) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content:
                                          Text('This section already exists'),
                                      duration: Duration(seconds: 2),
                                    ),
                                  );
                                }
                              },
                            ),
                          ),
                          onSubmitted: (newSection) {
                            if (newSection.isNotEmpty &&
                                !customSections.contains(newSection)) {
                              setState(() {
                                customSections.add(newSection);
                                customSectionController.clear();
                              });
                            }
                          },
                        ),

                        // List of selected custom sections
                        if (customSections.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Container(
                            height: 150,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: ListView.builder(
                              shrinkWrap: true,
                              itemCount: customSections.length,
                              itemBuilder: (context, index) {
                                return ListTile(
                                  dense: true,
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 8.0),
                                  title: Text(customSections[index]),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.delete,
                                        color: Colors.red, size: 20),
                                    onPressed: () {
                                      setState(() {
                                        customSections.removeAt(index);
                                      });
                                    },
                                  ),
                                );
                              },
                            ),
                          ),
                        ],

                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
                // Footer with buttons that stays fixed
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton.icon(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        label: const Text('Delete',
                            style: TextStyle(color: Colors.red)),
                        onPressed: () {
                          // Show delete confirmation dialog
                          _showDeleteCategoryDialog(context, category);
                        },
                      ),
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

                          // Create the updated category
                          final categoryService = Provider.of<CategoryService>(
                              context,
                              listen: false);

                          // Update the category
                          final updatedCategory = Category(
                            id: category.id,
                            name: nameController.text.trim(),
                            description: descriptionController.text.trim(),
                            color: selectedColor,
                            customSections: customSections,
                            categorySettings: settings,
                            createdAt: category.createdAt,
                          );

                          // Update the category in the service
                          await categoryService.updateCategory(updatedCategory);

                          if (context.mounted) {
                            // Close the dialog
                            Navigator.pop(context);

                            // Show success message
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                    'Category "${updatedCategory.name}" updated'),
                                backgroundColor:
                                    Theme.of(context).colorScheme.secondary,
                              ),
                            );
                          }
                        },
                        child: const Text('SAVE CHANGES'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  void _showColorPickerPopup(BuildContext context, String currentColor,
      Function(String) onColorSelected) {
    final List<Map<String, dynamic>> colorOptions = [
      {'code': '#4682B4', 'name': 'Steel Blue'},
      {'code': '#CD853F', 'name': 'Peru (Brown)'},
      {'code': '#2E8B57', 'name': 'Sea Green'},
      {'code': '#8B4513', 'name': 'Brown'},
      {'code': '#4169E1', 'name': 'Royal Blue'},
      {'code': '#800000', 'name': 'Maroon'},
      {'code': '#9370DB', 'name': 'Medium Purple'},
      {'code': '#3CB371', 'name': 'Medium Sea Green'},
      {'code': '#FF6347', 'name': 'Tomato'},
      {'code': '#20B2AA', 'name': 'Light Sea Green'},
      {'code': '#8A2BE2', 'name': 'Blue Violet'},
      {'code': '#228B22', 'name': 'Forest Green'},
      {'code': '#B22222', 'name': 'Firebrick'},
      {'code': '#4B0082', 'name': 'Indigo'},
      {'code': '#DAA520', 'name': 'Goldenrod'},
      {'code': '#008080', 'name': 'Teal'},
    ];

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select a Color'),
          content: SizedBox(
            width: 300,
            height: 300,
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1,
              ),
              itemCount: colorOptions.length,
              itemBuilder: (context, index) {
                final colorCode = colorOptions[index]['code'] as String;
                final colorName = colorOptions[index]['name'] as String;
                final color =
                    Color(int.parse('FF${colorCode.substring(1)}', radix: 16));
                final isSelected = colorCode == currentColor;

                return InkWell(
                  onTap: () {
                    onColorSelected(colorCode);
                    Navigator.pop(context);
                  },
                  child: Tooltip(
                    message: colorName,
                    child: Container(
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? Colors.white : Colors.transparent,
                          width: 3,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: isSelected
                          ? const Center(
                              child: Icon(Icons.check,
                                  color: Colors.white, size: 24),
                            )
                          : null,
                    ),
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCEL'),
            ),
          ],
        );
      },
    );
  }

  void _showDeleteCategoryDialog(BuildContext context, Category category) {
    // Get SOPs for this category to check if it's in use
    final sopService = Provider.of<SOPService>(context, listen: false);
    final categorySOPs =
        sopService.sops.where((sop) => sop.categoryId == category.id).toList();

    final hasSOPs = categorySOPs.isNotEmpty;

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
                    border: Border.all(color: Colors.amber.shade800),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.warning_amber,
                              color: Colors.amber.shade800),
                          const SizedBox(width: 8),
                          const Text(
                            'Warning',
                            style: TextStyle(fontWeight: FontWeight.bold),
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
                    Provider.of<CategoryService>(context, listen: false);

                // First dismiss the confirmation dialog
                Navigator.pop(context);
                // Then dismiss the category settings dialog
                Navigator.pop(context);

                // Delete the category
                categoryService.deleteCategory(category.id);

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Category "${category.name}" deleted'),
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
}
