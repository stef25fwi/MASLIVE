import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../pages/cart/unified_cart_page.dart';
import '../../providers/cart_provider.dart';
import '../../utils/cart_constants.dart';

class CartBadgeGlyph extends StatelessWidget {
  const CartBadgeGlyph({
    super.key,
    required this.count,
    this.iconColor,
    this.backgroundColor,
    this.borderColor,
    this.iconSize = 22,
    this.containerSize = 42,
    this.showContainer = true,
    this.badgeTop = 2,
    this.badgeRight = 2,
  });

  static const LinearGradient badgeGradient = LinearGradient(
    colors: <Color>[
      Color(0xFFFF7BC5),
      Color(0xFFFF4D8D),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  final int count;
  final Color? iconColor;
  final Color? backgroundColor;
  final Color? borderColor;
  final double iconSize;
  final double containerSize;
  final bool showContainer;
  final double badgeTop;
  final double badgeRight;

  @override
  Widget build(BuildContext context) {
    final badgeLabel = count > CartConstants.badgeMaxValue
        ? '${CartConstants.badgeMaxValue}+'
        : '$count';

    final iconWidget = Icon(
      Icons.shopping_cart_rounded,
      color: iconColor ?? const Color(0xFF111827),
      size: iconSize,
    );

    final iconBody = showContainer
        ? Container(
            width: containerSize,
            height: containerSize,
            decoration: BoxDecoration(
              color: backgroundColor ?? Colors.white.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: borderColor ?? Colors.white.withValues(alpha: 0.30),
              ),
            ),
            child: Center(child: iconWidget),
          )
        : SizedBox(
            width: containerSize,
            height: containerSize,
            child: Center(child: iconWidget),
          );

    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        iconBody,
        if (count > 0)
          Positioned(
            right: badgeRight,
            top: badgeTop,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                gradient: badgeGradient,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white, width: 1),
              ),
              child: Text(
                badgeLabel,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 10,
                  height: 1,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class CartIconBadge extends StatelessWidget {
  const CartIconBadge({
    super.key,
    this.iconColor,
    this.backgroundColor,
    this.borderColor,
    this.onPressed,
  });

  final Color? iconColor;
  final Color? backgroundColor;
  final Color? borderColor;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Consumer<CartProvider>(
      builder: (context, cart, _) {
        return IconButton(
          tooltip: 'Panier',
          onPressed: onPressed ?? () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const UnifiedCartPage()),
            );
          },
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 42, minHeight: 42),
          icon: CartBadgeGlyph(
            count: cart.totalQuantity,
            iconColor: iconColor,
            backgroundColor: backgroundColor,
            borderColor: borderColor,
          ),
        );
      },
    );
  }
}
