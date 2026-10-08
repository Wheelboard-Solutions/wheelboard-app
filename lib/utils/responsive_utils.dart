import 'package:flutter/material.dart';

/// Responsive utility class for consistent responsive design
class ResponsiveUtils {
  /// Breakpoints for different screen sizes
  static const double mobileBreakpoint = 600;
  static const double tabletBreakpoint = 900;
  static const double desktopBreakpoint = 1200;

  /// Get responsive padding based on screen width
  static EdgeInsets getResponsivePadding(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width > desktopBreakpoint) {
      return const EdgeInsets.all(32);
    } else if (width > tabletBreakpoint) {
      return const EdgeInsets.all(24);
    } else {
      return const EdgeInsets.all(16);
    }
  }

  /// Get responsive horizontal padding
  static EdgeInsets getResponsiveHorizontalPadding(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width > desktopBreakpoint) {
      return const EdgeInsets.symmetric(horizontal: 32);
    } else if (width > tabletBreakpoint) {
      return const EdgeInsets.symmetric(horizontal: 24);
    } else {
      return const EdgeInsets.symmetric(horizontal: 16);
    }
  }

  /// Get responsive vertical padding
  static EdgeInsets getResponsiveVerticalPadding(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width > desktopBreakpoint) {
      return const EdgeInsets.symmetric(vertical: 24);
    } else if (width > tabletBreakpoint) {
      return const EdgeInsets.symmetric(vertical: 20);
    } else {
      return const EdgeInsets.symmetric(vertical: 16);
    }
  }

  /// Get responsive spacing
  static double getResponsiveSpacing(
    BuildContext context, {
    double? small,
    double? medium,
    double? large,
  }) {
    final width = MediaQuery.of(context).size.width;
    if (width > desktopBreakpoint) {
      return large ?? 24;
    } else if (width > tabletBreakpoint) {
      return medium ?? 20;
    } else {
      return small ?? 16;
    }
  }

  /// Get responsive font size
  static double getResponsiveFontSize(
    BuildContext context, {
    double? small,
    double? medium,
    double? large,
  }) {
    final width = MediaQuery.of(context).size.width;
    if (width > desktopBreakpoint) {
      return large ?? 18;
    } else if (width > tabletBreakpoint) {
      return medium ?? 16;
    } else {
      return small ?? 14;
    }
  }

  /// Get responsive icon size
  static double getResponsiveIconSize(
    BuildContext context, {
    double? small,
    double? medium,
    double? large,
  }) {
    final width = MediaQuery.of(context).size.width;
    if (width > desktopBreakpoint) {
      return large ?? 32;
    } else if (width > tabletBreakpoint) {
      return medium ?? 28;
    } else {
      return small ?? 24;
    }
  }

  /// Get responsive grid cross axis count
  static int getResponsiveGridCount(
    BuildContext context, {
    int? small,
    int? medium,
    int? large,
  }) {
    final width = MediaQuery.of(context).size.width;
    if (width > desktopBreakpoint) {
      return large ?? 4;
    } else if (width > tabletBreakpoint) {
      return medium ?? 3;
    } else {
      return small ?? 2;
    }
  }

  /// Check if screen is mobile
  static bool isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < mobileBreakpoint;
  }

  /// Check if screen is tablet
  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= mobileBreakpoint && width < desktopBreakpoint;
  }

  /// Check if screen is desktop
  static bool isDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= desktopBreakpoint;
  }

  /// Get responsive container constraints
  static BoxConstraints getResponsiveConstraints(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width > desktopBreakpoint) {
      return const BoxConstraints(maxWidth: 1200);
    } else if (width > tabletBreakpoint) {
      return const BoxConstraints(maxWidth: 800);
    } else {
      return const BoxConstraints(maxWidth: 600);
    }
  }

  /// Get responsive button height
  static double getResponsiveButtonHeight(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width > desktopBreakpoint) {
      return 56;
    } else if (width > tabletBreakpoint) {
      return 52;
    } else {
      return 48;
    }
  }

  /// Get responsive border radius
  static double getResponsiveBorderRadius(
    BuildContext context, {
    double? small,
    double? medium,
    double? large,
  }) {
    final width = MediaQuery.of(context).size.width;
    if (width > desktopBreakpoint) {
      return large ?? 16;
    } else if (width > tabletBreakpoint) {
      return medium ?? 14;
    } else {
      return small ?? 12;
    }
  }
}

/// Responsive widget that adapts its child based on screen size
class ResponsiveWidget extends StatelessWidget {
  final Widget mobile;
  final Widget? tablet;
  final Widget? desktop;

  const ResponsiveWidget({
    super.key,
    required this.mobile,
    this.tablet,
    this.desktop,
  });

  @override
  Widget build(BuildContext context) {
    if (ResponsiveUtils.isDesktop(context) && desktop != null) {
      return desktop!;
    } else if (ResponsiveUtils.isTablet(context) && tablet != null) {
      return tablet!;
    } else {
      return mobile;
    }
  }
}

/// Responsive grid widget
class ResponsiveGrid extends StatelessWidget {
  final List<Widget> children;
  final int? mobileColumns;
  final int? tabletColumns;
  final int? desktopColumns;
  final double spacing;
  final double runSpacing;

  const ResponsiveGrid({
    super.key,
    required this.children,
    this.mobileColumns,
    this.tabletColumns,
    this.desktopColumns,
    this.spacing = 16,
    this.runSpacing = 16,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        int crossAxisCount;
        if (ResponsiveUtils.isDesktop(context)) {
          crossAxisCount = desktopColumns ?? 4;
        } else if (ResponsiveUtils.isTablet(context)) {
          crossAxisCount = tabletColumns ?? 3;
        } else {
          crossAxisCount = mobileColumns ?? 2;
        }

        return GridView.builder(
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
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

/// Responsive text widget
class ResponsiveText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  const ResponsiveText(
    this.text, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: style,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}

/// Responsive spacing widget
class ResponsiveSpacing extends StatelessWidget {
  final double? small;
  final double? medium;
  final double? large;
  final bool isVertical;

  const ResponsiveSpacing({
    super.key,
    this.small,
    this.medium,
    this.large,
    this.isVertical = true,
  });

  @override
  Widget build(BuildContext context) {
    final spacing = ResponsiveUtils.getResponsiveSpacing(
      context,
      small: small,
      medium: medium,
      large: large,
    );

    if (isVertical) {
      return SizedBox(height: spacing);
    } else {
      return SizedBox(width: spacing);
    }
  }
}
