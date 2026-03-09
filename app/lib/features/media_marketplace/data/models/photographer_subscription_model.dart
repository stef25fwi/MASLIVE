import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/enums/subscription_status.dart';
import '../mappers/timestamp_mapper.dart';

int _subscriptionInt(dynamic value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return fallback;
}

double _subscriptionDouble(dynamic value, {double fallback = 0}) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return fallback;
}

Map<String, dynamic> _subscriptionMap(dynamic value) {
  if (value is! Map) return const <String, dynamic>{};
  return Map<String, dynamic>.from(value);
}

/// Snapshot de quota embarque dans l'abonnement pour garantir la coherence historique.
class PhotographerQuotaSnapshot {
  final int maxPublishedPhotos;
  final int maxStorageBytes;
  final int maxActiveGalleries;
  final int maxActivePacks;
  final double commissionRate;
  final String? planCode;

  const PhotographerQuotaSnapshot({
    this.maxPublishedPhotos = 0,
    this.maxStorageBytes = 0,
    this.maxActiveGalleries = 0,
    this.maxActivePacks = 0,
    this.commissionRate = 0,
    this.planCode,
  });

  factory PhotographerQuotaSnapshot.fromMap(Map<String, dynamic> map) {
    return PhotographerQuotaSnapshot(
      maxPublishedPhotos: _subscriptionInt(map['maxPublishedPhotos']),
      maxStorageBytes: _subscriptionInt(map['maxStorageBytes']),
      maxActiveGalleries: _subscriptionInt(map['maxActiveGalleries']),
      maxActivePacks: _subscriptionInt(map['maxActivePacks']),
      commissionRate: _subscriptionDouble(map['commissionRate']),
      planCode: map['planCode']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'maxPublishedPhotos': maxPublishedPhotos,
      'maxStorageBytes': maxStorageBytes,
      'maxActiveGalleries': maxActiveGalleries,
      'maxActivePacks': maxActivePacks,
      'commissionRate': commissionRate,
      if (planCode != null) 'planCode': planCode,
    };
  }

  PhotographerQuotaSnapshot copyWith({
    int? maxPublishedPhotos,
    int? maxStorageBytes,
    int? maxActiveGalleries,
    int? maxActivePacks,
    double? commissionRate,
    String? planCode,
  }) {
    return PhotographerQuotaSnapshot(
      maxPublishedPhotos: maxPublishedPhotos ?? this.maxPublishedPhotos,
      maxStorageBytes: maxStorageBytes ?? this.maxStorageBytes,
      maxActiveGalleries: maxActiveGalleries ?? this.maxActiveGalleries,
      maxActivePacks: maxActivePacks ?? this.maxActivePacks,
      commissionRate: commissionRate ?? this.commissionRate,
      planCode: planCode ?? this.planCode,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PhotographerQuotaSnapshot &&
        other.maxPublishedPhotos == maxPublishedPhotos &&
        other.maxStorageBytes == maxStorageBytes &&
        other.maxActiveGalleries == maxActiveGalleries &&
        other.maxActivePacks == maxActivePacks &&
        other.commissionRate == commissionRate &&
        other.planCode == planCode;
  }

  @override
  int get hashCode => Object.hash(
        maxPublishedPhotos,
        maxStorageBytes,
        maxActiveGalleries,
        maxActivePacks,
        commissionRate,
        planCode,
      );
}

/// Abonnement Stripe d'un photographe et son etat synchronise.
class PhotographerSubscriptionModel {
  final String subscriptionId;
  final String photographerId;
  final String ownerUid;
  final String planId;
  final String? stripeCustomerId;
  final String? stripeSubscriptionId;
  final String? stripePriceId;
  final SubscriptionStatus status;
  final String billingInterval;
  final DateTime? startedAt;
  final DateTime? currentPeriodStart;
  final DateTime? currentPeriodEnd;
  final bool cancelAtPeriodEnd;
  final DateTime? canceledAt;
  final PhotographerQuotaSnapshot quotaSnapshot;
  final DateTime createdAt;
  final DateTime updatedAt;

  const PhotographerSubscriptionModel({
    required this.subscriptionId,
    required this.photographerId,
    required this.ownerUid,
    required this.planId,
    this.stripeCustomerId,
    this.stripeSubscriptionId,
    this.stripePriceId,
    this.status = SubscriptionStatus.incomplete,
    this.billingInterval = 'month',
    this.startedAt,
    this.currentPeriodStart,
    this.currentPeriodEnd,
    this.cancelAtPeriodEnd = false,
    this.canceledAt,
    this.quotaSnapshot = const PhotographerQuotaSnapshot(),
    required this.createdAt,
    required this.updatedAt,
  });

  factory PhotographerSubscriptionModel.fromMap(
    Map<String, dynamic> map, {
    String? subscriptionId,
  }) {
    return PhotographerSubscriptionModel(
      subscriptionId: subscriptionId ?? (map['subscriptionId']?.toString() ?? ''),
      photographerId: map['photographerId']?.toString() ?? '',
      ownerUid: map['ownerUid']?.toString() ?? '',
      planId: map['planId']?.toString() ?? '',
      stripeCustomerId: map['stripeCustomerId']?.toString(),
      stripeSubscriptionId: map['stripeSubscriptionId']?.toString(),
      stripePriceId: map['stripePriceId']?.toString(),
      status: subscriptionStatusFromString(map['status']?.toString()),
      billingInterval: map['billingInterval']?.toString() ?? 'month',
      startedAt: TimestampMapper.fromFirestore(map['startedAt']),
      currentPeriodStart: TimestampMapper.fromFirestore(map['currentPeriodStart']),
      currentPeriodEnd: TimestampMapper.fromFirestore(map['currentPeriodEnd']),
      cancelAtPeriodEnd: map['cancelAtPeriodEnd'] as bool? ?? false,
      canceledAt: TimestampMapper.fromFirestore(map['canceledAt']),
      quotaSnapshot: PhotographerQuotaSnapshot.fromMap(
        _subscriptionMap(map['quotaSnapshot']),
      ),
      createdAt: TimestampMapper.fromFirestoreOrNow(map['createdAt']),
      updatedAt: TimestampMapper.fromFirestoreOrNow(map['updatedAt']),
    );
  }

  factory PhotographerSubscriptionModel.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return PhotographerSubscriptionModel.fromMap(doc.data() ?? const <String, dynamic>{}, subscriptionId: doc.id);
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'subscriptionId': subscriptionId,
      'photographerId': photographerId,
      'ownerUid': ownerUid,
      'planId': planId,
      if (stripeCustomerId != null) 'stripeCustomerId': stripeCustomerId,
      if (stripeSubscriptionId != null) 'stripeSubscriptionId': stripeSubscriptionId,
      if (stripePriceId != null) 'stripePriceId': stripePriceId,
      'status': status.firestoreValue,
      'billingInterval': billingInterval,
      if (startedAt != null) 'startedAt': TimestampMapper.toFirestore(startedAt),
      if (currentPeriodStart != null)
        'currentPeriodStart': TimestampMapper.toFirestore(currentPeriodStart),
      if (currentPeriodEnd != null)
        'currentPeriodEnd': TimestampMapper.toFirestore(currentPeriodEnd),
      'cancelAtPeriodEnd': cancelAtPeriodEnd,
      if (canceledAt != null) 'canceledAt': TimestampMapper.toFirestore(canceledAt),
      'quotaSnapshot': quotaSnapshot.toMap(),
      'createdAt': TimestampMapper.toFirestore(createdAt),
      'updatedAt': TimestampMapper.toFirestore(updatedAt),
    };
  }

  PhotographerSubscriptionModel copyWith({
    String? subscriptionId,
    String? photographerId,
    String? ownerUid,
    String? planId,
    String? stripeCustomerId,
    String? stripeSubscriptionId,
    String? stripePriceId,
    SubscriptionStatus? status,
    String? billingInterval,
    DateTime? startedAt,
    DateTime? currentPeriodStart,
    DateTime? currentPeriodEnd,
    bool? cancelAtPeriodEnd,
    DateTime? canceledAt,
    PhotographerQuotaSnapshot? quotaSnapshot,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PhotographerSubscriptionModel(
      subscriptionId: subscriptionId ?? this.subscriptionId,
      photographerId: photographerId ?? this.photographerId,
      ownerUid: ownerUid ?? this.ownerUid,
      planId: planId ?? this.planId,
      stripeCustomerId: stripeCustomerId ?? this.stripeCustomerId,
      stripeSubscriptionId: stripeSubscriptionId ?? this.stripeSubscriptionId,
      stripePriceId: stripePriceId ?? this.stripePriceId,
      status: status ?? this.status,
      billingInterval: billingInterval ?? this.billingInterval,
      startedAt: startedAt ?? this.startedAt,
      currentPeriodStart: currentPeriodStart ?? this.currentPeriodStart,
      currentPeriodEnd: currentPeriodEnd ?? this.currentPeriodEnd,
      cancelAtPeriodEnd: cancelAtPeriodEnd ?? this.cancelAtPeriodEnd,
      canceledAt: canceledAt ?? this.canceledAt,
      quotaSnapshot: quotaSnapshot ?? this.quotaSnapshot,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PhotographerSubscriptionModel &&
        other.subscriptionId == subscriptionId &&
        other.photographerId == photographerId &&
        other.ownerUid == ownerUid &&
        other.planId == planId &&
        other.stripeCustomerId == stripeCustomerId &&
        other.stripeSubscriptionId == stripeSubscriptionId &&
        other.stripePriceId == stripePriceId &&
        other.status == status &&
        other.billingInterval == billingInterval &&
        other.startedAt == startedAt &&
        other.currentPeriodStart == currentPeriodStart &&
        other.currentPeriodEnd == currentPeriodEnd &&
        other.cancelAtPeriodEnd == cancelAtPeriodEnd &&
        other.canceledAt == canceledAt &&
        other.quotaSnapshot == quotaSnapshot &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode => Object.hash(
        subscriptionId,
        photographerId,
        ownerUid,
        planId,
        stripeCustomerId,
        stripeSubscriptionId,
        stripePriceId,
        status,
        billingInterval,
        startedAt,
        currentPeriodStart,
        currentPeriodEnd,
        cancelAtPeriodEnd,
        canceledAt,
        quotaSnapshot,
        createdAt,
        updatedAt,
      );
}