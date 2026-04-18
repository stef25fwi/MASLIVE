import 'package:cloud_firestore/cloud_firestore.dart';

class BloomArtOrder {
  const BloomArtOrder({
    required this.id,
    required this.itemId,
    required this.offerId,
    required this.sellerId,
    required this.buyerId,
    required this.finalPrice,
    required this.currency,
    required this.checkoutSource,
    required this.paymentStatus,
    required this.orderStatus,
    this.stripeCheckoutSessionId,
    this.stripePaymentIntentId,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String itemId;
  final String offerId;
  final String sellerId;
  final String buyerId;
  final double finalPrice;
  final String currency;
  final String checkoutSource;
  final String? stripeCheckoutSessionId;
  final String? stripePaymentIntentId;
  final String paymentStatus;
  final String orderStatus;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'itemId': itemId,
      'offerId': offerId,
      'sellerId': sellerId,
      'buyerId': buyerId,
      'finalPrice': finalPrice,
      'currency': currency,
      'checkoutSource': checkoutSource,
      'stripeCheckoutSessionId': stripeCheckoutSessionId,
      'stripePaymentIntentId': stripePaymentIntentId,
      'paymentStatus': paymentStatus,
      'orderStatus': orderStatus,
      if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
      if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
    };
  }

  factory BloomArtOrder.fromMap(String id, Map<String, dynamic> map) {
    return BloomArtOrder(
      id: id,
      itemId: (map['itemId'] ?? '').toString(),
      offerId: (map['offerId'] ?? '').toString(),
      sellerId: (map['sellerId'] ?? '').toString(),
      buyerId: (map['buyerId'] ?? '').toString(),
      finalPrice: double.tryParse((map['finalPrice'] ?? 0).toString()) ?? 0,
      currency: (map['currency'] ?? 'EUR').toString(),
      checkoutSource: (map['checkoutSource'] ?? 'bloom_art').toString(),
      stripeCheckoutSessionId: map['stripeCheckoutSessionId']?.toString(),
      stripePaymentIntentId: map['stripePaymentIntentId']?.toString(),
      paymentStatus: (map['paymentStatus'] ?? 'pending').toString(),
      orderStatus: (map['orderStatus'] ?? 'draft').toString(),
      createdAt: _toDate(map['createdAt']),
      updatedAt: _toDate(map['updatedAt']),
    );
  }

  factory BloomArtOrder.fromDocument(DocumentSnapshot<Map<String, dynamic>> doc) {
    return BloomArtOrder.fromMap(doc.id, doc.data() ?? <String, dynamic>{});
  }

  static DateTime? _toDate(Object? raw) {
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    return null;
  }
}