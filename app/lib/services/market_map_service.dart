import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/market_country.dart';
import '../models/market_event.dart';

class CreateCircuitResult {
  const CreateCircuitResult({
    required this.countryId,
    required this.eventId,
    required this.circuitId,
    required this.countryRef,
    required this.eventRef,
    required this.circuitRef,
  });

  final String countryId;
  final String eventId;
  final String circuitId;

  final DocumentReference<Map<String, dynamic>> countryRef;
  final DocumentReference<Map<String, dynamic>> eventRef;
  final DocumentReference<Map<String, dynamic>> circuitRef;
}

class MarketMapService {
  MarketMapService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _countriesCol =>
      _db.collection('marketMap');

  Stream<List<MarketCountry>> watchCountries() {
    return _countriesCol.orderBy('name').snapshots().map(
          (snapshot) => snapshot.docs.map(MarketCountry.fromDoc).toList(),
        );
  }

  Stream<List<MarketEvent>> watchEvents({required String countryId}) {
    return _countriesCol
        .doc(countryId)
        .collection('events')
        .orderBy('startDate', descending: true)
        .orderBy('name')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => MarketEvent.fromDoc(doc, countryId: countryId))
              .toList(),
        );
  }

  Future<CreateCircuitResult> createCircuitStep1({
    required String countryName,
    required String eventName,
    DateTime? startDate,
    DateTime? endDate,
    required String circuitName,
    required String uid,
  }) async {
    final normalizedCountry = _normalizeName(countryName);
    final normalizedEvent = _normalizeName(eventName);
    final normalizedCircuit = _normalizeName(circuitName);
    final normalizedUid = uid.trim();

    if (normalizedUid.isEmpty) {
      throw ArgumentError('uid est requis');
    }
    if (normalizedCountry.isEmpty) {
      throw ArgumentError('Le pays est requis');
    }
    if (normalizedEvent.isEmpty) {
      throw ArgumentError('L\'événement est requis');
    }
    if (normalizedCircuit.isEmpty) {
      throw ArgumentError('Le nom du circuit est requis');
    }
    if (startDate != null && endDate != null && endDate.isBefore(startDate)) {
      throw ArgumentError('La date de fin doit être après la date de début');
    }

    final countryId = slugify(normalizedCountry);
    final countryRef = _countriesCol.doc(countryId);

    final eventId = _buildEventId(normalizedEvent, startDate);
    final eventRef = countryRef.collection('events').doc(eventId);

    final circuitSlug = slugify(normalizedCircuit);

    // Id lisible + suffix pour éviter collisions
    String circuitId = _buildCircuitId(circuitSlug);
    DocumentReference<Map<String, dynamic>> circuitRef =
        eventRef.collection('circuits').doc(circuitId);

    const defaultCenter = {'lat': 16.241, 'lng': -61.533};

    await _db.runTransaction((tx) async {
      final serverNow = FieldValue.serverTimestamp();

      // 1) Country
      final countrySnap = await tx.get(countryRef);
      if (!countrySnap.exists) {
        tx.set(countryRef, {
          'name': normalizedCountry,
          'slug': countryId,
          'createdAt': serverNow,
          'updatedAt': serverNow,
        });
      } else {
        tx.update(countryRef, {'updatedAt': serverNow});
      }

      // 2) Event
      final eventSnap = await tx.get(eventRef);
      if (!eventSnap.exists) {
        tx.set(eventRef, {
          'name': normalizedEvent,
          'slug': eventId,
          'countryId': countryId,
          'startDate': startDate != null ? Timestamp.fromDate(startDate) : null,
          'endDate': endDate != null ? Timestamp.fromDate(endDate) : null,
          'createdAt': serverNow,
          'updatedAt': serverNow,
        });
      } else {
        final update = <String, dynamic>{'updatedAt': serverNow};
        if (startDate != null) {
          update['startDate'] = Timestamp.fromDate(startDate);
        }
        if (endDate != null) {
          update['endDate'] = Timestamp.fromDate(endDate);
        }
        tx.update(eventRef, update);
      }

      // 3) Circuit (collision check best-effort)
      for (int i = 0; i < 3; i++) {
        final existing = await tx.get(circuitRef);
        if (!existing.exists) break;
        circuitId = _buildCircuitId(circuitSlug);
        circuitRef = eventRef.collection('circuits').doc(circuitId);
      }

      tx.set(circuitRef, {
        'name': normalizedCircuit,
        'slug': circuitSlug,
        'status': 'draft',
        'countryId': countryId,
        'eventId': eventId,
        'createdByUid': normalizedUid,
        'createdAt': serverNow,
        'updatedAt': serverNow,
        'perimeterLocked': false,
        'zoomLocked': false,
        'center': defaultCenter,
        'initialZoom': 14,
        'bounds': null,
        'styleId': null,
        'styleUrl': null,
        'wizardState': {
          'wizardStep': 1,
          'completedSteps': [1],
        },
      });

      // 4) Default layers
      final layersCol = circuitRef.collection('layers');

      tx.set(layersCol.doc('perimeter'), {
        'type': 'perimeter',
        'isEnabled': true,
        'order': 0,
        'style': {
          'fillOpacity': 0.15,
          'lineWidth': 3,
        },
        'params': {
          'snapToRoad': false,
          'showLabels': true,
        },
        'createdAt': serverNow,
        'updatedAt': serverNow,
      });

      tx.set(layersCol.doc('pois'), {
        'type': 'pois',
        'isEnabled': true,
        'order': 1,
        'style': {
          'icon': 'marker',
          'iconSize': 1.0,
        },
        'params': {
          'showLabels': true,
        },
        'createdAt': serverNow,
        'updatedAt': serverNow,
      });

      tx.set(layersCol.doc('track'), {
        'type': 'track',
        'isEnabled': true,
        'order': 2,
        'style': {
          'lineWidth': 4,
          'opacity': 1.0,
        },
        'params': {
          'snapToRoad': false,
        },
        'createdAt': serverNow,
        'updatedAt': serverNow,
      });
    });

    return CreateCircuitResult(
      countryId: countryId,
      eventId: eventId,
      circuitId: circuitRef.id,
      countryRef: countryRef,
      eventRef: eventRef,
      circuitRef: circuitRef,
    );
  }

  static String _normalizeName(String input) {
    final trimmed = input.trim();
    final normalized = trimmed.replaceAll(RegExp(r'\s+'), ' ');
    if (normalized.isEmpty) return '';
    if (normalized.length > 60) return normalized.substring(0, 60).trim();
    return normalized;
  }

  static String slugify(String input) {
    var s = input.trim().toLowerCase();
    if (s.isEmpty) return '';

    const replacements = {
      'à': 'a',
      'á': 'a',
      'â': 'a',
      'ä': 'a',
      'ã': 'a',
      'å': 'a',
      'ç': 'c',
      'è': 'e',
      'é': 'e',
      'ê': 'e',
      'ë': 'e',
      'ì': 'i',
      'í': 'i',
      'î': 'i',
      'ï': 'i',
      'ñ': 'n',
      'ò': 'o',
      'ó': 'o',
      'ô': 'o',
      'ö': 'o',
      'õ': 'o',
      'ù': 'u',
      'ú': 'u',
      'û': 'u',
      'ü': 'u',
      'ý': 'y',
      'ÿ': 'y',
      'œ': 'oe',
      'æ': 'ae',
    };

    replacements.forEach((k, v) {
      s = s.replaceAll(k, v);
    });

    s = s
        .replaceAll(RegExp(r"[^a-z0-9]+"), '-')
        .replaceAll(RegExp(r"-+"), '-')
        .replaceAll(RegExp(r"^-|-$"), '');

    return s;
  }

  static String _buildEventId(String eventName, DateTime? startDate) {
    final base = slugify(eventName);
    if (startDate == null) return base;

    final yyyy = startDate.year.toString().padLeft(4, '0');
    final mm = startDate.month.toString().padLeft(2, '0');
    final dd = startDate.day.toString().padLeft(2, '0');
    return slugify('$base-$yyyy$mm$dd');
  }

  static String _buildCircuitId(String circuitSlug) {
    final rand = Random.secure();
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final suffix = List.generate(5, (_) => chars[rand.nextInt(chars.length)])
        .join();
    final base = circuitSlug.isEmpty ? 'circuit' : circuitSlug;
    return '$base-$suffix';
  }
}
