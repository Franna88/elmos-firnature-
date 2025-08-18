import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/production_item_model.dart';
import '../models/mes_item_model.dart';

/// Service for managing production timer functionality
class ProductionTimerService extends ChangeNotifier {
  static const String _collectionName = 'production_sessions';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Current state
  ProductionSession? _currentSession;
  ProductionItem? _selectedItem;
  Timer? _timer;

  // Getters
  ProductionSession? get currentSession => _currentSession;
  ProductionItem? get selectedItem => _selectedItem;
  bool get hasActiveSession => _currentSession?.isActive == true;
  bool get hasSelectedItem => _selectedItem != null;
  TimerActionType? get currentActiveAction =>
      _currentSession?.currentActiveAction;

  // Timer constraints based on requirements
  bool get canStartActions => hasSelectedItem;
  bool get canShowNextButton =>
      currentActiveAction == TimerActionType.production;
  bool get requiresFinishedQtyForShutdown =>
      false; // Never require popup for shutdown

  ProductionTimerService() {
    // Start the timer that updates every second
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (hasActiveSession) {
        notifyListeners();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// Select an item and start a new production session
  Future<void> selectItem(ProductionItem item) async {
    try {
      _selectedItem = item;

      // End any existing session
      if (_currentSession != null && _currentSession!.isActive) {
        await endSession();
      }

      // Create new session
      final sessionId = _firestore.collection(_collectionName).doc().id;
      _currentSession = ProductionSession(
        id: sessionId,
        itemId: item.id,
        itemName: item.name,
        startTime: DateTime.now(),
      );

      // Auto-start Setup action as per requirements - NO POPUPS!
      await startAction(TimerActionType.setup);

      // Save to Firestore
      await _saveSession();

      notifyListeners();

      if (kDebugMode) {
        print(
            'Selected item: ${item.name} and started Setup action immediately');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error selecting item: $e');
      }
      rethrow;
    }
  }

  /// Start a specific timer action
  Future<void> startAction(TimerActionType actionType) async {
    if (!canStartActions) {
      throw Exception('Cannot start actions without selecting an item first');
    }

    if (_currentSession == null) {
      throw Exception('No active session');
    }

    try {
      // Stop any currently active action
      await _stopCurrentAction();

      // Start the new action
      final now = DateTime.now();
      final actionState = TimerActionState(
        type: actionType,
        startTime: now,
        isActive: true,
      );

      _currentSession = _currentSession!.copyWith(
        actionStates: {
          ..._currentSession!.actionStates,
          actionType: actionState,
        },
      );

      await _saveSession();
      notifyListeners();

      if (kDebugMode) {
        print('Started action: ${actionType.displayName}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error starting action: $e');
      }
      rethrow;
    }
  }

  /// Stop the current active action
  Future<void> stopCurrentAction() async {
    await _stopCurrentAction();
    await _saveSession();
    notifyListeners();
  }

  /// Private method to stop current action without saving
  Future<void> _stopCurrentAction() async {
    if (_currentSession == null) return;

    final currentActive = _currentSession!.currentActiveAction;
    if (currentActive == null) return;

    final now = DateTime.now();
    final currentState = _currentSession!.actionStates[currentActive]!;
    final duration = currentState.startTime != null
        ? now.difference(currentState.startTime!).inSeconds
        : 0;

    final updatedState = currentState.copyWith(
      endTime: now,
      durationSeconds: duration,
      isActive: false,
    );

    _currentSession = _currentSession!.copyWith(
      actionStates: {
        ..._currentSession!.actionStates,
        currentActive: updatedState,
      },
    );
  }

  /// Increment cycle count (Next button functionality)
  Future<void> incrementCycle() async {
    if (!canShowNextButton) {
      throw Exception('Can only increment cycle during Production action');
    }

    if (_currentSession == null || _selectedItem == null) {
      throw Exception('No active session or selected item');
    }

    try {
      _currentSession = _currentSession!.copyWith(
        cycleCount: _currentSession!.cycleCount + _selectedItem!.qtyPerCycle,
      );

      await _saveSession();
      notifyListeners();

      if (kDebugMode) {
        print('Incremented cycle count to: ${_currentSession!.cycleCount}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error incrementing cycle: $e');
      }
      rethrow;
    }
  }

  /// Handle Job Complete action - immediately switch to counting
  Future<void> completeJob() async {
    try {
      // Stop current action and start Counting - NO POPUPS!
      await startAction(TimerActionType.counting);

      if (kDebugMode) {
        print('Job completed, started counting action immediately');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error completing job: $e');
      }
      rethrow;
    }
  }

  /// Handle shutdown - immediately switch to shutdown mode
  Future<void> shutdown({int? finishedQty}) async {
    try {
      // First start the shutdown action immediately - NO POPUPS!
      await startAction(TimerActionType.shutdown);

      // Update item with finished quantity if provided
      if (finishedQty != null && _selectedItem != null) {
        _selectedItem = _selectedItem!.copyWith(finishedQty: finishedQty);
        await _updateItemInFirestore();
      }

      if (kDebugMode) {
        print('Shutdown action started immediately');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error during shutdown: $e');
      }
      rethrow;
    }
  }

  /// End the current session completely
  Future<void> endShiftCompletely({int? finishedQty}) async {
    try {
      // Update item with finished quantity if provided
      if (finishedQty != null && _selectedItem != null) {
        _selectedItem = _selectedItem!.copyWith(finishedQty: finishedQty);
        await _updateItemInFirestore();
      }

      // End the session
      await endSession();

      if (kDebugMode) {
        print('Shift ended completely with finished qty: $finishedQty');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error ending shift: $e');
      }
      rethrow;
    }
  }

  /// End the current session
  Future<void> endSession() async {
    if (_currentSession == null) return;

    try {
      await _stopCurrentAction();

      _currentSession = _currentSession!.copyWith(
        endTime: DateTime.now(),
        isActive: false,
      );

      await _saveSession();

      // Clear current state
      _currentSession = null;
      _selectedItem = null;

      notifyListeners();

      if (kDebugMode) {
        print('Production session ended');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error ending session: $e');
      }
      rethrow;
    }
  }

  /// Get current action duration in seconds
  int getCurrentActionDuration() {
    if (_currentSession == null) return 0;

    final currentAction = _currentSession!.currentActiveAction;
    if (currentAction == null) return 0;

    final actionState = _currentSession!.actionStates[currentAction]!;
    if (!actionState.isActive || actionState.startTime == null) return 0;

    return DateTime.now().difference(actionState.startTime!).inSeconds;
  }

  /// Get total session time in seconds
  int getTotalSessionTime() {
    if (_currentSession == null) return 0;
    return _currentSession!.totalSessionTimeSeconds;
  }

  /// Get total time for specific action type
  int getActionTotalTime(TimerActionType actionType) {
    if (_currentSession == null) return 0;

    final actionState = _currentSession!.actionStates[actionType];
    if (actionState == null) return 0;

    if (actionState.isActive && actionState.startTime != null) {
      return DateTime.now().difference(actionState.startTime!).inSeconds;
    }

    return actionState.durationSeconds;
  }

  /// Format duration as HH:MM:SS
  static String formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final remainingSeconds = seconds % 60;

    return '${hours.toString().padLeft(2, '0')}:'
        '${minutes.toString().padLeft(2, '0')}:'
        '${remainingSeconds.toString().padLeft(2, '0')}';
  }

  /// Load available production items (convert from MES items)
  Future<List<ProductionItem>> loadAvailableItems() async {
    try {
      final querySnapshot = await _firestore
          .collection('mes_items')
          .where('isActive', isEqualTo: true)
          .get();

      return querySnapshot.docs.map((doc) {
        final mesItem = MESItem.fromFirestore(doc);
        return ProductionItem.fromMESItem(mesItem);
      }).toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error loading items: $e');
      }
      return [];
    }
  }

  /// Update production item quantities
  Future<void> updateItemQuantities({
    required int qtyPerCycle,
    required int finishedQty,
    int? targetQty,
  }) async {
    if (_selectedItem == null) {
      throw Exception('No item selected');
    }

    try {
      _selectedItem = _selectedItem!.copyWith(
        qtyPerCycle: qtyPerCycle,
        finishedQty: finishedQty,
        targetQty: targetQty,
      );

      await _updateItemInFirestore();
      notifyListeners();

      if (kDebugMode) {
        print(
            'Updated item quantities: qty/cycle=$qtyPerCycle, finished=$finishedQty');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error updating quantities: $e');
      }
      rethrow;
    }
  }

  /// Save session to Firestore
  Future<void> _saveSession() async {
    if (_currentSession == null) return;

    try {
      await _firestore
          .collection(_collectionName)
          .doc(_currentSession!.id)
          .set(_currentSession!.toMap());
    } catch (e) {
      if (kDebugMode) {
        print('Error saving session: $e');
      }
      rethrow;
    }
  }

  /// Update item in Firestore (as production_items collection)
  Future<void> _updateItemInFirestore() async {
    if (_selectedItem == null) return;

    try {
      await _firestore
          .collection('production_items')
          .doc(_selectedItem!.id)
          .set(_selectedItem!.toFirestore());
    } catch (e) {
      if (kDebugMode) {
        print('Error updating item in Firestore: $e');
      }
      rethrow;
    }
  }

  /// Load existing session if any
  Future<void> loadExistingSession(String userId) async {
    try {
      final querySnapshot = await _firestore
          .collection(_collectionName)
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        _currentSession = ProductionSession.fromMap(
          querySnapshot.docs.first.data(),
        );

        // Load associated item if session has one
        if (_currentSession!.itemId != null) {
          try {
            final itemDoc = await _firestore
                .collection('production_items')
                .doc(_currentSession!.itemId)
                .get();

            if (itemDoc.exists) {
              _selectedItem = ProductionItem.fromFirestore(itemDoc);
            }
          } catch (e) {
            if (kDebugMode) {
              print('Error loading associated item: $e');
            }
          }
        }

        notifyListeners();

        if (kDebugMode) {
          print('Loaded existing session: ${_currentSession!.id}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading existing session: $e');
      }
    }
  }
}
