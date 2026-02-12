import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class SellerOrderDetailPage extends StatefulWidget {
  const SellerOrderDetailPage({super.key, required this.orderId});

  final String orderId;

  @override
  State<SellerOrderDetailPage> createState() => _SellerOrderDetailPageState();
}

class _SellerOrderDetailPageState extends State<SellerOrderDetailPage> {
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Commande'),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('orders').doc(widget.orderId).snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final doc = snap.data!;
          if (!doc.exists) {
            return const Center(child: Text('Commande introuvable'));
          }

          final data = doc.data() ?? {};
          final status = (data['status'] ?? 'pending').toString();
          final buyerId = (data['buyerId'] ?? data['userId'] ?? '').toString();
          final items = (data['items'] is List) ? (data['items'] as List).cast<dynamic>() : const <dynamic>[];

          final myItems = uid == null
              ? items
              : items.where((it) {
                  if (it is! Map) return false;
                  final sellerId = (it['sellerId'] ?? '').toString();
                  return sellerId.isEmpty || sellerId == uid;
                }).toList();

          final totalPrice = data['totalPrice'];
          final total = totalPrice is num ? totalPrice.toInt() : 0;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Commande #${widget.orderId.substring(0, 8).toUpperCase()}',
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
              ),
              const SizedBox(height: 10),
              Text('Acheteur: $buyerId', style: const TextStyle(color: Colors.black54)),
              const SizedBox(height: 10),
              _StatusChip(status: status),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 12),
              const Text('Articles', style: TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              ...myItems.map((it) {
                final m = it is Map ? it : <String, dynamic>{};
                final title = (m['title'] ?? '').toString();
                final qty = (m['qty'] ?? m['quantity'] ?? 1);
                final q = qty is num ? qty.toInt() : 1;
                final priceCents = (m['priceCents'] ?? m['pricePerUnit'] ?? 0);
                final p = priceCents is num ? priceCents.toInt() : 0;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title.isEmpty ? 'Article' : title, style: const TextStyle(fontWeight: FontWeight.w700)),
                            Text('x$q', style: const TextStyle(color: Colors.black54, fontSize: 12)),
                          ],
                        ),
                      ),
                      Text('${((p * q) / 100).toStringAsFixed(2)}€', style: const TextStyle(fontWeight: FontWeight.w900)),
                    ],
                  ),
                );
              }),
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total', style: TextStyle(fontWeight: FontWeight.w900)),
                  Text('${(total / 100).toStringAsFixed(2)}€', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                ],
              ),
              const SizedBox(height: 18),
              if (status == 'pending') ...[
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _saving ? null : () => _setStatus('validated'),
                        icon: const Icon(Icons.check),
                        label: const Text('Valider'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _saving ? null : () => _setStatus('rejected'),
                        icon: const Icon(Icons.close),
                        label: const Text('Rejeter'),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Future<void> _setStatus(String newStatus) async {
    setState(() => _saving = true);
    try {
      final ref = FirebaseFirestore.instance.collection('orders').doc(widget.orderId);
      await ref.update({
        'status': newStatus,
        if (newStatus == 'validated') 'validatedAt': FieldValue.serverTimestamp(),
        if (newStatus == 'rejected') 'rejectedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;
    switch (status) {
      case 'validated':
        color = Colors.green;
        label = 'Validée';
        break;
      case 'rejected':
        color = Colors.red;
        label = 'Rejetée';
        break;
      case 'paid':
        color = Colors.blue;
        label = 'Payée';
        break;
      case 'pending':
      default:
        color = Colors.orange;
        label = 'En attente';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(fontWeight: FontWeight.w900, color: color),
      ),
    );
  }
}
