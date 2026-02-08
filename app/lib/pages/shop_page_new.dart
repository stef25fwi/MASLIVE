import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'cart_page.dart';
import 'storex_shop_page.dart';
import 'product_detail_page.dart';
import '../models/group_product.dart';
import '../services/cart_service.dart';

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
  String? selectedSize;
  String? selectedColor;

  static const String _allGroupsLabel = 'Tous les groupes';

  static const _bg = Color(0xFFF6F7FB);

  // Compact (comme ton mockup)
  static const double _pageHPad = 10;
  static const double _gridGap = 8;

  static const double _headerH = 190; // hauteur header (légèrement augmentée)
  static const double _filtersPinnedH = 152; // chips catégories + dropdown groupes + filtres taille/couleur

  static const double _cardRadius = 24;

  static const double _addSize = 44;
  static const double _addRadius = 16;

  // Fallback (aligné avec l'admin) si Firestore ne renvoie rien.
  static const _fallbackCats = <String>[
    "Tous",
    "Vêtements",
    "Accessoires",
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

  Query<Map<String, dynamic>> _buildCategoriesQuery() {
    Query<Map<String, dynamic>> query = FirebaseFirestore.instance
        .collectionGroup('products')
        .where('status', isEqualTo: 'published')
        .where('isVisible', isEqualTo: true);

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
        .where('status', isEqualTo: 'published')
        .where('isVisible', isEqualTo: true);

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

  List<String> _extractSizesFromTags(
    Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final set = <String>{};
    final knownSizes = {'xs', 's', 'm', 'l', 'xl', 'xxl', 'one size', 'unique'};
    for (final d in docs) {
      final tags = d.data()['tags'];
      if (tags is List) {
        for (final tag in tags) {
          final t = tag.toString().toLowerCase().trim();
          if (knownSizes.contains(t)) {
            set.add(tag.toString());
          }
        }
      }
    }
    final sizes = set.toList()..sort();
    return sizes;
  }

  List<String> _extractColorsFromTags(
    Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final set = <String>{};
    final knownColors = {
      'noir', 'blanc', 'rouge', 'bleu', 'vert', 'jaune',
      'orange', 'rose', 'violet', 'gris', 'marron',
      'multicolore', 'beige', 'turquoise'
    };
    for (final d in docs) {
      final tags = d.data()['tags'];
      if (tags is List) {
        for (final tag in tags) {
          final t = tag.toString().toLowerCase().trim();
          if (knownColors.contains(t)) {
            set.add(tag.toString());
          }
        }
      }
    }
    final colors = set.toList()..sort();
    return colors;
  }

  String _effectiveGroupId() {
    return selectedGroup == _allGroupsLabel ? 'all' : selectedGroup;
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _filterProductsByTags(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    return docs.where((doc) {
      final tags = doc.data()['tags'];
      if (tags is! List) return false;

      final tagsLower = tags.map((t) => t.toString().toLowerCase()).toSet();

      if (selectedSize != null) {
        if (!tagsLower.contains(selectedSize!.toLowerCase())) {
          return false;
        }
      }

      if (selectedColor != null) {
        if (!tagsLower.contains(selectedColor!.toLowerCase())) {
          return false;
        }
      }

      return true;
    }).toList();
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

    // ✅ Hauteurs normalisées pour affichage complet du texte et du prix
    final bigTileH = tileW * 1.35; // hauteur unique pour toutes les tuiles

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

                        final dynamicSizes = (catSnap.hasData)
                            ? _extractSizesFromTags(catSnap.data!.docs)
                            : <String>[];
                        final dynamicColors = (catSnap.hasData)
                            ? _extractColorsFromTags(catSnap.data!.docs)
                            : <String>[];

                        return _FiltersBar(
                          cats: _cats,
                          selectedIndex: catIndex,
                          onCatChanged: (i) => setState(() => catIndex = i),
                          groups: dynamicGroups,
                          selectedGroup: selectedGroup,
                          onGroupChanged: (v) => setState(() {
                            selectedGroup = v;
                            catIndex = 0;
                          }),
                          sizes: dynamicSizes,
                          selectedSize: selectedSize,
                          onSizeChanged: (v) => setState(() => selectedSize = v),
                          colors: dynamicColors,
                          selectedColor: selectedColor,
                          onColorChanged: (v) => setState(() => selectedColor = v),
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
                  20,
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
                                  builder: (_) => const StorexShopPage(
                                    shopId: "global",
                                    groupId: "MASLIVE",
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
                          height: bigTileH,
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
                            compact: false,
                          ),
                        ),
                        const SizedBox(width: _gridGap),
                        SizedBox(
                          width: tileW,
                          height: bigTileH,
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
                            compact: false,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Section produits dynamiques depuis Firestore
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _buildCategoriesQuery().snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const SliverToBoxAdapter(
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.all(40),
                        child: CircularProgressIndicator(),
                      ),
                    ),
                  );
                }

                // Filtrer par catégorie si sélectionnée
                var docs = snapshot.data!.docs;
                if (catIndex > 0 && catIndex < _cats.length) {
                  final selectedCat = _cats[catIndex];
                  docs = docs.where((d) {
                    final cat = d.data()['category'];
                    return cat == selectedCat;
                  }).toList();
                }

                // Filtrer par tags (taille/couleur)
                docs = _filterProductsByTags(docs);

                if (docs.isEmpty) {
                  return SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(40),
                      child: Center(
                        child: Column(
                          children: const [
                            Icon(
                              Icons.inventory_2_outlined,
                              size: 64,
                              color: Color(0xFFCBD5E1),
                            ),
                            SizedBox(height: 16),
                            Text(
                              'Aucun produit disponible',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }

                return SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    _pageHPad,
                    16,
                    _pageHPad,
                    16,
                  ),
                  sliver: SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: _gridGap,
                      crossAxisSpacing: _gridGap,
                      childAspectRatio: 1 / 1.35,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final doc = docs[index];
                        final product = GroupProduct.fromFirestore(doc);

                        return _ProductTile(
                          title: product.title,
                          price: product.priceLabel,
                          image: product.imagePath != null &&
                                  product.imagePath!.isNotEmpty
                              ? _AssetOrFallback(
                                  assetPath: product.imagePath!,
                                  fallbackIcon: Icons.shopping_bag_outlined,
                                )
                              : Container(
                                  color: const Color(0xFFF1F2F6),
                                  child: const Icon(
                                    Icons.shopping_bag_outlined,
                                    size: 48,
                                    color: Color(0xFFCBD5E1),
                                  ),
                                ),
                          onAdd: () => _addProductToCart(product),
                          onTap: () => _openProductDetail(product),
                          compact: false,
                          outOfStock: product.isOutOfStock,
                        );
                      },
                      childCount: docs.length,
                    ),
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
          width: 48,
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
          ),
          child: const Icon(
            Icons.shopping_bag_outlined,
            color: Colors.white,
            size: 24,
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
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
          ),
          child: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
            size: 18,
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
    this.sizes = const [],
    this.selectedSize,
    this.onSizeChanged,
    this.colors = const [],
    this.selectedColor,
    this.onColorChanged,
  });

  final List<String> cats;
  final int selectedIndex;
  final ValueChanged<int> onCatChanged;

  final List<String> groups;
  final String selectedGroup;
  final ValueChanged<String> onGroupChanged;

  final List<String> sizes;
  final String? selectedSize;
  final ValueChanged<String?>? onSizeChanged;

  final List<String> colors;
  final String? selectedColor;
  final ValueChanged<String?>? onColorChanged;

  static const double chipsH = 34;
  static const double dropdownH = 40;
  static const double filterRowH = 32;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF6F7FB),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        children: [
          SizedBox(
            height: chipsH,
            child: Stack(
              children: [
                SingleChildScrollView(
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
                        const SizedBox(width: 6),
                      ],
                    ],
                  ),
                ),
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  child: IgnorePointer(
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF6F7FB).withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            _Dot(),
                            SizedBox(width: 3),
                            _Dot(),
                            SizedBox(width: 3),
                            _Dot(),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
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
          if (sizes.isNotEmpty || colors.isNotEmpty) const SizedBox(height: 8),
          if (sizes.isNotEmpty)
            SizedBox(
              height: filterRowH,
              child: _FilterRow(
                label: 'Taille',
                items: sizes,
                selected: selectedSize,
                onChanged: onSizeChanged,
              ),
            ),
          if (sizes.isNotEmpty && colors.isNotEmpty) const SizedBox(height: 6),
          if (colors.isNotEmpty)
            SizedBox(
              height: filterRowH,
              child: _FilterRow(
                label: 'Couleur',
                items: colors,
                selected: selectedColor,
                onChanged: onColorChanged,
              ),
            ),
        ],
      ),
    );
  }
}

class _FilterRow extends StatelessWidget {
  const _FilterRow({
    required this.label,
    required this.items,
    required this.selected,
    required this.onChanged,
  });

  final String label;
  final List<String> items;
  final String? selected;
  final ValueChanged<String?>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          '$label:',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Color(0xFF6B7280),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _MiniChip(
                  label: 'Tous',
                  selected: selected == null,
                  onTap: () => onChanged?.call(null),
                ),
                const SizedBox(width: 6),
                for (final item in items) ...[
                  _MiniChip(
                    label: item,
                    selected: selected == item,
                    onTap: () => onChanged?.call(item),
                  ),
                  const SizedBox(width: 6),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MiniChip extends StatelessWidget {
  const _MiniChip({
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
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF2563EB) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected
                ? const Color(0xFF2563EB)
                : const Color(0xFFE5E7EB),
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: selected ? Colors.white : const Color(0xFF6B7280),
          ),
        ),
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

class _Dot extends StatelessWidget {
  const _Dot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 4,
      height: 4,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        shape: BoxShape.circle,
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
      borderRadius: BorderRadius.circular(999),
      clipBehavior: Clip.antiAlias,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
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
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            e,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 20,
                            ),
                          ),
                        ),
                        if (e == value)
                          const Icon(
                            Icons.check_circle,
                            color: Color(0xFF2563EB),
                            size: 18,
                          ),
                      ],
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
            // bandeau bleu entier
            Positioned.fill(
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF4E7CCB), Color(0xFF7AA6F3)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: const Icon(
                          Icons.photo_library_rounded,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 24,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        subtitle,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.92),
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
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
    this.outOfStock = false,
  });

  final String title;
  final String price;
  final Widget image;
  final VoidCallback onAdd;
  final VoidCallback onTap;
  final bool compact;
  final bool outOfStock;

  @override
  Widget build(BuildContext context) {
    return _BaseCard(
      child: InkWell(
        onTap: onTap,
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                  child: SizedBox(
                    height: compact ? 110 : 180,
                    width: double.infinity,
                    child: image,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: compact ? 2 : 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: compact ? 16 : 22,
                          height: 1.05,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            price,
                            style: TextStyle(
                              fontSize: compact ? 14 : 16,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFF111827),
                            ),
                          ),
                          if (outOfStock)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.red.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: const Text(
                                'Rupture de stock',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.redAccent,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // ✅ Bouton + overlay (fini le "+" dans l'image)
            Positioned(
              right: 12,
              bottom: 12,
              child: _AddButton(
                onTap: outOfStock ? null : onAdd,
                disabled: outOfStock,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({required this.onTap, this.disabled = false});
  final VoidCallback? onTap;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: disabled ? null : onTap,
      borderRadius: BorderRadius.circular(
        _ShopPixelPerfectPageState._addRadius,
      ),
      child: Ink(
        width: _ShopPixelPerfectPageState._addSize,
        height: _ShopPixelPerfectPageState._addSize,
        decoration: BoxDecoration(
          gradient: disabled
              ? const LinearGradient(
                  colors: [Color(0xFFCBD5E1), Color(0xFFE5E7EB)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : const LinearGradient(
                  colors: [Color(0xFFFF7BA7), Color(0xFF7CCBFF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
          borderRadius: BorderRadius.circular(
            _ShopPixelPerfectPageState._addRadius,
          ),
          boxShadow: [
            BoxShadow(
              color:
                  Colors.black.withValues(alpha: disabled ? 0.06 : 0.16),
              blurRadius: 16,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Icon(
          Icons.add_rounded,
          color: disabled ? Colors.white70 : Colors.white,
          size: 28,
        ),
      ),
    );
  }
}

/// -------------------- EMPTY STATE --------------------
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
