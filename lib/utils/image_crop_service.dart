import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;

/// Service class for handling image cropping functionality
/// Provides a unified interface for cropping images across different platforms
class ImageCropService {
  /// Crops an image for SOP step display with optimal aspect ratios
  /// Returns the cropped image file or null if user cancels
  static Future<CroppedFile?> cropImageForStepImage({
    required String imagePath,
    required BuildContext context,
  }) async {
    try {
      if (kDebugMode) {
        print('Starting image crop for SOP step image: $imagePath');
      }

      // For web, skip cropping and return original file for automatic optimization
      if (kIsWeb) {
        if (kDebugMode) {
          print('Web platform - skipping crop, using automatic optimization');
        }

        // Return original file - the existing optimization pipeline will handle sizing
        return CroppedFile(imagePath);
      }

      // For mobile platforms (Android/iOS), use full cropping functionality
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: imagePath,
        compressFormat: ImageCompressFormat.jpg,
        compressQuality: 90,
        uiSettings: [
          // Android-specific settings
          AndroidUiSettings(
            toolbarTitle: 'Crop SOP Image',
            toolbarColor: Colors.blue[700],
            toolbarWidgetColor: Colors.white,
            backgroundColor: Colors.white,
            activeControlsWidgetColor: Colors.blue[700],
            dimmedLayerColor: Colors.black.withValues(alpha: 0.5),
            cropGridColor: Colors.white.withValues(alpha: 0.8),
            cropFrameColor: Colors.blue[700],
            initAspectRatio: CropAspectRatioPreset.ratio16x9,
            lockAspectRatio: false,
            hideBottomControls: false,
            showCropGrid: true,
          ),

          // iOS-specific settings
          IOSUiSettings(
            title: 'Crop SOP Image',
            doneButtonTitle: 'Done',
            cancelButtonTitle: 'Cancel',
            minimumAspectRatio: 0.3,
            aspectRatioLockEnabled: false,
            resetAspectRatioEnabled: true,
            rotateButtonsHidden: false,
            rotateClockwiseButtonHidden: false,
          ),
        ],
      );

      if (croppedFile != null) {
        if (kDebugMode) {
          print('Image successfully cropped: ${croppedFile.path}');

          // Log file size information
          if (!kIsWeb) {
            final File file = File(croppedFile.path);
            final int fileSize = await file.length();
            print('Cropped image size: $fileSize bytes');
          }
        }
        return croppedFile;
      } else {
        if (kDebugMode) {
          print('Image cropping was cancelled by user');
        }
        return null;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error during image cropping: $e');
      }

      // Show error to user
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error cropping image: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }

      return null;
    }
  }

  /// Crops an image for SOP thumbnail with square aspect ratio preference
  /// Returns the cropped image file or null if user cancels
  static Future<CroppedFile?> cropImageForThumbnail({
    required String imagePath,
    required BuildContext context,
  }) async {
    try {
      if (kDebugMode) {
        print('Starting image crop for SOP thumbnail: $imagePath');
      }

      // For web, skip cropping and return original file for automatic optimization
      if (kIsWeb) {
        if (kDebugMode) {
          print(
              'Web platform - skipping thumbnail crop, using automatic optimization');
        }

        // Return original file - the existing optimization pipeline will handle sizing
        return CroppedFile(imagePath);
      }

      // For mobile platforms (Android/iOS), use full cropping functionality
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: imagePath,
        compressFormat: ImageCompressFormat.jpg,
        compressQuality: 85,
        uiSettings: [
          // Android-specific settings
          AndroidUiSettings(
            toolbarTitle: 'Crop Thumbnail',
            toolbarColor: Colors.green[700],
            toolbarWidgetColor: Colors.white,
            backgroundColor: Colors.white,
            activeControlsWidgetColor: Colors.green[700],
            dimmedLayerColor: Colors.black.withValues(alpha: 0.5),
            cropGridColor: Colors.white.withValues(alpha: 0.8),
            cropFrameColor: Colors.green[700],
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: false,
            hideBottomControls: false,
            showCropGrid: true,
          ),

          // iOS-specific settings
          IOSUiSettings(
            title: 'Crop Thumbnail',
            doneButtonTitle: 'Done',
            cancelButtonTitle: 'Cancel',
            minimumAspectRatio: 0.5,
            aspectRatioLockEnabled: false,
            resetAspectRatioEnabled: true,
            rotateButtonsHidden: false,
            rotateClockwiseButtonHidden: false,
          ),
        ],
      );

      if (croppedFile != null) {
        if (kDebugMode) {
          print('Thumbnail successfully cropped: ${croppedFile.path}');

          // Log file size information
          if (!kIsWeb) {
            final File file = File(croppedFile.path);
            final int fileSize = await file.length();
            print('Cropped thumbnail size: $fileSize bytes');
          }
        }
        return croppedFile;
      } else {
        if (kDebugMode) {
          print('Thumbnail cropping was cancelled by user');
        }
        return null;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error during thumbnail cropping: $e');
      }

      // Show error to user
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error cropping thumbnail: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }

      return null;
    }
  }

  /// Checks if image cropping is supported on the current platform
  static bool get isSupported {
    // Cropping is supported on mobile, web uses automatic optimization
    return true;
  }

  /// Gets information about recommended dimensions for SOP step images
  static String get stepImageInfo =>
      'Mobile: Interactive cropping available. Web: Automatic optimization applied.';

  /// Gets information about recommended dimensions for SOP thumbnails
  static String get thumbnailInfo =>
      'Mobile: Square cropping available. Web: Automatic optimization applied.';
}
