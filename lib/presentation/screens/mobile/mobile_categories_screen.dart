import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
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
                  const Text(
                    "Elmo's Furniture",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
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
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : categories.isEmpty
              ? const Center(
                  child: Text('No categories found'),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16.0),
                  itemCount: categories.length,
                  itemBuilder: (context, index) {
                    final category = categories[index];
                    final sopsInCategory = sopService.sops
                        .where((sop) => sop.categoryName == category.name)
                        .toList();

                    return _buildCategoryCard(
                        context, category, sopsInCategory);
                  },
                ),
    );
  }

  Widget _buildCategoryCard(
      BuildContext context, Category category, List<SOP> sops) {
    final Color categoryColor = _getCategoryColor(category.name);

    return Card(
      margin: const EdgeInsets.only(bottom: 16.0),
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
              ],
            ),
          ),

          // SOPs list
          if (sops.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'No SOPs in this category',
                style: TextStyle(color: Colors.grey[600]),
              ),
            )
          else
            ListView.separated(
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              itemCount: sops.length,
              separatorBuilder: (context, index) => Divider(
                height: 1,
                color: Colors.grey[200],
              ),
              itemBuilder: (context, index) {
                final sop = sops[index];
                return ListTile(
                  title: Text(
                    sop.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  subtitle: Text(
                    '${sop.steps.length} steps • Rev ${sop.revisionNumber}',
                    style: TextStyle(
                      fontSize: 12.0,
                      color: Colors.grey[600],
                    ),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16.0),
                  onTap: () {
                    context.go('/mobile/sop/${sop.id}');
                  },
                );
              },
            ),
        ],
      ),
    );
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
        return AppColors.primaryRed;
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
