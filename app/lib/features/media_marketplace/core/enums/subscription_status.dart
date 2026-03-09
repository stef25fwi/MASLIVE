enum SubscriptionStatus {
  incomplete,
  trialing,
  active,
  pastDue,
  canceled,
  unpaid,
}

SubscriptionStatus subscriptionStatusFromString(
  String? value, {
  SubscriptionStatus fallback = SubscriptionStatus.incomplete,
}) {
  switch ((value ?? '').trim().toLowerCase()) {
    case 'incomplete':
      return SubscriptionStatus.incomplete;
    case 'trialing':
      return SubscriptionStatus.trialing;
    case 'active':
      return SubscriptionStatus.active;
    case 'past_due':
    case 'pastdue':
      return SubscriptionStatus.pastDue;
    case 'canceled':
    case 'cancelled':
      return SubscriptionStatus.canceled;
    case 'unpaid':
      return SubscriptionStatus.unpaid;
    default:
      return fallback;
  }
}

extension SubscriptionStatusX on SubscriptionStatus {
  String get firestoreValue {
    switch (this) {
      case SubscriptionStatus.pastDue:
        return 'past_due';
      default:
        return name;
    }
  }

  String get label {
    switch (this) {
      case SubscriptionStatus.incomplete:
        return 'Incomplet';
      case SubscriptionStatus.trialing:
        return 'Essai';
      case SubscriptionStatus.active:
        return 'Actif';
      case SubscriptionStatus.pastDue:
        return 'Impayes';
      case SubscriptionStatus.canceled:
        return 'Resilie';
      case SubscriptionStatus.unpaid:
        return 'Non paye';
    }
  }
}