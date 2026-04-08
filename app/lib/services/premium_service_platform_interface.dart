import 'premium_service_models.dart';

abstract class PremiumServicePlatform {
  Future<void> configure(String revenueCatApiKey);

  Future<void> logIn(String appUserId);

  Future<void> logOut();

  Future<bool> hasActiveEntitlement(String entitlementId);

  Future<PremiumOfferings> getOfferings();

  Future<void> purchasePackage(PremiumPackage package);

  Future<void> restorePurchases();
}