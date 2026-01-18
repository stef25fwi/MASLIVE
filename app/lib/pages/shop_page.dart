import 'package:flutter/material.dart';

import '../ui/theme/maslive_theme.dart';
import '../ui/widgets/gradient_header.dart';
import '../ui/widgets/honeycomb_background.dart';
import '../ui/widgets/maslive_card.dart';

class ShopUiPage extends StatefulWidget {
  const ShopUiPage({super.key, this.groupId});

  final String? groupId;

  @override
  State<ShopUiPage> createState() => _ShopPageState();
}

class _ShopPageState extends State<ShopUiPage> {
  String _category = 'Tous';

  @override
  Widget build(BuildContext context) {
    final products = _MockProduct.sample.where((p) {
      if (_category == 'Tous') return true;
      return p.category == _category;
    }).toList();

    return Scaffold(
      body: HoneycombBackground(
        opacity: 0.08,
        child: Column(
          children: [
            MasliveGradientHeader(
              height: 220,
              padding: const EdgeInsets.fromLTRB(16, 48, 16, 16),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back_ios_new_rounded),
                        color: MasliveTheme.textPrimary,
                      ),
                      const Spacer(),
                      Text(
                        widget.groupId == null ? 'Shop' : 'Shop du groupe',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w900,
                              color: MasliveTheme.textPrimary,
                            ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Recherche (mock)')),
                          );
                        },
                        icon: const Icon(Icons.search_rounded),
                        color: MasliveTheme.textPrimary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _CategoryRow(
                    selected: _category,
                    onSelected: (c) => setState(() => _category = c),
                  ),
                  const SizedBox(height: 12),
                  MasliveCard(
                    radius: 22,
                    child: Row(
                      children: [
                        const Icon(Icons.local_shipping_outlined, color: MasliveTheme.textPrimary),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Livraison 24–48h · Retours gratuits (mock)',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: MasliveTheme.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ),
                        TextButton(
                          onPressed: () {},
                          child: const Text('Infos'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
                child: GridView.builder(
                  itemCount: products.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.76,
                  ),
                  itemBuilder: (context, i) {
                    return _ProductCard(product: products[i]);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelected;

  const _CategoryRow({
    required this.selected,
    required this.onSelected,
  });

  static const _cats = <String>['Tous', 'T-shirts', 'Casquettes', 'Stickers', 'Accessoires'];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _cats.map((c) {
          final isSelected = c == selected;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              onTap: () => onSelected(c),
              borderRadius: BorderRadius.circular(MasliveTheme.rPill),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(MasliveTheme.rPill),
                  color: isSelected ? const Color(0x14FF6BB5) : MasliveTheme.surface,
                  border: Border.all(color: MasliveTheme.divider),
                  boxShadow: isSelected ? MasliveTheme.cardShadow : null,
                ),
                child: Text(
                  c,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: isSelected ? MasliveTheme.textPrimary : MasliveTheme.textSecondary,
                      ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final _MockProduct product;

  const _ProductCard({required this.product});

  @override
  Widget build(BuildContext context) {
    return MasliveCard(
      radius: 22,
      padding: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () {
          showModalBottomSheet<void>(
            context: context,
            backgroundColor: Colors.transparent,
            builder: (context) {
              return _ProductSheet(product: product);
            },
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset(
                      product.imageAsset,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(color: MasliveTheme.surfaceAlt),
                    ),
                    Positioned(
                      left: 10,
                      top: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.86),
                          borderRadius: BorderRadius.circular(MasliveTheme.rPill),
                          border: Border.all(color: MasliveTheme.divider),
                        ),
                        child: Text(
                          product.category,
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                fontWeight: FontWeight.w900,
                                color: MasliveTheme.textPrimary,
                              ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: MasliveTheme.textPrimary,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(
                        product.priceLabel,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                      const Spacer(),
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          gradient: MasliveTheme.actionGradient,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: MasliveTheme.cardShadow,
                        ),
                        child: const Icon(Icons.add_rounded, color: Colors.white),
                      ),
                    ],
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

class _ProductSheet extends StatelessWidget {
  final _MockProduct product;

  const _ProductSheet({required this.product});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.92),
          borderRadius: BorderRadius.circular(24),
          boxShadow: MasliveTheme.floatingShadow,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    product.name,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(product.description, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: MasliveTheme.textSecondary)),
            const SizedBox(height: 14),
            Row(
              children: [
                Text(product.priceLabel, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                const Spacer(),
                FilledButton(
                  style: FilledButton.styleFrom(
                    shape: const StadiumBorder(),
                    backgroundColor: MasliveTheme.pink,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Ajouté au panier (mock)')),
                    );
                  },
                  child: const Text('Ajouter'),
                )
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MockProduct {
  final String name;
  final String category;
  final String priceLabel;
  final String imageAsset;
  final String description;

  const _MockProduct({
    required this.name,
    required this.category,
    required this.priceLabel,
    required this.imageAsset,
    required this.description,
  });

  static const sample = <_MockProduct>[
    _MockProduct(
      name: 'T-shirt MASLIVE Premium',
      category: 'T-shirts',
      priceLabel: '29€',
      imageAsset: 'assets/splash/maslivepink.png',
      description: 'Coupe oversize, coton doux, logo discret. Edition mock.',
    ),
    _MockProduct(
      name: 'Casquette Pastel',
      category: 'Casquettes',
      priceLabel: '24€',
      imageAsset: 'assets/splash/maslivepinky.png',
      description: 'Visière courbe, broderie premium, look clean.',
    ),
    _MockProduct(
      name: 'Pack Stickers',
      category: 'Stickers',
      priceLabel: '9€',
      imageAsset: 'assets/splash/maslivesmall.png',
      description: 'Stickers résistants, finition mate, 6 pièces.',
    ),
    _MockProduct(
      name: 'Porte-clés Honeycomb',
      category: 'Accessoires',
      priceLabel: '12€',
      imageAsset: 'assets/splash/maslive.png',
      description: 'Texture honeycomb, accroche solide, style premium.',
    ),
  ];
}
