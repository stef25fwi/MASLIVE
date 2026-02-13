import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../models/market_country.dart';
import '../../models/market_event.dart';
import '../../services/market_map_service.dart';
import '../../utils/country_flag.dart';

class CreateCircuitStep1Dialog extends StatefulWidget {
  const CreateCircuitStep1Dialog({super.key, this.service});

  final MarketMapService? service;

  @override
  State<CreateCircuitStep1Dialog> createState() => _CreateCircuitStep1DialogState();
}

class _CreateCircuitStep1DialogState extends State<CreateCircuitStep1Dialog> {
  final _circuitCtrl = TextEditingController();

  String? _selectedCountryId;
  String? _selectedCountryName;

  String? _selectedEventId;
  String? _selectedEventName;

  DateTime? _startDate;
  DateTime? _endDate;

  bool _loading = false;

  late final MarketMapService _service = widget.service ?? MarketMapService();

  @override
  void dispose() {
    _circuitCtrl.dispose();
    super.dispose();
  }

  String get _effectiveCountryId {
    final id = _selectedCountryId;
    if (id != null && id.isNotEmpty) return id;
    final name = (_selectedCountryName ?? '').trim();
    if (name.isEmpty) return '';
    return MarketMapService.slugify(name);
  }

  bool get _canSubmit {
    final circuitName = _circuitCtrl.text.trim();
    final countryName = (_selectedCountryName ?? '').trim();
    final eventName = (_selectedEventName ?? '').trim();
    if (_loading) return false;
    if (circuitName.isEmpty) return false;
    if (countryName.isEmpty) return false;
    if (eventName.isEmpty) return false;
    if (_startDate != null && _endDate != null && _endDate!.isBefore(_startDate!)) {
      return false;
    }
    return true;
  }

  Future<void> _pickStartDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? now,
      firstDate: DateTime(now.year - 10),
      lastDate: DateTime(now.year + 10),
    );
    if (!mounted) return;
    if (picked == null) return;
    setState(() {
      _startDate = DateTime(picked.year, picked.month, picked.day);
      if (_endDate != null && _endDate!.isBefore(_startDate!)) {
        _endDate = null;
      }
    });
  }

  Future<void> _pickEndDate() async {
    final now = DateTime.now();
    final initial = _endDate ?? _startDate ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 10),
      lastDate: DateTime(now.year + 10),
    );
    if (!mounted) return;
    if (picked == null) return;
    setState(() {
      _endDate = DateTime(picked.year, picked.month, picked.day);
    });
  }

  Future<String?> _promptName({required String title, required String hint}) async {
    final ctrl = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(hintText: hint),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );
    final normalized = (value ?? '').trim().replaceAll(RegExp(r'\s+'), ' ');
    if (normalized.isEmpty) return null;
    return normalized.length > 60 ? normalized.substring(0, 60).trim() : normalized;
  }

  Future<void> _addNewCountry() async {
    final name = await _promptName(
      title: 'Créer un nouveau pays',
      hint: 'Ex: France',
    );
    if (!mounted) return;
    if (name == null) return;

    setState(() {
      _selectedCountryId = null;
      _selectedCountryName = name;
      _selectedEventId = null;
      _selectedEventName = null;
    });
  }

  Future<void> _addNewEvent() async {
    if ((_selectedCountryName ?? '').trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sélectionne d\'abord un pays.')),
      );
      return;
    }

    final name = await _promptName(
      title: 'Créer un nouvel événement',
      hint: 'Ex: Trail 2026',
    );
    if (!mounted) return;
    if (name == null) return;

    setState(() {
      _selectedEventId = null;
      _selectedEventName = name;
    });
  }

  Future<void> _submit() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vous devez être connecté.')),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final result = await _service.createCircuitStep1(
        countryName: _selectedCountryName ?? '',
        eventName: _selectedEventName ?? '',
        startDate: _startDate,
        endDate: _endDate,
        circuitName: _circuitCtrl.text,
        uid: user.uid,
      );

      if (!mounted) return;
      Navigator.of(context).pop(result);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final maxWidth = MediaQuery.of(context).size.width;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Créer un circuit',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),

              TextField(
                controller: _circuitCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nom du circuit *',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),

              // Pays
              StreamBuilder<List<MarketCountry>>(
                stream: _service.watchCountries(),
                builder: (context, snapshot) {
                  final items = <DropdownMenuItem<String>>[
                    const DropdownMenuItem(
                      value: '__new__',
                      child: Text('➕ Créer nouveau pays'),
                    ),
                  ];

                  final idToName = <String, String>{};
                  final countries = snapshot.data ?? const <MarketCountry>[];
                  for (final c in countries) {
                    idToName[c.id] = c.name;
                    items.add(
                      DropdownMenuItem(
                        value: c.id,
                        child: Text(
                          formatCountryLabelWithFlag(
                            name: c.name,
                            iso2: guessIso2FromMarketMapCountry(
                              id: c.id,
                              slug: c.slug,
                              name: c.name,
                            ),
                          ),
                        ),
                      ),
                    );
                  }

                  final value = _selectedCountryId;

                  return Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          key: ValueKey<String>('country:${value ?? '__none__'}'),
                          isExpanded: true,
                          initialValue: value,
                          decoration: InputDecoration(
                            labelText: 'Pays *',
                            helperText: _selectedCountryName != null &&
                                    _selectedCountryId == null
                                ? 'Nouveau pays: ${_selectedCountryName!}'
                                : null,
                            border: const OutlineInputBorder(),
                          ),
                          items: items,
                          onChanged: _loading
                              ? null
                              : (v) {
                                  if (v == '__new__') {
                                    _addNewCountry();
                                    return;
                                  }
                                  if (v == null) return;
                                  setState(() {
                                    _selectedCountryId = v;
                                    _selectedCountryName = idToName[v];
                                    _selectedEventId = null;
                                    _selectedEventName = null;
                                    _startDate = null;
                                    _endDate = null;
                                  });
                                },
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: 'Créer un pays',
                        onPressed: _loading ? null : _addNewCountry,
                        icon: const Icon(Icons.add),
                      ),
                    ],
                  );
                },
              ),

              const SizedBox(height: 12),

              // Événement
              if (_effectiveCountryId.isEmpty)
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: null,
                        decoration: const InputDecoration(
                          labelText: 'Événement *',
                          border: OutlineInputBorder(),
                          helperText: 'Sélectionne un pays d\'abord',
                        ),
                        items: const [],
                        onChanged: null,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: 'Créer un événement',
                      onPressed: null,
                      icon: const Icon(Icons.add),
                    ),
                  ],
                )
              else
                StreamBuilder<List<MarketEvent>>(
                  stream: _service.watchEvents(countryId: _effectiveCountryId),
                  builder: (context, snapshot) {
                    final items = <DropdownMenuItem<String>>[
                      const DropdownMenuItem(
                        value: '__new__',
                        child: Text('➕ Créer nouvel événement'),
                      ),
                    ];

                    final idToName = <String, String>{};
                    final idToEvent = <String, MarketEvent>{};
                    final events = snapshot.data ?? const <MarketEvent>[];
                    for (final e in events) {
                      idToName[e.id] = e.name;
                      idToEvent[e.id] = e;
                      items.add(
                        DropdownMenuItem(
                          value: e.id,
                          child: Text(e.name),
                        ),
                      );
                    }

                    return Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            key: ValueKey<String>('event:$_effectiveCountryId:${_selectedEventId ?? '__none__'}'),
                            isExpanded: true,
                            initialValue: _selectedEventId,
                            decoration: InputDecoration(
                              labelText: 'Événement *',
                              helperText: _selectedEventName != null &&
                                      _selectedEventId == null
                                  ? 'Nouvel événement: $_selectedEventName'
                                  : null,
                              border: const OutlineInputBorder(),
                            ),
                            items: items,
                            onChanged: _loading
                                ? null
                                : (v) {
                                    if (v == '__new__') {
                                      _addNewEvent();
                                      return;
                                    }
                                    if (v == null) return;
                                    final picked = idToEvent[v];
                                    setState(() {
                                      _selectedEventId = v;
                                      _selectedEventName = idToName[v];
                                      // Important: si l'événement existe déjà, on reprend ses dates
                                      // pour que l'ID slugifié corresponde et qu'on réutilise l'existant.
                                      _startDate = picked?.startDate;
                                      _endDate = picked?.endDate;
                                    });
                                  },
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          tooltip: 'Créer un événement',
                          onPressed: _loading ? null : _addNewEvent,
                          icon: const Icon(Icons.add),
                        ),
                      ],
                    );
                  },
                ),

              const SizedBox(height: 12),

              // Dates
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _loading ? null : _pickStartDate,
                      icon: const Icon(Icons.date_range),
                      label: Text(
                        _startDate == null
                            ? 'Date début (optionnel)'
                            : 'Début: ${_formatDate(_startDate!)}',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _loading ? null : _pickEndDate,
                      icon: const Icon(Icons.event),
                      label: Text(
                        _endDate == null
                            ? 'Date fin (optionnel)'
                            : 'Fin: ${_formatDate(_endDate!)}',
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              Row(
                children: [
                  TextButton(
                    onPressed: _loading ? null : () => Navigator.pop(context),
                    child: const Text('Annuler'),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: _canSubmit ? _submit : null,
                    child: _loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Créer et continuer'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _formatDate(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }
}
