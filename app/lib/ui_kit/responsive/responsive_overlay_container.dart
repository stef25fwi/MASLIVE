import 'package:flutter/widgets.dart';

import 'responsive_value.dart';

/// Keeps the compact overlay width derived from the current viewport, then
/// constrains the same overlay on tablet and desktop layouts.
class ResponsiveOverlayContainer extends StatelessWidget {
  const ResponsiveOverlayContainer({
    super.key,
    required this.child,
    this.compactHorizontalInset = 16,
    this.mediumMaxWidth = 560,
    this.expandedMaxWidth = 640,
    this.wideMaxWidth = 720,
    this.alignment = Alignment.center,
  });

  final Widget child;
  final double compactHorizontalInset;
  final double mediumMaxWidth;
  final double expandedMaxWidth;
  final double wideMaxWidth;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    final viewportWidth = MediaQuery.sizeOf(context).width;
    final compactMaxWidth = (viewportWidth - (compactHorizontalInset * 2))
        .clamp(0.0, double.infinity)
        .toDouble();
    final maxWidth = responsiveValue<double>(
      context,
      compact: compactMaxWidth,
      medium: mediumMaxWidth,
      expanded: expandedMaxWidth,
      wide: wideMaxWidth,
    );

    return Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
