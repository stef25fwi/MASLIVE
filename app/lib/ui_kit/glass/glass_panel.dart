import 'dart:ui';

import 'package:flutter/material.dart';

import '../tokens/maslive_tokens.dart';

class GlassPanel extends StatelessWidget {
  final Widget child;
  final double blur;
  final double opacity;
  final double radius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;

  const GlassPanel({
    super.key,
    required this.child,
    this.blur = MasliveTokens.blurM,
    this.opacity = 0.75,
    this.radius = MasliveTokens.rL,
    this.padding,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    final content = ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: opacity.clamp(0.72, 0.80)),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              width: 1,
              color: Colors.white.withValues(alpha: 0.55),
            ),
            boxShadow: [
              BoxShadow(
                color: MasliveTokens.shadow,
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );

    if (margin == null) return content;
    return Padding(padding: margin!, child: content);
  }
}
