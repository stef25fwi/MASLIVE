import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import 'dart:async';
import 'dart:convert';

import 'premium_service_models.dart';
import 'premium_service_platform_interface.dart';
import 'premium_service_platform_stub.dart'
  if (dart.library.io) 'premium_service_platform_native.dart'
  as premium_platform;

export 'premium_service_models.dart';

class PremiumService {
  PremiumService._();
  static final instance = PremiumService._();
  static const String _revenueCatPlaceholderKey =
      'REVENUECAT_PUBLIC_SDK_KEY_HERE';

  String _entitlementId = 'premium';
  bool _revenueCatConfigured = false;
  final ValueNotifier<bool> isPremium = ValueNotifier<bool>(false);
  final PremiumServicePlatform _nativePlatform =
    premium_platform.createPremiumServicePlatform();

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _webUserSub;

  static const String _subscriptionCheckoutEndpoint =
      'https://us-east1-maslive.cloudfunctions.net/createSubscriptionCheckoutSession';

  static bool isPlaceholderApiKey(String value) {
    final normalized = value.trim();
    return normalized.isEmpty || normalized == _revenueCatPlaceholderKey;
  }

  void _ensureRevenueCatAvailable() {
    if (kIsWeb) {
      throw UnsupportedError(
        'RevenueCat native SDK indisponible sur web; utiliser le flux Stripe web.',
      );
    }
    if (!_revenueCatConfigured) {
      throw StateError('RevenueCat non configuré');
    }
  }

  Future<void> init({
    required String revenueCatApiKey,
    required String entitlementId,
  }) async {
    _entitlementId = entitlementId;

    if (kIsWeb) {
      // Web: premium via Firestore (users/{uid}.premium.status) driven by Stripe webhooks
      FirebaseAuth.instance.authStateChanges().listen((u) {
        _webUserSub?.cancel();
        _webUserSub = null;

        if (u == null) {
          isPremium.value = false;
          return;
        }

        _webUserSub = FirebaseFirestore.instance
            .collection('users')
            .doc(u.uid)
            .snapshots()
            .listen((snap) {
          final data = snap.data();
          final premium = data?['premium'];
          final status = premium is Map ? premium['status'] : null;
          isPremium.value = status == 'active';
        });
      });

      // Trigger initial state
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        isPremium.value = false;
      }
      return;
    }

    if (isPlaceholderApiKey(revenueCatApiKey)) {
      isPremium.value = false;
      if (kReleaseMode) {
        throw StateError('RC_API_KEY manquant ou placeholder en build release');
      }
      debugPrint('⚠️ PremiumService: RC_API_KEY manquant, RevenueCat désactivé');
      return;
    }

    await _nativePlatform.configure(revenueCatApiKey);
    _revenueCatConfigured = true;

    // Sync user RevenueCat avec Firebase (si déjà loggué)
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await logIn(user.uid);
    } else {
      await refresh();
    }

    // Écoute changements d’état
    FirebaseAuth.instance.authStateChanges().listen((u) async {
      if (u == null) {
        if (_revenueCatConfigured) {
          await _nativePlatform.logOut();
        }
        isPremium.value = false;
      } else {
        await logIn(u.uid);
      }
    });
  }

  Future<void> logIn(String appUserId) async {
    _ensureRevenueCatAvailable();
    await _nativePlatform.logIn(appUserId);
    await refresh();
  }

  Future<void> refresh() async {
    _ensureRevenueCatAvailable();
    final active = await _nativePlatform.hasActiveEntitlement(_entitlementId);
    isPremium.value = active;
  }

  Future<PremiumOfferings> getOfferings() {
    _ensureRevenueCatAvailable();
    return _nativePlatform.getOfferings();
  }

  Future<void> purchasePackage(PremiumPackage package) async {
    _ensureRevenueCatAvailable();
    await _nativePlatform.purchasePackage(package);
    await refresh();
  }

  Future<void> restorePurchases() async {
    if (kIsWeb) return;
    _ensureRevenueCatAvailable();
    await _nativePlatform.restorePurchases();
    await refresh();
  }

  Future<void> startStripeSubscriptionCheckout({
    required String priceId,
    required Uri successUrl,
    required Uri cancelUrl,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw StateError('Not signed in');

    final token = await user.getIdToken();
    final response = await http
        .post(
          Uri.parse(_subscriptionCheckoutEndpoint),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({
            'priceId': priceId,
            'successUrl': successUrl.toString(),
            'cancelUrl': cancelUrl.toString(),
          }),
        )
        .timeout(const Duration(seconds: 25));

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(body['error']?.toString() ?? 'Checkout failed');
    }

    final url = body['url']?.toString();
    if (url == null || url.isEmpty) throw StateError('Missing checkout url');

    final ok = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.platformDefault,
    );
    if (!ok) throw StateError('Cannot open checkout url');
  }

  Future<bool> openCheckoutUrl(String url) async {
    final value = url.trim();
    if (value.isEmpty) return false;
    return launchUrl(
      Uri.parse(value),
      mode: LaunchMode.platformDefault,
    );
  }
}
