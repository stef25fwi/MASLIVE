import '../entities/map_style_preset.dart';

abstract class MapStylePresetRepository {
  Stream<List<MapStylePreset>> watchAllPresets({String? orgId});

  Stream<List<MapStylePreset>> watchWizardQuickPresets({String? orgId});

  Future<List<MapStylePreset>> getAllPresets({String? orgId});

  Future<List<MapStylePreset>> getWizardQuickPresets({String? orgId});

  Future<MapStylePreset?> getPresetById(String id);

  Future<MapStylePreset> createPreset(MapStylePreset preset);

  Future<MapStylePreset> updatePreset(MapStylePreset preset);

  Future<void> publishPreset(String presetId);

  Future<void> archivePreset(String presetId);

  Future<void> deletePreset(String presetId);

  Future<MapStylePreset> duplicatePreset(String presetId);

  Future<void> setDefaultPreset(String presetId, {required String orgId});
}
