import 'package:flutter/material.dart';

/// Bulle d'icone style MASLIVE (degrade + gloss + halo)
class MasliveBubbleIcon extends StatelessWidget {
  const MasliveBubbleIcon({
    super.key,
    required this.child,
    this.size = 64,
    this.onTap,
    this.paddingRatio = 0.22,
  });

  final Widget child;
  final double size;
  final VoidCallback? onTap;
  final double paddingRatio;

  @override
  Widget build(BuildContext context) {
    final pad = size * paddingRatio;

    final bubble = Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(pad),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFF7AAE),
            Color(0xFF9B6BFF),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF9B6BFF).withValues(alpha: 0.22),
            blurRadius: size * 0.45,
            spreadRadius: size * 0.05,
            offset: const Offset(0, 12),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: size * 0.20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          Center(
            child: IconTheme.merge(
              data: const IconThemeData(color: Colors.white),
              child: child,
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: ClipOval(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(-0.65, -0.75),
                      radius: 0.95,
                      colors: [
                        Colors.white.withAlpha((0.55 * 255).round()),
                        Colors.white.withAlpha((0.20 * 255).round()),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.35, 0.9],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: ClipOval(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withAlpha((0.14 * 255).round()),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: ClipOval(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                    color: Colors.white.withValues(alpha: 0.22),
                      width: size * 0.03,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return bubble;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: bubble,
      ),
    );
  }
}
