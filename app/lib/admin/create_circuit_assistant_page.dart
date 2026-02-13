import 'package:flutter/material.dart';

import 'circuit_wizard_entry_page.dart';

/// Ancien assistant de création de circuit.
///
/// Conservé uniquement pour compatibilité (liens/menus legacy).
/// L'outil unique de création/modification est désormais le Wizard Circuit Pro.
class CreateCircuitAssistantPage extends StatelessWidget {
  const CreateCircuitAssistantPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Outil remplacé'),
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
                'Cet assistant est remplacé par le Wizard Circuit Pro.\n\n👉 Utilise un seul outil pour créer et modifier des circuits.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const CircuitWizardEntryPage()),
                ),
                icon: const Icon(Icons.auto_fix_high),
                label: const Text('Ouvrir Wizard Circuit Pro'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
