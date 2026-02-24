import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/market_circuit.dart';
import '../models/market_country.dart';
import '../models/market_event.dart';
import '../models/market_layer.dart';
import '../services/market_map_service.dart';
import '../services/circuit_search_service.dart';
import '../utils/country_flag.dart';
import '../ui/widgets/country_autocomplete_field.dart';
import 'circuit_wizard_pro_page.dart';

class POIMarketMapWizardPage extends StatefulWidget {
  const POIMarketMapWizardPage({
    super.key,
    MarketMapService? service,
    this.initialCountryId,
    this.initialEventId,
    this.initialCircuitId,
  }) : _service = service;

  final MarketMapService? _service;

  /// Optionnel : pré-sélectionne pays / événement / circuit
  /// quand on arrive depuis le CreateCircuitAssistant.
  final String? initialCountryId;
  final String? initialEventId;
  final String? initialCircuitId;

  @override
  State<POIMarketMapWizardPage> createState() => _POIMarketMapWizardPageState();
}

class _POIMarketMapWizardPageState extends State<POIMarketMapWizardPage> {
  int _step = 0;

  late final MarketMapService _service = widget._service ?? MarketMapService();

  MarketCountry? _country;
  MarketEvent? _event;
  MarketCircuit? _circuit;

  final CircuitSearchService _circuitSearch = CircuitSearchService();
  String? _selectedCircuitPickKey;
  final TextEditingController _circuitSearchCtrl = TextEditingController();
  String _circuitQuery = '';

  final TextEditingController _countryCtrl = TextEditingController();

  bool get _canGoNext {
    switch (_step) {
      case 0:
        return _country != null;
      case 1:
        return _event != null;
      case 2:
        return _circuit != null;
      case 3:
        return true;
      default:
        return false;
    }
  }

  @override
  void initState() {
    super.initState();

    _circuitSearchCtrl.addListener(() {
      final next = _circuitSearchCtrl.text;
      if (next == _circuitQuery) return;
      setState(() => _circuitQuery = next);
    });

    // Si on vient avec un circuit pré-sélectionné, on tente de
    // positionner directement le wizard sur le bon pays / event / circuit.
    final countryId = widget.initialCountryId;
    final eventId = widget.initialEventId;
    final circuitId = widget.initialCircuitId;

    if (countryId != null && eventId != null && circuitId != null) {
      _preselectFromIds(countryId: countryId, eventId: eventId, circuitId: circuitId);
    }
  }

  @override
  void dispose() {
    _countryCtrl.dispose();
    _circuitSearchCtrl.dispose();
    super.dispose();
  }

  Future<void> _preselectFromIds({
    required String countryId,
    required String eventId,
    required String circuitId,
  }) async {
    try {
      final db = FirebaseFirestore.instance;

      final countrySnap = await db.collection('marketMap').doc(countryId).get();
      final eventSnap = await db
          .collection('marketMap')
          .doc(countryId)
          .collection('events')
          .doc(eventId)
          .get();
      final circuitSnap = await db
          .collection('marketMap')
          .doc(countryId)
          .collection('events')
          .doc(eventId)
          .collection('circuits')
          .doc(circuitId)
          .get();

      if (!mounted) return;
      if (!countrySnap.exists || !eventSnap.exists || !circuitSnap.exists) {
        return; // fallback: wizard classique
      }

      final country = MarketCountry(
        id: countrySnap.id,
        name: (countrySnap.data()?['name'] as String?) ?? countrySnap.id,
        slug: (countrySnap.data()?['slug'] as String?) ?? countrySnap.id,
      );

      final event = MarketEvent(
        id: eventSnap.id,
        countryId: countrySnap.id,
        name: (eventSnap.data()?['name'] as String?) ?? eventSnap.id,
        slug: (eventSnap.data()?['slug'] as String?) ?? eventSnap.id,
      );

      final circuit = MarketCircuit.fromDoc(circuitSnap);

      setState(() {
        _country = country;
        _event = event;
        _circuit = circuit;
        _step = 3; // on atterrit directement sur la gestion des couches/POI
        _countryCtrl.text = country.name.trim().isNotEmpty ? country.name : country.id;
        _selectedCircuitPickKey = '${country.id}::${event.id}::${circuit.id}::${CircuitSource.mapMarket.name}';
      });
    } catch (_) {
      // En cas d'erreur réseau ou autre, on laisse le wizard en mode normal.
    }
  }

  Future<void> _openDraftInCircuitWizard(CircuitPick pick) async {
    final projectId = pick.projectId;
    if (projectId == null || projectId.trim().isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ Brouillon invalide (projectId manquant).')),
      );
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CircuitWizardProPage(
          projectId: projectId,
          countryId: pick.countryId,
          eventId: pick.eventId,
          circuitId: pick.circuitId,
          initialStep: 5, // POIs (index 5)
        ),
      ),
    );

    if (!mounted) return;
    setState(() {
      _selectedCircuitPickKey = null;
      _circuit = null;
    });
  }

  Future<void> _selectPublishedCircuit(CircuitPick pick) async {
    try {
      final db = FirebaseFirestore.instance;
      final snap = await db
          .collection('marketMap')
          .doc(pick.countryId)
          .collection('events')
          .doc(pick.eventId)
          .collection('circuits')
          .doc(pick.circuitId)
          .get();

      if (!mounted) return;
      if (!snap.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('❌ Circuit introuvable (marketMap).')),
        );
        return;
      }

      final circuit = MarketCircuit.fromDoc(snap);
      setState(() {
        _circuit = circuit;
        _selectedCircuitPickKey = pick.key;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ Erreur lors du chargement du circuit.')),
      );
    }
  }

  void _goToStep(int next) {
    setState(() {
      _step = next;
    });
  }

  void _next() {
    if (!_canGoNext) return;
    if (_step < 3) {
      setState(() => _step += 1);
    }
  }

  void _prev() {
    if (_step > 0) {
      setState(() => _step -= 1);
    }
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
            child: const Text('Créer'),
          ),
        ],
      ),
    );
    final normalized = (value ?? '').trim().replaceAll(RegExp(r'\s+'), ' ');
    if (normalized.isEmpty) return null;
    return normalized.length > 60 ? normalized.substring(0, 60).trim() : normalized;
  }

  Future<void> _createCountry() async {
    final name = await _promptName(
      title: 'Créer un pays',
      hint: 'Ex: Guadeloupe',
    );
    if (!mounted || name == null) return;

    final countryId = MarketMapService.slugify(name);
    final now = FieldValue.serverTimestamp();

    await _service.countryRef(countryId).set({
      'name': name,
      'slug': countryId,
      'createdAt': now,
      'updatedAt': now,
    }, SetOptions(merge: true));

    setState(() {
      _country = MarketCountry(
        id: countryId,
        name: name,
        slug: countryId,
      );
      _event = null;
      _circuit = null;
      _step = 1;
    });
  }

  Future<void> _createEvent() async {
    final country = _country;
    if (country == null) return;

    final name = await _promptName(
      title: 'Créer un événement',
      hint: 'Ex: Carnaval 2026',
    );
    if (!mounted || name == null) return;

    final now = FieldValue.serverTimestamp();
    final eventId = MarketMapService.slugify(name);

    await _service.eventRef(countryId: country.id, eventId: eventId).set({
      'name': name,
      'slug': eventId,
      'countryId': country.id,
      'startDate': null,
      'endDate': null,
      'createdAt': now,
      'updatedAt': now,
    }, SetOptions(merge: true));

    setState(() {
      _event = MarketEvent(
        id: eventId,
        countryId: country.id,
        name: name,
        slug: eventId,
      );
      _circuit = null;
      _step = 2;
    });
  }

  Future<void> _createCircuit() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vous devez être connecté.')),
      );
      return;
    }

    final country = _country;
    final event = _event;
    if (country == null || event == null) return;

    final name = await _promptName(
      title: 'Créer un circuit',
      hint: 'Ex: Circuit principal',
    );
    if (!mounted || name == null) return;

    try {
      final result = await _service.createCircuitStep1(
        countryName: country.name,
        eventName: event.name,
        startDate: event.startDate,
        endDate: event.endDate,
        circuitName: name,
        uid: user.uid,
      );

      final snap = await result.circuitRef.get();
      if (!mounted) return;

      final circuit = MarketCircuit.fromDoc(snap);
      setState(() {
        _circuit = circuit;
        _step = 3;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    }
  }

  IconData _layerIcon(MarketLayer layer) {
    switch (layer.type) {
      case 'pois':
        return Icons.place_rounded;
      case 'parking':
        return Icons.local_parking_rounded;
      case 'wc':
        return Icons.wc_rounded;
      case 'assistance':
        return Icons.support_agent_rounded;
      case 'track':
      case 'tracking':
      case 'visited':
      case 'full':
        return Icons.route_rounded;
      case 'perimeter':
        return Icons.crop_square_rounded;
      default:
        return Icons.layers_rounded;
    }
  }

  Color _layerColor(MarketLayer layer) {
    switch (layer.type) {
      case 'pois':
        return const Color(0xFFFF7A00);
      case 'parking':
        return const Color(0xFF9C27B0);
      case 'wc':
        return const Color(0xFF00BCD4);
      case 'assistance':
        return const Color(0xFFFFC107);
      case 'track':
      case 'tracking':
      case 'visited':
      case 'full':
        return const Color(0xFF1A73E8);
      case 'perimeter':
        return const Color(0xFF4CAF50);
      default:
        return const Color(0xFFB66CFF);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = switch (_step) {
      0 => 'POI Wizard • Pays',
      1 => 'POI Wizard • Événement',
      2 => 'POI Wizard • Circuit',
      _ => 'POI Wizard • Couches',
    };

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            tooltip: 'Revenir au début',
            onPressed: () {
              setState(() {
                _step = 0;
                _country = null;
                _event = null;
                _circuit = null;
              });
            },
            icon: const Icon(Icons.restart_alt_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          _Breadcrumb(
            countryName: _country?.name,
            eventName: _event?.name,
            circuitName: _circuit?.name,
            step: _step,
            onTap: (s) {
              // On autorise uniquement retour en arrière.
              if (s <= _step) _goToStep(s);
            },
          ),
          const Divider(height: 1),
          Expanded(child: _buildStepContent()),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Row(
          children: [
            if (_step > 0)
              TextButton.icon(
                onPressed: _prev,
                icon: const Icon(Icons.chevron_left_rounded),
                label: const Text('Retour'),
              ),
            const Spacer(),
            if (_step < 3)
              FilledButton.icon(
                onPressed: _canGoNext ? _next : null,
                icon: const Icon(Icons.chevron_right_rounded),
                label: const Text('Suivant'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_step) {
      case 0:
        return _buildCountryStep();
      case 1:
        return _buildEventStep();
      case 2:
        return _buildCircuitStep();
      case 3:
        return _buildLayersStep();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildCountryStep() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '1/4 • Pays',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: StreamBuilder<List<MarketCountry>>(
                  stream: _service.watchCountries(),
                  builder: (context, snapshot) {
                    final items = snapshot.data ?? const <MarketCountry>[];

                    return MarketCountryAutocompleteField(
                      items: items,
                      controller: _countryCtrl,
                      labelText: 'Pays',
                      hintText: 'Rechercher un pays…',
                      onSelected: (c) {
                        setState(() {
                          _country = c;
                          _event = null;
                          _circuit = null;
                        });
                      },
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              IconButton.filledTonal(
                tooltip: 'Créer un pays',
                onPressed: _createCountry,
                icon: const Icon(Icons.add_rounded),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Choisis le pays de travail. Tu pourras ensuite sélectionner un événement puis un circuit.',
          ),
        ],
      ),
    );
  }

  Widget _buildEventStep() {
    final country = _country;
    if (country == null) {
      return const Center(child: Text('Sélectionne un pays.'));
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '2/4 • Événement',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: StreamBuilder<List<MarketEvent>>(
                  stream: _service.watchEvents(countryId: country.id),
                  builder: (context, snapshot) {
                    final items = snapshot.data ?? const <MarketEvent>[];

                    return DropdownButtonFormField<String>(
                      key: ValueKey('event-${_event?.id ?? ''}'),
                      initialValue: _event?.id,
                      decoration: const InputDecoration(
                        labelText: 'Événement',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        for (final e in items)
                          DropdownMenuItem(value: e.id, child: Text(e.name)),
                      ],
                      onChanged: (id) {
                        final selected = items.firstWhere(
                          (e) => e.id == id,
                          orElse: () => MarketEvent(
                            id: '',
                            countryId: country.id,
                            name: '',
                            slug: '',
                          ),
                        );
                        if (selected.id.isEmpty) return;
                        setState(() {
                          _event = selected;
                          _circuit = null;
                        });
                      },
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              IconButton.filledTonal(
                tooltip: 'Créer un événement',
                onPressed: _createEvent,
                icon: const Icon(Icons.add_rounded),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Pays: ${formatCountryLabelWithFlag(
              name: country.name,
              iso2: guessIso2FromMarketMapCountry(
                id: country.id,
                slug: country.slug,
                name: country.name,
              ),
            )}',
          ),
        ],
      ),
    );
  }

  Widget _buildCircuitStep() {
    final country = _country;
    final event = _event;
    if (country == null || event == null) {
      return const Center(child: Text('Sélectionne un pays et un événement.'));
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '3/4 • Circuit',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _circuitSearchCtrl,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              labelText: 'Rechercher un circuit',
              hintText: 'Brouillon ou publié',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: StreamBuilder<List<CircuitPick>>(
                  stream: _circuitSearch.watchAllCircuitsForPoiTile(
                    countryId: country.id,
                    eventId: event.id,
                    queryText: _circuitQuery,
                    keepBothIfDuplicate: false,
                  ),
                  builder: (context, snapshot) {
                    final items = snapshot.data ?? const <CircuitPick>[];

                    return DropdownButtonFormField<String>(
                      key: ValueKey('circuit-pick-${_selectedCircuitPickKey ?? ''}'),
                      initialValue: _selectedCircuitPickKey,
                      decoration: const InputDecoration(
                        labelText: 'Circuit',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        for (final c in items)
                          DropdownMenuItem(
                            value: c.key,
                            child: Text('${c.name} (${c.badge})'),
                          ),
                      ],
                      onChanged: (key) async {
                        final selected = items.where((c) => c.key == key).toList();
                        if (selected.isEmpty) return;
                        final pick = selected.first;

                        setState(() {
                          _selectedCircuitPickKey = pick.key;
                        });

                        if (pick.source == CircuitSource.draft) {
                          await _openDraftInCircuitWizard(pick);
                          return;
                        }

                        await _selectPublishedCircuit(pick);
                      },
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              IconButton.filledTonal(
                tooltip: 'Créer un circuit',
                onPressed: _createCircuit,
                icon: const Icon(Icons.add_rounded),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text('Événement: ${event.name}'),
        ],
      ),
    );
  }

  Widget _buildLayersStep() {
    final country = _country;
    final event = _event;
    final circuit = _circuit;
    if (country == null || event == null || circuit == null) {
      return const Center(child: Text('Sélectionne un pays, un événement et un circuit.'));
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: _CircuitStyleSelector(
            countryId: country.id,
            eventId: event.id,
            circuitId: circuit.id,
            service: _service,
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: StreamBuilder<List<MarketLayer>>(
            stream: _service.watchLayers(
              countryId: country.id,
              eventId: event.id,
              circuitId: circuit.id,
            ),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('Erreur: ${snapshot.error}'));
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final layers = snapshot.data ?? const <MarketLayer>[];
              if (layers.isEmpty) {
                return const Center(
                    child: Text('Aucune couche trouvée pour ce circuit.'));
              }

              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: layers.length,
                separatorBuilder: (context, index) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final layer = layers[index];
                  final color = _layerColor(layer);

                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: color.withValues(alpha: 0.15),
                        foregroundColor: color,
                        child: Icon(_layerIcon(layer)),
                      ),
                      title: Text(layer.id),
                      subtitle: Text(
                          'type: ${layer.type} • enabled: ${layer.isEnabled}'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => _LayerPoisPage(
                              countryId: country.id,
                              countryName: country.name,
                              eventId: event.id,
                              eventName: event.name,
                              circuitId: circuit.id,
                              circuitName: circuit.name,
                              layer: layer,
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _CircuitStyleSelector extends StatelessWidget {
  const _CircuitStyleSelector({
    required this.countryId,
    required this.eventId,
    required this.circuitId,
    required this.service,
  });

  final String countryId;
  final String eventId;
  final String circuitId;
  final MarketMapService service;

  static const List<Map<String, String>> _styles = [
    {
      'id': 'streets-v12',
      'name': 'Streets',
      'url': 'mapbox://styles/mapbox/streets-v12',
    },
    {
      'id': 'outdoors-v12',
      'name': 'Outdoors',
      'url': 'mapbox://styles/mapbox/outdoors-v12',
    },
    {
      'id': 'satellite-streets-v12',
      'name': 'Satellite streets',
      'url': 'mapbox://styles/mapbox/satellite-streets-v12',
    },
    {
      'id': 'light-v11',
      'name': 'Light',
      'url': 'mapbox://styles/mapbox/light-v11',
    },
    {
      'id': 'dark-v11',
      'name': 'Dark',
      'url': 'mapbox://styles/mapbox/dark-v11',
    },
  ];

  @override
  Widget build(BuildContext context) {
    final circuitRef = service.circuitRef(
      countryId: countryId,
      eventId: eventId,
      circuitId: circuitId,
    );

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: circuitRef.snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return Text('Erreur style: ${snap.error}');
        }
        if (!snap.hasData) {
          return const LinearProgressIndicator();
        }

        final data = snap.data!.data() ?? const <String, dynamic>{};
        final currentId = (data['styleId'] as String?) ?? 'streets-v12';

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Style de carte Mapbox',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: currentId,
              decoration: const InputDecoration(
                labelText: 'Style',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final s in _styles)
                  DropdownMenuItem(
                    value: s['id'],
                    child: Text(s['name'] ?? ''),
                  ),
              ],
              onChanged: (value) async {
                if (value == null) return;
                final style =
                    _styles.firstWhere((s) => s['id'] == value, orElse: () => _styles.first);
                await circuitRef.update({
                  'styleId': style['id'],
                  'styleUrl': style['url'],
                  'updatedAt': FieldValue.serverTimestamp(),
                });
              },
            ),
            const SizedBox(height: 4),
            const Text(
              'Ce style sera utilisé par la carte 3D / Mapbox pour ce circuit.',
              style: TextStyle(fontSize: 12),
            ),
          ],
        );
      },
    );
  }
}

class _Breadcrumb extends StatelessWidget {
  const _Breadcrumb({
    required this.countryName,
    required this.eventName,
    required this.circuitName,
    required this.step,
    required this.onTap,
  });

  final String? countryName;
  final String? eventName;
  final String? circuitName;
  final int step;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    Widget chip({required int index, required String label, required bool enabled}) {
      return InkWell(
        onTap: enabled ? () => onTap(index) : null,
        child: Chip(
          label: Text(label),
          backgroundColor: enabled ? null : Colors.grey.withValues(alpha: 0.15),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          chip(
            index: 0,
            label: countryName == null || countryName!.isEmpty
                ? 'Pays'
                : 'Pays: $countryName',
            enabled: step >= 0,
          ),
          const SizedBox(width: 8),
          chip(
            index: 1,
            label: eventName == null || eventName!.isEmpty
                ? 'Événement'
                : 'Événement: $eventName',
            enabled: step >= 1,
          ),
          const SizedBox(width: 8),
          chip(
            index: 2,
            label: circuitName == null || circuitName!.isEmpty
                ? 'Circuit'
                : 'Circuit: $circuitName',
            enabled: step >= 2,
          ),
          const SizedBox(width: 8),
          chip(index: 3, label: 'Couches', enabled: step >= 3),
        ],
      ),
    );
  }
}

class _LayerPoisPage extends StatefulWidget {
  const _LayerPoisPage({
    required this.countryId,
    required this.countryName,
    required this.eventId,
    required this.eventName,
    required this.circuitId,
    required this.circuitName,
    required this.layer,
  });

  final String countryId;
  final String countryName;
  final String eventId;
  final String eventName;
  final String circuitId;
  final String circuitName;
  final MarketLayer layer;

  @override
  State<_LayerPoisPage> createState() => _LayerPoisPageState();
}

class _LayerPoisPageState extends State<_LayerPoisPage> {
  final _db = FirebaseFirestore.instance;

  static const _types = <String>['market', 'visit', 'food', 'wc', 'parking', 'assistance'];

  CollectionReference<Map<String, dynamic>> get _poisCol => _db
      .collection('marketMap')
      .doc(widget.countryId)
      .collection('events')
      .doc(widget.eventId)
      .collection('circuits')
      .doc(widget.circuitId)
      .collection('pois');

  Future<void> _createOrEditPoi({String? poiId, Map<String, dynamic>? existing}) async {
    final nameCtrl = TextEditingController(text: (existing?['name'] ?? '').toString());
    final descCtrl = TextEditingController(text: (existing?['description'] ?? '').toString());
    final instagramCtrl = TextEditingController(text: (existing?['instagram'] ?? '').toString());
    final facebookCtrl = TextEditingController(text: (existing?['facebook'] ?? '').toString());
    final latCtrl = TextEditingController(
      text: existing?['lat'] != null ? (existing!['lat'] as num).toString() : '',
    );
    final lngCtrl = TextEditingController(
      text: existing?['lng'] != null ? (existing!['lng'] as num).toString() : '',
    );

    String type = (existing?['type'] ?? _types.first).toString();
    bool isVisible = (existing?['isVisible'] as bool?) ?? true;

    double? parseDouble(String input) {
      final v = input.trim().replaceAll(',', '.');
      return double.tryParse(v);
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(poiId == null ? 'Ajouter un POI' : 'Modifier le POI'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nom *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: ValueKey('type-$type'),
                initialValue: type,
                items: [
                  for (final t in _types) DropdownMenuItem(value: t, child: Text(t)),
                ],
                onChanged: (v) => type = v ?? type,
                decoration: const InputDecoration(
                  labelText: 'Type',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: instagramCtrl,
                decoration: const InputDecoration(
                  labelText: 'Instagram',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: facebookCtrl,
                decoration: const InputDecoration(
                  labelText: 'Facebook',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: latCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Lat *',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: lngCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Lng *',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: isVisible,
                onChanged: (v) => isVisible = v,
                title: const Text('Visible (liste + couche)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    final name = nameCtrl.text.trim();
    final lat = parseDouble(latCtrl.text);
    final lng = parseDouble(lngCtrl.text);

    if (name.isEmpty || lat == null || lng == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nom/Lat/Lng requis.')),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    final now = FieldValue.serverTimestamp();

    final data = <String, dynamic>{
      'name': name,
      'description': descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
      'instagram': instagramCtrl.text.trim().isEmpty ? null : instagramCtrl.text.trim(),
      'facebook': facebookCtrl.text.trim().isEmpty ? null : facebookCtrl.text.trim(),
      'type': type,
      'lat': lat,
      'lng': lng,
      'layerId': widget.layer.id,
      'isVisible': isVisible,
      'updatedAt': now,
      if (poiId == null) 'createdAt': now,
      if (poiId == null) 'createdByUid': user?.uid,
    };

    if (poiId == null) {
      await _poisCol.add(data);
    } else {
      await _poisCol.doc(poiId).set(data, SetOptions(merge: true));
    }
  }

  Future<void> _deletePoi(String poiId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer ce POI ?'),
        content: const Text('Cette action est irréversible.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (ok != true) return;
    await _poisCol.doc(poiId).delete();
  }

  Future<void> _toggleVisible(String poiId, bool value) async {
    await _poisCol.doc(poiId).update({
      'isVisible': value,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  IconData _typeIcon(String? type) {
    switch (type) {
      case 'food':
        return Icons.restaurant_rounded;
      case 'visit':
        return Icons.emoji_people_rounded;
      case 'wc':
        return Icons.wc_rounded;
      case 'parking':
        return Icons.local_parking_rounded;
      case 'assistance':
        return Icons.support_agent_rounded;
      case 'market':
      default:
        return Icons.place_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('POIs • ${widget.layer.id}'),
        actions: [
          IconButton(
            tooltip: 'Ajouter un POI',
            onPressed: () => _createOrEditPoi(),
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${widget.countryName} • ${widget.eventName} • ${widget.circuitName}\nCouche: ${widget.layer.id} (${widget.layer.type})',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _poisCol
                  .where('layerId', isEqualTo: widget.layer.id)
                  .orderBy('name')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Erreur: ${snapshot.error}'));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data!.docs;
                if (docs.isEmpty) {
                  return const Center(child: Text('Aucun POI pour cette couche.'));
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: docs.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data();
                    final name = (data['name'] ?? doc.id).toString();
                    final type = data['type']?.toString();
                    final lat = (data['lat'] as num?)?.toDouble();
                    final lng = (data['lng'] as num?)?.toDouble();
                    final isVisible = (data['isVisible'] as bool?) ?? true;

                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          child: Icon(_typeIcon(type)),
                        ),
                        title: Text(name),
                        subtitle: Text(
                          '${type ?? 'poi'}'
                          '${lat != null && lng != null ? ' • ${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}' : ''}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Tooltip(
                              message: 'Visible',
                              child: Checkbox(
                                value: isVisible,
                                onChanged: (v) {
                                  if (v == null) return;
                                  _toggleVisible(doc.id, v);
                                },
                              ),
                            ),
                            IconButton(
                              tooltip: 'Modifier',
                              onPressed: () => _createOrEditPoi(
                                poiId: doc.id,
                                existing: data,
                              ),
                              icon: const Icon(Icons.edit_rounded),
                            ),
                            IconButton(
                              tooltip: 'Supprimer',
                              onPressed: () => _deletePoi(doc.id),
                              icon: const Icon(Icons.delete_outline_rounded),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
