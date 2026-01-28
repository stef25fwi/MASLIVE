import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'admin_gate.dart';

class AdminStockPage extends StatefulWidget {
  const AdminStockPage({super.key, this.shopId});

  final String? shopId;

  @override
  State<AdminStockPage> createState() => _AdminStockPageState();
}

class _AdminStockPageState extends State<AdminStockPage> {
  final _db = FirebaseFirestore.instance;

  final _searchCtrl = TextEditingController();
  String _filter = 'all';

  static const _filters = <String>['all', 'low', 'out'];

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
          title: const Text('Stock (Admin)'),
          actions: [
            IconButton(
              tooltip: 'Rafraîchir',
              onPressed: () => setState(() {}),
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(
                    controller: _searchCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Rechercher un produit…',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      for (final f in _filters)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            selected: _filter == f,
                            label: Text(_filterLabel(f)),
                            onSelected: (_) => setState(() => _filter = f),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _db
                    .collection('products')
                    .orderBy('updatedAt', descending: true)
                    .limit(400)
                    .snapshots(),
                builder: (context, snap) {
                  if (!snap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final search = _searchCtrl.text.trim().toLowerCase();

                  final docs = snap.data!.docs.where((d) {
                    final data = d.data();
                    if (widget.shopId != null &&
                        widget.shopId!.trim().isNotEmpty) {
                      final shopId = (data['shopId'] ?? '').toString();
                      if (shopId != widget.shopId) return false;
                    }

                    final title = ((data['name'] ?? data['title']) ?? '')
                        .toString()
                        .toLowerCase();
                    if (search.isNotEmpty && !title.contains(search))
                      return false;

                    final stock = _computeTotalStock(data);
                    if (_filter == 'out' && stock > 0) return false;
                    if (_filter == 'low' && !(stock > 0 && stock <= 5))
                      return false;

                    return true;
                  }).toList();

                  if (docs.isEmpty) {
                    return const Center(child: Text('Aucun produit'));
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: docs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, i) {
                      final doc = docs[i];
                      final data = doc.data();
                      final title = ((data['name'] ?? data['title']) ?? '')
                          .toString();
                      final category = (data['category'] ?? '').toString();
                      final stock = _computeTotalStock(data);

                      return InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => _editStock(productId: doc.id, data: data),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.black12),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 46,
                                height: 46,
                                decoration: BoxDecoration(
                                  color: _stockColor(
                                    stock,
                                  ).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  Icons.inventory_2,
                                  color: _stockColor(stock),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      title,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      category.isEmpty ? '—' : category,
                                      style: const TextStyle(
                                        color: Colors.black54,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: _stockColor(
                                    stock,
                                  ).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  'Stock: $stock',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    color: _stockColor(stock),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(Icons.chevron_right),
                            ],
                          ),
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

  String _filterLabel(String f) {
    switch (f) {
      case 'all':
        return 'Tous';
      case 'low':
        return 'Faible (≤ 5)';
      case 'out':
        return 'Rupture';
      default:
        return f;
    }
  }

  Color _stockColor(int stock) {
    if (stock <= 0) return const Color(0xFFB42318);
    if (stock <= 5) return const Color(0xFFB54708);
    return const Color(0xFF067647);
  }

  int _computeTotalStock(Map<String, dynamic> data) {
    final raw = data['stockByVariant'];
    if (raw is Map) {
      int sum = 0;
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

  Map<String, int> _parseStockByVariant(dynamic raw) {
    if (raw is Map) {
      return raw.map((k, v) {
        final key = k.toString();
        final value = (v is int) ? v : int.tryParse(v.toString()) ?? 0;
        return MapEntry(key, value);
      });
    }
    return <String, int>{};
  }

  Future<void> _editStock({
    required String productId,
    required Map<String, dynamic> data,
  }) async {
    final shopId = (data['shopId'] as String?)?.trim();
    final title = ((data['name'] ?? data['title']) ?? '').toString();

    final initialStockByVariant = _parseStockByVariant(data['stockByVariant']);
    final initialStock = _computeTotalStock(data);

    final map = <String, TextEditingController>{};
    void addController(String key, int value) {
      map[key] = TextEditingController(text: value.toString());
    }

    if (initialStockByVariant.isNotEmpty) {
      for (final e in initialStockByVariant.entries) {
        addController(e.key, e.value);
      }
    } else {
      addController('default|default', initialStock);
    }

    final newKeyCtrl = TextEditingController();
    final newQtyCtrl = TextEditingController(text: '0');

    bool saving = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Stock: $title'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ...map.entries.map((e) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              e.key,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          SizedBox(
                            width: 120,
                            child: TextField(
                              controller: e.value,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Qté',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            tooltip: 'Supprimer variante',
                            onPressed: saving
                                ? null
                                : () {
                                    setDialogState(() {
                                      map.remove(e.key)?.dispose();
                                    });
                                  },
                            icon: const Icon(Icons.delete_outline),
                          ),
                        ],
                      ),
                    );
                  }),
                  const Divider(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: newKeyCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Variante (taille|couleur)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 120,
                        child: TextField(
                          controller: newQtyCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Qté',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        onPressed: saving
                            ? null
                            : () {
                                final key = newKeyCtrl.text.trim();
                                final qty =
                                    int.tryParse(newQtyCtrl.text.trim()) ?? 0;
                                if (key.isEmpty) return;
                                if (map.containsKey(key)) return;
                                setDialogState(() {
                                  addController(key, qty);
                                  newKeyCtrl.clear();
                                  newQtyCtrl.text = '0';
                                });
                              },
                        icon: const Icon(Icons.add),
                        label: const Text('Ajouter'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (saving) const LinearProgressIndicator(),
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Astuce: le shop utilise stockByVariant.',
                      style: TextStyle(
                        color: Colors.black.withValues(alpha: 0.55),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(ctx),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      final stockByVariant = <String, int>{};
                      for (final e in map.entries) {
                        final v = int.tryParse(e.value.text.trim()) ?? 0;
                        stockByVariant[e.key] = v;
                      }

                      if (stockByVariant.isEmpty) {
                        stockByVariant['default|default'] = 0;
                      }

                      final total = stockByVariant.values.fold<int>(
                        0,
                        (a, b) => a + b,
                      );

                      setDialogState(() => saving = true);
                      try {
                        final payload = <String, dynamic>{
                          'stockByVariant': stockByVariant,
                          'stock': total,
                          'updatedAt': FieldValue.serverTimestamp(),
                        };

                        await _db
                            .collection('products')
                            .doc(productId)
                            .set(payload, SetOptions(merge: true));

                        if (shopId != null && shopId.isNotEmpty) {
                          await _db
                              .collection('shops')
                              .doc(shopId)
                              .collection('products')
                              .doc(productId)
                              .set(payload, SetOptions(merge: true));
                        }

                        if (!ctx.mounted) return;
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('✅ Stock mis à jour')),
                        );
                      } catch (e) {
                        if (!ctx.mounted) return;
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text('❌ Erreur: $e')));
                      } finally {
                        if (ctx.mounted) setDialogState(() => saving = false);
                      }
                    },
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );

    for (final c in map.values) {
      c.dispose();
    }
    newKeyCtrl.dispose();
    newQtyCtrl.dispose();
  }
}
