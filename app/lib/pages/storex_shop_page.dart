import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'cart/unified_cart_page.dart';
import 'product_detail_page.dart';
import '../models/group_product.dart';
import '../services/cart_service.dart';
import '../shop/widgets/shop_drawer.dart';
import '../widgets/cart/cart_icon_badge.dart';
import '../widgets/language_switcher.dart';
import '../l10n/app_localizations.dart' as l10n;
import '../ui/snack/top_snack_bar.dart';

/// ===============================================================
/// Storex-style Shop for MassLive (Firestore: products + categories)
/// Compatible avec tes champs: status/isVisible/isActive/moderationStatus
/// Images: imagePath (assets/...) ou imageUrl (https)
/// Wishlist: users/{uid}/wishlist/{productId}
/// Orders: users/{uid}/orders/{orderId} (simple affichage)
/// ===============================================================

class StorexShopPage extends StatefulWidget {
  const StorexShopPage({
    super.key,
    this.shopId = 'global',
    this.groupId = 'MASLIVE',
  });
  final String? shopId;
  final String? groupId;

  // Gradient rainbow (référence historique du header panier)
  static const rainbowGradient = LinearGradient(
    colors: [Color(0xFFFFE36A), Color(0xFFFF7BC5), Color(0xFF7CE0FF)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const premiumHeaderGradient = LinearGradient(
    colors: [
      Color(0xFFFFE36A),
      Color(0xFFFF8ACD),
      Color(0xFF98E4FF),
      Color(0xFFB8FFDA),
    ],
    stops: [0.0, 0.34, 0.7, 1.0],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  @override
  State<StorexShopPage> createState() => _StorexShopPageState();
}

class _ShopUi {
  const _ShopUi._();

  static const Color pageBg = Color(0xFFF7F8FC);
  static const Color textMain = Color(0xFF101828);
  static const Color textMuted = Color(0xFF667085);
  static const Color strokeSoft = Color(0x1F0F172A);
  static const Color navBg = Color(0xF9FFFFFF);

  static const LinearGradient chipGradient = LinearGradient(
    colors: [Color(0xFFFFB26A), Color(0xFFFF7BC5), Color(0xFF7CE0FF)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const BoxShadow cardShadow = BoxShadow(
    color: Color(0x14000000),
    blurRadius: 18,
    offset: Offset(0, 8),
  );
}

class _StorexShopPageState extends State<StorexShopPage> {
  int tab = 0;

  @override
  void initState() {
    super.initState();
    CartService.instance.start();
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _StorexHome(shopId: widget.shopId, groupId: widget.groupId),
      _StorexSearch(shopId: widget.shopId, groupId: widget.groupId),
      _StorexFavorites(shopId: widget.shopId, groupId: widget.groupId),
      _StorexMediatheque(shopId: widget.shopId, groupId: widget.groupId),
    ];

    return DefaultTextStyle.merge(
      style: const TextStyle(fontWeight: FontWeight.w600),
      child: Scaffold(
        backgroundColor: _ShopUi.pageBg,
        body: pages[tab],
        bottomNavigationBar: SafeArea(
          top: false,
          child: Container(
            height: 68,
            decoration: BoxDecoration(
              color: _ShopUi.navBg,
              border: const Border(top: BorderSide(color: _ShopUi.strokeSoft)),
              boxShadow: const <BoxShadow>[
                BoxShadow(
                  color: Color(0x14000000),
                  blurRadius: 20,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _Bottom(
                  icon: Icons.map_outlined,
                  activeIcon: Icons.map,
                  active: tab == 0,
                  onTap: () => setState(() => tab = 0),
                ),
                _Bottom(
                  icon: Icons.search_outlined,
                  activeIcon: Icons.search,
                  active: tab == 1,
                  onTap: () => setState(() => tab = 1),
                ),
                _Bottom(
                  icon: Icons.favorite_outline_rounded,
                  activeIcon: Icons.favorite_rounded,
                  active: tab == 2,
                  onTap: () => setState(() => tab = 2),
                ),
                _Bottom(
                  icon: Icons.image_outlined,
                  activeIcon: Icons.image_rounded,
                  active: tab == 3,
                  onTap: () => setState(() => tab = 3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Bottom extends StatelessWidget {
  const _Bottom({
    required this.icon,
    required this.activeIcon,
    required this.active,
    required this.onTap,
  });
  final IconData icon;
  final IconData activeIcon;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final iconChild = Icon(
      active ? activeIcon : icon,
      color: active ? Colors.white : const Color(0xFF98A2B3),
    );

    return InkResponse(
      radius: 28,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        padding: const EdgeInsets.all(8),
        decoration: active
            ? BoxDecoration(
                gradient: _ShopUi.chipGradient,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const <BoxShadow>[_ShopUi.cardShadow],
              )
            : null,
        child: iconChild,
      ),
    );
  }
}

/// =======================
/// FIRESTORE QUERIES (MassLive)
/// =======================

class StorexRepo {
  StorexRepo({required this.shopId, required this.groupId});
  final String? shopId;
  final String? groupId;

  Query<Map<String, dynamic>> base() {
    final sid = shopId?.trim();
    if (sid != null && sid.isNotEmpty) {
      // Compat: ancienne boutique => shops/{shopId}/products
      return FirebaseFirestore.instance
          .collection('shops')
          .doc(sid)
          .collection('products')
          .where('isActive', isEqualTo: true);
    }

    // Fallback: nouveau schéma (si utilisé ailleurs)
    Query<Map<String, dynamic>> q = FirebaseFirestore.instance.collection(
      'products',
    );
    if (groupId != null && groupId!.trim().isNotEmpty) {
      q = q.where('groupId', isEqualTo: groupId);
    }
    return q.where('isActive', isEqualTo: true);
  }

  Query<Map<String, dynamic>> bestSeller({int limit = 12}) {
    return base().orderBy('updatedAt', descending: true).limit(limit);
  }

  Query<Map<String, dynamic>> byCategory({
    required String categoryId,
    int limit = 80,
  }) {
    final sid = shopId?.trim();
    final q = base();
    if (sid != null && sid.isNotEmpty) {
      // Ancienne boutique: champ categoryId présent.
      return q
          .where('categoryId', isEqualTo: categoryId)
          .orderBy('updatedAt', descending: true)
          .limit(limit);
    }

    // Nouveau schéma possible: categoryId
    return q
        .where('categoryId', isEqualTo: categoryId)
        .orderBy('updatedAt', descending: true)
        .limit(limit);
  }

  Stream<Set<String>> wishlistIds() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return Stream.value(<String>{});
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('wishlist')
        .snapshots()
        .map((s) => s.docs.map((d) => d.id).toSet());
  }

  Future<void> toggleWish(GroupProduct p) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final ref = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('wishlist')
        .doc(p.id);
    final snap = await ref.get();
    if (snap.exists) {
      await ref.delete();
    } else {
      await ref.set({
        'title': p.title,
        'priceCents': p.priceCents,
        'imagePath': p.imagePath,
        'imageUrl': p.imageUrl,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> wishlistItems() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const Stream.empty();
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('wishlist')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> orders() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const Stream.empty();
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('orders')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // Utilitaire: accepte "approved" OU champ absent
  static bool onlyApproved(Map<String, dynamic> d) {
    final ms = d['moderationStatus'];
    if (ms == null) return true;
    return ms.toString().toLowerCase() == 'approved';
  }
}

/// =======================
/// HOME
/// =======================

class _StorexHome extends StatelessWidget {
  const _StorexHome({required this.shopId, required this.groupId});
  final String? shopId;
  final String? groupId;

  @override
  Widget build(BuildContext context) {
    final repo = StorexRepo(shopId: shopId, groupId: groupId);

    return Scaffold(
      backgroundColor: _ShopUi.pageBg,
      drawer: ShopDrawer(
        shopId: shopId,
        groupId: groupId,
        onNavigateHome: () => Navigator.of(context).pop(),
        onNavigateSearch: () {
          Navigator.of(context).pop();
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => _StorexSearch(shopId: shopId, groupId: groupId),
            ),
          );
        },
        onNavigateProfile: () {
          Navigator.of(context).pop();
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => _StorexAccount(shopId: shopId, groupId: groupId),
            ),
          );
        },
        onNavigateCategory: (categoryId, title) {
          Navigator.of(context).pop();
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => _ListPage(
                shopId: shopId,
                groupId: groupId,
                categoryId: categoryId,
                title: title,
              ),
            ),
          );
        },
      ),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF6F7FB),
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        toolbarHeight: 88,
        iconTheme: const IconThemeData(color: _ShopUi.textMain),
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        centerTitle: true,
        title: const Padding(
          padding: EdgeInsets.only(top: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "MAS'LIVE",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.9,
                  color: _ShopUi.textMain,
                  height: 1,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'LA BOUTIQUE',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 2.2,
                  color: _ShopUi.textMuted,
                  height: 1,
                ),
              ),
            ],
          ),
        ),
        actions: [
          CartIconBadge(
            iconGradient: const LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: <Color>[
                Color(0xFFFFB26A),
                Color(0xFFFF7BC5),
                Color(0xFF7CE0FF),
              ],
            ),
            backgroundColor: _ShopUi.pageBg,
            borderColor: _ShopUi.strokeSoft,
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const UnifiedCartPage())),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: StreamBuilder<Set<String>>(
        stream: repo.wishlistIds(),
        builder: (context, wishSnap) {
          final wish = wishSnap.data ?? <String>{};
          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: repo.bestSeller(limit: 200).snapshots(),
            builder: (context, snap) {
              if (!snap.hasData)
                return const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                );
              final docs = snap.data!.docs
                  .where((d) => StorexRepo.onlyApproved(d.data()))
                  .toList();
              if (docs.isEmpty) {
                return _Empty(
                  l10n.AppLocalizations.of(context)!.noProductsFound,
                );
              }
              final products = docs.map(GroupProduct.fromFirestore).toList();

              final counts = <String, int>{};
              for (final p in products) {
                final c = p.category.trim();
                if (c.isEmpty) continue;
                counts[c] = (counts[c] ?? 0) + 1;
              }
              final cats = counts.keys.toList()..sort();

              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _StorexHeroBanner(),
                    if (cats.isNotEmpty) ...[
                      const SizedBox(height: 18),
                      const Text(
                        'CATÉGORIES',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.4,
                          color: _ShopUi.textMain,
                          height: 1,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 46,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          itemCount: cats.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 12),
                          itemBuilder: (_, i) => _StorexCategoryChip(
                            label: cats[i].toUpperCase(),
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => _ListPage(
                                  shopId: shopId,
                                  groupId: groupId,
                                  categoryId: cats[i],
                                  title: cats[i],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 26),
                    Row(
                      children: [
                        Text(
                          l10n.AppLocalizations.of(
                            context,
                          )!.shopBestSeller.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.4,
                            color: _ShopUi.textMain,
                            height: 1,
                          ),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => _ListPage(
                                shopId: shopId,
                                groupId: groupId,
                                categoryId: null,
                                title: l10n.AppLocalizations.of(
                                  context,
                                )!.shopBestSeller,
                              ),
                            ),
                          ),
                          child: Text(
                            l10n.AppLocalizations.of(context)!.shopSeeMore,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: _ShopUi.textMuted,
                              height: 1,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: min(products.length, 10),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 14,
                            crossAxisSpacing: 14,
                            childAspectRatio: 0.735,
                          ),
                      itemBuilder: (context, index) {
                        final p = products[index];
                        return _StorexPremiumProductCard(
                          product: p,
                          wished: wish.contains(p.id),
                          onWish: () => repo.toggleWish(p),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ProductDetailPage(
                                groupId: (groupId ?? 'MASLIVE'),
                                product: p,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ─── _StorexHeroBanner ──────────────────────────────────────────────────────

class _StorexHeroBanner extends StatelessWidget {
  const _StorexHeroBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(2),
      height: 188,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFE36A), Color(0xFFFF7BC5), Color(0xFF7CE0FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(30),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset('assets/shop/boutik1.webp', fit: BoxFit.cover),
            Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 1.15,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.18),
                  ],
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withValues(alpha: 0.20),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.08),
                  ],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── _StorexCategoryChip ─────────────────────────────────────────────────────

class _StorexCategoryChip extends StatelessWidget {
  const _StorexCategoryChip({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(
          color: _ShopUi.textMain,
          borderRadius: BorderRadius.circular(24),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: 0.2,
            height: 1,
          ),
        ),
      ),
    );
  }
}

// ─── _StorexPremiumProductCard ───────────────────────────────────────────────

class _StorexPremiumProductCard extends StatelessWidget {
  const _StorexPremiumProductCard({
    required this.product,
    required this.wished,
    required this.onWish,
    required this.onTap,
  });
  final GroupProduct product;
  final bool wished;
  final VoidCallback onWish;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _Img(p: product, fit: BoxFit.cover),
                    Positioned(
                      top: 10,
                      right: 10,
                      child: GestureDetector(
                        onTap: onWish,
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.88),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.12),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                          child: Icon(
                            wished ? Icons.favorite : Icons.favorite_border,
                            color: wished
                                ? const Color(0xFFFF4D8D)
                                : _ShopUi.textMain,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            product.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: _ShopUi.textMain,
              height: 1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            product.priceLabel,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: _ShopUi.textMain,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

/// =======================
/// SEARCH OVERLAY
/// =======================

class _StorexSearch extends StatefulWidget {
  const _StorexSearch({required this.shopId, required this.groupId});
  final String? shopId;
  final String? groupId;

  @override
  State<_StorexSearch> createState() => _StorexSearchState();
}

class _StorexSearchState extends State<_StorexSearch> {
  final ctrl = TextEditingController();
  String q = "";

  @override
  void dispose() {
    ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repo = StorexRepo(shopId: widget.shopId, groupId: widget.groupId);

    return Scaffold(
      backgroundColor: _ShopUi.pageBg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
              child: Row(
                children: [
                  const Icon(Icons.search, color: Colors.black38),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: ctrl,
                      onChanged: (v) => setState(() => q = v.trim()),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.black38),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: repo.bestSeller(limit: 250).snapshots(),
                builder: (context, snap) {
                  if (!snap.hasData)
                    return const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    );
                  final docs = snap.data!.docs
                      .where((d) => StorexRepo.onlyApproved(d.data()))
                      .toList();
                  final all = docs.map(GroupProduct.fromFirestore).toList();

                  final filtered = q.isEmpty
                      ? all
                      : all
                            .where(
                              (p) => p.title.toLowerCase().contains(
                                q.toLowerCase(),
                              ),
                            )
                            .toList();
                  if (filtered.isEmpty) {
                    return _Empty(l10n.AppLocalizations.of(context)!.noResults);
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                    itemCount: min(filtered.length, 40),
                    separatorBuilder: (_, index) => const SizedBox(height: 10),
                    itemBuilder: (_, i) {
                      final p = filtered[i];
                      return InkWell(
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ProductDetailPage(
                              groupId: (widget.groupId ?? 'MASLIVE'),
                              product: p,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 54,
                              height: 54,
                              decoration: BoxDecoration(
                                color: const Color(0xFFE3E5EA),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: _Img(p: p, fit: BoxFit.cover),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    p.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    p.priceLabel,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// =======================
/// LISTING (grid/list + wishlist)
/// =======================

class _ListPage extends StatefulWidget {
  const _ListPage({
    required this.shopId,
    required this.groupId,
    required this.categoryId,
    required this.title,
  });
  final String? shopId;
  final String? groupId;
  final String? categoryId; // null = all
  final String title;

  @override
  State<_ListPage> createState() => _ListPageState();
}

class _ListPageState extends State<_ListPage> {
  bool grid = true;

  @override
  Widget build(BuildContext context) {
    final repo = StorexRepo(shopId: widget.shopId, groupId: widget.groupId);

    final stream = widget.categoryId == null
        ? repo.bestSeller(limit: 250).snapshots()
        : repo
              .byCategory(categoryId: widget.categoryId!, limit: 250)
              .snapshots();

    return Scaffold(
      backgroundColor: _ShopUi.pageBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        scrolledUnderElevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: StorexShopPage.premiumHeaderGradient,
          ),
        ),
        elevation: 0,
        iconTheme: const IconThemeData(color: _ShopUi.textMain),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        centerTitle: true,
        title: Text(
          widget.title.toUpperCase(),
          style: const TextStyle(
            color: _ShopUi.textMain,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(grid ? Icons.view_list : Icons.grid_view),
            onPressed: () => setState(() => grid = !grid),
          ),
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => _StorexSearch(
                  shopId: widget.shopId,
                  groupId: widget.groupId,
                ),
              ),
            ),
          ),
        ],
      ),
      body: StreamBuilder<Set<String>>(
        stream: repo.wishlistIds(),
        builder: (context, wishSnap) {
          final wish = wishSnap.data ?? <String>{};

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: stream,
            builder: (context, snap) {
              if (!snap.hasData)
                return const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                );
              final docs = snap.data!.docs
                  .where((d) => StorexRepo.onlyApproved(d.data()))
                  .toList();
              final products = docs.map(GroupProduct.fromFirestore).toList();
              if (products.isEmpty) {
                return _Empty(
                  l10n.AppLocalizations.of(context)!.noProductsFound,
                );
              }

              if (grid) {
                return GridView.builder(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 0.82,
                  ),
                  itemCount: products.length,
                  itemBuilder: (_, i) {
                    final p = products[i];
                    final wished = wish.contains(p.id);
                    return InkWell(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ProductDetailPage(
                            groupId: (widget.groupId ?? 'MASLIVE'),
                            product: p,
                          ),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: _Img(p: p, fit: BoxFit.cover),
                                ),
                                Positioned(
                                  right: 6,
                                  bottom: 6,
                                  child: InkResponse(
                                    onTap: () => repo.toggleWish(p),
                                    radius: 18,
                                    child: Icon(
                                      wished
                                          ? Icons.favorite
                                          : Icons.favorite_border,
                                      color: wished
                                          ? Colors.redAccent
                                          : Colors.black54,
                                      size: 20,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            p.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            p.priceLabel,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                    );
                  },
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                itemCount: products.length,
                separatorBuilder: (_, index) => const SizedBox(height: 10),
                itemBuilder: (_, i) {
                  final p = products[i];
                  final wished = wish.contains(p.id);
                  return InkWell(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ProductDetailPage(
                          groupId: (widget.groupId ?? 'MASLIVE'),
                          product: p,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 92,
                          height: 92,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE3E5EA),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: _Img(p: p, fit: BoxFit.cover),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                p.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                p.priceLabel,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                        InkResponse(
                          onTap: () => repo.toggleWish(p),
                          radius: 20,
                          child: Icon(
                            wished ? Icons.favorite : Icons.favorite_border,
                            color: wished ? Colors.redAccent : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

/// =======================
/// ACCOUNT + WISHLIST + ORDERS
/// =======================

class _StorexAccount extends StatelessWidget {
  const _StorexAccount({required this.shopId, required this.groupId});
  final String? shopId;
  final String? groupId;

  @override
  Widget build(BuildContext context) {
    final repo = StorexRepo(shopId: shopId, groupId: groupId);
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: _ShopUi.pageBg,
      drawer: ShopDrawer(
        shopId: shopId,
        groupId: groupId,
        onNavigateHome: () {
          Navigator.of(context).pop();
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => _StorexHome(shopId: shopId, groupId: groupId),
            ),
          );
        },
        onNavigateSearch: () {
          Navigator.of(context).pop();
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => _StorexSearch(shopId: shopId, groupId: groupId),
            ),
          );
        },
        onNavigateProfile: () {
          Navigator.of(context).pop();
        },
        onNavigateCategory: (categoryId, title) {
          Navigator.of(context).pop();
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => _ListPage(
                shopId: shopId,
                groupId: groupId,
                categoryId: categoryId,
                title: title,
              ),
            ),
          );
        },
      ),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        scrolledUnderElevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: StorexShopPage.premiumHeaderGradient,
          ),
        ),
        elevation: 0,
        iconTheme: const IconThemeData(color: _ShopUi.textMain),
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        actions: [
          LanguageSwitcher(textColor: _ShopUi.textMain),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
        children: [
          Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black26),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person_outline, color: Colors.black54),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user?.displayName ?? 'User',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user?.email ?? 'not-signed-in',
                      style: const TextStyle(color: Colors.black38),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _AccountRow(
            icon: Icons.receipt_long,
            label: l10n.AppLocalizations.of(context)!.myOrders,
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => _OrdersPage(repo: repo))),
          ),
          _AccountRow(
            icon: Icons.favorite_border,
            label: l10n.AppLocalizations.of(context)!.myFavorites,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    _StorexFavorites(shopId: shopId, groupId: groupId),
              ),
            ),
          ),
          if (user != null)
            _AccountRow(
              icon: Icons.logout,
              label: l10n.AppLocalizations.of(context)!.logout,
              onTap: () async {
                final logoutLabel = l10n.AppLocalizations.of(context)!.logout;
                await FirebaseAuth.instance.signOut();
                if (!context.mounted) return;
                TopSnackBar.show(context, SnackBar(content: Text(logoutLabel)));
              },
            )
          else
            _AccountRow(
              icon: Icons.login,
              label: l10n.AppLocalizations.of(context)!.signIn,
              onTap: () => Navigator.pushNamed(context, '/login'),
            ),
        ],
      ),
    );
  }
}

class _AccountRow extends StatelessWidget {
  const _AccountRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(icon, color: Colors.black45),
          title: Text(label, style: const TextStyle(color: Colors.black54)),
          trailing: const Icon(Icons.chevron_right, color: Colors.black26),
          onTap: onTap,
        ),
        const Divider(height: 1),
      ],
    );
  }
}

class _OrdersPage extends StatelessWidget {
  const _OrdersPage({required this.repo});
  final StorexRepo repo;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Scaffold(
        backgroundColor: _ShopUi.pageBg,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          shadowColor: Colors.transparent,
          scrolledUnderElevation: 0,
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: StorexShopPage.premiumHeaderGradient,
            ),
          ),
          elevation: 0,
          iconTheme: const IconThemeData(color: _ShopUi.textMain),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
          ),
          centerTitle: true,
          title: Text(
            l10n.AppLocalizations.of(context)!.myOrders,
            style: const TextStyle(
              color: _ShopUi.textMain,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.AppLocalizations.of(context)!.login,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Connecte-toi pour voir tes commandes.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () => Navigator.pushNamed(context, '/login'),
                  child: const Text('Se connecter'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: _ShopUi.pageBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        scrolledUnderElevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: StorexShopPage.premiumHeaderGradient,
          ),
        ),
        elevation: 0,
        iconTheme: const IconThemeData(color: _ShopUi.textMain),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        centerTitle: true,
        title: Text(
          l10n.AppLocalizations.of(context)!.myOrders,
          style: const TextStyle(
            color: _ShopUi.textMain,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: repo.orders(),
        builder: (context, snap) {
          if (!snap.hasData)
            return const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            );
          final docs = snap.data!.docs;

          return ListView(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
            children: [
              Text(
                "${docs.length} ${l10n.AppLocalizations.of(context)!.orders}",
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 10),
              Container(height: 44, color: const Color(0xFF1F232A)),
              const SizedBox(height: 6),
              ...docs.map((doc) {
                final d = doc.data();
                final orderNo = (d['orderNo'] ?? doc.id).toString();
                final status = (d['status'] ?? 'processing').toString();
                final itemsCount = (d['items'] is List)
                    ? (d['items'] as List).length
                    : ((d['itemsCount'] ?? 1) as num).toInt();
                final items = itemsCount.toString();
                final createdAt =
                    (d['createdAt'] as Timestamp?)?.toDate().toString() ?? "";

                final isCancelled = status.toLowerCase().contains('cancel');

                return Column(
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        '${l10n.AppLocalizations.of(context)!.orderNo} $orderNo',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        '$createdAt  •  $items ${l10n.AppLocalizations.of(context)!.itemsLabel}',
                        style: const TextStyle(color: Colors.black45),
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: isCancelled ? Colors.red : Colors.grey,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          status,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                    const Divider(height: 1),
                  ],
                );
              }),
            ],
          );
        },
      ),
    );
  }
}

/// =======================
/// FAVORIS / WISHLIST PAGE
/// =======================

class _StorexFavorites extends StatelessWidget {
  const _StorexFavorites({required this.shopId, required this.groupId});
  final String? shopId;
  final String? groupId;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Center(child: Text('Connectez-vous pour voir vos favoris'));
    }

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Favoris',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final wishlist =
                  (snapshot.data?['wishlist'] as List?)?.cast<String>() ?? [];

              if (wishlist.isEmpty) {
                return const _Empty('Aucun favori pour le moment');
              }

              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('products')
                    .where(
                      FieldPath.documentId,
                      whereIn: wishlist.take(10).toList(),
                    )
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final products = snapshot.data!.docs
                      .map((doc) => GroupProduct.fromFirestore(doc))
                      .toList();

                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 0.6,
                        ),
                    itemCount: products.length,
                    itemBuilder: (context, index) {
                      final p = products[index];
                      return _StorexPremiumProductCard(
                        product: p,
                        wished: wishlist.contains(p.id),
                        onWish: () {
                          // Toggle wishlist
                          final updatedWishlist = List<String>.from(wishlist);
                          if (updatedWishlist.contains(p.id)) {
                            updatedWishlist.remove(p.id);
                          } else {
                            updatedWishlist.add(p.id);
                          }
                          FirebaseFirestore.instance
                              .collection('users')
                              .doc(user.uid)
                              .update({'wishlist': updatedWishlist});
                        },
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => ProductDetailPage(
                                groupId: groupId ?? 'MASLIVE',
                                product: p,
                              ),
                            ),
                          );
                          final size = p.sizes.isNotEmpty ? p.sizes.first : 'M';
                          final color = p.colors.isNotEmpty
                              ? p.colors.first
                              : 'Noir';
                          CartService.instance.addProduct(
                            groupId: groupId ?? 'MASLIVE',
                            product: p,
                            size: size,
                            color: color,
                            quantity: 1,
                          );
                        },
                      );
                    },
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

/// =======================
/// MEDIATHEQUE / MEDIA LIBRARY PAGE
/// =======================

class _StorexMediatheque extends StatelessWidget {
  const _StorexMediatheque({required this.shopId, required this.groupId});
  final String? shopId;
  final String? groupId;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Médiathèque',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('products')
                .where('itemType', isEqualTo: 'Media')
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final products = snapshot.data!.docs
                  .map((doc) => GroupProduct.fromFirestore(doc))
                  .toList();

              if (products.isEmpty) {
                return const _Empty('Aucun média disponible');
              }

              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.6,
                ),
                itemCount: products.length,
                itemBuilder: (context, index) {
                  final p = products[index];
                  return _StorexPremiumProductCard(
                    product: p,
                    wished: false,
                    onWish: () {},
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => ProductDetailPage(
                            groupId: groupId ?? 'MASLIVE',
                            product: p,
                          ),
                        ),
                      );
                      final size = p.sizes.isNotEmpty ? p.sizes.first : 'M';
                      final color = p.colors.isNotEmpty
                          ? p.colors.first
                          : 'Noir';
                      CartService.instance.addProduct(
                        groupId: groupId ?? 'MASLIVE',
                        product: p,
                        size: size,
                        color: color,
                        quantity: 1,
                      );
                    },
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

/// =======================
/// IMAGE HELPERS (asset OR network)
/// =======================

class _Img extends StatelessWidget {
  const _Img({required this.p, required this.fit});
  final GroupProduct p;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    return _ImgRaw(
      imagePath: p.imagePath ?? '',
      imageUrl: p.imageUrl,
      fit: fit,
    );
  }
}

class _ImgRaw extends StatelessWidget {
  const _ImgRaw({
    required this.imagePath,
    required this.imageUrl,
    required this.fit,
  });
  final String imagePath;
  final String imageUrl;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final p = imagePath.trim();
    final u = imageUrl.trim();

    if (p.startsWith('assets/')) {
      return Image.asset(
        p,
        fit: fit,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (context, error, stackTrace) => _fallback(),
      );
    }
    if (u.startsWith('http')) {
      return Image.network(
        u,
        fit: fit,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (context, error, stackTrace) => _fallback(),
      );
    }
    return _fallback();
  }

  Widget _fallback() => Container(
    color: const Color(0xFFEFF1F6),
    child: const Center(
      child: Icon(
        Icons.shopping_bag_outlined,
        color: Color(0xFFB0B6C3),
        size: 36,
      ),
    ),
  );
}

class _Empty extends StatelessWidget {
  const _Empty(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Center(
    child: Text(
      text,
      style: const TextStyle(
        color: _ShopUi.textMuted,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}
