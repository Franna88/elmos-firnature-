import 'package:flutter/material.dart';
import 'scanner_service_interface.dart';

/// Web implementation of the scanner service
class WebScannerService implements ScannerService {
  @override
  Future<String?> showQRScanner(BuildContext context) async {
    // Show a dialog explaining that QR scanning is not available on web
    return showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('QR Scanning Unavailable'),
          content: const Text('QR scanning is not available on web platforms. '
              'Please use the mobile app to scan QR codes.'),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  @override
  bool isScanningAvailable() {
    return false;
  }
}
