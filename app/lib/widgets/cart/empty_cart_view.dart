import 'package:flutter/material.dart';

class EmptyCartView extends StatelessWidget {
  const EmptyCartView({
    super.key,
    this.onContinueShopping,
  });

  final VoidCallback? onContinueShopping;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: <Color>[
                  Color(0xFFFFF6D9),
                  Color(0xFFFFEAF5),
                  Color(0xFFEFF9FF),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: const Color(0x1F0F172A)),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  blurRadius: 22,
                  offset: const Offset(0, 14),
                  color: const Color(0x1A000000),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: const Icon(
                      Icons.shopping_cart_checkout_rounded,
                      size: 36,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Ton panier est vide',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Ajoute du merch, des medias ou les prochains produits MASLIVE depuis une seule experience panier.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF4B5563),
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: onContinueShopping,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF111827),
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.storefront_outlined),
                    label: const Text('Retour boutique'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}