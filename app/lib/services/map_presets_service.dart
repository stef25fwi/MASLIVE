import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/map_preset_model.dart';

/// Service pour gérer les cartes pré-enregistrées stockées dans Firestore
class MapPresetsService {
  static const String _collection = 'map_presets';
  final FirebaseFirestore _firestore;

  MapPresetsService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Stream pour récupérer toutes les cartes d'un groupe
  Stream<List<MapPresetModel>> getGroupPresetsStream(String groupId) {
    return _firestore
        .collection(_collection)
        .where('groupId', isEqualTo: groupId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => MapPresetModel.fromDoc(doc))
              .toList();
        });
  }

  /// Récupère toutes les cartes publiques d'un groupe
  Stream<List<MapPresetModel>> getPublicPresetsStream(String groupId) {
    return _firestore
        .collection(_collection)
        .where('groupId', isEqualTo: groupId)
        .where('isPublic', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => MapPresetModel.fromDoc(doc))
              .toList();
        });
  }

  /// Récupère une carte par son ID
  Future<MapPresetModel?> getPreset(String presetId) async {
    try {
      final doc = await _firestore.collection(_collection).doc(presetId).get();
      if (doc.exists) {
        return MapPresetModel.fromDoc(doc);
      }
      return null;
    } catch (e) {
      print('Erreur lors de la récupération de la carte: $e');
      return null;
    }
  }

  /// Crée une nouvelle carte pré-enregistrée
  Future<String> createPreset(MapPresetModel preset) async {
    try {
      final docRef = await _firestore
          .collection(_collection)
          .add(preset.toMap());
      return docRef.id;
    } catch (e) {
      print('Erreur lors de la création de la carte: $e');
      rethrow;
    }
  }

  /// Met à jour une carte existante
  Future<void> updatePreset(MapPresetModel preset) async {
    try {
      await _firestore
          .collection(_collection)
          .doc(preset.id)
          .update(preset.copyWith(updatedAt: DateTime.now()).toMap());
    } catch (e) {
      print('Erreur lors de la mise à jour de la carte: $e');
      rethrow;
    }
  }

  /// Met à jour la visibilité d'une couche dans une carte
  Future<void> updateLayerVisibility(
    String presetId,
    String layerId,
    bool visible,
  ) async {
    try {
      final preset = await getPreset(presetId);
      if (preset == null) return;

      final layer = preset.getLayer(layerId);
      if (layer == null) return;

      final updatedPreset = preset.withLayer(layer.copyWith(visible: visible));
      await updatePreset(updatedPreset);
    } catch (e) {
      print('Erreur lors de la mise à jour de la visibilité: $e');
      rethrow;
    }
  }

  /// Ajoute une couche à une carte
  Future<void> addLayer(String presetId, LayerModel layer) async {
    try {
      final preset = await getPreset(presetId);
      if (preset == null) return;

      final updatedPreset = preset.withLayer(layer);
      await updatePreset(updatedPreset);
    } catch (e) {
      print('Erreur lors de l\'ajout de la couche: $e');
      rethrow;
    }
  }

  /// Supprime une couche d'une carte
  Future<void> removeLayer(String presetId, String layerId) async {
    try {
      final preset = await getPreset(presetId);
      if (preset == null) return;

      final updatedPreset = preset.withoutLayer(layerId);
      await updatePreset(updatedPreset);
    } catch (e) {
      print('Erreur lors de la suppression de la couche: $e');
      rethrow;
    }
  }

  /// Supprime une carte complète
  Future<void> deletePreset(String presetId) async {
    try {
      await _firestore.collection(_collection).doc(presetId).delete();
    } catch (e) {
      print('Erreur lors de la suppression de la carte: $e');
      rethrow;
    }
  }

  /// Duplique une carte existante
  Future<String> duplicatePreset(MapPresetModel preset) async {
    try {
      final newPreset = preset.copyWith(
        id: '', // Sera généré par Firestore
        title: '${preset.title} (copie)',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      return await createPreset(newPreset);
    } catch (e) {
      print('Erreur lors de la duplication de la carte: $e');
      rethrow;
    }
  }
}
