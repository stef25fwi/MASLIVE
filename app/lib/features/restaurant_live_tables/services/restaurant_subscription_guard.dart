class RestaurantSubscriptionGuard {
  const RestaurantSubscriptionGuard();

  static const Set<String> _allowedPlanCodes = <String>{
    'food_pro_live',
    'food_premium',
    'restaurant_live_plus',
  };

  bool hasActiveLiveTableFeature(Map<String, dynamic>? liveTableSubscription) {
    final raw = liveTableSubscription ?? const <String, dynamic>{};
    final status = (raw['status'] ?? '').toString().trim().toLowerCase();
    final planCode = (raw['planCode'] ?? '').toString().trim().toLowerCase();
    final isStatusActive = status == 'active' || status == 'trialing';
    return isStatusActive && _allowedPlanCodes.contains(planCode);
  }

  bool canEditLiveTable({
    required bool isFoodPoi,
    required bool isPremium,
    required bool isBusinessSubscribed,
  }) {
    if (!isFoodPoi) return false;
    return isPremium || isBusinessSubscribed;
  }
}
