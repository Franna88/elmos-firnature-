import 'package:flutter/material.dart';

/// A utility class for handling responsive breakpoints across different screen sizes.
class ResponsiveBreakpoints {
  final BuildContext context;

  const ResponsiveBreakpoints._(this.context);

  /// Creates a ResponsiveBreakpoints instance for the given context.
  static ResponsiveBreakpoints of(BuildContext context) {
    return ResponsiveBreakpoints._(context);
  }

  /// Screen width breakpoints
  static const double _smallScreenBreakpoint = 600.0;
  static const double _mediumScreenBreakpoint = 1024.0;

  /// Returns true if the current screen width is considered small (mobile).
  bool get isSmallScreen =>
      MediaQuery.of(context).size.width < _smallScreenBreakpoint;

  /// Returns true if the current screen width is considered medium (tablet).
  bool get isMediumScreen =>
      MediaQuery.of(context).size.width >= _smallScreenBreakpoint &&
      MediaQuery.of(context).size.width < _mediumScreenBreakpoint;

  /// Returns true if the current screen width is considered large (desktop).
  bool get isLargeScreen =>
      MediaQuery.of(context).size.width >= _mediumScreenBreakpoint;

  /// Returns the current screen width.
  double get screenWidth => MediaQuery.of(context).size.width;

  /// Returns the current screen height.
  double get screenHeight => MediaQuery.of(context).size.height;

  /// Returns a value based on the current screen size.
  ///
  /// Example usage:
  /// ```dart
  /// final padding = ResponsiveBreakpoints.of(context).value<double>(
  ///   small: 8.0,
  ///   medium: 16.0,
  ///   large: 24.0,
  /// );
  /// ```
  T value<T>({
    required T small,
    T? medium,
    required T large,
  }) {
    if (isSmallScreen) return small;
    if (isMediumScreen) return medium ?? large;
    return large;
  }
}
