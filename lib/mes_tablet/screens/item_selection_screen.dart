import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import '../models/furniture_item.dart';
import '../../data/services/mes_service.dart';
import '../../data/models/mes_process_model.dart';
import '../models/user.dart';
import '../../presentation/widgets/cross_platform_image.dart';
import '../../core/theme/app_theme.dart';

class ItemSelectionScreen extends StatefulWidget {
  final User? initialUser;
  final MESProcess? initialProcess;

  const ItemSelectionScreen({Key? key, this.initialUser, this.initialProcess})
      : super(key: key);

  @override
  State<ItemSelectionScreen> createState() => _ItemSelectionScreenState();
}

class _ItemSelectionScreenState extends State<ItemSelectionScreen> {
  String? _selectedCategory;
  bool _isLoading = false;
  User? _user;
  MESProcess? _selectedProcess;

  @override
  void initState() {
    super.initState();
    // If initialUser and initialProcess are provided, use them right away
    _user = widget.initialUser;
    _selectedProcess = widget.initialProcess;
    _loadItems();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // If initialUser/initialProcess weren't provided, try to get them from route arguments
    if (_user == null || _selectedProcess == null) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map<String, dynamic>) {
        _user ??= args['user'] as User?;
        _selectedProcess ??= args['process'] as MESProcess?;
      } else if (args is User) {
        // Fallback for direct User argument (backward compatibility)
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
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  List<FurnitureItem> get items {
    final mesService = Provider.of<MESService>(context, listen: false);

    // Filter items by the selected process
    final filteredMESItems = mesService.items.where((mesItem) {
      return _selectedProcess != null &&
          mesItem.processId == _selectedProcess!.id;
    }).toList();

    return filteredMESItems
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
    // Make sure we have both user and process
    if (_user == null || _selectedProcess == null) {
      // Navigate back to process selection if we're missing required data
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_user == null) {
          Navigator.pushReplacementNamed(context, '/login');
        } else {
          Navigator.pushReplacementNamed(context, '/process_selection',
              arguments: _user);
        }
      });

      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Select Item to Build'),
            Text(
              'Process: ${_selectedProcess!.name}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.normal,
                color: Colors.white.withOpacity(0.9),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.primaryBlue,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back to Process Selection',
          onPressed: () {
            Navigator.pushReplacementNamed(context, '/process_selection',
                arguments: _user);
          },
        ),
        actions: [
          // Refresh button
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadItems,
          ),
          // Exit button
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () {
              Navigator.pushReplacementNamed(context, '/login');
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
            Icon(Icons.inventory_2, size: 80, color: Colors.grey.shade400),
            const SizedBox(height: 24),
            Text(
              'No Items Available',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            Text(
              'Process: ${_selectedProcess?.name ?? "Unknown"}',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.primaryBlue,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              margin: const EdgeInsets.symmetric(horizontal: 32),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  Text(
                    'This process has no items assigned to it.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Colors.grey.shade700,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Please contact your administrator to assign items to this process or select a different process.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey.shade600,
                        ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pushReplacementNamed(
                        context, '/process_selection',
                        arguments: _user);
                  },
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Change Process'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh'),
                  onPressed: _loadItems,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey.shade600,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${filteredItems.length} items available in this process',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (_selectedCategory != null)
                TextButton(
                  onPressed: () {
                    setState(() {
                      _selectedCategory = null;
                    });
                  },
                  child: const Text('Clear Filter'),
                ),
            ],
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
