import '../../domain/entities/map_style_preset.dart';
import '../../domain/repositories/map_style_preset_repository.dart';
import '../datasources/map_style_firestore_datasource.dart';
import '../models/map_style_preset_model.dart';

class MapStylePresetRepositoryImpl implements MapStylePresetRepository {
  MapStylePresetRepositoryImpl({MapStyleFirestoreDatasource? datasource})
    : _datasource = datasource ?? MapStyleFirestoreDatasource();

  final MapStyleFirestoreDatasource _datasource;

  @override
  Stream<List<MapStylePreset>> watchAllPresets({String? orgId}) {
    return _datasource
        .watchAllPresets(orgId: orgId)
        .map((items) => items.map((item) => item.toEntity()).toList(growable: false));
  }

  @override
  Stream<List<MapStylePreset>> watchWizardQuickPresets({String? orgId}) {
    return _datasource
        .watchWizardQuickPresets(orgId: orgId)
        .map((items) => items.map((item) => item.toEntity()).toList(growable: false));
  }

  @override
  Future<List<MapStylePreset>> getAllPresets({String? orgId}) async {
    final items = await _datasource.getAllPresets(orgId: orgId);
    return items.map((item) => item.toEntity()).toList(growable: false);
  }

  @override
  Future<List<MapStylePreset>> getWizardQuickPresets({String? orgId}) async {
    final items = await _datasource.getWizardQuickPresets(orgId: orgId);
    return items.map((item) => item.toEntity()).toList(growable: false);
  }

  @override
  Future<MapStylePreset?> getPresetById(String id) async {
    final model = await _datasource.getPresetById(id);
    return model?.toEntity();
  }

  @override
  Future<MapStylePreset> createPreset(MapStylePreset preset) async {
    final model = MapStylePresetModel.fromEntity(preset);
    final created = await _datasource.createPreset(model);
    return created.toEntity();
  }

  @override
  Future<MapStylePreset> updatePreset(MapStylePreset preset) async {
    final model = MapStylePresetModel.fromEntity(preset);
    final updated = await _datasource.updatePreset(model);
    return updated.toEntity();
  }

  @override
  Future<void> publishPreset(String presetId) {
    return _datasource.publishPreset(presetId);
  }

  @override
  Future<void> archivePreset(String presetId) {
    return _datasource.archivePreset(presetId);
  }

  @override
  Future<void> deletePreset(String presetId) async {
    final existing = await _datasource.getPresetById(presetId);
    if (existing == null) return;
    if (existing.referencesCount > 0) {
      throw StateError('Preset utilise par des cartes, suppression bloquee');
    }
    await _datasource.deletePreset(presetId);
  }

  @override
  Future<MapStylePreset> duplicatePreset(String presetId) async {
    final duplicated = await _datasource.duplicatePreset(presetId);
    return duplicated.toEntity();
  }

  @override
  Future<void> setDefaultPreset(String presetId, {required String orgId}) {
    return _datasource.setDefaultPreset(presetId, orgId: orgId);
  }
}
