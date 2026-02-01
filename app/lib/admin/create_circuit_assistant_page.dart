// lib/admin/create_circuit_assistant_page.dart
//
// Page "Create Circuit Assistant"
// - L'utilisateur clique sur File → MarketMap
// - On ouvre un dialog Step 1 (Pays / Événement / Nom circuit)

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class CreateCircuitResult {
  final String countryId;
  final String eventId;
  final String circuitId;

  CreateCircuitResult({
    required this.countryId,
    required this.eventId,
    required this.circuitId,
  });
}

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
    final result = await showDialog<CreateCircuitResult>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const _CreateMarketMapStep1Dialog(),
    );

    if (result != null && mounted) {
      setState(() {
        _lastCreated = result;
      });

      // Navigation vers Step 2 (placeholder pour l'instant)
      if (mounted) {
        await Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (_) => _Step2PlaceholderPage(result: result),
          ),
        );
      }
    }
  }

  /// Crée la structure Firestore pour MarketMap:
  /// marketMap/{countryId}/events/{eventId}/circuits/{circuitId}
  /// + 6 layers par défaut (tracking, visited, full, assistance, parking, wc)
  Future<CreateCircuitResult> _createMarketMapDraft({
    required String countryName,
    required String eventName,
    required String circuitName,
    required String startDateYYYYMMDD,
    required String endDateYYYYMMDD,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    final countryId = _slugify(countryName);
    final eventId = _slugify(eventName);
    final circuitId = _slugify(circuitName);

    final db = FirebaseFirestore.instance;

    await db.runTransaction((tx) async {
      // 1. Créer le document pays
      final countryRef = db.collection('marketMap').doc(countryId);
      tx.set(countryRef, {
        'name': _cleanName(countryName),
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': user.uid,
      });

      // 2. Créer le document événement
      final eventRef = countryRef.collection('events').doc(eventId);
      tx.set(eventRef, {
        'name': _cleanName(eventName),
        'startDate': startDateYYYYMMDD,
        'endDate': endDateYYYYMMDD,
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': user.uid,
      });

      // 3. Créer le document circuit (draft)
      final circuitRef = eventRef.collection('circuits').doc(circuitId);
      tx.set(circuitRef, {
        'name': _cleanName(circuitName),
        'wizardStep': 1,
        'completedSteps': <int>[],
        'perimeterLocked': false,
        'mapLocked': false,
        'center': null,
        'bounds': null,
        'mapStyle': 'mapbox://styles/mapbox/streets-v12',
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': user.uid,
      });

      // 4. Créer les 6 layers par défaut
      final layersData = _defaultLayerDocs();
      for (final layerData in layersData) {
        final layerKey = layerData['key'] as String;
        final layerRef = circuitRef.collection('layers').doc(layerKey);
        tx.set(layerRef, layerData);
      }
    });

    return CreateCircuitResult(
      countryId: countryId,
      eventId: eventId,
      circuitId: circuitId,
    );
  }

  List<Map<String, dynamic>> _defaultLayerDocs() {
    return [
      {
        'key': 'tracking',
        'name': 'Tracking',
        'visible': true,
        'order': 0,
        'style': {
          'line': {'color': '#FF5722', 'width': 3, 'dashArray': <int>[]},
        },
        'source': <String, dynamic>{},
        'params': <String, dynamic>{},
      },
      {
        'key': 'visited',
        'name': 'Visited',
        'visible': true,
        'order': 1,
        'style': {
          'line': {'color': '#4CAF50', 'width': 2, 'dashArray': <int>[]},
        },
        'source': <String, dynamic>{},
        'params': <String, dynamic>{},
      },
      {
        'key': 'full',
        'name': 'Full Circuit',
        'visible': true,
        'order': 2,
        'style': {
          'line': {'color': '#2196F3', 'width': 2, 'dashArray': <int>[]},
        },
        'source': <String, dynamic>{},
        'params': <String, dynamic>{},
      },
      {
        'key': 'assistance',
        'name': 'Assistance Points',
        'visible': true,
        'order': 3,
        'style': {
          'marker': {
            'color': '#FFC107',
            'icon': 'assistance',
            'size': 'medium',
          },
        },
        'source': <String, dynamic>{},
        'params': <String, dynamic>{},
      },
      {
        'key': 'parking',
        'name': 'Parking',
        'visible': true,
        'order': 4,
        'style': {
          'marker': {'color': '#9C27B0', 'icon': 'parking', 'size': 'medium'},
        },
        'source': <String, dynamic>{},
        'params': <String, dynamic>{},
      },
      {
        'key': 'wc',
        'name': 'WC',
        'visible': true,
        'order': 5,
        'style': {
          'marker': {'color': '#00BCD4', 'icon': 'wc', 'size': 'medium'},
        },
        'source': <String, dynamic>{},
        'params': <String, dynamic>{},
      },
    ];
  }

  String _slugify(String text) {
    return text
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'[àáâãäå]'), 'a')
        .replaceAll(RegExp(r'[èéêë]'), 'e')
        .replaceAll(RegExp(r'[ìíîï]'), 'i')
        .replaceAll(RegExp(r'[òóôõö]'), 'o')
        .replaceAll(RegExp(r'[ùúûü]'), 'u')
        .replaceAll(RegExp(r'[ýÿ]'), 'y')
        .replaceAll(RegExp(r'[ñ]'), 'n')
        .replaceAll(RegExp(r'[ç]'), 'c')
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
  }

  String _yyyymmdd(DateTime date) {
    return '${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}';
  }

  String _cleanName(String name) {
    return name.trim().replaceAll(RegExp(r'\s+'), ' ');
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
        startDateYYYYMMDD: parentState._yyyymmdd(_startDate),
        endDateYYYYMMDD: parentState._yyyymmdd(_endDate),
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
