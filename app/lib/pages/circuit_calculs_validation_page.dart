// ignore_for_file: unused_field, unused_element, dead_code

import 'package:flutter/material.dart';

class CircuitCalculsValidationPage extends StatefulWidget {
  const CircuitCalculsValidationPage({super.key});

  @override
  State<CircuitCalculsValidationPage> createState() =>
      _CircuitCalculsValidationPageState();
}

class _CircuitCalculsValidationPageState
    extends State<CircuitCalculsValidationPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
        title: const Text(
          "Calculs & Validation (Legacy)",
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
