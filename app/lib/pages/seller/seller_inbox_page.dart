import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../security/profile_capability_policy.dart';
import '../../widgets/capability_guard.dart';

class SellerInboxPage extends StatelessWidget {
  const SellerInboxPage({super.key});

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
      message: 'Cette inbox est réservée aux vendeurs et gestionnaires autorisés.',
      child: const _SellerInboxContent(),
    );
  }
}

class _SellerInboxContent extends StatelessWidget {
  const _SellerInboxContent();

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Scaffold(body: Center(child: Text('Connexion requise')));
    }

    final inboxQuery = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('inbox')
        .orderBy('createdAt', descending: true)
        .limit(200);

    return Scaffold(
      appBar: AppBar(title: const Text('Inbox vendeur')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: inboxQuery.snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return const Center(child: Text('Aucun message vendeur'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final document = docs[index];
              final data = document.data();
              final title = (data['title'] ?? '').toString();
              final body = (data['body'] ?? '').toString();
              final orderId = (data['orderId'] ?? '').toString();
              final read = data['read'] == true;
              final timestamp = data['createdAt'];
              final createdAt = timestamp is Timestamp ? timestamp.toDate() : null;

              return InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () async {
                  try {
                    await document.reference.set(
                      <String, dynamic>{'read': true},
                      SetOptions(merge: true),
                    );
                  } catch (_) {}
                  if (orderId.isEmpty || !context.mounted) return;
                  Navigator.of(context).pushNamed(
                    '/seller-order',
                    arguments: orderId,
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.black12),
                    color: read ? Colors.white : const Color(0xFFFFF7E8),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: read ? Colors.black12 : Colors.orange,
                        ),
                        child: const Icon(
                          Icons.shopping_bag,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Row(
                              children: <Widget>[
                                Expanded(
                                  child: Text(
                                    title.isEmpty ? 'Message' : title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontWeight:
                                          read ? FontWeight.w700 : FontWeight.w900,
                                    ),
                                  ),
                                ),
                                if (createdAt != null)
                                  Text(
                                    _formatDate(createdAt),
                                    style: const TextStyle(
                                      color: Colors.black45,
                                      fontSize: 12,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              body,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.black54),
                            ),
                            if (orderId.isNotEmpty) ...<Widget>[
                              const SizedBox(height: 8),
                              Text(
                                'Commande: ${orderId.substring(0, orderId.length.clamp(0, 10)).toUpperCase()}',
                                style: const TextStyle(
                                  color: Colors.black38,
                                  fontSize: 12,
                                ),
                              ),
                            ],
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

  static String _formatDate(DateTime date) {
    final dd = date.day.toString().padLeft(2, '0');
    final mm = date.month.toString().padLeft(2, '0');
    final hh = date.hour.toString().padLeft(2, '0');
    final min = date.minute.toString().padLeft(2, '0');
    return '$dd/$mm ${hh}h$min';
  }
}
