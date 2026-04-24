import 'package:flutter/material.dart';

import '../../domain/commerce_models.dart';
import '../controllers/product_controller.dart';
import '../widgets/change_notifier_provider_lite.dart';
import '../../../../ui/snack/top_snack_bar.dart';

class BoutiquePage extends StatefulWidget {
  final String shopId;
  final String userId;

  const BoutiquePage({super.key, required this.shopId, required this.userId});

  @override
  State<BoutiquePage> createState() => _BoutiquePageState();
}

class _BoutiquePageState extends State<BoutiquePage> {
  late final ProductController controller;
  final TextEditingController searchCtrl = TextEditingController();
  final Map<String, CartItem> cart = {};

  @override
  void initState() {
    super.initState();
    controller = ProductController(shopId: widget.shopId);
    searchCtrl.addListener(() => controller.setSearch(searchCtrl.text));
    controller.setFilter(const ProductFilter(onlyActive: true));
  }

  @override
  void dispose() {
    searchCtrl.dispose();
    controller.dispose();
    super.dispose();
  }

  int get cartCount => cart.values.fold<int>(0, (sum, item) => sum + item.qty);

  void addToCart(Product product) {
    setState(() {
      final current = cart[product.id];
      if (current == null) {
        cart[product.id] = CartItem(product: product, qty: 1);
      } else {
        cart[product.id] = current.copyWith(qty: current.qty + 1);
      }
    });
  }

  void removeFromCart(Product product) {
    setState(() {
      final current = cart[product.id];
      if (current == null) return;
      final nextQty = current.qty - 1;
      if (nextQty <= 0) {
        cart.remove(product.id);
      } else {
        cart[product.id] = current.copyWith(qty: nextQty);
      }
    });
  }

  double get total => cart.values.fold<double>(
    0,
    (sum, item) => sum + (item.product.price * item.qty),
  );

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return ChangeNotifierProviderLite(
      notifier: controller,
      child: Builder(
        builder: (context) {
          final currentController =
              ChangeNotifierProviderLite.of<ProductController>(context);

          return Scaffold(
            backgroundColor: Colors.white,
            body: SafeArea(
              top: false,
              child: Column(
                children: [
                  Container(
                    padding: EdgeInsets.fromLTRB(16, topPadding + 12, 16, 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          blurRadius: 20,
                          offset: const Offset(0, 6),
                          color: Colors.black.withAlpha(15),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Boutique',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        _CartIconWithBadge(
                          count: cartCount,
                          onTap: () => _openCart(context, currentController),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                    child: TextField(
                      controller: searchCtrl,
                      decoration: InputDecoration(
                        hintText: 'Rechercher…',
                        prefixIcon: const Icon(Icons.search),
                        filled: true,
                        fillColor: const Color(0xFFF6F7FB),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Stack(
                      children: [
                        StreamBuilder<List<Product>>(
                          stream: currentController.streamProducts(),
                          builder: (context, snapshot) {
                            if (snapshot.hasError) {
                              return Center(
                                child: Text('Erreur: ${snapshot.error}'),
                              );
                            }
                            if (!snapshot.hasData) {
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            }

                            final products = snapshot.data!;
                            if (products.isEmpty) {
                              return const Center(
                                child: Text('Aucun produit disponible'),
                              );
                            }

                            return ListView.separated(
                              padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
                              itemCount: products.length,
                              separatorBuilder: (context, index) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (_, index) {
                                final product = products[index];
                                final isOut = product.stockStatus == 'out';
                                return Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(
                                      color: const Color(0xFFE9ECF3),
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        blurRadius: 18,
                                        offset: const Offset(0, 10),
                                        color: Colors.black.withValues(alpha: 0.05),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(14),
                                        child: Container(
                                          width: 66,
                                          height: 66,
                                          color: const Color(0xFFF6F7FB),
                                          child: product.mainImageUrl == null
                                              ? const Icon(Icons.photo_outlined)
                                              : Image.network(
                                                  product.mainImageUrl!,
                                                  fit: BoxFit.cover,
                                                ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              product.name,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w900,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              '${product.price.toStringAsFixed(2)} ${product.currency}',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            _StockPill(
                                              text: isOut
                                                  ? 'Rupture'
                                                  : (product.stockStatus == 'low'
                                                        ? 'Stock faible'
                                                        : 'En stock'),
                                              filled:
                                                  isOut ||
                                                  product.stockStatus == 'low',
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      if (isOut)
                                        const Icon(
                                          Icons.block,
                                          color: Colors.black54,
                                        )
                                      else
                                        Column(
                                          children: [
                                            IconButton.filled(
                                              onPressed: () => addToCart(product),
                                              icon: const Icon(
                                                Icons.add_shopping_cart_outlined,
                                              ),
                                            ),
                                            if (cart[product.id] != null)
                                              Text(
                                                'x${cart[product.id]!.qty}',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w900,
                                                ),
                                              ),
                                          ],
                                        ),
                                    ],
                                  ),
                                );
                              },
                            );
                          },
                        ),
                        AnimatedBuilder(
                          animation: currentController,
                          builder: (context, child) {
                            if (!currentController.busy) {
                              return const SizedBox.shrink();
                            }
                            return Container(
                              color: Colors.black.withAlpha(20),
                              child: const Center(
                                child: CircularProgressIndicator(),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _openCart(
    BuildContext context,
    ProductController currentController,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) {
        final items = cart.values.toList();
        return Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            14,
            16,
            16 + MediaQuery.of(context).padding.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Panier',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              if (items.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Ton panier est vide.'),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: items.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 16),
                    itemBuilder: (_, index) {
                      final item = items[index];
                      return Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.product.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => removeFromCart(item.product),
                            icon: const Icon(Icons.remove_circle_outline),
                          ),
                          Text(
                            '${item.qty}',
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                          IconButton(
                            onPressed: () => addToCart(item.product),
                            icon: const Icon(Icons.add_circle_outline),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${(item.product.price * item.qty).toStringAsFixed(2)} ${item.product.currency}',
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Total: ${total.toStringAsFixed(2)} EUR',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  FilledButton(
                    onPressed: items.isEmpty
                        ? null
                        : () async {
                            try {
                              final orderId = await currentController.commerceRepo
                                  .checkoutCreateOrder(
                                    shopId: widget.shopId,
                                    userId: widget.userId,
                                    items: items,
                                  );
                              if (!context.mounted) return;
                              setState(() => cart.clear());
                              Navigator.pop(context);
                              TopSnackBar.show(
                                context,
                                SnackBar(
                                  content: Text('Commande créée: $orderId'),
                                ),
                              );
                            } catch (error) {
                              if (!context.mounted) return;
                              TopSnackBar.show(
                                context,
                                SnackBar(
                                  content: Text(
                                    'Checkout impossible: $error',
                                  ),
                                ),
                              );
                            }
                          },
                    child: const Text('Commander'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CartIconWithBadge extends StatelessWidget {
  final int count;
  final VoidCallback? onTap;

  const _CartIconWithBadge({required this.count, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          onPressed: onTap,
          icon: const Icon(Icons.shopping_bag_outlined),
        ),
        if (count > 0)
          Positioned(
            right: 4,
            top: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '$count',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _StockPill extends StatelessWidget {
  final String text;
  final bool filled;

  const _StockPill({required this.text, required this.filled});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: filled ? Colors.black : const Color(0xFFF6F7FB),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: filled ? Colors.black : const Color(0xFFE9ECF3),
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: filled ? Colors.white : Colors.black87,
          fontWeight: FontWeight.w900,
          fontSize: 12,
        ),
      ),
    );
  }
}