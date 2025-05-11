import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_network/image_network.dart';

/// A widget that displays images across different platforms,
/// using ImageNetwork for web to handle CORS issues and regular Image widgets for other platforms.
class CrossPlatformImage extends StatelessWidget {
  final String? imageUrl;
  final double width;
  final double height;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;

  const CrossPlatformImage({
    super.key,
    required this.imageUrl,
    this.width = 200.0,
    this.height = 140.0,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
  });

  @override
  Widget build(BuildContext context) {
    // Make sure we have actual dimensions, especially for web
    final double actualWidth = width == double.infinity ? 300.0 : width;
    final double actualHeight = height == double.infinity ? 200.0 : height;

    // Default error widget if not provided
    final Widget defaultErrorWidget = Container(
      width: actualWidth,
      height: actualHeight,
      color: Colors.grey[200],
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.broken_image, size: 56, color: Colors.grey[400]),
          const SizedBox(height: 8),
          Text(
            "Image Error",
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          )
        ],
      ),
    );

    // Default placeholder widget if not provided
    final Widget defaultPlaceholder = Container(
      width: actualWidth,
      height: actualHeight,
      color: Colors.grey[200],
      child: Center(
        child: CircularProgressIndicator(
          strokeWidth: 3.0,
          color: Colors.red[700],
        ),
      ),
    );

    // If imageUrl is null, return error widget
    if (imageUrl == null) {
      return errorWidget ?? defaultErrorWidget;
    }

    // Handle different image types
    if (imageUrl!.startsWith('data:image/')) {
      // Data URL handling is the same across platforms
      try {
        final bytes = base64Decode(imageUrl!.split(',')[1]);
        return Image.memory(
          bytes,
          width: actualWidth,
          height: actualHeight,
          fit: fit,
          errorBuilder: (context, error, stackTrace) =>
              errorWidget ?? defaultErrorWidget,
        );
      } catch (e) {
        debugPrint('Error decoding data URL: $e');
        return errorWidget ?? defaultErrorWidget;
      }
    } else if (imageUrl!.startsWith('assets/')) {
      // Asset image handling is the same across platforms
      return Image.asset(
        imageUrl!,
        width: actualWidth,
        height: actualHeight,
        fit: fit,
        errorBuilder: (context, error, stackTrace) =>
            errorWidget ?? defaultErrorWidget,
      );
    } else {
      // Network image handling - use ImageNetwork for web
      if (kIsWeb) {
        return ImageNetwork(
          image: imageUrl!,
          height: actualHeight,
          width: actualWidth,
          duration: 1000,
          fitWeb: _mapBoxFitToWeb(fit),
          onLoading: placeholder ?? defaultPlaceholder,
          onError: errorWidget ?? defaultErrorWidget,
        );
      } else {
        // For mobile and other platforms, use regular Image.network
        return Image.network(
          imageUrl!,
          width: actualWidth,
          height: actualHeight,
          fit: fit,
          errorBuilder: (context, error, stackTrace) =>
              errorWidget ?? defaultErrorWidget,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return placeholder ?? defaultPlaceholder;
          },
        );
      }
    }
  }

  // Helper method to map BoxFit to BoxFitWeb
  BoxFitWeb _mapBoxFitToWeb(BoxFit fit) {
    switch (fit) {
      case BoxFit.contain:
        return BoxFitWeb.contain;
      case BoxFit.cover:
        return BoxFitWeb.cover;
      case BoxFit.fill:
        return BoxFitWeb.fill;
      case BoxFit.fitHeight:
        return BoxFitWeb.cover;
      case BoxFit.fitWidth:
        return BoxFitWeb.cover;
      case BoxFit.none:
        return BoxFitWeb.contain;
      case BoxFit.scaleDown:
        return BoxFitWeb.scaleDown;
      default:
        return BoxFitWeb.cover;
    }
  }
}
