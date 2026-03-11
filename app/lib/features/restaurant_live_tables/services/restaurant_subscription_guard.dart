class RestaurantSubscriptionGuard {
  const RestaurantSubscriptionGuard();

  bool canEditLiveTable({
    required bool isFoodPoi,
    required bool isPremium,
    required bool isBusinessSubscribed,
  }) {
    if (!isFoodPoi) return false;
    return isPremium || isBusinessSubscribed;
  }
}
