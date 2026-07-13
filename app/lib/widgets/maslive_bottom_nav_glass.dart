import 'dart:ui';
import 'package:flutter/material.dart';

/// Barre de navigation inférieure MASLIVE avec effet verre blanc transparent,
/// indicateur glissant pastel et animations fluides.
class MasliveBottomNavGlass extends StatelessWidget {
  final int index;
  final ValueChanged<int> onTap;
  final VoidCallback onPlus;

  const MasliveBottomNavGlass({
    super.key,
    required this.index,
    required this.onTap,
    required this.onPlus,
  });

  static const barHeight = 68.0;
  static const _icons = <IconData?>[
    null, // Icône Carte MASLIVE dessinée sur mesure.
    Icons.search_rounded,
    Icons.movie_creation_outlined,
    Icons.person_rounded,
  ];

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return SizedBox(
      height: barHeight + bottomPad,
      child: Stack(
        children: [
          Positioned(
            left: 12,
            right: 12,
            bottom: bottomPad,
            child: _GlassBar(index: index, onTap: onTap),
          ),
          Positioned(
            right: 18,
            bottom: 18 + bottomPad,
            child: _PlusButton(onTap: onPlus),
          ),
        ],
      ),
    );
  }
}

class _GlassBar extends StatelessWidget {
  final int index;
  final ValueChanged<int> onTap;

  const _GlassBar({required this.index, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          height: MasliveBottomNavGlass.barHeight,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.35),
              width: 1.2,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x24000000),
                blurRadius: 18,
                offset: Offset(0, 12),
              ),
            ],
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              const reservedForFab = 78.0;
              const sidePadding = 12.0;
              const indicatorWidth = 56.0;
              final usableWidth =
                  (constraints.maxWidth - reservedForFab - sidePadding * 2)
                      .clamp(0.0, constraints.maxWidth);
              final safeWidth = usableWidth == 0
                  ? constraints.maxWidth
                  : usableWidth;
              final itemWidth = safeWidth / MasliveBottomNavGlass._icons.length;
              final clampedIndex = index.clamp(
                0,
                MasliveBottomNavGlass._icons.length - 1,
              );
              final indicatorLeft =
                  (itemWidth * clampedIndex) + (itemWidth - indicatorWidth) / 2;
              final maxLeft = (safeWidth - indicatorWidth).clamp(
                0.0,
                safeWidth,
              );
              final resolvedIndicatorLeft = indicatorLeft.clamp(0.0, maxLeft);

              return Padding(
                padding: const EdgeInsets.fromLTRB(
                  sidePadding,
                  0,
                  reservedForFab + sidePadding,
                  0,
                ),
                child: Stack(
                  children: [
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 280),
                      curve: Curves.easeOutCubic,
                      left: resolvedIndicatorLeft,
                      bottom: 10,
                      child: _Indicator(width: indicatorWidth),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: List.generate(
                        MasliveBottomNavGlass._icons.length,
                        (i) => _NavIcon(
                          icon: MasliveBottomNavGlass._icons[i],
                          selected: index == i,
                          onTap: () => onTap(i),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Indicator extends StatelessWidget {
  final double width;
  const _Indicator({required this.width});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 42,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFF9FF), Color(0xFFEFF4FF)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.7)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 16,
            offset: Offset(0, 10),
          ),
        ],
      ),
    );
  }
}

class _NavIcon extends StatelessWidget {
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;

  const _NavIcon({
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = const Color(0xFF111827);
    final idleColor = const Color(0xFF7A8699);
    final iconColor = selected ? activeColor : idleColor;

    return InkResponse(
      onTap: onTap,
      radius: 28,
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        offset: selected ? const Offset(0, -0.12) : Offset.zero,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 160),
          opacity: selected ? 1 : 0.75,
          child: icon == null
              ? CustomPaint(
                  size: const Size(30, 30),
                  painter: _MasliveMapPinIconPainter(color: iconColor),
                )
              : Icon(
                  icon,
                  color: iconColor,
                  size: 26,
                ),
        ),
      ),
    );
  }
}

class _MasliveMapPinIconPainter extends CustomPainter {
  final Color color;

  const _MasliveMapPinIconPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final scaleX = size.width / 30;
    final scaleY = size.height / 30;
    canvas.save();
    canvas.scale(scaleX, scaleY);

    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Carte pliée : trois volets, lisible en très petite taille.
    final mapPath = Path()
      ..moveTo(3.5, 13.0)
      ..lineTo(8.6, 10.8)
      ..lineTo(13.7, 13.0)
      ..lineTo(21.5, 10.8)
      ..lineTo(26.5, 13.0)
      ..lineTo(26.5, 25.0)
      ..lineTo(21.5, 22.8)
      ..lineTo(13.7, 25.0)
      ..lineTo(8.6, 22.8)
      ..lineTo(3.5, 25.0)
      ..close();
    canvas.drawPath(mapPath, stroke);

    canvas.drawLine(const Offset(8.6, 10.8), const Offset(8.6, 22.8), stroke);
    canvas.drawLine(const Offset(21.5, 10.8), const Offset(21.5, 22.8), stroke);

    // Épingle pleine au-dessus de la carte.
    final pinPath = Path()
      ..moveTo(15.0, 4.0)
      ..cubicTo(11.6, 4.0, 9.4, 6.4, 9.4, 9.2)
      ..cubicTo(9.4, 12.8, 13.3, 16.2, 15.0, 18.7)
      ..cubicTo(16.7, 16.2, 20.6, 12.8, 20.6, 9.2)
      ..cubicTo(20.6, 6.4, 18.4, 4.0, 15.0, 4.0)
      ..close();
    canvas.drawPath(pinPath, fill);

    final hole = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(const Offset(15.0, 9.2), 2.15, hole);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _MasliveMapPinIconPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _PlusButton extends StatelessWidget {
  final VoidCallback onTap;
  const _PlusButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFFFE36A), Color(0xFFFF7BC5), Color(0xFF7CE0FF)],
            ),
            boxShadow: const [
              BoxShadow(
                blurRadius: 18,
                offset: Offset(0, 10),
                color: Color(0x24000000),
              ),
            ],
          ),
          child: const Icon(Icons.add_rounded, color: Colors.white, size: 30),
        ),
      ),
    );
  }
}
