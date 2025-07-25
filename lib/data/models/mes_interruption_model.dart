import 'package:cloud_firestore/cloud_firestore.dart';

class MESInterruptionType {
  final String id;
  final String name;
  final String? description;
  final String? icon;
  final String? color; // Hex color string (e.g., "#FF5722")
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  MESInterruptionType({
    required this.id,
    required this.name,
    this.description,
    this.icon,
    this.color,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  // Create from Firestore document
  factory MESInterruptionType.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return MESInterruptionType(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'],
      icon: data['icon'],
      color: data['color'],
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
      'icon': icon,
      'color': color,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  // Create a copy with updated fields
  MESInterruptionType copyWith({
    String? name,
    String? description,
    String? icon,
    String? color,
    bool? isActive,
  }) {
    return MESInterruptionType(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}
