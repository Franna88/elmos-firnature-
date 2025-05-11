import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/mes_item_model.dart';
import '../models/mes_interruption_model.dart';
import '../models/mes_production_record_model.dart';

class MESService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Collection references
  CollectionReference get _itemsCollection =>
      _firestore.collection('mes_items');
  CollectionReference get _interruptionTypesCollection =>
      _firestore.collection('mes_interruption_types');
  CollectionReference get _productionRecordsCollection =>
      _firestore.collection('mes_production_records');

  // Cache data
  List<MESItem> _items = [];
  List<MESInterruptionType> _interruptionTypes = [];
  List<MESProductionRecord> _productionRecords = [];

  // Getters for cached data
  List<MESItem> get items => _items;
  List<MESInterruptionType> get interruptionTypes => _interruptionTypes;
  List<MESProductionRecord> get productionRecords => _productionRecords;

  // Loading states
  bool _isLoadingItems = false;
  bool _isLoadingInterruptionTypes = false;
  bool _isLoadingProductionRecords = false;

  // Getters for loading states
  bool get isLoadingItems => _isLoadingItems;
  bool get isLoadingInterruptionTypes => _isLoadingInterruptionTypes;
  bool get isLoadingProductionRecords => _isLoadingProductionRecords;

  // CRUD operations for MES Items

  // Fetch all active MES items
  Future<List<MESItem>> fetchItems({bool onlyActive = true}) async {
    try {
      _isLoadingItems = true;
      notifyListeners();

      Query query = _itemsCollection;

      if (onlyActive) {
        query = query.where('isActive', isEqualTo: true);
      }

      final snapshot = await query.get();
      _items = snapshot.docs.map((doc) => MESItem.fromFirestore(doc)).toList();

      _isLoadingItems = false;
      notifyListeners();

      return _items;
    } catch (e) {
      _isLoadingItems = false;
      notifyListeners();
      rethrow;
    }
  }

  // Add a new MES item
  Future<MESItem> addItem(
      String name, String category, int estimatedTimeInMinutes,
      {String? imageUrl}) async {
    try {
      final now = DateTime.now();

      final docRef = await _itemsCollection.add({
        'name': name,
        'category': category,
        'imageUrl': imageUrl,
        'estimatedTimeInMinutes': estimatedTimeInMinutes,
        'isActive': true,
        'createdAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
      });

      final newItem = MESItem(
        id: docRef.id,
        name: name,
        category: category,
        imageUrl: imageUrl,
        estimatedTimeInMinutes: estimatedTimeInMinutes,
        isActive: true,
        createdAt: now,
        updatedAt: now,
      );

      _items.add(newItem);
      notifyListeners();

      return newItem;
    } catch (e) {
      rethrow;
    }
  }

  // Update an existing MES item
  Future<MESItem> updateItem(MESItem item) async {
    try {
      final now = DateTime.now();

      await _itemsCollection.doc(item.id).update({
        'name': item.name,
        'category': item.category,
        'imageUrl': item.imageUrl,
        'estimatedTimeInMinutes': item.estimatedTimeInMinutes,
        'isActive': item.isActive,
        'updatedAt': Timestamp.fromDate(now),
      });

      final updatedItem = MESItem(
        id: item.id,
        name: item.name,
        category: item.category,
        imageUrl: item.imageUrl,
        estimatedTimeInMinutes: item.estimatedTimeInMinutes,
        isActive: item.isActive,
        createdAt: item.createdAt,
        updatedAt: now,
      );

      final index = _items.indexWhere((i) => i.id == item.id);
      if (index != -1) {
        _items[index] = updatedItem;
        notifyListeners();
      }

      return updatedItem;
    } catch (e) {
      rethrow;
    }
  }

  // Deactivate an MES item (soft delete)
  Future<void> deactivateItem(String itemId) async {
    try {
      await _itemsCollection.doc(itemId).update({
        'isActive': false,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });

      final index = _items.indexWhere((i) => i.id == itemId);
      if (index != -1) {
        _items[index] = _items[index].copyWith(isActive: false);
        notifyListeners();
      }
    } catch (e) {
      rethrow;
    }
  }

  // Delete an MES item (hard delete)
  Future<void> deleteItem(String itemId) async {
    try {
      await _itemsCollection.doc(itemId).delete();

      _items.removeWhere((i) => i.id == itemId);
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  // CRUD operations for Interruption Types

  // Fetch all interruption types
  Future<List<MESInterruptionType>> fetchInterruptionTypes(
      {bool onlyActive = true}) async {
    try {
      _isLoadingInterruptionTypes = true;
      notifyListeners();

      Query query = _interruptionTypesCollection;

      if (onlyActive) {
        query = query.where('isActive', isEqualTo: true);
      }

      final snapshot = await query.get();
      _interruptionTypes = snapshot.docs
          .map((doc) => MESInterruptionType.fromFirestore(doc))
          .toList();

      _isLoadingInterruptionTypes = false;
      notifyListeners();

      return _interruptionTypes;
    } catch (e) {
      _isLoadingInterruptionTypes = false;
      notifyListeners();
      rethrow;
    }
  }

  // Add a new interruption type
  Future<MESInterruptionType> addInterruptionType(String name,
      {String? description, String? icon}) async {
    try {
      final now = DateTime.now();

      final docRef = await _interruptionTypesCollection.add({
        'name': name,
        'description': description,
        'icon': icon,
        'isActive': true,
        'createdAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
      });

      final newType = MESInterruptionType(
        id: docRef.id,
        name: name,
        description: description,
        icon: icon,
        isActive: true,
        createdAt: now,
        updatedAt: now,
      );

      _interruptionTypes.add(newType);
      notifyListeners();

      return newType;
    } catch (e) {
      rethrow;
    }
  }

  // Update an interruption type
  Future<MESInterruptionType> updateInterruptionType(
      MESInterruptionType type) async {
    try {
      final now = DateTime.now();

      await _interruptionTypesCollection.doc(type.id).update({
        'name': type.name,
        'description': type.description,
        'icon': type.icon,
        'isActive': type.isActive,
        'updatedAt': Timestamp.fromDate(now),
      });

      final updatedType = MESInterruptionType(
        id: type.id,
        name: type.name,
        description: type.description,
        icon: type.icon,
        isActive: type.isActive,
        createdAt: type.createdAt,
        updatedAt: now,
      );

      final index = _interruptionTypes.indexWhere((t) => t.id == type.id);
      if (index != -1) {
        _interruptionTypes[index] = updatedType;
        notifyListeners();
      }

      return updatedType;
    } catch (e) {
      rethrow;
    }
  }

  // Deactivate an interruption type (soft delete)
  Future<void> deactivateInterruptionType(String typeId) async {
    try {
      await _interruptionTypesCollection.doc(typeId).update({
        'isActive': false,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });

      final index = _interruptionTypes.indexWhere((t) => t.id == typeId);
      if (index != -1) {
        _interruptionTypes[index] =
            _interruptionTypes[index].copyWith(isActive: false);
        notifyListeners();
      }
    } catch (e) {
      rethrow;
    }
  }

  // Delete an interruption type (hard delete)
  Future<void> deleteInterruptionType(String typeId) async {
    try {
      await _interruptionTypesCollection.doc(typeId).delete();

      _interruptionTypes.removeWhere((t) => t.id == typeId);
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  // CRUD operations for Production Records

  // Fetch production records with filters
  Future<List<MESProductionRecord>> fetchProductionRecords({
    String? userId,
    String? itemId,
    DateTime? startDate,
    DateTime? endDate,
    bool onlyCompleted = false,
  }) async {
    try {
      _isLoadingProductionRecords = true;
      notifyListeners();

      Query query = _productionRecordsCollection;

      if (userId != null) {
        query = query.where('userId', isEqualTo: userId);
      }

      if (itemId != null) {
        query = query.where('itemId', isEqualTo: itemId);
      }

      if (onlyCompleted) {
        query = query.where('isCompleted', isEqualTo: true);
      }

      if (startDate != null) {
        query = query.where('startTime',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
      }

      if (endDate != null) {
        // Add one day to include the entire end date
        final nextDay = DateTime(endDate.year, endDate.month, endDate.day + 1);
        query =
            query.where('startTime', isLessThan: Timestamp.fromDate(nextDay));
      }

      final snapshot = await query.get();
      _productionRecords = snapshot.docs
          .map((doc) => MESProductionRecord.fromFirestore(doc))
          .toList();

      _isLoadingProductionRecords = false;
      notifyListeners();

      return _productionRecords;
    } catch (e) {
      _isLoadingProductionRecords = false;
      notifyListeners();
      rethrow;
    }
  }

  // Start a new production record
  Future<MESProductionRecord> startProductionRecord(
      String itemId, String userId, String userName) async {
    try {
      final now = DateTime.now();

      final docRef = await _productionRecordsCollection.add({
        'itemId': itemId,
        'userId': userId,
        'userName': userName,
        'startTime': Timestamp.fromDate(now),
        'endTime': null,
        'totalProductionTimeSeconds': 0,
        'totalInterruptionTimeSeconds': 0,
        'isCompleted': false,
        'interruptions': [],
        'createdAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
      });

      final newRecord = MESProductionRecord(
        id: docRef.id,
        itemId: itemId,
        userId: userId,
        userName: userName,
        startTime: now,
        endTime: null,
        totalProductionTimeSeconds: 0,
        totalInterruptionTimeSeconds: 0,
        isCompleted: false,
        interruptions: [],
        createdAt: now,
        updatedAt: now,
      );

      _productionRecords.add(newRecord);
      notifyListeners();

      return newRecord;
    } catch (e) {
      rethrow;
    }
  }

  // Update a production record
  Future<MESProductionRecord> updateProductionRecord(
      MESProductionRecord record) async {
    try {
      final now = DateTime.now();

      await _productionRecordsCollection.doc(record.id).update({
        'endTime':
            record.endTime != null ? Timestamp.fromDate(record.endTime!) : null,
        'totalProductionTimeSeconds': record.totalProductionTimeSeconds,
        'totalInterruptionTimeSeconds': record.totalInterruptionTimeSeconds,
        'isCompleted': record.isCompleted,
        'interruptions': record.interruptions.map((i) => i.toMap()).toList(),
        'updatedAt': Timestamp.fromDate(now),
      });

      final updatedRecord = record.copyWith();

      final index = _productionRecords.indexWhere((r) => r.id == record.id);
      if (index != -1) {
        _productionRecords[index] = updatedRecord;
        notifyListeners();
      }

      return updatedRecord;
    } catch (e) {
      rethrow;
    }
  }

  // Add an interruption to a production record
  Future<MESProductionRecord> addInterruptionToRecord(
      String recordId, String typeId, String typeName, DateTime startTime,
      {DateTime? endTime, int durationSeconds = 0, String? notes}) async {
    try {
      // Find the record
      final index = _productionRecords.indexWhere((r) => r.id == recordId);
      if (index == -1) {
        throw Exception('Production record not found');
      }

      final record = _productionRecords[index];

      // Create the new interruption
      final interruption = MESInterruption(
        typeId: typeId,
        typeName: typeName,
        startTime: startTime,
        endTime: endTime,
        durationSeconds: durationSeconds,
        notes: notes,
      );

      // Add to the list
      final updatedInterruptions =
          List<MESInterruption>.from(record.interruptions)..add(interruption);

      // Update total interruption time
      final totalInterruptionTime =
          record.totalInterruptionTimeSeconds + durationSeconds;

      // Create updated record
      final updatedRecord = record.copyWith(
        interruptions: updatedInterruptions,
        totalInterruptionTimeSeconds: totalInterruptionTime,
      );

      // Save to Firestore
      return await updateProductionRecord(updatedRecord);
    } catch (e) {
      rethrow;
    }
  }

  // Complete a production record
  Future<MESProductionRecord> completeProductionRecord(
      String recordId, int totalProductionTimeSeconds) async {
    try {
      // Find the record
      final index = _productionRecords.indexWhere((r) => r.id == recordId);
      if (index == -1) {
        throw Exception('Production record not found');
      }

      final record = _productionRecords[index];
      final now = DateTime.now();

      // Create updated record
      final updatedRecord = record.copyWith(
        endTime: now,
        totalProductionTimeSeconds: totalProductionTimeSeconds,
        isCompleted: true,
      );

      // Save to Firestore
      return await updateProductionRecord(updatedRecord);
    } catch (e) {
      rethrow;
    }
  }

  // Get a single production record by ID
  Future<MESProductionRecord> getProductionRecord(String recordId) async {
    try {
      final doc = await _productionRecordsCollection.doc(recordId).get();

      if (!doc.exists) {
        throw Exception('Production record not found');
      }

      return MESProductionRecord.fromFirestore(doc);
    } catch (e) {
      rethrow;
    }
  }

  // Get unique categories from items
  List<String> getUniqueCategories() {
    return _items.map((item) => item.category).toSet().toList();
  }

  // Get items by category
  List<MESItem> getItemsByCategory(String category) {
    return _items.where((item) => item.category == category).toList();
  }

  // Fetch all unique operators from production records
  Future<List<Map<String, dynamic>>> fetchUniqueOperators() async {
    try {
      // Use a set to track unique user IDs
      final Set<String> uniqueUserIds = {};
      final List<Map<String, dynamic>> operators = [];

      // If we already have production records loaded, use them
      if (_productionRecords.isNotEmpty) {
        for (var record in _productionRecords) {
          if (!uniqueUserIds.contains(record.userId)) {
            uniqueUserIds.add(record.userId);
            operators.add({
              'id': record.userId,
              'name': record.userName,
            });
          }
        }
      } else {
        // Otherwise fetch from Firestore
        final snapshot = await _productionRecordsCollection.get();
        for (var doc in snapshot.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final userId = data['userId'] as String;
          final userName = data['userName'] as String;

          if (!uniqueUserIds.contains(userId)) {
            uniqueUserIds.add(userId);
            operators.add({
              'id': userId,
              'name': userName,
            });
          }
        }
      }

      // Sort by name
      operators
          .sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));

      return operators;
    } catch (e) {
      rethrow;
    }
  }

  // Fetch daily production summaries
  Future<List<Map<String, dynamic>>> fetchDailySummaries({
    DateTime? startDate,
    DateTime? endDate,
    String? userId,
  }) async {
    try {
      // Make sure we have production records
      await fetchProductionRecords(
        userId: userId,
        startDate: startDate,
        endDate: endDate,
      );

      // Group records by date and user
      final Map<String, Map<String, dynamic>> dailySummaries = {};

      for (var record in _productionRecords) {
        // Skip non-completed records
        if (!record.isCompleted) continue;

        // Create date key (yyyy-MM-dd)
        final date = DateTime(
          record.startTime.year,
          record.startTime.month,
          record.startTime.day,
        );
        final dateStr = date.toIso8601String().split('T')[0];
        final key = '${dateStr}_${record.userId}';

        if (!dailySummaries.containsKey(key)) {
          dailySummaries[key] = {
            'date': date,
            'userId': record.userId,
            'userName': record.userName,
            'itemsCompleted': 0,
            'totalProductionTimeSeconds': 0,
            'totalNonProductiveTimeSeconds': 0,
          };
        }

        // Update summary
        dailySummaries[key]!['itemsCompleted'] =
            (dailySummaries[key]!['itemsCompleted'] as int) + 1;

        dailySummaries[key]!['totalProductionTimeSeconds'] =
            (dailySummaries[key]!['totalProductionTimeSeconds'] as int) +
                record.totalProductionTimeSeconds;

        dailySummaries[key]!['totalNonProductiveTimeSeconds'] =
            (dailySummaries[key]!['totalNonProductiveTimeSeconds'] as int) +
                record.totalInterruptionTimeSeconds;
      }

      // Convert to list and sort by date (newest first)
      final result = dailySummaries.values.toList()
        ..sort(
            (a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime));

      return result;
    } catch (e) {
      rethrow;
    }
  }
}
