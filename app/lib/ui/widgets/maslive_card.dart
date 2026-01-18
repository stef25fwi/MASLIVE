import 'package:flutter/material.dart';
import '../theme/maslive_theme.dart';

class MasliveCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final double radius;

  const MasliveCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(MasliveTheme.s16),
    this.margin,
    this.radius = 20,
  });

  @override
  Widget build(BuildContext context) {
    final box = Container(
      decoration: BoxDecoration(
        color: MasliveTheme.surface,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: MasliveTheme.cardShadow,
        border: Border.all(color: MasliveTheme.divider, width: 1),
      ),
      child: Padding(padding: padding, child: child),
    );

    if (margin == null) return box;
    return Padding(padding: margin!, child: box);
  }
}
