import 'package:cloud_firestore/cloud_firestore.dart';

/// Centralise les conversions Timestamp <-> DateTime du module media marketplace.
class TimestampMapper {
  const TimestampMapper._();

  static DateTime? fromFirestore(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }
    if (value is String) {
      return DateTime.tryParse(value);
    }
    return null;
  }

  static DateTime fromFirestoreOrNow(dynamic value) {
    return fromFirestore(value) ?? DateTime.now();
  }

  static Timestamp? toFirestore(DateTime? value) {
    if (value == null) return null;
    return Timestamp.fromDate(value);
  }
}