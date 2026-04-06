import 'dart:async';
import 'dart:ui';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/cart_item_model.dart';
import '../../providers/cart_provider.dart';
import '../../services/cart_checkout_service.dart';
import '../../session/require_signin.dart';
import '../../session/session_controller.dart';
import '../../session/session_scope.dart';
import '../../ui/snack/top_snack_bar.dart';
import '../../ui_kit/tokens/maslive_tokens.dart';

const LinearGradient _premiumHeaderGradient = LinearGradient(
  colors: <Color>[
    Color(0xFFFFE36A),
    Color(0xFFFF8ACD),
    Color(0xFF98E4FF),
    Color(0xFFB8FFDA),
  ],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

class MasliveUltraPremiumCheckoutPage extends StatefulWidget {
  const MasliveUltraPremiumCheckoutPage({super.key});

  @override
  State<MasliveUltraPremiumCheckoutPage> createState() =>
      _MasliveUltraPremiumCheckoutPageState();
}

class _MasliveUltraPremiumCheckoutPageState
    extends State<MasliveUltraPremiumCheckoutPage> {
  final TextEditingController _promoController = TextEditingController();

  DeliveryMode _deliveryMode = DeliveryMode.standard;
  PaymentMode _paymentMode = PaymentMode.card;
  bool _useSavedAddress = true;
  bool _acceptTerms = true;
  String? _promoCode;
  int _promoDiscountCents = 0;
  bool _checkoutLoading = false;
  bool _promoValidationLoading = false;

  double get serviceFee => 0.0;

  bool _hasPhysicalItems(List<CartItemModel> items) {
    return items.any((e) => e.requiresShipping);
  }

  double _subtotal(List<CartItemModel> items) {
    return items.fold(0.0, (sum, e) => sum + e.totalPrice);
  }

  int _totalQuantity(List<CartItemModel> items) {
    return items.fold(0, (sum, e) => sum + e.safeQuantity);
  }

  double _promoDiscount() {
    return _promoDiscountCents / 100.0;
  }

  double _shippingCost({
    required bool hasPhysicalItems,
  }) {
    if (!hasPhysicalItems) return 0;
    return _shippingCents(hasPhysicalItems: hasPhysicalItems) / 100.0;
  }

  int _shippingCents({required bool hasPhysicalItems}) {
    if (!hasPhysicalItems) return 0;
    switch (_deliveryMode) {
      case DeliveryMode.pickup:
        return 500;
      case DeliveryMode.standard:
        return 2000;
    }
  }

  String _shippingMethodKey({required bool hasPhysicalItems}) {
    if (!hasPhysicalItems) return 'free';
    switch (_deliveryMode) {
      case DeliveryMode.pickup:
        return 'local_pickup';
      case DeliveryMode.standard:
        return 'flat_rate';
    }
  }

  void _clearPromoState() {
    if (_promoCode == null && _promoDiscountCents == 0) return;
    setState(() {
      _promoCode = null;
      _promoDiscountCents = 0;
    });
  }

  Future<void> _incrementItem(CartProvider cart, CartItemModel item) async {
    _clearPromoState();
    await cart.incrementItem(item.id);
  }

  Future<void> _decrementItem(CartProvider cart, CartItemModel item) async {
    _clearPromoState();
    await cart.decrementItem(item.id);
  }

  Future<void> _removeItem(CartProvider cart, CartItemModel item) async {
    _clearPromoState();
    await cart.removeCartItem(item.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${item.title} supprimé du panier'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MasliveTokens.rM),
        ),
      ),
    );
  }

  Future<void> _applyPromo() async {
    final code = _promoController.text.trim().toUpperCase();
    if (code.isEmpty) return;

    setState(() => _promoValidationLoading = true);
    try {
      final cart = context.read<CartProvider>();
      final items = cart.checkoutEligibleItems;
      final subtotal = items.fold(0.0, (sum, e) => sum + e.totalPrice);
      final subtotalCents = (subtotal * 100).toInt();

      final result = await CartCheckoutService.validatePromoCode(
        code,
        subtotalCents: subtotalCents,
      );

      if (!mounted) return;

      final valid = result['valid'] as bool? ?? false;
      final message = (result['message'] as String?) ?? 'Erreur';
      final discountCents = (result['discountCents'] as num?)?.toInt() ?? 0;

      if (valid) {
        setState(() {
          _promoCode = code;
          _promoDiscountCents = discountCents;
        });
        TopSnackBar.show(
          context,
          SnackBar(content: Text(message)),
        );
        _promoController.clear();
      } else {
        setState(() {
          _promoCode = null;
          _promoDiscountCents = 0;
        });
        TopSnackBar.show(
          context,
          SnackBar(
            content: Text(message),
            backgroundColor: const Color(0xFFEF5350),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _promoCode = null;
        _promoDiscountCents = 0;
      });
      TopSnackBar.show(
        context,
        SnackBar(
          content: Text('Erreur validation: $e'),
          backgroundColor: const Color(0xFFEF5350),
        ),
      );
    } finally {
      if (mounted) setState(() => _promoValidationLoading = false);
    }
  }

  Future<void> _checkout(
    BuildContext context, {
    required CartProvider cart,
    required SessionController session,
  }) async {
    if (_checkoutLoading) return;

    if (!_acceptTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Veuillez accepter les conditions avant de continuer.',
          ),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(MasliveTokens.rM),
          ),
        ),
      );
      return;
    }

    if (cart.isEmpty) return;

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

    final hasMerch = cart.merchCheckoutItems.isNotEmpty;
    final hasMedia = cart.mediaCheckoutItems.isNotEmpty;
    if (!hasMerch && !hasMedia) return;

    setState(() => _checkoutLoading = true);
    try {
      if (hasMerch && hasMedia) {
        final hasPhysicalItems = _hasPhysicalItems(cart.checkoutEligibleItems);
        if (hasPhysicalItems && !_useSavedAddress) {
          if (!context.mounted) return;
          TopSnackBar.show(
            context,
            const SnackBar(
              content: Text(
                'Adresse requise: activez l\'adresse enregistrée ou renseignez-la dans le checkout boutique.',
              ),
            ),
          );
          return;
        }
        await CartCheckoutService.startMixedCheckout(
          context,
          cart,
          shippingCents: _shippingCents(
            hasPhysicalItems: hasPhysicalItems,
          ),
          shippingMethod: _shippingMethodKey(
            hasPhysicalItems: hasPhysicalItems,
          ),
          promoCode: _promoCode,
        );
        return;
      }

      if (hasMerch) {
        await CartCheckoutService.startMerchCheckout(context);
        return;
      }

      await CartCheckoutService.startMediaCheckout(context, cart);
    } catch (error) {
      if (!context.mounted) return;
      TopSnackBar.show(
        context,
        SnackBar(content: Text('Checkout impossible: $error')),
      );
    } finally {
      if (mounted) setState(() => _checkoutLoading = false);
    }
  }

  @override
  void dispose() {
    _promoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final session = SessionScope.of(context);

    final items = cart.checkoutEligibleItems;
    final hasPhysicalItems = _hasPhysicalItems(items);
    final subtotal = _subtotal(items);
    final promoDiscount = _promoDiscount();
    final shippingCost = _shippingCost(
      hasPhysicalItems: hasPhysicalItems,
    );
    final total = (subtotal - promoDiscount) + shippingCost + serviceFee;
    final totalQuantity = _totalQuantity(items);

    return Scaffold(
      backgroundColor: MasliveTokens.bg,
      body: Stack(
        children: [
          Column(
            children: [
              _CheckoutTopBar(
                onBack: () => Navigator.of(context).maybePop(),
                itemCount: totalQuantity,
                loading: _checkoutLoading,
              ),
              Expanded(
                child: cart.loading && items.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : items.isEmpty
                    ? const _EmptyCheckoutView()
                    : ListView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(18, 18, 18, 250),
                        children: [
                          _HeroSummaryCard(
                            totalItems: totalQuantity,
                            hasPhysicalItems: hasPhysicalItems,
                            total: total,
                          ),
                          const SizedBox(height: 18),

                          const _SectionTitle(
                            title: 'Articles',
                            subtitle: 'Panier fusionné merch + media',
                          ),
                          const SizedBox(height: 12),

                          ...items.map(
                            (item) => Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: _UltraCartItemCard(
                                item: item,
                                onDelete: () => _removeItem(cart, item),
                                onIncrement: item.canAdjustQuantity
                                    ? () => _incrementItem(cart, item)
                                    : null,
                                onDecrement: item.canAdjustQuantity
                                    ? () => _decrementItem(cart, item)
                                    : null,
                              ),
                            ),
                          ),

                          const SizedBox(height: 10),

                          _GlassBlock(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const _SectionMiniHeader(
                                  title: 'Code promo',
                                  trailing: 'Réduction',
                                ),
                                const SizedBox(height: 14),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Container(
                                        height: 54,
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(
                                            MasliveTokens.rM,
                                          ),
                                          border: Border.all(
                                            color: const Color(0xFFE7EAF2),
                                          ),
                                        ),
                                        child: TextField(
                                          controller: _promoController,
                                          decoration: const InputDecoration(
                                            hintText: 'Entrer un code promo',
                                            border: InputBorder.none,
                                            contentPadding:
                                                EdgeInsets.symmetric(
                                                  horizontal: 16,
                                                  vertical: 16,
                                                ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    SizedBox(
                                      height: 54,
                                      child: DecoratedBox(
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            MasliveTokens.rM,
                                          ),
                                          gradient: const LinearGradient(
                                            colors: [
                                              Color(0xFFFFB15E),
                                              Color(0xFFFF6FA7),
                                            ],
                                          ),
                                        ),
                                        child: ElevatedButton(
                                          onPressed: _promoValidationLoading ? null : _applyPromo,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.transparent,
                                            shadowColor: Colors.transparent,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(
                                                    MasliveTokens.rM,
                                                  ),
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 20,
                                            ),
                                          ),
                                          child: _promoValidationLoading
                                              ? const SizedBox(
                                                  width: 20,
                                                  height: 20,
                                                  child: CircularProgressIndicator(
                                                    valueColor:
                                                        AlwaysStoppedAnimation<Color>(
                                                          Colors.white,
                                                        ),
                                                    strokeWidth: 2,
                                                  ),
                                                )
                                              : const Text(
                                                  'Appliquer',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                                ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (_promoCode != null) ...[
                                  const SizedBox(height: 12),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      _SoftChip.gradient('Code: $_promoCode'),
                                      _SoftChip.soft(
                                        'Réduction: -${promoDiscount.toStringAsFixed(2)} €',
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),

                          const SizedBox(height: 14),

                          _GlassBlock(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const _SectionMiniHeader(
                                  title: 'Livraison',
                                  trailing: 'Choisissez une option',
                                ),
                                const SizedBox(height: 14),
                                if (!hasPhysicalItems)
                                  const _InfoBanner(
                                    icon: Icons.download_done_rounded,
                                    title: 'Aucune livraison requise',
                                    subtitle:
                                        'Votre commande contient uniquement des contenus digitaux.',
                                  )
                                else
                                  Column(
                                    children: [
                                      _SelectableTile(
                                        title: 'Standard',
                                        subtitle: 'Tarif live Stripe / Storex',
                                        trailing: '20,00 €',
                                        selected:
                                            _deliveryMode ==
                                            DeliveryMode.standard,
                                        onTap: () => setState(
                                          () => _deliveryMode =
                                              DeliveryMode.standard,
                                        ),
                                        leadingIcon:
                                            Icons.local_shipping_outlined,
                                      ),
                                      const SizedBox(height: 10),
                                      _SelectableTile(
                                        title: 'Retrait',
                                        subtitle:
                                            'Point partenaire / événement',
                                        trailing: '5,00 €',
                                        selected:
                                            _deliveryMode ==
                                            DeliveryMode.pickup,
                                        onTap: () => setState(
                                          () => _deliveryMode =
                                              DeliveryMode.pickup,
                                        ),
                                        leadingIcon: Icons.storefront_outlined,
                                      ),
                                      const SizedBox(height: 12),
                                      _ToggleLine(
                                        value: _useSavedAddress,
                                        title:
                                            'Utiliser mon adresse enregistrée',
                                        subtitle:
                                            '12 rue Exemple, 97122 Baie-Mahault',
                                        onChanged: (v) => setState(
                                          () => _useSavedAddress = v,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      const _InfoBanner(
                                        icon: Icons.info_outline_rounded,
                                        title: 'Tarifs alignés backend',
                                        subtitle:
                                            'Le montant final de livraison est calculé sur les valeurs autorisées par Stripe/Firebase.',
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 14),

                          _GlassBlock(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const _SectionMiniHeader(
                                  title: 'Paiement',
                                  trailing: 'Sécurisé',
                                ),
                                const SizedBox(height: 14),
                                _SelectableTile(
                                  title: 'Carte bancaire',
                                  subtitle: 'Visa, Mastercard, CB',
                                  trailing: 'Recommandé',
                                  selected: _paymentMode == PaymentMode.card,
                                  onTap: () => setState(
                                    () => _paymentMode = PaymentMode.card,
                                  ),
                                  leadingIcon: Icons.credit_card_rounded,
                                ),
                                const SizedBox(height: 10),
                                _SelectableTile(
                                  title: 'Apple Pay / Google Pay',
                                  subtitle: 'Paiement rapide',
                                  trailing: 'Rapide',
                                  selected: _paymentMode == PaymentMode.wallet,
                                  onTap: () => setState(
                                    () => _paymentMode = PaymentMode.wallet,
                                  ),
                                  leadingIcon: Icons.phone_iphone_rounded,
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 14),

                          _GlassBlock(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const _SectionMiniHeader(
                                  title: 'Récapitulatif',
                                  trailing: 'MASLIVE Checkout',
                                ),
                                const SizedBox(height: 14),
                                _SummaryRow(
                                  label: 'Sous-total',
                                  value: '${subtotal.toStringAsFixed(2)} €',
                                ),
                                const SizedBox(height: 10),
                                _SummaryRow(
                                  label: 'Réduction',
                                  value: promoDiscount > 0
                                      ? '-${promoDiscount.toStringAsFixed(2)} €'
                                      : '0,00 €',
                                  valueColor: promoDiscount > 0
                                      ? MasliveTokens.success
                                      : null,
                                ),
                                const SizedBox(height: 10),
                                _SummaryRow(
                                  label: 'Livraison',
                                  value: shippingCost == 0
                                      ? 'Offerte'
                                      : '${shippingCost.toStringAsFixed(2)} €',
                                ),
                                const SizedBox(height: 10),
                                _SummaryRow(
                                  label: 'Frais de service',
                                  value: '${serviceFee.toStringAsFixed(2)} €',
                                ),
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 14),
                                  child: Divider(
                                    height: 1,
                                    color: Color(0xFFE7EAF2),
                                  ),
                                ),
                                _SummaryRow(
                                  label: 'Total',
                                  value: '${total.toStringAsFixed(2)} €',
                                  strong: true,
                                ),
                                const SizedBox(height: 14),
                                _ToggleLine(
                                  value: _acceptTerms,
                                  title: 'J\'accepte les conditions',
                                  subtitle:
                                      'Paiement, livraison et contenu digital',
                                  onChanged: (v) =>
                                      setState(() => _acceptTerms = v),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
          if (items.isNotEmpty)
            Positioned(
              left: 14,
              right: 14,
              bottom: 14,
              child: _CheckoutBottomBar(
                total: total,
                totalQuantity: totalQuantity,
                paymentMode: _paymentMode,
                loading: _checkoutLoading,
                onCheckout: () =>
                    _checkout(context, cart: cart, session: session),
              ),
            ),
        ],
      ),
    );
  }
}

enum DeliveryMode { standard, pickup }

enum PaymentMode { card, wallet }

class _CheckoutTopBar extends StatelessWidget {
  final VoidCallback onBack;
  final int itemCount;
  final bool loading;

  const _CheckoutTopBar({
    required this.onBack,
    required this.itemCount,
    required this.loading,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      decoration: const BoxDecoration(gradient: _premiumHeaderGradient),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            _GlassCircleButton(
              icon: Icons.arrow_back_ios_new_rounded,
              onTap: onBack,
            ),
            const Spacer(),
            Column(
              children: [
                const Text(
                  'Checkout',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF17181D),
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$itemCount article${itemCount > 1 ? 's' : ''}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF3F4452),
                  ),
                ),
              ],
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.38),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
              ),
              child: Row(
                children: [
                  if (loading)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    const Icon(
                      Icons.lock_outline_rounded,
                      size: 16,
                      color: Color(0xFF17181D),
                    ),
                  const SizedBox(width: 6),
                  const Text(
                    'Sécurisé',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF17181D),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroSummaryCard extends StatelessWidget {
  final int totalItems;
  final bool hasPhysicalItems;
  final double total;

  const _HeroSummaryCard({
    required this.totalItems,
    required this.hasPhysicalItems,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    return _GlassBlock(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: const LinearGradient(
                colors: [
                  Color(0xFFFFAE5F),
                  Color(0xFFFF6EAB),
                  Color(0xFF7D84FF),
                ],
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x22FF6DA6),
                  blurRadius: 20,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(
              Icons.shopping_bag_outlined,
              color: Colors.white,
              size: 30,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Commande MASLIVE',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF17181D),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  hasPhysicalItems
                      ? '$totalItems article(s) • merch + media'
                      : '$totalItems contenu(s) digital(aux)',
                  style: const TextStyle(
                    fontSize: 14.5,
                    color: Color(0xFF73798A),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${total.toStringAsFixed(2)} €',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: Color(0xFF15171D),
            ),
          ),
        ],
      ),
    );
  }
}

class _UltraCartItemCard extends StatelessWidget {
  final CartItemModel item;
  final Future<void> Function() onDelete;
  final Future<void> Function()? onIncrement;
  final Future<void> Function()? onDecrement;

  const _UltraCartItemCard({
    required this.item,
    required this.onDelete,
    required this.onIncrement,
    required this.onDecrement,
  });

  @override
  Widget build(BuildContext context) {
    final subtitle = (item.subtitle ?? '').trim();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFE7EAF2)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x10000000),
            blurRadius: 26,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ProductThumb(imageUrl: item.imageUrl),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF12141A),
                          height: 1.15,
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () => unawaited(onDelete()),
                      borderRadius: BorderRadius.circular(999),
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7F8FB),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Icon(
                          Icons.delete_outline_rounded,
                          size: 20,
                          color: Color(0xFF7D6874),
                        ),
                      ),
                    ),
                  ],
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 14.5,
                      color: Color(0xFF767D8D),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _SoftChip.gradient(item.itemType.name),
                    if ((item.subtitle ?? '').trim().isNotEmpty)
                      _SoftChip.soft(item.subtitle!.trim()),
                    _SoftChip.soft(
                      item.requiresShipping ? 'Livraison' : 'Digital',
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${item.unitPrice.toStringAsFixed(2)} € / unité',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF7B8190),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    _QtyStepper(
                      quantity: item.safeQuantity,
                      onIncrement: onIncrement,
                      onDecrement: onDecrement,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${item.totalPrice.toStringAsFixed(2)} €',
                      style: const TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF12141A),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductThumb extends StatelessWidget {
  final String imageUrl;

  const _ProductThumb({required this.imageUrl});

  bool get _isAsset => imageUrl.startsWith('assets/');

  bool get _isHttp =>
      imageUrl.startsWith('http://') || imageUrl.startsWith('https://');

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 98,
      height: 112,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF5F6FA), Color(0xFFEBEEF5)],
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: _isAsset
              ? Image.asset(
                  imageUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => const Center(
                    child: Icon(
                      Icons.image_outlined,
                      size: 30,
                      color: Color(0xFF9CA3AF),
                    ),
                  ),
                )
              : _isHttp
              ? Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => const Center(
                    child: Icon(
                      Icons.image_outlined,
                      size: 30,
                      color: Color(0xFF9CA3AF),
                    ),
                  ),
                )
              : const Center(
                  child: Icon(
                    Icons.image_outlined,
                    size: 30,
                    color: Color(0xFF9CA3AF),
                  ),
                ),
        ),
      ),
    );
  }
}

class _QtyStepper extends StatelessWidget {
  final int quantity;
  final Future<void> Function()? onIncrement;
  final Future<void> Function()? onDecrement;

  const _QtyStepper({
    required this.quantity,
    required this.onIncrement,
    required this.onDecrement,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: const Color(0xFFF6F7FB),
        border: Border.all(color: const Color(0xFFE8EAF1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _QtyButton(
            icon: Icons.remove_rounded,
            onTap: onDecrement == null ? null : () => unawaited(onDecrement!()),
          ),
          SizedBox(
            width: 34,
            child: Center(
              child: Text(
                '$quantity',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1A1C22),
                ),
              ),
            ),
          ),
          _QtyButton(
            icon: Icons.add_rounded,
            onTap: onIncrement == null ? null : () => unawaited(onIncrement!()),
          ),
        ],
      ),
    );
  }
}

class _QtyButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _QtyButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        child: Icon(
          icon,
          size: 18,
          color: onTap == null
              ? const Color(0xFFB4BAC8)
              : const Color(0xFF3E4350),
        ),
      ),
    );
  }
}

class _GlassBlock extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;

  const _GlassBlock({required this.child, this.padding});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: padding ?? const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.88),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: const Color(0xFFE7EAF2)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x12000000),
                blurRadius: 28,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionTitle({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: Color(0xFF17181D),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w600,
            color: Color(0xFF757C8C),
          ),
        ),
      ],
    );
  }
}

class _SectionMiniHeader extends StatelessWidget {
  final String title;
  final String trailing;

  const _SectionMiniHeader({required this.title, required this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: Color(0xFF15171D),
          ),
        ),
        const Spacer(),
        Text(
          trailing,
          style: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: Color(0xFF8B91A1),
          ),
        ),
      ],
    );
  }
}

class _SelectableTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final String trailing;
  final bool selected;
  final VoidCallback onTap;
  final IconData leadingIcon;

  const _SelectableTile({
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.selected,
    required this.onTap,
    required this.leadingIcon,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: selected ? const Color(0xFFFF95A4) : const Color(0xFFE7EAF2),
            width: selected ? 1.4 : 1,
          ),
          gradient: selected
              ? const LinearGradient(
                  colors: [Color(0xFFFFF2E4), Color(0xFFFFEEF5)],
                )
              : null,
          color: selected ? null : Colors.white,
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFFF7F8FB),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                leadingIcon,
                size: 21,
                color: const Color(0xFF303646),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF15171D),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF7D8393),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  trailing,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF16181D),
                  ),
                ),
                const SizedBox(height: 6),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected
                          ? const Color(0xFFFF7DA0)
                          : const Color(0xFFC9CEDA),
                      width: 2,
                    ),
                    color: selected
                        ? const Color(0xFFFF7DA0)
                        : Colors.transparent,
                  ),
                  child: selected
                      ? const Icon(Icons.check, size: 11, color: Colors.white)
                      : null,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool strong;
  final Color? valueColor;

  const _SummaryRow({
    required this.label,
    required this.value,
    this.strong = false,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: strong ? 15.5 : 14.5,
            fontWeight: strong ? FontWeight.w800 : FontWeight.w700,
            color: strong ? const Color(0xFF15171D) : const Color(0xFF7B8190),
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: strong ? 21 : 15,
            fontWeight: strong ? FontWeight.w900 : FontWeight.w800,
            color: valueColor ?? const Color(0xFF15171D),
          ),
        ),
      ],
    );
  }
}

class _ToggleLine extends StatelessWidget {
  final bool value;
  final String title;
  final String subtitle;
  final ValueChanged<bool> onChanged;

  const _ToggleLine({
    required this.value,
    required this.title,
    required this.subtitle,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Switch.adaptive(value: value, onChanged: onChanged),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF15171D),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF80879A),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InfoBanner extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _InfoBanner({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFD),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE8ECF4)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, size: 20, color: const Color(0xFF2F5FA9)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF15171D),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 13.2,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF7C8291),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CheckoutBottomBar extends StatelessWidget {
  final double total;
  final int totalQuantity;
  final PaymentMode paymentMode;
  final VoidCallback onCheckout;
  final bool loading;

  const _CheckoutBottomBar({
    required this.total,
    required this.totalQuantity,
    required this.paymentMode,
    required this.loading,
    required this.onCheckout,
  });

  String get paymentLabel {
    switch (paymentMode) {
      case PaymentMode.card:
        return 'Carte bancaire';
      case PaymentMode.wallet:
        return 'Wallet';
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.90),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: const Color(0xFFE7EAF2)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x16000000),
                blurRadius: 30,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$totalQuantity article${totalQuantity > 1 ? 's' : ''} • $paymentLabel',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF7B8190),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${total.toStringAsFixed(2)} €',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF14161C),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              SizedBox(
                height: 58,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    gradient: const LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        Color(0xFFFFA24C),
                        Color(0xFFFF5CA6),
                        Color(0xFF7B81FF),
                      ],
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x33FF6A9B),
                        blurRadius: 20,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: loading ? null : onCheckout,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 22),
                    ),
                    child: Row(
                      children: [
                        if (loading)
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        else
                          const Icon(
                            Icons.lock_outline_rounded,
                            size: 18,
                            color: Colors.white,
                          ),
                        const SizedBox(width: 8),
                        const Text(
                          'Payer maintenant',
                          style: TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlassCircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _GlassCircleButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Material(
          color: Colors.white.withValues(alpha: 0.20),
          child: InkWell(
            onTap: onTap,
            child: SizedBox(
              width: 42,
              height: 42,
              child: Icon(icon, size: 19, color: const Color(0xFF17181D)),
            ),
          ),
        ),
      ),
    );
  }
}

class _SoftChip extends StatelessWidget {
  final String label;
  final BoxDecoration decoration;
  final Color textColor;

  const _SoftChip._({
    required this.label,
    required this.decoration,
    required this.textColor,
  });

  factory _SoftChip.soft(String label) {
    return _SoftChip._(
      label: label,
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8FB),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE7EAF2)),
      ),
      textColor: const Color(0xFF5F6676),
    );
  }

  factory _SoftChip.gradient(String label) {
    return _SoftChip._(
      label: label,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        gradient: const LinearGradient(
          colors: [Color(0xFFFFF0DF), Color(0xFFFFE7F1)],
        ),
      ),
      textColor: const Color(0xFF915218),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: decoration,
      alignment: Alignment.center,
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w800,
          color: textColor,
        ),
      ),
    );
  }
}

class _EmptyCheckoutView extends StatelessWidget {
  const _EmptyCheckoutView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Container(
          padding: const EdgeInsets.all(26),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: const Color(0xFFE9EAF0)),
          ),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.shopping_bag_outlined,
                size: 54,
                color: Color(0xFF9CA3AF),
              ),
              SizedBox(height: 14),
              Text(
                'Votre checkout est vide',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF14161B),
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Ajoutez des produits merch ou des contenus media pour continuer.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14.5,
                  height: 1.4,
                  color: Color(0xFF7B8190),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
