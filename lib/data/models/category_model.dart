class Category {
  final String id;
  final String name;
  final String? description;
  final String? color; // optional color code for the category
  final DateTime createdAt;
  final Map<String, bool> categorySettings; // Store section requirements
  final List<String> customSections; // New: Store custom section names

  Category({
    required this.id,
    required this.name,
    this.description,
    this.color,
    required this.createdAt,
    Map<String, bool>? categorySettings,
    List<String>? customSections,
  })  : categorySettings = categorySettings ?? {},
        customSections = customSections ?? [];

  Category copyWith({
    String? id,
    String? name,
    String? description,
    String? color,
    DateTime? createdAt,
    Map<String, bool>? categorySettings,
    List<String>? customSections,
  }) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      color: color ?? this.color,
      createdAt: createdAt ?? this.createdAt,
      categorySettings: categorySettings ?? this.categorySettings,
      customSections: customSections ?? this.customSections,
    );
  }

  // Convert Category to a Map for Firestore
  Map<String, dynamic> toMap() {
    // Ensure steps is always included in settings
    final Map<String, bool> settings = {'steps': true};

    // Keep only steps and any non-standard sections
    categorySettings.forEach((key, value) {
      if (key == 'steps' || !['tools', 'safety', 'cautions'].contains(key)) {
        settings[key] = value;
      }
    });

    return {
      'name': name,
      'description': description,
      'color': color,
      'createdAt': createdAt,
      'categorySettings': settings,
      'customSections': customSections,
    };
  }

  // Create a Category from a Firestore document
  factory Category.fromMap(String id, Map<String, dynamic> map) {
    // Parse categorySettings if it exists
    Map<String, bool> settings = {};

    if (map['categorySettings'] != null) {
      // Convert from Firestore map to Map<String, bool>
      final rawSettings = map['categorySettings'] as Map<String, dynamic>;
      rawSettings.forEach((key, value) {
        if (value is bool) {
          settings[key] = value;
        }
      });
    }

    // Parse customSections if it exists
    List<String> customSections = [];
    if (map['customSections'] != null) {
      customSections = List<String>.from(map['customSections']);
    }

    return Category(
      id: id,
      name: map['name'] ?? '',
      description: map['description'],
      color: map['color'],
      createdAt: map['createdAt']?.toDate() ?? DateTime.now(),
      categorySettings: settings,
      customSections: customSections,
    );
  }
}
