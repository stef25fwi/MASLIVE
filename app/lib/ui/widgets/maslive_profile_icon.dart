import 'package:flutter/material.dart';

class MasliveProfileIcon extends StatelessWidget {
  const MasliveProfileIcon({
    super.key,
    this.size = 64,
    this.badgeSizeRatio = 0.22,
    this.showBadge = true,
  });

  final double size;
  final double badgeSizeRatio;
  final bool showBadge;

  @override
  Widget build(BuildContext context) {
    final badgeSize = size * badgeSizeRatio;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
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
                  color: const Color(0xFF9B6BFF).withValues(alpha: 0.25),
                  blurRadius: size * 0.35,
                  spreadRadius: size * 0.06,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Center(
              child: _UserGlyph(size: size),
            ),
          ),
          if (showBadge)
            Positioned(
              right: size * 0.10,
              top: size * 0.10,
              child: Container(
                width: badgeSize,
                height: badgeSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF22C55E),
                  border: Border.all(
                    color: Colors.white.withAlpha((0.95 * 255).round()),
                    width: badgeSize * 0.18,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha((0.12 * 255).round()),
                      blurRadius: badgeSize * 0.7,
                      offset: const Offset(0, 3),
                    )
                  ],
                ),
                child: Center(
                  child: Icon(
                    Icons.check_rounded,
                    color: Colors.white,
                    size: badgeSize * 0.65,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _UserGlyph extends StatelessWidget {
  const _UserGlyph({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    final head = size * 0.26;
    final bodyW = size * 0.54;
    final bodyH = size * 0.30;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: head,
          height: head,
          decoration: BoxDecoration(
            color: Colors.white.withAlpha((0.95 * 255).round()),
            shape: BoxShape.circle,
          ),
        ),
        SizedBox(height: size * 0.06),
        Container(
          width: bodyW,
          height: bodyH,
          decoration: BoxDecoration(
            color: Colors.white.withAlpha((0.95 * 255).round()),
            borderRadius: BorderRadius.circular(bodyH),
          ),
        ),
      ],
    );
  }
}
