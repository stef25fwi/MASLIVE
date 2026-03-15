import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/cart_provider.dart';
import '../../services/cart_checkout_service.dart';
import '../../session/require_signin.dart';
import '../../session/session_scope.dart';
import '../../ui/snack/top_snack_bar.dart';
import '../../widgets/cart/cart_group_section.dart';
import '../../widgets/cart/cart_item_tile.dart';
import '../../widgets/cart/cart_summary_card.dart';
import '../../widgets/cart/empty_cart_view.dart';

class UnifiedCartPage extends StatelessWidget {
  const UnifiedCartPage({
    super.key,
    this.embedded = false,
  });

  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final session = SessionScope.of(context);

    Widget body;
    if (cart.loading && cart.items.isEmpty) {
      body = const Center(child: CircularProgressIndicator());
    } else if (cart.isEmpty) {
      body = EmptyCartView(
        onContinueShopping: () => Navigator.of(context).maybePop(),
      );
    } else {
      final currency = cart.items.first.currency;
      body = ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: <Widget>[
          if (cart.error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Material(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(18),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Text(
                    'Erreur panier: ${cart.error}',
                    style: const TextStyle(
                      color: Color(0xFF991B1B),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          if (cart.merchItems.isNotEmpty)
            CartGroupSection(
              title: 'Merch',
              subtitle: 'Produits physiques et variantes.',
              trailing: TextButton(
                onPressed: cart.clearMerch,
                child: const Text('Vider'),
              ),
              child: Column(
                children: cart.merchItems
                    .map(
                      (item) => CartItemTile(
                        item: item,
                        onRemove: () => cart.removeCartItem(item.id),
                        onIncrement: () => cart.incrementItem(item.id),
                        onDecrement: () => cart.decrementItem(item.id),
                      ),
                    )
                    .toList(growable: false),
              ),
            ),
          if (cart.mediaItems.isNotEmpty)
            CartGroupSection(
              title: 'Media',
              subtitle: 'Produits digitaux et contenus marketplace.',
              trailing: TextButton(
                onPressed: cart.clearMedia,
                child: const Text('Vider'),
              ),
              child: Column(
                children: cart.mediaItems
                    .map(
                      (item) => CartItemTile(
                        item: item,
                        onRemove: () => cart.removeCartItem(item.id),
                      ),
                    )
                    .toList(growable: false),
              ),
            ),
          CartSummaryCard(
            merchSubtotal: cart.merchSubtotal,
            mediaSubtotal: cart.mediaSubtotal,
            grandTotal: cart.grandTotal,
            currency: currency,
            enabled: !cart.isEmpty,
            onCheckout: () => _handleCheckout(context, cart, session),
            checkoutLabel: cart.mediaCheckoutItems.isNotEmpty && cart.merchCheckoutItems.isNotEmpty
                ? 'Continuer vers checkout'
                : 'Continuer',
          ),
        ],
      );
    }

    if (embedded) {
      return body;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Panier'),
        actions: <Widget>[
          if (!cart.isEmpty)
            TextButton(
              onPressed: cart.clearCart,
              child: const Text('Tout vider'),
            ),
        ],
      ),
      body: body,
    );
  }

  Future<void> _handleCheckout(
    BuildContext context,
    CartProvider cart,
    SessionControllerLike? session,
  ) async {
    final hasMerch = cart.merchCheckoutItems.isNotEmpty;
    final hasMedia = cart.mediaCheckoutItems.isNotEmpty;

    if (!hasMerch && !hasMedia) {
      return;
    }

    if (hasMerch && !hasMedia) {
      await _startMerchCheckout(context, session);
      return;
    }

    if (!hasMerch && hasMedia) {
      await _startMediaCheckout(context, cart, session);
      return;
    }

    await _showSplitCheckoutSheet(context, cart, session);
  }

  Future<void> _startMerchCheckout(
    BuildContext context,
    SessionControllerLike session,
  ) async {
    if (!session.isSignedIn) {
      await requireSignIn(context, session: session);
      if (!session.isSignedIn || !context.mounted) return;
    }

    if (FirebaseAuth.instance.currentUser?.uid == null) {
      TopSnackBar.show(
        context,
        const SnackBar(content: Text('Utilisateur introuvable')),
      );
      return;
    }

    await CartCheckoutService.startMerchCheckout(context);
  }

  Future<void> _startMediaCheckout(
    BuildContext context,
    CartProvider cart,
    SessionControllerLike session,
  ) async {
    if (!session.isSignedIn) {
      await requireSignIn(context, session: session);
      if (!session.isSignedIn || !context.mounted) return;
    }

    if (FirebaseAuth.instance.currentUser?.uid == null) {
      TopSnackBar.show(
        context,
        const SnackBar(content: Text('Utilisateur introuvable')),
      );
      return;
    }

    try {
      await CartCheckoutService.startMediaCheckout(context, cart);
    } catch (error) {
      if (!context.mounted) return;
      TopSnackBar.show(
        context,
        SnackBar(content: Text('Checkout media impossible: $error')),
      );
    }
  }

  Future<void> _showSplitCheckoutSheet(
    BuildContext context,
    CartProvider cart,
    SessionControllerLike session,
  ) async {
    final payload = cart.buildCheckoutPayload();
    final summary = Map<String, dynamic>.from(
      payload['summary'] as Map<String, dynamic>? ?? const <String, dynamic>{},
    );

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'Choisir le checkout',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(
                  'Le panier contient du merch et des medias. Checkout separe disponible maintenant.',
                  style: Theme.of(sheetContext).textTheme.bodyMedium,
                ),
                const SizedBox(height: 14),
                Text('Total merch: ${summary['merchSubtotal'] ?? 0} EUR'),
                Text('Total media: ${summary['mediaSubtotal'] ?? 0} EUR'),
                Text('Total global: ${summary['grandTotal'] ?? 0} EUR'),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.of(sheetContext).pop();
                      unawaited(_startMerchCheckout(context, session));
                    },
                    icon: const Icon(Icons.shopping_bag_outlined),
                    label: const Text('Payer le merch'),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(sheetContext).pop();
                      unawaited(_startMediaCheckout(context, cart, session));
                    },
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('Payer les medias'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

typedef SessionControllerLike = dynamic;