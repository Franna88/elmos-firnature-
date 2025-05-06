import 'package:flutter/material.dart';
import '../models/furniture_item.dart';

class ItemSelectionScreen extends StatefulWidget {
  const ItemSelectionScreen({Key? key}) : super(key: key);

  @override
  State<ItemSelectionScreen> createState() => _ItemSelectionScreenState();
}

class _ItemSelectionScreenState extends State<ItemSelectionScreen> {
  String? _selectedCategory;
  
  List<FurnitureItem> get filteredItems {
    if (_selectedCategory == null) {
      return demoFurnitureItems;
    }
    return demoFurnitureItems.where((item) => item.category == _selectedCategory).toList();
  }

  // Get unique categories from items
  List<String> get categories {
    return demoFurnitureItems
        .map((item) => item.category)
        .toSet()
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Item to Build'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              Navigator.pushReplacementNamed(context, '/login');
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                      selectedColor: const Color(0xFFEB281E).withOpacity(0.2),
                      checkmarkColor: const Color(0xFFEB281E),
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
                      label: Text(category),
                      selected: _selectedCategory == category,
                      selectedColor: const Color(0xFFEB281E).withOpacity(0.2),
                      checkmarkColor: const Color(0xFFEB281E),
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
                  return _buildItemCard(context, item);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemCard(BuildContext context, FurnitureItem item) {
    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      elevation: 4,
      child: InkWell(
        onTap: () {
          // Navigate to timer screen with selected item
          Navigator.pushNamed(
            context, 
            '/timer',
            arguments: item,
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Placeholder for actual image
            Expanded(
              child: Container(
                color: Colors.grey[300],
                child: Center(
                  child: Icon(
                    _getIconForCategory(item.category),
                    size: 80,
                    color: const Color(0xFF2C2C2C),
                  ),
                ),
              ),
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
} 