// ignore_for_file: unused_field, unused_element, dead_code

import 'package:flutter/material.dart';

class CircuitImportExportPage extends StatefulWidget {
  const CircuitImportExportPage({super.key});

  @override
  State<CircuitImportExportPage> createState() =>
      _CircuitImportExportPageState();
}

class _CircuitImportExportPageState extends State<CircuitImportExportPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
        title: const Text(
          "Importer / Exporter (Legacy)",
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.info_outline, size: 48),
              const SizedBox(height: 12),
              const Text(
                "Outil legacy désactivé.\nUtilise le Wizard Circuit (MarketMap).",
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () =>
                    Navigator.of(context).pushNamed('/admin/circuit-wizard'),
                child: const Text("Ouvrir le Wizard Circuit"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Widgets inutilisés mais conservés pour compilation
class _ImportButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool isLoading;
  final VoidCallback onPressed;

  const _ImportButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.isLoading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}

class _FileCard extends StatelessWidget {
  final String file;
  final VoidCallback onDelete;

  const _FileCard({required this.file, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
