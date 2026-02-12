import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;
import 'package:flutter/widgets.dart';

class NotificationsService {
  NotificationsService._();

  static final NotificationsService instance = NotificationsService._();

  bool _started = false;
  StreamSubscription<User?>? _authSub;
  StreamSubscription<String>? _tokenRefreshSub;
  StreamSubscription<RemoteMessage>? _openedSub;
  GlobalKey<NavigatorState>? _navigatorKey;

  void start({GlobalKey<NavigatorState>? navigatorKey}) {
    if (_started) return;
    _started = true;

    _navigatorKey = navigatorKey;

    _openedSub = FirebaseMessaging.onMessageOpenedApp.listen(_handleMessage);
    // Si l'app est lancée depuis une notification
    FirebaseMessaging.instance.getInitialMessage().then((m) {
      if (m != null) _handleMessage(m);
    });

    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) async {
      await _tokenRefreshSub?.cancel();
      _tokenRefreshSub = null;

      if (user == null) return;

      await _requestPermissionIfNeeded();
      await _syncCurrentToken(user.uid);

      _tokenRefreshSub = FirebaseMessaging.instance.onTokenRefresh.listen(
        (token) => _saveTokenForUser(user.uid, token),
      );
    });
  }

  Future<void> dispose() async {
    await _tokenRefreshSub?.cancel();
    await _authSub?.cancel();
    await _openedSub?.cancel();
  }

  Future<void> _requestPermissionIfNeeded() async {
    // iOS/macOS: obligatoire pour recevoir des notifications.
    // Android: selon la version/targetSdk, peut être no-op ou requis (API 33+).
    // On appelle de manière safe.
    try {
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
    } catch (_) {}
  }

  Future<void> _syncCurrentToken(String uid) async {
    final token = await FirebaseMessaging.instance.getToken();
    if (token == null || token.isEmpty) return;
    await _saveTokenForUser(uid, token);
  }

  Future<void> _saveTokenForUser(String uid, String token) async {
    final safeDocId = token.replaceAll('/', '_');
    final platform = kIsWeb
        ? 'web'
        : (defaultTargetPlatform == TargetPlatform.iOS
            ? 'ios'
            : (defaultTargetPlatform == TargetPlatform.android ? 'android' : 'unknown'));

    // 1) Nouveau stockage: users/{uid}/devices/{deviceId}
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('devices')
        .doc(safeDocId)
        .set(
      {
        'token': token,
        'platform': platform,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    // 2) Back-compat: tableau users/{uid}.fcmTokens (utilisé par d'autres notifs)
    await FirebaseFirestore.instance.collection('users').doc(uid).set(
      {
        'fcmTokens': FieldValue.arrayUnion([token]),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  void _handleMessage(RemoteMessage message) {
    final type = (message.data['type'] ?? '').toString();
    final nav = _navigatorKey?.currentState;
    if (nav == null) return;

    if (type == 'pending_product') {
      // On ouvre la liste de modération (l'accès reste protégé côté UI).
      nav.pushNamed('/pending-products');
      return;
    }

    if (type == 'order') {
      String orderId = (message.data['orderId'] ?? '').toString();
      final deepLink = (message.data['deepLink'] ?? '').toString();
      if (orderId.isEmpty && deepLink.startsWith('maslive://orders/')) {
        orderId = deepLink.split('/').last;
      }
      if (orderId.isEmpty) return;
      nav.pushNamed('/seller-order', arguments: orderId);
      return;
    }
  }
}
