import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import '../models/furniture_item.dart';
import '../../data/services/mes_service.dart';
import '../models/user.dart';
import 'package:go_router/go_router.dart';
import '../../presentation/widgets/cross_platform_image.dart';
import '../../core/theme/app_theme.dart';

class ItemSelectionScreen extends StatefulWidget {
  final User? initialUser;

  const ItemSelectionScreen({Key? key, this.initialUser}) : super(key: key);

  @override
  State<ItemSelectionScreen> createState() => _ItemSelectionScreenState();
}

class _ItemSelectionScreenState extends State<ItemSelectionScreen> {
  String? _selectedCategory;
  bool _isLoading = false;
  User? _user;

  @override
  void initState() {
    super.initState();
    // If initialUser is provided, use it right away
    _user = widget.initialUser;
    _loadItems();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // If initialUser wasn't provided, try to get it from route arguments
    if (_user == null) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is User) {
        _user = args;
      }
    }
  }

  Future<void> _loadItems() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final mesService = Provider.of<MESService>(context, listen: false);
      await mesService.fetchItems(onlyActive: true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading items: $e')),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  List<FurnitureItem> get items {
    final mesService = Provider.of<MESService>(context, listen: false);
    return mesService.items
        .map((mesItem) => FurnitureItem.fromMESItem(mesItem))
        .toList();
  }

  List<FurnitureItem> get filteredItems {
    if (_selectedCategory == null) {
      return items;
    }
    return items.where((item) => item.category == _selectedCategory).toList();
  }

  // Get unique categories/processes from items
  List<String> get categories {
    return items.map((item) => item.category).toSet().toList();
  }

  // Get process info for display
  String getProcessDisplayName(String category) {
    final mesService = Provider.of<MESService>(context, listen: false);
    final mesItems =
        mesService.items.where((item) => item.category == category);
    if (mesItems.isNotEmpty) {
      final firstItem = mesItems.first;
      final process = mesService.getProcessById(firstItem.processId);
      if (process != null) {
        return process.stationName != null
            ? '${process.name} (${process.stationName})'
            : process.name;
      }
    }
    return category; // Fallback to category name
  }

  @override
  Widget build(BuildContext context) {
    // Make sure we have a user, either from initialUser or from route arguments
    if (_user == null) {
      // Navigate back to login if we somehow don't have a user
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacementNamed(context, '/login');
      });

      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Item to Build'),
        backgroundColor: AppColors.primaryBlue,
        foregroundColor: Colors.white,
        actions: [
          // Refresh button
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadItems,
          ),
          // Exit button
          IconButton(
            icon: const Icon(Icons.exit_to_app),
            tooltip: 'Exit to main menu',
            onPressed: () {
              Navigator.of(context).pop();
              if (context.mounted) {
                GoRouter.of(context).go('/mobile/selection');
              }
            },
          ),
          // Screen dimensions display in debug mode
          if (kDebugMode)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: Center(
                child: Text(
                  '${MediaQuery.of(context).size.width.toInt()}×${MediaQuery.of(context).size.height.toInt()}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildContent(_user!),
    );
  }

  Widget _buildContent(User user) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.warning, size: 64, color: Colors.orange),
            const SizedBox(height: 16),
            const Text(
              'No items available',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Please contact your administrator to add items.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
              onPressed: _loadItems,
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome message with operator name
          Text(
            'Welcome, ${user.name}!',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Please select an item to build:',
            style: TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 16),

          // Category filter
          SizedBox(
            height: 50,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: FilterChip(
                    label: const Text('All'),
                    selected: _selectedCategory == null,
                    selectedColor: AppColors.primaryBlue.withOpacity(0.2),
                    checkmarkColor: AppColors.primaryBlue,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _selectedCategory = null;
                        });
                      }
                    },
                  ),
                ),
                ...categories.map((category) => Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: FilterChip(
                        label: Text(getProcessDisplayName(category)),
                        selected: _selectedCategory == category,
                        selectedColor: AppColors.primaryBlue.withOpacity(0.2),
                        checkmarkColor: AppColors.primaryBlue,
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _selectedCategory = category;
                            } else {
                              _selectedCategory = null;
                            }
                          });
                        },
                      ),
                    )),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Item grid
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 1.2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: filteredItems.length,
              itemBuilder: (context, index) {
                final item = filteredItems[index];
                return _buildItemCard(context, item, user);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemCard(BuildContext context, FurnitureItem item, User user) {
    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      elevation: 4,
      child: InkWell(
        onTap: () {
          // Create a new production record in Firebase and navigate to timer screen
          _startProduction(item, user);
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image or placeholder
            Expanded(
              child: item.imageUrl != null && item.imageUrl!.isNotEmpty
                  ? CrossPlatformImage(
                      imageUrl: item.imageUrl!,
                      width: 300,
                      height: 200,
                      fit: BoxFit.cover,
                      errorWidget: _buildImagePlaceholder(item),
                    )
                  : _buildImagePlaceholder(item),
            ),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Est. time: ${item.estimatedTimeInMinutes} min',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePlaceholder(FurnitureItem item) {
    return Container(
      color: AppColors.backgroundWhite,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _getIconForCategory(item.category),
              size: 80,
              color: AppColors.textMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'No Image',
              style: TextStyle(
                color: AppColors.textLight,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getIconForCategory(String category) {
    switch (category.toLowerCase()) {
      case 'chairs':
        return Icons.chair;
      case 'tables':
        return Icons.table_restaurant;
      case 'ottomans':
        return Icons.weekend;
      case 'benches':
        return Icons.deck;
      default:
        return Icons.chair_alt;
    }
  }

  // Start production and navigate to timer screen
  Future<void> _startProduction(FurnitureItem item, User user) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final mesService = Provider.of<MESService>(context, listen: false);

      // Create a new production record
      final record = await mesService.startProductionRecord(
        item.id,
        user.id,
        user.name,
      );

      // Navigate to timer screen with item and record ID
      Navigator.pushNamed(
        context,
        '/timer',
        arguments: {
          'item': item,
          'user': user,
          'recordId': record.id,
        },
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error starting production: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
}
