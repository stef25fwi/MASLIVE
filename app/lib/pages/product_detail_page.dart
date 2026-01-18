import 'package:flutter/material.dart';
import '../models/group_product.dart';
import '../services/cart_service.dart';
import 'cart_page.dart';
import '../widgets/honeycomb_background.dart';
import '../widgets/rainbow_header.dart';

class ProductDetailPage extends StatefulWidget {
  final String groupId;
  final GroupProduct product;

  const ProductDetailPage({
    super.key,
    required this.groupId,
    required this.product,
  });

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  String size = 'M';
  String color = 'Noir';

  static const _bg = Color(0xFFF4F5F8);

  Widget _productImageGallery(GroupProduct p) {
    final urls = <String>[
      if (p.imageUrl.isNotEmpty) p.imageUrl,
      if ((p.imageUrl2 ?? '').isNotEmpty) p.imageUrl2!,
    ];

    if (urls.isEmpty) {
      return Container(color: Colors.black.withValues(alpha: 0.06));
    }

    if (urls.length == 1) {
      return Image.network(urls.first, fit: BoxFit.cover);
    }

    return PageView.builder(
      itemCount: urls.length,
      itemBuilder: (context, i) {
        return Image.network(urls[i], fit: BoxFit.cover);
      },
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
                          child: _productImageGallery(p),
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
                            choices: const ['XS', 'S', 'M', 'L', 'XL'],
                            onPick: (v) => setState(() => size = v),
                          ),
                          const SizedBox(height: 10),
                          _rowSelector(
                            label: 'Couleur',
                            value: color,
                            choices: const ['Noir', 'Blanc', 'Gris'],
                            onPick: (v) => setState(() => color = v),
                          ),
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
            text: 'Ajouter',
            onTap: () {
              CartService.instance.addProduct(
                groupId: widget.groupId,
                product: p,
                size: size,
                color: color,
              );

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Ajouté: ${p.title} ($size, $color)'),
                  action: SnackBarAction(
                    label: 'Panier',
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const CartPage()),
                      );
                    },
                  ),
                ),
              );
            },
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
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: on ? Colors.white : const Color(0xFFF0F2F6),
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: on
                        ? [
                            BoxShadow(
                              blurRadius: 12,
                              offset: const Offset(0, 8),
                              color: Colors.black.withValues(alpha: 0.08),
                            )
                          ]
                        : null,
                  ),
                  child: Text(
                    c,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: on ? const Color(0xFF1A73E8) : Colors.black.withValues(alpha: 0.60),
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

  Widget _gradientButton({required String text, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFFFE36A),
              Color(0xFFFF7BC5),
              Color(0xFF7CE0FF),
            ],
          ),
          boxShadow: [
            BoxShadow(
              blurRadius: 16,
              offset: const Offset(0, 10),
              color: Colors.black.withValues(alpha: 0.12),
            ),
          ],
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
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
          child: Icon(icon, size: 22, color: Colors.black.withValues(alpha: 0.75)),
        ),
      ),
    );
  }
}
