import 'package:flutter/material.dart';

/// Breakpoints for responsive design
class AppBreakpoints {
  static const double mobile = 600;
  static const double tablet = 960;
  static const double desktop = 1280;
  static const double largeDesktop = 1920;
}

/// Screen size categories
enum ScreenSize {
  mobile,
  tablet,
  desktop,
  largeDesktop,
}

/// ResponsiveLayout provides utilities for creating responsive UIs.
/// It helps determine the current screen size and conditionally render widgets.
class ResponsiveLayout extends StatelessWidget {
  final Widget mobile;
  final Widget? tablet;
  final Widget? desktop;
  final Widget? largeDesktop;

  const ResponsiveLayout({
    Key? key,
    required this.mobile,
    this.tablet,
    this.desktop,
    this.largeDesktop,
  }) : super(key: key);

  /// Get the current screen size category
  static ScreenSize getScreenSize(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    if (width >= AppBreakpoints.largeDesktop) {
      return ScreenSize.largeDesktop;
    } else if (width >= AppBreakpoints.desktop) {
      return ScreenSize.desktop;
    } else if (width >= AppBreakpoints.tablet) {
      return ScreenSize.tablet;
    } else {
      return ScreenSize.mobile;
    }
  }

  /// Check if the current screen is mobile
  static bool isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < AppBreakpoints.tablet;
  }

  /// Check if the current screen is tablet
  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= AppBreakpoints.tablet && width < AppBreakpoints.desktop;
  }

  /// Check if the current screen is desktop
  static bool isDesktop(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= AppBreakpoints.desktop &&
        width < AppBreakpoints.largeDesktop;
  }

  /// Check if the current screen is large desktop
  static bool isLargeDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= AppBreakpoints.largeDesktop;
  }

  /// Check if the current screen is mobile or tablet
  static bool isMobileOrTablet(BuildContext context) {
    return MediaQuery.of(context).size.width < AppBreakpoints.desktop;
  }

  /// Check if the current screen is tablet or desktop
  static bool isTabletOrDesktop(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= AppBreakpoints.tablet;
  }

  /// Get the number of columns to use in a grid based on screen size
  static int getGridColumnCount(BuildContext context) {
    final screenSize = getScreenSize(context);

    switch (screenSize) {
      case ScreenSize.mobile:
        return 1;
      case ScreenSize.tablet:
        return 2;
      case ScreenSize.desktop:
        return 3;
      case ScreenSize.largeDesktop:
        return 4;
    }
  }

  /// Get appropriate padding based on screen size
  static EdgeInsets getScreenPadding(BuildContext context) {
    final screenSize = getScreenSize(context);

    switch (screenSize) {
      case ScreenSize.mobile:
        return const EdgeInsets.symmetric(horizontal: 16, vertical: 16);
      case ScreenSize.tablet:
        return const EdgeInsets.symmetric(horizontal: 24, vertical: 24);
      case ScreenSize.desktop:
      case ScreenSize.largeDesktop:
        return const EdgeInsets.symmetric(horizontal: 32, vertical: 32);
    }
  }

  /// Get appropriate spacing based on screen size
  static double getSpacing(BuildContext context) {
    final screenSize = getScreenSize(context);

    switch (screenSize) {
      case ScreenSize.mobile:
        return 8.0;
      case ScreenSize.tablet:
        return 12.0;
      case ScreenSize.desktop:
        return 16.0;
      case ScreenSize.largeDesktop:
        return 24.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = getScreenSize(context);

    switch (screenSize) {
      case ScreenSize.largeDesktop:
        return largeDesktop ?? desktop ?? tablet ?? mobile;
      case ScreenSize.desktop:
        return desktop ?? tablet ?? mobile;
      case ScreenSize.tablet:
        return tablet ?? mobile;
      case ScreenSize.mobile:
        return mobile;
    }
  }
}

/// A builder widget that provides the current screen size to its builder function
class ResponsiveBuilder extends StatelessWidget {
  final Widget Function(BuildContext context, ScreenSize screenSize) builder;

  const ResponsiveBuilder({
    Key? key,
    required this.builder,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final screenSize = ResponsiveLayout.getScreenSize(context);
    return builder(context, screenSize);
  }
}

/// A grid that adapts its column count based on screen size
class ResponsiveGrid extends StatelessWidget {
  final List<Widget> children;
  final double spacing;
  final double runSpacing;
  final int? mobileColumns;
  final int? tabletColumns;
  final int? desktopColumns;
  final int? largeDesktopColumns;

  const ResponsiveGrid({
    Key? key,
    required this.children,
    this.spacing = 16,
    this.runSpacing = 16,
    this.mobileColumns,
    this.tabletColumns,
    this.desktopColumns,
    this.largeDesktopColumns,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        int columns;

        if (width >= AppBreakpoints.largeDesktop) {
          columns = largeDesktopColumns ?? 4;
        } else if (width >= AppBreakpoints.desktop) {
          columns = desktopColumns ?? 3;
        } else if (width >= AppBreakpoints.tablet) {
          columns = tabletColumns ?? 2;
        } else {
          columns = mobileColumns ?? 1;
        }

        return GridView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: spacing,
            mainAxisSpacing: runSpacing,
            childAspectRatio: 1,
          ),
          itemCount: children.length,
          itemBuilder: (context, index) => children[index],
        );
      },
    );
  }
}
