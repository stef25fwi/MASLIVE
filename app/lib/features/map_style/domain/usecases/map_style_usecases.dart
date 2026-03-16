import '../entities/map_style_preset.dart';
import '../repositories/map_style_preset_repository.dart';

class WatchMapStylePresetsUseCase {
  const WatchMapStylePresetsUseCase(this.repository);
  final MapStylePresetRepository repository;

  Stream<List<MapStylePreset>> call({String? orgId}) {
    return repository.watchAllPresets(orgId: orgId);
  }
}

class WatchWizardQuickMapStylePresetsUseCase {
  const WatchWizardQuickMapStylePresetsUseCase(this.repository);
  final MapStylePresetRepository repository;

  Stream<List<MapStylePreset>> call({String? orgId}) {
    return repository.watchWizardQuickPresets(orgId: orgId);
  }
}

class GetMapStylePresetsUseCase {
  const GetMapStylePresetsUseCase(this.repository);
  final MapStylePresetRepository repository;

  Future<List<MapStylePreset>> call({String? orgId}) {
    return repository.getAllPresets(orgId: orgId);
  }
}

class CreateMapStylePresetUseCase {
  const CreateMapStylePresetUseCase(this.repository);
  final MapStylePresetRepository repository;

  Future<MapStylePreset> call(MapStylePreset preset) {
    return repository.createPreset(preset);
  }
}

class UpdateMapStylePresetUseCase {
  const UpdateMapStylePresetUseCase(this.repository);
  final MapStylePresetRepository repository;

  Future<MapStylePreset> call(MapStylePreset preset) {
    return repository.updatePreset(preset);
  }
}

class PublishMapStylePresetUseCase {
  const PublishMapStylePresetUseCase(this.repository);
  final MapStylePresetRepository repository;

  Future<void> call(String presetId) {
    return repository.publishPreset(presetId);
  }
}

class ArchiveMapStylePresetUseCase {
  const ArchiveMapStylePresetUseCase(this.repository);
  final MapStylePresetRepository repository;

  Future<void> call(String presetId) {
    return repository.archivePreset(presetId);
  }
}

class DeleteMapStylePresetUseCase {
  const DeleteMapStylePresetUseCase(this.repository);
  final MapStylePresetRepository repository;

  Future<void> call(String presetId) {
    return repository.deletePreset(presetId);
  }
}

class DuplicateMapStylePresetUseCase {
  const DuplicateMapStylePresetUseCase(this.repository);
  final MapStylePresetRepository repository;

  Future<MapStylePreset> call(String presetId) {
    return repository.duplicatePreset(presetId);
  }
}

class SetDefaultMapStylePresetUseCase {
  const SetDefaultMapStylePresetUseCase(this.repository);
  final MapStylePresetRepository repository;

  Future<void> call(String presetId, {required String orgId}) {
    return repository.setDefaultPreset(presetId, orgId: orgId);
  }
}
