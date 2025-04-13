import 'package:flutter/foundation.dart' show ChangeNotifier, kDebugMode;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../models/category_model.dart' as models;

class CategoryService extends ChangeNotifier {
  // Nullable Firebase service
  FirebaseFirestore? _firestore;

  List<models.Category> _categories = [];

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
          },
          {
            'name': 'Upholstery',
            'description': 'Procedures related to upholstery operations',
            'color': '#4169E1', // Royal Blue
            'createdAt': Timestamp.now(),
          },
          {
            'name': 'Finishing',
            'description': 'Procedures related to finishing operations',
            'color': '#2E8B57', // Sea Green
            'createdAt': Timestamp.now(),
          },
          {
            'name': 'Assembly',
            'description': 'Procedures related to furniture assembly',
            'color': '#CD853F', // Peru (brown)
            'createdAt': Timestamp.now(),
          },
          {
            'name': 'CNC Operations',
            'description': 'Procedures related to CNC machine operations',
            'color': '#4682B4', // Steel Blue
            'createdAt': Timestamp.now(),
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
    if (_usingLocalData) {
      if (kDebugMode) {
        print('Using local data: Loading sample categories');
      }
      _loadSampleCategories();
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
      {String? description, String? color}) async {
    final now = DateTime.now();
    final categoryId = const Uuid().v4();

    if (kDebugMode) {
      print('Starting category creation process for "$name"');
      print(
          'Firebase connection status: ${!_usingLocalData ? "Connected" : "Not connected (local mode)"}');
    }

    final category = models.Category(
      id: categoryId,
      name: name,
      description: description,
      color: color,
      createdAt: now,
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
      if (!_usingLocalData) {
        // Update the category document in Firestore
        final categoryData = category.toMap();

        await _firestore!
            .collection('categories')
            .doc(category.id)
            .update(categoryData);

        if (kDebugMode) {
          print('Updated category in Firestore with ID: ${category.id}');
        }
      }

      // Update the local list
      final index = _categories.indexWhere((c) => c.id == category.id);
      if (index >= 0) {
        _categories[index] = category;
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
      if (!_usingLocalData) {
        // Delete the category document from Firestore
        await _firestore!.collection('categories').doc(id).delete();

        if (kDebugMode) {
          print('Deleted category with ID: $id from Firestore');
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
}
