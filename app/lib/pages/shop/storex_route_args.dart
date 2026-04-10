/// Constantes de routes et classes d'arguments pour le module Storex.
/// Fichier léger importé dans main.dart (pas de dépendance lourde).
class StorexRoutes {
  static const paymentComplete = '/storex/paymentComplete';
  static const reviews = '/storex/reviews';
  static const addReview = '/storex/addReview';
  static const orderTracker = '/storex/orderTracker';
}

class PaymentCompleteArgs {
  final String orderCode;
  final String? continueToRoute;
  const PaymentCompleteArgs({required this.orderCode, this.continueToRoute});
}

class ReviewsArgs {
  final String productId;
  final String productTitle;
  const ReviewsArgs({required this.productId, required this.productTitle});
}

class AddReviewArgs {
  final String productId;
  final String productTitle;
  const AddReviewArgs({required this.productId, required this.productTitle});
}

class OrderTrackerArgs {
  final String orderId;
  const OrderTrackerArgs({required this.orderId});
}
