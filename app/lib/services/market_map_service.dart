import 'dart:math';
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/market_country.dart';
import '../models/market_circuit.dart';
import '../models/market_event.dart';
import '../models/market_layer.dart';
import '../models/market_poi.dart';

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

class VisibleCircuitsIndex {
  const VisibleCircuitsIndex({
    required this.countryIds,
    required this.eventIdsByCountry,
  });

  final Set<String> countryIds;
  final Map<String, Set<String>> eventIdsByCountry;

  Set<String> eventIdsForCountry(String countryId) {
    return eventIdsByCountry[countryId] ?? const <String>{};
  }
}

class MarketMapService {
  MarketMapService({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _countriesCol =>
      _db.collection('marketMap');

  /// Index (runtime) des circuits publiés et visibles.
  ///
  /// Objectif: filtrer les pays/événements affichés dans le menu "Carte"
  /// sans avoir besoin d'index composite Firestore (on fait une seule requête
  /// `collectionGroup('circuits')` filtrée sur `status==published` et
  /// `isVisible==true`).
  Stream<VisibleCircuitsIndex> watchVisibleCircuitsIndex() {
    final primary = _db
        .collectionGroup('circuits')
        .where('status', isEqualTo: 'published')
        .where('isVisible', isEqualTo: true)
        .snapshots()
        .map(_visibleIndexFromCircuitsGroupSnapshot);

    final fallback = _watchVisibleCircuitsIndexViaMarketMapPaths();

    late final StreamController<VisibleCircuitsIndex> controller;
    StreamSubscription<VisibleCircuitsIndex>? sub;
    var usedFallback = false;

    void listenTo(Stream<VisibleCircuitsIndex> s) {
      sub = s.listen(
        controller.add,
        onError: (error, stackTrace) {
          // Sur certaines configs de règles/index, le `collectionGroup('circuits')`
          // peut échouer et bloquer le menu Home (mode dégradé). On bascule sur
          // une stratégie robuste qui ne regarde que `marketMap/{country}/events/{event}/circuits`.
          if (!usedFallback && error is FirebaseException) {
            final code = error.code;
            if (code == 'permission-denied' || code == 'failed-precondition') {
              usedFallback = true;
              sub?.cancel();
              listenTo(fallback);
              return;
            }
          }

          controller.addError(error, stackTrace);
        },
      );
    }

    controller = StreamController<VisibleCircuitsIndex>(
      onListen: () {
        listenTo(primary);
      },
      onCancel: () async {
        await sub?.cancel();
      },
    );

    return controller.stream;
  }

  VisibleCircuitsIndex _visibleIndexFromCircuitsGroupSnapshot(
    QuerySnapshot<Map<String, dynamic>> snap,
  ) {
    final countryIds = <String>{};
    final eventIdsByCountry = <String, Set<String>>{};

    for (final d in snap.docs) {
      // IMPORTANT: certains anciens circuits n'ont pas (ou plus) des champs
      // `countryId`/`eventId` fiables. On dérive donc d'abord depuis le chemin.
      // Attendu: marketMap/{countryId}/events/{eventId}/circuits/{circuitId}
      String countryId = '';
      String eventId = '';

      final segments = d.reference.path.split('/');
      final marketMapIdx = segments.indexOf('marketMap');

      // Si ce `circuits` ne vient pas du MarketMap, on l'ignore.
      if (marketMapIdx == -1) continue;

      final canParseFromPath =
          segments.length >= marketMapIdx + 6 &&
          segments[marketMapIdx + 2] == 'events' &&
          segments[marketMapIdx + 4] == 'circuits';

      if (canParseFromPath) {
        countryId = segments[marketMapIdx + 1].trim();
        eventId = segments[marketMapIdx + 3].trim();
      }

      if (countryId.isEmpty || eventId.isEmpty) {
        final data = d.data();
        countryId = (data['countryId'] ?? '').toString().trim();
        eventId = (data['eventId'] ?? '').toString().trim();
      }
      if (countryId.isEmpty || eventId.isEmpty) continue;

      countryIds.add(countryId);
      (eventIdsByCountry[countryId] ??= <String>{}).add(eventId);
    }

    return VisibleCircuitsIndex(
      countryIds: countryIds,
      eventIdsByCountry: eventIdsByCountry,
    );
  }

  /// Fallback robuste: construit l'index des circuits publiés et visibles en ne scannant que
  /// l'arborescence `marketMap/{countryId}/events/{eventId}/circuits`.
  ///
  /// Cela évite les erreurs de permission possibles avec `collectionGroup('circuits')`
  /// quand d'autres sous-collections `circuits` existent ailleurs avec des règles plus strictes.
  Stream<VisibleCircuitsIndex> _watchVisibleCircuitsIndexViaMarketMapPaths() {
    late final StreamController<VisibleCircuitsIndex> controller;

    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? countriesSub;
    final eventsSubs = <String, StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>{};
    final circuitsSubs = <String, StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>{};

    // Cache: pour chaque (country,event) => hasVisible
    final hasVisibleByEvent = <String, bool>{};

    void emit() {
      final countryIds = <String>{};
      final eventIdsByCountry = <String, Set<String>>{};

      hasVisibleByEvent.forEach((key, hasVisible) {
        if (!hasVisible) return;
        final parts = key.split('|');
        if (parts.length != 2) return;
        final countryId = parts[0];
        final eventId = parts[1];
        if (countryId.isEmpty || eventId.isEmpty) return;
        countryIds.add(countryId);
        (eventIdsByCountry[countryId] ??= <String>{}).add(eventId);
      });

      controller.add(
        VisibleCircuitsIndex(
          countryIds: countryIds,
          eventIdsByCountry: eventIdsByCountry,
        ),
      );
    }

    void trackEventCircuits({required String countryId, required String eventId}) {
      final key = '$countryId|$eventId';
      if (circuitsSubs.containsKey(key)) return;

        final sub = _countriesCol
          .doc(countryId)
          .collection('events')
          .doc(eventId)
          .collection('circuits')
          .where('status', isEqualTo: 'published')
          .where('isVisible', isEqualTo: true)
          .limit(1)
          .snapshots()
          .listen(
            (snap) {
              hasVisibleByEvent[key] = snap.docs.isNotEmpty;
              emit();
            },
            onError: (error, stackTrace) {
              // En cas de permission, on considère qu'il n'y a pas de circuits visibles.
              if (error is FirebaseException && error.code == 'permission-denied') {
                hasVisibleByEvent[key] = false;
                emit();
                return;
              }
              controller.addError(error, stackTrace);
            },
          );

      circuitsSubs[key] = sub;
    }

    void untrackEventCircuits({required String countryId, required String eventId}) {
      final key = '$countryId|$eventId';
      hasVisibleByEvent.remove(key);
      circuitsSubs.remove(key)?.cancel();
    }

    void trackCountryEvents(String countryId) {
      if (eventsSubs.containsKey(countryId)) return;

      eventsSubs[countryId] = _countriesCol
          .doc(countryId)
          .collection('events')
          .snapshots()
          .listen(
            (snap) {
              final currentEventIds = <String>{for (final d in snap.docs) d.id};

              // Ajout des nouveaux.
              for (final eventId in currentEventIds) {
                trackEventCircuits(countryId: countryId, eventId: eventId);
              }

              // Suppression de ceux qui n'existent plus.
              final toRemove = <String>[];
              for (final key in hasVisibleByEvent.keys) {
                final parts = key.split('|');
                if (parts.length != 2) continue;
                if (parts[0] != countryId) continue;
                if (!currentEventIds.contains(parts[1])) {
                  toRemove.add(key);
                }
              }
              for (final key in toRemove) {
                final parts = key.split('|');
                if (parts.length != 2) continue;
                untrackEventCircuits(countryId: parts[0], eventId: parts[1]);
              }

              emit();
            },
            onError: (error, stackTrace) {
              if (error is FirebaseException && error.code == 'permission-denied') {
                // Un pays inaccessible => on le retire de l'index.
                final toRemove = <String>[];
                for (final key in hasVisibleByEvent.keys) {
                  final parts = key.split('|');
                  if (parts.length != 2) continue;
                  if (parts[0] == countryId) toRemove.add(key);
                }
                for (final k in toRemove) {
                  final parts = k.split('|');
                  if (parts.length != 2) continue;
                  untrackEventCircuits(countryId: parts[0], eventId: parts[1]);
                }
                eventsSubs.remove(countryId)?.cancel();
                emit();
                return;
              }
              controller.addError(error, stackTrace);
            },
          );
    }

    void untrackCountry(String countryId) {
      eventsSubs.remove(countryId)?.cancel();
      final keysToRemove = <String>[];
      for (final key in circuitsSubs.keys) {
        if (key.startsWith('$countryId|')) keysToRemove.add(key);
      }
      for (final key in keysToRemove) {
        final parts = key.split('|');
        if (parts.length != 2) continue;
        untrackEventCircuits(countryId: parts[0], eventId: parts[1]);
      }
    }

    controller = StreamController<VisibleCircuitsIndex>(
      onListen: () {
        controller.add(const VisibleCircuitsIndex(
          countryIds: <String>{},
          eventIdsByCountry: <String, Set<String>>{},
        ));

        countriesSub = _countriesCol.snapshots().listen(
          (snap) {
            final countryIds = <String>{for (final d in snap.docs) d.id};

            for (final id in countryIds) {
              trackCountryEvents(id);
            }

            final toRemove = <String>[];
            for (final existing in eventsSubs.keys) {
              if (!countryIds.contains(existing)) toRemove.add(existing);
            }
            for (final id in toRemove) {
              untrackCountry(id);
            }

            emit();
          },
          onError: controller.addError,
        );
      },
      onCancel: () async {
        await countriesSub?.cancel();
        for (final s in eventsSubs.values) {
          await s.cancel();
        }
        for (final s in circuitsSubs.values) {
          await s.cancel();
        }
      },
    );

    return controller.stream;
  }

  Stream<List<MarketCountry>> watchCountries() {
    return _countriesCol
        .orderBy('name')
        .snapshots()
        .map((snapshot) => snapshot.docs.map(MarketCountry.fromDoc).toList());
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

  Stream<List<MarketCircuit>> watchCircuits({
    required String countryId,
    required String eventId,
  }) {
    return _countriesCol
        .doc(countryId)
        .collection('events')
        .doc(eventId)
        .collection('circuits')
        .orderBy('updatedAt', descending: true)
        .orderBy('name')
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => MarketCircuit.fromDoc(doc)).toList(),
        );
  }

  Stream<List<MarketLayer>> watchLayers({
    required String countryId,
    required String eventId,
    required String circuitId,
  }) {
    return _countriesCol
        .doc(countryId)
        .collection('events')
        .doc(eventId)
        .collection('circuits')
        .doc(circuitId)
        .collection('layers')
        .orderBy('order')
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => MarketLayer.fromDoc(doc)).toList(),
        );
  }

  DocumentReference<Map<String, dynamic>> countryRef(String countryId) {
    return _countriesCol.doc(countryId);
  }

  DocumentReference<Map<String, dynamic>> eventRef({
    required String countryId,
    required String eventId,
  }) {
    return countryRef(countryId).collection('events').doc(eventId);
  }

  DocumentReference<Map<String, dynamic>> circuitRef({
    required String countryId,
    required String eventId,
    required String circuitId,
  }) {
    return eventRef(
      countryId: countryId,
      eventId: eventId,
    ).collection('circuits').doc(circuitId);
  }

  CollectionReference<Map<String, dynamic>> circuitPoisCol({
    required String countryId,
    required String eventId,
    required String circuitId,
  }) {
    return circuitRef(
      countryId: countryId,
      eventId: eventId,
      circuitId: circuitId,
    ).collection('pois');
  }

  /// Stream des POIs visibles pour un circuit.
  ///
  /// - `layerIds` vide/null => toutes les couches
  /// - `layerIds` <= 10 => filtre Firestore via whereIn
  /// - `layerIds` > 10 => requêtes chunkées (whereIn par paquets de 10) + merge
  Stream<List<MarketPoi>> watchVisiblePois({
    required String countryId,
    required String eventId,
    required String circuitId,
    Set<String>? layerIds,
  }) {
    final col = circuitPoisCol(
      countryId: countryId,
      eventId: eventId,
      circuitId: circuitId,
    );

    final normalized = (layerIds ?? const <String>{})
        .where((e) => e.trim().isNotEmpty)
        .toSet();

    Query<Map<String, dynamic>> query = col.where('isVisible', isEqualTo: true);

    if (normalized.isNotEmpty && normalized.length <= 10) {
      query = query.where('layerId', whereIn: normalized.toList());
    }

    if (normalized.isNotEmpty && normalized.length > 10) {
      final ids = normalized.toList()..sort();
      final chunks = <List<String>>[];
      for (var i = 0; i < ids.length; i += 10) {
        chunks.add(ids.sublist(i, min(i + 10, ids.length)));
      }

      late final StreamController<List<MarketPoi>> controller;
      final subs = <StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>[];
      final latestByChunk = <int, List<MarketPoi>>{};

      void emitMerged() {
        final byId = <String, MarketPoi>{};
        for (final list in latestByChunk.values) {
          for (final poi in list) {
            byId[poi.id] = poi;
          }
        }
        controller.add(byId.values.toList());
      }

      controller = StreamController<List<MarketPoi>>(
        onListen: () {
          for (var idx = 0; idx < chunks.length; idx++) {
            final chunk = chunks[idx];
            final q = col
                .where('isVisible', isEqualTo: true)
                .where('layerId', whereIn: chunk);

            subs.add(
              q.snapshots().listen((snap) {
                latestByChunk[idx] = snap.docs.map(MarketPoi.fromDoc).toList();
                emitMerged();
              }, onError: controller.addError),
            );
          }
        },
        onCancel: () async {
          for (final s in subs) {
            await s.cancel();
          }
        },
      );

      return controller.stream;
    }

    return query.snapshots().map((snap) {
      final pois = snap.docs.map(MarketPoi.fromDoc).toList();
      return pois;
    });
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
    DocumentReference<Map<String, dynamic>> circuitRef = eventRef
        .collection('circuits')
        .doc(circuitId);

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
        'isVisible': false,
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
        'style': {'fillOpacity': 0.15, 'lineWidth': 3},
        'params': {'snapToRoad': false, 'showLabels': true},
        'createdAt': serverNow,
        'updatedAt': serverNow,
      });

      tx.set(layersCol.doc('pois'), {
        'type': 'pois',
        'isEnabled': true,
        'order': 1,
        'style': {'icon': 'marker', 'iconSize': 1.0},
        'params': {'showLabels': true},
        'createdAt': serverNow,
        'updatedAt': serverNow,
      });

      tx.set(layersCol.doc('track'), {
        'type': 'track',
        'isEnabled': true,
        'order': 2,
        'style': {'lineWidth': 4, 'opacity': 1.0},
        'params': {'snapToRoad': false},
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
    final suffix = List.generate(
      5,
      (_) => chars[rand.nextInt(chars.length)],
    ).join();
    final base = circuitSlug.isEmpty ? 'circuit' : circuitSlug;
    return '$base-$suffix';
  }
}
