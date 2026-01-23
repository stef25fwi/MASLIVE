import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'group_add_item_page.dart';
import 'pending_products_page.dart';
import 'favorites_page.dart';
import 'login_page.dart';
import 'create_circuit_features_page.dart';
import '../ui/map_access_labels.dart';
import '../widgets/rainbow_header.dart';
import '../widgets/honeycomb_background.dart';

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
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LoginPage()),
        );
      });
      return const SizedBox.shrink();
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _userDocStream(),
      builder: (context, snap) {
        final data = snap.data?.data() ?? {};
        final isAdmin = (data['isAdmin'] == true);
        final role = (data['role'] ?? 'user').toString();
        final groupId = (data['groupId'] as String?)?.trim();
        final isGroupAdmin = role == 'group' && (groupId != null && groupId.isNotEmpty);

        return Scaffold(
          body: HoneycombBackground(
            child: CustomScrollView(
              slivers: [
                const SliverToBoxAdapter(
                  child: RainbowHeader(
                    title: 'Mon compte',
                    trailing: Icon(
                      Icons.person_outline,
                      color: Colors.white,
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
              _AccountHeader(
                displayName: data['displayName'] ?? (user!.displayName ?? "Utilisateur"),
                email: user!.email ?? "",
                photoUrl: data['photoUrl'] ?? user!.photoURL,
                isAdmin: isAdmin,
              ),

              const SizedBox(height: 16),

              _SectionCard(
                title: "Mon profil",
                subtitle: "Infos, préférences, sécurité",
                icon: Icons.person,
                onTap: () => _showEditProfileSheet(context, initial: data),
              ),

              const SizedBox(height: 12),

              _SectionCard(
                title: "Mes favoris",
                subtitle: "Points & circuits sauvegardés",
                icon: Icons.bookmark,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const FavoritesPage()),
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
                    const SnackBar(content: Text("À brancher : page Historique")),
                  );
                },
              ),

              const SizedBox(height: 20),

              if (isAdmin) ...[
                const _SectionTitle("Espace Admin"),
                const SizedBox(height: 10),
                AdminTilesGrid(
                  onAddPoi: () => showDialog(
                    context: context,
                    builder: (_) => AddPoiDialog(db: _db, uid: user!.uid),
                  ),
                  onCreateCircuit: () => showDialog(
                    context: context,
                    builder: (_) => CreateCircuitDialog(db: _db, uid: user!.uid),
                  ),
                  onSetStartEnd: () => showDialog(
                    context: context,
                    builder: (_) => StartEndDialog(db: _db, uid: user!.uid),
                  ),
                  onModeration: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const PendingProductsPage()),
                    );
                  },
                ),
              ],

              if (isGroupAdmin) ...[
                const SizedBox(height: 20),
                const _SectionTitle("Espace Groupe"),
                const SizedBox(height: 10),
                GroupTilesGrid(
                  onAddItem: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => GroupAddItemPage(groupId: groupId),
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

  void _showEditProfileSheet(BuildContext context, {required Map<String, dynamic> initial}) {
    final nameCtrl = TextEditingController(text: initial['displayName'] ?? user!.displayName ?? "");
    final photoCtrl = TextEditingController(text: initial['photoUrl'] ?? user!.photoURL ?? "");

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16, right: 16, top: 12,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Modifier mon profil", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
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
                      'photoUrl': photoCtrl.text.trim().isEmpty ? null : photoCtrl.text.trim(),
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
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 6)),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: Colors.white,
            backgroundImage: (photoUrl == null || photoUrl!.isEmpty) ? null : NetworkImage(photoUrl!),
            child: (photoUrl == null || photoUrl!.isEmpty)
                ? const Icon(Icons.person, color: _adminAccent)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(displayName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: _adminAccent)),
                const SizedBox(height: 2),
                Text(email, style: const TextStyle(color: Colors.black54)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _Chip(label: isAdmin ? "Admin" : "Utilisateur", icon: isAdmin ? Icons.verified : Icons.person_outline),
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
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600, color: _adminAccent)),
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
    return Text(text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _adminAccent));
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
            BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 6)),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44, height: 44,
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
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w800, color: _adminAccent)),
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

class AdminTilesGrid extends StatelessWidget {
  final VoidCallback onAddPoi;
  final VoidCallback onCreateCircuit;
  final VoidCallback onSetStartEnd;
  final VoidCallback onModeration;

  const AdminTilesGrid({
    super.key,
    required this.onAddPoi,
    required this.onCreateCircuit,
    required this.onSetStartEnd,
    required this.onModeration,
  });

  @override
  Widget build(BuildContext context) {
    final mapLabels = mapAccessLabels();

    return GridView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.15,
      ),
      children: [
        _AdminTile(
          title: "Ajouter POI",
          subtitle: "Point d'intérêt",
          icon: Icons.add_location_alt,
          onTap: onAddPoi,
        ),
        _AdminTile(
          title: "Créer circuit",
          subtitle: "Itinéraire",
          icon: Icons.alt_route,
          onTap: onCreateCircuit,
        ),
        _AdminTile(
          title: "Départ / Arrivée",
          subtitle: "Points clés",
          icon: Icons.flag,
          onTap: onSetStartEnd,
        ),
        _AdminTile(
          title: "Articles à valider",
          subtitle: "Boutique",
          icon: Icons.shield,
          onTap: onModeration,
        ),
        _AdminTile(
          title: mapLabels.title,
          subtitle: mapLabels.subtitle,
          icon: Icons.map_outlined,
          onTap: () => Navigator.pushNamed(context, '/mapbox-google-light'),
        ),
        _AdminTile(
          title: "Éditeur de cartes",
          subtitle: "Créer / éditer (presets)",
          icon: Icons.edit,
          onTap: () => Navigator.pushNamed(context, '/map-admin'),
        ),
        _AdminTile(
          title: "Éditer circuit",
          subtitle: "Track Editor",
          icon: Icons.route,
          onTap: () => Navigator.pushNamed(context, '/admin/track-editor'),
        ),
        _AdminTile(
          title: "Bibliothèque",
          subtitle: "Année / Pays / Commune",
          icon: Icons.folder_copy_outlined,
          onTap: () => Navigator.pushNamed(context, '/admin/map-library'),
        ),
        _AdminTile(
          title: "Tracking Dash",
          subtitle: "Circuits & Suivi",
          icon: Icons.dashboard,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CreateCircuitFeaturesPage()),
            );
          },
        ),
      ],
    );
  }
}

class GroupTilesGrid extends StatelessWidget {
  final VoidCallback onAddItem;

  const GroupTilesGrid({
    super.key,
    required this.onAddItem,
  });

  @override
  Widget build(BuildContext context) {
    return GridView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.15,
      ),
      children: [
        _AdminTile(
          title: "Ajouter article",
          subtitle: "Boutique du groupe",
          icon: Icons.add_shopping_cart,
          onTap: onAddItem,
        ),
      ],
    );
  }
}

class _AdminTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _AdminTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 6)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 46, height: 46,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: _adminAccent.withValues(alpha: 0.1),
              ),
              child: Icon(icon, color: _adminAccent),
            ),
            const Spacer(),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w900, color: _adminAccent)),
            const SizedBox(height: 4),
            Text(subtitle, style: const TextStyle(color: Colors.black54)),
          ],
        ),
      ),
    );
  }
}

/// ---------- Dialogs (Firestore writes) ----------

class AddPoiDialog extends StatefulWidget {
  final FirebaseFirestore db;
  final String uid;
  const AddPoiDialog({super.key, required this.db, required this.uid});

  @override
  State<AddPoiDialog> createState() => _AddPoiDialogState();
}

class _AddPoiDialogState extends State<AddPoiDialog> {
  final nameCtrl = TextEditingController();
  final catCtrl = TextEditingController(text: "nature");
  final descCtrl = TextEditingController();
  final latCtrl = TextEditingController();
  final lngCtrl = TextEditingController();

  bool saving = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Ajouter un POI"),
      content: SingleChildScrollView(
        child: Column(
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: "Nom")),
            TextField(controller: catCtrl, decoration: const InputDecoration(labelText: "Catégorie")),
            TextField(controller: descCtrl, decoration: const InputDecoration(labelText: "Description")),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: TextField(controller: latCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Lat"))),
                const SizedBox(width: 8),
                Expanded(child: TextField(controller: lngCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Lng"))),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: saving ? null : () => Navigator.pop(context), child: const Text("Annuler")),
        FilledButton(
          onPressed: saving ? null : () async {
            final nav = Navigator.of(context);
            final name = nameCtrl.text.trim();
            final cat = catCtrl.text.trim();
            final desc = descCtrl.text.trim();
            final lat = double.tryParse(latCtrl.text.trim());
            final lng = double.tryParse(lngCtrl.text.trim());

            if (name.isEmpty || lat == null || lng == null) return;

            setState(() => saving = true);
            await widget.db.collection('pois').add({
              'name': name,
              'category': cat.isEmpty ? 'other' : cat,
              'description': desc,
              'lat': lat,
              'lng': lng,
              'createdAt': FieldValue.serverTimestamp(),
              'createdBy': widget.uid,
              'isActive': true,
            });
            if (mounted) nav.pop();
          },
          child: saving ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text("Enregistrer"),
        ),
      ],
    );
  }
}

class CreateCircuitDialog extends StatefulWidget {
  final FirebaseFirestore db;
  final String uid;
  const CreateCircuitDialog({super.key, required this.db, required this.uid});

  @override
  State<CreateCircuitDialog> createState() => _CreateCircuitDialogState();
}

class _CreateCircuitDialogState extends State<CreateCircuitDialog> {
  final titleCtrl = TextEditingController();
  final descCtrl = TextEditingController();

  // départ
  final sLatCtrl = TextEditingController();
  final sLngCtrl = TextEditingController();
  final sLabelCtrl = TextEditingController(text: "Départ");

  // arrivée
  final eLatCtrl = TextEditingController();
  final eLngCtrl = TextEditingController();
  final eLabelCtrl = TextEditingController(text: "Arrivée");

  bool saving = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Créer un circuit"),
      content: SingleChildScrollView(
        child: Column(
          children: [
            TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: "Titre")),
            TextField(controller: descCtrl, decoration: const InputDecoration(labelText: "Description")),
            const SizedBox(height: 10),

            const Align(
              alignment: Alignment.centerLeft,
              child: Text("Point de départ", style: TextStyle(fontWeight: FontWeight.w800)),
            ),
            TextField(controller: sLabelCtrl, decoration: const InputDecoration(labelText: "Label")),
            Row(
              children: [
                Expanded(child: TextField(controller: sLatCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Lat"))),
                const SizedBox(width: 8),
                Expanded(child: TextField(controller: sLngCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Lng"))),
              ],
            ),

            const SizedBox(height: 10),

            const Align(
              alignment: Alignment.centerLeft,
              child: Text("Point d'arrivée", style: TextStyle(fontWeight: FontWeight.w800)),
            ),
            TextField(controller: eLabelCtrl, decoration: const InputDecoration(labelText: "Label")),
            Row(
              children: [
                Expanded(child: TextField(controller: eLatCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Lat"))),
                const SizedBox(width: 8),
                Expanded(child: TextField(controller: eLngCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Lng"))),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: saving ? null : () => Navigator.pop(context), child: const Text("Annuler")),
        FilledButton(
          onPressed: saving ? null : () async {
            final nav = Navigator.of(context);
            final title = titleCtrl.text.trim();
            final sLat = double.tryParse(sLatCtrl.text.trim());
            final sLng = double.tryParse(sLngCtrl.text.trim());
            final eLat = double.tryParse(eLatCtrl.text.trim());
            final eLng = double.tryParse(eLngCtrl.text.trim());

            if (title.isEmpty || sLat == null || sLng == null || eLat == null || eLng == null) return;

            setState(() => saving = true);
            await widget.db.collection('circuits').add({
              'title': title,
              'description': descCtrl.text.trim(),
              'start': {'lat': sLat, 'lng': sLng, 'label': sLabelCtrl.text.trim()},
              'end': {'lat': eLat, 'lng': eLng, 'label': eLabelCtrl.text.trim()},
              'points': [],
              'createdAt': FieldValue.serverTimestamp(),
              'createdBy': widget.uid,
              'isPublished': false,
            });
            if (mounted) nav.pop();
          },
          child: saving ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text("Créer"),
        ),
      ],
    );
  }
}

/// Option simple : enregistrer un "draft" départ/arrivée global (ex: config)
class StartEndDialog extends StatefulWidget {
  final FirebaseFirestore db;
  final String uid;
  const StartEndDialog({super.key, required this.db, required this.uid});

  @override
  State<StartEndDialog> createState() => _StartEndDialogState();
}

class _StartEndDialogState extends State<StartEndDialog> {
  final sLatCtrl = TextEditingController();
  final sLngCtrl = TextEditingController();
  final eLatCtrl = TextEditingController();
  final eLngCtrl = TextEditingController();
  bool saving = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Départ / Arrivée (config)"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Align(alignment: Alignment.centerLeft, child: Text("Départ", style: TextStyle(fontWeight: FontWeight.w800))),
          Row(
            children: [
              Expanded(child: TextField(controller: sLatCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Lat"))),
              const SizedBox(width: 8),
              Expanded(child: TextField(controller: sLngCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Lng"))),
            ],
          ),
          const SizedBox(height: 10),
          const Align(alignment: Alignment.centerLeft, child: Text("Arrivée", style: TextStyle(fontWeight: FontWeight.w800))),
          Row(
            children: [
              Expanded(child: TextField(controller: eLatCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Lat"))),
              const SizedBox(width: 8),
              Expanded(child: TextField(controller: eLngCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Lng"))),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: saving ? null : () => Navigator.pop(context), child: const Text("Annuler")),
        FilledButton(
          onPressed: saving ? null : () async {
            final nav = Navigator.of(context);
            final sLat = double.tryParse(sLatCtrl.text.trim());
            final sLng = double.tryParse(sLngCtrl.text.trim());
            final eLat = double.tryParse(eLatCtrl.text.trim());
            final eLng = double.tryParse(eLngCtrl.text.trim());
            if (sLat == null || sLng == null || eLat == null || eLng == null) return;

            setState(() => saving = true);
            await widget.db.collection('config').doc('routing').set({
              'start': {'lat': sLat, 'lng': sLng},
              'end': {'lat': eLat, 'lng': eLng},
              'updatedAt': FieldValue.serverTimestamp(),
              'updatedBy': widget.uid,
            }, SetOptions(merge: true));

            if (mounted) nav.pop();
          },
          child: saving ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text("Enregistrer"),
        ),
      ],
    );
  }
}
