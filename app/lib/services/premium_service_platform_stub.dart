import 'premium_service_models.dart';
import 'premium_service_platform_interface.dart';

class UnsupportedPremiumServicePlatform implements PremiumServicePlatform {
  @override
  Future<void> configure(String revenueCatApiKey) async {
    throw UnsupportedError('RevenueCat indisponible sur cette plateforme.');
  }

  @override
  Future<PremiumOfferings> getOfferings() async {
    throw UnsupportedError('RevenueCat indisponible sur cette plateforme.');
  }

  @override
  Future<bool> hasActiveEntitlement(String entitlementId) async {
    throw UnsupportedError('RevenueCat indisponible sur cette plateforme.');
  }

  @override
  Future<void> logIn(String appUserId) async {
    throw UnsupportedError('RevenueCat indisponible sur cette plateforme.');
  }

  @override
  Future<void> logOut() async {
    throw UnsupportedError('RevenueCat indisponible sur cette plateforme.');
  }

  @override
  Future<void> purchasePackage(PremiumPackage package) async {
    throw UnsupportedError('RevenueCat indisponible sur cette plateforme.');
  }

  @override
  Future<void> restorePurchases() async {
    throw UnsupportedError('RevenueCat indisponible sur cette plateforme.');
  }
}

PremiumServicePlatform createPremiumServicePlatform() {
  return UnsupportedPremiumServicePlatform();
}