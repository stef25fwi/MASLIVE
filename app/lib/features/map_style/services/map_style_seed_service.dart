import 'package:firebase_auth/firebase_auth.dart';

import '../data/mocks/map_style_mock_presets.dart';
import '../domain/repositories/map_style_preset_repository.dart';

class MapStyleSeedService {
  const MapStyleSeedService({required MapStylePresetRepository repository})
    : _repository = repository;

  final MapStylePresetRepository _repository;

  Future<int> seedDefaultPresets() async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'admin';
    final presets = MapStyleMockPresets.build(ownerUid: uid, orgId: uid);
    var created = 0;
    for (final preset in presets) {
      await _repository.createPreset(preset.copyWith(id: ''));
      created++;
    }
    return created;
  }
}
