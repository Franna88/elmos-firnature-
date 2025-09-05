import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../../data/services/sop_service.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/services/category_service.dart';
import '../../../data/models/category_model.dart';
import '../../../data/models/sop_model.dart';
import '../../../core/theme/app_theme.dart';

class MobileCategoriesScreen extends StatefulWidget {
  const MobileCategoriesScreen({super.key});

  @override
  State<MobileCategoriesScreen> createState() => _MobileCategoriesScreenState();
}

class _MobileCategoriesScreenState extends State<MobileCategoriesScreen> {
  bool _isLoading = true;
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    final sopService = Provider.of<SOPService>(context, listen: false);
    final categoryService =
        Provider.of<CategoryService>(context, listen: false);

    await Future.wait([
      sopService.refreshSOPs(),
      categoryService.refreshCategories(),
    ]);

    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final sopService = Provider.of<SOPService>(context);
    final categoryService = Provider.of<CategoryService>(context);
    final authService = Provider.of<AuthService>(context);

    // Get all categories and sort them alphabetically
    final categories = categoryService.categories.toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: const Text("Categories",
            style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        automaticallyImplyLeading: false,
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).pop(),
              )
            : IconButton(
                icon: const Icon(Icons.menu),
                onPressed: () {
                  _scaffoldKey.currentState!.openDrawer();
                },
              ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Image.asset(
                    'assets/images/elmos_logo.png',
                    height: 40,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Welcome, ${authService.userName ?? 'User'}",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    authService.userEmail ?? '',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.article),
              title: const Text('SOPs'),
              onTap: () {
                Navigator.pop(context);
                context.go('/mobile/sops');
              },
            ),
            ListTile(
              leading: const Icon(Icons.category),
              title: const Text('Categories'),
              selected: true,
              onTap: () {
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.factory_outlined),
              title: const Text('Factory MES'),
              onTap: () {
                Navigator.pop(context);
                context.go('/mes');
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Logout'),
              onTap: () async {
                await authService.logout();
                if (context.mounted) {
                  context.go('/login');
                }
              },
            ),
            // Version display
            FutureBuilder<PackageInfo>(
              future: PackageInfo.fromPlatform(),
              builder: (context, snapshot) {
                String version = "Version: ";
                if (snapshot.hasData) {
                  version += snapshot.data!.version;
                } else {
                  version += "Loading...";
                }

                return Padding(
                  padding: const EdgeInsets.symmetric(
                      vertical: 16.0, horizontal: 16.0),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline,
                          size: 16, color: Colors.grey),
                      const SizedBox(width: 8),
                      Text(
                        version,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : categories.isEmpty
              ? const Center(
                  child: Text('No categories found'),
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    // Determine if we're on a tablet-sized screen
                    final isTablet = constraints.maxWidth > 600;

                    // Calculate number of columns based on width
                    final int crossAxisCount =
                        isTablet ? (constraints.maxWidth > 900 ? 3 : 2) : 1;

                    // Use grid for tablet, list for phone
                    return crossAxisCount > 1
                        ? GridView.builder(
                            padding: const EdgeInsets.all(16.0),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: crossAxisCount,
                              childAspectRatio: 1.5,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                            ),
                            itemCount: categories.length,
                            itemBuilder: (context, index) {
                              final category = categories[index];
                              final sopsInCategory = sopService.sops
                                  .where((sop) =>
                                      sop.categoryName == category.name)
                                  .toList();

                              return _buildCategoryCard(
                                  context, category, sopsInCategory);
                            },
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16.0),
                            itemCount: categories.length,
                            itemBuilder: (context, index) {
                              final category = categories[index];
                              final sopsInCategory = sopService.sops
                                  .where((sop) =>
                                      sop.categoryName == category.name)
                                  .toList();

                              return _buildCategoryCard(
                                  context, category, sopsInCategory);
                            },
                          );
                  },
                ),
    );
  }

  Widget _buildCategoryCard(
      BuildContext context, Category category, List<SOP> sops) {
    final Color categoryColor = _getCategoryColor(category.name);

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
      margin: const EdgeInsets.only(bottom: 12.0),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Category header
          Container(
            width: double.infinity,
            padding:
                const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
            decoration: BoxDecoration(
              color: categoryColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12.0),
                topRight: Radius.circular(12.0),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _getCategoryIcon(category.name),
                  color: Colors.white,
                ),
                const SizedBox(width: 12.0),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18.0,
                        ),
                      ),
                      Text(
                        '${sops.length} SOPs',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14.0,
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    // Navigate to filtered SOPs view
                    _navigateToFilteredSOPs(context, category.name);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: categoryColor,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12.0, vertical: 8.0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20.0),
                    ),
                  ),
                  child: const Text(
                    'View All',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),

          // Sections list - with compact height and consistent colors
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 12.0, 16.0, 12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sections:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14.0,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 8.0),
                Wrap(
                  spacing: 8.0,
                  runSpacing: 8.0,
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
                      avatar: Icon(iconData, size: 16, color: categoryColor),
                      label: Text(section),
                      backgroundColor: categoryColor.withOpacity(0.1),
                      visualDensity: VisualDensity.compact,
                      labelStyle: TextStyle(
                        fontSize: 12.0,
                        color: categoryColor,
                        fontWeight: FontWeight.w500,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),

          // Only show "No SOPs" message if empty
          if (sops.isEmpty)
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
              child: Text(
                'No SOPs in this category',
                style: TextStyle(
                    color: Colors.grey[600], fontStyle: FontStyle.italic),
              ),
            ),
        ],
      ),
    );
  }

  // Helper widget to build a stat card - keeping the method signature but removing implementation
  Widget _buildStatCard({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
    required int flex,
  }) {
    // This method is kept for compatibility but not used anymore
    return const SizedBox.shrink();
  }

  // Method to navigate to the filtered SOPs view
  void _navigateToFilteredSOPs(BuildContext context, String categoryName) {
    // We'll use the mobile SOPs screen with the category pre-selected
    context.go('/mobile/sops', extra: {'category': categoryName});
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
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
        return AppColors.primaryBlue;
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'assembly':
        return Icons.build;
      case 'finishing':
        return Icons.format_paint;
      case 'machinery':
        return Icons.precision_manufacturing;
      case 'quality':
        return Icons.verified;
      case 'upholstery':
        return Icons.chair;
      default:
        return Icons.category;
    }
  }
}
