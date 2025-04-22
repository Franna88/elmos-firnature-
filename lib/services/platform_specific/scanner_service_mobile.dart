import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'scanner_service_interface.dart';

/// Mobile scanner implementation for Android devices
class MobileScannerService implements ScannerService {
  final ImagePicker _picker = ImagePicker();

  @override
  Future<String?> showQRScanner(BuildContext context) async {
    // Show a dialog to explain the process
    bool? proceed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('QR Code Scanner'),
          content: const Text('To scan a QR code:\n\n'
              '1. Tap "Take Photo"\n'
              '2. Point your camera at the QR code\n'
              '3. Take a photo of the QR code\n\n'
              'The app will then process the image and extract the QR code data.'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Take Photo'),
            ),
          ],
        );
      },
    );

    if (proceed != true) {
      return null;
    }

    try {
      // Open the camera to take a photo
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 90,
      );

      if (photo == null) {
        return null;
      }

      // In a real implementation, we would process the image to extract QR code data
      // For testing purposes, you can use a dialog to input the QR code data
      String? manualInput = await showDialog<String>(
        context: context,
        builder: (BuildContext context) {
          String input = '';

          return AlertDialog(
            title: const Text('Enter QR Code Data'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'For testing purposes, please enter the QR code data manually:',
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 12),
                TextField(
                  decoration: const InputDecoration(
                    hintText: 'QR Code data',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    input = value;
                  },
                ),
              ],
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(null),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(input),
                child: const Text('Submit'),
              ),
            ],
          );
        },
      );

      return manualInput;
    } catch (e) {
      // Show error message
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return null;
    }
  }

  @override
  bool isScanningAvailable() {
    return true;
  }
}
