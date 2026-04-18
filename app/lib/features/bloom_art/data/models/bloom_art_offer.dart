import 'package:cloud_firestore/cloud_firestore.dart';

class BloomArtOffer {
  const BloomArtOffer({
    required this.id,
    required this.itemId,
    required this.buyerId,
    required this.sellerId,
    required this.proposedPrice,
    required this.buyerMessage,
    required this.referencePriceSnapshot,
    required this.autoAcceptThresholdPercent,
    required this.autoAccepted,
    required this.status,
    required this.checkoutEligible,
    this.createdAt,
    this.respondedAt,
    this.acceptedAt,
    this.declinedAt,
    this.paidAt,
  });

  final String id;
  final String itemId;
  final String buyerId;
  final String sellerId;
  final double proposedPrice;
  final String buyerMessage;
  final double referencePriceSnapshot;
  final double autoAcceptThresholdPercent;
  final bool autoAccepted;
  final String status;
  final bool checkoutEligible;
  final DateTime? createdAt;
  final DateTime? respondedAt;
  final DateTime? acceptedAt;
  final DateTime? declinedAt;
  final DateTime? paidAt;

  bool get isPending => status == 'pending';
  bool get isAccepted => status == 'accepted' || status == 'auto_accepted';
  bool get isCheckoutStarted => status == 'checkout_started';
  bool get isPaid => status == 'paid';

  BloomArtOffer copyWith({
    String? id,
    String? itemId,
    String? buyerId,
    String? sellerId,
    double? proposedPrice,
    String? buyerMessage,
    double? referencePriceSnapshot,
    double? autoAcceptThresholdPercent,
    bool? autoAccepted,
    String? status,
    bool? checkoutEligible,
    DateTime? createdAt,
    DateTime? respondedAt,
    DateTime? acceptedAt,
    DateTime? declinedAt,
    DateTime? paidAt,
  }) {
    return BloomArtOffer(
      id: id ?? this.id,
      itemId: itemId ?? this.itemId,
      buyerId: buyerId ?? this.buyerId,
      sellerId: sellerId ?? this.sellerId,
      proposedPrice: proposedPrice ?? this.proposedPrice,
      buyerMessage: buyerMessage ?? this.buyerMessage,
      referencePriceSnapshot: referencePriceSnapshot ?? this.referencePriceSnapshot,
      autoAcceptThresholdPercent: autoAcceptThresholdPercent ?? this.autoAcceptThresholdPercent,
      autoAccepted: autoAccepted ?? this.autoAccepted,
      status: status ?? this.status,
      checkoutEligible: checkoutEligible ?? this.checkoutEligible,
      createdAt: createdAt ?? this.createdAt,
      respondedAt: respondedAt ?? this.respondedAt,
      acceptedAt: acceptedAt ?? this.acceptedAt,
      declinedAt: declinedAt ?? this.declinedAt,
      paidAt: paidAt ?? this.paidAt,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'itemId': itemId,
      'buyerId': buyerId,
      'sellerId': sellerId,
      'proposedPrice': proposedPrice,
      'buyerMessage': buyerMessage,
      'referencePriceSnapshot': referencePriceSnapshot,
      'autoAcceptThresholdPercent': autoAcceptThresholdPercent,
      'autoAccepted': autoAccepted,
      'status': status,
      'checkoutEligible': checkoutEligible,
      if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
      if (respondedAt != null) 'respondedAt': Timestamp.fromDate(respondedAt!),
      if (acceptedAt != null) 'acceptedAt': Timestamp.fromDate(acceptedAt!),
      if (declinedAt != null) 'declinedAt': Timestamp.fromDate(declinedAt!),
      if (paidAt != null) 'paidAt': Timestamp.fromDate(paidAt!),
    };
  }

  factory BloomArtOffer.fromMap(String id, Map<String, dynamic> map) {
    return BloomArtOffer(
      id: id,
      itemId: (map['itemId'] ?? '').toString(),
      buyerId: (map['buyerId'] ?? '').toString(),
      sellerId: (map['sellerId'] ?? '').toString(),
      proposedPrice: _toDouble(map['proposedPrice']),
      buyerMessage: (map['buyerMessage'] ?? '').toString(),
      referencePriceSnapshot: _toDouble(map['referencePriceSnapshot']),
      autoAcceptThresholdPercent: _toDouble(map['autoAcceptThresholdPercent'], fallback: 0.9),
      autoAccepted: map['autoAccepted'] == true,
      status: (map['status'] ?? 'pending').toString(),
      checkoutEligible: map['checkoutEligible'] == true,
      createdAt: _toDate(map['createdAt']),
      respondedAt: _toDate(map['respondedAt']),
      acceptedAt: _toDate(map['acceptedAt']),
      declinedAt: _toDate(map['declinedAt']),
      paidAt: _toDate(map['paidAt']),
    );
  }

  factory BloomArtOffer.fromDocument(DocumentSnapshot<Map<String, dynamic>> doc) {
    return BloomArtOffer.fromMap(doc.id, doc.data() ?? <String, dynamic>{});
  }

  static DateTime? _toDate(Object? raw) {
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    return null;
  }

  static double _toDouble(Object? raw, {double fallback = 0}) {
    final parsed = double.tryParse(raw?.toString() ?? '');
    return parsed ?? fallback;
  }
}