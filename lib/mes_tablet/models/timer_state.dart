enum TimerStatus {
  notStarted,
  running,
  paused,
  onBreak,
  maintenance,
  completed
}

class ProductionTimerState {
  final String itemId;
  TimerStatus status;
  
  // Timestamps for different states
  DateTime? runningStartTime; // When the current running period started
  DateTime? breakStartTime;   // When the current break started
  DateTime? maintenanceStartTime; // When the current maintenance started
  
  // Accumulated durations (in seconds)
  int totalProductionSeconds; // Total time in production (excluding pauses/breaks)
  int totalBreakSeconds;      // Total time on breaks
  int totalMaintenanceSeconds; // Total time on maintenance
  
  int itemsCompleted;
  
  ProductionTimerState({
    required this.itemId,
    this.status = TimerStatus.notStarted,
    this.runningStartTime,
    this.breakStartTime,
    this.maintenanceStartTime,
    this.totalProductionSeconds = 0,
    this.totalBreakSeconds = 0,
    this.totalMaintenanceSeconds = 0,
    this.itemsCompleted = 0,
  });

  // Start/resume production timer
  void startTimer() {
    if (status == TimerStatus.onBreak && breakStartTime != null) {
      // Coming back from break, add break time to total
      final breakDuration = DateTime.now().difference(breakStartTime!).inSeconds;
      totalBreakSeconds += breakDuration;
      breakStartTime = null;
    } else if (status == TimerStatus.maintenance && maintenanceStartTime != null) {
      // Coming back from maintenance, add maintenance time to total
      final maintenanceDuration = DateTime.now().difference(maintenanceStartTime!).inSeconds;
      totalMaintenanceSeconds += maintenanceDuration;
      maintenanceStartTime = null;
    }
    
    status = TimerStatus.running;
    runningStartTime = DateTime.now();
  }

  // Pause the production timer
  void pauseTimer() {
    if (status == TimerStatus.running && runningStartTime != null) {
      // Add current running time to total
      final runningDuration = DateTime.now().difference(runningStartTime!).inSeconds;
      totalProductionSeconds += runningDuration;
      runningStartTime = null;
      status = TimerStatus.paused;
    }
  }

  // Switch to break
  void startBreak() {
    if (status == TimerStatus.running && runningStartTime != null) {
      // Save current production time
      final runningDuration = DateTime.now().difference(runningStartTime!).inSeconds;
      totalProductionSeconds += runningDuration;
      runningStartTime = null;
    }
    
    status = TimerStatus.onBreak;
    breakStartTime = DateTime.now();
  }

  // Switch to maintenance
  void startMaintenance() {
    if (status == TimerStatus.running && runningStartTime != null) {
      // Save current production time
      final runningDuration = DateTime.now().difference(runningStartTime!).inSeconds;
      totalProductionSeconds += runningDuration;
      runningStartTime = null;
    }
    
    status = TimerStatus.maintenance;
    maintenanceStartTime = DateTime.now();
  }

  // Complete the current item
  void completeCurrentItem() {
    if (status == TimerStatus.running && runningStartTime != null) {
      // Add current running time to total
      final runningDuration = DateTime.now().difference(runningStartTime!).inSeconds;
      totalProductionSeconds += runningDuration;
    }
    
    itemsCompleted++;
    resetForNextItem();
  }

  // Reset the timer for a new item
  void resetForNextItem() {
    status = TimerStatus.notStarted;
    runningStartTime = null;
    // We don't reset break and maintenance times as they are cumulative
  }

  // Get current production time (including ongoing session)
  int getCurrentProductionSeconds() {
    int total = totalProductionSeconds;
    if (status == TimerStatus.running && runningStartTime != null) {
      total += DateTime.now().difference(runningStartTime!).inSeconds;
    }
    return total;
  }

  // Get current break time (including ongoing break)
  int getCurrentBreakSeconds() {
    int total = totalBreakSeconds;
    if (status == TimerStatus.onBreak && breakStartTime != null) {
      total += DateTime.now().difference(breakStartTime!).inSeconds;
    }
    return total;
  }

  // Get current maintenance time (including ongoing maintenance)
  int getCurrentMaintenanceSeconds() {
    int total = totalMaintenanceSeconds;
    if (status == TimerStatus.maintenance && maintenanceStartTime != null) {
      total += DateTime.now().difference(maintenanceStartTime!).inSeconds;
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