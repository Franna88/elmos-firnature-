import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_network/image_network.dart';
import 'dart:ui' as ui;
import 'dart:typed_data';

/// A widget that displays images across different platforms,
/// using ImageNetwork for web to handle CORS issues and regular Image widgets for other platforms.
class CrossPlatformImage extends StatelessWidget {
  final String? imageUrl;
  final double width;
  final double height;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;
  final int? cacheWidth;
  final int? cacheHeight;

  // Static in-memory cache for images
  static final Map<String, Uint8List> _imageCache = {};

  const CrossPlatformImage({
    super.key,
    required this.imageUrl,
    this.width = 200.0,
    this.height = 140.0,
    this.fit = BoxFit.contain,
    this.placeholder,
    this.errorWidget,
    this.cacheWidth,
    this.cacheHeight,
  });

  @override
  Widget build(BuildContext context) {
    // Only apply default dimensions if no width/height provided
    final double actualWidth = width;
    final double actualHeight = height;

    // Use cacheWidth and cacheHeight if provided, otherwise calculate based on device pixel ratio
    // Handle infinity values gracefully
    final int? effectiveCacheWidth = cacheWidth ??
        (actualWidth.isInfinite
            ? null
            : (actualWidth * MediaQuery.of(context).devicePixelRatio).round());
    final int? effectiveCacheHeight = cacheHeight ??
        (actualHeight.isInfinite
            ? null
            : (actualHeight * MediaQuery.of(context).devicePixelRatio).round());

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
      try {
        final bytes = base64Decode(imageUrl!.split(',')[1]);
        return SizedBox(
          width: actualWidth,
          height: actualHeight,
          child: Image.memory(
            bytes,
            width: actualWidth,
            height: actualHeight,
            fit: fit,
            cacheWidth: effectiveCacheWidth,
            cacheHeight: effectiveCacheHeight,
            errorBuilder: (context, error, stackTrace) =>
                errorWidget ?? defaultErrorWidget,
          ),
        );
      } catch (e) {
        debugPrint('Error decoding data URL: $e');
        return errorWidget ?? defaultErrorWidget;
      }
    } else if (imageUrl!.startsWith('assets/')) {
      return SizedBox(
        width: actualWidth,
        height: actualHeight,
        child: Image.asset(
          imageUrl!,
          width: actualWidth,
          height: actualHeight,
          fit: fit,
          cacheWidth: effectiveCacheWidth,
          cacheHeight: effectiveCacheHeight,
          errorBuilder: (context, error, stackTrace) =>
              errorWidget ?? defaultErrorWidget,
        ),
      );
    } else {
      // Check if the image is already in our memory cache
      if (!kIsWeb && _imageCache.containsKey(imageUrl)) {
        return SizedBox(
          width: actualWidth,
          height: actualHeight,
          child: Image.memory(
            _imageCache[imageUrl]!,
            width: actualWidth,
            height: actualHeight,
            fit: fit,
            cacheWidth: effectiveCacheWidth,
            cacheHeight: effectiveCacheHeight,
            errorBuilder: (context, error, stackTrace) =>
                errorWidget ?? defaultErrorWidget,
          ),
        );
      }

      // Network image handling - use ImageNetwork for web
      if (kIsWeb) {
        return SizedBox(
          width: actualWidth,
          height: actualHeight,
          child: ImageNetwork(
            image: imageUrl!,
            height: actualHeight,
            width: actualWidth,
            duration: 1000,
            fitWeb: _mapBoxFitToWeb(fit),
            onLoading: placeholder ?? defaultPlaceholder,
            onError: errorWidget ?? defaultErrorWidget,
          ),
        );
      } else {
        return SizedBox(
          width: actualWidth,
          height: actualHeight,
          child: Image.network(
            imageUrl!,
            width: actualWidth,
            height: actualHeight,
            fit: fit,
            cacheWidth: effectiveCacheWidth,
            cacheHeight: effectiveCacheHeight,
            errorBuilder: (context, error, stackTrace) =>
                errorWidget ?? defaultErrorWidget,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;

              return Container(
                width: actualWidth,
                height: actualHeight,
                color: Colors.grey[200],
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded /
                                loadingProgress.expectedTotalBytes!
                            : null,
                        strokeWidth: 3.0,
                        color: Colors.red[700],
                      ),
                      if (loadingProgress.expectedTotalBytes != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          '${((loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!) * 100).toStringAsFixed(0)}%',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
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

  // Static method to add an image to the memory cache
  // This should be called by the preloading system
  static void addToCache(String url, Uint8List bytes) {
    _imageCache[url] = bytes;
  }

  // Clear the entire cache or a specific image
  static void clearCache([String? url]) {
    if (url != null) {
      _imageCache.remove(url);
    } else {
      _imageCache.clear();
    }
  }
}
