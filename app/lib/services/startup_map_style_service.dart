import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../utils/mapbox_style_url.dart';

class StartupHomeMapAppearance {
  const StartupHomeMapAppearance({
    required this.buildingsEnabled,
    required this.buildingsOpacity,
    required this.buildingColor,
    required this.greenColor,
    required this.waterColor,
  });

  static const StartupHomeMapAppearance defaults = StartupHomeMapAppearance(
    buildingsEnabled: true,
    buildingsOpacity: 0.72,
    buildingColor: Color(0xFFD1D5DB),
    greenColor: Color(0xFF77B255),
    waterColor: Color(0xFF58A6FF),
  );

  final bool buildingsEnabled;
  final double buildingsOpacity;
  final Color buildingColor;
  final Color greenColor;
  final Color waterColor;

  Map<String, Object> toMap() {
    return <String, Object>{
      'buildingsEnabled': buildingsEnabled,
      'buildingsOpacity': buildingsOpacity,
      'buildingColor': _colorToHex(buildingColor),
      'greenColor': _colorToHex(greenColor),
      'waterColor': _colorToHex(waterColor),
    };
  }

  factory StartupHomeMapAppearance.fromMap(Map<String, dynamic> map) {
    return StartupHomeMapAppearance(
      buildingsEnabled: _parseBool(
        map['buildingsEnabled'],
        fallback: defaults.buildingsEnabled,
      ),
      buildingsOpacity: _parseDouble(
        map['buildingsOpacity'],
        fallback: defaults.buildingsOpacity,
      ).clamp(0.0, 1.0),
      buildingColor: _parseColor(
        map['buildingColor'],
        fallback: defaults.buildingColor,
      ),
      greenColor: _parseColor(
        map['greenColor'],
        fallback: defaults.greenColor,
      ),
      waterColor: _parseColor(
        map['waterColor'],
        fallback: defaults.waterColor,
      ),
    );
  }

  static bool _parseBool(dynamic value, {required bool fallback}) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    final raw = (value ?? '').toString().trim().toLowerCase();
    if (raw == 'true' || raw == '1' || raw == 'yes' || raw == 'on') {
      return true;
    }
    if (raw == 'false' || raw == '0' || raw == 'no' || raw == 'off') {
      return false;
    }
    return fallback;
  }

  static double _parseDouble(dynamic value, {required double fallback}) {
    if (value is num) return value.toDouble();
    return double.tryParse((value ?? '').toString()) ?? fallback;
  }

  static Color _parseColor(dynamic value, {required Color fallback}) {
    final raw = (value ?? '').toString().trim();
    if (raw.isEmpty) return fallback;

    var normalized = raw;
    if (normalized.startsWith('#')) {
      normalized = normalized.substring(1);
    }
    if (normalized.startsWith('0x') || normalized.startsWith('0X')) {
      normalized = normalized.substring(2);
    }
    if (normalized.length == 6) {
      normalized = 'FF$normalized';
    }

    final parsed = int.tryParse(normalized, radix: 16);
    if (parsed == null) return fallback;
    return Color(parsed);
  }

  static String _colorToHex(Color color) {
    final argb = color.toARGB32().toRadixString(16).padLeft(8, '0');
    return '#${argb.toUpperCase()}';
  }
}

class StartupMapStyleService {
  StartupMapStyleService._();

  static final StartupMapStyleService instance = StartupMapStyleService._();

  static const String _collection = 'config';
  static const String _document = 'appStartup';
  static const String _fieldStyleUrl = 'defaultHomeMapStyleUrl';
  static const String _fieldHomeAppearance = 'defaultHomeMapAppearance';

  DocumentReference<Map<String, dynamic>> get _doc => FirebaseFirestore.instance
      .collection(_collection)
      .doc(_document);

  Future<String?> getDefaultStyleUrl() async {
    final snapshot = await _doc.get();
    return tryNormalizeMapboxStyleUrl(snapshot.data()?[_fieldStyleUrl] as String?);
  }

  Future<StartupHomeMapAppearance?> getHomeMapAppearance() async {
    final snapshot = await _doc.get();
    final raw = snapshot.data()?[_fieldHomeAppearance];
    if (raw is! Map) return null;
    return StartupHomeMapAppearance.fromMap(Map<String, dynamic>.from(raw));
  }

  Future<void> saveDefaultStyleUrl(String? styleUrl) async {
    final normalized = tryNormalizeMapboxStyleUrl(styleUrl);
    await _doc.set(
      <String, Object?>{
        _fieldStyleUrl:
            normalized == null || normalized.isEmpty ? FieldValue.delete() : normalized,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Future<void> saveHomeMapAppearance(StartupHomeMapAppearance? appearance) async {
    await _doc.set(
      <String, Object?>{
        _fieldHomeAppearance:
            appearance == null ? FieldValue.delete() : appearance.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Future<void> saveHomeMapConfig({
    String? styleUrl,
    StartupHomeMapAppearance? appearance,
  }) async {
    final normalized = tryNormalizeMapboxStyleUrl(styleUrl);
    await _doc.set(
      <String, Object?>{
        _fieldStyleUrl:
            normalized == null || normalized.isEmpty ? FieldValue.delete() : normalized,
        _fieldHomeAppearance:
            appearance == null ? FieldValue.delete() : appearance.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }
}