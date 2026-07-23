import 'package:flutter/widgets.dart';

import 'responsive_breakpoints.dart';
import 'responsive_value.dart';

/// Centers page content on large screens while preserving the exact compact
/// padding supplied by the caller.
class ResponsivePageContainer extends StatelessWidget {
  const ResponsivePageContainer({
    super.key,
    required this.child,
    this.compactPadding = EdgeInsets.zero,
    this.mediumPadding,
    this.expandedPadding,
    this.widePadding,
    this.maxContentWidth = 1280,
    this.alignment = Alignment.topCenter,
  });

  final Widget child;
  final EdgeInsetsGeometry compactPadding;
  final EdgeInsetsGeometry? mediumPadding;
  final EdgeInsetsGeometry? expandedPadding;
  final EdgeInsetsGeometry? widePadding;
  final double maxContentWidth;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    final padding = responsiveValue<EdgeInsetsGeometry>(
      context,
      compact: compactPadding,
      medium: mediumPadding,
      expanded: expandedPadding,
      wide: widePadding,
    );

    final constrainedChild = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxContentWidth),
      child: child,
    );

    if (context.isCompactLayout) {
      return Padding(padding: padding, child: constrainedChild);
    }

    return Align(
      alignment: alignment,
      child: Padding(padding: padding, child: constrainedChild),
    );
  }
}
