import 'package:flutter/material.dart';
import '../services/cart_service.dart';
import '../session/require_signin.dart';
import '../session/session_scope.dart';

class CartPage extends StatelessWidget {
  const CartPage({super.key});

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Panier'),
        actions: [
          IconButton(
            tooltip: 'Vider',
            onPressed: () => CartService.instance.clear(),
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: CartService.instance,
        builder: (context, _) {
          final items = CartService.instance.items;
          if (items.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.shopping_bag_outlined, size: 52),
                    const SizedBox(height: 10),
                    const Text(
                      'Votre panier est vide',
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Ajoutez des articles depuis la boutique.',
                      style: TextStyle(
                        color: Colors.black.withValues(alpha: 0.6),
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 14),
                    FilledButton.icon(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.arrow_back_rounded),
                      label: const Text('Continuer mes achats'),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
            itemBuilder: (context, index) {
              final item = items[index];
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 72,
                      height: 72,
                      color: Colors.black.withValues(alpha: 0.06),
                      child: item.imageUrl.isEmpty
                          ? const Icon(Icons.image_outlined)
                          : Image.network(item.imageUrl, fit: BoxFit.cover),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Taille ${item.size} • ${item.color}',
                          style: TextStyle(
                            color: Colors.black.withValues(alpha: 0.55),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            _QtyButton(
                              icon: Icons.remove,
                              onTap: () => CartService.instance
                                  .setQuantity(item.key, item.quantity - 1),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              child: Text(
                                '${item.quantity}',
                                style: const TextStyle(fontWeight: FontWeight.w900),
                              ),
                            ),
                            _QtyButton(
                              icon: Icons.add,
                              onTap: () => CartService.instance
                                  .setQuantity(item.key, item.quantity + 1),
                            ),
                            const Spacer(),
                            IconButton(
                              tooltip: 'Supprimer',
                              onPressed: () => CartService.instance.removeKey(item.key),
                              icon: const Icon(Icons.close_rounded),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
            separatorBuilder: (_, _) => const Divider(height: 28),
            itemCount: items.length,
          );
        },
      ),
      bottomSheet: AnimatedBuilder(
        animation: CartService.instance,
        builder: (context, _) {
          return Container(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 12,
              bottom: 12 + MediaQuery.of(context).padding.bottom,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.94),
              boxShadow: [
                BoxShadow(
                  blurRadius: 18,
                  offset: const Offset(0, -8),
                  color: Colors.black.withValues(alpha: 0.08),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Total',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        CartService.instance.totalLabel,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  onPressed: CartService.instance.items.isEmpty
                      ? null
                      : () => requireSignIn(
                            context,
                            session: session,
                            onSignedIn: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Checkout à brancher (démo)'),
                                ),
                              );
                            },
                          ),
                  child: const Text('Commander'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _QtyButton extends StatelessWidget {
  const _QtyButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(icon, size: 18),
        ),
      ),
    );
  }
}
