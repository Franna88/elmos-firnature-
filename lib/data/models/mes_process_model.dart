import 'package:cloud_firestore/cloud_firestore.dart';

class MESProcess {
  final String id;
  final String name;
  final String? description;
  final String? stationId; // Reference to MESStation
  final String? stationName; // Cached for UI performance
  final bool isActive;
  final bool
      requiresSetup; // Whether this process requires setup before production
  final int setupTimeMinutes; // Setup time required in minutes
  final DateTime createdAt;
  final DateTime updatedAt;

  MESProcess({
    required this.id,
    required this.name,
    this.description,
    this.stationId,
    this.stationName,
    this.isActive = true,
    this.requiresSetup = false,
    this.setupTimeMinutes = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  // Create from Firestore document
  factory MESProcess.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return MESProcess(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'],
      stationId: data['stationId'],
      stationName: data['stationName'],
      isActive: data['isActive'] ?? true,
      requiresSetup: data['requiresSetup'] ?? false,
      setupTimeMinutes: data['setupTimeMinutes'] ?? 0,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }

  // Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'description': description,
      'stationId': stationId,
      'stationName': stationName,
      'isActive': isActive,
      'requiresSetup': requiresSetup,
      'setupTimeMinutes': setupTimeMinutes,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  // Create a copy with updated fields
  MESProcess copyWith({
    String? name,
    String? description,
    String? stationId,
    String? stationName,
    bool? isActive,
    bool? requiresSetup,
    int? setupTimeMinutes,
  }) {
    return MESProcess(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      stationId: stationId ?? this.stationId,
      stationName: stationName ?? this.stationName,
      isActive: isActive ?? this.isActive,
      requiresSetup: requiresSetup ?? this.requiresSetup,
      setupTimeMinutes: setupTimeMinutes ?? this.setupTimeMinutes,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  @override
  String toString() {
    return 'MESProcess{id: $id, name: $name, description: $description, stationId: $stationId, isActive: $isActive, requiresSetup: $requiresSetup}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MESProcess && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
