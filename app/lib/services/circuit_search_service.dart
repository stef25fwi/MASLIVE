import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

enum CircuitSource { draft, mapMarket }

class CircuitPick {
  CircuitPick({
    required this.source,
    required this.countryId,
    required this.eventId,
    required this.circuitId,
    required this.name,
    required this.refPath,
    this.updatedAt,
    this.projectId,
  });

  final CircuitSource source;
  final String countryId;
  final String eventId;
  final String circuitId;
  final String name;
  final DateTime? updatedAt;

  /// Chemin Firestore complet (utile debug / navigation).
  final String refPath;

  /// Pour les brouillons: id du doc `map_projects/{projectId}`.
  final String? projectId;

  String get badge => source == CircuitSource.draft ? 'Brouillon' : 'Publié';

  /// Clé unique pour UI (dropdown) quand on conserve les doublons.
  String get key => '$countryId::$eventId::$circuitId::${source.name}';

  /// Clé logique (draft + publié peuvent partager ce key).
  String get logicalKey => '$countryId::$eventId::$circuitId';
}

class CircuitSearchService {
  CircuitSearchService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  Stream<List<CircuitPick>> watchDraftCircuits({
    required String countryId,
    required String eventId,
    String? actorUid,
    String? queryText,
  }) {
    Query<Map<String, dynamic>> q = _db
        .collection('map_projects')
        .where('countryId', isEqualTo: countryId)
        .where('eventId', isEqualTo: eventId);

    final uid = (actorUid ?? '').trim();
    if (uid.isNotEmpty) {
      q = q.where('uid', isEqualTo: uid);
    }

    return q.snapshots().map((snap) {
      final text = (queryText ?? '').trim().toLowerCase();
      final items = snap.docs
          .map((d) {
            final data = d.data();
            final name = (data['circuitName'] ?? data['name'] ?? 'Sans nom').toString();
            final updated = (data['updatedAt'] as Timestamp?)?.toDate();
            final cid = (data['circuitId'] ?? d.id).toString();
            return CircuitPick(
              source: CircuitSource.draft,
              countryId: countryId,
              eventId: eventId,
              circuitId: cid,
              name: name,
              updatedAt: updated,
              refPath: d.reference.path,
              projectId: d.id,
            );
          })
          .where((c) {
            if (text.isEmpty) return true;
            return c.name.toLowerCase().contains(text);
          })
          .toList();

      items.sort((a, b) {
        final na = a.name.toLowerCase();
        final nb = b.name.toLowerCase();
        final cmp = na.compareTo(nb);
        if (cmp != 0) return cmp;
        final ta = a.updatedAt?.millisecondsSinceEpoch ?? 0;
        final tb = b.updatedAt?.millisecondsSinceEpoch ?? 0;
        return tb.compareTo(ta);
      });

      return items;
    });
  }

  Stream<List<CircuitPick>> watchPublishedCircuits({
    required String countryId,
    required String eventId,
    String? queryText,
  }) {
    Query<Map<String, dynamic>> q = _db
        .collection('marketMap')
        .doc(countryId)
        .collection('events')
        .doc(eventId)
        .collection('circuits');

    return q.snapshots().map((snap) {
      final text = (queryText ?? '').trim().toLowerCase();
      final items = snap.docs
          .map((d) {
            final data = d.data();
            final name = (data['name'] ?? 'Sans nom').toString();
            final updated = (data['updatedAt'] as Timestamp?)?.toDate();
            return CircuitPick(
              source: CircuitSource.mapMarket,
              countryId: countryId,
              eventId: eventId,
              circuitId: d.id,
              name: name,
              updatedAt: updated,
              refPath: d.reference.path,
            );
          })
          .where((c) {
            if (text.isEmpty) return true;
            return c.name.toLowerCase().contains(text);
          })
          .toList();

      items.sort((a, b) {
        final na = a.name.toLowerCase();
        final nb = b.name.toLowerCase();
        final cmp = na.compareTo(nb);
        if (cmp != 0) return cmp;
        final ta = a.updatedAt?.millisecondsSinceEpoch ?? 0;
        final tb = b.updatedAt?.millisecondsSinceEpoch ?? 0;
        return tb.compareTo(ta);
      });

      return items;
    });
  }

  Stream<List<CircuitPick>> watchAllCircuitsForPoiTile({
    required String countryId,
    required String eventId,
    String? actorUid,
    String? queryText,
    bool keepBothIfDuplicate = true,
  }) {
    final draft$ = watchDraftCircuits(
      countryId: countryId,
      eventId: eventId,
      actorUid: actorUid,
      queryText: queryText,
    );
    final pub$ = watchPublishedCircuits(
      countryId: countryId,
      eventId: eventId,
      queryText: queryText,
    );

    return _combineLatest2<List<CircuitPick>, List<CircuitPick>, List<CircuitPick>>(
      draft$,
      pub$,
      (draftList, pubList) {
        final all = <CircuitPick>[...pubList, ...draftList];

        if (keepBothIfDuplicate) {
          all.sort((a, b) {
            final sa = a.source == CircuitSource.mapMarket ? 0 : 1;
            final sb = b.source == CircuitSource.mapMarket ? 0 : 1;
            if (sa != sb) return sa.compareTo(sb);
            final ta = a.updatedAt?.millisecondsSinceEpoch ?? 0;
            final tb = b.updatedAt?.millisecondsSinceEpoch ?? 0;
            return tb.compareTo(ta);
          });
          return all;
        }

        // Dédupe logique (priorité: publié)
        final byLogical = <String, CircuitPick>{};
        for (final c in all) {
          final k = c.logicalKey;
          final existing = byLogical[k];
          if (existing == null) {
            byLogical[k] = c;
            continue;
          }
          if (existing.source == CircuitSource.draft && c.source == CircuitSource.mapMarket) {
            byLogical[k] = c;
          }
        }

        final merged = byLogical.values.toList()
          ..sort((a, b) {
            final ta = a.updatedAt?.millisecondsSinceEpoch ?? 0;
            final tb = b.updatedAt?.millisecondsSinceEpoch ?? 0;
            return tb.compareTo(ta);
          });
        return merged;
      },
    );
  }
}

Stream<R> _combineLatest2<A, B, R>(
  Stream<A> a$,
  Stream<B> b$,
  R Function(A a, B b) combiner,
) {
  late final StreamController<R> controller;
  StreamSubscription<A>? subA;
  StreamSubscription<B>? subB;

  A? lastA;
  B? lastB;
  var hasA = false;
  var hasB = false;

  void emitIfReady() {
    if (!hasA || !hasB) return;
    try {
      controller.add(combiner(lastA as A, lastB as B));
    } catch (e, st) {
      controller.addError(e, st);
    }
  }

  controller = StreamController<R>(
    onListen: () {
      subA = a$.listen(
        (v) {
          lastA = v;
          hasA = true;
          emitIfReady();
        },
        onError: controller.addError,
        onDone: () {
          // On ne ferme pas automatiquement: l'autre stream peut continuer.
        },
      );
      subB = b$.listen(
        (v) {
          lastB = v;
          hasB = true;
          emitIfReady();
        },
        onError: controller.addError,
        onDone: () {
          // idem
        },
      );
    },
    onCancel: () async {
      await subA?.cancel();
      await subB?.cancel();
    },
  );

  return controller.stream;
}
