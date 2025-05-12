import 'dart:async';
import 'package:flutter/material.dart';

enum ProductionTimerMode {
  notStarted,
  running,
  paused,
  interrupted,
}

// A specialized timer controller for production timing
class ProductionTimer {
  // Current timer state
  ProductionTimerMode _mode = ProductionTimerMode.notStarted;
  ProductionTimerMode get mode => _mode;

  // Accumulated times (in seconds)
  int _productionTime = 0;
  int _interruptionTime = 0;

  // Timestamp trackers
  DateTime? _productionStartTime;
  DateTime? _interruptionStartTime;

  // Completion counter
  int _completedCount = 0;
  int get completedCount => _completedCount;

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

  // Start or resume the production timer
  void startProduction() {
    if (_mode == ProductionTimerMode.interrupted) {
      // Coming back from interruption - add interruption time to total
      if (_interruptionStartTime != null) {
        final interruptionDuration =
            DateTime.now().difference(_interruptionStartTime!).inSeconds;
        _interruptionTime += interruptionDuration;
        _interruptionStartTime = null;
      }
    }

    _mode = ProductionTimerMode.running;
    _productionStartTime = DateTime.now();
    _productionStartCount++;
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

  // Mark an item as completed
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
    _productionTime = 0;
    _interruptionTime = 0;
    _productionStartCount = 0;
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
