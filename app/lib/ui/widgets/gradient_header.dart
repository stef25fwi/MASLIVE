import 'dart:ui';

import 'package:flutter/material.dart';
import '../theme/maslive_theme.dart';

/// Bande header pastel avec arrondi bas + léger flou/overlay (glass).
class MasliveGradientHeader extends StatelessWidget {
  final Widget child;
  final double height;
  final EdgeInsetsGeometry padding;

  const MasliveGradientHeader({
    super.key,
    required this.child,
    this.height = 170,
    this.padding = const EdgeInsets.fromLTRB(
      MasliveTheme.s16,
      52,
      MasliveTheme.s16,
      MasliveTheme.s16,
    ),
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        bottomLeft: Radius.circular(MasliveTheme.rHeader),
        bottomRight: Radius.circular(MasliveTheme.rHeader),
      ),
      child: SizedBox(
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const DecoratedBox(
              decoration: BoxDecoration(gradient: MasliveTheme.headerGradient),
            ),
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
              child: Container(
                color: Colors.white.withOpacity(0.06),
              ),
            ),
            Padding(
              padding: padding,
              child: child,
            ),
          ],
        ),
      ),
    );
  }
}
