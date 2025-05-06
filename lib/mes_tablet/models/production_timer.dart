import 'dart:async';
import 'package:flutter/material.dart';

enum ProductionTimerMode {
  notStarted,
  running,
  paused,
  onBreak,
  maintenance,
  prep
}

// A specialized timer controller for production timing
class ProductionTimer {
  // Current timer state
  ProductionTimerMode _mode = ProductionTimerMode.notStarted;
  ProductionTimerMode get mode => _mode;

  // Accumulated times (in seconds)
  int _productionTime = 0;
  int _breakTime = 0;
  int _maintenanceTime = 0;
  int _prepTime = 0;
  
  // Timestamp trackers
  DateTime? _productionStartTime;
  DateTime? _breakStartTime;
  DateTime? _maintenanceStartTime;
  DateTime? _prepStartTime;
  
  // Completion counter
  int _completedCount = 0;
  int get completedCount => _completedCount;
  
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
    if (_mode == ProductionTimerMode.onBreak) {
      // Coming back from break - add break time to total
      if (_breakStartTime != null) {
        final breakDuration = DateTime.now().difference(_breakStartTime!).inSeconds;
        _breakTime += breakDuration;
        _breakStartTime = null;
      }
    } else if (_mode == ProductionTimerMode.maintenance) {
      // Coming back from maintenance - add maintenance time to total
      if (_maintenanceStartTime != null) {
        final maintenanceDuration = DateTime.now().difference(_maintenanceStartTime!).inSeconds;
        _maintenanceTime += maintenanceDuration;
        _maintenanceStartTime = null;
      }
    } else if (_mode == ProductionTimerMode.prep) {
      // Coming back from prep - add prep time to total
      if (_prepStartTime != null) {
        final prepDuration = DateTime.now().difference(_prepStartTime!).inSeconds;
        _prepTime += prepDuration;
        _prepStartTime = null;
      }
    }
    
    _mode = ProductionTimerMode.running;
    _productionStartTime = DateTime.now();
  }

  // Pause the production timer
  void pauseProduction() {
    if (_mode == ProductionTimerMode.running && _productionStartTime != null) {
      // Add current production time to total
      final duration = DateTime.now().difference(_productionStartTime!).inSeconds;
      _productionTime += duration;
      _productionStartTime = null;
    }
    
    _mode = ProductionTimerMode.paused;
  }

  // Start a break
  void startBreak() {
    if (_mode == ProductionTimerMode.running && _productionStartTime != null) {
      // Add current production time to total
      final duration = DateTime.now().difference(_productionStartTime!).inSeconds;
      _productionTime += duration;
      _productionStartTime = null;
    }
    
    _mode = ProductionTimerMode.onBreak;
    _breakStartTime = DateTime.now();
  }

  // Start maintenance
  void startMaintenance() {
    if (_mode == ProductionTimerMode.running && _productionStartTime != null) {
      // Add current production time to total
      final duration = DateTime.now().difference(_productionStartTime!).inSeconds;
      _productionTime += duration;
      _productionStartTime = null;
    }
    
    _mode = ProductionTimerMode.maintenance;
    _maintenanceStartTime = DateTime.now();
  }

  // Start prep time
  void startPrep() {
    if (_mode == ProductionTimerMode.running && _productionStartTime != null) {
      // Add current production time to total
      final duration = DateTime.now().difference(_productionStartTime!).inSeconds;
      _productionTime += duration;
      _productionStartTime = null;
    }
    
    _mode = ProductionTimerMode.prep;
    _prepStartTime = DateTime.now();
  }

  // Mark an item as completed
  void completeItem() {
    if (_mode == ProductionTimerMode.running && _productionStartTime != null) {
      // Add current production time to total
      final duration = DateTime.now().difference(_productionStartTime!).inSeconds;
      _productionTime += duration;
      _productionStartTime = null;
    }
    
    _completedCount++;
    
    // Reset production time but keep break and maintenance time
    _productionTime = 0;
    _mode = ProductionTimerMode.notStarted;
  }

  // Reset the timer for a new item
  void resetForNewItem() {
    _mode = ProductionTimerMode.notStarted;
    _productionStartTime = null;
    _productionTime = 0;
    // We don't reset break, maintenance, and prep times
  }

  // Get total production time in seconds
  int getProductionTime() {
    int total = _productionTime;
    if (_mode == ProductionTimerMode.running && _productionStartTime != null) {
      // Add current running time
      final duration = DateTime.now().difference(_productionStartTime!).inSeconds;
      total += duration;
    }
    return total;
  }

  // Get total break time in seconds
  int getBreakTime() {
    int total = _breakTime;
    if (_mode == ProductionTimerMode.onBreak && _breakStartTime != null) {
      // Add current break time
      final duration = DateTime.now().difference(_breakStartTime!).inSeconds;
      total += duration;
    }
    return total;
  }

  // Get total maintenance time in seconds
  int getMaintenanceTime() {
    int total = _maintenanceTime;
    if (_mode == ProductionTimerMode.maintenance && _maintenanceStartTime != null) {
      // Add current maintenance time
      final duration = DateTime.now().difference(_maintenanceStartTime!).inSeconds;
      total += duration;
    }
    return total;
  }

  // Get total prep time in seconds
  int getPrepTime() {
    int total = _prepTime;
    if (_mode == ProductionTimerMode.prep && _prepStartTime != null) {
      // Add current prep time
      final duration = DateTime.now().difference(_prepStartTime!).inSeconds;
      total += duration;
    }
    return total;
  }

  // Format seconds into HH:MM:SS
  static String formatTime(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final remainingSeconds = seconds % 60;
    
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }
} 