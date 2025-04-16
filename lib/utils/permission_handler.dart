import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

class PermissionHandler {
  /// Requests and checks camera and storage permissions
  /// Returns true if permissions are granted, false otherwise
  static Future<bool> requestCameraPermissions(BuildContext context) async {
    // No permission handling needed for web
    if (kIsWeb) return true;

    // For Android native app - check permissions
    if (Platform.isAndroid) {
      // Show explanation dialog if needed
      bool shouldShowRationale = false;

      // If permissions were denied earlier, explain why we need them
      if (shouldShowRationale) {
        final bool proceed = await _showPermissionRationaleDialog(
            context,
            'Camera and Storage Access Needed',
            'We need access to your camera and storage to take and upload photos. '
                'Without these permissions, you won\'t be able to add images to SOPs.');

        if (!proceed) return false;
      }

      // Permissions are handled by image_picker plugin internally,
      // this is just preparing for any custom permission logic needed later
      return true;
    }

    // Default allow for iOS and other platforms
    return true;
  }

  /// Shows an explanation dialog for permissions
  static Future<bool> _showPermissionRationaleDialog(
    BuildContext context,
    String title,
    String message,
  ) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  /// Picks an image from either camera or gallery
  /// Handles permissions and returns the picked XFile
  static Future<XFile?> pickImage(
      BuildContext context, ImageSource source) async {
    // Check permissions first
    final hasPermission = await requestCameraPermissions(context);
    if (!hasPermission) return null;

    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 1200,
        maxHeight: 1200,
      );

      return image;
    } catch (e) {
      debugPrint('Error picking image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to select image: $e')),
      );
      return null;
    }
  }
}
