import 'package:flutter/material.dart';

import '../../models/market_circuit.dart';
import '../../models/market_country.dart';
import '../../models/market_event.dart';
import '../../models/market_layer.dart';
import '../../services/market_map_service.dart';

class MarketMapPoiSelection {
  const MarketMapPoiSelection._({
    required this.enabled,
    this.country,
    this.event,
    this.circuit,
    this.layerIds = const <String>{},
  });

  final bool enabled;
  final MarketCountry? country;
  final MarketEvent? event;
  final MarketCircuit? circuit;
  final Set<String> layerIds;

  const MarketMapPoiSelection.disabled() : this._(enabled: false);

  factory MarketMapPoiSelection.enabled({
    required MarketCountry country,
    required MarketEvent event,
    required MarketCircuit circuit,
    required Set<String> layerIds,
  }) {
    return MarketMapPoiSelection._(
      enabled: true,
      country: country,
      event: event,
      circuit: circuit,
      layerIds: layerIds,
    );
  }
}

Future<MarketMapPoiSelection?> showMarketMapPoiSelectorSheet(
  BuildContext context, {
  MarketMapService? service,
  MarketMapPoiSelection? initial,
  String title = 'POIs MarketMap',
  bool showLayers = true,
}) {
  return showModalBottomSheet<MarketMapPoiSelection>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _MarketMapPoiSelectorSheet(
      service: service ?? MarketMapService(),
      initial: initial,
      title: title,
      showLayers: showLayers,
    ),
  );
}

Future<MarketMapPoiSelection?> showMarketMapCircuitSelectorSheet(
  BuildContext context, {
  MarketMapService? service,
  MarketMapPoiSelection? initial,
}) {
  return showMarketMapPoiSelectorSheet(
    context,
    service: service,
    initial: initial,
    title: 'Carte',
    showLayers: false,
  );
}

class _MarketMapPoiSelectorSheet extends StatefulWidget {
  const _MarketMapPoiSelectorSheet({
    required this.service,
    this.initial,
    required this.title,
    required this.showLayers,
  });

  final MarketMapService service;
  final MarketMapPoiSelection? initial;
  final String title;
  final bool showLayers;

  @override
  State<_MarketMapPoiSelectorSheet> createState() => _MarketMapPoiSelectorSheetState();
}

class _MarketMapPoiSelectorSheetState extends State<_MarketMapPoiSelectorSheet> {
  MarketCountry? _country;
  MarketEvent? _event;
  MarketCircuit? _circuit;
  Set<String> _layerIds = <String>{};
  bool _layerSelectionInitialized = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    if (initial != null && initial.enabled) {
      _country = initial.country;
      _event = initial.event;
      _circuit = initial.circuit;
      _layerIds = {...initial.layerIds};
      _layerSelectionInitialized = _layerIds.isNotEmpty;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(left: 16, right: 16, top: 4, bottom: 16 + bottomPadding),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.title,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                ),
              ),
              TextButton.icon(
                onPressed: () => Navigator.of(context).pop(const MarketMapPoiSelection.disabled()),
                icon: const Icon(Icons.visibility_off_rounded),
                label: const Text('Désactiver'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          StreamBuilder<List<MarketCountry>>(
            stream: widget.service.watchCountries(),
            builder: (context, snap) {
              final items = snap.data ?? const <MarketCountry>[];
              return DropdownButtonFormField<String>(
                value: _country?.id,
                decoration: const InputDecoration(
                  labelText: 'Pays',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final c in items)
                    DropdownMenuItem(value: c.id, child: Text(c.name)),
                ],
                onChanged: (id) {
                  if (id == null) return;
                  final selected = items.firstWhere(
                    (c) => c.id == id,
                    orElse: () => const MarketCountry(id: '', name: '', slug: ''),
                  );
                  if (selected.id.isEmpty) return;
                  setState(() {
                    _country = selected;
                    _event = null;
                    _circuit = null;
                    _layerIds = <String>{};
                    _layerSelectionInitialized = false;
                  });
                },
              );
            },
          ),
          const SizedBox(height: 12),
          _event == null && _country == null
              ? const SizedBox.shrink()
              : StreamBuilder<List<MarketEvent>>(
                  stream: _country == null
                      ? const Stream.empty()
                      : widget.service.watchEvents(countryId: _country!.id),
                  builder: (context, snap) {
                    final items = snap.data ?? const <MarketEvent>[];
                    return DropdownButtonFormField<String>(
                      value: _event?.id,
                      decoration: const InputDecoration(
                        labelText: 'Événement',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        for (final e in items)
                          DropdownMenuItem(value: e.id, child: Text(e.name)),
                      ],
                      onChanged: (id) {
                        if (id == null) return;
                        final selected = items.firstWhere(
                          (e) => e.id == id,
                          orElse: () => MarketEvent(
                            id: '',
                            countryId: _country?.id ?? '',
                            name: '',
                            slug: '',
                          ),
                        );
                        if (selected.id.isEmpty) return;
                        setState(() {
                          _event = selected;
                          _circuit = null;
                          _layerIds = <String>{};
                          _layerSelectionInitialized = false;
                        });
                      },
                    );
                  },
                ),
          const SizedBox(height: 12),
          StreamBuilder<List<MarketCircuit>>(
            stream: (_country == null || _event == null)
                ? const Stream.empty()
                : widget.service.watchCircuits(countryId: _country!.id, eventId: _event!.id),
            builder: (context, snap) {
              final allCircuits = snap.data ?? const <MarketCircuit>[];
              // Ne proposer dans le menu que les circuits marqués visibles.
              final items =
                  allCircuits.where((c) => c.isVisible == true).toList(growable: false);

              final selectedId = _circuit?.id;
              final currentValue =
                  items.any((c) => c.id == selectedId) ? selectedId : null;
              return DropdownButtonFormField<String>(
                value: currentValue,
                decoration: const InputDecoration(
                  labelText: 'Circuit',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final c in items)
                    DropdownMenuItem(value: c.id, child: Text('${c.name} (${c.status})')),
                ],
                onChanged: (id) {
                  if (id == null) return;
                  final selected = items.firstWhere(
                    (c) => c.id == id,
                    orElse: () => MarketCircuit(
                      id: '',
                      countryId: _country?.id ?? '',
                      eventId: _event?.id ?? '',
                      name: '',
                      slug: '',
                      status: 'draft',
                      createdByUid: '',
                      perimeterLocked: false,
                      zoomLocked: false,
                      center: const {'lat': 0.0, 'lng': 0.0},
                      initialZoom: 14,
                      isVisible: false,
                      wizardState: const <String, dynamic>{},
                    ),
                  );
                  if (selected.id.isEmpty) return;
                  setState(() {
                    _circuit = selected;
                    _layerIds = <String>{};
                    _layerSelectionInitialized = false;
                  });
                },
              );
            },
          ),
          const SizedBox(height: 12),
          if (widget.showLayers) _buildLayerChooser(),
          if (widget.showLayers) const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: (_country != null && _event != null && _circuit != null)
                ? () {
                    final selection = MarketMapPoiSelection.enabled(
                      country: _country!,
                      event: _event!,
                      circuit: _circuit!,
                      layerIds: widget.showLayers ? {..._layerIds} : <String>{},
                    );
                    Navigator.of(context).pop(selection);
                  }
                : null,
            icon: const Icon(Icons.check_rounded),
            label: const Text('Appliquer'),
          ),
        ],
      ),
    );
  }

  Widget _buildLayerChooser() {
    final country = _country;
    final event = _event;
    final circuit = _circuit;

    if (country == null || event == null || circuit == null) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<List<MarketLayer>>(
      stream: widget.service.watchLayers(
        countryId: country.id,
        eventId: event.id,
        circuitId: circuit.id,
      ),
      builder: (context, snap) {
        final layers = snap.data ?? const <MarketLayer>[];
        if (layers.isEmpty) {
          return const Text('Aucune couche trouvée.');
        }

        if (!_layerSelectionInitialized) {
          _layerSelectionInitialized = true;
          _layerIds = layers.where((l) => l.isEnabled).map((l) => l.id).toSet();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Couches (filtre)',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            ...layers.map((layer) {
              final enabled = _layerIds.contains(layer.id);
              return CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                value: enabled,
                onChanged: (v) {
                  setState(() {
                    if (v == true) {
                      _layerIds.add(layer.id);
                    } else {
                      _layerIds.remove(layer.id);
                    }
                  });
                },
                title: Text(layer.id),
                subtitle: Text('type: ${layer.type}'),
              );
            }),
          ],
        );
      },
    );
  }
}
