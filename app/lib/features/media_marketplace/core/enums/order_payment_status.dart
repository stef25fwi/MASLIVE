enum OrderPaymentStatus {
  pending,
  paid,
  failed,
  refunded,
}

OrderPaymentStatus orderPaymentStatusFromString(
  String? value, {
  OrderPaymentStatus fallback = OrderPaymentStatus.pending,
}) {
  switch ((value ?? '').trim().toLowerCase()) {
    case 'pending':
      return OrderPaymentStatus.pending;
    case 'paid':
      return OrderPaymentStatus.paid;
    case 'failed':
      return OrderPaymentStatus.failed;
    case 'refunded':
      return OrderPaymentStatus.refunded;
    default:
      return fallback;
  }
}

extension OrderPaymentStatusX on OrderPaymentStatus {
  String get firestoreValue => name;

  String get label {
    switch (this) {
      case OrderPaymentStatus.pending:
        return 'En attente';
      case OrderPaymentStatus.paid:
        return 'Paye';
      case OrderPaymentStatus.failed:
        return 'Echoue';
      case OrderPaymentStatus.refunded:
        return 'Rembourse';
    }
  }
}