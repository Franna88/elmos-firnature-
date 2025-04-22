import 'package:flutter/widgets.dart';

/// Interface for platform-specific scanner implementation
abstract class ScannerService {
  /// Shows a QR scanner UI and returns the scanned data
  Future<String?> showQRScanner(BuildContext context);

  /// Checks if scanning functionality is available on this platform
  bool isScanningAvailable();
}
