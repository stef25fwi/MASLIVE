import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/repositories/map_style_preset_repository_impl.dart';
import '../../domain/entities/map_style_enums.dart';
import '../../domain/entities/map_style_preset.dart';
import '../../domain/repositories/map_style_preset_repository.dart';
import '../../domain/usecases/map_style_usecases.dart';

class MapStyleStudioStats {
  const MapStyleStudioStats({
    required this.total,
    required this.published,
    required this.wizardVisible,
    required this.lastUpdate,
  });

  final int total;
  final int published;
  final int wizardVisible;
  final DateTime? lastUpdate;
}

class MapStyleStudioController extends ChangeNotifier {
  MapStyleStudioController({MapStylePresetRepository? repository})
    : this._(repository ?? MapStylePresetRepositoryImpl());

  MapStyleStudioController._(this._repository)
    : _watchUseCase = WatchMapStylePresetsUseCase(_repository),
      _createUseCase = CreateMapStylePresetUseCase(_repository),
      _publishUseCase = PublishMapStylePresetUseCase(_repository),
      _archiveUseCase = ArchiveMapStylePresetUseCase(_repository),
      _deleteUseCase = DeleteMapStylePresetUseCase(_repository),
      _duplicateUseCase = DuplicateMapStylePresetUseCase(_repository),
      _setDefaultUseCase = SetDefaultMapStylePresetUseCase(_repository);

  final MapStylePresetRepository _repository;
  final WatchMapStylePresetsUseCase _watchUseCase;
  final CreateMapStylePresetUseCase _createUseCase;
  final PublishMapStylePresetUseCase _publishUseCase;
  final ArchiveMapStylePresetUseCase _archiveUseCase;
  final DeleteMapStylePresetUseCase _deleteUseCase;
  final DuplicateMapStylePresetUseCase _duplicateUseCase;
  final SetDefaultMapStylePresetUseCase _setDefaultUseCase;

  StreamSubscription<List<MapStylePreset>>? _subscription;

  bool loading = false;
  Object? error;
  String? orgId;
  List<MapStylePreset> presets = const <MapStylePreset>[];
  MapStylePreset? selectedPreset;

  MapStyleStudioStats get stats {
    final published = presets.where((item) => item.status == MapStyleStatus.published).length;
    final wizardVisible = presets.where((item) => item.status == MapStyleStatus.published && item.visibleInWizard).length;
    final last = presets.isEmpty
        ? null
        : presets.map((item) => item.updatedAt).reduce((a, b) => a.isAfter(b) ? a : b);
    return MapStyleStudioStats(
      total: presets.length,
      published: published,
      wizardVisible: wizardVisible,
      lastUpdate: last,
    );
  }

  Future<void> start({String? organizationId}) async {
    orgId = organizationId;
    loading = true;
    error = null;
    notifyListeners();

    await _subscription?.cancel();
    _subscription = _watchUseCase(orgId: organizationId).listen(
      (items) {
        presets = items;
        if (selectedPreset != null) {
          selectedPreset = items.where((item) => item.id == selectedPreset!.id).firstOrNull;
        }
        selectedPreset ??= items.firstOrNull;
        loading = false;
        error = null;
        notifyListeners();
      },
      onError: (Object err, StackTrace _) {
        loading = false;
        error = err;
        notifyListeners();
      },
    );
  }

  void selectPreset(MapStylePreset preset) {
    selectedPreset = preset;
    notifyListeners();
  }

  Future<MapStylePreset> createPreset(MapStylePreset draft) async {
    final created = await _createUseCase(draft);
    selectedPreset = created;
    notifyListeners();
    return created;
  }

  Future<void> savePreset(MapStylePreset preset) async {
    await _repository.updatePreset(preset);
  }

  Future<void> publishPreset(String presetId) async {
    await _publishUseCase(presetId);
  }

  Future<void> archivePreset(String presetId) async {
    await _archiveUseCase(presetId);
  }

  Future<void> deletePreset(String presetId) async {
    await _deleteUseCase(presetId);
    if (selectedPreset?.id == presetId) {
      selectedPreset = presets.where((item) => item.id != presetId).firstOrNull;
      notifyListeners();
    }
  }

  Future<MapStylePreset> duplicatePreset(String presetId) async {
    final duplicated = await _duplicateUseCase(presetId);
    selectedPreset = duplicated;
    notifyListeners();
    return duplicated;
  }

  Future<void> setDefaultPreset(String presetId) async {
    final id = orgId ?? selectedPreset?.orgId ?? '';
    if (id.isEmpty) return;
    await _setDefaultUseCase(presetId, orgId: id);
  }

  Future<void> toggleWizardVisibility(MapStylePreset preset, bool nextValue) async {
    await _repository.updatePreset(
      preset.copyWith(
        visibleInWizard: nextValue,
        isQuickPreset: nextValue ? preset.isQuickPreset : false,
      ),
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
