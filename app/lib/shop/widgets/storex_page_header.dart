import 'package:flutter/material.dart';

import '../../ui_kit/responsive/responsive.dart';
import '../../widgets/cart/cart_icon_badge.dart';
import 'package:masslive/ui_kit/tokens/maslive_tokens.dart';

class StorexPageHeaderTitle extends StatelessWidget {
  const StorexPageHeaderTitle({super.key, required this.subtitle});

  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final titleSize = responsiveValue<double>(
      context,
      compact: 28,
      medium: 30,
      expanded: 32,
      wide: 34,
    );
    final subtitleSize = responsiveValue<double>(
      context,
      compact: 13.5,
      medium: 14,
      expanded: 15,
      wide: 15.5,
    );
    final maxWidth = responsiveValue<double>(
      context,
      compact: 220,
      medium: 300,
      expanded: 380,
      wide: 440,
    );

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            "MAS'LIVE",
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: titleSize,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.8,
              color: MasliveTokens.text,
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
          SizedBox(
            height: responsiveValue<double>(
              context,
              compact: 8,
              medium: 7,
              expanded: 7,
              wide: 8,
            ),
          ),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: subtitleSize,
              fontWeight: FontWeight.w500,
              letterSpacing: responsiveValue<double>(
                context,
                compact: 2.2,
                medium: 2.35,
                expanded: 2.5,
                wide: 2.6,
              ),
              color: const Color(0xFF667085),
              height: 1,
            ),
          ),
        ],
      ),
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
    final iconSize = responsiveValue<double>(
      context,
      compact: 30,
      medium: 31,
      expanded: 32,
      wide: 34,
    );

    return CartBadgeGlyph(
      count: badgeCount,
      iconColor: selected ? Colors.white : MasliveTokens.text,
      iconSize: iconSize,
      containerSize: iconSize,
      showContainer: false,
      badgeRight: -7,
      badgeTop: -7,
    );
  }
}
