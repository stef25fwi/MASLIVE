import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'admin_gate.dart';

class AdminProductCategoriesPage extends StatefulWidget {
  const AdminProductCategoriesPage({super.key});

  @override
  State<AdminProductCategoriesPage> createState() =>
      _AdminProductCategoriesPageState();
}

class _AdminProductCategoriesPageState
    extends State<AdminProductCategoriesPage> {
  final _db = FirebaseFirestore.instance;
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AdminGate(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Catégories produits'),
          actions: [
            IconButton(
              tooltip: 'Ajouter',
              onPressed: _addCategory,
              icon: const Icon(Icons.add),
            ),
          ],
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _searchCtrl,
                decoration: const InputDecoration(
                  hintText: 'Rechercher une catégorie…',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _db
                    .collection('productCategories')
                    .orderBy('name')
                    .limit(200)
                    .snapshots(),
                builder: (context, catSnap) {
                  if (!catSnap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: _db
                        .collection('products')
                        .orderBy('updatedAt', descending: true)
                        .limit(800)
                        .snapshots(),
                    builder: (context, prodSnap) {
                      final counts = <String, int>{};
                      if (prodSnap.hasData) {
                        for (final d in prodSnap.data!.docs) {
                          final c = (d.data()['category'] ?? '')
                              .toString()
                              .trim();
                          if (c.isEmpty) continue;
                          counts[c] = (counts[c] ?? 0) + 1;
                        }
                      }

                      final search = _searchCtrl.text.trim().toLowerCase();

                      final cats =
                          catSnap.data!.docs
                              .map(
                                (d) =>
                                    (d.data()['name'] ?? '').toString().trim(),
                              )
                              .where((n) => n.isNotEmpty)
                              .toSet()
                              .toList()
                            ..sort();

                      // Ajouter les catégories observées dans les produits (même si pas encore dans productCategories)
                      for (final c in counts.keys) {
                        if (!cats.contains(c)) cats.add(c);
                      }
                      cats.sort();

                      final filtered = cats.where((c) {
                        if (search.isEmpty) return true;
                        return c.toLowerCase().contains(search);
                      }).toList();

                      if (filtered.isEmpty) {
                        return const Center(child: Text('Aucune catégorie'));
                      }

                      return ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, i) {
                          final name = filtered[i];
                          final count = counts[name] ?? 0;

                          return ListTile(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            tileColor: Colors.white,
                            leading: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: Colors.blue.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.category,
                                color: Colors.blue,
                              ),
                            ),
                            title: Text(
                              name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            subtitle: Text(
                              '$count produit${count > 1 ? 's' : ''} (échantillon récent)',
                            ),
                            trailing: PopupMenuButton<String>(
                              itemBuilder: (_) => const [
                                PopupMenuItem(
                                  value: 'rename',
                                  child: Text('Renommer'),
                                ),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Text('Supprimer'),
                                ),
                              ],
                              onSelected: (v) {
                                if (v == 'rename') {
                                  _renameCategory(oldName: name);
                                } else if (v == 'delete') {
                                  _deleteCategory(name: name);
                                }
                              },
                            ),
                          );
                        },
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

  String _idForName(String name) {
    final cleaned = name
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), '-')
        .replaceAll(RegExp(r'[^a-z0-9\-_]'), '');
    return cleaned.isEmpty
        ? DateTime.now().millisecondsSinceEpoch.toString()
        : cleaned;
  }

  Future<void> _upsertCategory(String name) async {
    final id = _idForName(name);
    await _db.collection('productCategories').doc(id).set({
      'name': name.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _addCategory() async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nouvelle catégorie'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            labelText: 'Nom',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Créer'),
          ),
        ],
      ),
    );

    final name = ctrl.text.trim();
    ctrl.dispose();

    if (ok != true || name.isEmpty) return;

    try {
      await _upsertCategory(name);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('✅ Catégorie créée')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('❌ Erreur: $e')));
    }
  }

  Future<void> _renameCategory({required String oldName}) async {
    final ctrl = TextEditingController(text: oldName);
    bool migrate = true;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Renommer catégorie'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: ctrl,
                decoration: const InputDecoration(
                  labelText: 'Nouveau nom',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              CheckboxListTile(
                value: migrate,
                onChanged: (v) => setState(() => migrate = v ?? true),
                title: const Text('Mettre à jour les produits existants'),
                controlAffinity: ListTileControlAffinity.leading,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Renommer'),
            ),
          ],
        ),
      ),
    );

    final newName = ctrl.text.trim();
    ctrl.dispose();

    if (ok != true || newName.isEmpty || newName == oldName) return;

    try {
      await _upsertCategory(newName);
      if (migrate) {
        await _migrateProductsCategory(from: oldName, to: newName);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('✅ Catégorie renommée')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('❌ Erreur: $e')));
    }
  }

  Future<void> _deleteCategory({required String name}) async {
    bool migrate = true;
    const fallback = 'Autre';

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Supprimer catégorie'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Supprimer "$name" ?'),
              const SizedBox(height: 10),
              CheckboxListTile(
                value: migrate,
                onChanged: (v) => setState(() => migrate = v ?? true),
                title: const Text('Remplacer dans les produits existants'),
                subtitle: const Text('Les produits passeront sur "Autre".'),
                controlAffinity: ListTileControlAffinity.leading,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Supprimer'),
            ),
          ],
        ),
      ),
    );

    if (ok != true) return;

    try {
      // best-effort: supprimer tous les docs qui matchent le nom
      final snap = await _db
          .collection('productCategories')
          .where('name', isEqualTo: name)
          .limit(20)
          .get();
      for (final d in snap.docs) {
        await d.reference.delete();
      }

      if (migrate) {
        await _migrateProductsCategory(from: name, to: fallback);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('✅ Catégorie supprimée')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('❌ Erreur: $e')));
    }
  }

  Future<void> _migrateProductsCategory({
    required String from,
    required String to,
  }) async {
    DocumentSnapshot<Map<String, dynamic>>? last;

    while (true) {
      Query<Map<String, dynamic>> q = _db
          .collection('products')
          .where('category', isEqualTo: from)
          .orderBy(FieldPath.documentId)
          .limit(350);
      if (last != null) q = q.startAfterDocument(last);

      final snap = await q.get();
      if (snap.docs.isEmpty) return;

      final batch = _db.batch();
      for (final d in snap.docs) {
        final data = d.data();
        final shopId = (data['shopId'] as String?)?.trim();

        final payload = <String, dynamic>{
          'category': to,
          'updatedAt': FieldValue.serverTimestamp(),
        };

        batch.set(d.reference, payload, SetOptions(merge: true));

        if (shopId != null && shopId.isNotEmpty) {
          final mirror = _db
              .collection('shops')
              .doc(shopId)
              .collection('products')
              .doc(d.id);
          batch.set(mirror, payload, SetOptions(merge: true));
        }
      }

      await batch.commit();
      last = snap.docs.last;

      // S'il y a peu de docs, on a fini.
      if (snap.docs.length < 350) return;
    }
  }
}
