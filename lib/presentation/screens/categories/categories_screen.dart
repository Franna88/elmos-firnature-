import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../data/services/sop_service.dart';
import '../../../data/services/category_service.dart';
import '../../../data/models/sop_model.dart';
import '../../../data/models/category_model.dart';
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
                  'Use the search bar to find specific SOPs across all categories.',
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
}
