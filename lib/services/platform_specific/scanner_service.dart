import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;

import 'scanner_service_interface.dart';
import 'scanner_service_mobile.dart';
import 'scanner_service_ios.dart';
import 'scanner_service_web.dart';

/// Factory for creating the appropriate scanner service based on platform
class ScannerServiceFactory {
  /// Returns the appropriate scanner service implementation
  static ScannerService getScannerService() {
    if (kIsWeb) {
      return WebScannerService();
    }

    if (Platform.isIOS) {
      return IOSScannerService();
    }

    // For Android and other platforms
    return MobileScannerService();
  }
}
