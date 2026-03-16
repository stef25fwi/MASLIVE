import 'dart:async';

import 'package:flutter/material.dart';

import '../../../map_style/data/repositories/map_style_preset_repository_impl.dart';
import '../../../map_style/domain/entities/map_style_preset.dart';
import '../../../map_style/domain/usecases/map_style_usecases.dart';
import '../widgets/wizard_quick_preset_carousel.dart';

class WizardStep2MapStyleSection extends StatefulWidget {
  const WizardStep2MapStyleSection({
    super.key,
    required this.orgId,
    required this.currentStyleUrl,
    required this.onApplyPreset,
    required this.onPreviewPreset,
    required this.onDuplicatePreset,
  });

  final String orgId;
  final String currentStyleUrl;
  final ValueChanged<MapStylePreset> onApplyPreset;
  final ValueChanged<MapStylePreset> onPreviewPreset;
  final ValueChanged<MapStylePreset> onDuplicatePreset;

  @override
  State<WizardStep2MapStyleSection> createState() => _WizardStep2MapStyleSectionState();
}

class _WizardStep2MapStyleSectionState extends State<WizardStep2MapStyleSection> {
  final _repository = MapStylePresetRepositoryImpl();
  late final WatchWizardQuickMapStylePresetsUseCase _watchUseCase;
  StreamSubscription<List<MapStylePreset>>? _subscription;

  bool _loading = true;
  Object? _error;
  List<MapStylePreset> _presets = const <MapStylePreset>[];

  @override
  void initState() {
    super.initState();
    _watchUseCase = WatchWizardQuickMapStylePresetsUseCase(_repository);
    _subscription = _watchUseCase(orgId: widget.orgId).listen(
      (items) {
        setState(() {
          _presets = items;
          _loading = false;
          _error = null;
        });
      },
      onError: (Object err, StackTrace _) {
        setState(() {
          _error = err;
          _loading = false;
        });
      },
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text(
          'Presets rapides Mapbox Style',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        const Text(
          'Presets publies et visibles dans le wizard (etape 2).',
          style: TextStyle(color: Color(0xFF6B7280), fontSize: 12),
        ),
        const SizedBox(height: 10),
        if (_loading)
          const SizedBox(height: 80, child: Center(child: CircularProgressIndicator()))
        else if (_error != null)
          Text('Erreur presets: $_error', style: const TextStyle(color: Colors.red))
        else
          WizardQuickPresetCarousel(
            presets: _presets,
            selectedPresetId: _presets.firstWhereOrNull((item) => item.theme.global.mapboxBaseStyle == widget.currentStyleUrl)?.id,
            onApply: widget.onApplyPreset,
            onPreview: widget.onPreviewPreset,
            onDuplicate: widget.onDuplicatePreset,
          ),
      ],
    );
  }
}

extension _FirstWhereOrNull<E> on Iterable<E> {
  E? firstWhereOrNull(bool Function(E element) test) {
    for (final item in this) {
      if (test(item)) return item;
    }
    return null;
  }
}
