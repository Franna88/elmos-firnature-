import '../../../data/models/mes_item_model.dart';

class FurnitureItem {
  final String id;
  final String name;
  final String? imageUrl;
  final String category;
  final int estimatedTimeInMinutes;
  int completedCount;

  FurnitureItem({
    required this.id,
    required this.name,
    this.imageUrl,
    required this.category,
    required this.estimatedTimeInMinutes,
    this.completedCount = 0,
  });

  // Create from MESItem
  factory FurnitureItem.fromMESItem(MESItem mesItem) {
    return FurnitureItem(
      id: mesItem.id,
      name: mesItem.name,
      imageUrl: mesItem.imageUrl,
      category: mesItem.category,
      estimatedTimeInMinutes: mesItem.estimatedTimeInMinutes,
    );
  }
}

// This is kept for backwards compatibility - the actual data will come from Firebase
final List<FurnitureItem> demoFurnitureItems = [];
