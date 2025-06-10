import 'package:flutter/foundation.dart' show ChangeNotifier, kDebugMode;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../models/category_model.dart' as models;

class CategoryService extends ChangeNotifier {
  // Nullable Firebase service
  FirebaseFirestore? _firestore;

  List<models.Category> _categories = [];
  bool _isLoading = false;
  bool _hasLoaded = false;

  // Flag to track if we're using local data
  bool _usingLocalData = false;

  List<models.Category> get categories => List.unmodifiable(_categories);
  bool get usingLocalData => _usingLocalData;

  CategoryService() {
    _initializeData();
  }

  Future<void> _initializeData() async {
    try {
      // Initialize Firebase services
      _firestore = FirebaseFirestore.instance;

      if (kDebugMode) {
        print('Initializing CategoryService');
        print('Firestore: ${_firestore != null ? "initialized" : "failed"}');
      }

      // Test if Firestore is working
      await _ensureCollectionExists();

      if (kDebugMode) {
        print('✅ Using Firebase Firestore for Category data');
      }

      await _loadCategories();
    } catch (e) {
      if (kDebugMode) {
        print('❌ Firebase initialization error in CategoryService: $e');
        print('Using local category data instead');
        if (e is FirebaseException) {
          print('Firebase error code: ${e.code}');
          print('Firebase error message: ${e.message}');
        }
      }
      _usingLocalData = true;
      _loadSampleCategories();
    }
  }

  Future<void> _ensureCollectionExists() async {
    try {
      if (kDebugMode) {
        print('Checking Firestore categories collection...');
      }

      // Check if 'categories' collection exists by trying to get a document
      final categoriesSnapshot =
          await _firestore!.collection('categories').limit(1).get();

      if (kDebugMode) {
        print(
            '- "categories" collection check: ${categoriesSnapshot.size} documents found');
      }

      // If collection is empty, create initial categories
      if (categoriesSnapshot.docs.isEmpty) {
        if (kDebugMode) {
          print('Creating initial categories in Firestore');
        }

        // Create default categories
        final defaultCategories = [
          {
            'name': 'Woodworking',
            'description': 'Procedures related to woodworking operations',
            'color': '#8B4513', // Brown
            'createdAt': Timestamp.now(),
            'categorySettings': {},
            'customSections': [],
          },
          {
            'name': 'Upholstery',
            'description': 'Procedures related to upholstery operations',
            'color': '#4169E1', // Royal Blue
            'createdAt': Timestamp.now(),
            'categorySettings': {},
            'customSections': [],
          },
          {
            'name': 'Finishing',
            'description': 'Procedures related to finishing operations',
            'color': '#2E8B57', // Sea Green
            'createdAt': Timestamp.now(),
            'categorySettings': {},
            'customSections': [],
          },
          {
            'name': 'Assembly',
            'description': 'Procedures related to furniture assembly',
            'color': '#CD853F', // Peru (brown)
            'createdAt': Timestamp.now(),
            'categorySettings': {},
            'customSections': [],
          },
          {
            'name': 'CNC Operations',
            'description': 'Procedures related to CNC machine operations',
            'color': '#4682B4', // Steel Blue
            'createdAt': Timestamp.now(),
            'categorySettings': {},
            'customSections': [],
          },
        ];

        // Add default categories to Firestore
        for (var category in defaultCategories) {
          final docRef =
              await _firestore!.collection('categories').add(category);
          if (kDebugMode) {
            print(
                '- Created category "${category['name']}" with ID: ${docRef.id}');
          }
        }
      }

      if (kDebugMode) {
        print('✅ Firestore category collection check complete');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error ensuring category collection exists: $e');
        if (e is FirebaseException) {
          print('Firebase error code: ${e.code}');
          print('Firebase error message: ${e.message}');
        }
      }
      throw e; // Re-throw to be caught by the caller
    }
  }

  Future<void> _loadCategories() async {
    // Prevent duplicate loading
    if (_isLoading || _hasLoaded) {
      return;
    }

    _isLoading = true;

    if (_usingLocalData) {
      if (kDebugMode) {
        print('Using local data: Loading sample categories');
      }
      _loadSampleCategories();
      _isLoading = false;
      _hasLoaded = true;
      return;
    }

    try {
      if (kDebugMode) {
        print('Attempting to load categories from Firestore...');
      }

      // Get all categories from Firestore
      final snapshot =
          await _firestore!.collection('categories').orderBy('name').get();

      if (kDebugMode) {
        print('Retrieved ${snapshot.docs.length} categories from Firestore');
      }

      final List<models.Category> loadedCategories = [];

      for (var doc in snapshot.docs) {
        final data = doc.data();
        loadedCategories.add(models.Category.fromMap(doc.id, data));
      }

      _categories = loadedCategories;
      _hasLoaded = true;
      notifyListeners();

      if (kDebugMode) {
        print(
            '✅ Successfully loaded ${loadedCategories.length} categories from Firestore');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error loading categories from Firestore: $e');
        if (e is FirebaseException) {
          print('Firebase error code: ${e.code}');
          print('Firebase error message: ${e.message}');
        }
        print('Using sample categories instead');
      }
      _loadSampleCategories();
      _hasLoaded = true;
    } finally {
      _isLoading = false;
    }
  }

  void _loadSampleCategories() {
    _categories = [
      models.Category(
        id: '1',
        name: 'Woodworking',
        description: 'Procedures related to woodworking operations',
        color: '#8B4513', // Brown
        createdAt: DateTime.now(),
      ),
      models.Category(
        id: '2',
        name: 'Upholstery',
        description: 'Procedures related to upholstery operations',
        color: '#4169E1', // Royal Blue
        createdAt: DateTime.now(),
      ),
      models.Category(
        id: '3',
        name: 'Finishing',
        description: 'Procedures related to finishing operations',
        color: '#2E8B57', // Sea Green
        createdAt: DateTime.now(),
      ),
      models.Category(
        id: '4',
        name: 'Assembly',
        description: 'Procedures related to furniture assembly',
        color: '#CD853F', // Peru (brown)
        createdAt: DateTime.now(),
      ),
      models.Category(
        id: '5',
        name: 'CNC Operations',
        description: 'Procedures related to CNC machine operations',
        color: '#4682B4', // Steel Blue
        createdAt: DateTime.now(),
      ),
    ];
    notifyListeners();
  }

  Future<void> refreshCategories() async {
    await _loadCategories();
  }

  models.Category? getCategoryById(String id) {
    try {
      return _categories.firstWhere((category) => category.id == id);
    } catch (e) {
      return null;
    }
  }

  Future<models.Category> createCategory(String name,
      {String? description,
      String? color,
      Map<String, bool>? categorySettings,
      List<String>? customSections}) async {
    final now = DateTime.now();
    final categoryId = const Uuid().v4();

    if (kDebugMode) {
      print('Starting category creation process for "$name"');
      print(
          'Firebase connection status: ${!_usingLocalData ? "Connected" : "Not connected (local mode)"}');
    }

    // Create basic category, always setting 'steps' to true since it's required
    final Map<String, bool> initialSettings =
        categorySettings ?? {'steps': true};
    if (!initialSettings.containsKey('steps')) {
      initialSettings['steps'] = true; // Ensure steps is always included
    }

    // Remove any standard sections except steps
    final Map<String, bool> filteredSettings = {'steps': true};
    initialSettings.forEach((key, value) {
      // Keep steps and any non-standard sections the user added
      if (key == 'steps' || !['tools', 'safety', 'cautions'].contains(key)) {
        filteredSettings[key] = value;
      }
    });

    final List<String> initialCustomSections = customSections ?? [];

    final category = models.Category(
      id: categoryId,
      name: name,
      description: description,
      color: color,
      createdAt: now,
      categorySettings: filteredSettings,
      customSections: initialCustomSections,
    );

    if (!_usingLocalData) {
      try {
        if (kDebugMode) {
          print('_firestore instance exists: ${_firestore != null}');
        }

        // Create the category document
        final categoryData = {
          'name': name,
          'description': description,
          'color': color,
          'createdAt': Timestamp.fromDate(now),
          'categorySettings': category.categorySettings,
          'customSections': category.customSections,
        };

        if (kDebugMode) {
          print('Creating category in Firestore with data: $categoryData');
          print('Target Firestore path: categories/$categoryId');
        }

        // Create the category in Firestore
        await _firestore!
            .collection('categories')
            .doc(categoryId)
            .set(categoryData)
            .then((_) {
          if (kDebugMode) {
            print(
                '✅ Successfully wrote category data to Firestore path: categories/$categoryId');
          }
        }).catchError((error) {
          if (kDebugMode) {
            print('❌ Failed to write to Firestore: $error');
          }
          throw error;
        });

        if (kDebugMode) {
          print('Created new category in Firestore with ID: $categoryId');
        }
      } catch (e) {
        if (kDebugMode) {
          print('❌ Error creating category in Firestore: $e');
          print('Using local category data instead');
        }
        _usingLocalData = true;
      }
    }

    // Add to local list
    _categories.add(category);
    notifyListeners();

    if (kDebugMode) {
      print(
          'Category created and added to local list. Total categories: ${_categories.length}');
    }

    return category;
  }

  Future<void> updateCategory(models.Category category) async {
    try {
      // Ensure steps is always included
      final updatedSettings = Map<String, bool>.from(category.categorySettings);
      updatedSettings['steps'] = true;

      // Remove any standard sections except steps
      final Map<String, bool> filteredSettings = {'steps': true};
      updatedSettings.forEach((key, value) {
        // Keep steps and any non-standard sections the user added
        if (key == 'steps' || !['tools', 'safety', 'cautions'].contains(key)) {
          filteredSettings[key] = value;
        }
      });

      // Create a new category with the updated settings
      final updatedCategory =
          category.copyWith(categorySettings: filteredSettings);

      if (!_usingLocalData) {
        // Update the category document in Firestore
        final categoryData = updatedCategory.toMap();

        await _firestore!
            .collection('categories')
            .doc(updatedCategory.id)
            .update(categoryData);

        if (kDebugMode) {
          print('Updated category in Firestore with ID: ${updatedCategory.id}');
        }
      }

      // Update the local list
      final index = _categories.indexWhere((c) => c.id == updatedCategory.id);
      if (index >= 0) {
        _categories[index] = updatedCategory;
        notifyListeners();
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error updating category: $e');
      }

      // If using Firestore failed, switch to local data
      if (!_usingLocalData) {
        _usingLocalData = true;

        // Update local list
        final index = _categories.indexWhere((c) => c.id == category.id);
        if (index >= 0) {
          _categories[index] = category;
          notifyListeners();
        }
      } else {
        throw Exception('Failed to update category: $e');
      }
    }
  }

  Future<void> deleteCategory(String id) async {
    try {
      // Get the category before deletion to record its name
      final category = getCategoryById(id);
      final categoryName = category?.name ?? '';

      if (!_usingLocalData) {
        // Delete the category document from Firestore
        await _firestore!.collection('categories').doc(id).delete();

        if (kDebugMode) {
          print('Deleted category with ID: $id from Firestore');
        }

        // Update any SOPs that are in this category
        try {
          // Get SOPs in this category
          final sopsQuery = await _firestore!
              .collection('sops')
              .where('categoryId', isEqualTo: id)
              .get();

          // Update each SOP to remove the category
          for (var doc in sopsQuery.docs) {
            await _firestore!.collection('sops').doc(doc.id).update({
              'categoryId': '',
              'categoryName': 'Uncategorized',
            });

            if (kDebugMode) {
              print('Updated SOP ${doc.id} to remove deleted category $id');
            }
          }
        } catch (e) {
          if (kDebugMode) {
            print('❌ Error updating SOPs after category deletion: $e');
          }
        }
      }

      // Update the local list
      _categories.removeWhere((category) => category.id == id);
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error deleting category: $e');
      }

      if (!_usingLocalData) {
        _usingLocalData = true;
        // Update the local list
        _categories.removeWhere((category) => category.id == id);
        notifyListeners();
      } else {
        throw Exception('Failed to delete category: $e');
      }
    }
  }

  // Add a new section to a category
  Future<void> addSectionToCategory(String categoryId, String sectionName,
      {bool isRequired = false}) async {
    try {
      // Find the category in local list
      final categoryIndex = _categories.indexWhere((c) => c.id == categoryId);
      if (categoryIndex < 0) {
        throw Exception('Category not found with ID: $categoryId');
      }

      final category = _categories[categoryIndex];

      // Create updated maps for the category
      final updatedSettings = Map<String, bool>.from(category.categorySettings);
      updatedSettings[sectionName] = isRequired;

      // Create updated category with the new section
      final updatedCategory = category.copyWith(
        categorySettings: updatedSettings,
      );

      if (!_usingLocalData) {
        // Update in Firestore
        await _firestore!.collection('categories').doc(categoryId).update({
          'categorySettings': updatedSettings,
        });

        if (kDebugMode) {
          print(
              'Added section "$sectionName" to category $categoryId in Firestore');
        }
      }

      // Update local list
      _categories[categoryIndex] = updatedCategory;
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error adding section to category: $e');
      }
      throw Exception('Failed to add section to category: $e');
    }
  }

  // Add a custom section to a category
  Future<void> addCustomSectionToCategory(
      String categoryId, String sectionName) async {
    try {
      // Find the category in local list
      final categoryIndex = _categories.indexWhere((c) => c.id == categoryId);
      if (categoryIndex < 0) {
        throw Exception('Category not found with ID: $categoryId');
      }

      final category = _categories[categoryIndex];

      // Prevent duplicates
      if (category.customSections.contains(sectionName)) {
        return;
      }

      // Create updated custom sections list
      final updatedCustomSections = List<String>.from(category.customSections);
      updatedCustomSections.add(sectionName);

      // Create updated category with the new custom section
      final updatedCategory = category.copyWith(
        customSections: updatedCustomSections,
      );

      if (!_usingLocalData) {
        // Update in Firestore
        await _firestore!.collection('categories').doc(categoryId).update({
          'customSections': updatedCustomSections,
        });

        if (kDebugMode) {
          print(
              'Added custom section "$sectionName" to category $categoryId in Firestore');
        }
      }

      // Update local list
      _categories[categoryIndex] = updatedCategory;
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error adding custom section to category: $e');
      }
      throw Exception('Failed to add custom section to category: $e');
    }
  }

  // Remove a section from a category
  Future<void> removeSectionFromCategory(
      String categoryId, String sectionName) async {
    try {
      // Find the category in local list
      final categoryIndex = _categories.indexWhere((c) => c.id == categoryId);
      if (categoryIndex < 0) {
        throw Exception('Category not found with ID: $categoryId');
      }

      final category = _categories[categoryIndex];

      // Create updated maps for the category
      final updatedSettings = Map<String, bool>.from(category.categorySettings);
      updatedSettings.remove(sectionName);

      // Create updated category without the section
      final updatedCategory = category.copyWith(
        categorySettings: updatedSettings,
      );

      if (!_usingLocalData) {
        // Update in Firestore
        await _firestore!.collection('categories').doc(categoryId).update({
          'categorySettings': updatedSettings,
        });

        if (kDebugMode) {
          print(
              'Removed section "$sectionName" from category $categoryId in Firestore');
        }
      }

      // Update local list
      _categories[categoryIndex] = updatedCategory;
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error removing section from category: $e');
      }
      throw Exception('Failed to remove section from category: $e');
    }
  }

  // Remove a custom section from a category
  Future<void> removeCustomSectionFromCategory(
      String categoryId, String sectionName) async {
    try {
      // Find the category in local list
      final categoryIndex = _categories.indexWhere((c) => c.id == categoryId);
      if (categoryIndex < 0) {
        throw Exception('Category not found with ID: $categoryId');
      }

      final category = _categories[categoryIndex];

      // Create updated custom sections list
      final updatedCustomSections = List<String>.from(category.customSections);
      updatedCustomSections.remove(sectionName);

      // Create updated category without the custom section
      final updatedCategory = category.copyWith(
        customSections: updatedCustomSections,
      );

      if (!_usingLocalData) {
        // Update in Firestore
        await _firestore!.collection('categories').doc(categoryId).update({
          'customSections': updatedCustomSections,
        });

        if (kDebugMode) {
          print(
              'Removed custom section "$sectionName" from category $categoryId in Firestore');
        }
      }

      // Update local list
      _categories[categoryIndex] = updatedCategory;
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error removing custom section from category: $e');
      }
      throw Exception('Failed to remove custom section from category: $e');
    }
  }
}
