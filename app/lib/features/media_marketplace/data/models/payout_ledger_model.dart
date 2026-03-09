import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/enums/payout_status.dart';
import '../mappers/timestamp_mapper.dart';

double _payoutDouble(dynamic value, {double fallback = 0}) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return fallback;
}

Map<String, dynamic> _payoutMap(dynamic value) {
  if (value is! Map) return const <String, dynamic>{};
  return Map<String, dynamic>.from(value);
}

/// Ecriture de ledger liée à une vente et au reversement photographe.
class PayoutLedgerModel {
  final String ledgerId;
  final String photographerId;
  final String orderId;
  final String assetId;
  final double grossAmount;
  final double platformFee;
  final double stripeFee;
  final double taxAmount;
  final double netAmount;
  final String currency;
  final PayoutStatus payoutStatus;
  final String? payoutBatchId;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? paidAt;

  const PayoutLedgerModel({
    required this.ledgerId,
    required this.photographerId,
    required this.orderId,
    required this.assetId,
    this.grossAmount = 0,
    this.platformFee = 0,
    this.stripeFee = 0,
    this.taxAmount = 0,
    this.netAmount = 0,
    this.currency = 'EUR',
    this.payoutStatus = PayoutStatus.pending,
    this.payoutBatchId,
    this.metadata = const <String, dynamic>{},
    required this.createdAt,
    required this.updatedAt,
    this.paidAt,
  });

  factory PayoutLedgerModel.fromMap(Map<String, dynamic> map, {String? ledgerId}) {
    return PayoutLedgerModel(
      ledgerId: ledgerId ?? (map['ledgerId']?.toString() ?? ''),
      photographerId: map['photographerId']?.toString() ?? '',
      orderId: map['orderId']?.toString() ?? '',
      assetId: map['assetId']?.toString() ?? '',
      grossAmount: _payoutDouble(map['grossAmount']),
      platformFee: _payoutDouble(map['platformFee']),
      stripeFee: _payoutDouble(map['stripeFee']),
      taxAmount: _payoutDouble(map['taxAmount']),
      netAmount: _payoutDouble(map['netAmount']),
      currency: map['currency']?.toString() ?? 'EUR',
      payoutStatus: payoutStatusFromString(map['payoutStatus']?.toString()),
      payoutBatchId: map['payoutBatchId']?.toString(),
      metadata: _payoutMap(map['metadata']),
      createdAt: TimestampMapper.fromFirestoreOrNow(map['createdAt']),
      updatedAt: TimestampMapper.fromFirestoreOrNow(map['updatedAt']),
      paidAt: TimestampMapper.fromFirestore(map['paidAt']),
    );
  }

  factory PayoutLedgerModel.fromDocument(DocumentSnapshot<Map<String, dynamic>> doc) {
    return PayoutLedgerModel.fromMap(doc.data() ?? const <String, dynamic>{}, ledgerId: doc.id);
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'ledgerId': ledgerId,
      'photographerId': photographerId,
      'orderId': orderId,
      'assetId': assetId,
      'grossAmount': grossAmount,
      'platformFee': platformFee,
      'stripeFee': stripeFee,
      'taxAmount': taxAmount,
      'netAmount': netAmount,
      'currency': currency,
      'payoutStatus': payoutStatus.firestoreValue,
      if (payoutBatchId != null) 'payoutBatchId': payoutBatchId,
      'metadata': metadata,
      'createdAt': TimestampMapper.toFirestore(createdAt),
      'updatedAt': TimestampMapper.toFirestore(updatedAt),
      if (paidAt != null) 'paidAt': TimestampMapper.toFirestore(paidAt),
    };
  }

  PayoutLedgerModel copyWith({
    String? ledgerId,
    String? photographerId,
    String? orderId,
    String? assetId,
    double? grossAmount,
    double? platformFee,
    double? stripeFee,
    double? taxAmount,
    double? netAmount,
    String? currency,
    PayoutStatus? payoutStatus,
    String? payoutBatchId,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? paidAt,
  }) {
    return PayoutLedgerModel(
      ledgerId: ledgerId ?? this.ledgerId,
      photographerId: photographerId ?? this.photographerId,
      orderId: orderId ?? this.orderId,
      assetId: assetId ?? this.assetId,
      grossAmount: grossAmount ?? this.grossAmount,
      platformFee: platformFee ?? this.platformFee,
      stripeFee: stripeFee ?? this.stripeFee,
      taxAmount: taxAmount ?? this.taxAmount,
      netAmount: netAmount ?? this.netAmount,
      currency: currency ?? this.currency,
      payoutStatus: payoutStatus ?? this.payoutStatus,
      payoutBatchId: payoutBatchId ?? this.payoutBatchId,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      paidAt: paidAt ?? this.paidAt,
    );
  }
}