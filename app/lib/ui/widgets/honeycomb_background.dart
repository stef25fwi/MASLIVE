import 'package:flutter/material.dart';

/// Fond "glass" blanc avec motif nid d'abeille subtil par-dessus.
///
/// Utilise l'asset: `assets/textures/maslive_honeycomb_2048.png`.
class HoneycombBackground extends StatelessWidget {
  final Widget child;
  final double opacity;
  final EdgeInsetsGeometry padding;

  const HoneycombBackground({
    super.key,
    required this.child,
    this.opacity = 0.08,
    this.padding = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: Stack(
        children: [
          Positioned.fill(
            child: Padding(
              padding: padding,
              child: child,
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: Opacity(
                opacity: opacity.clamp(0.0, 1.0),
                child: Image.asset(
                  'assets/textures/maslive_honeycomb_2048.png',
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.low,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
