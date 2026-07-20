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
    this.selectedTimeSlot,
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
  final String? selectedTimeSlot;
  final DateTime? approximateTime;

  bool get hasSelection =>
      _has(selectedCircuitId) ||
      _has(selectedMapId) ||
      _has(selectedCountryId) ||
      _has(selectedEventId) ||
      _has(selectedPhotographerId) ||
      _has(selectedPointId) ||
      _has(selectedTimeSlot) ||
      selectedEventDate != null ||
      approximateTime != null;

  Map<String, dynamic> toRouteArguments({
    bool includeLegacyAliases = false,
  }) {
    final modern = <String, dynamic>{
      if (_has(selectedCircuitId))
        'selectedCircuitId': selectedCircuitId!.trim(),
      if (_has(selectedMapId)) 'selectedMapId': selectedMapId!.trim(),
      if (selectedEventDate != null)
        'selectedEventDate': selectedEventDate!.toIso8601String(),
      if (_has(selectedCountryId))
        'selectedCountryId': selectedCountryId!.trim(),
      if (_has(selectedEventId)) 'selectedEventId': selectedEventId!.trim(),
      if (_has(selectedCircuitName))
        'selectedCircuitName': selectedCircuitName!.trim(),
      if (_has(selectedPhotographerId))
        'selectedPhotographerId': selectedPhotographerId!.trim(),
      if (_has(selectedPointId)) 'selectedPointId': selectedPointId!.trim(),
      if (_has(selectedTimeSlot))
        'selectedTimeSlot': selectedTimeSlot!.trim(),
      if (approximateTime != null)
        'approximateTime': approximateTime!.toIso8601String(),
    };

    final legacy = <String, dynamic>{
      if (_has(selectedCircuitId)) 'circuitId': selectedCircuitId!.trim(),
      if (_has(selectedMapId)) 'mapId': selectedMapId!.trim(),
      if (selectedEventDate != null)
        'eventDate': selectedEventDate!.toIso8601String(),
      if (_has(selectedCountryId)) 'countryId': selectedCountryId!.trim(),
      if (_has(selectedEventId)) 'eventId': selectedEventId!.trim(),
      if (_has(selectedCircuitName))
        'circuitName': selectedCircuitName!.trim(),
      if (_has(selectedPhotographerId))
        'photographerId': selectedPhotographerId!.trim(),
      if (_has(selectedPointId)) 'pointId': selectedPointId!.trim(),
      if (_has(selectedTimeSlot)) 'timeSlot': selectedTimeSlot!.trim(),
      if (approximateTime != null)
        'approximateTime': approximateTime!.toIso8601String(),
    };

    if (!includeLegacyAliases) return legacy;
    return <String, dynamic>{...modern, ...legacy};
  }

  factory PhotoShopNavigationContext.fromRouteArguments(Object? arguments) {
    if (arguments is! Map) return const PhotoShopNavigationContext();
    final map = Map<String, dynamic>.from(arguments);

    return PhotoShopNavigationContext(
      selectedCircuitId: _normalized(
        map['selectedCircuitId'] ?? map['circuitId'],
      ),
      selectedMapId: _normalized(map['selectedMapId'] ?? map['mapId']),
      selectedEventDate: _parseDate(
        map['selectedEventDate'] ?? map['eventDate'],
      ),
      selectedCountryId: _normalized(
        map['selectedCountryId'] ?? map['countryId'],
      ),
      selectedEventId: _normalized(map['selectedEventId'] ?? map['eventId']),
      selectedCircuitName: _normalized(
        map['selectedCircuitName'] ?? map['circuitName'],
      ),
      selectedPhotographerId: _normalized(
        map['selectedPhotographerId'] ?? map['photographerId'],
      ),
      selectedPointId: _normalized(map['selectedPointId'] ?? map['pointId']),
      selectedTimeSlot: _normalized(
        map['selectedTimeSlot'] ?? map['timeSlot'] ?? map['slot'],
      ),
      approximateTime: _parseDate(map['approximateTime']),
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
    String? selectedTimeSlot,
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
      selectedTimeSlot: selectedTimeSlot ?? this.selectedTimeSlot,
      approximateTime: approximateTime ?? this.approximateTime,
    );
  }

  static bool _has(String? value) => value?.trim().isNotEmpty == true;

  static String? _normalized(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  static DateTime? _parseDate(Object? value) {
    if (value is DateTime) return value;
    final text = _normalized(value);
    return text == null ? null : DateTime.tryParse(text);
  }
}
