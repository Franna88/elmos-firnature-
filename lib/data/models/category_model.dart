class Category {
  final String id;
  final String name;
  final String? description;
  final String? color; // optional color code for the category
  final DateTime createdAt;
  final Map<String, bool>
      categorySettings; // Store section requirements (tools, safety, cautions, etc.)

  Category({
    required this.id,
    required this.name,
    this.description,
    this.color,
    required this.createdAt,
    Map<String, bool>? categorySettings,
  }) : categorySettings = categorySettings ??
            {
              'tools': true,
              'safety': true,
              'cautions': true,
              'steps': true, // Steps are always required
            };

  Category copyWith({
    String? id,
    String? name,
    String? description,
    String? color,
    DateTime? createdAt,
    Map<String, bool>? categorySettings,
  }) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      color: color ?? this.color,
      createdAt: createdAt ?? this.createdAt,
      categorySettings: categorySettings ?? this.categorySettings,
    );
  }

  // Convert Category to a Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'color': color,
      'createdAt': createdAt,
      'categorySettings': categorySettings,
    };
  }

  // Create a Category from a Firestore document
  factory Category.fromMap(String id, Map<String, dynamic> map) {
    // Parse categorySettings if it exists
    Map<String, bool> settings = {
      'tools': true,
      'safety': true,
      'cautions': true,
      'steps': true,
    };

    if (map['categorySettings'] != null) {
      // Convert from Firestore map to Map<String, bool>
      final rawSettings = map['categorySettings'] as Map<String, dynamic>;
      rawSettings.forEach((key, value) {
        if (value is bool) {
          settings[key] = value;
        }
      });
    }

    return Category(
      id: id,
      name: map['name'] ?? '',
      description: map['description'],
      color: map['color'],
      createdAt: map['createdAt']?.toDate() ?? DateTime.now(),
      categorySettings: settings,
    );
  }
}
