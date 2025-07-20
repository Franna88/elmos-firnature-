import 'package:cloud_firestore/cloud_firestore.dart';

class MESItem {
  final String id;
  final String name;
  final String? description;
  final String? imageUrl;
  final String processId; // Reference to MESProcess
  final String? processName; // Cached for UI performance
  final int estimatedTimeInMinutes;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  MESItem({
    required this.id,
    required this.name,
    this.description,
    this.imageUrl,
    required this.processId,
    this.processName,
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
      description: data['description'],
      imageUrl: data['imageUrl'],
      processId:
          data['processId'] ?? data['category'] ?? '', // Backward compatibility
      processName:
          data['processName'] ?? data['category'], // Backward compatibility
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
      'description': description,
      'imageUrl': imageUrl,
      'processId': processId,
      'processName': processName,
      'estimatedTimeInMinutes': estimatedTimeInMinutes,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      // Keep category for backward compatibility during migration
      'category': processName ?? processId,
    };
  }

  // Create a copy of the item with updated fields
  MESItem copyWith({
    String? name,
    String? description,
    String? imageUrl,
    String? processId,
    String? processName,
    int? estimatedTimeInMinutes,
    bool? isActive,
  }) {
    return MESItem(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      processId: processId ?? this.processId,
      processName: processName ?? this.processName,
      estimatedTimeInMinutes:
          estimatedTimeInMinutes ?? this.estimatedTimeInMinutes,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  // Backward compatibility getter for category
  String get category => processName ?? processId;
}
