import 'package:flutter/foundation.dart';

@immutable
class PhotoSearchQuery {
  const PhotoSearchQuery({
    this.circuitId,
    this.eventDate,
    this.approximateTime,
    this.pointId,
    this.participantNumber,
    this.outfitColor,
    this.bibNumber,
    this.group,
    this.team,
    this.slot,
    this.participantQrCode,
  });

  final String? circuitId;
  final DateTime? eventDate;
  final DateTime? approximateTime;
  final String? pointId;
  final String? participantNumber;
  final String? outfitColor;
  final String? bibNumber;
  final String? group;
  final String? team;
  final String? slot;
  final String? participantQrCode;

  String? get groupId => group;
  String? get teamId => team;
  String? get timeSlot => slot;

  bool get isEmpty => toFirestoreFilters().isEmpty;
  bool get hasCriteria => !isEmpty;

  factory PhotoSearchQuery.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const PhotoSearchQuery();

    return PhotoSearchQuery(
      circuitId: _normalized(map['circuitId'] ?? map['selectedCircuitId']),
      eventDate: _parseDate(map['eventDate'] ?? map['selectedEventDate']),
      approximateTime: _parseDate(map['approximateTime']),
      pointId: _normalized(map['pointId'] ?? map['selectedPointId']),
      participantNumber: _normalized(map['participantNumber']),
      outfitColor: _normalized(map['outfitColor']),
      bibNumber: _normalized(map['bibNumber']),
      group: _normalized(map['groupId'] ?? map['group']),
      team: _normalized(map['teamId'] ?? map['team']),
      slot: _normalized(
        map['timeSlot'] ?? map['selectedTimeSlot'] ?? map['slot'],
      ),
      participantQrCode: _normalized(map['participantQrCode']),
    );
  }

  Map<String, dynamic> toFirestoreFilters() => <String, dynamic>{
        if (_has(circuitId)) 'circuitId': circuitId!.trim(),
        if (eventDate != null) 'eventDay': _dayKey(eventDate!),
        if (approximateTime != null)
          'approximateMinute':
              approximateTime!.hour * 60 + approximateTime!.minute,
        if (_has(pointId)) 'pointId': pointId!.trim(),
        if (_has(participantNumber))
          'participantNumber': participantNumber!.trim().toUpperCase(),
        if (_has(outfitColor))
          'outfitColor': outfitColor!.trim().toLowerCase(),
        if (_has(bibNumber))
          'bibNumber': bibNumber!.trim().toUpperCase(),
        if (_has(group)) 'group': group!.trim().toLowerCase(),
        if (_has(team)) 'team': team!.trim().toLowerCase(),
        if (_has(slot)) 'slot': slot!.trim().toLowerCase(),
        if (_has(participantQrCode))
          'participantQrCode': participantQrCode!.trim(),
      };

  List<String> toNormalizedTags() {
    final filters = toFirestoreFilters();
    return filters.entries
        .where((entry) => entry.value is String)
        .map((entry) => '${entry.key}:${entry.value}')
        .toList(growable: false);
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

  static String _dayKey(DateTime value) {
    final local = value.toLocal();
    return '${local.year.toString().padLeft(4, '0')}-'
        '${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')}';
  }
}
