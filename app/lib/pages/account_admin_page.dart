import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'favorites_page.dart';
import 'login_page.dart';
import 'media_gallery_maslive_instagram_page.dart';
import '../widgets/rainbow_header.dart';
import '../widgets/honeycomb_background.dart';
import '../admin/admin_main_dashboard.dart';
import '../admin/admin_stock_page.dart';
import '../admin/admin_product_categories_page.dart';
import '../admin/commerce_analytics_page.dart';
import 'storex_shop_page.dart';

const Color _adminAccent = Color(0xFF1E88E5);

class AccountAndAdminPage extends StatefulWidget {
  const AccountAndAdminPage({super.key});

  @override
  State<AccountAndAdminPage> createState() => _AccountAndAdminPageState();
}

class _AccountAndAdminPageState extends State<AccountAndAdminPage> {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  User? get user => _auth.currentUser;

  Stream<DocumentSnapshot<Map<String, dynamic>>> _userDocStream() {
    final uid = user?.uid;
    return _db.collection('users').doc(uid).snapshots();
  }

  @override
  Widget build(BuildContext context) {
    if (user == null) {
      // Rediriger vers la page de connexion si non connecté
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(
          context,
        ).pushReplacement(MaterialPageRoute(builder: (_) => const LoginPage()));
      });
      return const SizedBox.shrink();
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _userDocStream(),
      builder: (context, snap) {
        final data = snap.data?.data() ?? {};
        final isAdmin = (data['isAdmin'] == true);
        final role = (data['role'] ?? '').toString().trim().toLowerCase();
        final isSuperAdmin = role == 'superadmin';
        final isStephane = (user?.email ?? '').toLowerCase() == 's-stephane@live.fr';
        final showSuperAdminCommerce = isSuperAdmin || isStephane;

        return Scaffold(
          body: HoneycombBackground(
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: RainbowHeader(
                    title: 'Espace administrateur',
                    leading: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      _AccountHeader(
                        displayName:
                            data['displayName'] ??
                            (user!.displayName ?? "Utilisateur"),
                        email: user!.email ?? "",
                        photoUrl: data['photoUrl'] ?? user!.photoURL,
                        isAdmin: isAdmin,
                      ),

                      const SizedBox(height: 16),

                      _SectionCard(
                        title: "Mon profil",
                        subtitle: "Infos, préférences, sécurité",
                        icon: Icons.person,
                        onTap: () =>
                            _showEditProfileSheet(context, initial: data),
                      ),

                      const SizedBox(height: 12),

                      _SectionCard(
                        title: "Mes favoris",
                        subtitle: "Points & circuits sauvegardés",
                        icon: Icons.bookmark,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const FavoritesPage(),
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 12),

                      _SectionCard(
                        title: "Historique",
                        subtitle: "Dernières actions sur la carte",
                        icon: Icons.history,
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("À brancher : page Historique"),
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 12),

                      _SectionCard(
                        title: "Inbox vendeur",
                        subtitle: "Commandes à valider",
                        icon: Icons.inbox,
                        onTap: () {
                          Navigator.of(context).pushNamed('/seller-inbox');
                        },
                      ),

                      const SizedBox(height: 20),

                      if (isAdmin) ...[
                        const _SectionTitle("Espace Admin"),
                        const SizedBox(height: 10),
                        _SectionCard(
                          title: "Dashboard Administrateur",
                          subtitle: "Vue d'ensemble complète de la gestion",
                          icon: Icons.dashboard,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const AdminMainDashboard(),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        _SectionCard(
                          title: "Galerie Médias",
                          subtitle: "Consulter et gérer les médias MAS'LIVE",
                          icon: Icons.photo_library,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const MediaGalleryMasliveInstagramPage(),
                              ),
                            );
                          },
                        ),
                        if (showSuperAdminCommerce) ...[
                          const SizedBox(height: 20),
                          const _SectionTitle('Commerce (SuperAdmin)'),
                          const SizedBox(height: 10),
                          _SuperAdminCommerceSection(
                            shopId: 'global',
                            email: user?.email ?? '',
                          ),
                        ],
                      ],
                    ]),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showEditProfileSheet(
    BuildContext context, {
    required Map<String, dynamic> initial,
  }) {
    final nameCtrl = TextEditingController(
      text: initial['displayName'] ?? user!.displayName ?? "",
    );
    final photoCtrl = TextEditingController(
      text: initial['photoUrl'] ?? user!.photoURL ?? "",
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 12,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Modifier mon profil",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: "Nom affiché",
                  prefixIcon: Icon(Icons.badge),
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: photoCtrl,
                decoration: const InputDecoration(
                  labelText: "URL photo (optionnel)",
                  prefixIcon: Icon(Icons.image),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.save),
                  label: const Text("Enregistrer"),
                  onPressed: () async {
                    final nav = Navigator.of(context);
                    final uid = user!.uid;
                    await _db.collection('users').doc(uid).set({
                      'displayName': nameCtrl.text.trim(),
                      'photoUrl': photoCtrl.text.trim().isEmpty
                          ? null
                          : photoCtrl.text.trim(),
                      'updatedAt': FieldValue.serverTimestamp(),
                    }, SetOptions(merge: true));

                    if (mounted) nav.pop();
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// ---------- UI Components ----------

class _AccountHeader extends StatelessWidget {
  final String displayName;
  final String email;
  final String? photoUrl;
  final bool isAdmin;

  const _AccountHeader({
    required this.displayName,
    required this.email,
    required this.photoUrl,
    required this.isAdmin,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: Colors.white,
            backgroundImage: (photoUrl == null || photoUrl!.isEmpty)
                ? null
                : NetworkImage(photoUrl!),
            child: (photoUrl == null || photoUrl!.isEmpty)
                ? const Icon(Icons.person, color: _adminAccent)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: _adminAccent,
                  ),
                ),
                const SizedBox(height: 2),
                Text(email, style: const TextStyle(color: Colors.black54)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _Chip(
                      label: isAdmin ? "Admin" : "Utilisateur",
                      icon: isAdmin ? Icons.verified : Icons.person_outline,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final IconData icon;
  const _Chip({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: _adminAccent.withValues(alpha: 0.12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: _adminAccent),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: _adminAccent,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w800,
        color: _adminAccent,
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 10,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: _adminAccent.withValues(alpha: 0.1),
              ),
              child: Icon(icon, color: _adminAccent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: _adminAccent,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(subtitle, style: const TextStyle(color: Colors.black54)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: _adminAccent),
          ],
        ),
      ),
    );
  }
}

class _SuperAdminCommerceSection extends StatelessWidget {
  const _SuperAdminCommerceSection({required this.shopId, required this.email});

  final String shopId;
  final String email;

  @override
  Widget build(BuildContext context) {
    final db = FirebaseFirestore.instance;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Articles boutique (actifs)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              'Profil: $email',
              style: const TextStyle(color: Colors.black54, fontSize: 12),
            ),
            const SizedBox(height: 12),
            _CommerceQuickLinks(shopId: shopId),
            const SizedBox(height: 12),
            _CommercePathsCard(shopId: shopId),
            const SizedBox(height: 12),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: db
                  .collection('shops')
                  .doc(shopId)
                  .collection('products')
                  .where('isActive', isEqualTo: true)
                  .where('moderationStatus', isEqualTo: 'approved')
                  .orderBy('updatedAt', descending: true)
                  .limit(12)
                  .snapshots(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (!snap.hasData || snap.data!.docs.isEmpty) {
                  return const Text(
                    'Aucun article actif trouvé dans la boutique.',
                    style: TextStyle(color: Colors.black54),
                  );
                }

                final docs = snap.data!.docs;
                return Column(
                  children: [
                    for (final doc in docs)
                      _CommerceProductTile(data: doc.data()),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _CommerceQuickLinks extends StatelessWidget {
  const _CommerceQuickLinks({required this.shopId});

  final String shopId;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _CommerceLinkChip(
          label: 'Filtre boutique',
          icon: Icons.filter_list,
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
        _CommerceLinkChip(
          label: 'Stock',
          icon: Icons.warehouse,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => AdminStockPage(shopId: shopId),
              ),
            );
          },
        ),
        _CommerceLinkChip(
          label: 'Analytics commerce',
          icon: Icons.analytics,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const CommerceAnalyticsPage(),
              ),
            );
          },
        ),
        _CommerceLinkChip(
          label: 'Catégories',
          icon: Icons.category,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const AdminProductCategoriesPage(),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _CommercePathsCard extends StatelessWidget {
  const _CommercePathsCard({required this.shopId});

  final String shopId;

  @override
  Widget build(BuildContext context) {
    final firestorePaths = <String>[
      'shops/$shopId/products',
      'products',
      'productCategories',
      'commerce_submissions',
    ];
    final storagePath = 'commerce/{scopeId}/{ownerUid}/{submissionId}/';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Chemins Firestore & Storage',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          for (final path in firestorePaths)
            _CommercePathRow(
              label: path,
              onCopy: () => _copy(context, path),
            ),
          const SizedBox(height: 6),
          _CommercePathRow(
            label: 'Storage: $storagePath',
            onCopy: () => _copy(context, storagePath),
          ),
        ],
      ),
    );
  }

  void _copy(BuildContext context, String value) {
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Copié: $value')),
    );
  }
}

class _CommercePathRow extends StatelessWidget {
  const _CommercePathRow({required this.label, required this.onCopy});

  final String label;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: Colors.black87),
            ),
          ),
          IconButton(
            tooltip: 'Copier',
            icon: const Icon(Icons.copy, size: 16),
            onPressed: onCopy,
          ),
        ],
      ),
    );
  }
}

class _CommerceLinkChip extends StatelessWidget {
  const _CommerceLinkChip({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: _adminAccent.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: _adminAccent.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: _adminAccent),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: _adminAccent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CommerceProductTile extends StatelessWidget {
  const _CommerceProductTile({required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final title = ((data['name'] ?? data['title']) ?? '').toString().trim();
    final category = (data['category'] ?? '').toString().trim();
    final stock = _computeTotalStock(data);
    final price = data['price']?.toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _stockColor(stock).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.shopping_bag, color: _stockColor(stock), size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.isEmpty ? '—' : title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                if (category.isNotEmpty)
                  Text(
                    category,
                    style: const TextStyle(color: Colors.black54, fontSize: 12),
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Stock: $stock',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: _stockColor(stock),
                ),
              ),
              if (price != null)
                Text(
                  '$price €',
                  style: const TextStyle(color: Colors.black54, fontSize: 12),
                ),
            ],
          ),
        ],
      ),
    );
  }

  static int _computeTotalStock(Map<String, dynamic> data) {
    final raw = data['stockByVariant'];
    if (raw is Map) {
      var sum = 0;
      raw.forEach((_, v) {
        final i = (v is int) ? v : int.tryParse(v.toString()) ?? 0;
        sum += i;
      });
      return sum;
    }
    final stock = data['stock'];
    if (stock is int) return stock;
    return int.tryParse(stock?.toString() ?? '') ?? 0;
  }

  static Color _stockColor(int stock) {
    if (stock <= 0) return const Color(0xFFB42318);
    if (stock <= 5) return const Color(0xFFB54708);
    return const Color(0xFF067647);
  }
}
