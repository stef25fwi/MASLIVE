import 'dart:ui';

import 'package:flutter/material.dart';
import '../theme/maslive_theme.dart';

/// Bande header pastel avec arrondi bas + léger flou/overlay (glass).
class MasliveGradientHeader extends StatelessWidget {
  final Widget child;
  final double height;
  final EdgeInsetsGeometry padding;
  final BorderRadius borderRadius;
  final Color? backgroundColor;

  const MasliveGradientHeader({
    super.key,
    required this.child,
    this.height = 60,
    this.padding = const EdgeInsets.fromLTRB(
      MasliveTheme.s16,
      6,
      MasliveTheme.s16,
      6,
    ),
    this.borderRadius = const BorderRadius.only(
      bottomLeft: Radius.circular(MasliveTheme.rHeader),
      bottomRight: Radius.circular(MasliveTheme.rHeader),
    ),
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final decoration = backgroundColor != null
        ? BoxDecoration(color: backgroundColor)
        : const BoxDecoration(gradient: MasliveTheme.headerGradient);

    return ClipRRect(
      borderRadius: borderRadius,
      child: SizedBox(
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            DecoratedBox(decoration: decoration),
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
              child: Container(color: Colors.white.withValues(alpha: 0.06)),
            ),
            Padding(padding: padding, child: child),
          ],
        ),
      ),
    );
  }
}
