class FurnitureItem {
  final String id;
  final String name;
  final String imageUrl;
  final String category;
  final int estimatedTimeInMinutes;
  int completedCount;

  FurnitureItem({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.category,
    required this.estimatedTimeInMinutes,
    this.completedCount = 0,
  });
}

// Sample data
final List<FurnitureItem> demoFurnitureItems = [
  FurnitureItem(
    id: '1',
    name: 'Dining Chair',
    imageUrl: 'assets/images/dining_chair.jpg',
    category: 'Chairs',
    estimatedTimeInMinutes: 45,
  ),
  FurnitureItem(
    id: '2',
    name: 'Coffee Table',
    imageUrl: 'assets/images/coffee_table.jpg',
    category: 'Tables',
    estimatedTimeInMinutes: 90,
  ),
  FurnitureItem(
    id: '3',
    name: 'Bar Stool',
    imageUrl: 'assets/images/bar_stool.jpg',
    category: 'Chairs',
    estimatedTimeInMinutes: 60,
  ),
  FurnitureItem(
    id: '4',
    name: 'Dining Table',
    imageUrl: 'assets/images/dining_table.jpg',
    category: 'Tables',
    estimatedTimeInMinutes: 120,
  ),
  FurnitureItem(
    id: '5',
    name: 'Ottoman',
    imageUrl: 'assets/images/ottoman.jpg',
    category: 'Ottomans',
    estimatedTimeInMinutes: 40,
  ),
  FurnitureItem(
    id: '6',
    name: 'Bench',
    imageUrl: 'assets/images/bench.jpg',
    category: 'Benches',
    estimatedTimeInMinutes: 75,
  ),
]; 