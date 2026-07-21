import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../security/profile_capability_policy.dart';
import '../../widgets/capability_guard.dart';

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
    return CapabilityGuard.any(
      anyOf: const <Capability>[
        Capability.manageOwnGallery,
        Capability.manageArtGallery,
        Capability.manageGroupShop,
        Capability.manageAllOrders,
      ],
      fullPage: true,
      message: 'Vous ne disposez pas d’un espace vendeur autorisé.',
      child: _OrderContent(
        orderId: widget.orderId,
        saving: _saving,
        onSetStatus: _setStatus,
      ),
    );
  }

  Future<void> _setStatus(String newStatus) async {
    setState(() => _saving = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      final profile = await ProfileCapabilityPolicy.instance.resolveCurrent();
      if (uid == null || profile == null) {
        throw StateError('Connexion requise');
      }

      final ref = FirebaseFirestore.instance.collection('orders').doc(widget.orderId);
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final snapshot = await transaction.get(ref);
        if (!snapshot.exists) throw StateError('Commande introuvable');
        final data = snapshot.data() ?? <String, dynamic>{};
        final items = data['items'] is List
            ? (data['items'] as List).whereType<Map>().toList(growable: false)
            : const <Map>[];
        final ownsItem = items.any(
          (item) => (item['sellerId'] ?? '').toString() == uid,
        );
        final canManageAll = profile.can(Capability.manageAllOrders);
        if (!ownsItem && !canManageAll) {
          throw StateError('Cette commande ne contient aucun article de votre espace vendeur.');
        }

        transaction.update(ref, <String, dynamic>{
          'sellerStatuses.$uid': newStatus,
          if (newStatus == 'validated')
            'sellerValidatedAt.$uid': FieldValue.serverTimestamp(),
          if (newStatus == 'rejected')
            'sellerRejectedAt.$uid': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _OrderContent extends StatelessWidget {
  const _OrderContent({
    required this.orderId,
    required this.saving,
    required this.onSetStatus,
  });

  final String orderId;
  final bool saving;
  final Future<void> Function(String status) onSetStatus;

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return Scaffold(
      appBar: AppBar(title: const Text('Commande vendeur')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('orders').doc(orderId).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final document = snapshot.data!;
          if (!document.exists) {
            return const Center(child: Text('Commande introuvable'));
          }

          final data = document.data() ?? <String, dynamic>{};
          final allItems = data['items'] is List
              ? (data['items'] as List).whereType<Map>().toList(growable: false)
              : const <Map>[];
          final myItems = allItems
              .where((item) => (item['sellerId'] ?? '').toString() == uid)
              .toList(growable: false);
          final sellerStatuses = data['sellerStatuses'] is Map
              ? Map<String, dynamic>.from(data['sellerStatuses'] as Map)
              : const <String, dynamic>{};
          final status = (sellerStatuses[uid] ?? 'pending').toString();

          if (myItems.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Cette commande ne contient aucun article appartenant à votre espace vendeur.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final shippingAddress = data['shippingAddress'] is Map
              ? Map<String, dynamic>.from(data['shippingAddress'] as Map)
              : const <String, dynamic>{};
          final sellerTotal = myItems.fold<int>(0, (total, item) {
            final quantity = (item['qty'] ?? item['quantity'] ?? 1) as num? ?? 1;
            final price = (item['priceCents'] ?? item['pricePerUnit'] ?? 0) as num? ?? 0;
            return total + quantity.toInt() * price.toInt();
          });

          return ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              Text(
                'Commande #${orderId.substring(0, orderId.length.clamp(0, 8)).toUpperCase()}',
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
              ),
              const SizedBox(height: 10),
              _StatusChip(status: status),
              if (shippingAddress.isNotEmpty) ...<Widget>[
                const SizedBox(height: 14),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Text('Livraison', style: TextStyle(fontWeight: FontWeight.w900)),
                        const SizedBox(height: 6),
                        Text(
                          '${shippingAddress['firstName'] ?? ''} ${shippingAddress['lastName'] ?? ''}'.trim(),
                        ),
                        Text((shippingAddress['addressLine1'] ?? '').toString()),
                        Text(
                          <String>[
                            (shippingAddress['zip'] ?? '').toString(),
                            (shippingAddress['region'] ?? '').toString(),
                            (shippingAddress['country'] ?? '').toString(),
                          ].where((value) => value.trim().isNotEmpty).join(' '),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              const Text('Mes articles', style: TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              ...myItems.map((item) {
                final title = (item['title'] ?? 'Article').toString();
                final quantity = ((item['qty'] ?? item['quantity'] ?? 1) as num? ?? 1).toInt();
                final price = ((item['priceCents'] ?? item['pricePerUnit'] ?? 0) as num? ?? 0).toInt();
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text('Quantité : $quantity'),
                  trailing: Text('${((price * quantity) / 100).toStringAsFixed(2)} €'),
                );
              }),
              const Divider(height: 30),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  const Text('Total de mon espace', style: TextStyle(fontWeight: FontWeight.w900)),
                  Text('${(sellerTotal / 100).toStringAsFixed(2)} €'),
                ],
              ),
              if (status == 'pending') ...<Widget>[
                const SizedBox(height: 20),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: saving ? null : () => onSetStatus('validated'),
                        icon: const Icon(Icons.check),
                        label: const Text('Valider mes articles'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: saving ? null : () => onSetStatus('rejected'),
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
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'validated' => Colors.green,
      'rejected' => Colors.red,
      'processing' => Colors.blueGrey,
      _ => Colors.orange,
    };
    final label = switch (status) {
      'validated' => 'Validée',
      'rejected' => 'Rejetée',
      'processing' => 'En cours',
      _ => 'En attente',
    };
    return Align(
      alignment: Alignment.centerLeft,
      child: Chip(
        label: Text(label),
        side: BorderSide(color: color.withValues(alpha: 0.4)),
        backgroundColor: color.withValues(alpha: 0.12),
      ),
    );
  }
}
