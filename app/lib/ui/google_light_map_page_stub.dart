import 'package:flutter/material.dart';

/// Stub for legacy GoogleLightMapPage (moved to legacy folder)
class GoogleLightMapPage extends StatelessWidget {
  const GoogleLightMapPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Page déplacée')),
      body: const Center(
        child: Text(
          'Google Light Map n\'est pas disponible sur cette plateforme.\n'
          'Utilisez DefaultMapPage sur le web ou HomeMapPage3D sur mobile.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
