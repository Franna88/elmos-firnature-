import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_network/image_network.dart';

import 'dart:typed_data';

/// A widget that displays images across different platforms,
/// using ImageNetwork for web to handle CORS issues and regular Image widgets for other platforms.
class CrossPlatformImage extends StatelessWidget {
  final String? imageUrl;
  final double? width;
  final double? height;
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
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.placeholder,
    this.errorWidget,
    this.cacheWidth,
    this.cacheHeight,
  });

  @override
  Widget build(BuildContext context) {
    // Safely handle dimensions with validation
    final double actualWidth = _validateDimension(width, 200.0);
    final double actualHeight = _validateDimension(height, 140.0);

    // Safely get device pixel ratio with fallback
    final double devicePixelRatio = _safeGetDevicePixelRatio(context);

    // Use cacheWidth and cacheHeight if provided, otherwise calculate based on device pixel ratio
    // Handle infinity values gracefully and validate cache dimensions
    final int? effectiveCacheWidth = _calculateCacheDimension(
      cacheWidth, 
      actualWidth, 
      devicePixelRatio,
    );
    final int? effectiveCacheHeight = _calculateCacheDimension(
      cacheHeight, 
      actualHeight, 
      devicePixelRatio,
    );

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

    // If imageUrl is null or empty, return error widget
    if (imageUrl == null || imageUrl!.trim().isEmpty) {
      return errorWidget ?? defaultErrorWidget;
    }

    // Validate imageUrl to prevent engine errors
    final validatedImageUrl = _validateImageUrl(imageUrl!);
    if (validatedImageUrl == null) {
      debugPrint('Invalid image URL detected: $imageUrl');
      return errorWidget ?? defaultErrorWidget;
    }

    // Handle different image types
    if (validatedImageUrl.startsWith('data:image/')) {
      try {
        final bytes = base64Decode(validatedImageUrl.split(',')[1]);
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
    } else if (validatedImageUrl.startsWith('assets/')) {
      return SizedBox(
        width: actualWidth,
        height: actualHeight,
        child: Image.asset(
          validatedImageUrl,
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
      if (!kIsWeb && _imageCache.containsKey(validatedImageUrl)) {
        return SizedBox(
          width: actualWidth,
          height: actualHeight,
          child: Image.memory(
            _imageCache[validatedImageUrl]!,
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
            image: validatedImageUrl,
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
            validatedImageUrl,
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

  /// Validates and sanitizes dimension values to prevent engine errors
  double _validateDimension(double? dimension, double defaultValue) {
    if (dimension == null) return defaultValue;
    if (dimension.isNaN || dimension.isInfinite || dimension <= 0) {
      return defaultValue;
    }
    // Clamp to reasonable bounds to prevent memory issues
    return dimension.clamp(1.0, 4000.0);
  }

  /// Safely gets device pixel ratio with proper context validation
  double _safeGetDevicePixelRatio(BuildContext context) {
    try {
      final MediaQueryData? mediaQuery = MediaQuery.maybeOf(context);
      return mediaQuery?.devicePixelRatio ?? 1.0;
    } catch (e) {
      debugPrint('Warning: Could not access MediaQuery, using default pixel ratio: $e');
      return 1.0;
    }
  }

  /// Calculates cache dimensions safely, preventing null/invalid values from reaching the engine
  int? _calculateCacheDimension(
    int? providedCache,
    double actualDimension,
    double devicePixelRatio,
  ) {
    if (providedCache != null) {
      // Validate provided cache dimension
      if (providedCache <= 0 || providedCache > 8000) {
        return null; // Invalid cache dimension, let Flutter handle it
      }
      return providedCache;
    }

    // Calculate based on actual dimension and pixel ratio
    if (actualDimension.isInfinite || actualDimension.isNaN || actualDimension <= 0) {
      return null;
    }

    final calculatedCache = (actualDimension * devicePixelRatio).round();
    
    // Validate calculated cache dimension
    if (calculatedCache <= 0 || calculatedCache > 8000) {
      return null;
    }

    return calculatedCache;
  }

  /// Validates image URL to prevent engine errors
  String? _validateImageUrl(String url) {
    try {
      final trimmedUrl = url.trim();
      
      // Check for empty or null-like strings
      if (trimmedUrl.isEmpty || trimmedUrl == 'null' || trimmedUrl == 'undefined') {
        return null;
      }

      // Validate different URL types
      if (trimmedUrl.startsWith('data:image/')) {
        // Validate data URL format
        if (!trimmedUrl.contains(',') || trimmedUrl.split(',').length != 2) {
          return null;
        }
        return trimmedUrl;
      } else if (trimmedUrl.startsWith('assets/')) {
        // Validate asset path
        if (trimmedUrl.length < 8) { // assets/ + at least one character
          return null;
        }
        return trimmedUrl;
      } else if (trimmedUrl.startsWith('http://') || trimmedUrl.startsWith('https://')) {
        // Validate network URL
        try {
          final uri = Uri.parse(trimmedUrl);
          if (uri.host.isEmpty) {
            return null;
          }
          return trimmedUrl;
        } catch (e) {
          debugPrint('Invalid URL format: $trimmedUrl');
          return null;
        }
      } else {
        // Unknown URL format, might be relative path or invalid
        debugPrint('Unknown URL format: $trimmedUrl');
        return null;
      }
    } catch (e) {
      debugPrint('Error validating image URL: $e');
      return null;
    }
  }
}
