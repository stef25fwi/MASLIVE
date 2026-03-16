import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/map_style_enums.dart';
import '../../utils/map_style_defaults.dart';
import '../models/map_style_preset_model.dart';

class MapStyleFirestoreDatasource {
  MapStyleFirestoreDatasource({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection {
    return _firestore.collection(MapStyleDefaults.collection);
  }

  Query<Map<String, dynamic>> _baseQuery({String? orgId}) {
    Query<Map<String, dynamic>> query = _collection;
    if (orgId != null && orgId.trim().isNotEmpty) {
      query = query.where('orgId', isEqualTo: orgId.trim());
    }
    return query;
  }

  Stream<List<MapStylePresetModel>> watchAllPresets({String? orgId}) {
    return _baseQuery(orgId: orgId)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(MapStylePresetModel.fromDocument).toList(growable: false));
  }

  Stream<List<MapStylePresetModel>> watchWizardQuickPresets({String? orgId}) {
    return _baseQuery(orgId: orgId)
        .where('status', isEqualTo: MapStyleStatus.published.name)
        .where('visibleInWizard', isEqualTo: true)
        .where('isQuickPreset', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
          final list = snapshot.docs.map(MapStylePresetModel.fromDocument).toList(growable: false);
          list.sort((a, b) {
            if (a.isDefault && !b.isDefault) return -1;
            if (!a.isDefault && b.isDefault) return 1;
            return b.updatedAt.compareTo(a.updatedAt);
          });
          return list;
        });
  }

  Future<List<MapStylePresetModel>> getAllPresets({String? orgId}) async {
    final snapshot = await _baseQuery(orgId: orgId).orderBy('updatedAt', descending: true).get();
    return snapshot.docs.map(MapStylePresetModel.fromDocument).toList(growable: false);
  }

  Future<List<MapStylePresetModel>> getWizardQuickPresets({String? orgId}) async {
    final snapshot = await _baseQuery(orgId: orgId)
        .where('status', isEqualTo: MapStyleStatus.published.name)
        .where('visibleInWizard', isEqualTo: true)
        .where('isQuickPreset', isEqualTo: true)
        .get();
    final list = snapshot.docs.map(MapStylePresetModel.fromDocument).toList(growable: false);
    list.sort((a, b) {
      if (a.isDefault && !b.isDefault) return -1;
      if (!a.isDefault && b.isDefault) return 1;
      return b.updatedAt.compareTo(a.updatedAt);
    });
    return list;
  }

  Future<MapStylePresetModel?> getPresetById(String id) async {
    final document = await _collection.doc(id).get();
    if (!document.exists) return null;
    return MapStylePresetModel.fromDocument(document);
  }

  Future<MapStylePresetModel> createPreset(MapStylePresetModel model) async {
    final docRef = model.id.trim().isEmpty ? _collection.doc() : _collection.doc(model.id.trim());
    final now = DateTime.now();
    final payload = model
        .copyWith(id: docRef.id, createdAt: now, updatedAt: now)
        .toMap();
    await docRef.set(payload, SetOptions(merge: false));
    final saved = await docRef.get();
    return MapStylePresetModel.fromDocument(saved);
  }

  Future<MapStylePresetModel> updatePreset(MapStylePresetModel model) async {
    final ref = _collection.doc(model.id);
    final payload = model.copyWith(updatedAt: DateTime.now()).toMap();
    await ref.set(payload, SetOptions(merge: true));
    final saved = await ref.get();
    return MapStylePresetModel.fromDocument(saved);
  }

  Future<void> publishPreset(String presetId) async {
    final now = DateTime.now();
    await _collection.doc(presetId).set(<String, dynamic>{
      'status': MapStyleStatus.published.name,
      'publishedAt': Timestamp.fromDate(now),
      'archivedAt': null,
      'updatedAt': Timestamp.fromDate(now),
    }, SetOptions(merge: true));
  }

  Future<void> archivePreset(String presetId) async {
    final now = DateTime.now();
    await _collection.doc(presetId).set(<String, dynamic>{
      'status': MapStyleStatus.archived.name,
      'visibleInWizard': false,
      'isQuickPreset': false,
      'isDefault': false,
      'archivedAt': Timestamp.fromDate(now),
      'updatedAt': Timestamp.fromDate(now),
    }, SetOptions(merge: true));
  }

  Future<void> deletePreset(String presetId) async {
    await _collection.doc(presetId).delete();
  }

  Future<MapStylePresetModel> duplicatePreset(String presetId) async {
    final source = await getPresetById(presetId);
    if (source == null) {
      throw StateError('Preset introuvable');
    }
    final now = DateTime.now();
    final duplicate = source.copyWith(
      id: '',
      name: '${source.name} copy',
      status: MapStyleStatus.draft,
      isDefault: false,
      visibleInWizard: false,
      isQuickPreset: false,
      usageCount: 0,
      referencesCount: 0,
      createdAt: now,
      updatedAt: now,
      publishedAt: null,
      archivedAt: null,
    );
    return createPreset(duplicate);
  }

  Future<void> setDefaultPreset(String presetId, {required String orgId}) async {
    final query = await _baseQuery(orgId: orgId).where('isDefault', isEqualTo: true).get();
    final batch = _firestore.batch();
    for (final doc in query.docs) {
      if (doc.id == presetId) continue;
      batch.set(doc.reference, <String, dynamic>{'isDefault': false, 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
    }
    batch.set(_collection.doc(presetId), <String, dynamic>{'isDefault': true, 'status': MapStyleStatus.published.name, 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
    await batch.commit();
  }
}
