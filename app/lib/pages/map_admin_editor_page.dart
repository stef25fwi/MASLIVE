import "package:flutter/material.dart";

/// Map admin editor (flutter_map) removed.
/// Mapbox-only stub: will be reimplemented with Mapbox drawing later.
class MapAdminEditorPage extends StatelessWidget {
  const MapAdminEditorPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Map admin editor (Mapbox migration)")),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.construction_rounded, size: 48),
              const SizedBox(height: 12),
              const Text(
                "L’éditeur admin est en migration Mapbox (édition/drawing).",
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Retour"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
