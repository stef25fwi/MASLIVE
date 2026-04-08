import 'package:purchases_flutter/purchases_flutter.dart';

import 'premium_service_models.dart';
import 'premium_service_platform_interface.dart';

class NativePremiumServicePlatform implements PremiumServicePlatform {
  @override
  Future<void> configure(String revenueCatApiKey) async {
    await Purchases.setLogLevel(LogLevel.info);
    await Purchases.configure(PurchasesConfiguration(revenueCatApiKey));
  }

  @override
  Future<PremiumOfferings> getOfferings() async {
    final offerings = await Purchases.getOfferings();
    final packages = offerings.current?.availablePackages ?? const <Package>[];

    return PremiumOfferings(
      availablePackages: packages
          .map(
            (package) => PremiumPackage(
              id: package.storeProduct.identifier,
              title: package.storeProduct.title,
              description: package.storeProduct.description,
              priceString: package.storeProduct.priceString,
              platformPackage: package,
            ),
          )
          .toList(growable: false),
    );
  }

  @override
  Future<bool> hasActiveEntitlement(String entitlementId) async {
    final info = await Purchases.getCustomerInfo();
    return info.entitlements.active[entitlementId] != null;
  }

  @override
  Future<void> logIn(String appUserId) async {
    await Purchases.logIn(appUserId);
  }

  @override
  Future<void> logOut() async {
    await Purchases.logOut();
  }

  @override
  Future<void> purchasePackage(PremiumPackage package) async {
    final nativePackage = package.platformPackage;
    if (nativePackage is! Package) {
      throw StateError('Package RevenueCat native manquant.');
    }
    await Purchases.purchase(PurchaseParams.package(nativePackage));
  }

  @override
  Future<void> restorePurchases() async {
    await Purchases.restorePurchases();
  }
}

PremiumServicePlatform createPremiumServicePlatform() {
  return NativePremiumServicePlatform();
}