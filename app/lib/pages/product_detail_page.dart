import 'package:flutter/material.dart';
import '../models/group_product.dart';
import '../services/cart_service.dart';
import 'cart_page.dart';
import '../widgets/honeycomb_background.dart';
import '../widgets/rainbow_header.dart';

class ProductDetailPage extends StatefulWidget {
  final String groupId;
  final GroupProduct product;
  final String? heroTag;

  const ProductDetailPage({
    super.key,
    required this.groupId,
    required this.product,
    this.heroTag,
  });

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  String size = 'M';
  String color = 'Noir';
  int quantity = 1; // Nouvelle variable pour la quantité

  final PageController _galleryController = PageController();
  int _galleryIndex = 0;

  static const _bg = Color(0xFFF4F5F8);

  @override
  void initState() {
    super.initState();
    // Initialiser avec les valeurs par défaut du produit
    size = widget.product.sizes.isNotEmpty
        ? widget.product.sizes.first
        : 'Unique';
    color = widget.product.colors.isNotEmpty
        ? widget.product.colors.first
        : 'Default';
  }

  @override
  void dispose() {
    _galleryController.dispose();
    super.dispose();
  }

  Widget _productImageGallery(GroupProduct p) {
    // Vérifier si c'est un asset local
    if (p.imagePath != null && p.imagePath!.isNotEmpty) {
      return Image.asset(
        p.imagePath!,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) =>
            Image.asset('assets/splash/maslivesmall.png', fit: BoxFit.contain),
      );
    }

    // URLs réseau
    final urls = <String>[
      if (p.imageUrl.isNotEmpty) p.imageUrl,
      if ((p.imageUrl2 ?? '').isNotEmpty) p.imageUrl2!,
    ];

    if (urls.isEmpty) {
      return Image.asset('assets/splash/maslivesmall.png', fit: BoxFit.contain);
    }

    if (urls.length == 1) {
      final u = urls.first;
      if (u.startsWith('assets/')) {
        return Image.asset(
          u,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) =>
              Image.asset('assets/splash/maslivesmall.png', fit: BoxFit.contain),
        );
      }
      return Image.network(
        u,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) =>
            Image.asset('assets/splash/maslivesmall.png', fit: BoxFit.contain),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        PageView.builder(
          controller: _galleryController,
          itemCount: urls.length,
          onPageChanged: (i) => setState(() => _galleryIndex = i),
          itemBuilder: (context, i) {
            final u = urls[i];
            if (u.startsWith('assets/')) {
              return Image.asset(
                u,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => Image.asset(
                  'assets/splash/maslivesmall.png',
                  fit: BoxFit.contain,
                ),
              );
            }
            return Image.network(
              u,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => Image.asset(
                'assets/splash/maslivesmall.png',
                fit: BoxFit.contain,
              ),
            );
          },
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 10,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(urls.length, (i) {
              final selected = i == _galleryIndex;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: selected ? 18 : 7,
                height: 7,
                decoration: BoxDecoration(
                  color: selected
                      ? Colors.white.withValues(alpha: 0.95)
                      : Colors.white.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      blurRadius: 8,
                      color: Colors.black.withValues(alpha: 0.20),
                    ),
                  ],
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;

    return Scaffold(
      backgroundColor: _bg,
      body: HoneycombBackground(
        child: Column(
          children: [
            RainbowHeader(
              title: 'Shop',
              height: 155,
              trailing: _circleIcon(
                icon: Icons.close_rounded,
                onTap: () => Navigator.pop(context),
              ),
            ),
            Expanded(
              child: Transform.translate(
                offset: const Offset(0, -14),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 120),
                  children: [
                    // Carte image
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            blurRadius: 18,
                            offset: const Offset(0, 10),
                            color: Colors.black.withValues(alpha: 0.06),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: AspectRatio(
                          aspectRatio: 1.08,
                          child: widget.heroTag == null
                              ? _productImageGallery(p)
                              : Hero(
                                  tag: widget.heroTag!,
                                  child: _productImageGallery(p),
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Infos produit
                    _card(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p.title,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            p.priceLabel,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Produit officiel du groupe • Qualité premium',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: Colors.black.withValues(alpha: 0.55),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Options
                    _card(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Options',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 10),
                          _rowSelector(
                            label: 'Taille',
                            value: size,
                            choices: p.sizes,
                            onPick: (v) => setState(() {
                              size = v;
                              quantity = 1; // Reset quantité lors du changement
                            }),
                          ),
                          const SizedBox(height: 10),
                          _rowSelector(
                            label: 'Couleur',
                            value: color,
                            choices: p.colors,
                            onPick: (v) => setState(() {
                              color = v;
                              quantity = 1; // Reset quantité lors du changement
                            }),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Stock et Quantité
                    _card(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text(
                                'Disponibilité',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(width: 8),
                              _StockPill(stock: p.stockFor(size, color)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            p.stockFor(size, color) > 0
                                ? '${p.stockFor(size, color)} disponible(s) pour $size / $color'
                                : 'Rupture de stock pour $size / $color',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: p.stockFor(size, color) > 0
                                  ? const Color(0xFF0F766E)
                                  : const Color(0xFFB42318),
                            ),
                          ),
                          if (p.stockFor(size, color) > 0) ...[
                            const SizedBox(height: 12),
                            const Text(
                              'Quantité',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 8),
                            _QtySelector(
                              value: quantity,
                              max: p.stockFor(size, color),
                              onChanged: (v) => setState(() => quantity = v),
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Description
                    _card(
                      child: Text(
                        'Description du produit…\n'
                        '• Impression HD\n'
                        '• Coupe unisexe\n'
                        '• Livraison locale / retrait possible',
                        style: TextStyle(
                          fontSize: 14.5,
                          height: 1.35,
                          fontWeight: FontWeight.w700,
                          color: Colors.black.withValues(alpha: 0.72),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),

      // Bottom “sticky” achat
      bottomSheet: _buyBar(context, p),
    );
  }

  Widget _buyBar(BuildContext context, GroupProduct p) {
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
                Text(
                  p.priceLabel,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Taille $size • $color',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.black.withValues(alpha: 0.55),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _gradientButton(
            text: p.stockFor(size, color) > 0
                ? 'Ajouter ($quantity)'
                : 'Indisponible',
            onTap: p.stockFor(size, color) > 0
                ? () {
                    if (quantity > p.stockFor(size, color)) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('❌ Quantité indisponible'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }

                    CartService.instance.addProduct(
                      groupId: widget.groupId,
                      product: p,
                      size: size,
                      color: color,
                      quantity: quantity, // Utiliser la quantité sélectionnée
                    );

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          '✅ Ajouté: $quantity x ${p.title} ($size, $color)',
                        ),
                        backgroundColor: const Color(0xFF0F766E),
                        action: SnackBarAction(
                          label: 'Panier',
                          textColor: Colors.white,
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const CartPage(),
                              ),
                            );
                          },
                        ),
                      ),
                    );

                    // Reset quantité après ajout
                    setState(() => quantity = 1);
                  }
                : null,
          ),
        ],
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            blurRadius: 18,
            offset: const Offset(0, 10),
            color: Colors.black.withValues(alpha: 0.06),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _rowSelector({
    required String label,
    required String value,
    required List<String> choices,
    required ValueChanged<String> onPick,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 78,
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: Colors.black.withValues(alpha: 0.75),
            ),
          ),
        ),
        Expanded(
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: choices.map((c) {
              final on = c == value;
              return InkWell(
                borderRadius: BorderRadius.circular(22),
                onTap: () => onPick(c),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: on ? Colors.white : const Color(0xFFF0F2F6),
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: on
                        ? [
                            BoxShadow(
                              blurRadius: 12,
                              offset: const Offset(0, 8),
                              color: Colors.black.withValues(alpha: 0.08),
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    c,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: on
                          ? const Color(0xFF1A73E8)
                          : Colors.black.withValues(alpha: 0.60),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _gradientButton({required String text, VoidCallback? onTap}) {
    final enabled = onTap != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: enabled
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFFFE36A),
                    Color(0xFFFF7BC5),
                    Color(0xFF7CE0FF),
                  ],
                )
              : LinearGradient(
                  colors: [Colors.grey.shade300, Colors.grey.shade400],
                ),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    blurRadius: 16,
                    offset: const Offset(0, 10),
                    color: Colors.black.withValues(alpha: 0.12),
                  ),
                ]
              : null,
        ),
        child: Text(
          text,
          style: TextStyle(
            color: enabled ? Colors.white : Colors.grey.shade600,
            fontWeight: FontWeight.w900,
            fontSize: 15,
          ),
        ),
      ),
    );
  }

  Widget _circleIcon({required IconData icon, VoidCallback? onTap}) {
    return Material(
      color: Colors.white.withValues(alpha: 0.92),
      shape: const CircleBorder(),
      elevation: 6,
      shadowColor: Colors.black.withValues(alpha: 0.15),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(
            icon,
            size: 22,
            color: Colors.black.withValues(alpha: 0.75),
          ),
        ),
      ),
    );
  }
}

// Widgets pour gestion stock et quantité
class _StockPill extends StatelessWidget {
  const _StockPill({required this.stock});
  final int stock;

  @override
  Widget build(BuildContext context) {
    final ok = stock > 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: ok ? const Color(0xFFD1FAE5) : const Color(0xFFFEE4E2),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        ok ? 'En stock' : 'Rupture',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w900,
          color: ok ? const Color(0xFF065F46) : const Color(0xFF7A271A),
        ),
      ),
    );
  }
}

class _QtySelector extends StatelessWidget {
  const _QtySelector({
    required this.value,
    required this.max,
    required this.onChanged,
  });

  final int value;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _QtyBtn(
          icon: Icons.remove_rounded,
          onTap: value > 1 ? () => onChanged(value - 1) : null,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
            ),
            child: Text(
              '$value',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
            ),
          ),
        ),
        const SizedBox(width: 10),
        _QtyBtn(
          icon: Icons.add_rounded,
          onTap: value < max ? () => onChanged(value + 1) : null,
        ),
      ],
    );
  }
}

class _QtyBtn extends StatelessWidget {
  const _QtyBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: onTap == null
              ? Colors.black.withValues(alpha: 0.04)
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
        ),
        child: Icon(
          icon,
          color: onTap == null ? Colors.black26 : Colors.black87,
          size: 20,
        ),
      ),
    );
  }
}
