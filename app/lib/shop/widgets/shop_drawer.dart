import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../pages/media_shop_page.dart';
import '../../models/group_product.dart';
import '../../widgets/language_switcher.dart';
import '../../l10n/app_localizations.dart' as l10n;

/// Drawer standardisé pour toutes les pages boutique
/// 
/// Affiche:
/// - Navigation principale (Home, Search, Profile)
/// - Lien vers Media Shop
/// - Catégories de produits dynamiques
/// - Sélecteur de langue
class ShopDrawer extends StatelessWidget {
  const ShopDrawer({
    super.key,
    this.shopId = 'global',
    this.groupId = 'MASLIVE',
    required this.onNavigateHome,
    required this.onNavigateSearch,
    required this.onNavigateProfile,
    required this.onNavigateCategory,
  });

  final String? shopId;
  final String? groupId;
  final VoidCallback onNavigateHome;
  final VoidCallback onNavigateSearch;
  final VoidCallback onNavigateProfile;
  final void Function(String? categoryId, String title) onNavigateCategory;

  static const String _allCategoryId = '__all__';

  @override
  Widget build(BuildContext context) {
    final repo = StorexRepo(shopId: shopId, groupId: groupId);
    final localizations = l10n.AppLocalizations.of(context)!;

    return Drawer(
      backgroundColor: Colors.white,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Logo
              Image.asset(
                'assets/images/maslivelogo.png',
                height: 40,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 30),
              
              // Éléments fixes
              ShopDrawerItem(
                localizations.home,
                () {
                  Navigator.of(context).pop();
                  onNavigateHome();
                },
                icon: Icons.home_rounded,
              ),
              const SizedBox(height: 4),
              ShopDrawerItem(
                localizations.search,
                () {
                  Navigator.of(context).pop();
                  onNavigateSearch();
                },
                icon: Icons.search_rounded,
              ),
              const SizedBox(height: 4),
              ShopDrawerItem(
                localizations.profile,
                () {
                  Navigator.of(context).pop();
                  onNavigateProfile();
                },
                icon: Icons.person_rounded,
              ),
              
              const Divider(height: 32, thickness: 1),
              
              // Media Shop section
              InkWell(
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const MediaShopPage(),
                  ));
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF4A90E2), Color(0xFF357ABD)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.shopping_bag_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Media Shop',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.arrow_forward_ios,
                        color: Colors.white,
                        size: 16,
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Header catégories
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 12),
                child: Text(
                  localizations.categories.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.black45,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              
              // Catégories dynamiques
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: repo.bestSeller(limit: 250).snapshots(),
                  builder: (context, snap) {
                    if (!snap.hasData) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      );
                    }

                    final docs = (snap.data?.docs ?? [])
                        .where((d) => StorexRepo.onlyApproved(d.data()))
                        .toList();
                    final products = docs.map(GroupProduct.fromFirestore).toList();

                    final set = <String>{};
                    for (final p in products) {
                      final c = p.category.trim();
                      if (c.isNotEmpty) set.add(c);
                    }
                    final cats = set.toList()..sort();
                    final finalCats = <String>[_allCategoryId, ...cats];

                    return ListView(
                      padding: EdgeInsets.zero,
                      children: finalCats.map((c) {
                        return ShopDrawerItem(
                          c == _allCategoryId ? localizations.all : c,
                          () {
                            Navigator.of(context).pop();
                            final title = c == _allCategoryId ? localizations.all : c;
                            final categoryId = c == _allCategoryId ? null : c;
                            onNavigateCategory(categoryId, title);
                          },
                          small: true,
                        );
                      }).toList(),
                    );
                  },
                ),
              ),
              
              // Language switcher
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  LanguageSwitcher(),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

/// Item du drawer (navigation)
class ShopDrawerItem extends StatelessWidget {
  const ShopDrawerItem(
    this.label,
    this.onTap, {
    super.key,
    this.small = false,
    this.icon,
  });

  final String label;
  final VoidCallback onTap;
  final bool small;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.symmetric(
          vertical: small ? 10 : 14,
          horizontal: 12,
        ),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 20, color: Colors.black87),
              const SizedBox(width: 12)
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: small ? 14 : 16,
                color: Colors.black87,
                fontWeight: small ? FontWeight.w600 : FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Repository Storex (queries Firestore)
/// 
/// Utilisé par le drawer pour récupérer les catégories dynamiques
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
      return q.where('categoryId', isEqualTo: categoryId).orderBy('updatedAt', descending: true).limit(limit);
    }

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

  /// Filtre: accepte "approved" OU champ absent
  static bool onlyApproved(Map<String, dynamic> d) {
    final ms = d['moderationStatus'];
    if (ms == null) return true;
    return ms.toString().toLowerCase() == 'approved';
  }
}
