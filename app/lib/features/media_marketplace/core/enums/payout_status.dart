enum PayoutStatus {
  pending,
  available,
  paid,
}

PayoutStatus payoutStatusFromString(
  String? value, {
  PayoutStatus fallback = PayoutStatus.pending,
}) {
  switch ((value ?? '').trim().toLowerCase()) {
    case 'pending':
      return PayoutStatus.pending;
    case 'available':
      return PayoutStatus.available;
    case 'paid':
      return PayoutStatus.paid;
    default:
      return fallback;
  }
}

extension PayoutStatusX on PayoutStatus {
  String get firestoreValue => name;

  String get label {
    switch (this) {
      case PayoutStatus.pending:
        return 'En attente';
      case PayoutStatus.available:
        return 'Disponible';
      case PayoutStatus.paid:
        return 'Paye';
    }
  }
}