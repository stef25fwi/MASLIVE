import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/cart_provider.dart';
import '../checkout/maslive_ultra_premium_checkout_page.dart';
import '../../widgets/cart/cart_item_tile.dart';
import '../../widgets/cart/cart_summary_card.dart';
import '../../widgets/cart/empty_cart_view.dart';

class UnifiedCartPage extends StatefulWidget {
  const UnifiedCartPage({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<UnifiedCartPage> createState() => _UnifiedCartPageState();
}

class _UnifiedCartPageState extends State<UnifiedCartPage> {
  bool _animateIn = false;

  static const LinearGradient _premiumHeaderGradient = LinearGradient(
    colors: <Color>[
      Color(0xFFFFE36A),
      Color(0xFFFF8ACD),
      Color(0xFF98E4FF),
      Color(0xFFB8FFDA),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _animateIn = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final currency = cart.items.isNotEmpty ? cart.items.first.currency : 'EUR';

    Widget body;
    if (cart.loading && cart.items.isEmpty) {
      body = const Center(child: CircularProgressIndicator());
    } else if (cart.isEmpty) {
      body = EmptyCartView(
        onContinueShopping: () => Navigator.of(context).maybePop(),
      );
    } else {
      body = ListView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          widget.embedded ? 8 : 18,
          16,
          widget.embedded ? 8 : 18,
          widget.embedded ? 24 : 14,
        ),
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
            _reveal(
              index: 0,
              child: _PremiumCartSection(
                title: 'Merch',
                subtitle: 'Produits physiques et variantes.',
                clearLabel: 'Vider',
                onClear: cart.clearMerch,
                child: Column(
                  children: cart.merchItems
                      .map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: CartItemTile(
                            item: item,
                            onRemove: () => cart.removeCartItem(item.id),
                            onIncrement: () => cart.incrementItem(item.id),
                            onDecrement: () => cart.decrementItem(item.id),
                          ),
                        ),
                      )
                      .toList(growable: false),
                ),
              ),
            ),
          if (cart.mediaItems.isNotEmpty)
            _reveal(
              index: 1,
              child: _PremiumCartSection(
                title: 'Media',
                subtitle: 'Produits digitaux et contenus marketplace.',
                clearLabel: 'Vider',
                onClear: cart.clearMedia,
                child: Column(
                  children: cart.mediaItems
                      .map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: CartItemTile(
                            item: item,
                            onRemove: () => cart.removeCartItem(item.id),
                          ),
                        ),
                      )
                      .toList(growable: false),
                ),
              ),
            ),
          if (widget.embedded)
            _reveal(
              index: 2,
              child: CartSummaryCard(
                merchSubtotal: cart.merchSubtotal,
                mediaSubtotal: cart.mediaSubtotal,
                grandTotal: cart.grandTotal,
                currency: currency,
                enabled: !cart.isEmpty,
                onCheckout: () => _handleCheckout(context, cart),
                checkoutLabel:
                    cart.mediaCheckoutItems.isNotEmpty &&
                        cart.merchCheckoutItems.isNotEmpty
                    ? 'Continuer vers checkout'
                    : 'Continuer',
              ),
            ),
        ],
      );
    }

    if (widget.embedded) {
      return body;
    }

    final checkoutLabel = cart.mediaCheckoutItems.isNotEmpty &&
            cart.merchCheckoutItems.isNotEmpty
        ? 'Continuer vers checkout'
        : 'Continuer';

    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F9),
      body: Column(
        children: <Widget>[
          _CartHeader(
            onBack: () => Navigator.of(context).maybePop(),
            onClearAll: cart.clearCart,
            canClear: !cart.isEmpty,
          ),
          Expanded(child: body),
          _CartBottomSummary(
            totalLabel: 'Total',
            totalValue: '${cart.grandTotal.toStringAsFixed(2)} ${currency.toUpperCase()}',
            buttonLabel: checkoutLabel,
            onPressed: () => _handleCheckout(context, cart),
            enabled: !cart.isEmpty,
          ),
        ],
      ),
    );
  }

  Widget _reveal({required int index, required Widget child}) {
    final delayMs = 90 * index;
    return AnimatedSlide(
      offset: _animateIn ? Offset.zero : const Offset(0, 0.08),
      duration: Duration(milliseconds: 340 + delayMs),
      curve: Curves.easeOutCubic,
      child: AnimatedOpacity(
        opacity: _animateIn ? 1 : 0,
        duration: Duration(milliseconds: 260 + delayMs),
        curve: Curves.easeOutCubic,
        child: child,
      ),
    );
  }

  Future<void> _handleCheckout(
    BuildContext context,
    CartProvider cart,
  ) async {
    if (cart.checkoutEligibleItems.isEmpty) {
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const MasliveUltraPremiumCheckoutPage(),
      ),
    );
  }
}

class _CartHeader extends StatelessWidget {
  const _CartHeader({
    required this.onBack,
    required this.onClearAll,
    required this.canClear,
  });

  final VoidCallback onBack;
  final VoidCallback onClearAll;
  final bool canClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(top: 54, left: 18, right: 18, bottom: 18),
      decoration: const BoxDecoration(
        gradient: _UnifiedCartPageState._premiumHeaderGradient,
      ),
      child: Row(
        children: <Widget>[
          _HeaderIconButton(
            icon: Icons.arrow_back_ios_new_rounded,
            onTap: onBack,
          ),
          const Expanded(
            child: Center(
              child: Text(
                'Panier',
                style: TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1A2240),
                  letterSpacing: -0.8,
                ),
              ),
            ),
          ),
          GestureDetector(
            onTap: canClear ? onClearAll : null,
            child: Opacity(
              opacity: canClear ? 1 : 0.5,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                child: Text(
                  'Tout vider',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A2240),
                    letterSpacing: -0.3,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: SizedBox(
        width: 42,
        height: 42,
        child: Icon(
          icon,
          size: 22,
          color: const Color(0xFF1A2240),
        ),
      ),
    );
  }
}

class _PremiumCartSection extends StatelessWidget {
  const _PremiumCartSection({
    required this.title,
    required this.subtitle,
    required this.clearLabel,
    required this.onClear,
    required this.child,
  });

  final String title;
  final String subtitle;
  final String clearLabel;
  final VoidCallback onClear;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFC),
        borderRadius: BorderRadius.circular(34),
        border: Border.all(
          color: const Color(0xFFE6E8F0),
          width: 1.1,
        ),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x100F172A),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF17234A),
                        letterSpacing: -0.8,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF8A92A8),
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: onClear,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
                  child: Text(
                    clearLabel,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFA27182),
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _CartBottomSummary extends StatelessWidget {
  const _CartBottomSummary({
    required this.totalLabel,
    required this.totalValue,
    required this.buttonLabel,
    required this.onPressed,
    required this.enabled,
  });

  final String totalLabel;
  final String totalValue;
  final String buttonLabel;
  final VoidCallback onPressed;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(34),
        ),
        border: Border.all(color: const Color(0xFFE9ECF3)),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x120F172A),
            blurRadius: 22,
            offset: Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Row(
              children: <Widget>[
                Text(
                  totalLabel,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF8A92A8),
                  ),
                ),
                const Spacer(),
                Text(
                  totalValue,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF17234A),
                    letterSpacing: -0.8,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 58,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  gradient: LinearGradient(
                    colors: enabled
                        ? const <Color>[
                            Color(0xFFF7C16E),
                            Color(0xFFF090D4),
                            Color(0xFF91B9FF),
                          ]
                        : const <Color>[
                            Color(0xFFE5E7EB),
                            Color(0xFFD1D5DB),
                          ],
                  ),
                  boxShadow: const <BoxShadow>[
                    BoxShadow(
                      color: Color(0x22000000),
                      blurRadius: 14,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: enabled ? onPressed : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    disabledBackgroundColor: Colors.transparent,
                    disabledForegroundColor: const Color(0xFF6B7280),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(22),
                    ),
                  ),
                  child: Text(
                    buttonLabel,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF17234A),
                      letterSpacing: -0.4,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
