enum OrderDeliveryStatus {
  pending,
  ready,
  delivered,
}

OrderDeliveryStatus orderDeliveryStatusFromString(
  String? value, {
  OrderDeliveryStatus fallback = OrderDeliveryStatus.pending,
}) {
  switch ((value ?? '').trim().toLowerCase()) {
    case 'pending':
      return OrderDeliveryStatus.pending;
    case 'ready':
      return OrderDeliveryStatus.ready;
    case 'delivered':
      return OrderDeliveryStatus.delivered;
    default:
      return fallback;
  }
}

extension OrderDeliveryStatusX on OrderDeliveryStatus {
  String get firestoreValue => name;

  String get label {
    switch (this) {
      case OrderDeliveryStatus.pending:
        return 'En attente';
      case OrderDeliveryStatus.ready:
        return 'Pret';
      case OrderDeliveryStatus.delivered:
        return 'Livre';
    }
  }
}