import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/order_model.dart';
import '../services/order_service.dart';
import '../ui/snack/top_snack_bar.dart';
import 'admin_gate.dart';

class AdminOrdersPage extends StatefulWidget {
  const AdminOrdersPage({super.key});

  @override
  State<AdminOrdersPage> createState() => _AdminOrdersPageState();
}

class _AdminOrdersPageState extends State<AdminOrdersPage> {
  final _db = FirebaseFirestore.instance;
  final _orderService = OrderService();

  final _searchCtrl = TextEditingController();
  String _statusFilter = 'all';

  static const _statusOptions = <String>[
    'all',
    'pending',
    'confirmed',
    'shipped',
    'delivered',
    'cancelled',
  ];

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
          title: const Text('Commandes (Admin)'),
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
                      hintText: 'Rechercher (orderId, userId, groupId)…',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 40,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemBuilder: (context, i) {
                        final status = _statusOptions[i];
                        final selected = _statusFilter == status;
                        return ChoiceChip(
                          selected: selected,
                          label: Text(_statusLabel(status)),
                          onSelected: (_) =>
                              setState(() => _statusFilter = status),
                        );
                      },
                      separatorBuilder: (context, index) => const SizedBox(width: 8),
                      itemCount: _statusOptions.length,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _db
                    .collection('orders')
                    .orderBy('createdAt', descending: true)
                    .limit(300)
                    .snapshots(),
                builder: (context, snap) {
                  if (!snap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final search = _searchCtrl.text.trim().toLowerCase();

                  final orders = snap.data!.docs
                      .map((d) => ShopOrder.fromMap(d.id, d.data()))
                      .where((o) {
                        if (_statusFilter != 'all' &&
                            o.status != _statusFilter) {
                          return false;
                        }
                        if (search.isEmpty) return true;
                        return o.orderId.toLowerCase().contains(search) ||
                            o.userId.toLowerCase().contains(search) ||
                            o.groupId.toLowerCase().contains(search);
                      })
                      .toList();

                  if (orders.isEmpty) {
                    return const Center(child: Text('Aucune commande trouvée'));
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: orders.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                    itemBuilder: (context, i) {
                      final order = orders[i];
                      return _AdminOrderCard(
                        order: order,
                        onTap: () => _showOrderDetails(order),
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

  String _statusLabel(String status) {
    switch (status) {
      case 'all':
        return 'Toutes';
      case 'pending':
        return 'En attente';
      case 'confirmed':
        return 'Confirmées';
      case 'shipped':
        return 'Expédiées';
      case 'delivered':
        return 'Livrées';
      case 'cancelled':
        return 'Annulées';
      default:
        return status;
    }
  }

  Future<void> _showOrderDetails(ShopOrder order) async {
    final notesCtrl = TextEditingController(text: order.notes ?? '');
    String status = order.status;
    bool saving = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 8,
            bottom: 16 + MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: ListView(
            shrinkWrap: true,
            children: [
              Text(
                'Commande #${order.orderId.substring(0, 8).toUpperCase()}',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'userId: ${order.userId}',
                style: const TextStyle(color: Colors.black54),
              ),
              Text(
                'groupId: ${order.groupId}',
                style: const TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: status,
                decoration: const InputDecoration(
                  labelText: 'Statut',
                  border: OutlineInputBorder(),
                ),
                items: _statusOptions
                    .where((s) => s != 'all')
                    .map(
                      (s) => DropdownMenuItem(
                        value: s,
                        child: Text(_statusLabel(s)),
                      ),
                    )
                    .toList(),
                onChanged: saving
                    ? null
                    : (v) {
                        if (v == null) return;
                        setModalState(() => status = v);
                      },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Notes',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Articles',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              ...order.items.map(
                (it) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          it.title,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      Text(
                        'x${it.quantity}',
                        style: const TextStyle(color: Colors.black54),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '${(it.totalPrice / 100).toStringAsFixed(2)}€',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ),
              ),
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Total',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  Text(
                    order.formattedTotal,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (saving) const Center(child: CircularProgressIndicator()),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Supprimer'),
                      onPressed: saving
                          ? null
                          : () async {
                              final ok = await showDialog<bool>(
                                context: ctx,
                                builder: (confirmCtx) => Dialog(
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(maxWidth: 700),
                                    child: AlertDialog(
                                      title: const Text('Supprimer la commande ?'),
                                      content: const Text(
                                        'Cette action est irréversible.',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(confirmCtx, false),
                                          child: const Text('Annuler'),
                                        ),
                                        FilledButton(
                                          onPressed: () =>
                                              Navigator.pop(confirmCtx, true),
                                          child: const Text('Supprimer'),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                              if (ok != true) return;

                              setModalState(() => saving = true);
                              try {
                                await _orderService.deleteOrder(order.orderId);
                                if (ctx.mounted) Navigator.of(ctx).pop();
                              } catch (e) {
                                if (!ctx.mounted) return;
                                TopSnackBar.show(
                                  ctx,
                                  SnackBar(content: Text('❌ Erreur: $e')),
                                );
                              } finally {
                                if (ctx.mounted) {
                                  setModalState(() => saving = false);
                                }
                              }
                            },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      icon: const Icon(Icons.save),
                      label: const Text('Enregistrer'),
                      onPressed: saving
                          ? null
                          : () async {
                              setModalState(() => saving = true);
                              try {
                                final notes = notesCtrl.text.trim();
                                if (notes != (order.notes ?? '').trim()) {
                                  await _orderService.addNotes(
                                    order.orderId,
                                    notes,
                                  );
                                }
                                if (status != order.status) {
                                  await _orderService.updateStatus(
                                    order.orderId,
                                    status,
                                  );
                                }
                                if (ctx.mounted) {
                                  TopSnackBar.show(
                                    ctx,
                                    const SnackBar(
                                      content: Text('✅ Commande mise à jour'),
                                    ),
                                  );
                                  Navigator.of(ctx).pop();
                                }
                              } catch (e) {
                                if (!ctx.mounted) return;
                                TopSnackBar.show(
                                  ctx,
                                  SnackBar(content: Text('❌ Erreur: $e')),
                                );
                              } finally {
                                if (ctx.mounted) {
                                  setModalState(() => saving = false);
                                }
                              }
                            },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    notesCtrl.dispose();
  }
}

class _AdminOrderCard extends StatelessWidget {
  const _AdminOrderCard({required this.order, required this.onTap});

  final ShopOrder order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final userShort = order.userId.length <= 8
        ? order.userId
        : order.userId.substring(0, 8);

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.black12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '#${order.orderId.substring(0, 8).toUpperCase()}',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                _StatusBadge(status: order.status),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${order.items.length} article${order.items.length > 1 ? 's' : ''} • ${order.formattedTotal}',
              style: const TextStyle(
                color: Colors.black54,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'group: ${order.groupId} • user: $userShort',
              style: TextStyle(
                color: Colors.black.withValues(alpha: 0.55),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final String status;

  Color _color() {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'confirmed':
        return Colors.blue;
      case 'shipped':
        return Colors.blue;
      case 'delivered':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _label() {
    switch (status) {
      case 'pending':
        return 'En attente';
      case 'confirmed':
        return 'Confirmée';
      case 'shipped':
        return 'Expédiée';
      case 'delivered':
        return 'Livrée';
      case 'cancelled':
        return 'Annulée';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _color();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: c.withValues(alpha: 0.35)),
      ),
      child: Text(
        _label(),
        style: TextStyle(color: c, fontWeight: FontWeight.w900, fontSize: 12),
      ),
    );
  }
}
