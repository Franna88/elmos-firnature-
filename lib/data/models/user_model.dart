import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String id;
  final String name;
  final String email;
  final String role;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool isActive;
  final String? phoneNumber;
  final String? profileImageUrl;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.createdAt,
    this.updatedAt,
    this.isActive = true,
    this.phoneNumber,
    this.profileImageUrl,
  });

  // Create UserModel from Firestore document
  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel(
      id: doc.id,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      role: data['role'] ?? 'user',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      isActive: data['isActive'] ?? true,
      phoneNumber: data['phoneNumber'],
      profileImageUrl: data['profileImageUrl'],
    );
  }

  // Create UserModel from Map (for local storage)
  factory UserModel.fromMap(Map<String, dynamic> map, String id) {
    return UserModel(
      id: id,
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      role: map['role'] ?? 'user',
      createdAt: map['createdAt'] is DateTime
          ? map['createdAt']
          : DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now(),
      updatedAt: map['updatedAt'] is DateTime
          ? map['updatedAt']
          : DateTime.tryParse(map['updatedAt'] ?? ''),
      isActive: map['isActive'] ?? true,
      phoneNumber: map['phoneNumber'],
      profileImageUrl: map['profileImageUrl'],
    );
  }

  // Convert UserModel to Map for Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'email': email,
      'role': role,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'isActive': isActive,
      'phoneNumber': phoneNumber,
      'profileImageUrl': profileImageUrl,
    };
  }

  // Convert UserModel to Map for local storage
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'role': role,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'isActive': isActive,
      'phoneNumber': phoneNumber,
      'profileImageUrl': profileImageUrl,
    };
  }

  // Create a copy with updated fields
  UserModel copyWith({
    String? id,
    String? name,
    String? email,
    String? role,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isActive,
    String? phoneNumber,
    String? profileImageUrl,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isActive: isActive ?? this.isActive,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'UserModel(id: $id, name: $name, email: $email, role: $role, isActive: $isActive)';
  }
}

// Predefined user roles
class UserRole {
  static const String admin = 'admin';
  static const String manager = 'manager';
  static const String assembly = 'assembly';
  static const String finishing = 'finishing';
  static const String machinery = 'machinery';
  static const String quality = 'quality';
  static const String user = 'user';

  static const List<String> allRoles = [
    admin,
    manager,
    assembly,
    finishing,
    machinery,
    quality,
    user,
  ];

  static String getRoleDisplayName(String role) {
    switch (role) {
      case admin:
        return 'Administrator';
      case manager:
        return 'Manager';
      case assembly:
        return 'Assembly';
      case finishing:
        return 'Finishing';
      case machinery:
        return 'Machinery/CNC';
      case quality:
        return 'Quality Control';
      case user:
        return 'User';
      default:
        return role.substring(0, 1).toUpperCase() + role.substring(1);
    }
  }
}
