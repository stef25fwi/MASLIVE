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
          'Cette page a été déplacée vers le dossier legacy.\n'
          'Utilisez HomeMapPage3D ou HomeMapPageWeb à la place.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
