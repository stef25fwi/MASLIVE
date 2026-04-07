import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/maslive_theme.dart';

class MasliveFloatingGlassDock extends StatelessWidget {
  const MasliveFloatingGlassDock({
    super.key,
    required this.child,
    this.height = 84,
    this.padding = const EdgeInsets.fromLTRB(12, 12, 12, 12),
    this.borderRadius = const BorderRadius.all(Radius.circular(30)),
  });

  final Widget child;
  final double height;
  final EdgeInsetsGeometry padding;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: MasliveTheme.floatingShadow,
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.76),
                  Colors.white.withValues(alpha: 0.50),
                ],
              ),
              borderRadius: borderRadius,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.52),
                width: 1.15,
              ),
            ),
            child: SizedBox(
              height: height,
              child: Padding(padding: padding, child: child),
            ),
          ),
        ),
      ),
    );
  }
}