import 'package:flutter/foundation.dart';

/// Global debug control system to prevent DebugService overflow
/// This controls all debug output throughout the application
class DebugControl {
  // EMERGENCY SETTING: Set to false to disable ALL debug output
  static const bool _enableDebugOutput = true;
  
  // More granular controls
  static const bool _enableAuthDebug = true;
  static const bool _enableRouterDebug = true;
  static const bool _enableServiceDebug = true;
  static const bool _enableImageDebug = false;
  static const bool _enableTimerDebug = false;
  static const bool _enableMESDebug = false;
  
  /// Safe debug print that won't overwhelm the debug service
  static void debugLog(String message, {String? category}) {
    if (!_enableDebugOutput) return;
    
    // Category-specific filtering
    if (category != null) {
      switch (category.toLowerCase()) {
        case 'auth':
          if (!_enableAuthDebug) return;
          break;
        case 'router':
          if (!_enableRouterDebug) return;
          break;
        case 'service':
          if (!_enableServiceDebug) return;
          break;
        case 'image':
          if (!_enableImageDebug) return;
          break;
        case 'timer':
          if (!_enableTimerDebug) return;
          break;
        case 'mes':
          if (!_enableMESDebug) return;
          break;
      }
    }
    
    // Only print in debug mode and if enabled
    if (kDebugMode) {
      try {
        // Use a simple, safe print that won't cause serialization issues
        print(message);
      } catch (e) {
        // If even this fails, silently ignore to prevent cascade failures
      }
    }
  }
  
  /// Safe debug print for objects that might contain null values
  static void debugLogObject(String label, Object? object, {String? category}) {
    if (!_enableDebugOutput) return;
    
    try {
      final safeString = object?.toString() ?? 'null';
      debugLog('$label: $safeString', category: category);
    } catch (e) {
      debugLog('$label: [object serialization failed]', category: category);
    }
  }
  
  /// For critical errors that should always be shown
  static void errorLog(String message) {
    if (kDebugMode) {
      try {
        print('🚨 ERROR: $message');
      } catch (e) {
        // Even critical errors shouldn't break the app
      }
    }
  }
}

/// Convenience methods for common debug patterns
extension SafeDebugPrint on String {
  void debugLog({String? category}) => DebugControl.debugLog(this, category: category);
  void errorLog() => DebugControl.errorLog(this);
}
