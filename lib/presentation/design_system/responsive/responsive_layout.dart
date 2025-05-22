import 'package:flutter/material.dart';

/// ResponsiveLayout provides utilities for creating responsive UIs.
/// It helps determine the current screen size and adapt layouts accordingly.
class ResponsiveLayout {
  // Breakpoints
  static const double mobileBreakpoint = 600;
  static const double tabletBreakpoint = 900;
  static const double desktopBreakpoint = 1200;
  static const double largeDesktopBreakpoint = 1440;

  /// Checks if the current screen size is mobile (< 600)
  static bool isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < mobileBreakpoint;
  }

  /// Checks if the current screen size is tablet (>= 600 && < 900)
  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= mobileBreakpoint && width < tabletBreakpoint;
  }

  /// Checks if the current screen size is desktop (>= 900)
  static bool isDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= tabletBreakpoint;
  }

  /// Checks if the current screen size is large desktop (>= 1200)
  static bool isLargeDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= desktopBreakpoint;
  }

  /// Checks if the current screen size is tablet or larger
  static bool isTabletOrDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= mobileBreakpoint;
  }

  /// Returns a value based on the current screen size
  static T getValueForScreenType<T>({
    required BuildContext context,
    required T mobile,
    T? tablet,
    T? desktop,
    T? largeDesktop,
  }) {
    final width = MediaQuery.of(context).size.width;

    // Large desktop value
    if (width >= largeDesktopBreakpoint && largeDesktop != null) {
      return largeDesktop;
    }

    // Desktop value
    if (width >= desktopBreakpoint && desktop != null) {
      return desktop;
    }

    // Tablet value
    if (width >= mobileBreakpoint && tablet != null) {
      return tablet;
    }

    // Mobile value (default)
    return mobile;
  }

  /// Returns a widget based on the current screen size
  static Widget buildResponsive({
    required BuildContext context,
    required Widget mobile,
    Widget? tablet,
    Widget? desktop,
    Widget? largeDesktop,
  }) {
    final width = MediaQuery.of(context).size.width;

    // Large desktop layout
    if (width >= largeDesktopBreakpoint && largeDesktop != null) {
      return largeDesktop;
    }

    // Desktop layout
    if (width >= desktopBreakpoint && desktop != null) {
      return desktop;
    }

    // Tablet layout
    if (width >= mobileBreakpoint && tablet != null) {
      return tablet;
    }

    // Mobile layout (default)
    return mobile;
  }
}
