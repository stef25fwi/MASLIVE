import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'cart_page.dart';
import 'media_shop_wrapper.dart';
import 'product_detail_page.dart';
import '../models/group_product.dart';
import '../services/cart_service.dart';
import '../shop/widgets/product_tile.dart';

class ShopPixelPerfectPage extends StatefulWidget {
  const ShopPixelPerfectPage({super.key, this.shopId});

  /// Optionnel: si fourni, filtre les articles de ce shop.
  final String? shopId;

  @override
  State<ShopPixelPerfectPage> createState() => _ShopPixelPerfectPageState();
}

class _ShopPixelPerfectPageState extends State<ShopPixelPerfectPage> {
  bool _listEquals(List<String> a, List<String> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  int catIndex = 0;
  String selectedGroup = "Tous les groupes";

  static const String _allGroupsLabel = 'Tous les groupes';

  static const _bg = Color(0xFFF6F7FB);

  // Compact (comme ton mockup)
  static const double _pageHPad = 10;
  static const double _gridGap = 8;

  static const double _headerH = 190; // hauteur header (légèrement augmentée)
  static const double _filtersPinnedH = 78; // chips + dropdown plus bas

  static const double _cardRadius = 24;
  static const double _innerRadius = 18;

  static const double _addSize = 44;
  static const double _addRadius = 16;

  // Fallback (aligné avec l'admin) si Firestore ne renvoie rien.
  static const _fallbackCats = <String>[
    "Tous",
    "Vêtements",
    "Accessoires",
    "Nourriture",
    "Boissons",
    "Souvenirs",
    "Artisanat",
    "Autre",
  ];

  List<String> _cats = _fallbackCats;

  // Groupes (si le champ Firestore `groupId` est renseigné)
  static const _fallbackGroups = <String>[
    _allGroupsLabel,
    'Akiyo',
    'Kassav',
    'MasK',
  ];

  @override
  void initState() {
    super.initState();
    CartService.instance.start();
  }

  Query<Map<String, dynamic>> _buildProductsQuery() {
    Query<Map<String, dynamic>> query = FirebaseFirestore.instance
        .collectionGroup('products')
        .where('isActive', isEqualTo: true)
        .where('moderationStatus', isEqualTo: 'approved');

    final selectedCat = _cats[catIndex.clamp(0, _cats.length - 1)];
    if (selectedCat != 'Tous') {
      query = query.where('category', isEqualTo: selectedCat);
    }

    if (widget.shopId != null && widget.shopId!.trim().isNotEmpty) {
      query = query.where('shopId', isEqualTo: widget.shopId);
    }

    if (selectedGroup != _allGroupsLabel) {
      query = query.where('groupId', isEqualTo: selectedGroup);
    }

    return query.orderBy('updatedAt', descending: true).limit(60);
  }

  Query<Map<String, dynamic>> _buildCategoriesQuery() {
    Query<Map<String, dynamic>> query = FirebaseFirestore.instance
        .collectionGroup('products')
        .where('isActive', isEqualTo: true)
        .where('moderationStatus', isEqualTo: 'approved');

    if (widget.shopId != null && widget.shopId!.trim().isNotEmpty) {
      query = query.where('shopId', isEqualTo: widget.shopId);
    }

    if (selectedGroup != _allGroupsLabel) {
      query = query.where('groupId', isEqualTo: selectedGroup);
    }

    return query.orderBy('updatedAt', descending: true).limit(200);
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
    final cats = set.toList()..sort();
    return ['Tous', ...cats];
  }

  Query<Map<String, dynamic>> _buildGroupsQuery() {
    Query<Map<String, dynamic>> query = FirebaseFirestore.instance
        .collectionGroup('products')
        .where('isActive', isEqualTo: true)
        .where('moderationStatus', isEqualTo: 'approved');

    // Les groupes proposés doivent rester cohérents avec le shop sélectionné.
    if (widget.shopId != null && widget.shopId!.trim().isNotEmpty) {
      query = query.where('shopId', isEqualTo: widget.shopId);
    }

    // On lit un échantillon récent et on déduplique.
    return query.orderBy('updatedAt', descending: true).limit(200);
  }

  List<String> _extractGroups(
    Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final set = <String>{};
    for (final d in docs) {
      final raw = d.data()['groupId'];
      final g = (raw is String) ? raw.trim() : '';
      if (g.isNotEmpty) set.add(g);
    }
    final groups = set.toList()..sort();
    return [_allGroupsLabel, ...groups];
  }

  String _effectiveGroupId() {
    return selectedGroup == _allGroupsLabel ? 'all' : selectedGroup;
  }

  GroupProduct _demoProduct({
    required String id,
    required String title,
    required int priceCents,
    required String category,
    String? imagePath,
  }) {
    return GroupProduct(
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
  }

  void _openProductDetail(GroupProduct product) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProductDetailPage(
          groupId: _effectiveGroupId(),
          product: product,
          heroTag: 'product-${product.id}',
        ),
      ),
    );
  }

  void _addProductToCart(GroupProduct product) {
    final size = product.sizes.isNotEmpty ? product.sizes.first : 'Unique';
    final color = product.colors.isNotEmpty ? product.colors.first : 'Default';

    CartService.instance.addProduct(
      groupId: _effectiveGroupId(),
      product: product,
      size: size,
      color: color,
      quantity: 1,
    );

    ScaffoldMessenger.of(context).showSnackBar(
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

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final contentW = size.width - (_pageHPad * 2);
    final tileW = (contentW - _gridGap) / 2;

    // ✅ Hauteurs qui matchent mieux ta capture (A54)
    final bigTileH = tileW * 0.92; // plus haut => image plus grande
    final smallTileH = tileW * 0.58; // bandanas plus bas

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: _bg,
        body: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            _Header(
              height: _headerH,
              onBackTap: () => Navigator.of(context).maybePop(),
              onCartTap: () {
                Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const CartPage()));
              },
            ),

            // ✅ PINNED : ne scroll pas
            SliverPersistentHeader(
              pinned: true,
              delegate: _PinnedDelegate(
                height: _filtersPinnedH,
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _buildGroupsQuery().snapshots(),
                  builder: (context, snap) {
                    final dynamicGroups = (snap.hasData)
                        ? _extractGroups(snap.data!.docs)
                        : _fallbackGroups;

                    // Si l'utilisateur avait un groupe sélectionné qui n'existe plus,
                    // on revient à "Tous les groupes".
                    if (!dynamicGroups.contains(selectedGroup)) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (!mounted) return;
                        setState(() => selectedGroup = _allGroupsLabel);
                      });
                    }

                    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: _buildCategoriesQuery().snapshots(),
                      builder: (context, catSnap) {
                        final dynamicCats = (catSnap.hasData)
                            ? _extractCategories(catSnap.data!.docs)
                            : _fallbackCats;

                        if (!_listEquals(dynamicCats, _cats)) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (!mounted) return;
                            setState(() {
                              _cats = dynamicCats;
                              if (catIndex >= _cats.length) catIndex = 0;
                            });
                          });
                        }

                        return _FiltersBar(
                          cats: _cats,
                          selectedIndex: catIndex,
                          onCatChanged: (i) => setState(() => catIndex = i),
                          groups: dynamicGroups,
                          selectedGroup: selectedGroup,
                          onGroupChanged: (v) => setState(() {
                            selectedGroup = v;
                            // Quand on change de groupe, on revient sur Tous côté catégories.
                            catIndex = 0;
                          }),
                        );
                      },
                    );
                  },
                ),
              ),
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  _pageHPad,
                  12,
                  _pageHPad,
                  10,
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        SizedBox(
                          width: tileW,
                          height: bigTileH,
                          child: _PhotoTile(
                            title: "Boutique photos",
                            subtitle: "Photographes only",
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => MediaShopWrapper(
                                    groupId: _effectiveGroupId(),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: _gridGap),
                        SizedBox(
                          width: tileW,
                          height: bigTileH,
                          child: _ProductTile(
                            title: "Casquette\nMASLIVE",
                            price: "25,00 €",
                            image: const _AssetOrFallback(
                              assetPath: "assets/shop/capblack1.png",
                              fallbackIcon: Icons.checkroom_outlined,
                            ),
                            onAdd: () => _addProductToCart(
                              _demoProduct(
                                id: 'demo-casquette',
                                title: 'Casquette MASLIVE',
                                priceCents: 2500,
                                category: 'Accessoires',
                                imagePath: 'assets/shop/capblack1.png',
                              ),
                            ),
                            onTap: () => _openProductDetail(
                              _demoProduct(
                                id: 'demo-casquette',
                                title: 'Casquette MASLIVE',
                                priceCents: 2500,
                                category: 'Accessoires',
                                imagePath: 'assets/shop/capblack1.png',
                              ),
                            ),
                            compact: false,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: _gridGap),
                    Row(
                      children: [
                        SizedBox(
                          width: tileW,
                          height: bigTileH,
                          child: _ProductTile(
                            title: "T-shirt\nMASLIVE",
                            price: "25,00 €",
                            image: const _AssetOrFallback(
                              assetPath: "assets/shop/tshirtblack.png",
                              fallbackIcon: Icons.checkroom_outlined,
                            ),
                            onAdd: () => _addProductToCart(
                              _demoProduct(
                                id: 'demo-tshirt',
                                title: 'T-shirt MASLIVE',
                                priceCents: 2500,
                                category: 'Vêtements',
                                imagePath: 'assets/shop/tshirtblack.png',
                              ),
                            ),
                            onTap: () => _openProductDetail(
                              _demoProduct(
                                id: 'demo-tshirt',
                                title: 'T-shirt MASLIVE',
                                priceCents: 2500,
                                category: 'Vêtements',
                                imagePath: 'assets/shop/tshirtblack.png',
                              ),
                            ),
                            compact: false,
                          ),
                        ),
                        const SizedBox(width: _gridGap),
                        SizedBox(
                          width: tileW,
                          height: bigTileH,
                          child: _ProductTile(
                            title: "Porte-clé\nMASLIVE",
                            price: "8,00 €",
                            image: const _AssetOrFallback(
                              assetPath: "assets/shop/porteclésblack01.png",
                              fallbackIcon: Icons.key_outlined,
                            ),
                            onAdd: () => _addProductToCart(
                              _demoProduct(
                                id: 'demo-porte-cle',
                                title: 'Porte-clé MASLIVE',
                                priceCents: 800,
                                category: 'Accessoires',
                                imagePath: 'assets/shop/porteclésblack01.png',
                              ),
                            ),
                            onTap: () => _openProductDetail(
                              _demoProduct(
                                id: 'demo-porte-cle',
                                title: 'Porte-clé MASLIVE',
                                priceCents: 800,
                                category: 'Accessoires',
                                imagePath: 'assets/shop/porteclésblack01.png',
                              ),
                            ),
                            compact: false,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: _gridGap),
                    Row(
                      children: [
                        SizedBox(
                          width: tileW,
                          height: smallTileH,
                          child: _ProductTile(
                            title: "Bandana\nMASLIVE",
                            price: "20,00 €",
                            image: const _AssetOrFallback(
                              assetPath: "assets/shop/logomockup.jpeg",
                              fallbackIcon: Icons.auto_awesome_outlined,
                            ),
                            onAdd: () => _addProductToCart(
                              _demoProduct(
                                id: 'demo-bandana-1',
                                title: 'Bandana MASLIVE',
                                priceCents: 2000,
                                category: 'Accessoires',
                                imagePath: 'assets/shop/logomockup.jpeg',
                              ),
                            ),
                            onTap: () => _openProductDetail(
                              _demoProduct(
                                id: 'demo-bandana-1',
                                title: 'Bandana MASLIVE',
                                priceCents: 2000,
                                category: 'Accessoires',
                                imagePath: 'assets/shop/logomockup.jpeg',
                              ),
                            ),
                            compact: true,
                          ),
                        ),
                        const SizedBox(width: _gridGap),
                        SizedBox(
                          width: tileW,
                          height: smallTileH,
                          child: _ProductTile(
                            title: "Bandana\nMASLIVE",
                            price: "10,00 €",
                            image: const _AssetOrFallback(
                              assetPath: "assets/shop/modelmaslivewhite.png",
                              fallbackIcon: Icons.auto_awesome_outlined,
                            ),
                            onAdd: () => _addProductToCart(
                              _demoProduct(
                                id: 'demo-bandana-2',
                                title: 'Bandana MASLIVE',
                                priceCents: 1000,
                                category: 'Accessoires',
                                imagePath: 'assets/shop/modelmaslivewhite.png',
                              ),
                            ),
                            onTap: () => _openProductDetail(
                              _demoProduct(
                                id: 'demo-bandana-2',
                                title: 'Bandana MASLIVE',
                                priceCents: 1000,
                                category: 'Accessoires',
                                imagePath: 'assets/shop/modelmaslivewhite.png',
                              ),
                            ),
                            compact: true,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(_pageHPad, 0, _pageHPad, 10),
                child: const Text(
                  "Articles",
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF111827),
                  ),
                ),
              ),
            ),

            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _buildProductsQuery().snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(_pageHPad, 0, _pageHPad, 18),
                      child: Center(
                        child: SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(strokeWidth: 3),
                        ),
                      ),
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        _pageHPad,
                        0,
                        _pageHPad,
                        18,
                      ),
                      child: const _EmptyStateCard(
                        title: "Impossible de charger les articles",
                        subtitle:
                            "Vérifie la connexion et les règles Firestore.",
                      ),
                    ),
                  );
                }

                final docs = snapshot.data?.docs ?? const [];
                if (docs.isEmpty) {
                  return SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        _pageHPad,
                        0,
                        _pageHPad,
                        18,
                      ),
                      child: const _EmptyStateCard(
                        title: "Aucun article pour l'instant",
                        subtitle:
                            "Ajoute des produits via Admin → Commerce → Produits (isActive + approved).",
                      ),
                    ),
                  );
                }

                final products = docs
                    .map((d) => GroupProduct.fromMap(d.id, d.data()))
                    .toList(growable: false);

                return SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    _pageHPad,
                    0,
                    _pageHPad,
                    18,
                  ),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: _gridGap,
                          crossAxisSpacing: _gridGap,
                          childAspectRatio: 0.68,
                        ),
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final product = products[index];
                      final raw = docs[index].data();
                      final groupId =
                          ((raw['groupId'] as String?)?.trim().isNotEmpty ==
                              true)
                          ? (raw['groupId'] as String)
                          : 'all';

                      final hasStock =
                          product.stockByVariant?.values.any(
                            (qty) => qty > 0,
                          ) ??
                          false;

                      final options = <String>[];
                      if (product.sizes.isNotEmpty) {
                        options.add(
                          product.sizes.length == 1
                              ? product.sizes.first
                              : '${product.sizes.first}-${product.sizes.last}',
                        );
                      }
                      if (product.colors.isNotEmpty) {
                        options.add(
                          product.colors.length == 1
                              ? product.colors.first
                              : '${product.colors.first}/${product.colors.last}',
                        );
                      }

                      final tileData = ProductTileData(
                        title: product.title,
                        subtitle: product.category.isNotEmpty
                            ? product.category
                            : 'Article',
                        price: product.priceCents / 100.0,
                        currency: '€',
                        imageUrl: product.imageUrl,
                        isAvailable: product.isActive && hasStock,
                        stockLabel: hasStock ? 'En stock' : 'Rupture',
                        badges: [
                          if (product.category.isNotEmpty) product.category,
                        ],
                        options: options,
                      );

                      return ProductTile(
                        data: tileData,
                        heroTag: 'product-${product.id}',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ProductDetailPage(
                              groupId: groupId,
                              product: product,
                              heroTag: 'product-${product.id}',
                            ),
                          ),
                        ),
                        onAdd: () {
                          final size = product.sizes.isNotEmpty
                              ? product.sizes.first
                              : 'Unique';
                          final color = product.colors.isNotEmpty
                              ? product.colors.first
                              : 'Default';

                          CartService.instance.addProduct(
                            groupId: groupId,
                            product: product,
                            size: size,
                            color: color,
                            quantity: 1,
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                '${product.title} ajouté au panier',
                              ),
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
                      );
                    }, childCount: products.length),
                  ),
                );
              },
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }
}

/// -------------------- HEADER --------------------
class _Header extends StatelessWidget {
  const _Header({
    required this.height,
    required this.onBackTap,
    required this.onCartTap,
  });
  final double height;
  final VoidCallback onBackTap;
  final VoidCallback onCartTap;

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      expandedHeight: height,
      backgroundColor: Colors.transparent,
      elevation: 0,
      automaticallyImplyLeading: false,
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFFFFC36A),
                    Color(0xFFFF7BA7),
                    Color(0xFF7CCBFF),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                child: Column(
                  children: [
                    Row(
                      children: [
                        _BackButton(onTap: onBackTap),
                        const Spacer(),
                        _CartButton(onTap: onCartTap),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      "La Boutique",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 46,
                        height: 1.0,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.22),
                            ),
                          ),
                          child: const Text(
                            "Trouve des produits officiels et des photos\nd'événements.",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 17,
                              height: 1.2,
                            ),
                          ),
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
    );
  }
}

class _CartButton extends StatelessWidget {
  const _CartButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.16),
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          width: 64,
          height: 64,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
          ),
          child: const Icon(
            Icons.shopping_bag_outlined,
            color: Colors.white,
            size: 34,
          ),
        ),
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.16),
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          width: 52,
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
          ),
          child: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
            size: 22,
          ),
        ),
      ),
    );
  }
}

/// -------------------- PINNED FILTERS --------------------
class _PinnedDelegate extends SliverPersistentHeaderDelegate {
  _PinnedDelegate({required this.height, required this.child});
  final double height;
  final Widget child;

  @override
  double get minExtent => height;
  @override
  double get maxExtent => height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => child;

  @override
  bool shouldRebuild(covariant _PinnedDelegate oldDelegate) =>
      oldDelegate.height != height || oldDelegate.child != child;
}

class _FiltersBar extends StatelessWidget {
  const _FiltersBar({
    required this.cats,
    required this.selectedIndex,
    required this.onCatChanged,
    required this.groups,
    required this.selectedGroup,
    required this.onGroupChanged,
  });

  final List<String> cats;
  final int selectedIndex;
  final ValueChanged<int> onCatChanged;

  final List<String> groups;
  final String selectedGroup;
  final ValueChanged<String> onGroupChanged;

  static const double chipsH = 34;
  static const double dropdownH = 40;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF6F7FB),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        children: [
          SizedBox(
            height: chipsH,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  for (int i = 0; i < cats.length; i++) ...[
                    _SelectedChip(
                      label: cats[i],
                      selected: selectedIndex == i,
                      onTap: () => onCatChanged(i),
                    ),
                    const SizedBox(width: 10),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: dropdownH,
            child: _GroupDropdown(
              value: selectedGroup,
              items: groups,
              onChanged: onGroupChanged,
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectedChip extends StatelessWidget {
  const _SelectedChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
        decoration: BoxDecoration(
          gradient: selected
              ? const LinearGradient(
                  colors: [Color(0xFFFFC36A), Color(0xFFFF7BA7)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: selected ? null : Colors.white,
          borderRadius: BorderRadius.circular(999),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 14,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 18,
            color: Color(0xFF111827),
          ),
        ),
      ),
    );
  }
}

class _GroupDropdown extends StatelessWidget {
  const _GroupDropdown({
    required this.value,
    required this.items,
    required this.onChanged,
  });
  final String value;
  final List<String> items;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 16,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: value,
            isExpanded: true,
            icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 28),
            items: items
                .map(
                  (e) => DropdownMenuItem(
                    value: e,
                    child: Text(
                      e,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 20,
                      ),
                    ),
                  ),
                )
                .toList(),
            onChanged: (v) {
              if (v != null) onChanged(v);
            },
          ),
        ),
      ),
    );
  }
}

/// -------------------- TILES --------------------
class _BaseCard extends StatelessWidget {
  const _BaseCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(
          _ShopPixelPerfectPageState._cardRadius,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 22,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(
          _ShopPixelPerfectPageState._cardRadius,
        ),
        child: child,
      ),
    );
  }
}

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _BaseCard(
      child: InkWell(
        onTap: onTap,
        child: Stack(
          children: [
            // bandeau bleu haut
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              height: 70,
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF4E7CCB), Color(0xFF7AA6F3)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 20,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.92),
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // contenu bas
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 82, 14, 14),
              child: Align(
                alignment: Alignment.bottomLeft,
                child: Text(
                  "Boutique\nphotos",
                  style: const TextStyle(
                    fontSize: 28,
                    height: 1.05,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF111827),
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

class _ProductTile extends StatelessWidget {
  const _ProductTile({
    required this.title,
    required this.price,
    required this.image,
    required this.onAdd,
    required this.onTap,
    required this.compact,
  });

  final String title;
  final String price;
  final Widget image;
  final VoidCallback onAdd;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return _BaseCard(
      child: InkWell(
        onTap: onTap,
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(
                      _ShopPixelPerfectPageState._innerRadius,
                    ),
                    child: SizedBox(
                      height: compact
                          ? 54
                          : 96, // ✅ image plus grande sur grandes tuiles
                      width: double.infinity,
                      child: image,
                    ),
                  ),
                  SizedBox(height: compact ? 8 : 10),
                  Text(
                    title,
                    maxLines: compact ? 2 : 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: compact ? 18 : 26,
                      height: 1.05,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    price,
                    style: TextStyle(
                      fontSize: compact ? 16 : 18,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF111827),
                    ),
                  ),
                ],
              ),
            ),

            // ✅ Bouton + overlay (fini le "+" dans l'image)
            Positioned(right: 12, bottom: 12, child: _AddButton(onTap: onAdd)),
          ],
        ),
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(
        _ShopPixelPerfectPageState._addRadius,
      ),
      child: Ink(
        width: _ShopPixelPerfectPageState._addSize,
        height: _ShopPixelPerfectPageState._addSize,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFF7BA7), Color(0xFF7CCBFF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(
            _ShopPixelPerfectPageState._addRadius,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.16),
              blurRadius: 16,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
      ),
    );
  }
}

/// -------------------- EMPTY STATE --------------------
class _EmptyStateCard extends StatelessWidget {
  const _EmptyStateCard({
    this.title = "Aucun produit disponible",
    this.subtitle = "Reviens plus tard ou change de catégorie.",
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return _BaseCard(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 22, 18, 22),
        child: Column(
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Icon(
                Icons.shopping_bag_outlined,
                size: 42,
                color: Colors.black.withValues(alpha: 0.35),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.black.withValues(alpha: 0.55),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// -------------------- IMAGE helper --------------------
/// Mets tes vraies images dans assets/shop/* (png/jpeg)
/// Si absent => fallback propre (pas de + fantôme)
class _AssetOrFallback extends StatelessWidget {
  const _AssetOrFallback({required this.assetPath, required this.fallbackIcon});

  final String assetPath;
  final IconData fallbackIcon;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF1F2F6), Color(0xFFE9ECF5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Image.asset(
        assetPath,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Center(
            child: Icon(
              fallbackIcon,
              size: 34,
              color: Colors.black.withValues(alpha: 0.35),
            ),
          );
        },
      ),
    );
  }
}
