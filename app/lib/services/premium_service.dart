import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

class PremiumService {
  PremiumService._();
  static final instance = PremiumService._();

  String _entitlementId = 'premium';
  final ValueNotifier<bool> isPremium = ValueNotifier<bool>(false);

  Future<void> init({
    required String revenueCatApiKey,
    required String entitlementId,
  }) async {
    _entitlementId = entitlementId;

    if (kIsWeb) {
      isPremium.value = false;
      return;
    }

    await Purchases.setLogLevel(LogLevel.info);
    await Purchases.configure(PurchasesConfiguration(revenueCatApiKey));

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
        await Purchases.logOut();
        isPremium.value = false;
      } else {
        await logIn(u.uid);
      }
    });
  }

  Future<void> logIn(String appUserId) async {
    if (kIsWeb) return;
    await Purchases.logIn(appUserId);
    await refresh();
  }

  Future<void> refresh() async {
    if (kIsWeb) return;
    final info = await Purchases.getCustomerInfo();
    final active = info.entitlements.active[_entitlementId] != null;
    isPremium.value = active;
  }

  Future<Offerings> getOfferings() => Purchases.getOfferings();

  Future<void> purchasePackage(Package package) async {
    if (kIsWeb) return;
    await Purchases.purchasePackage(package);
    await refresh();
  }

  Future<void> restorePurchases() async {
    if (kIsWeb) return;
    await Purchases.restorePurchases();
    await refresh();
  }
}
