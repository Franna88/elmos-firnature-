import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../data/services/mes_service.dart';
import '../../data/models/mes_item_model.dart';
import '../../data/models/mes_interruption_model.dart';

class MESManagementScreen extends StatefulWidget {
  const MESManagementScreen({Key? key}) : super(key: key);

  @override
  State<MESManagementScreen> createState() => _MESManagementScreenState();
}

class _MESManagementScreenState extends State<MESManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // Load initial data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Load MES data
  Future<void> _loadData() async {
    final mesService = Provider.of<MESService>(context, listen: false);

    // Load items and interruption types
    await mesService.fetchItems();
    await mesService.fetchInterruptionTypes();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manufacturing Execution System'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/dashboard'),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Production Items'),
            Tab(text: 'Interruption Types'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _loadData,
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _ItemsTab(),
          _InterruptionTypesTab(),
        ],
      ),
    );
  }
}

// Tab for managing production items
class _ItemsTab extends StatelessWidget {
  const _ItemsTab({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<MESService>(
      builder: (context, mesService, child) {
        if (mesService.isLoadingItems) {
          return const Center(child: CircularProgressIndicator());
        }

        final items = mesService.items;

        if (items.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('No production items found.'),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('Add Item'),
                  onPressed: () => _showAddItemDialog(context),
                ),
              ],
            ),
          );
        }

        return Stack(
          children: [
            ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                return _buildItemCard(context, item);
              },
            ),
            Positioned(
              right: 16,
              bottom: 16,
              child: FloatingActionButton(
                onPressed: () => _showAddItemDialog(context),
                tooltip: 'Add Item',
                child: const Icon(Icons.add),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildItemCard(BuildContext context, MESItem item) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    item.name,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit),
                      tooltip: 'Edit',
                      onPressed: () => _showEditItemDialog(context, item),
                    ),
                    IconButton(
                      icon: Icon(item.isActive
                          ? Icons.visibility
                          : Icons.visibility_off),
                      tooltip: item.isActive ? 'Deactivate' : 'Activate',
                      onPressed: () => _toggleItemStatus(context, item),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete),
                      tooltip: 'Delete',
                      color: Colors.red,
                      onPressed: () => _confirmDeleteItem(context, item),
                    ),
                  ],
                ),
              ],
            ),
            const Divider(),
            Row(
              children: [
                _buildInfoChip(
                    context, Icons.category, 'Category', item.category),
                const SizedBox(width: 16),
                _buildInfoChip(
                  context,
                  Icons.timer,
                  'Est. Time',
                  '${item.estimatedTimeInMinutes} min',
                ),
              ],
            ),
            if (!item.isActive)
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info, color: Colors.red),
                    SizedBox(width: 8),
                    Text(
                      'This item is currently inactive and not visible on tablets',
                      style: TextStyle(color: Colors.red),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(
      BuildContext context, IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(value),
            ],
          ),
        ],
      ),
    );
  }

  // Dialog to add a new item
  void _showAddItemDialog(BuildContext context) {
    final nameController = TextEditingController();
    final categoryController = TextEditingController();
    final timeController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Production Item'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Item Name',
                  hintText: 'e.g., Dining Chair',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: categoryController,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  hintText: 'e.g., Chairs',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: timeController,
                decoration: const InputDecoration(
                  labelText: 'Estimated Time (minutes)',
                  hintText: 'e.g., 45',
                ),
                keyboardType: TextInputType.number,
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
            onPressed: () async {
              if (nameController.text.isEmpty ||
                  categoryController.text.isEmpty ||
                  timeController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please fill all fields')),
                );
                return;
              }

              // Parse time value
              final time = int.tryParse(timeController.text);
              if (time == null || time <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Please enter a valid time in minutes')),
                );
                return;
              }

              try {
                final mesService =
                    Provider.of<MESService>(context, listen: false);
                await mesService.addItem(
                  nameController.text.trim(),
                  categoryController.text.trim(),
                  time,
                );

                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Item added successfully')),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error adding item: $e')),
                );
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  // Dialog to edit an existing item
  void _showEditItemDialog(BuildContext context, MESItem item) {
    final nameController = TextEditingController(text: item.name);
    final categoryController = TextEditingController(text: item.category);
    final timeController =
        TextEditingController(text: item.estimatedTimeInMinutes.toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Production Item'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Item Name',
                  hintText: 'e.g., Dining Chair',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: categoryController,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  hintText: 'e.g., Chairs',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: timeController,
                decoration: const InputDecoration(
                  labelText: 'Estimated Time (minutes)',
                  hintText: 'e.g., 45',
                ),
                keyboardType: TextInputType.number,
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
            onPressed: () async {
              if (nameController.text.isEmpty ||
                  categoryController.text.isEmpty ||
                  timeController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please fill all fields')),
                );
                return;
              }

              // Parse time value
              final time = int.tryParse(timeController.text);
              if (time == null || time <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Please enter a valid time in minutes')),
                );
                return;
              }

              try {
                final mesService =
                    Provider.of<MESService>(context, listen: false);
                await mesService.updateItem(
                  item.copyWith(
                    name: nameController.text.trim(),
                    category: categoryController.text.trim(),
                    estimatedTimeInMinutes: time,
                  ),
                );

                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Item updated successfully')),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error updating item: $e')),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  // Toggle item active status
  void _toggleItemStatus(BuildContext context, MESItem item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(item.isActive ? 'Deactivate Item' : 'Activate Item'),
        content: Text(
          item.isActive
              ? 'This item will no longer be visible on tablets. Continue?'
              : 'This item will be visible on tablets again. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              try {
                final mesService =
                    Provider.of<MESService>(context, listen: false);
                await mesService.updateItem(
                  item.copyWith(isActive: !item.isActive),
                );

                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      item.isActive
                          ? 'Item deactivated successfully'
                          : 'Item activated successfully',
                    ),
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error updating item: $e')),
                );
              }
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  // Confirm and delete an item
  void _confirmDeleteItem(BuildContext context, MESItem item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Item'),
        content: Text(
          'Are you sure you want to permanently delete "${item.name}"? '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            onPressed: () async {
              try {
                final mesService =
                    Provider.of<MESService>(context, listen: false);
                await mesService.deleteItem(item.id);

                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Item deleted successfully')),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error deleting item: $e')),
                );
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

// Tab for managing interruption types
class _InterruptionTypesTab extends StatelessWidget {
  const _InterruptionTypesTab({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<MESService>(
      builder: (context, mesService, child) {
        if (mesService.isLoadingInterruptionTypes) {
          return const Center(child: CircularProgressIndicator());
        }

        final types = mesService.interruptionTypes;

        if (types.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('No interruption types found.'),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('Add Type'),
                  onPressed: () => _showAddTypeDialog(context),
                ),
              ],
            ),
          );
        }

        return Stack(
          children: [
            ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: types.length,
              itemBuilder: (context, index) {
                final type = types[index];
                return _buildTypeCard(context, type);
              },
            ),
            Positioned(
              right: 16,
              bottom: 16,
              child: FloatingActionButton(
                onPressed: () => _showAddTypeDialog(context),
                tooltip: 'Add Interruption Type',
                child: const Icon(Icons.add),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTypeCard(BuildContext context, MESInterruptionType type) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    type.name,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit),
                      tooltip: 'Edit',
                      onPressed: () => _showEditTypeDialog(context, type),
                    ),
                    IconButton(
                      icon: Icon(type.isActive
                          ? Icons.visibility
                          : Icons.visibility_off),
                      tooltip: type.isActive ? 'Deactivate' : 'Activate',
                      onPressed: () => _toggleTypeStatus(context, type),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete),
                      tooltip: 'Delete',
                      color: Colors.red,
                      onPressed: () => _confirmDeleteType(context, type),
                    ),
                  ],
                ),
              ],
            ),
            if (type.description != null && type.description!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(type.description!),
            ],
            if (!type.isActive) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info, color: Colors.red),
                    SizedBox(width: 8),
                    Text(
                      'This interruption type is currently inactive',
                      style: TextStyle(color: Colors.red),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Dialog to add a new interruption type
  void _showAddTypeDialog(BuildContext context) {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Interruption Type'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Name'),
              const SizedBox(height: 8),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  hintText: 'e.g., Break, Maintenance, etc.',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Description (Optional)'),
              const SizedBox(height: 8),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  hintText: 'Describe this interruption type',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
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
            onPressed: () async {
              if (nameController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a name')),
                );
                return;
              }

              try {
                final mesService =
                    Provider.of<MESService>(context, listen: false);
                await mesService.addInterruptionType(
                  nameController.text.trim(),
                  description: descriptionController.text.trim(),
                );

                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Interruption type added successfully')),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error adding interruption type: $e')),
                );
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  // Dialog to edit an existing interruption type
  void _showEditTypeDialog(BuildContext context, MESInterruptionType type) {
    final nameController = TextEditingController(text: type.name);
    final descriptionController =
        TextEditingController(text: type.description ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Interruption Type'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Name'),
              const SizedBox(height: 8),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  hintText: 'e.g., Break, Maintenance, etc.',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Description (Optional)'),
              const SizedBox(height: 8),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  hintText: 'Describe this interruption type',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
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
            onPressed: () async {
              if (nameController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a name')),
                );
                return;
              }

              try {
                final mesService =
                    Provider.of<MESService>(context, listen: false);
                await mesService.updateInterruptionType(
                  type.copyWith(
                    name: nameController.text.trim(),
                    description: descriptionController.text.trim(),
                  ),
                );

                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Interruption type updated successfully')),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text('Error updating interruption type: $e')),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  // Toggle interruption type active status
  void _toggleTypeStatus(BuildContext context, MESInterruptionType type) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(type.isActive ? 'Deactivate Type' : 'Activate Type'),
        content: Text(
          type.isActive
              ? 'This interruption type will no longer be available on tablets. Continue?'
              : 'This interruption type will be available on tablets again. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              try {
                final mesService =
                    Provider.of<MESService>(context, listen: false);
                await mesService.updateInterruptionType(
                  type.copyWith(isActive: !type.isActive),
                );

                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      type.isActive
                          ? 'Interruption type deactivated successfully'
                          : 'Interruption type activated successfully',
                    ),
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text('Error updating interruption type: $e')),
                );
              }
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  // Confirm and delete an interruption type
  void _confirmDeleteType(BuildContext context, MESInterruptionType type) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Interruption Type'),
        content: Text(
          'Are you sure you want to permanently delete "${type.name}"? '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            onPressed: () async {
              try {
                final mesService =
                    Provider.of<MESService>(context, listen: false);
                await mesService.deleteInterruptionType(type.id);

                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Interruption type deleted successfully')),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text('Error deleting interruption type: $e')),
                );
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
