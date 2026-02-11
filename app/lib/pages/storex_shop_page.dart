import 'dart:math';
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'cart_page.dart';
import 'product_detail_page.dart';
import '../models/group_product.dart';
import '../services/cart_service.dart';
import '../widgets/language_switcher.dart';
import '../l10n/app_localizations.dart' as l10n;

/// ===============================================================
/// Storex-style Shop for MassLive (Firestore: products + categories)
/// Compatible avec tes champs: status/isVisible/isActive/moderationStatus
/// Images: imagePath (assets/...) ou imageUrl (https)
/// Wishlist: users/{uid}/wishlist/{productId}
/// Orders: users/{uid}/orders/{orderId} (simple affichage)
/// ===============================================================

class StorexShopPage extends StatefulWidget {
  const StorexShopPage({super.key, this.shopId = 'global', this.groupId = 'MASLIVE'});
  final String? shopId;
  final String? groupId;

  // Gradient rainbow (référence cart_page.dart)
  static const rainbowGradient = LinearGradient(
    colors: [Color(0xFFFFE36A), Color(0xFFFF7BC5), Color(0xFF7CE0FF)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  @override
  State<StorexShopPage> createState() => _StorexShopPageState();
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
      _StorexCategory(shopId: widget.shopId, groupId: widget.groupId),
      const _CartWrap(),
      _StorexAccount(shopId: widget.shopId, groupId: widget.groupId),
    ];

    return DefaultTextStyle.merge(
      style: const TextStyle(fontWeight: FontWeight.w600),
      child: Scaffold(
        body: pages[tab],
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          height: 58,
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Color(0x11000000))),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _Bottom(icon: Icons.storefront_outlined, activeIcon: Icons.storefront, active: tab == 0, onTap: () => setState(() => tab = 0)),
              _Bottom(icon: Icons.grid_view_outlined, activeIcon: Icons.grid_view, active: tab == 1, onTap: () => setState(() => tab = 1)),
              _Bottom(icon: Icons.shopping_bag_outlined, activeIcon: Icons.shopping_bag, active: tab == 2, onTap: () => setState(() => tab = 2)),
              _Bottom(icon: Icons.person_outline, activeIcon: Icons.person, active: tab == 3, onTap: () => setState(() => tab = 3)),
            ],
          ),
        ),
      ),
      ),
    );
  }
}

class _Bottom extends StatelessWidget {
  const _Bottom({required this.icon, required this.activeIcon, required this.active, required this.onTap});
  final IconData icon;
  final IconData activeIcon;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      radius: 28,
      onTap: onTap,
      child: Icon(active ? activeIcon : icon, color: active ? Colors.black87 : Colors.black38),
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
    Query<Map<String, dynamic>> q = FirebaseFirestore.instance.collection('products');
    if (groupId != null && groupId!.trim().isNotEmpty) {
      q = q.where('groupId', isEqualTo: groupId);
    }
    return q.where('isActive', isEqualTo: true);
  }

  Query<Map<String, dynamic>> bestSeller({int limit = 12}) {
    return base().orderBy('updatedAt', descending: true).limit(limit);
  }

  Query<Map<String, dynamic>> byCategory({required String categoryId, int limit = 80}) {
    final sid = shopId?.trim();
    final q = base();
    if (sid != null && sid.isNotEmpty) {
      // Ancienne boutique: champ categoryId présent.
      return q.where('categoryId', isEqualTo: categoryId).orderBy('updatedAt', descending: true).limit(limit);
    }

    // Nouveau schéma possible: categoryId
    return q.where('categoryId', isEqualTo: categoryId).orderBy('updatedAt', descending: true).limit(limit);
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
    final ref = FirebaseFirestore.instance.collection('users').doc(uid).collection('wishlist').doc(p.id);
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
    return FirebaseFirestore.instance.collection('users').doc(uid).collection('wishlist').orderBy('createdAt', descending: true).snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> orders() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const Stream.empty();
    return FirebaseFirestore.instance.collection('users').doc(uid).collection('orders').orderBy('createdAt', descending: true).snapshots();
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
      backgroundColor: Colors.white,
      drawer: _StorexDrawer(shopId: shopId, groupId: groupId),
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: StorexShopPage.rainbowGradient),
        ),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        centerTitle: false,
        title: LanguageSwitcher(textColor: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => _SearchPage(shopId: shopId, groupId: groupId))),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: repo.bestSeller(limit: 200).snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator(strokeWidth: 2));
          final docs = snap.data!.docs.where((d) => StorexRepo.onlyApproved(d.data())).toList();
          if (docs.isEmpty) {
            return _Empty(l10n.AppLocalizations.of(context)!.noProductsFound);
          }

          final products = docs.map(GroupProduct.fromFirestore).toList();

          // calc top categories for banners
          final counts = <String, int>{};
          for (final p in products) {
            final cid = p.category.trim();
            if (cid.isEmpty) continue;
            counts[cid] = (counts[cid] ?? 0) + 1;
          }
          final topCats = counts.keys.toList()
            ..sort((a, b) => (counts[b] ?? 0).compareTo(counts[a] ?? 0));
          final catA = topCats.isNotEmpty ? topCats[0] : 'Accessoires';
          final catB = topCats.length > 1 ? topCats[1] : catA;

          return ListView(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 16),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    l10n.AppLocalizations.of(context)!.shopBestSeller,
                    style: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.6),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => _ListPage(
                          shopId: shopId,
                          groupId: groupId,
                          categoryId: null,
                          title: l10n.AppLocalizations.of(context)!.shopBestSeller,
                        ),
                      ),
                    ),
                    child: Text(
                      l10n.AppLocalizations.of(context)!.shopSeeMore,
                      style: const TextStyle(color: Colors.black38),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              SizedBox(
                height: 230,
                child: StreamBuilder<Set<String>>(
                  stream: repo.wishlistIds(),
                  builder: (context, wishSnap) {
                    final wish = wishSnap.data ?? <String>{};
                    return ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: min(products.length, 10),
                      separatorBuilder: (_, index) => const SizedBox(width: 10),
                      itemBuilder: (_, i) {
                        final p = products[i];
                        return _BestCard(
                          p: p,
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
                    );
                  },
                ),
              ),

              const SizedBox(height: 14),

              _BannerTile(
                title: catA.toUpperCase(),
                subtitle:
                    "${counts[catA] ?? 0} ${l10n.AppLocalizations.of(context)!.itemsLabel}",
                  image: products.firstWhere((x) => x.category == catA, orElse: () => products.first),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => _ListPage(shopId: shopId, groupId: groupId, categoryId: catA, title: catA))),
              ),

              const SizedBox(height: 12),

              _BannerTile(
                title: catB.toUpperCase(),
                subtitle:
                    "${counts[catB] ?? 0} ${l10n.AppLocalizations.of(context)!.itemsLabel}",
                  image: products.firstWhere((x) => x.category == catB, orElse: () => products.first),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => _ListPage(shopId: shopId, groupId: groupId, categoryId: catB, title: catB))),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _BestCard extends StatelessWidget {
  const _BestCard({required this.p, required this.wished, required this.onWish, required this.onTap});
  final GroupProduct p;
  final bool wished;
  final VoidCallback onWish;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        width: 160,
        decoration: BoxDecoration(color: const Color(0xFFF1F2F4), borderRadius: BorderRadius.circular(14)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                    child: _Img(p: p, fit: BoxFit.cover),
                  ),
                  Positioned(
                    right: 6,
                    bottom: 6,
                    child: InkResponse(
                      onTap: onWish,
                      radius: 18,
                      child: Icon(wished ? Icons.favorite : Icons.favorite_border, color: wished ? Colors.redAccent : Colors.black54, size: 20),
                    ),
                  )
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
              child: Text(p.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w500)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
              child: Text(p.priceLabel, style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
  }
}

class _BannerTile extends StatelessWidget {
  const _BannerTile({required this.title, required this.subtitle, required this.image, required this.onTap});
  final String title;
  final String subtitle;
  final GroupProduct image;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        height: 140,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), color: const Color(0xFFF1F2F4)),
        child: Stack(
          children: [
            Positioned.fill(
              child: ClipRRect(borderRadius: BorderRadius.circular(14), child: _Img(p: image, fit: BoxFit.cover)),
            ),
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), color: Colors.white.withAlpha((0.55 * 255).round())),
              ),
            ),
            Positioned(
              right: 16,
              top: 46,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1.0)),
                  const SizedBox(height: 6),
                  Text(subtitle, style: const TextStyle(color: Colors.black38)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// =======================
/// DRAWER
/// =======================

class _StorexDrawer extends StatelessWidget {
  const _StorexDrawer({required this.shopId, required this.groupId});
  final String? shopId;
  final String? groupId;

  static const String _allCategoryId = '__all__';

  @override
  Widget build(BuildContext context) {
    final repo = StorexRepo(shopId: shopId, groupId: groupId);

    return Drawer(
      backgroundColor: Colors.transparent,
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withAlpha(240),
                  const Color(0xFFF8F9FA).withAlpha(240),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 10),
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: repo.bestSeller(limit: 250).snapshots(),
            builder: (context, snap) {
              final docs = (snap.data?.docs ?? []).where((d) => StorexRepo.onlyApproved(d.data())).toList();
              final products = docs.map(GroupProduct.fromFirestore).toList();

              final set = <String>{};
              for (final p in products) {
                final c = p.category.trim();
                if (c.isNotEmpty) set.add(c);
              }
              final cats = set.toList()..sort();
              final finalCats = <String>[_allCategoryId, ...cats];

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Image.asset(
                        'assets/images/maslivelogo.png',
                        height: 34,
                        fit: BoxFit.contain,
                      ),
                      LanguageSwitcher(),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _DrawerItem(l10n.AppLocalizations.of(context)!.home, () => Navigator.of(context).pop(), icon: Icons.home_outlined),
                  _DrawerItem(l10n.AppLocalizations.of(context)!.search, () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => _SearchPage(shopId: shopId, groupId: groupId)));
                  }, icon: Icons.search),
                  _DrawerItem(l10n.AppLocalizations.of(context)!.profile, () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => _StorexAccount(shopId: shopId, groupId: groupId)));
                  }, icon: Icons.person_outline),
                  _DrawerItem(l10n.AppLocalizations.of(context)!.signIn, () {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l10n.AppLocalizations.of(context)!.comingSoon)),
                    );
                  }),
                  const Divider(height: 28),
                  Text(
                    l10n.AppLocalizations.of(context)!.categories,
                    style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  ...finalCats.map((c) => Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: _DrawerItem(c == _allCategoryId ? l10n.AppLocalizations.of(context)!.all : c, () {
                          Navigator.of(context).pop();
                          final title = c == _allCategoryId ? l10n.AppLocalizations.of(context)!.all : c;
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => _ListPage(
                                shopId: shopId,
                                groupId: groupId,
                                categoryId: c == _allCategoryId ? null : c,
                                title: title,
                              ),
                            ),
                          );
                        }, small: true),
                      )),
                  const Spacer(),
                ],
              );
            },
          ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  const _DrawerItem(this.label, this.onTap, {this.small = false, this.icon});
  final String label;
  final VoidCallback onTap;
  final bool small;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: EdgeInsets.symmetric(
          vertical: small ? 8 : 12,
          horizontal: small ? 0 : 4,
        ),
        child: Row(
          children: [
            if (icon != null) ...[Icon(icon, size: 18, color: Colors.black54), const SizedBox(width: 8)],
            Text(label, style: TextStyle(fontSize: small ? 14 : 16, color: Colors.black54, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

/// =======================
/// SEARCH OVERLAY
/// =======================

class _SearchPage extends StatefulWidget {
  const _SearchPage({required this.shopId, required this.groupId});
  final String? shopId;
  final String? groupId;

  @override
  State<_SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<_SearchPage> {
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
      backgroundColor: Colors.white,
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
                      decoration: const InputDecoration(border: InputBorder.none),
                    ),
                  ),
                  IconButton(icon: const Icon(Icons.close, color: Colors.black38), onPressed: () => Navigator.of(context).pop()),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: repo.bestSeller(limit: 250).snapshots(),
                builder: (context, snap) {
                  if (!snap.hasData) return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                  final docs = snap.data!.docs.where((d) => StorexRepo.onlyApproved(d.data())).toList();
                  final all = docs.map(GroupProduct.fromFirestore).toList();

                  final filtered = q.isEmpty ? all : all.where((p) => p.title.toLowerCase().contains(q.toLowerCase())).toList();
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
                              decoration: BoxDecoration(color: const Color(0xFFE3E5EA), borderRadius: BorderRadius.circular(6)),
                              child: ClipRRect(borderRadius: BorderRadius.circular(6), child: _Img(p: p, fit: BoxFit.cover)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(p.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 6),
                                  Text(p.priceLabel, style: const TextStyle(fontWeight: FontWeight.w800)),
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
/// CATEGORY GRID (simple)
/// =======================

class _StorexCategory extends StatelessWidget {
  const _StorexCategory({required this.shopId, required this.groupId});
  final String? shopId;
  final String? groupId;

  @override
  Widget build(BuildContext context) {
    final repo = StorexRepo(shopId: shopId, groupId: groupId);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: StorexShopPage.rainbowGradient),
        ),
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          l10n.AppLocalizations.of(context)!.categories,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
          ),
        ),
        actions: [
          LanguageSwitcher(),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.search, color: Colors.black54),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => _SearchPage(shopId: shopId, groupId: groupId))),
          )
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: repo.bestSeller(limit: 250).snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator(strokeWidth: 2));
          final docs = snap.data!.docs.where((d) => StorexRepo.onlyApproved(d.data())).toList();
          final products = docs.map(GroupProduct.fromFirestore).toList();

          final counts = <String, int>{};
          for (final p in products) {
            final c = p.category.trim();
            if (c.isEmpty) continue;
            counts[c] = (counts[c] ?? 0) + 1;
          }
          final cats = counts.keys.toList()..sort();

          if (cats.isEmpty) {
            return _Empty(l10n.AppLocalizations.of(context)!.noData);
          }

          return GridView.builder(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.05,
            ),
            itemCount: cats.length,
            itemBuilder: (_, i) {
              final c = cats[i];
              final count = counts[c] ?? 0;
              return InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => _ListPage(shopId: shopId, groupId: groupId, categoryId: c, title: c))),
                child: Container(
                  decoration: BoxDecoration(color: const Color(0xFFE3E5EA), borderRadius: BorderRadius.circular(10)),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(color: Colors.black.withAlpha((0.18 * 255).round()), borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(c.toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, letterSpacing: 0.8)),
                            const SizedBox(height: 6),
                              Text(
                                "$count ${l10n.AppLocalizations.of(context)!.itemsLabel}",
                                style: const TextStyle(color: Colors.white70),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// =======================
/// LISTING (grid/list + wishlist)
/// =======================

class _ListPage extends StatefulWidget {
  const _ListPage({required this.shopId, required this.groupId, required this.categoryId, required this.title});
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
        : repo.byCategory(categoryId: widget.categoryId!, limit: 250).snapshots();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: StorexShopPage.rainbowGradient),
        ),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        centerTitle: true,
        title: Text(
          widget.title.toUpperCase(),
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
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
                builder: (_) => _SearchPage(
                  shopId: widget.shopId,
                  groupId: widget.groupId
                )
              )
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
              if (!snap.hasData) return const Center(child: CircularProgressIndicator(strokeWidth: 2));
              final docs = snap.data!.docs.where((d) => StorexRepo.onlyApproved(d.data())).toList();
              final products = docs.map(GroupProduct.fromFirestore).toList();
              if (products.isEmpty) {
                return _Empty(l10n.AppLocalizations.of(context)!.noProductsFound);
              }

              if (grid) {
                return GridView.builder(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 0.82,
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
                                ClipRRect(borderRadius: BorderRadius.circular(10), child: _Img(p: p, fit: BoxFit.cover)),
                                Positioned(
                                  right: 6, bottom: 6,
                                  child: InkResponse(
                                    onTap: () => repo.toggleWish(p),
                                    radius: 18,
                                    child: Icon(wished ? Icons.favorite : Icons.favorite_border, color: wished ? Colors.redAccent : Colors.black54, size: 20),
                                  ),
                                )
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(p.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          Text(p.priceLabel, style: const TextStyle(fontWeight: FontWeight.w800)),
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
                          width: 92, height: 92,
                          decoration: BoxDecoration(color: const Color(0xFFE3E5EA), borderRadius: BorderRadius.circular(10)),
                          child: ClipRRect(borderRadius: BorderRadius.circular(10), child: _Img(p: p, fit: BoxFit.cover)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(p.title, maxLines: 2, overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 8),
                              Text(p.priceLabel, style: const TextStyle(fontWeight: FontWeight.w800)),
                            ],
                          ),
                        ),
                        InkResponse(
                          onTap: () => repo.toggleWish(p),
                          radius: 20,
                          child: Icon(wished ? Icons.favorite : Icons.favorite_border, color: wished ? Colors.redAccent : Colors.black54),
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
      backgroundColor: Colors.white,
      drawer: _StorexDrawer(shopId: shopId, groupId: groupId),
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: StorexShopPage.rainbowGradient),
        ),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        actions: [
          LanguageSwitcher(textColor: Colors.white),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
        children: [
          Row(
            children: [
              Container(
                width: 54, height: 54,
                decoration: BoxDecoration(border: Border.all(color: Colors.black26), shape: BoxShape.circle),
                child: const Icon(Icons.person_outline, color: Colors.black54),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user?.displayName ?? "User", style: const TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text(user?.email ?? "not-signed-in", style: const TextStyle(color: Colors.black38)),
                  ],
                ),
              )
            ],
          ),
          const SizedBox(height: 20),
          _AccountRow(
            icon: Icons.receipt_long,
            label: l10n.AppLocalizations.of(context)!.myOrders,
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => _OrdersPage(repo: repo))),
          ),
          _AccountRow(
            icon: Icons.favorite_border,
            label: l10n.AppLocalizations.of(context)!.myFavorites,
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => _WishlistPage(repo: repo))),
          ),
          _AccountRow(
            icon: Icons.logout,
            label: l10n.AppLocalizations.of(context)!.logout,
            onTap: () async {
              final messenger = ScaffoldMessenger.of(context);
              final logoutLabel = l10n.AppLocalizations.of(context)!.logout;
              await FirebaseAuth.instance.signOut();
              messenger.showSnackBar(
                SnackBar(
                  content: Text(logoutLabel),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _AccountRow extends StatelessWidget {
  const _AccountRow({required this.icon, required this.label, required this.onTap});
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

class _WishlistPage extends StatelessWidget {
  const _WishlistPage({required this.repo});
  final StorexRepo repo;

  Future<GroupProduct?> _fetchProductById(String productId) async {
    final sid = repo.shopId?.trim();
    if (sid != null && sid.isNotEmpty) {
      final shopRef = FirebaseFirestore.instance
          .collection('shops')
          .doc(sid)
          .collection('products')
          .doc(productId);

      final shopSnap = await shopRef.get();
      if (shopSnap.exists) return GroupProduct.fromFirestore(shopSnap);
    }

    final rootRef = FirebaseFirestore.instance.collection('products').doc(productId);
    final rootSnap = await rootRef.get();
    if (rootSnap.exists) return GroupProduct.fromFirestore(rootSnap);
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black54),
            onPressed: () => Navigator.of(context).pop(),
          ),
          centerTitle: true,
          title: Text(
            l10n.AppLocalizations.of(context)!.myFavorites,
            style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w800),
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
                  'Connecte-toi pour voir ta wishlist.',
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
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white, elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.black54), onPressed: () => Navigator.of(context).pop()),
        centerTitle: true,
        title: Text(
          l10n.AppLocalizations.of(context)!.myFavorites,
          style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w800),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: repo.wishlistItems(),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator(strokeWidth: 2));
          final docs = snap.data!.docs;
          if (docs.isEmpty) {
            return _Empty(l10n.AppLocalizations.of(context)!.noFavoritesYet);
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
            itemCount: docs.length,
            separatorBuilder: (_, index) => const SizedBox(height: 12),
            itemBuilder: (_, i) {
              final d = docs[i].data();
              final productId = docs[i].id;
              final title = (d['title'] ?? 'Produit').toString();
              final priceCents = (d['priceCents'] is num) ? (d['priceCents'] as num).toInt() : null;
              final price = priceCents == null ? '' : "€${(priceCents / 100).toStringAsFixed(2)}";
              final imagePath = (d['imagePath'] ?? '').toString();
              final imageUrl = (d['imageUrl'] ?? '').toString();

              return Container(
                decoration: BoxDecoration(color: const Color(0xFFF1F2F4), borderRadius: BorderRadius.circular(10)),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Row(
                    children: [
                      Container(
                        width: 72, height: 72,
                        decoration: BoxDecoration(color: const Color(0xFFE3E5EA), borderRadius: BorderRadius.circular(8)),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: _ImgRaw(imagePath: imagePath, imageUrl: imageUrl, fit: BoxFit.cover),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title, maxLines: 2, overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 8),
                            Text(price, style: const TextStyle(fontWeight: FontWeight.w800)),
                            const SizedBox(height: 8),
                            SizedBox(
                              height: 36,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF1F232A),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                ),
                                onPressed: () async {
                                  final messenger = ScaffoldMessenger.of(context);
                                  try {
                                    debugPrint('[SHOP] Add wishlist item to cart: $productId');
                                    final p = await _fetchProductById(productId);
                                    if (p == null) {
                                      messenger.showSnackBar(
                                        const SnackBar(content: Text('Produit introuvable.')),
                                      );
                                      return;
                                    }

                                    final size = p.sizes.isNotEmpty ? p.sizes.first : 'M';
                                    final color = p.colors.isNotEmpty ? p.colors.first : 'Noir';

                                    CartService.instance.addProduct(
                                      groupId: (repo.groupId ?? 'MASLIVE'),
                                      product: p,
                                      size: size,
                                      color: color,
                                      quantity: 1,
                                    );

                                    messenger.showSnackBar(
                                      const SnackBar(content: Text('Ajouté au panier ✅')),
                                    );
                                  } catch (e) {
                                    messenger.showSnackBar(
                                      SnackBar(content: Text('Erreur ajout panier: $e')),
                                    );
                                  }
                                },
                                child: Text(l10n.AppLocalizations.of(context)!.addToCart),
                              ),
                            ),
                          ],
                        ),
                      )
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
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
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black54),
            onPressed: () => Navigator.of(context).pop(),
          ),
          centerTitle: true,
          title: Text(
            l10n.AppLocalizations.of(context)!.myOrders,
            style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w800),
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
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white, elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.black54), onPressed: () => Navigator.of(context).pop()),
        centerTitle: true,
        title: Text(
          l10n.AppLocalizations.of(context)!.myOrders,
          style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w800),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: repo.orders(),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator(strokeWidth: 2));
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
                final createdAt = (d['createdAt'] as Timestamp?)?.toDate().toString() ?? "";

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
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(color: isCancelled ? Colors.red : Colors.grey, borderRadius: BorderRadius.circular(6)),
                        child: Text(status, style: const TextStyle(color: Colors.white, fontSize: 12)),
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
/// CART WRAP (ta page existante)
/// =======================

class _CartWrap extends StatelessWidget {
  const _CartWrap();

  @override
  Widget build(BuildContext context) {
    return const CartPage();
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
    return _ImgRaw(imagePath: p.imagePath ?? '', imageUrl: p.imageUrl, fit: fit);
  }
}

class _ImgRaw extends StatelessWidget {
  const _ImgRaw({required this.imagePath, required this.imageUrl, required this.fit});
  final String imagePath;
  final String imageUrl;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final p = imagePath.trim();
    final u = imageUrl.trim();

    if (p.startsWith('assets/')) {
      return Image.asset(p, fit: fit, width: double.infinity, height: double.infinity, errorBuilder: (context, error, stackTrace) => _fallback());
    }
    if (u.startsWith('http')) {
      return Image.network(u, fit: fit, width: double.infinity, height: double.infinity, errorBuilder: (context, error, stackTrace) => _fallback());
    }
    return _fallback();
  }

  Widget _fallback() => Container(
        color: const Color(0xFFE3E5EA),
        child: const Center(child: Icon(Icons.shopping_bag_outlined, color: Color(0xFFB0B6C3), size: 36)),
      );
}

class _Empty extends StatelessWidget {
  const _Empty(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Center(child: Text(text, style: const TextStyle(color: Colors.black38)));
}
