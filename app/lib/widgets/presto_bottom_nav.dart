import 'dart:ui';
import 'package:flutter/material.dart';

class PrestoBottomNav extends StatelessWidget {
  final int index;
  final ValueChanged<int> onTap;
  final VoidCallback onPlus;

  const PrestoBottomNav({
    super.key,
    required this.index,
    required this.onTap,
    required this.onPlus,
  });

  static const barHeight = 78.0;
  static const _icons = <IconData>[
    Icons.near_me_rounded,
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
          height: PrestoBottomNav.barHeight,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.82),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.white.withOpacity(0.35),
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
              final itemWidth = safeWidth / PrestoBottomNav._icons.length;
              final clampedIndex = index.clamp(
                0,
                PrestoBottomNav._icons.length - 1,
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
                        PrestoBottomNav._icons.length,
                        (i) => _NavIcon(
                          icon: PrestoBottomNav._icons[i],
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
        border: Border.all(color: Colors.white.withOpacity(0.7)),
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
  final IconData icon;
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
          child: Icon(
            icon,
            color: selected ? activeColor : idleColor,
            size: 24,
          ),
        ),
      ),
    );
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
