import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'favorites_page.dart';
import 'login_page.dart';
import '../widgets/rainbow_header.dart';
import '../widgets/honeycomb_background.dart';
import '../admin/admin_main_dashboard.dart';
import '../commerce_module_single_file.dart';

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
                          title: "Commerce (Monolith)",
                          subtitle: "Gestion produits + photos",
                          icon: Icons.shopping_bag,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const ProductManagementPage(
                                  shopId: 'global',
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        _SectionCard(
                          title: "Boutique (Monolith)",
                          subtitle: "Panier + checkout",
                          icon: Icons.shopping_cart_outlined,
                          onTap: () {
                            final uid = FirebaseAuth.instance.currentUser?.uid ?? 'guest';
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => BoutiquePage(
                                  shopId: 'global',
                                  userId: uid,
                                ),
                              ),
                            );
                          },
                        ),
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
