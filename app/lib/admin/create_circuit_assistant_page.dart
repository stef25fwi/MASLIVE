// lib/admin/create_circuit_assistant_page.dart
//
// Page "Create Circuit Assistant"
// - L'utilisateur clique sur File → MarketMap
// - On ouvre un dialog Step 1 (Pays / Événement / Nom circuit)

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/market_map_service.dart';

class CreateCircuitAssistantPage extends StatefulWidget {
  const CreateCircuitAssistantPage({super.key});

  @override
  State<CreateCircuitAssistantPage> createState() =>
      _CreateCircuitAssistantPageState();
}

class _CreateCircuitAssistantPageState
    extends State<CreateCircuitAssistantPage> {
  CreateCircuitResult? _lastCreated;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Circuit Assistant'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _busy ? null : _openMarketMapCreateDialog,
            tooltip: 'Create MarketMap',
          ),
        ],
      ),
      body: Center(
        child: _lastCreated == null
            ? const Text('Cliquez sur "+" pour créer un MarketMap')
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Dernier circuit créé:'),
                  const SizedBox(height: 16),
                  Text('Pays: ${_lastCreated!.countryId}'),
                  Text('Événement: ${_lastCreated!.eventId}'),
                  Text('Circuit: ${_lastCreated!.circuitId}'),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: _busy ? null : _openMarketMapCreateDialog,
                    child: const Text('Créer un autre circuit'),
                  ),
                ],
              ),
      ),
    );
  }

  Future<void> _openMarketMapCreateDialog() async {
    if (_busy) return;

    final result = await showDialog<CreateCircuitResult>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const _CreateMarketMapStep1Dialog(),
    );

    if (result != null && mounted) {
      setState(() {
        _lastCreated = result;
      });

      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => _Step2PlaceholderPage(result: result),
        ),
      );
    }
  }

  /// Délègue la création du circuit à MarketMapService.createCircuitStep1
  Future<CreateCircuitResult> _createMarketMapDraft({
    required String countryName,
    required String eventName,
    required String circuitName,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    final service = MarketMapService(firestore: FirebaseFirestore.instance);

    return service.createCircuitStep1(
      countryName: countryName,
      eventName: eventName,
      startDate: startDate,
      endDate: endDate,
      circuitName: circuitName,
      uid: user.uid,
    );
  }
}

// =============================================================================
// Dialog Step 1: Formulaire de base (Pays / Événement / Circuit)
// =============================================================================

class _CreateMarketMapStep1Dialog extends StatefulWidget {
  const _CreateMarketMapStep1Dialog();

  @override
  State<_CreateMarketMapStep1Dialog> createState() =>
      _CreateMarketMapStep1DialogState();
}

class _CreateMarketMapStep1DialogState
    extends State<_CreateMarketMapStep1Dialog> {
  final _formKey = GlobalKey<FormState>();
  final _countryController = TextEditingController();
  final _eventController = TextEditingController();
  final _circuitController = TextEditingController();

  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 7));

  bool _busy = false;

  @override
  void dispose() {
    _countryController.dispose();
    _eventController.dispose();
    _circuitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create MarketMap - Step 1'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _countryController,
                decoration: const InputDecoration(
                  labelText: 'Pays',
                  hintText: 'Ex: Guadeloupe',
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Requis' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _eventController,
                decoration: const InputDecoration(
                  labelText: 'Événement',
                  hintText: 'Ex: Carnaval 2026',
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Requis' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _circuitController,
                decoration: const InputDecoration(
                  labelText: 'Nom du circuit',
                  hintText: 'Ex: Circuit Principal',
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Requis' : null,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ListTile(
                      title: const Text('Date début'),
                      subtitle: Text(_formatDate(_startDate)),
                      onTap: () => _pickDate(isStart: true),
                    ),
                  ),
                  Expanded(
                    child: ListTile(
                      title: const Text('Date fin'),
                      subtitle: Text(_formatDate(_endDate)),
                      onTap: () => _pickDate(isStart: false),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          onPressed: _busy ? null : _onCreate,
          child: _busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Créer'),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  Future<void> _pickDate({required bool isStart}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : _endDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _onCreate() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _busy = true);

    try {
      final parentState = context
          .findAncestorStateOfType<_CreateCircuitAssistantPageState>();
      if (parentState == null) {
        throw Exception('Parent state not found');
      }

      final result = await parentState._createMarketMapDraft(
        countryName: _countryController.text.trim(),
        eventName: _eventController.text.trim(),
        circuitName: _circuitController.text.trim(),
        startDate: _startDate,
        endDate: _endDate,
      );

      if (mounted) {
        Navigator.of(context).pop(result);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }
}

// =============================================================================
// Step 2 Placeholder
// =============================================================================

class _Step2PlaceholderPage extends StatelessWidget {
  final CreateCircuitResult result;

  const _Step2PlaceholderPage({required this.result});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Step 2 - À venir')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Circuit créé avec succès!'),
            const SizedBox(height: 16),
            Text('Pays: ${result.countryId}'),
            Text('Événement: ${result.eventId}'),
            Text('Circuit: ${result.circuitId}'),
            const SizedBox(height: 32),
            const Text('Étape 2 du wizard à implémenter...'),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Retour'),
            ),
          ],
        ),
      ),
    );
  }
}
