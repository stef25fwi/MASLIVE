import 'package:flutter/material.dart';

/// Scrollbar avec effet glass (glassmorphism) sur le côté
class GlassScrollbar extends StatelessWidget {
  const GlassScrollbar({
    super.key,
    required this.child,
    this.controller,
    this.thumbVisibility = true,
    this.thickness = 8.0,
    this.radius = const Radius.circular(8),
    this.scrollbarOrientation = ScrollbarOrientation.right,
  });

  final Widget child;
  final ScrollController? controller;
  final bool thumbVisibility;
  final double thickness;
  final Radius radius;
  final ScrollbarOrientation scrollbarOrientation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Couleurs pour l'effet glass
    final thumbColor = isDark
        ? Colors.white.withValues(alpha: 0.25)
        : Colors.black.withValues(alpha: 0.15);

    final trackColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.05);

    return ScrollbarTheme(
      data: ScrollbarThemeData(
        thumbVisibility: WidgetStateProperty.all(thumbVisibility),
        thickness: WidgetStateProperty.all(thickness),
        radius: radius,
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.dragged)) {
            return thumbColor.withValues(alpha: thumbColor.a * 1.5);
          }
          if (states.contains(WidgetState.hovered)) {
            return thumbColor.withValues(alpha: thumbColor.a * 1.2);
          }
          return thumbColor;
        }),
        trackColor: WidgetStateProperty.all(trackColor),
        trackBorderColor: WidgetStateProperty.all(Colors.transparent),
        crossAxisMargin: 2.0,
        mainAxisMargin: 4.0,
        minThumbLength: 48.0,
      ),
      child: Scrollbar(
        controller: controller,
        scrollbarOrientation: scrollbarOrientation,
        child: child,
      ),
    );
  }
}
