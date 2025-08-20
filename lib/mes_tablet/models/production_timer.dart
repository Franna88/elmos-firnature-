import 'dart:async';
import 'package:flutter/material.dart';
import '../../data/models/mes_interruption_model.dart';

enum ProductionTimerMode {
  notStarted,
  setup,
  running,
  paused,
  interrupted,
}

// Model for tracking individual action instances during item production
class ActionRecord {
  final MESInterruptionType action;
  final DateTime startTime;
  final DateTime endTime;
  final int durationSeconds;

  ActionRecord({
    required this.action,
    required this.startTime,
    required this.endTime,
    required this.durationSeconds,
  });

  // Convert to map for storage
  Map<String, dynamic> toMap() {
    return {
      'actionId': action.id,
      'actionName': action.name,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
      'durationSeconds': durationSeconds,
    };
  }

  // Create from map (for loading from storage)
  factory ActionRecord.fromMap(
      Map<String, dynamic> map, MESInterruptionType action) {
    return ActionRecord(
      action: action,
      startTime: DateTime.parse(map['startTime']),
      endTime: DateTime.parse(map['endTime']),
      durationSeconds: map['durationSeconds'],
    );
  }
}

// Model for tracking individual item completion times
class ItemCompletionRecord {
  final int itemNumber;
  final DateTime startTime;
  final DateTime endTime;
  final int durationSeconds; // Pure production time (excludes action time)
  final int totalTimeSeconds; // Total time including actions
  final List<ActionRecord> actionRecords; // Actions performed during this item

  ItemCompletionRecord({
    required this.itemNumber,
    required this.startTime,
    required this.endTime,
    required this.durationSeconds,
    required this.totalTimeSeconds,
    required this.actionRecords,
  });

  // Get total time spent on actions for this item
  int get totalActionTime =>
      actionRecords.fold(0, (sum, action) => sum + action.durationSeconds);

  // Convert to map for storage
  Map<String, dynamic> toMap() {
    return {
      'itemNumber': itemNumber,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
      'durationSeconds': durationSeconds,
      'totalTimeSeconds': totalTimeSeconds,
      'actionRecords': actionRecords.map((action) => action.toMap()).toList(),
    };
  }

  // Create from map
  factory ItemCompletionRecord.fromMap(
      Map<String, dynamic> map, List<MESInterruptionType> availableActions) {
    final actionRecordsData = map['actionRecords'] as List<dynamic>? ?? [];
    final actionRecords = actionRecordsData.map((actionData) {
      final actionMap = actionData as Map<String, dynamic>;
      final actionId = actionMap['actionId'] as String;
      final action = availableActions.firstWhere(
        (a) => a.id == actionId,
        orElse: () => MESInterruptionType(
          id: actionId,
          name: actionMap['actionName'] ?? 'Unknown Action',
          color: null,
          isActive: false,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      return ActionRecord.fromMap(actionMap, action);
    }).toList();

    return ItemCompletionRecord(
      itemNumber: map['itemNumber'],
      startTime: DateTime.parse(map['startTime']),
      endTime: DateTime.parse(map['endTime']),
      durationSeconds: map['durationSeconds'],
      totalTimeSeconds: map['totalTimeSeconds'] ??
          map['durationSeconds'], // Fallback for backwards compatibility
      actionRecords: actionRecords,
    );
  }
}

// A specialized timer controller for production timing
class ProductionTimer {
  // Current timer state
  ProductionTimerMode _mode = ProductionTimerMode.notStarted;
  ProductionTimerMode get mode => _mode;

  // Accumulated times (in seconds)
  int _productionTime = 0;
  int _interruptionTime = 0;
  int _setupTime = 0;

  // Current item timing
  DateTime? _currentItemStartTime;
  int _currentItemProductionTime =
      0; // Accumulated production time for current item (excludes action time)

  // NEW: Dedicated Item Timer (only runs during production, excludes action time)
  DateTime?
      _currentItemTimerStartTime; // When item timer started (production mode only)
  int _currentItemTimerSeconds = 0; // Pure item production time

  // NEW: Action tracking for current item
  List<ActionRecord> _currentItemActionRecords =
      []; // Actions performed during current item

  // Timestamp trackers for overall session
  DateTime? _productionStartTime;
  DateTime? _interruptionStartTime;
  DateTime? _setupStartTime;

  // Action timer support
  MESInterruptionType? _currentAction;
  DateTime? _actionStartTime;
  int _actionTime = 0;

  MESInterruptionType? get currentAction => _currentAction;

  // NEW: Item timer getters - only runs during Production action
  bool get isItemTimerRunning =>
      _currentItemTimerStartTime != null &&
      _mode == ProductionTimerMode.running &&
      _currentAction != null &&
      _currentAction!.name.toLowerCase().contains('production');
  List<ActionRecord> get currentItemActionRecords =>
      List.unmodifiable(_currentItemActionRecords);

  // Completion counter and records
  int _completedCount = 0;
  int get completedCount => _completedCount;

  // List of completed items with their times
  List<ItemCompletionRecord> _completedItems = [];
  List<ItemCompletionRecord> get completedItems =>
      List.unmodifiable(_completedItems);

  // Track number of times production was started
  int _productionStartCount = 0;
  int get productionStartCount => _productionStartCount;

  // Callback for UI updates
  final VoidCallback? onTick;
  Timer? _timer;

  // Constructor
  ProductionTimer({this.onTick}) {
    // Create a timer that ticks every second for updating the UI
    _timer = Timer.periodic(const Duration(seconds: 1), _tick);
  }

  // Timer tick handler - calls the update callback
  void _tick(Timer timer) {
    if (onTick != null) {
      onTick!();
    }
  }

  // Clean up resources
  void dispose() {
    _timer?.cancel();
  }

  // Start the main production timer
  void startProduction() {
    final now = DateTime.now();

    if (_mode == ProductionTimerMode.interrupted) {
      // Coming back from interruption - add interruption time to total
      if (_interruptionStartTime != null) {
        final interruptionDuration =
            now.difference(_interruptionStartTime!).inSeconds;
        _interruptionTime += interruptionDuration;
        _interruptionStartTime = null;
      }
    }

    _mode = ProductionTimerMode.running;
    _productionStartTime = now;

    // Start the first item timer if this is the first time starting
    if (_currentItemStartTime == null) {
      _currentItemStartTime = now;
      _currentItemProductionTime =
          0; // Initialize production time for first item
    }

    // NEW: Start item timer (only runs during production, not during actions)
    if (_currentAction == null) {
      _currentItemTimerStartTime = now;
    }

    _productionStartCount++;
  }

  // Start setup mode
  void startSetup() {
    _mode = ProductionTimerMode.setup;
    _setupStartTime = DateTime.now();
  }

  // Complete setup and transition to production
  void completeSetup() {
    if (_mode == ProductionTimerMode.setup && _setupStartTime != null) {
      // Add setup time to total
      final setupDuration =
          DateTime.now().difference(_setupStartTime!).inSeconds;
      _setupTime += setupDuration;
      _setupStartTime = null;
    }

    // Transition to production mode
    startProduction();
  }

  // Get current setup time (including ongoing session)
  int getSetupTime() {
    int total = _setupTime;

    if (_mode == ProductionTimerMode.setup && _setupStartTime != null) {
      final currentDuration =
          DateTime.now().difference(_setupStartTime!).inSeconds;
      total += currentDuration;
    }

    return total;
  }

  // Start or switch to an action
  void startAction(MESInterruptionType action) {
    final now = DateTime.now();

    // Save current production time if we're switching from production to action
    if (_currentAction == null &&
        _mode == ProductionTimerMode.running &&
        _productionStartTime != null) {
      // Pause production timer - save accumulated production time
      final productionDuration =
          now.difference(_productionStartTime!).inSeconds;
      _productionTime += productionDuration;
      _currentItemProductionTime +=
          productionDuration; // Also add to current item production time
      _productionStartTime = null;
    }

    // NEW: Handle item timer based on action type
    if (_currentAction == null && _currentItemTimerStartTime != null) {
      // We're switching from no action to an action
      final itemTimerDuration =
          now.difference(_currentItemTimerStartTime!).inSeconds;
      _currentItemTimerSeconds += itemTimerDuration;
      _currentItemTimerStartTime = null; // Pause item timer initially
    }

    // Save current action time if switching between actions
    if (_currentAction != null && _actionStartTime != null) {
      final actionDuration = now.difference(_actionStartTime!).inSeconds;
      _actionTime += actionDuration;

      // NEW: Record the completed action for current item
      _currentItemActionRecords.add(ActionRecord(
        action: _currentAction!,
        startTime: _actionStartTime!,
        endTime: now,
        durationSeconds: actionDuration,
      ));
    }

    // Item production timer pauses during actions - only action timer runs

    // Start new action
    _currentAction = action;
    _actionStartTime = now;
    _actionTime = 0; // Reset for new action

    // NEW: If this is Production action, start item timer
    if (action.name.toLowerCase().contains('production')) {
      _currentItemTimerStartTime = now;
    }
  }

  // Stop current action
  void stopAction() {
    final now = DateTime.now();

    if (_currentAction != null && _actionStartTime != null) {
      final actionDuration = now.difference(_actionStartTime!).inSeconds;
      _actionTime += actionDuration;

      // NEW: Record the completed action for current item
      _currentItemActionRecords.add(ActionRecord(
        action: _currentAction!,
        startTime: _actionStartTime!,
        endTime: now,
        durationSeconds: actionDuration,
      ));
    }

    _currentAction = null;
    _actionStartTime = null;
    _actionTime = 0;

    // Resume production timer if we're still in running mode
    if (_mode == ProductionTimerMode.running) {
      _productionStartTime = now; // Resume production time tracking

      // NEW: Resume item timer when returning to production
      _currentItemTimerStartTime = now;
    }
  }

  // Get current action time including ongoing time
  // When no action is selected, this shows production time
  int getActionTime() {
    if (_currentAction == null) {
      // No action selected - show production time
      return getProductionTime();
    }

    // Action is selected - show action time
    int total = _actionTime;
    if (_actionStartTime != null) {
      final duration = DateTime.now().difference(_actionStartTime!).inSeconds;
      total += duration;
    }
    return total;
  }

  // Get color based on current action
  Color getActionColor() {
    if (_currentAction == null) {
      // Default production color (green)
      return const Color(0xFF4CAF50);
    }

    // Use the color defined in the MES Desktop Setup
    if (_currentAction!.color != null && _currentAction!.color!.isNotEmpty) {
      try {
        String colorHex = _currentAction!.color!.replaceAll('#', '');
        if (colorHex.length == 6) {
          colorHex = 'FF$colorHex'; // Add alpha channel
        }
        return Color(int.parse(colorHex, radix: 16));
      } catch (e) {
        // Fall back to default if color parsing fails
        return const Color(0xFF2C2C2C);
      }
    }

    // Fallback to name-based colors if no color is set
    final actionName = _currentAction!.name.toLowerCase();

    if (actionName.contains('break')) {
      return const Color(0xFF795548); // Brown
    } else if (actionName.contains('maintenance')) {
      return const Color(0xFFFF9800); // Orange
    } else if (actionName.contains('prep')) {
      return const Color(0xFF2196F3); // Blue
    } else if (actionName.contains('material')) {
      return const Color(0xFF4CAF50); // Green
    } else if (actionName.contains('training')) {
      return const Color(0xFF9C27B0); // Purple
    } else {
      return const Color(0xFF2C2C2C); // Default dark
    }
  }

  // Pause the production timer
  void pauseProduction() {
    if (_mode == ProductionTimerMode.running && _productionStartTime != null) {
      // Add current production time to total
      final duration =
          DateTime.now().difference(_productionStartTime!).inSeconds;
      _productionTime += duration;
      _productionStartTime = null;
    }

    _mode = ProductionTimerMode.paused;
  }

  // Start an interruption
  void startInterruption() {
    if (_mode == ProductionTimerMode.running && _productionStartTime != null) {
      // Add current production time to total
      final duration =
          DateTime.now().difference(_productionStartTime!).inSeconds;
      _productionTime += duration;
      _productionStartTime = null;
    }

    _mode = ProductionTimerMode.interrupted;
    _interruptionStartTime = DateTime.now();
  }

  // Complete current item and increment count (for "Next" functionality)
  void completeCurrentItem() {
    if (_currentItemStartTime != null) {
      final now = DateTime.now();

      // Save any ongoing production time for current item
      if (_currentAction == null &&
          _mode == ProductionTimerMode.running &&
          _productionStartTime != null) {
        final currentSessionTime =
            now.difference(_productionStartTime!).inSeconds;
        _currentItemProductionTime += currentSessionTime;
      }

      // NEW: Save any ongoing item timer time
      if (_currentItemTimerStartTime != null && _currentAction == null) {
        final itemTimerSessionTime =
            now.difference(_currentItemTimerStartTime!).inSeconds;
        _currentItemTimerSeconds += itemTimerSessionTime;
      }

      // NEW: Save any ongoing action
      if (_currentAction != null && _actionStartTime != null) {
        final actionDuration = now.difference(_actionStartTime!).inSeconds;
        _currentItemActionRecords.add(ActionRecord(
          action: _currentAction!,
          startTime: _actionStartTime!,
          endTime: now,
          durationSeconds: actionDuration,
        ));
      }

      // Use item timer for pure production time
      final itemProductionTime = _currentItemTimerSeconds;

      // Calculate total time including actions
      final totalActionTime = _currentItemActionRecords.fold(
          0, (sum, action) => sum + action.durationSeconds);
      final totalItemTime = itemProductionTime + totalActionTime;

      // Create completion record with detailed timing
      final record = ItemCompletionRecord(
        itemNumber: _completedCount + 1,
        startTime: _currentItemStartTime!,
        endTime: now,
        durationSeconds: itemProductionTime, // Pure production time
        totalTimeSeconds: totalItemTime, // Total time including actions
        actionRecords:
            List.from(_currentItemActionRecords), // Copy action records
      );

      _completedItems.add(record);
      _completedCount++;

      // Reset for next item
      _currentItemStartTime = now;
      _currentItemProductionTime = 0; // Reset production time for new item

      // NEW: Reset item timer for new item
      _currentItemTimerSeconds = 0;
      _currentItemActionRecords.clear(); // Clear action records for new item

      // If we're currently in production mode (not in action), reset timers
      if (_currentAction == null && _mode == ProductionTimerMode.running) {
        _productionStartTime = now;
        _currentItemTimerStartTime = now; // Start item timer for new item
      } else {
        _currentItemTimerStartTime =
            null; // Don't start item timer if in action mode
      }
    } else {
      _completedCount++;
    }
  }

  // End shift - stop all timers and save final state
  void endShift() {
    // Save any ongoing production time
    if (_mode == ProductionTimerMode.running && _productionStartTime != null) {
      final duration =
          DateTime.now().difference(_productionStartTime!).inSeconds;
      _productionTime += duration;
      _productionStartTime = null;
    }

    // Save any ongoing action time
    if (_currentAction != null && _actionStartTime != null) {
      final actionDuration =
          DateTime.now().difference(_actionStartTime!).inSeconds;
      _actionTime += actionDuration;
    }

    // Stop all timers
    _mode = ProductionTimerMode.paused;
    _currentAction = null;
    _actionStartTime = null;
    _actionTime = 0;
  }

  // Mark an item as completed (original complete functionality)
  void completeItem() {
    if (_mode == ProductionTimerMode.running && _productionStartTime != null) {
      // Add current production time to total
      final duration =
          DateTime.now().difference(_productionStartTime!).inSeconds;
      _productionTime += duration;
      _productionStartTime = null;
    }

    _completedCount++;

    // Reset the timer but maintain accumulated times for reporting
    _mode = ProductionTimerMode.notStarted;
  }

  // Reset the timer for a new item
  void resetForNewItem() {
    _mode = ProductionTimerMode.notStarted;
    _productionStartTime = null;
    _interruptionStartTime = null;
    _setupStartTime = null;
    _productionTime = 0;
    _interruptionTime = 0;
    _setupTime = 0;
    _productionStartCount = 0;
    _currentAction = null; // Clear current action
    _actionStartTime = null; // Clear action start time
    _actionTime = 0; // Reset action time
    _currentItemStartTime = null; // Clear item start time
    _currentItemProductionTime = 0; // Reset item production time
    _currentItemTimerStartTime = null; // Clear item timer start time
    _currentItemTimerSeconds = 0; // Reset item timer seconds
    _currentItemActionRecords.clear(); // Clear action records
    _completedCount = 0; // Reset completed items counter
    _completedItems.clear(); // Clear completed items list
  }

  // Get total production time in seconds
  int getProductionTime() {
    int total = _productionTime;
    if (_mode == ProductionTimerMode.running && _productionStartTime != null) {
      // Add current running time
      final duration =
          DateTime.now().difference(_productionStartTime!).inSeconds;
      total += duration;
    }
    return total;
  }

  // Get total interruption time in seconds
  int getTotalInterruptionTime() {
    int total = _interruptionTime;
    if (_mode == ProductionTimerMode.interrupted &&
        _interruptionStartTime != null) {
      // Add current interruption time
      final duration =
          DateTime.now().difference(_interruptionStartTime!).inSeconds;
      total += duration;
    }
    return total;
  }

  // Get total time (production + interruption)
  int getTotalTime() {
    return getProductionTime() + getTotalInterruptionTime();
  }

  // Get current item production time in seconds (excludes action time)
  int getCurrentItemTime() {
    if (_currentItemStartTime == null) return 0;

    // Return accumulated production time plus current session if actively producing
    int totalItemTime = _currentItemProductionTime;

    // Add current production session time if actively producing (not in action)
    if (_currentAction == null &&
        _mode == ProductionTimerMode.running &&
        _productionStartTime != null) {
      final currentSessionTime =
          DateTime.now().difference(_productionStartTime!).inSeconds;
      totalItemTime += currentSessionTime;
    }

    return totalItemTime;
  }

  // NEW: Get current item timer time (pure production time, excludes actions)
  int getCurrentItemTimerTime() {
    int totalItemTimerTime = _currentItemTimerSeconds;

    // Add current item timer session if running
    if (_currentItemTimerStartTime != null &&
        _mode == ProductionTimerMode.running &&
        _currentAction == null) {
      final currentSessionTime =
          DateTime.now().difference(_currentItemTimerStartTime!).inSeconds;
      totalItemTimerTime += currentSessionTime;
    }

    return totalItemTimerTime;
  }

  // Get average time per completed item in seconds
  double getAverageItemTime() {
    if (_completedItems.isEmpty) return 0.0;

    int totalTime =
        _completedItems.fold(0, (sum, item) => sum + item.durationSeconds);
    if (_completedItems.length == 0) return 0.0;

    final average = totalTime / _completedItems.length;
    return average.isFinite ? average : 0.0;
  }

  // Get fastest completed item time in seconds
  int getFastestItemTime() {
    if (_completedItems.isEmpty) return 0;
    return _completedItems
        .map((item) => item.durationSeconds)
        .reduce((a, b) => a < b ? a : b);
  }

  // Get slowest completed item time in seconds
  int getSlowestItemTime() {
    if (_completedItems.isEmpty) return 0;
    return _completedItems
        .map((item) => item.durationSeconds)
        .reduce((a, b) => a > b ? a : b);
  }

  // Get the duration of the current interruption in seconds
  int getCurrentInterruptionDuration() {
    if (_mode == ProductionTimerMode.interrupted &&
        _interruptionStartTime != null) {
      return DateTime.now().difference(_interruptionStartTime!).inSeconds;
    }
    return 0;
  }

  // Format seconds as HH:MM:SS
  static String formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final remainingSeconds = seconds % 60;

    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  // Get estimated completion percentage based on estimated time
  double getCompletionPercentage(int estimatedTimeInMinutes) {
    final estimatedTimeInSeconds = estimatedTimeInMinutes * 60;
    final currentTime = getProductionTime();

    if (estimatedTimeInSeconds <= 0) return 0.0;

    final percentage = (currentTime / estimatedTimeInSeconds) * 100;

    // Cap at 100%
    return percentage > 100 ? 100 : percentage;
  }
}
