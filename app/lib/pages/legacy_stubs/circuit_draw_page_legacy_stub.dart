import "package:flutter/material.dart";

/// Stub: legacy circuit drawing removed from build (flutter_map).
class CircuitDrawPageLegacy extends StatelessWidget {
  const CircuitDrawPageLegacy({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Circuit drawing (legacy disabled)")),
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
