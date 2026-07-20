import 'package:flutter/foundation.dart';

@immutable
class PhotoShopNavigationContext {
  const PhotoShopNavigationContext({
    this.selectedCircuitId,
    this.selectedMapId,
    this.selectedEventDate,
    this.selectedCountryId,
    this.selectedEventId,
    this.selectedCircuitName,
    this.selectedPhotographerId,
    this.selectedPointId,
    this.approximateTime,
  });

  final String? selectedCircuitId;
  final String? selectedMapId;
  final DateTime? selectedEventDate;
  final String? selectedCountryId;
  final String? selectedEventId;
  final String? selectedCircuitName;
  final String? selectedPhotographerId;
  final String? selectedPointId;
  final DateTime? approximateTime;

  bool get hasSelection =>
      selectedCircuitId?.trim().isNotEmpty == true ||
      selectedMapId?.trim().isNotEmpty == true ||
      selectedEventId?.trim().isNotEmpty == true ||
      selectedCountryId?.trim().isNotEmpty == true ||
      selectedEventDate != null;

  Map<String, dynamic> toRouteArguments() => <String, dynamic>{
        if (selectedCircuitId?.trim().isNotEmpty == true)
          'circuitId': selectedCircuitId!.trim(),
        if (selectedMapId?.trim().isNotEmpty == true)
          'mapId': selectedMapId!.trim(),
        if (selectedEventDate != null)
          'eventDate': selectedEventDate!.toIso8601String(),
        if (selectedCountryId?.trim().isNotEmpty == true)
          'countryId': selectedCountryId!.trim(),
        if (selectedEventId?.trim().isNotEmpty == true)
          'eventId': selectedEventId!.trim(),
        if (selectedCircuitName?.trim().isNotEmpty == true)
          'circuitName': selectedCircuitName!.trim(),
        if (selectedPhotographerId?.trim().isNotEmpty == true)
          'photographerId': selectedPhotographerId!.trim(),
        if (selectedPointId?.trim().isNotEmpty == true)
          'pointId': selectedPointId!.trim(),
        if (approximateTime != null)
          'approximateTime': approximateTime!.toIso8601String(),
      };

  factory PhotoShopNavigationContext.fromRouteArguments(Object? arguments) {
    if (arguments is! Map) return const PhotoShopNavigationContext();
    final map = Map<String, dynamic>.from(arguments);
    DateTime? parseDate(Object? value) {
      if (value is DateTime) return value;
      return value == null ? null : DateTime.tryParse(value.toString());
    }

    String? normalized(Object? value) {
      final text = value?.toString().trim();
      return text == null || text.isEmpty ? null : text;
    }

    return PhotoShopNavigationContext(
      selectedCircuitId: normalized(map['selectedCircuitId'] ?? map['circuitId']),
      selectedMapId: normalized(map['selectedMapId'] ?? map['mapId']),
      selectedEventDate: parseDate(map['selectedEventDate'] ?? map['eventDate']),
      selectedCountryId: normalized(map['selectedCountryId'] ?? map['countryId']),
      selectedEventId: normalized(map['selectedEventId'] ?? map['eventId']),
      selectedCircuitName: normalized(map['circuitName']),
      selectedPhotographerId:
          normalized(map['selectedPhotographerId'] ?? map['photographerId']),
      selectedPointId: normalized(map['selectedPointId'] ?? map['pointId']),
      approximateTime: parseDate(map['approximateTime']),
    );
  }

  PhotoShopNavigationContext copyWith({
    String? selectedCircuitId,
    String? selectedMapId,
    DateTime? selectedEventDate,
    String? selectedCountryId,
    String? selectedEventId,
    String? selectedCircuitName,
    String? selectedPhotographerId,
    String? selectedPointId,
    DateTime? approximateTime,
  }) {
    return PhotoShopNavigationContext(
      selectedCircuitId: selectedCircuitId ?? this.selectedCircuitId,
      selectedMapId: selectedMapId ?? this.selectedMapId,
      selectedEventDate: selectedEventDate ?? this.selectedEventDate,
      selectedCountryId: selectedCountryId ?? this.selectedCountryId,
      selectedEventId: selectedEventId ?? this.selectedEventId,
      selectedCircuitName: selectedCircuitName ?? this.selectedCircuitName,
      selectedPhotographerId:
          selectedPhotographerId ?? this.selectedPhotographerId,
      selectedPointId: selectedPointId ?? this.selectedPointId,
      approximateTime: approximateTime ?? this.approximateTime,
    );
  }
}
