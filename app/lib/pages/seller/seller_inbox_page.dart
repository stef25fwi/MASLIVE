import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class SellerInboxPage extends StatelessWidget {
  const SellerInboxPage({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Scaffold(
        body: Center(child: Text('Connexion requise')),
      );
    }

    final inboxQuery = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('inbox')
        .orderBy('createdAt', descending: true)
        .limit(200);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inbox vendeur'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: inboxQuery.snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snap.data!.docs;
          if (docs.isEmpty) {
            return const Center(child: Text('Aucun message'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final d = docs[i];
              final data = d.data();

              final title = (data['title'] ?? '').toString();
              final body = (data['body'] ?? '').toString();
              final orderId = (data['orderId'] ?? '').toString();
              final read = data['read'] == true;

              final ts = data['createdAt'];
              final createdAt = ts is Timestamp ? ts.toDate() : null;

              return InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () async {
                  // Mark read (best-effort)
                  try {
                    await d.reference.set(
                      {'read': true},
                      SetOptions(merge: true),
                    );
                  } catch (_) {}

                  if (orderId.isEmpty) return;
                  if (!context.mounted) return;
                  Navigator.of(context).pushNamed('/seller-order', arguments: orderId);
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
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: read ? Colors.black12 : Colors.orange,
                        ),
                        child: const Icon(Icons.shopping_bag, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    title.isEmpty ? 'Message' : title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontWeight: read ? FontWeight.w700 : FontWeight.w900,
                                    ),
                                  ),
                                ),
                                if (createdAt != null)
                                  Text(
                                    _formatDate(createdAt),
                                    style: const TextStyle(color: Colors.black45, fontSize: 12),
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
                            if (orderId.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                'Commande: ${orderId.substring(0, orderId.length.clamp(0, 10)).toUpperCase()}',
                                style: const TextStyle(color: Colors.black38, fontSize: 12),
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
