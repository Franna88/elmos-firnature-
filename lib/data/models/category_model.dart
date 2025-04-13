class Category {
  final String id;
  final String name;
  final String? description;
  final String? color; // optional color code for the category
  final DateTime createdAt;

  Category({
    required this.id,
    required this.name,
    this.description,
    this.color,
    required this.createdAt,
  });

  Category copyWith({
    String? id,
    String? name,
    String? description,
    String? color,
    DateTime? createdAt,
  }) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      color: color ?? this.color,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  // Convert Category to a Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'color': color,
      'createdAt': createdAt,
    };
  }

  // Create a Category from a Firestore document
  factory Category.fromMap(String id, Map<String, dynamic> map) {
    return Category(
      id: id,
      name: map['name'] ?? '',
      description: map['description'],
      color: map['color'],
      createdAt: map['createdAt']?.toDate() ?? DateTime.now(),
    );
  }
}
