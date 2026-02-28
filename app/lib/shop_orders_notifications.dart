import 'dart:io';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'ui/snack/top_snack_bar.dart';

/// ==========================
/// 1) BACKGROUND HANDLER
/// ==========================
/// IMPORTANT: doit être une fonction top-level.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Ici on évite de dépendre d'autres singletons.
  // L'objectif est surtout que le push soit géré correctement en arrière-plan.
  // (Sur iOS, les data-only peuvent être limités, mais notification+data marche bien.)
}

/// ==========================
/// 2) PUSH SERVICE
/// ==========================
class PushService {
  PushService._();
  static final PushService instance = PushService._();

  final _messaging = FirebaseMessaging.instance;
  final _db = FirebaseFirestore.instance;

  bool _initialized = false;

  Future<void> init(BuildContext context) async {
    if (_initialized) return;
    _initialized = true;

    // Handler arrière-plan
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // Foreground message (on évite d'utiliser un BuildContext potentiellement démonté)
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (!context.mounted) return;

      // En foreground, tu peux afficher un SnackBar / Dialog / LocalNotification.
      final data = message.data;
      if (data['type'] == 'order') {
        final orderId = data['orderId'];
        TopSnackBar.show(
          context,
          SnackBar(
            content: const Text('Nouvelle commande à valider'),
            action: SnackBarAction(
              label: 'Ouvrir',
              onPressed: () {
                if (!context.mounted) return;
                if (orderId != null) {
                  Navigator.of(context)
                      .pushNamed('/seller-order', arguments: orderId);
                }
              },
            ),
          ),
        );
      }
    });

    // iOS permission
    await _messaging.requestPermission(
      alert: true,
      sound: true,
      badge: true,
      provisional: false,
    );

    // Token sync au login
    await syncTokenForCurrentUser();
  }

  Future<void> syncTokenForCurrentUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final token = await _messaging.getToken();
    if (token == null) return;

    // deviceId simple (tu peux remplacer par device_info_plus pour vrai ID)
    final deviceId = _simpleDeviceId();

    await _db
        .collection('users')
        .doc(user.uid)
        .collection('devices')
        .doc(deviceId)
        .set({
      'token': token,
      'platform': Platform.isIOS
          ? 'ios'
          : (Platform.isAndroid ? 'android' : 'other'),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // Si token refresh
    _messaging.onTokenRefresh.listen((newToken) async {
      await _db
          .collection('users')
          .doc(user.uid)
          .collection('devices')
          .doc(deviceId)
          .set({
        'token': newToken,
        'platform': Platform.isIOS
            ? 'ios'
            : (Platform.isAndroid ? 'android' : 'other'),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  String _simpleDeviceId() {
    // Minimaliste : unique par installation (pas parfait).
    // Recommandé: device_info_plus + shared_preferences pour persister un UUID.
    return 'device_${Platform.operatingSystem}';
  }
}

/// ==========================
/// 4) MODELS
/// ==========================
class InboxMessage {
  final String id;
  final String type;
  final String title;
  final String body;
  final String orderId;
  final bool read;
  final Timestamp? createdAt;

  InboxMessage({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.orderId,
    required this.read,
    required this.createdAt,
  });

  factory InboxMessage.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return InboxMessage(
      id: doc.id,
      type: (d['type'] ?? '') as String,
      title: (d['title'] ?? '') as String,
      body: (d['body'] ?? '') as String,
      orderId: (d['orderId'] ?? '') as String,
      read: (d['read'] ?? false) as bool,
      createdAt: d['createdAt'] as Timestamp?,
    );
  }
}

class OrderModel {
  final String id;
  final String buyerId;
  final String status;
  final List<Map<String, dynamic>> items;
  final List<String> sellerIds;

  OrderModel({
    required this.id,
    required this.buyerId,
    required this.status,
    required this.items,
    required this.sellerIds,
  });

  factory OrderModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    final rawItems = (d['items'] as List?) ?? [];
    final items = rawItems
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    final sellers =
        ((d['sellerIds'] as List?) ?? []).map((e) => e.toString()).toList();
    return OrderModel(
      id: doc.id,
      buyerId: (d['buyerId'] ?? '') as String,
      status: (d['status'] ?? 'pending') as String,
      items: items,
      sellerIds: sellers,
    );
  }
}

/// ==========================
/// 5) INBOX PAGE (vendeur)
/// ==========================
class InboxPage extends StatelessWidget {
  const InboxPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Connecte-toi pour voir tes messages.')),
      );
    }

    final inboxQuery = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('inbox')
        .orderBy('createdAt', descending: true)
        .limit(50);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Boîte à messages'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: inboxQuery.snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text('Erreur: ${snap.error}'));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snap.data!.docs;
          if (docs.isEmpty) {
            return const Center(child: Text('Aucun message.'));
          }

          final messages = docs.map((d) => InboxMessage.fromDoc(d)).toList();

          return ListView.separated(
            itemCount: messages.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final m = messages[i];
              return ListTile(
                leading:
                    Icon(m.type == 'order' ? Icons.shopping_bag : Icons.message),
                title: Text(
                  m.title,
                  style: TextStyle(
                    fontWeight:
                        m.read ? FontWeight.normal : FontWeight.bold,
                  ),
                ),
                subtitle: Text(m.body),
                trailing: m.read ? null : const Icon(Icons.circle, size: 10),
                onTap: () async {
                  final nav = Navigator.of(context);

                  // Marquer comme lu
                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(user.uid)
                      .collection('inbox')
                      .doc(m.id)
                      .update({'read': true});

                  if (m.type == 'order' && m.orderId.isNotEmpty) {
                    nav.pushNamed('/seller-order', arguments: m.orderId);
                  }
                },
              );
            },
          );
        },
      ),
    );
  }
}

/// ==========================
/// 6) ORDER DETAILS (vendeur)
/// ==========================
class OrderDetailsPage extends StatelessWidget {
  final String orderId;
  const OrderDetailsPage({super.key, required this.orderId});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text('Détails commande')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('orders')
            .doc(orderId)
            .snapshots(),
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Text('Erreur: ${snap.error}'));
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          if (!snap.data!.exists) {
            return const Center(child: Text('Commande introuvable'));
          }

          final order = OrderModel.fromDoc(snap.data!);

          // Vérifie que l'utilisateur est vendeur (sinon affiche message)
          final isSeller = user != null && order.sellerIds.contains(user.uid);

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Statut: ${order.status}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text('Acheteur: ${order.buyerId}'),
                const SizedBox(height: 16),
                const Text(
                  'Articles',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.separated(
                    itemCount: order.items.length,
                    separatorBuilder: (context, index) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final it = order.items[i];

                      final title = (it['title'] ?? it['productId']).toString();

                      final qtyRaw = it['qty'] ?? it['quantity'] ?? 1;
                      final qty = (qtyRaw is num)
                          ? qtyRaw.toInt()
                          : int.tryParse(qtyRaw.toString()) ?? 1;

                      final priceRaw =
                          it['priceCents'] ?? it['pricePerUnit'] ?? it['price'] ?? 0;
                      final priceCents = (priceRaw is num)
                          ? priceRaw.toInt()
                          : int.tryParse(priceRaw.toString()) ?? 0;

                      return ListTile(
                        title: Text(title),
                        subtitle: Text('qty: $qty — $priceCents cts'),
                        trailing: Text('seller: ${it['sellerId'] ?? ''}'),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                if (!isSeller)
                  const Text(
                    "Tu n'es pas autorisé à valider cette commande.",
                    style: TextStyle(color: Colors.red),
                  ),
                if (isSeller) _OrderActions(orderId: orderId, currentStatus: order.status),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _OrderActions extends StatelessWidget {
  final String orderId;
  final String currentStatus;
  const _OrderActions({required this.orderId, required this.currentStatus});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    final canAct = currentStatus == 'pending' && user != null;

    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: !canAct
                ? null
                : () async {
                    final uid = FirebaseAuth.instance.currentUser?.uid;
                    if (uid == null) return;

                    await FirebaseFirestore.instance
                        .collection('orders')
                        .doc(orderId)
                        .update({
                      'status': 'validated',
                      'validatedAt': FieldValue.serverTimestamp(),
                      'validatedBy': uid,
                    });
                    if (!context.mounted) return;
                    TopSnackBar.show(
                      context,
                      const SnackBar(content: Text('Commande validée')),
                    );
                  },
            icon: const Icon(Icons.check),
            label: const Text('Valider'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: !canAct
                ? null
                : () async {
                    final uid = FirebaseAuth.instance.currentUser?.uid;
                    if (uid == null) return;

                    await FirebaseFirestore.instance
                        .collection('orders')
                        .doc(orderId)
                        .update({
                      'status': 'rejected',
                      'rejectedAt': FieldValue.serverTimestamp(),
                      'rejectedBy': uid,
                    });
                    if (!context.mounted) return;
                    TopSnackBar.show(
                      context,
                      const SnackBar(content: Text('Commande refusée')),
                    );
                  },
            icon: const Icon(Icons.close),
            label: const Text('Refuser'),
          ),
        ),
      ],
    );
  }
}

/// ==========================
/// 7) GO_ROUTER SNIPPET
/// ==========================
/// Option B (la plus fiable ici): tu gardes GetMaterialApp(routes: ...)
/// et tu relies ces pages via des routes nommées.
///
/// Exemples à ajouter dans `routes:` (voir `main.dart`) :
///
/// '/seller-inbox': (_) => const InboxPage(),
/// '/seller-order': (ctx) {
///   final args = ModalRoute.of(ctx)?.settings.arguments;
///   final orderId = args is String ? args : null;
///   if (orderId == null || orderId.trim().isEmpty) return const SizedBox.shrink();
///   return OrderDetailsPage(orderId: orderId);
/// },
