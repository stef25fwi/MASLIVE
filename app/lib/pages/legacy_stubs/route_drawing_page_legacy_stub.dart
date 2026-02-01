import "package:flutter/material.dart";

/// Stub: legacy route drawing removed from build (flutter_map).
class RouteDrawingPageLegacy extends StatelessWidget {
  const RouteDrawingPageLegacy({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Route drawing (legacy disabled)")),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            "Cette page legacy (flutter_map) est désactivée.\n"
            "Migration Mapbox drawing en cours.",
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
