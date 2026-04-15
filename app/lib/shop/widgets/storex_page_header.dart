import 'package:flutter/material.dart';

import '../../widgets/cart/cart_icon_badge.dart';

class StorexPageHeaderTitle extends StatelessWidget {
  const StorexPageHeaderTitle({
    super.key,
    required this.subtitle,
  });

  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          "MAS'LIVE",
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.8,
            color: const Color(0xFF101828),
            height: 1,
            shadows: <Shadow>[
              Shadow(
                offset: const Offset(0, 2),
                blurRadius: 6,
                color: Colors.black.withValues(alpha: 0.25),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w500,
            letterSpacing: 2.2,
            color: Color(0xFF667085),
            height: 1,
          ),
        ),
      ],
    );
  }
}

class StorexHeaderCartIcon extends StatelessWidget {
  const StorexHeaderCartIcon({
    super.key,
    required this.badgeCount,
    this.selected = false,
  });

  final int badgeCount;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return CartBadgeGlyph(
      count: badgeCount,
      iconColor: selected ? Colors.white : const Color(0xFF101828),
      iconSize: 30,
      containerSize: 30,
      showContainer: false,
      badgeRight: -7,
      badgeTop: -7,
    );
  }
}