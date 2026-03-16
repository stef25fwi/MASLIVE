import 'package:flutter/material.dart';

import '../../domain/entities/map_style_preset.dart';
import '../widgets/map_style_live_preview.dart';

class PreviewStyleSection extends StatelessWidget {
  const PreviewStyleSection({
    super.key,
    required this.preset,
    required this.onGenerateThumbnail,
    required this.onTestInWizard,
  });

  final MapStylePreset preset;
  final VoidCallback onGenerateThumbnail;
  final VoidCallback onTestInWizard;

  @override
  Widget build(BuildContext context) {
    return MapStyleLivePreview(
      preset: preset,
      onGenerateThumbnail: onGenerateThumbnail,
      onTestInWizard: onTestInWizard,
    );
  }
}
