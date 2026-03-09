import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../mappers/timestamp_mapper.dart';

List<String> _planStringList(dynamic value) {
  if (value is! Iterable) return const <String>[];
  return value.map((item) => item.toString()).toList(growable: false);
}

int _planInt(dynamic value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return fallback;
}

double _planDouble(dynamic value, {double fallback = 0}) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return fallback;
}

/// Plan commercial et quota pour les photographes.
class PhotographerPlanModel {
  final String planId;
  final String code;
  final String name;
  final String description;
  final double monthlyPrice;
  final double annualPrice;
  final String? stripePriceMonthlyId;
  final String? stripePriceAnnualId;
  final int maxPublishedPhotos;
  final int maxStorageBytes;
  final int maxActiveGalleries;
  final int maxActivePacks;
  final double commissionRate;
  final List<String> features;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const PhotographerPlanModel({
    required this.planId,
    required this.code,
    required this.name,
    required this.description,
    this.monthlyPrice = 0,
    this.annualPrice = 0,
    this.stripePriceMonthlyId,
    this.stripePriceAnnualId,
    this.maxPublishedPhotos = 0,
    this.maxStorageBytes = 0,
    this.maxActiveGalleries = 0,
    this.maxActivePacks = 0,
    this.commissionRate = 0,
    this.features = const <String>[],
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PhotographerPlanModel.fromMap(
    Map<String, dynamic> map, {
    String? planId,
  }) {
    return PhotographerPlanModel(
      planId: planId ?? (map['planId']?.toString() ?? ''),
      code: map['code']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
      monthlyPrice: _planDouble(map['monthlyPrice']),
      annualPrice: _planDouble(map['annualPrice']),
      stripePriceMonthlyId: map['stripePriceMonthlyId']?.toString(),
      stripePriceAnnualId: map['stripePriceAnnualId']?.toString(),
      maxPublishedPhotos: _planInt(map['maxPublishedPhotos']),
      maxStorageBytes: _planInt(map['maxStorageBytes']),
      maxActiveGalleries: _planInt(map['maxActiveGalleries']),
      maxActivePacks: _planInt(map['maxActivePacks']),
      commissionRate: _planDouble(map['commissionRate']),
      features: _planStringList(map['features']),
      isActive: map['isActive'] as bool? ?? true,
      createdAt: TimestampMapper.fromFirestoreOrNow(map['createdAt']),
      updatedAt: TimestampMapper.fromFirestoreOrNow(map['updatedAt']),
    );
  }

  factory PhotographerPlanModel.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return PhotographerPlanModel.fromMap(doc.data() ?? const <String, dynamic>{}, planId: doc.id);
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'planId': planId,
      'code': code,
      'name': name,
      'description': description,
      'monthlyPrice': monthlyPrice,
      'annualPrice': annualPrice,
      if (stripePriceMonthlyId != null) 'stripePriceMonthlyId': stripePriceMonthlyId,
      if (stripePriceAnnualId != null) 'stripePriceAnnualId': stripePriceAnnualId,
      'maxPublishedPhotos': maxPublishedPhotos,
      'maxStorageBytes': maxStorageBytes,
      'maxActiveGalleries': maxActiveGalleries,
      'maxActivePacks': maxActivePacks,
      'commissionRate': commissionRate,
      'features': features,
      'isActive': isActive,
      'createdAt': TimestampMapper.toFirestore(createdAt),
      'updatedAt': TimestampMapper.toFirestore(updatedAt),
    };
  }

  PhotographerPlanModel copyWith({
    String? planId,
    String? code,
    String? name,
    String? description,
    double? monthlyPrice,
    double? annualPrice,
    String? stripePriceMonthlyId,
    String? stripePriceAnnualId,
    int? maxPublishedPhotos,
    int? maxStorageBytes,
    int? maxActiveGalleries,
    int? maxActivePacks,
    double? commissionRate,
    List<String>? features,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PhotographerPlanModel(
      planId: planId ?? this.planId,
      code: code ?? this.code,
      name: name ?? this.name,
      description: description ?? this.description,
      monthlyPrice: monthlyPrice ?? this.monthlyPrice,
      annualPrice: annualPrice ?? this.annualPrice,
      stripePriceMonthlyId: stripePriceMonthlyId ?? this.stripePriceMonthlyId,
      stripePriceAnnualId: stripePriceAnnualId ?? this.stripePriceAnnualId,
      maxPublishedPhotos: maxPublishedPhotos ?? this.maxPublishedPhotos,
      maxStorageBytes: maxStorageBytes ?? this.maxStorageBytes,
      maxActiveGalleries: maxActiveGalleries ?? this.maxActiveGalleries,
      maxActivePacks: maxActivePacks ?? this.maxActivePacks,
      commissionRate: commissionRate ?? this.commissionRate,
      features: features ?? this.features,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PhotographerPlanModel &&
        other.planId == planId &&
        other.code == code &&
        other.name == name &&
        other.description == description &&
        other.monthlyPrice == monthlyPrice &&
        other.annualPrice == annualPrice &&
        other.stripePriceMonthlyId == stripePriceMonthlyId &&
        other.stripePriceAnnualId == stripePriceAnnualId &&
        other.maxPublishedPhotos == maxPublishedPhotos &&
        other.maxStorageBytes == maxStorageBytes &&
        other.maxActiveGalleries == maxActiveGalleries &&
        other.maxActivePacks == maxActivePacks &&
        other.commissionRate == commissionRate &&
        listEquals(other.features, features) &&
        other.isActive == isActive &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode => Object.hash(
        planId,
        code,
        name,
        description,
        monthlyPrice,
        annualPrice,
        stripePriceMonthlyId,
        stripePriceAnnualId,
        maxPublishedPhotos,
        maxStorageBytes,
        maxActiveGalleries,
        maxActivePacks,
        commissionRate,
        Object.hashAll(features),
        isActive,
        createdAt,
        updatedAt,
      );
}