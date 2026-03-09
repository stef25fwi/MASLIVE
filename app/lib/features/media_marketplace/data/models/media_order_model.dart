import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../core/enums/media_asset_type.dart';
import '../../core/enums/order_delivery_status.dart';
import '../../core/enums/order_payment_status.dart';
import '../mappers/timestamp_mapper.dart';

double _orderDouble(dynamic value, {double fallback = 0}) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return fallback;
}

int _orderInt(dynamic value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return fallback;
}

List<String> _orderStringList(dynamic value) {
  if (value is! Iterable) return const <String>[];
  return value.map((item) => item.toString()).toList(growable: false);
}

Map<String, dynamic> _orderMap(dynamic value) {
  if (value is! Map) return const <String, dynamic>{};
  return Map<String, dynamic>.from(value);
}

/// Ligne figée d'une commande média.
class MediaOrderLineItemModel {
  final String assetId;
  final MediaAssetType assetType;
  final String photographerId;
  final String? galleryId;
  final String? eventId;
  final String title;
  final String? thumbnailUrl;
  final int quantity;
  final double unitPrice;
  final double lineSubtotal;
  final String currency;
  final List<String> photoIds;
  final Map<String, dynamic> pricingSnapshot;

  const MediaOrderLineItemModel({
    required this.assetId,
    required this.assetType,
    required this.photographerId,
    this.galleryId,
    this.eventId,
    required this.title,
    this.thumbnailUrl,
    this.quantity = 1,
    this.unitPrice = 0,
    this.lineSubtotal = 0,
    this.currency = 'EUR',
    this.photoIds = const <String>[],
    this.pricingSnapshot = const <String, dynamic>{},
  });

  factory MediaOrderLineItemModel.fromMap(Map<String, dynamic> map) {
    return MediaOrderLineItemModel(
      assetId: map['assetId']?.toString() ?? '',
      assetType: mediaAssetTypeFromString(map['assetType']?.toString()),
      photographerId: map['photographerId']?.toString() ?? '',
      galleryId: map['galleryId']?.toString(),
      eventId: map['eventId']?.toString(),
      title: map['title']?.toString() ?? '',
      thumbnailUrl: map['thumbnailUrl']?.toString(),
      quantity: _orderInt(map['quantity'], fallback: 1),
      unitPrice: _orderDouble(map['unitPrice']),
      lineSubtotal: _orderDouble(map['lineSubtotal']),
      currency: map['currency']?.toString() ?? 'EUR',
      photoIds: _orderStringList(map['photoIds']),
      pricingSnapshot: _orderMap(map['pricingSnapshot']),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'assetId': assetId,
      'assetType': assetType.firestoreValue,
      'photographerId': photographerId,
      if (galleryId != null) 'galleryId': galleryId,
      if (eventId != null) 'eventId': eventId,
      'title': title,
      if (thumbnailUrl != null) 'thumbnailUrl': thumbnailUrl,
      'quantity': quantity,
      'unitPrice': unitPrice,
      'lineSubtotal': lineSubtotal,
      'currency': currency,
      'photoIds': photoIds,
      'pricingSnapshot': pricingSnapshot,
    };
  }

  MediaOrderLineItemModel copyWith({
    String? assetId,
    MediaAssetType? assetType,
    String? photographerId,
    String? galleryId,
    String? eventId,
    String? title,
    String? thumbnailUrl,
    int? quantity,
    double? unitPrice,
    double? lineSubtotal,
    String? currency,
    List<String>? photoIds,
    Map<String, dynamic>? pricingSnapshot,
  }) {
    return MediaOrderLineItemModel(
      assetId: assetId ?? this.assetId,
      assetType: assetType ?? this.assetType,
      photographerId: photographerId ?? this.photographerId,
      galleryId: galleryId ?? this.galleryId,
      eventId: eventId ?? this.eventId,
      title: title ?? this.title,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      lineSubtotal: lineSubtotal ?? this.lineSubtotal,
      currency: currency ?? this.currency,
      photoIds: photoIds ?? this.photoIds,
      pricingSnapshot: pricingSnapshot ?? this.pricingSnapshot,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MediaOrderLineItemModel &&
        other.assetId == assetId &&
        other.assetType == assetType &&
        other.photographerId == photographerId &&
        other.galleryId == galleryId &&
        other.eventId == eventId &&
        other.title == title &&
        other.thumbnailUrl == thumbnailUrl &&
        other.quantity == quantity &&
        other.unitPrice == unitPrice &&
        other.lineSubtotal == lineSubtotal &&
        other.currency == currency &&
        listEquals(other.photoIds, photoIds) &&
        mapEquals(other.pricingSnapshot, pricingSnapshot);
  }

  @override
  int get hashCode => Object.hash(
        assetId,
        assetType,
        photographerId,
        galleryId,
        eventId,
        title,
        thumbnailUrl,
        quantity,
        unitPrice,
        lineSubtotal,
        currency,
        Object.hashAll(photoIds),
        Object.hashAll(pricingSnapshot.entries),
      );
}

/// Commande média issue d'un checkout Stripe finalisé.
class MediaOrderModel {
  final String orderId;
  final String buyerUid;
  final List<String> photographerIds;
  final List<MediaOrderLineItemModel> items;
  final String currency;
  final double subtotal;
  final double stripeFee;
  final double platformFee;
  final double taxAmount;
  final double total;
  final double photographerNetTotal;
  final OrderPaymentStatus paymentStatus;
  final OrderDeliveryStatus deliveryStatus;
  final String? stripeCheckoutSessionId;
  final String? stripePaymentIntentId;
  final String? stripeCustomerId;
  final Map<String, dynamic> pricingBreakdown;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? paidAt;
  final DateTime? deliveredAt;

  const MediaOrderModel({
    required this.orderId,
    required this.buyerUid,
    this.photographerIds = const <String>[],
    this.items = const <MediaOrderLineItemModel>[],
    this.currency = 'EUR',
    this.subtotal = 0,
    this.stripeFee = 0,
    this.platformFee = 0,
    this.taxAmount = 0,
    this.total = 0,
    this.photographerNetTotal = 0,
    this.paymentStatus = OrderPaymentStatus.pending,
    this.deliveryStatus = OrderDeliveryStatus.pending,
    this.stripeCheckoutSessionId,
    this.stripePaymentIntentId,
    this.stripeCustomerId,
    this.pricingBreakdown = const <String, dynamic>{},
    this.metadata = const <String, dynamic>{},
    required this.createdAt,
    required this.updatedAt,
    this.paidAt,
    this.deliveredAt,
  });

  factory MediaOrderModel.fromMap(Map<String, dynamic> map, {String? orderId}) {
    final rawItems = map['items'];
    final items = rawItems is Iterable
        ? rawItems
            .whereType<Map>()
            .map((item) => MediaOrderLineItemModel.fromMap(Map<String, dynamic>.from(item)))
            .toList(growable: false)
        : const <MediaOrderLineItemModel>[];

    return MediaOrderModel(
      orderId: orderId ?? (map['orderId']?.toString() ?? ''),
      buyerUid: map['buyerUid']?.toString() ?? '',
      photographerIds: _orderStringList(map['photographerIds']),
      items: items,
      currency: map['currency']?.toString() ?? 'EUR',
      subtotal: _orderDouble(map['subtotal']),
      stripeFee: _orderDouble(map['stripeFee']),
      platformFee: _orderDouble(map['platformFee']),
      taxAmount: _orderDouble(map['taxAmount']),
      total: _orderDouble(map['total']),
      photographerNetTotal: _orderDouble(map['photographerNetTotal']),
      paymentStatus: orderPaymentStatusFromString(map['paymentStatus']?.toString()),
      deliveryStatus: orderDeliveryStatusFromString(map['deliveryStatus']?.toString()),
      stripeCheckoutSessionId: map['stripeCheckoutSessionId']?.toString(),
      stripePaymentIntentId: map['stripePaymentIntentId']?.toString(),
      stripeCustomerId: map['stripeCustomerId']?.toString(),
      pricingBreakdown: _orderMap(map['pricingBreakdown']),
      metadata: _orderMap(map['metadata']),
      createdAt: TimestampMapper.fromFirestoreOrNow(map['createdAt']),
      updatedAt: TimestampMapper.fromFirestoreOrNow(map['updatedAt']),
      paidAt: TimestampMapper.fromFirestore(map['paidAt']),
      deliveredAt: TimestampMapper.fromFirestore(map['deliveredAt']),
    );
  }

  factory MediaOrderModel.fromDocument(DocumentSnapshot<Map<String, dynamic>> doc) {
    return MediaOrderModel.fromMap(doc.data() ?? const <String, dynamic>{}, orderId: doc.id);
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'orderId': orderId,
      'buyerUid': buyerUid,
      'photographerIds': photographerIds,
      'items': items.map((item) => item.toMap()).toList(growable: false),
      'currency': currency,
      'subtotal': subtotal,
      'stripeFee': stripeFee,
      'platformFee': platformFee,
      'taxAmount': taxAmount,
      'total': total,
      'photographerNetTotal': photographerNetTotal,
      'paymentStatus': paymentStatus.firestoreValue,
      'deliveryStatus': deliveryStatus.firestoreValue,
      if (stripeCheckoutSessionId != null) 'stripeCheckoutSessionId': stripeCheckoutSessionId,
      if (stripePaymentIntentId != null) 'stripePaymentIntentId': stripePaymentIntentId,
      if (stripeCustomerId != null) 'stripeCustomerId': stripeCustomerId,
      'pricingBreakdown': pricingBreakdown,
      'metadata': metadata,
      'createdAt': TimestampMapper.toFirestore(createdAt),
      'updatedAt': TimestampMapper.toFirestore(updatedAt),
      if (paidAt != null) 'paidAt': TimestampMapper.toFirestore(paidAt),
      if (deliveredAt != null) 'deliveredAt': TimestampMapper.toFirestore(deliveredAt),
    };
  }

  MediaOrderModel copyWith({
    String? orderId,
    String? buyerUid,
    List<String>? photographerIds,
    List<MediaOrderLineItemModel>? items,
    String? currency,
    double? subtotal,
    double? stripeFee,
    double? platformFee,
    double? taxAmount,
    double? total,
    double? photographerNetTotal,
    OrderPaymentStatus? paymentStatus,
    OrderDeliveryStatus? deliveryStatus,
    String? stripeCheckoutSessionId,
    String? stripePaymentIntentId,
    String? stripeCustomerId,
    Map<String, dynamic>? pricingBreakdown,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? paidAt,
    DateTime? deliveredAt,
  }) {
    return MediaOrderModel(
      orderId: orderId ?? this.orderId,
      buyerUid: buyerUid ?? this.buyerUid,
      photographerIds: photographerIds ?? this.photographerIds,
      items: items ?? this.items,
      currency: currency ?? this.currency,
      subtotal: subtotal ?? this.subtotal,
      stripeFee: stripeFee ?? this.stripeFee,
      platformFee: platformFee ?? this.platformFee,
      taxAmount: taxAmount ?? this.taxAmount,
      total: total ?? this.total,
      photographerNetTotal: photographerNetTotal ?? this.photographerNetTotal,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      deliveryStatus: deliveryStatus ?? this.deliveryStatus,
      stripeCheckoutSessionId: stripeCheckoutSessionId ?? this.stripeCheckoutSessionId,
      stripePaymentIntentId: stripePaymentIntentId ?? this.stripePaymentIntentId,
      stripeCustomerId: stripeCustomerId ?? this.stripeCustomerId,
      pricingBreakdown: pricingBreakdown ?? this.pricingBreakdown,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      paidAt: paidAt ?? this.paidAt,
      deliveredAt: deliveredAt ?? this.deliveredAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MediaOrderModel &&
        other.orderId == orderId &&
        other.buyerUid == buyerUid &&
        listEquals(other.photographerIds, photographerIds) &&
        listEquals(other.items, items) &&
        other.currency == currency &&
        other.subtotal == subtotal &&
        other.stripeFee == stripeFee &&
        other.platformFee == platformFee &&
        other.taxAmount == taxAmount &&
        other.total == total &&
        other.photographerNetTotal == photographerNetTotal &&
        other.paymentStatus == paymentStatus &&
        other.deliveryStatus == deliveryStatus &&
        other.stripeCheckoutSessionId == stripeCheckoutSessionId &&
        other.stripePaymentIntentId == stripePaymentIntentId &&
        other.stripeCustomerId == stripeCustomerId &&
        mapEquals(other.pricingBreakdown, pricingBreakdown) &&
        mapEquals(other.metadata, metadata) &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt &&
        other.paidAt == paidAt &&
        other.deliveredAt == deliveredAt;
  }

  @override
  int get hashCode => Object.hashAll(<Object?>[
        orderId,
        buyerUid,
        Object.hashAll(photographerIds),
        Object.hashAll(items),
        currency,
        subtotal,
        stripeFee,
        platformFee,
        taxAmount,
        total,
        photographerNetTotal,
        paymentStatus,
        deliveryStatus,
        stripeCheckoutSessionId,
        stripePaymentIntentId,
        stripeCustomerId,
        Object.hashAll(pricingBreakdown.entries),
        Object.hashAll(metadata.entries),
        createdAt,
        updatedAt,
        paidAt,
        deliveredAt,
      ]);
}