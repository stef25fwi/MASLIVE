import 'package:flutter/foundation.dart';

import '../../domain/entities/map_style_enums.dart';
import '../../domain/entities/map_style_preset.dart';
import '../../utils/map_style_defaults.dart';

class MapStyleEditorController extends ChangeNotifier {
  MapStyleEditorController();

  MapStylePreset? _initial;
  MapStylePreset? _draft;
  bool saving = false;
  Object? error;

  MapStylePreset? get draft => _draft;

  bool get hasValue => _draft != null;

  bool get hasChanges => _initial != null && _draft != null && _initial != _draft;

  void load(MapStylePreset preset) {
    _initial = preset;
    _draft = preset;
    error = null;
    notifyListeners();
  }

  void createNew({
    required String id,
    required String ownerUid,
    required String orgId,
    String? name,
  }) {
    final preset = MapStyleDefaults.newDraft(
      id: id,
      ownerUid: ownerUid,
      orgId: orgId,
      name: (name == null || name.trim().isEmpty) ? 'Nouveau preset' : name.trim(),
    );
    load(preset);
  }

  void patch(MapStylePreset Function(MapStylePreset current) builder) {
    final current = _draft;
    if (current == null) return;
    _draft = builder(current).copyWith(updatedAt: DateTime.now());
    notifyListeners();
  }

  void setIdentity({
    String? name,
    String? description,
    MapStyleCategory? category,
    String? thumbnailUrl,
    String? dominantColor,
    List<String>? tags,
    bool? visibleInWizard,
    bool? isQuickPreset,
    bool? isDefault,
  }) {
    patch((current) {
      return current.copyWith(
        name: name ?? current.name,
        description: description ?? current.description,
        category: category ?? current.category,
        thumbnailUrl: thumbnailUrl ?? current.thumbnailUrl,
        dominantColor: dominantColor ?? current.dominantColor,
        tags: tags ?? current.tags,
        visibleInWizard: visibleInWizard ?? current.visibleInWizard,
        isQuickPreset: isQuickPreset ?? current.isQuickPreset,
        isDefault: isDefault ?? current.isDefault,
      );
    });
  }

  void setMapboxBaseStyle(String style) {
    patch((current) {
      return current.copyWith(
        theme: current.theme.copyWith(
          global: current.theme.global.copyWith(mapboxBaseStyle: style),
        ),
      );
    });
  }

  String? validateForSave() {
    final current = _draft;
    if (current == null) return 'Aucun preset en edition';
    if (current.name.trim().isEmpty) return 'Le nom est requis';
    if (!MapStyleDefaults.mapboxBaseStyles.contains(current.theme.global.mapboxBaseStyle)) {
      return 'Style Mapbox de base invalide';
    }
    return null;
  }

  void markSaving(bool value) {
    saving = value;
    notifyListeners();
  }

  void setError(Object? next) {
    error = next;
    notifyListeners();
  }

  void resetChanges() {
    if (_initial == null) return;
    _draft = _initial;
    notifyListeners();
  }
}
