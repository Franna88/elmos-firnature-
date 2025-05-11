import 'package:cloud_firestore/cloud_firestore.dart';

class MESItem {
  final String id;
  final String name;
  final String? imageUrl;
  final String category;
  final int estimatedTimeInMinutes;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  MESItem({
    required this.id,
    required this.name,
    this.imageUrl,
    required this.category,
    required this.estimatedTimeInMinutes,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  // Create from Firestore document
  factory MESItem.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return MESItem(
      id: doc.id,
      name: data['name'] ?? '',
      imageUrl: data['imageUrl'],
      category: data['category'] ?? '',
      estimatedTimeInMinutes: data['estimatedTimeInMinutes'] ?? 0,
      isActive: data['isActive'] ?? true,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }

  // Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'imageUrl': imageUrl,
      'category': category,
      'estimatedTimeInMinutes': estimatedTimeInMinutes,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  // Create a copy of the item with updated fields
  MESItem copyWith({
    String? name,
    String? imageUrl,
    String? category,
    int? estimatedTimeInMinutes,
    bool? isActive,
  }) {
    return MESItem(
      id: id,
      name: name ?? this.name,
      imageUrl: imageUrl ?? this.imageUrl,
      category: category ?? this.category,
      estimatedTimeInMinutes:
          estimatedTimeInMinutes ?? this.estimatedTimeInMinutes,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}
