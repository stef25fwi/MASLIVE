import 'package:flutter/material.dart';

import '../../../models/market_circuit.dart';
import '../../../models/market_country.dart';
import '../../../models/market_event.dart';
import '../../../models/market_poi.dart';
import '../../../services/market_map_service.dart';

class BusinessRestaurantSelection {
  const BusinessRestaurantSelection({
    required this.country,
    required this.event,
    required this.circuit,
    required this.poi,
  });

  final MarketCountry country;
  final MarketEvent event;
  final MarketCircuit circuit;
  final MarketPoi poi;
}

Future<BusinessRestaurantSelection?> showBusinessRestaurantSelectorSheet(
  BuildContext context, {
  MarketMapService? service,
  String title = 'Choisir mon restaurant',
  String? initialCountryId,
  String? initialEventId,
  String? initialCircuitId,
  String? initialPoiId,
}) {
  return showModalBottomSheet<BusinessRestaurantSelection>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (_) => _BusinessRestaurantSelectorSheet(
      service: service ?? MarketMapService(),
      title: title,
      initialCountryId: initialCountryId,
      initialEventId: initialEventId,
      initialCircuitId: initialCircuitId,
      initialPoiId: initialPoiId,
    ),
  );
}

class _BusinessRestaurantSelectorSheet extends StatefulWidget {
  const _BusinessRestaurantSelectorSheet({
    required this.service,
    required this.title,
    this.initialCountryId,
    this.initialEventId,
    this.initialCircuitId,
    this.initialPoiId,
  });

  final MarketMapService service;
  final String title;
  final String? initialCountryId;
  final String? initialEventId;
  final String? initialCircuitId;
  final String? initialPoiId;

  @override
  State<_BusinessRestaurantSelectorSheet> createState() =>
      _BusinessRestaurantSelectorSheetState();
}

class _BusinessRestaurantSelectorSheetState
    extends State<_BusinessRestaurantSelectorSheet> {
  MarketCountry? _country;
  MarketEvent? _event;
  MarketCircuit? _circuit;
  MarketPoi? _poi;

  String get _initialCountryId => (widget.initialCountryId ?? '').trim();
  String get _initialEventId => (widget.initialEventId ?? '').trim();
  String get _initialCircuitId => (widget.initialCircuitId ?? '').trim();
  String get _initialPoiId => (widget.initialPoiId ?? '').trim();

  String _countryLabel(MarketCountry c) => c.name.trim().isEmpty ? c.id : c.name.trim();
  String _eventLabel(MarketEvent e) => e.name.trim().isEmpty ? e.id : e.name.trim();
  String _circuitLabel(MarketCircuit c) => c.name.trim().isEmpty ? c.id : c.name.trim();
  String _poiLabel(MarketPoi p) => p.name.trim().isEmpty ? p.id : p.name.trim();

  bool _isRestaurantPoi(MarketPoi poi) {
    final type = (poi.type ?? poi.layerId).trim().toLowerCase();
    return type == 'food' || type == 'restaurant';
  }

  T? _resolveInitial<T>(Iterable<T> items, T? current, String initialId, String Function(T) getId) {
    if (current != null) {
      return items.where((item) => getId(item) == getId(current)).firstOrNull;
    }
    if (initialId.isEmpty) return null;
    return items.where((item) => getId(item) == initialId).firstOrNull;
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.viewInsetsOf(context).bottom;

    return StreamBuilder<VisibleCircuitsIndex>(
      stream: widget.service.watchVisibleCircuitsIndex(),
      builder: (context, visibleSnap) {
        final allowSelection = visibleSnap.hasData;
        final visibleIndex = visibleSnap.data;
        final visibleCountryIds = visibleIndex?.countryIds ?? const <String>{};
        final visibleEventIds = _country == null
            ? const <String>{}
            : visibleIndex?.eventIdsForCountry(_country!.id) ?? const <String>{};

        return FractionallySizedBox(
          heightFactor: 0.92,
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 8,
                bottom: 16 + bottomPadding,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      widget.title,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 8),
                    if (!allowSelection) const LinearProgressIndicator(),
                    const SizedBox(height: 12),
                    StreamBuilder<List<MarketCountry>>(
                stream: widget.service.watchCountries(),
                builder: (context, snap) {
                  final items = (snap.data ?? const <MarketCountry>[])
                      .where((c) => visibleCountryIds.contains(c.id))
                      .toList()
                    ..sort((a, b) => _countryLabel(a).compareTo(_countryLabel(b)));
                  final selectedCountry = _resolveInitial(
                    items,
                    _country,
                    _initialCountryId,
                    (item) => item.id,
                  );

                  if (!identical(selectedCountry, _country)) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!mounted) return;
                      setState(() {
                        _country = selectedCountry;
                        if (_country == null) {
                          _event = null;
                          _circuit = null;
                          _poi = null;
                        }
                      });
                    });
                  }

                  return DropdownButtonFormField<String>(
                    initialValue: selectedCountry?.id,
                    decoration: const InputDecoration(
                      labelText: 'Pays',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      for (final c in items)
                        DropdownMenuItem<String>(
                          value: c.id,
                          child: Text(_countryLabel(c)),
                        ),
                    ],
                    onChanged: !allowSelection
                        ? null
                        : (id) {
                            final next = items.where((c) => c.id == id).firstOrNull;
                            setState(() {
                              _country = next;
                              _event = null;
                              _circuit = null;
                              _poi = null;
                            });
                          },
                  );
                },
                    ),
                    const SizedBox(height: 12),
                    StreamBuilder<List<MarketEvent>>(
                stream: _country == null
                    ? const Stream.empty()
                    : widget.service.watchEvents(countryId: _country!.id),
                builder: (context, snap) {
                  final items = (snap.data ?? const <MarketEvent>[])
                      .where((e) => visibleEventIds.contains(e.id))
                      .toList();
                  final selectedEvent = _resolveInitial(
                    items,
                    _event,
                    _initialEventId,
                    (item) => item.id,
                  );

                  if (!identical(selectedEvent, _event)) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!mounted) return;
                      setState(() {
                        _event = selectedEvent;
                        if (_event == null) {
                          _circuit = null;
                          _poi = null;
                        }
                      });
                    });
                  }

                  return DropdownButtonFormField<String>(
                    initialValue: selectedEvent?.id,
                    decoration: const InputDecoration(
                      labelText: 'Événement',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      for (final e in items)
                        DropdownMenuItem<String>(
                          value: e.id,
                          child: Text(_eventLabel(e)),
                        ),
                    ],
                    onChanged: (!allowSelection || _country == null)
                        ? null
                        : (id) {
                            final next = items.where((e) => e.id == id).firstOrNull;
                            setState(() {
                              _event = next;
                              _circuit = null;
                              _poi = null;
                            });
                          },
                  );
                },
                    ),
                    const SizedBox(height: 12),
                    StreamBuilder<List<MarketCircuit>>(
                stream: (_country == null || _event == null)
                    ? const Stream.empty()
                    : widget.service.watchCircuits(
                        countryId: _country!.id,
                        eventId: _event!.id,
                      ),
                builder: (context, snap) {
                  final items = (snap.data ?? const <MarketCircuit>[])
                      .where((c) => c.isVisible)
                      .toList();
                  final selectedCircuit = _resolveInitial(
                    items,
                    _circuit,
                    _initialCircuitId,
                    (item) => item.id,
                  );

                  if (!identical(selectedCircuit, _circuit)) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!mounted) return;
                      setState(() {
                        _circuit = selectedCircuit;
                        if (_circuit == null) {
                          _poi = null;
                        }
                      });
                    });
                  }

                  return DropdownButtonFormField<String>(
                    initialValue: selectedCircuit?.id,
                    decoration: const InputDecoration(
                      labelText: 'Circuit',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      for (final c in items)
                        DropdownMenuItem<String>(
                          value: c.id,
                          child: Text(_circuitLabel(c)),
                        ),
                    ],
                    onChanged: (!allowSelection || _country == null || _event == null)
                        ? null
                        : (id) {
                            final next = items.where((c) => c.id == id).firstOrNull;
                            setState(() {
                              _circuit = next;
                              _poi = null;
                            });
                          },
                  );
                },
                    ),
                    const SizedBox(height: 12),
                    StreamBuilder<List<MarketPoi>>(
                stream: (_country == null || _event == null || _circuit == null)
                    ? const Stream.empty()
                    : widget.service.watchVisiblePois(
                        countryId: _country!.id,
                        eventId: _event!.id,
                        circuitId: _circuit!.id,
                      ),
                builder: (context, snap) {
                  final items = (snap.data ?? const <MarketPoi>[])
                      .where(_isRestaurantPoi)
                      .toList()
                    ..sort((a, b) => _poiLabel(a).compareTo(_poiLabel(b)));
                  final selectedPoi = _resolveInitial(
                    items,
                    _poi,
                    _initialPoiId,
                    (item) => item.id,
                  );

                  if (!identical(selectedPoi, _poi)) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!mounted) return;
                      setState(() => _poi = selectedPoi);
                    });
                  }

                  return DropdownButtonFormField<String>(
                    initialValue: selectedPoi?.id,
                    decoration: const InputDecoration(
                      labelText: 'Restaurant',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      for (final p in items)
                        DropdownMenuItem<String>(
                          value: p.id,
                          child: Text(_poiLabel(p)),
                        ),
                    ],
                    onChanged: (!allowSelection || _country == null || _event == null || _circuit == null)
                        ? null
                        : (id) {
                            final next = items.where((p) => p.id == id).firstOrNull;
                            setState(() => _poi = next);
                          },
                  );
                },
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: (_country != null && _event != null && _circuit != null && _poi != null)
                          ? () {
                              Navigator.of(context).pop(
                                BusinessRestaurantSelection(
                                  country: _country!,
                                  event: _event!,
                                  circuit: _circuit!,
                                  poi: _poi!,
                                ),
                              );
                            }
                          : null,
                      icon: const Icon(Icons.check_rounded),
                      label: const Text('Choisir ce restaurant'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull {
    if (isEmpty) return null;
    return first;
  }
}
