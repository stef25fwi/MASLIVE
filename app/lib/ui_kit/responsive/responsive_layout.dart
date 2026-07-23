import 'package:flutter/widgets.dart';

import 'responsive_breakpoints.dart';

typedef ResponsiveWidgetBuilder = Widget Function(
  BuildContext context,
  BoxConstraints constraints,
);

/// Chooses a layout builder from the current window class without changing
/// compact rendering when larger builders are omitted.
class ResponsiveLayout extends StatelessWidget {
  const ResponsiveLayout({
    super.key,
    required this.compact,
    this.medium,
    this.expanded,
    this.wide,
  });

  final ResponsiveWidgetBuilder compact;
  final ResponsiveWidgetBuilder? medium;
  final ResponsiveWidgetBuilder? expanded;
  final ResponsiveWidgetBuilder? wide;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;

        if (MasliveBreakpoints.isWide(width)) {
          return (wide ?? expanded ?? medium ?? compact)(context, constraints);
        }
        if (MasliveBreakpoints.isExpanded(width)) {
          return (expanded ?? medium ?? compact)(context, constraints);
        }
        if (MasliveBreakpoints.isMedium(width)) {
          return (medium ?? compact)(context, constraints);
        }
        return compact(context, constraints);
      },
    );
  }
}
