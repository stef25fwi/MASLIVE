import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/market_circuit_models.dart';
import 'audit_logger.dart';

typedef LngLat = ({double lng, double lat});

class CircuitDraftVersion {
  const CircuitDraftVersion({
    required this.id,
    required this.version,
    this.createdAt,
    this.createdBy,
  });

  final String id;
  final int version;
  final DateTime? createdAt;
  final String? createdBy;
}

class CircuitTemplate {
  const CircuitTemplate({
    required this.id,
    required this.name,
    required this.category,
    required this.defaultStyle,
    required this.defaultLayers,
    required this.defaultChecklist,
    this.isGlobal = false,
    this.createdBy,
  });

  final String id;
  final String name;
  final String category;
  final Map<String, dynamic> defaultStyle;
  final List<Map<String, dynamic>> defaultLayers;
  final List<dynamic> defaultChecklist;
  final bool isGlobal;
  final String? createdBy;

  factory CircuitTemplate.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return CircuitTemplate(
      id: doc.id,
      name: (data['name'] as String?) ?? doc.id,
      category: (data['category'] as String?) ?? 'tourisme',
      defaultStyle: Map<String, dynamic>.from(
        (data['defaultStyle'] as Map?) ?? const <String, dynamic>{},
      ),
      defaultLayers: ((data['defaultLayers'] as List?) ?? const <dynamic>[])
          .map((e) => Map<String, dynamic>.from((e as Map?) ?? const <String, dynamic>{}))
          .toList(),
      defaultChecklist: List<dynamic>.from(
        (data['defaultChecklist'] as List?) ?? const <dynamic>[],
      ),
      isGlobal: (data['isGlobal'] as bool?) ?? false,
      createdBy: data['createdBy'] as String?,
    );
  }
}

class CircuitRepository {
  static const int maxPoisPerProject = 2000;

  CircuitRepository({
    FirebaseFirestore? firestore,
    AuditLogger? auditLogger,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _audit = auditLogger ?? AuditLogger(firestore: firestore);

  final FirebaseFirestore _firestore;
  final AuditLogger _audit;

  CollectionReference<Map<String, dynamic>> get _projects =>
      _firestore.collection('map_projects');

  String createProjectId() => _projects.doc().id;

  Future<DocumentSnapshot<Map<String, dynamic>>> getProject(String projectId) {
    return _projects.doc(projectId).get();
  }

  Future<Map<String, dynamic>?> loadProjectCurrent({
    required String projectId,
    String? fallbackCountryId,
    String? fallbackEventId,
    String? fallbackCircuitId,
  }) async {
    final projectSnap = await _projects.doc(projectId).get();
    if (projectSnap.exists) {
      final data = projectSnap.data() ?? <String, dynamic>{};
      final current = data['current'];
      if (current is Map) {
        return {
          ...Map<String, dynamic>.from(current),
          'status': data['status'] ?? 'draft',
          'version': data['version'] ?? 1,
          'activeDraftId': data['activeDraftId'],
          'sourceOfTruth': data['sourceOfTruth'] ?? 'map_projects',
          'published': data['published'],
        };
      }
      return data;
    }

    if (fallbackCountryId == null || fallbackEventId == null || fallbackCircuitId == null) {
      return null;
    }

    final marketSnap = await _firestore
        .collection('marketMap')
        .doc(fallbackCountryId)
        .collection('events')
        .doc(fallbackEventId)
        .collection('circuits')
        .doc(fallbackCircuitId)
        .get();

    if (!marketSnap.exists) return null;
    final market = marketSnap.data() ?? <String, dynamic>{};
    return {
      'name': market['name'] ?? fallbackCircuitId,
      'countryId': fallbackCountryId,
      'eventId': fallbackEventId,
      'route': List<dynamic>.from((market['route'] as List?) ?? const <dynamic>[]),
      'perimeter':
          List<dynamic>.from((market['perimeter'] as List?) ?? const <dynamic>[]),
      'routeStyle': Map<String, dynamic>.from(
        (market['style'] as Map?) ?? const <String, dynamic>{},
      ),
      'status': 'published',
      'sourceOfTruth': 'map_projects',
    };
  }

  Future<void> saveDraft({
    required String projectId,
    required String actorUid,
    required String actorRole,
    required String groupId,
    required Map<String, dynamic> currentData,
    required List<MarketMapLayer> layers,
    required List<MarketMapPOI> pois,
    required int previousRouteCount,
    required int previousPoiCount,
    bool isNew = false,
  }) async {
    if (pois.length > maxPoisPerProject) {
      throw StateError('Limite POI dépassée: $maxPoisPerProject maximum par projet');
    }

    final projectRef = _projects.doc(projectId);
    final batch = _firestore.batch();
    final now = FieldValue.serverTimestamp();

    final existingSnap = await projectRef.get();
    final existing = existingSnap.data() ?? <String, dynamic>{};
    final existingCurrent = Map<String, dynamic>.from(
      (existing['current'] as Map?) ?? const <String, dynamic>{},
    );
    final nextVersion = ((existing['version'] as num?)?.toInt() ?? 0).clamp(0, 1 << 30);
    final isCreate = isNew || !existingSnap.exists;

    final routeDelta =
        ((currentData['route'] as List?)?.length ?? 0) - previousRouteCount;
    final poiDelta = pois.length - previousPoiCount;
    final perimeterChanged =
        ((existingCurrent['perimeter'] as List?)?.toString() ?? '[]') !=
            ((currentData['perimeter'] as List?)?.toString() ?? '[]');
    final oldStyle = Map<String, dynamic>.from(
      (existingCurrent['routeStyle'] as Map?) ?? const <String, dynamic>{},
    );
    final newStyle = Map<String, dynamic>.from(
      (currentData['routeStyle'] as Map?) ?? const <String, dynamic>{},
    );
    final styleChangedKeys = <String>{...oldStyle.keys, ...newStyle.keys}
        .where((k) => oldStyle[k].toString() != newStyle[k].toString())
        .toList()
      ..sort();

    final payload = <String, dynamic>{
      'groupId': groupId,
      'createdBy': existing['createdBy'] ?? actorUid,
      'status': existing['status'] ?? 'draft',
      'sourceOfTruth': 'map_projects',
      'version': nextVersion == 0 ? 1 : nextVersion,
      'updatedAt': now,
      'current': currentData,

      // Compat legacy
      'name': currentData['name'],
      'countryId': currentData['countryId'],
      'eventId': currentData['eventId'],
      'description': currentData['description'],
      'styleUrl': currentData['styleUrl'],
      'route': currentData['route'],
      'perimeter': currentData['perimeter'],
      'routeStyle': currentData['routeStyle'],
      'uid': actorUid,
    };
    if (isCreate) {
      payload['createdAt'] = now;
    }

    batch.set(projectRef, payload, SetOptions(merge: true));

    if (isCreate) {
      _audit.writeInBatch(
        batch: batch,
        actorUid: actorUid,
        actorRole: actorRole,
        action: 'create_project',
        target: AuditTarget(projectId: projectId, groupId: groupId),
      );
    }

    if (!isCreate && routeDelta != 0) {
      _audit.writeInBatch(
        batch: batch,
        actorUid: actorUid,
        actorRole: actorRole,
        action: 'update_route',
        target: AuditTarget(projectId: projectId, groupId: groupId),
        diffSummary: AuditDiffSummary(routePointsDelta: routeDelta),
      );
    }

    if (!isCreate && poiDelta != 0) {
      _audit.writeInBatch(
        batch: batch,
        actorUid: actorUid,
        actorRole: actorRole,
        action: 'update_pois',
        target: AuditTarget(projectId: projectId, groupId: groupId),
        diffSummary: AuditDiffSummary(poiDelta: poiDelta),
      );
    }

    if (!isCreate && styleChangedKeys.isNotEmpty) {
      _audit.writeInBatch(
        batch: batch,
        actorUid: actorUid,
        actorRole: actorRole,
        action: 'update_style',
        target: AuditTarget(projectId: projectId, groupId: groupId),
        diffSummary: AuditDiffSummary(styleChangedKeys: styleChangedKeys),
      );
    }

    await _syncLayersBatch(batch: batch, projectId: projectId, layers: layers);
    await _syncPoisBatch(batch: batch, projectId: projectId, pois: pois);

    _audit.writeInBatch(
      batch: batch,
      actorUid: actorUid,
      actorRole: actorRole,
      action: 'save_draft',
      target: AuditTarget(projectId: projectId, groupId: groupId),
      diffSummary: AuditDiffSummary(
        routePointsDelta: routeDelta,
        poiDelta: poiDelta,
        perimeterChanged: perimeterChanged,
        styleChangedKeys: styleChangedKeys,
      ),
    );

    await batch.commit();
  }

  Future<void> publishToMarketMap({
    required String projectId,
    required String actorUid,
    required String actorRole,
    required String groupId,
    required String countryId,
    required String eventId,
    required String marketCircuitId,
    required Map<String, dynamic> currentData,
    required List<MarketMapLayer> layers,
    required List<MarketMapPOI> pois,
  }) async {
    final db = _firestore;
    final now = FieldValue.serverTimestamp();

    final projectRef = _projects.doc(projectId);
    final countryRef = db.collection('marketMap').doc(countryId);
    final eventRef = countryRef.collection('events').doc(eventId);
    final circuitRef = eventRef.collection('circuits').doc(marketCircuitId);
    final marketMapPath =
        'marketMap/$countryId/events/$eventId/circuits/$marketCircuitId';

    final projectSnap = await projectRef.get();
    final projectData = projectSnap.data() ?? <String, dynamic>{};
    final version = ((projectData['version'] as num?)?.toInt() ?? 1) + 1;

    final batch = db.batch();
    batch.set(countryRef, {
      'name': countryId,
      'slug': countryId,
      'updatedAt': now,
      if (!(await countryRef.get()).exists) 'createdAt': now,
    }, SetOptions(merge: true));

    batch.set(eventRef, {
      'name': eventId,
      'slug': eventId,
      'countryId': countryId,
      'updatedAt': now,
      if (!(await eventRef.get()).exists) 'createdAt': now,
    }, SetOptions(merge: true));

    batch.set(circuitRef, {
      'name': currentData['name'] ?? marketCircuitId,
      'slug': _slugify((currentData['name'] ?? marketCircuitId).toString()),
      'status': 'published',
      'countryId': countryId,
      'eventId': eventId,
      'createdByUid': actorUid,
      'isVisible': true,
      'sourceProjectId': projectId,
      'publishedVersion': version,
      'publishedAt': now,
      'updatedAt': now,
      'route': currentData['route'] ?? const <dynamic>[],
      'perimeter': currentData['perimeter'] ?? const <dynamic>[],
      'style': currentData['routeStyle'] ?? const <String, dynamic>{},
      // C4: source-of-truth = sous-collections `layers/pois`.
      // On supprime les arrays redondants pour éliminer le risque de divergence.
      'layers': FieldValue.delete(),
      'pois': FieldValue.delete(),
      'layersSummary': {'count': layers.length},
      'poisSummary': {'count': pois.length},
    }, SetOptions(merge: true));

    await _syncMarketLayersBatch(
      batch: batch,
      countryId: countryId,
      eventId: eventId,
      circuitId: marketCircuitId,
      layers: layers,
    );
    await _syncMarketPoisBatch(
      batch: batch,
      countryId: countryId,
      eventId: eventId,
      circuitId: marketCircuitId,
      pois: pois,
      actorUid: actorUid,
    );

    batch.set(projectRef, {
      'status': 'published',
      'version': version,
      'sourceOfTruth': 'map_projects',
      'publishedRef': marketMapPath,
      'published': {
        'marketMapPath': marketMapPath,
        'publishedAt': now,
        'publishedBy': actorUid,
        'publishedVersion': version,
      },
      'publishedAt': now,
      'updatedAt': now,
      'isVisible': true,
      'circuitId': marketCircuitId,
    }, SetOptions(merge: true));

    _audit.writeInBatch(
      batch: batch,
      actorUid: actorUid,
      actorRole: actorRole,
      action: 'publish',
      target: AuditTarget(
        projectId: projectId,
        groupId: groupId,
        marketMapPath: marketMapPath,
      ),
    );

    await batch.commit();
  }

  Future<void> createDraftSnapshot({
    required String projectId,
    required String actorUid,
    required String actorRole,
    required String groupId,
    required Map<String, dynamic> currentData,
    required List<MarketMapLayer> layers,
    required List<MarketMapPOI> pois,
  }) async {
    final projectRef = _projects.doc(projectId);
    final project = await projectRef.get();
    final projectData = project.data() ?? <String, dynamic>{};

    final lock = projectData['editLock'];
    if (lock is Map) {
      final expires = lock['expiresAt'];
      if (expires is Timestamp && expires.toDate().isAfter(DateTime.now())) {
        throw StateError('Projet verrouillé: restauration/publication en cours');
      }
    }

    final version = ((projectData['version'] as num?)?.toInt() ?? 0) + 1;
    final draftsCol = projectRef.collection('drafts');
    final draftRef = draftsCol.doc();
    final now = FieldValue.serverTimestamp();
    final batch = _firestore.batch();

    batch.set(draftRef, {
      'version': version,
      'createdAt': now,
      'createdBy': actorUid,
      'dataSnapshot': {
        ...currentData,
        'layers': layers.map((l) => l.toFirestore()).toList(),
        'pois': pois.map((p) => p.toFirestore()).toList(),
        'poisSummary': {'count': pois.length},
        'stats': {
          'routePoints': (currentData['route'] as List?)?.length ?? 0,
          'perimeterPoints': (currentData['perimeter'] as List?)?.length ?? 0,
        },
      },
    });

    batch.set(projectRef, {
      'version': version,
      'activeDraftId': draftRef.id,
      'updatedAt': now,
    }, SetOptions(merge: true));

    _audit.writeInBatch(
      batch: batch,
      actorUid: actorUid,
      actorRole: actorRole,
      action: 'save_draft',
      target: AuditTarget(projectId: projectId, groupId: groupId, draftId: draftRef.id),
    );

    await batch.commit();
  }

  Future<List<CircuitDraftVersion>> listDrafts({
    required String projectId,
    int pageSize = 20,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
  }) async {
    Query<Map<String, dynamic>> query = _projects
        .doc(projectId)
        .collection('drafts')
        .orderBy('createdAt', descending: true)
        .limit(pageSize);

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    final snap = await query.get();
    return snap.docs.map((doc) {
      final data = doc.data();
      return CircuitDraftVersion(
        id: doc.id,
        version: (data['version'] as num?)?.toInt() ?? 0,
        createdBy: data['createdBy'] as String?,
        createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      );
    }).toList();
  }

  Future<void> restoreDraft({
    required String projectId,
    required String draftId,
    required String actorUid,
    required String actorRole,
    required String groupId,
  }) async {
    final projectRef = _projects.doc(projectId);
    final draftRef = projectRef.collection('drafts').doc(draftId);
    final now = FieldValue.serverTimestamp();

    final projectSnap = await projectRef.get();
    final projectData = projectSnap.data() ?? <String, dynamic>{};

    final lock = projectData['editLock'];
    if (lock is Map) {
      final expires = lock['expiresAt'];
      if (expires is Timestamp && expires.toDate().isAfter(DateTime.now())) {
        throw StateError('Projet verrouillé: restauration impossible');
      }
    }

    final draftSnap = await draftRef.get();
    if (!draftSnap.exists) {
      throw StateError('Draft introuvable');
    }
    final draftData = draftSnap.data() ?? <String, dynamic>{};
    final dataSnapshot =
        Map<String, dynamic>.from((draftData['dataSnapshot'] as Map?) ?? const <String, dynamic>{});

    final batch = _firestore.batch();
    batch.set(projectRef, {
      'current': dataSnapshot,
      'activeDraftId': draftId,
      'version': (draftData['version'] as num?)?.toInt() ?? projectData['version'] ?? 1,
      'updatedAt': now,
      'name': dataSnapshot['name'],
      'description': dataSnapshot['description'],
      'countryId': dataSnapshot['countryId'],
      'eventId': dataSnapshot['eventId'],
      'route': dataSnapshot['route'],
      'perimeter': dataSnapshot['perimeter'],
      'routeStyle': dataSnapshot['routeStyle'],
    }, SetOptions(merge: true));

    _audit.writeInBatch(
      batch: batch,
      actorUid: actorUid,
      actorRole: actorRole,
      action: 'restore_draft',
      target: AuditTarget(projectId: projectId, groupId: groupId, draftId: draftId),
    );
    await batch.commit();
  }

  Future<List<CircuitTemplate>> listTemplates({required String actorUid}) async {
    final snap = await _firestore
        .collection('circuit_templates')
        .where('isGlobal', isEqualTo: true)
        .get();
    final own = await _firestore
        .collection('circuit_templates')
        .where('createdBy', isEqualTo: actorUid)
        .get();

    final map = <String, CircuitTemplate>{};
    for (final doc in [...snap.docs, ...own.docs]) {
      map[doc.id] = CircuitTemplate.fromDoc(doc);
    }
    return map.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  Future<Map<String, dynamic>> createProjectFromTemplate({
    required CircuitTemplate template,
    required String groupId,
    required String actorUid,
    String? projectId,
  }) async {
    final id = projectId ?? createProjectId();
    final now = FieldValue.serverTimestamp();
    final current = <String, dynamic>{
      'name': template.name,
      'description': 'Projet créé depuis le template ${template.name}',
      'countryId': '',
      'eventId': '',
      'route': const <dynamic>[],
      'perimeter': const <dynamic>[],
      'routeStyle': template.defaultStyle,
      'templateId': template.id,
      'templateCategory': template.category,
      'checklist': template.defaultChecklist,
    };

    await _projects.doc(id).set({
      'groupId': groupId,
      'createdBy': actorUid,
      'uid': actorUid,
      'status': 'draft',
      'sourceOfTruth': 'map_projects',
      'version': 1,
      'createdAt': now,
      'updatedAt': now,
      'current': current,
      'name': current['name'],
      'description': current['description'],
      'countryId': current['countryId'],
      'eventId': current['eventId'],
      'route': current['route'],
      'perimeter': current['perimeter'],
      'routeStyle': current['routeStyle'],
    }, SetOptions(merge: true));

    final layers = template.defaultLayers.asMap().entries.map((entry) {
      final e = entry.value;
      return MarketMapLayer(
        id: (e['id'] as String?) ?? 'tpl_${entry.key + 1}',
        label: (e['label'] as String?) ?? 'Layer ${entry.key + 1}',
        type: (e['type'] as String?) ?? 'tour',
        isVisible: (e['isVisible'] as bool?) ?? true,
        zIndex: (e['zIndex'] as num?)?.toInt() ?? entry.key,
        color: e['color'] as String?,
        icon: e['icon'] as String?,
      );
    }).toList();

    final batch = _firestore.batch();
    await _syncLayersBatch(batch: batch, projectId: id, layers: layers);
    await batch.commit();

    return {'projectId': id, 'current': current};
  }

  Future<QuerySnapshot<Map<String, dynamic>>> listPoisPage({
    required String projectId,
    int pageSize = 100,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
  }) {
    Query<Map<String, dynamic>> query = _projects
        .doc(projectId)
        .collection('pois')
        .orderBy('name')
        .limit(pageSize);
    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }
    return query.get();
  }

  Future<void> _syncLayersBatch({
    required WriteBatch batch,
    required String projectId,
    required List<MarketMapLayer> layers,
  }) async {
    final col = _projects.doc(projectId).collection('layers');
    final snap = await col.get();
    final existing = {for (final d in snap.docs) d.id: d};
    final incomingIds = <String>{};

    for (final layer in layers) {
      final id = layer.id.trim().isEmpty ? 'layer_${layer.zIndex}' : layer.id.trim();
      incomingIds.add(id);
      final data = layer.toFirestore();
      final ref = col.doc(id);
      final old = existing[id]?.data();
      if (!_mapsShallowEqual(old, data)) {
        batch.set(ref, data, SetOptions(merge: true));
      }
    }

    for (final doc in snap.docs) {
      if (!incomingIds.contains(doc.id)) {
        batch.delete(doc.reference);
      }
    }
  }

  Future<void> _syncPoisBatch({
    required WriteBatch batch,
    required String projectId,
    required List<MarketMapPOI> pois,
  }) async {
    final col = _projects.doc(projectId).collection('pois');
    final snap = await col.get();
    final existing = {for (final d in snap.docs) d.id: d};
    final incomingIds = <String>{};

    for (final poi in pois) {
      final id = poi.id.trim().isEmpty
          ? 'poi_${poi.layerType}_${poi.lng.toStringAsFixed(5)}_${poi.lat.toStringAsFixed(5)}'
          : poi.id.trim();
      incomingIds.add(id);
      final data = {
        ...poi.toFirestore(),
        'layerId': poi.layerType,
        'isVisible': true,
      };
      final ref = col.doc(id);
      final old = existing[id]?.data();
      if (!_mapsShallowEqual(old, data)) {
        batch.set(ref, data, SetOptions(merge: true));
      }
    }

    for (final doc in snap.docs) {
      if (!incomingIds.contains(doc.id)) {
        batch.delete(doc.reference);
      }
    }
  }

  Future<void> _syncMarketLayersBatch({
    required WriteBatch batch,
    required String countryId,
    required String eventId,
    required String circuitId,
    required List<MarketMapLayer> layers,
  }) async {
    final col = _firestore
        .collection('marketMap')
        .doc(countryId)
        .collection('events')
        .doc(eventId)
        .collection('circuits')
        .doc(circuitId)
        .collection('layers');
    final snap = await col.get();
    final existingIds = snap.docs.map((d) => d.id).toSet();
    final incomingIds = <String>{};

    for (final layer in layers) {
      // IMPORTANT: dans `marketMap`, le docId de layer doit matcher le `layerId`
      // des POIs (sinon les filtres Mapbox par couche ne trouvent rien).
      // On privilégie donc `layer.type` comme identifiant stable.
      final id = _marketLayerId(layer);
      incomingIds.add(id);
      final data = {
        'type': layer.type,
        'label': layer.label,
        'isEnabled': layer.isVisible,
        'isVisible': layer.isVisible,
        'order': layer.zIndex,
        'zIndex': layer.zIndex,
        // Compat viewer: certains écrans lisent `color/icon` au top-level.
        if (layer.color != null) 'color': layer.color,
        if (layer.icon != null) 'icon': layer.icon,
        'style': {
          if (layer.color != null) 'color': layer.color,
          if (layer.icon != null) 'icon': layer.icon,
        },
        'params': const {'showLabels': true},
        'updatedAt': FieldValue.serverTimestamp(),
      };
      batch.set(col.doc(id), data, SetOptions(merge: true));
    }

    for (final oldId in existingIds.difference(incomingIds)) {
      batch.delete(col.doc(oldId));
    }
  }

  Future<void> _syncMarketPoisBatch({
    required WriteBatch batch,
    required String countryId,
    required String eventId,
    required String circuitId,
    required List<MarketMapPOI> pois,
    required String actorUid,
  }) async {
    final col = _firestore
        .collection('marketMap')
        .doc(countryId)
        .collection('events')
        .doc(eventId)
        .collection('circuits')
        .doc(circuitId)
        .collection('pois');
    final snap = await col.get();
    final existingIds = snap.docs.map((d) => d.id).toSet();
    final incomingIds = <String>{};

    for (final poi in pois) {
      final id = _marketPoiId(poi);
      incomingIds.add(id);

      String? metaString(String key) {
        final m = poi.metadata;
        if (m == null) return null;
        final v = m[key];
        return v is String ? v : null;
      }

      final instagram = (poi.instagram ?? metaString('instagram') ?? metaString('ig'))?.trim();
      final facebook = (poi.facebook ?? metaString('facebook') ?? metaString('fb'))?.trim();

      batch.set(col.doc(id), {
        'name': poi.name,
        'description': poi.description,
        'type': poi.layerType,
        'layerId': poi.layerType,
        'lat': poi.lat,
        'lng': poi.lng,
        'isVisible': true,
        if (instagram != null && instagram.isNotEmpty) 'instagram': instagram,
        if (facebook != null && facebook.isNotEmpty) 'facebook': facebook,
        'createdByUid': actorUid,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    for (final oldId in existingIds.difference(incomingIds)) {
      batch.delete(col.doc(oldId));
    }
  }

  bool _mapsShallowEqual(Map<String, dynamic>? a, Map<String, dynamic>? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (!b.containsKey(key)) return false;
      if (a[key].toString() != b[key].toString()) return false;
    }
    return true;
  }

  String _slugify(String value) {
    final normalized = value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
    return normalized.isEmpty ? 'circuit' : normalized;
  }

  String _marketLayerId(MarketMapLayer layer) {
    final normalizedType = layer.type.trim();
    final normalizedId = layer.id.trim();
    // On privilégie `type` comme identifiant stable.
    return normalizedType.isNotEmpty ? normalizedType : normalizedId;
  }

  String _marketPoiId(MarketMapPOI poi) {
    final trimmed = poi.id.trim();
    if (trimmed.isNotEmpty) return trimmed;
    return 'poi_${poi.layerType}_${poi.lng.toStringAsFixed(5)}_${poi.lat.toStringAsFixed(5)}';
  }
}
