import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../pages/cart/unified_cart_page.dart';
import '../../providers/cart_provider.dart';
import '../../utils/cart_constants.dart';

class CartIconBadge extends StatelessWidget {
  const CartIconBadge({
    super.key,
    this.iconColor,
    this.iconGradient,
    this.backgroundColor,
    this.borderColor,
    this.onPressed,
  });

  final Color? iconColor;
  final Gradient? iconGradient;
  final Color? backgroundColor;
  final Color? borderColor;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Consumer<CartProvider>(
      builder: (context, cart, _) {
        final count = cart.totalQuantity;
        final badgeLabel = count > CartConstants.badgeMaxValue
            ? '${CartConstants.badgeMaxValue}+'
            : '$count';

        return Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            IconButton(
              tooltip: 'Panier',
              onPressed: onPressed ?? () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const UnifiedCartPage()),
                );
              },
              icon: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: backgroundColor ?? Colors.white.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: borderColor ?? Colors.white.withValues(alpha: 0.30),
                  ),
                ),
                child: Builder(
                  builder: (context) {
                    final baseIcon = Icon(
                      Icons.shopping_cart_rounded,
                      color: iconGradient != null
                          ? Colors.white
                          : (iconColor ?? const Color(0xFF111827)),
                    );
                    if (iconGradient == null) return baseIcon;
                    return ShaderMask(
                      blendMode: BlendMode.srcIn,
                      shaderCallback: (bounds) => iconGradient!.createShader(bounds),
                      child: baseIcon,
                    );
                  },
                ),
              ),
            ),
            if (count > 0)
              Positioned(
                right: 2,
                top: 2,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF111827),
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
      },
    );
  }
}