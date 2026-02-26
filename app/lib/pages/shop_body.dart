import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/product_model.dart';
import '../shop/widgets/product_tile.dart';
import 'storex_shop_page.dart';
import 'product_detail_page.dart';
import '../services/cart_service.dart';
import 'cart_page.dart';
import '../ui/snack/top_snack_bar.dart';

class ShopBodyUnderHeader extends StatefulWidget {
  const ShopBodyUnderHeader({
    super.key,
    this.initialChip = 0,
    this.category = 'Tous',
    this.groupId,
  });

  final int initialChip;
  final String category;
  final String? groupId;

  @override
  State<ShopBodyUnderHeader> createState() => _ShopBodyUnderHeaderState();
}

class _ShopBodyUnderHeaderState extends State<ShopBodyUnderHeader> {
  late int selectedChip = widget.initialChip;

  static const String _allGroupsId = 'all';
  static const String _allGroupsLabel = 'Tous les groupes';

  static const _fallbackCategories = <String>[
    'Tous',
    'T-shirts',
    'Casquettes',
    'Stickers',
  ];

  List<String> _categories = _fallbackCategories;

  late String _selectedGroupId = widget.groupId ?? _allGroupsId;

  Query<Map<String, dynamic>> _buildQuery() {
    Query<Map<String, dynamic>> q = FirebaseFirestore.instance
        .collectionGroup('products')
        .where('isActive', isEqualTo: true)
        .where('moderationStatus', isEqualTo: 'approved');

    // Filter by category
    final selectedCategory =
        _categories[selectedChip.clamp(0, _categories.length - 1)];
    if (selectedCategory != 'Tous') {
      q = q.where('category', isEqualTo: selectedCategory);
    }

    // Filter by group
    if (_selectedGroupId != _allGroupsId) {
      q = q.where('groupId', isEqualTo: _selectedGroupId);
    }

    return q.orderBy('updatedAt', descending: true).limit(50);
  }

  Query<Map<String, dynamic>> _buildCategoriesQuery() {
    Query<Map<String, dynamic>> q = FirebaseFirestore.instance
        .collectionGroup('products')
        .where('isActive', isEqualTo: true)
        .where('moderationStatus', isEqualTo: 'approved');

    if (_selectedGroupId != _allGroupsId) {
      q = q.where('groupId', isEqualTo: _selectedGroupId);
    }

    return q.orderBy('updatedAt', descending: true).limit(200);
  }

  List<String> _extractCategories(
    Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final set = <String>{};
    for (final d in docs) {
      final raw = d.data()['category'];
      final c = (raw is String) ? raw.trim() : '';
      if (c.isNotEmpty) set.add(c);
    }
    final list = set.toList()..sort();
    return ['Tous', ...list];
  }

  bool _listEquals(List<String> a, List<String> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  String _groupDropdownLabel() {
    if (_selectedGroupId == _allGroupsId) return _allGroupsLabel;
    return _selectedGroupId;
  }

  Future<void> _pickGroup() async {
    // Récupère une liste de groupId réellement présents.
    final groups = await _loadAvailableGroups();

    if (!mounted) return;

    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final g in groups)
                ListTile(
                  title: Text(g),
                  trailing: (g == _groupDropdownLabel())
                      ? const Icon(Icons.check_rounded)
                      : null,
                  onTap: () => Navigator.pop(context, g),
                ),
            ],
          ),
        );
      },
    );

    if (!mounted || choice == null) return;
    setState(() {
      _selectedGroupId = choice == _allGroupsLabel ? _allGroupsId : choice;
    });
  }

  Future<List<String>> _loadAvailableGroups() async {
    try {
      Query<Map<String, dynamic>> query = FirebaseFirestore.instance
          .collectionGroup('products')
          .where('isActive', isEqualTo: true)
          .where('moderationStatus', isEqualTo: 'approved')
          .orderBy('updatedAt', descending: true)
          .limit(200);

      // Si la page est déjà contextualisée sur un groupe, on garde une sélection cohérente
      // mais le dropdown doit proposer tous les groupes disponibles.
      final snap = await query.get();
      final set = <String>{};
      for (final d in snap.docs) {
        final raw = d.data()['groupId'];
        final g = (raw is String) ? raw.trim() : '';
        if (g.isNotEmpty) set.add(g);
      }

      final list = set.toList()..sort();
      return [_allGroupsLabel, ...list];
    } catch (_) {
      return const <String>[_allGroupsLabel, 'Akiyo', 'Kassav', 'MasK'];
    }
  }

  void _addMockToCart({
    required String id,
    required String title,
    required int priceCents,
    required String category,
    String? imagePath,
  }) {
    final product = GroupProduct(
      id: id,
      title: title.replaceAll('\n', ' '),
      priceCents: priceCents,
      imageUrl: '',
      imagePath: imagePath,
      category: category,
      isActive: true,
      moderationStatus: 'approved',
      stockByVariant: const {'default|default': 999},
      availableSizes: const ['Unique'],
      availableColors: const ['Default'],
    );

    CartService.instance.addProduct(
      groupId: _selectedGroupId,
      product: product,
      size: product.sizes.first,
      color: product.colors.first,
      quantity: 1,
    );

    TopSnackBar.show(
      context,
      SnackBar(
        content: Text('${product.title} ajouté au panier'),
        action: SnackBarAction(
          label: 'Voir',
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CartPage()),
          ),
        ),
      ),
    );
  }

  // Mock articles (kept for grid header display)
  final List<_ShopItem> items = const [
    _ShopItem(
      category: "T-shirts",
      title: "T-shirt MASLIVE\nPremium",
      price: "29€",
      imageAsset: "assets/images/maslivesmall.png",
    ),
    _ShopItem(
      category: "Casquettes",
      title: "Casquette Pastel",
      price: "24€",
      imageAsset: "assets/images/maslivesmall.png",
    ),
    _ShopItem(
      category: "Stickers",
      title: "Pack Stickers",
      price: "9€",
      imageAsset: "assets/images/maslivesmall.png",
    ),
    _ShopItem(
      category: "Accessoires",
      title: "Bracelet MASLIVE",
      price: "12€",
      imageAsset: "assets/images/maslivesmall.png",
    ),
    _ShopItem(
      category: "T-shirts",
      title: "T-shirt MASLIVE\nEdition Carnaval",
      price: "35€",
      imageAsset: "assets/images/maslivesmall.png",
    ),
  ];

  // ---------- TYPO SCALE (stable, premium) ----------
  double _fs(
    BuildContext context,
    double base, {
    double min = 0.95,
    double max = 1.10,
  }) {
    final w = MediaQuery.sizeOf(context).width;
    final s = (w / 390.0).clamp(min, max);
    return base * s;
  }

  @override
  Widget build(BuildContext context) {
    final h1 = TextStyle(
      fontSize: _fs(context, 18),
      fontWeight: FontWeight.w900,
      color: const Color(0xFF111827),
    );

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        // CHIPS
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _buildCategoriesQuery().snapshots(),
          builder: (context, snap) {
            final dynamicCats = (snap.hasData)
                ? _extractCategories(snap.data!.docs)
                : _fallbackCategories;

            if (!_listEquals(dynamicCats, _categories)) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                setState(() {
                  _categories = dynamicCats;
                  if (selectedChip >= _categories.length) selectedChip = 0;
                });
              });
            }

            return SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: _ChipsRow(
                  labels: _categories,
                  selected: selectedChip,
                  onChanged: (i) => setState(() => selectedChip = i),
                  fontSize: _fs(context, 16),
                ),
              ),
            );
          },
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 10)),

        // DROPDOWN "Tous les groupes"
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: _GroupDropdown(
              label: _groupDropdownLabel(),
              onTap: _pickGroup,
              fontSize: _fs(context, 18),
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 12)),

        // GRID 2 colonnes (carte bleue + carte produit + 2 produits)
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          sliver: SliverToBoxAdapter(
            child: LayoutBuilder(
              builder: (context, c) {
                final w = c.maxWidth;
                const gap = 10.0;
                final itemW = (w - gap) / 2;

                // Calibrage tailles (réduites)
                final bigH = itemW * 0.85;
                final smallH = itemW * 0.65;

                return Column(
                  children: [
                    Row(
                      children: [
                        SizedBox(
                          width: itemW,
                          height: bigH,
                          child: GestureDetector(
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const StorexShopPage(
                                    shopId: "global",
                                    groupId: "MASLIVE",
                                  ),
                                ),
                              );
                            },
                            child: _GalleryBlueCard(
                              imageAsset: "assets/images/maslivesmall.png",
                              fsTitle: _fs(context, 26),
                              fsLine: _fs(context, 16),
                              fsPill: _fs(context, 16),
                            ),
                          ),
                        ),
                        const SizedBox(width: gap),
                        SizedBox(
                          width: itemW,
                          height: bigH,
                          child: _ProductTileCard(
                            badge: "T-shirts",
                            title: "T-shirt MASLIVE\nPremium",
                            price: "29€",
                            imageAsset: "assets/images/maslivesmall.png",
                            imageUrl: null,
                            onAdd: () => _addMockToCart(
                              id: 'mock-tshirt-premium',
                              title: 'T-shirt MASLIVE Premium',
                              priceCents: 2900,
                              category: 'T-shirts',
                              imagePath: 'assets/images/maslivesmall.png',
                            ),
                            fsTitle: _fs(context, 18),
                            fsPrice: _fs(context, 18),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: gap),
                    Row(
                      children: [
                        SizedBox(
                          width: itemW,
                          height: smallH,
                          child: _ProductTileCard(
                            badge: "Casquettes",
                            title: "Casquette Pastel",
                            price: "24€",
                            imageAsset: "assets/images/maslivesmall.png",
                            imageUrl: null,
                            onAdd: () => _addMockToCart(
                              id: 'mock-casquette-pastel',
                              title: 'Casquette Pastel',
                              priceCents: 2400,
                              category: 'Casquettes',
                              imagePath: 'assets/images/maslivesmall.png',
                            ),
                            fsTitle: _fs(context, 18),
                            fsPrice: _fs(context, 18),
                          ),
                        ),
                        const SizedBox(width: gap),
                        SizedBox(
                          width: itemW,
                          height: smallH,
                          child: _ProductTileCard(
                            badge: "Stickers",
                            title: "Pack Stickers",
                            price: "9€",
                            imageAsset: "assets/images/maslivesmall.png",
                            imageUrl: null,
                            onAdd: () => _addMockToCart(
                              id: 'mock-pack-stickers',
                              title: 'Pack Stickers',
                              priceCents: 900,
                              category: 'Stickers',
                              imagePath: 'assets/images/maslivesmall.png',
                            ),
                            fsTitle: _fs(context, 18),
                            fsPrice: _fs(context, 18),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 18)),

        // LISTE D'ARTICLES (scroll vertical)
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverToBoxAdapter(
            child: Row(children: [Text("Articles", style: h1)]),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 10)),

        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _buildQuery().snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SliverToBoxAdapter(
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(),
                  ),
                ),
              );
            }

            final docs = snapshot.data?.docs ?? [];

            if (docs.isEmpty) {
              return SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: Column(
                      children: const [
                        Icon(
                          Icons.shopping_bag_outlined,
                          size: 64,
                          color: Colors.black26,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Aucun produit disponible',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            final products = docs
                .map((doc) => GroupProduct.fromMap(doc.id, doc.data()))
                .toList();

            return SliverPadding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 0.74,
                ),
                delegate: SliverChildBuilderDelegate((context, i) {
                  final product = products[i];

                  final isAvailable = (product.stockByVariant == null)
                      ? true
                      : product.stockByVariant!.values.any((s) => s > 0);

                  final options = <String>[];
                  if (product.availableSizes != null &&
                      product.availableSizes!.isNotEmpty) {
                    final sizes = product.availableSizes!;
                    options.add(
                      sizes.length == 1
                          ? sizes.first
                          : '${sizes.first}-${sizes.last}',
                    );
                  }
                  if (product.availableColors != null &&
                      product.availableColors!.isNotEmpty) {
                    final colors = product.availableColors!;
                    options.add(colors.take(2).join('/'));
                  }

                  return ProductTile(
                    heroTag: 'product-${product.id}',
                    data: ProductTileData(
                      title: product.title,
                      subtitle: product.category,
                      price: product.priceCents / 100.0,
                      currency: '€',
                      imageUrl: product.imageUrl,
                      isAvailable: isAvailable,
                      stockLabel: isAvailable ? 'En stock' : 'Rupture',
                      badges: [product.category],
                      options: options,
                    ),
                    onAdd: () {
                      final size = product.sizes.isNotEmpty
                          ? product.sizes.first
                          : 'Unique';
                      final color = product.colors.isNotEmpty
                          ? product.colors.first
                          : 'Default';

                      CartService.instance.addProduct(
                        groupId: _selectedGroupId,
                        product: product,
                        size: size,
                        color: color,
                        quantity: 1,
                      );
                      TopSnackBar.show(
                        context,
                        SnackBar(
                          content: Text('${product.title} ajouté au panier'),
                          action: SnackBarAction(
                            label: 'Voir',
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const CartPage(),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ProductDetailPage(
                            groupId: _selectedGroupId,
                            product: product,
                            heroTag: 'product-${product.id}',
                          ),
                        ),
                      );
                    },
                  );
                }, childCount: products.length),
              ),
            );
          },
        ),
      ],
    );
  }
}

/// ---------------------
/// CHIPS
/// ---------------------
class _ChipsRow extends StatelessWidget {
  const _ChipsRow({
    required this.labels,
    required this.selected,
    required this.onChanged,
    required this.fontSize,
  });

  final List<String> labels;
  final int selected;
  final ValueChanged<int> onChanged;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          for (int i = 0; i < labels.length; i++) ...[
            _ChipPill(
              label: labels[i],
              selected: selected == i,
              onTap: () => onChanged(i),
              fontSize: fontSize,
            ),
            const SizedBox(width: 10),
          ],
        ],
      ),
    );
  }
}

class _ChipPill extends StatelessWidget {
  const _ChipPill({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.fontSize,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final bg = selected
        ? const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFB36A), Color(0xFFFF6FB1)],
          )
        : null;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          gradient: bg,
          color: selected ? null : Colors.white.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? Colors.white.withValues(alpha: 0.40)
                : Colors.white.withValues(alpha: 0.60),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w800,
            color: selected ? const Color(0xFF121826) : const Color(0xFF374151),
          ),
        ),
      ),
    );
  }
}

/// ---------------------
/// DROPDOWN
/// ---------------------
class _GroupDropdown extends StatelessWidget {
  const _GroupDropdown({
    required this.label,
    required this.onTap,
    required this.fontSize,
  });

  final String label;
  final VoidCallback onTap;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        height: 54,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.70),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.75),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF121826),
              ),
            ),
            const Spacer(),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 28,
              color: const Color(0xFF121826).withValues(alpha: 0.55),
            ),
          ],
        ),
      ),
    );
  }
}

/// ---------------------
/// TILE - Galerie bleue
/// ---------------------
class _GalleryBlueCard extends StatelessWidget {
  const _GalleryBlueCard({
    required this.imageAsset,
    required this.fsTitle,
    required this.fsLine,
    required this.fsPill,
  });

  final String imageAsset;
  final double fsTitle;
  final double fsLine;
  final double fsPill;

  @override
  Widget build(BuildContext context) {
    return _SoftCard(
      radius: 30,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0E2A4A), Color(0xFF2F74FF)],
          ),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(-0.7, -0.8),
                    radius: 1.2,
                    colors: [Colors.white10, Colors.transparent],
                  ),
                ),
              ),
            ),
            Positioned(
              right: 12,
              bottom: 12,
              child: Opacity(
                opacity: 0.20,
                child: Image.asset(imageAsset, width: 56, height: 56),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _PillDark(
                    icon: Icons.photo_library_outlined,
                    label: "Galerie photos",
                    fontSize: fsPill,
                  ),
                  const SizedBox(height: 18),
                  _PillDarkPlain(label: "Photographes only", fontSize: fsPill),
                  const SizedBox(height: 14),
                  Text(
                    "Photos par les\nphotographes",
                    style: TextStyle(
                      fontSize: fsTitle,
                      height: 1.08,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "Filtre: Tous les groupes",
                    style: TextStyle(
                      fontSize: fsLine,
                      fontWeight: FontWeight.w700,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "Photos à venir",
                    style: TextStyle(
                      fontSize: fsLine,
                      fontWeight: FontWeight.w700,
                      color: Colors.white.withValues(alpha: 0.85),
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

/// ---------------------
/// TILE - Produit (dans la grille top)
/// ---------------------
class _ProductTileCard extends StatelessWidget {
  const _ProductTileCard({
    required this.badge,
    required this.title,
    required this.price,
    this.imageAsset,
    this.imageUrl,
    required this.onAdd,
    required this.fsTitle,
    required this.fsPrice,
  });

  final String badge;
  final String title;
  final String price;
  final String? imageAsset;
  final String? imageUrl;
  final VoidCallback onAdd;
  final double fsTitle;
  final double fsPrice;

  Widget _thumbLocal({
    required BuildContext context,
    String? imageUrl,
    String? imageAsset,
  }) {
    if (imageUrl != null && imageUrl.trim().isNotEmpty) {
      return Image.network(
        imageUrl,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.high,
        errorBuilder: (context, error, stackTrace) => Container(
          color: const Color(0xFFF1F3F8),
          child: const Center(
            child: Icon(
              Icons.broken_image_outlined,
              color: Colors.black26,
              size: 34,
            ),
          ),
        ),
      );
    }
    return Container(
      color: const Color(0xFFF1F3F8),
      child: Center(
        child: Image.asset(
          imageAsset ?? 'assets/images/maslivesmall.png',
          width: 58,
          height: 58,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 18,
            offset: const Offset(0, 8),
            spreadRadius: 0,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  flex: 6,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(30),
                    ),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: _thumbLocal(
                            context: context,
                            imageUrl: imageUrl,
                            imageAsset: imageAsset,
                          ),
                        ),
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.black.withValues(alpha: 0.00),
                                  Colors.black.withValues(alpha: 0.06),
                                  Colors.black.withValues(alpha: 0.10),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  flex: 7,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _BadgeLight(label: badge),
                        const Spacer(),
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: fsTitle,
                            height: 1.12,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF121826),
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          price,
                          style: TextStyle(
                            fontSize: fsPrice,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF121826),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            Positioned(right: 14, bottom: 14, child: _AddButton(onTap: onAdd)),
          ],
        ),
      ),
    );
    return content;
  }
}

/// ---------------------
/// UI helpers
/// ---------------------
class _AddButton extends StatelessWidget {
  const _AddButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFF7BB7), Color(0xFF74C9FF)],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 14,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 26),
      ),
    );
  }
}

class _SoftCard extends StatelessWidget {
  const _SoftCard({required this.child, this.radius = 26});

  final Widget child;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: child,
      ),
    );
  }
}

class _PillDark extends StatelessWidget {
  const _PillDark({
    required this.icon,
    required this.label,
    required this.fontSize,
  });

  final IconData icon;
  final String label;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.22),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: Colors.white.withValues(alpha: 0.95)),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w900,
              color: Colors.white.withValues(alpha: 0.95),
            ),
          ),
        ],
      ),
    );
  }
}

class _PillDarkPlain extends StatelessWidget {
  const _PillDarkPlain({required this.label, required this.fontSize});
  final String label;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.16),
              width: 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w900,
              color: Colors.white.withValues(alpha: 0.92),
            ),
          ),
        ),
      ),
    );
  }
}

class _BadgeLight extends StatelessWidget {
  const _BadgeLight({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F3F8).withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFDDE2EE), width: 1),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w900,
          color: Color(0xFF2B3445),
        ),
      ),
    );
  }
}

/// ---------------------
/// Model mock
/// ---------------------
class _ShopItem {
  final String category;
  final String title;
  final String price;
  final String imageAsset;

  const _ShopItem({
    required this.category,
    required this.title,
    required this.price,
    required this.imageAsset,
  });
}
