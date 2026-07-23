import 'package:flutter/widgets.dart';

/// Shared responsive breakpoints for MASLIVE.
///
/// The compact range deliberately preserves the current smartphone rendering.
abstract final class MasliveBreakpoints {
  static const double compactMax = 599;
  static const double mediumMin = 600;
  static const double expandedMin = 1024;
  static const double wideMin = 1440;

  static bool isCompact(double width) => width <= compactMax;
  static bool isMedium(double width) =>
      width >= mediumMin && width < expandedMin;
  static bool isExpanded(double width) =>
      width >= expandedMin && width < wideMin;
  static bool isWide(double width) => width >= wideMin;
}

enum MasliveWindowClass { compact, medium, expanded, wide }

extension MasliveResponsiveContext on BuildContext {
  double get viewportWidth => MediaQuery.sizeOf(this).width;

  MasliveWindowClass get windowClass {
    final width = viewportWidth;
    if (MasliveBreakpoints.isCompact(width)) {
      return MasliveWindowClass.compact;
    }
    if (MasliveBreakpoints.isMedium(width)) {
      return MasliveWindowClass.medium;
    }
    if (MasliveBreakpoints.isExpanded(width)) {
      return MasliveWindowClass.expanded;
    }
    return MasliveWindowClass.wide;
  }

  bool get isCompactLayout => windowClass == MasliveWindowClass.compact;
  bool get isMediumLayout => windowClass == MasliveWindowClass.medium;
  bool get isExpandedLayout => windowClass == MasliveWindowClass.expanded;
  bool get isWideLayout => windowClass == MasliveWindowClass.wide;
}
