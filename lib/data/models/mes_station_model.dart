import 'package:cloud_firestore/cloud_firestore.dart';

class MESStation {
  final String id;
  final String name;
  final String? description;
  final String? location;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  MESStation({
    required this.id,
    required this.name,
    this.description,
    this.location,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  // Create from Firestore document
  factory MESStation.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return MESStation(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'],
      location: data['location'],
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
      'location': location,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  // Create a copy with updated fields
  MESStation copyWith({
    String? name,
    String? description,
    String? location,
    bool? isActive,
  }) {
    return MESStation(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      location: location ?? this.location,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  @override
  String toString() {
    return 'MESStation{id: $id, name: $name, description: $description, location: $location, isActive: $isActive}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MESStation && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
