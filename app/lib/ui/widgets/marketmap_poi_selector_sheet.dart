import 'package:flutter/material.dart';

import '../../models/market_circuit.dart';
import '../../models/market_country.dart';
import '../../models/market_event.dart';
import '../../models/market_layer.dart';
import '../../services/market_map_service.dart';
import '../../ui_kit/tokens/maslive_tokens.dart';
import '../../utils/country_flag.dart';
import 'country_autocomplete_field.dart';

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
  bool disableKeyboardInput = false,
}) {
  return showModalBottomSheet<MarketMapPoiSelection>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    builder: (_) => _MarketMapPoiSelectorSheet(
      service: service ?? MarketMapService(),
      initial: initial,
      title: title,
      showLayers: showLayers,
      disableKeyboardInput: disableKeyboardInput,
    ),
  );
}

Future<MarketMapPoiSelection?> showMarketMapCircuitSelectorSheet(
  BuildContext context, {
  MarketMapService? service,
  MarketMapPoiSelection? initial,
  bool disableKeyboardInput = false,
}) {
  return showMarketMapPoiSelectorSheet(
    context,
    service: service,
    initial: initial,
    title: '',
    showLayers: false,
    disableKeyboardInput: disableKeyboardInput,
  );
}

class _MarketMapPoiSelectorSheet extends StatefulWidget {
  const _MarketMapPoiSelectorSheet({
    required this.service,
    this.initial,
    required this.title,
    required this.showLayers,
    required this.disableKeyboardInput,
  });

  final MarketMapService service;
  final MarketMapPoiSelection? initial;
  final String title;
  final bool showLayers;
  final bool disableKeyboardInput;

  @override
  State<_MarketMapPoiSelectorSheet> createState() =>
      _MarketMapPoiSelectorSheetState();
}

class _MarketMapPoiSelectorSheetState
    extends State<_MarketMapPoiSelectorSheet> {
  MarketCountry? _country;
  MarketEvent? _event;
  MarketCircuit? _circuit;
  Set<String> _layerIds = <String>{};
  bool _layerSelectionInitialized = false;

  final TextEditingController _countryCtrl = TextEditingController();
  final TextEditingController _eventCtrl = TextEditingController();
  final TextEditingController _circuitCtrl = TextEditingController();

  final FocusNode _countryFocus = FocusNode();
  final FocusNode _eventFocus = FocusNode();
  final FocusNode _circuitFocus = FocusNode();

  bool _countryHasSelectedOption = false;
  bool _eventHasSelectedOption = false;
  bool _circuitHasSelectedOption = false;

  bool _updatingControllers = false;

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

      final country = _country;
      if (country != null) {
        _countryCtrl.text = _countryLabel(country);
        _countryHasSelectedOption = true;
      }

      final event = _event;
      if (event != null) {
        _eventCtrl.text = _eventLabel(event);
        _eventHasSelectedOption = true;
      }

      final circuit = _circuit;
      if (circuit != null) {
        _circuitCtrl.text = _circuitLabel(circuit);
        _circuitHasSelectedOption = true;
      }
    }

    // En mode strict (Home): si l'utilisateur modifie le texte après sélection,
    // on annule la sélection (pas de saisie libre).
    _countryCtrl.addListener(() {
      if (!widget.disableKeyboardInput) return;
      if (_updatingControllers) return;
      final selected = _country;
      if (selected == null) return;
      final typed = MarketMapService.slugify(_countryCtrl.text);
      final expected = MarketMapService.slugify(_countryLabel(selected));
      if (typed == expected) return;
      setState(() {
        _country = null;
        _countryHasSelectedOption = false;
        _event = null;
        _eventCtrl.clear();
        _eventHasSelectedOption = false;
        _circuit = null;
        _circuitCtrl.clear();
        _circuitHasSelectedOption = false;
        _layerIds = <String>{};
        _layerSelectionInitialized = false;
      });
    });

    _eventCtrl.addListener(() {
      if (!widget.disableKeyboardInput) return;
      if (_updatingControllers) return;
      final selected = _event;
      if (selected == null) return;
      final typed = MarketMapService.slugify(_eventCtrl.text);
      final expected = MarketMapService.slugify(_eventLabel(selected));
      if (typed == expected) return;
      setState(() {
        _event = null;
        _eventHasSelectedOption = false;
        _circuit = null;
        _circuitCtrl.clear();
        _circuitHasSelectedOption = false;
        _layerIds = <String>{};
        _layerSelectionInitialized = false;
      });
    });

    _circuitCtrl.addListener(() {
      if (!widget.disableKeyboardInput) return;
      if (_updatingControllers) return;
      final selected = _circuit;
      if (selected == null) return;
      final typed = MarketMapService.slugify(_circuitCtrl.text);
      final expected = MarketMapService.slugify(_circuitLabel(selected));
      if (typed == expected) return;
      setState(() {
        _circuit = null;
        _circuitHasSelectedOption = false;
        _layerIds = <String>{};
        _layerSelectionInitialized = false;
      });
    });

    _countryFocus.addListener(() {
      if (!widget.disableKeyboardInput) return;
      if (_countryFocus.hasFocus) return;
      if (!_countryHasSelectedOption) {
        if (_countryCtrl.text.trim().isNotEmpty) {
          _countryCtrl.clear();
        }
      } else {
        final c = _country;
        if (c != null) {
          _updatingControllers = true;
          _countryCtrl.text = _countryLabel(c);
          _updatingControllers = false;
        }
      }
    });

    _eventFocus.addListener(() {
      if (!widget.disableKeyboardInput) return;
      if (_eventFocus.hasFocus) return;
      if (!_eventHasSelectedOption) {
        if (_eventCtrl.text.trim().isNotEmpty) {
          _eventCtrl.clear();
        }
      } else {
        final event = _event;
        if (event != null) {
          _updatingControllers = true;
          _eventCtrl.text = _eventLabel(event);
          _updatingControllers = false;
        }
      }
    });

    _circuitFocus.addListener(() {
      if (!widget.disableKeyboardInput) return;
      if (_circuitFocus.hasFocus) return;
      if (!_circuitHasSelectedOption) {
        if (_circuitCtrl.text.trim().isNotEmpty) {
          _circuitCtrl.clear();
        }
      } else {
        final circuit = _circuit;
        if (circuit != null) {
          _updatingControllers = true;
          _circuitCtrl.text = _circuitLabel(circuit);
          _updatingControllers = false;
        }
      }
    });
  }

  @override
  void dispose() {
    _countryCtrl.dispose();
    _eventCtrl.dispose();
    _circuitCtrl.dispose();
    _countryFocus.dispose();
    _eventFocus.dispose();
    _circuitFocus.dispose();
    super.dispose();
  }

  String _countryLabel(MarketCountry c) {
    final name = c.name.trim();
    return name.isNotEmpty ? name : c.id;
  }

  String _countrySortKey(MarketCountry c) {
    final name = _countryLabel(c).trim().toLowerCase();
    return name.isNotEmpty ? name : c.id.trim().toLowerCase();
  }

  String _countryIso2(MarketCountry c) {
    return guessIso2FromMarketMapCountry(
      id: c.id,
      slug: c.slug,
      name: c.name,
    );
  }

  TextStyle _countryTextStyle(BuildContext context) {
    return Theme.of(context).textTheme.titleMedium?.copyWith(
          fontSize: 17,
          fontWeight: FontWeight.w800,
          color: Theme.of(context).colorScheme.onSurface,
        ) ??
        const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w800,
        );
  }

  InputDecoration _selectorDecoration(String label) {
    const radius = BorderRadius.all(Radius.circular(14));
    final border = OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: MasliveTokens.borderSoft),
    );
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: MasliveTokens.surface,
      border: border,
      enabledBorder: border,
      focusedBorder: border.copyWith(
        borderSide: BorderSide(color: Colors.grey.shade400),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
    );
  }

  Widget _countryOptionLabel(BuildContext context, MarketCountry c) {
    final iso2 = _countryIso2(c);
    final flag = countryFlagEmojiFromIso2(iso2);
    final label = _countryLabel(c).toUpperCase();
    final code = iso2.toUpperCase();
    final textStyle = _countryTextStyle(context);

    return Row(
      children: [
        SizedBox(
          width: 28,
          child: Text(
            flag.isEmpty ? '  ' : flag,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            '$label  ($code)',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textStyle,
          ),
        ),
      ],
    );
  }

  String _eventLabel(MarketEvent e) {
    final name = e.name.trim();
    return name.isNotEmpty ? name : e.id;
  }

  String _circuitLabel(MarketCircuit c) {
    final name = c.name.trim();
    final base = name.isNotEmpty ? name : c.id;
    final status = c.status.trim();
    return status.isNotEmpty ? '$base ($status)' : base;
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.viewInsetsOf(context).bottom;
    final baseTheme = Theme.of(context);
    final sheetTheme = baseTheme.copyWith(
      colorScheme: baseTheme.colorScheme.copyWith(
        primary: MasliveTokens.text,
        secondary: MasliveTokens.text,
      ),
      inputDecorationTheme: baseTheme.inputDecorationTheme.copyWith(
        filled: true,
        fillColor: MasliveTokens.surface,
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        menuStyle: MenuStyle(
          backgroundColor: WidgetStatePropertyAll<Color>(MasliveTokens.surface),
          shape: WidgetStatePropertyAll<OutlinedBorder>(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          side: WidgetStatePropertyAll<BorderSide>(
            BorderSide(color: MasliveTokens.borderSoft),
          ),
        ),
        inputDecorationTheme: baseTheme.inputDecorationTheme.copyWith(
          filled: true,
          fillColor: MasliveTokens.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: MasliveTokens.borderSoft),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: MasliveTokens.borderSoft),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.grey.shade400),
          ),
        ),
      ),
    );

    return StreamBuilder<VisibleCircuitsIndex>(
      stream: widget.service.watchVisibleCircuitsIndex(),
      builder: (context, visibleSnap) {
        final canFilterByVisibleIndex = visibleSnap.hasData;
        final visibleIndexHasError = visibleSnap.hasError;

        final visibleIndex = visibleSnap.data;
        final visibleCountryIds = canFilterByVisibleIndex
            ? (visibleIndex?.countryIds ?? const <String>{})
            : const <String>{};
        final visibleEventIds = (!canFilterByVisibleIndex || _country == null)
            ? const <String>{}
            : visibleIndex?.eventIdsForCountry(_country!.id) ??
                  const <String>{};

        // Filtre strict demandé: pas de fallback "tous les pays".
        // Un pays n'apparaît que s'il existe au moins 1 circuit visible (On line).
        final allowSelection = canFilterByVisibleIndex;

        return Theme(
          data: sheetTheme,
          child: ColoredBox(
            color: MasliveTokens.bg,
            child: Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 4,
                bottom: 16 + bottomPadding,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                Row(
                  children: [
                    if (widget.title.trim().isNotEmpty)
                      Expanded(
                        child: Text(
                          widget.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      )
                    else
                      const Spacer(),
                    TextButton.icon(
                      onPressed: () => Navigator.of(
                        context,
                      ).pop(const MarketMapPoiSelection.disabled()),
                      icon: const Icon(Icons.visibility_off_rounded),
                      label: const Text('Désactiver'),
                    ),
                  ],
                ),
                if (!allowSelection) const LinearProgressIndicator(),
                if (visibleIndexHasError)
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Text(
                      "Impossible de charger la liste des circuits publiés (mode dégradé).",
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                const SizedBox(height: 8),
                StreamBuilder<List<MarketCountry>>(
                  stream: widget.service.watchCountries(),
                  builder: (context, snap) {
                    final all = snap.data ?? const <MarketCountry>[];
                    final items = canFilterByVisibleIndex
                        ? all
                            .where((c) => visibleCountryIds.contains(c.id))
                            .toList(growable: true)
                        : <MarketCountry>[];
                    items.sort(
                      (a, b) => _countrySortKey(a).compareTo(_countrySortKey(b)),
                    );

                    if (widget.disableKeyboardInput) {
                      final selectedId = _country?.id;
                      final currentValue = items.any((c) => c.id == selectedId)
                          ? selectedId
                          : null;

                      return DropdownButtonFormField<String>(
                        initialValue: currentValue,
                        isExpanded: true,
                        menuMaxHeight: 420,
                        borderRadius: BorderRadius.circular(14),
                        dropdownColor: MasliveTokens.surface,
                        decoration: _selectorDecoration('PAYS'),
                        items: [
                          for (final c in items)
                            DropdownMenuItem<String>(
                              value: c.id,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: c.id == currentValue
                                      ? Colors.grey.shade200
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 4,
                                ),
                                child: _countryOptionLabel(context, c),
                              ),
                            ),
                        ],
                        onChanged: !allowSelection
                            ? null
                            : (id) {
                                if (id == null) return;
                                final selected = items.firstWhere(
                                  (c) => c.id == id,
                                );
                                setState(() {
                                  _country = selected;
                                  _countryHasSelectedOption = true;
                                  _countryCtrl.text = _countryLabel(selected);

                                  _event = null;
                                  _eventCtrl.clear();
                                  _eventHasSelectedOption = false;
                                  _circuit = null;
                                  _circuitCtrl.clear();
                                  _circuitHasSelectedOption = false;
                                  _layerIds = <String>{};
                                  _layerSelectionInitialized = false;
                                });
                              },
                      );
                    }

                    return MarketCountryAutocompleteField(
                      items: items,
                      controller: _countryCtrl,
                      labelText: 'Pays',
                      hintText: widget.disableKeyboardInput
                          ? 'Rechercher un pays…'
                          : 'Rechercher un pays…',
                      enabled: allowSelection,
                      strictSelection: widget.disableKeyboardInput,
                      onSelected: (c) {
                        setState(() {
                          if (c == null) {
                            _country = null;
                          } else {
                            _country = c;
                          }
                          _event = null;
                          _eventCtrl.clear();
                          _eventHasSelectedOption = false;
                          _circuit = null;
                          _circuitCtrl.clear();
                          _circuitHasSelectedOption = false;
                          _layerIds = <String>{};
                          _layerSelectionInitialized = false;
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
                  final all = snap.data ?? const <MarketEvent>[];
                  final items = canFilterByVisibleIndex
                      ? all
                            .where((e) => visibleEventIds.contains(e.id))
                            .toList(growable: false)
                      : const <MarketEvent>[];

                  final selectedId = _event?.id;

                  if (widget.disableKeyboardInput) {
                    MarketEvent? initialSelection;
                    if (selectedId != null) {
                      for (final e in items) {
                        if (e.id == selectedId) {
                          initialSelection = e;
                          break;
                        }
                      }
                    }

                    return DropdownMenu<MarketEvent>(
                      width: MediaQuery.sizeOf(context).width - 32,
                      controller: _eventCtrl,
                      focusNode: _eventFocus,
                      enabled: allowSelection && _country != null,
                      label: const Text('EVENEMENT'),
                      enableSearch: true,
                      enableFilter: true,
                      requestFocusOnTap: true,
                      initialSelection: initialSelection,
                      dropdownMenuEntries: [
                        for (final e in items)
                          DropdownMenuEntry<MarketEvent>(
                            value: e,
                            label: _eventLabel(e),
                          ),
                      ],
                      onSelected: (!allowSelection || _country == null)
                          ? null
                          : (e) {
                              setState(() {
                                _event = e;
                                _eventHasSelectedOption = e != null;
                                _updatingControllers = true;
                                if (e == null) {
                                  _eventCtrl.clear();
                                } else {
                                  _eventCtrl.text = _eventLabel(e);
                                }
                                _updatingControllers = false;

                                _circuit = null;
                                _circuitCtrl.clear();
                                _circuitHasSelectedOption = false;
                                _layerIds = <String>{};
                                _layerSelectionInitialized = false;
                              });
                            },
                    );
                  }

                  final value = items.any((e) => e.id == selectedId)
                      ? selectedId
                      : null;

                  return DropdownButtonFormField<String>(
                    initialValue: value,
                    borderRadius: BorderRadius.circular(14),
                    dropdownColor: MasliveTokens.surface,
                    decoration: _selectorDecoration('EVENEMENT'),
                    items: [
                      for (final e in items)
                        DropdownMenuItem(
                          value: e.id,
                          child: Text(_eventLabel(e)),
                        ),
                    ],
                    onChanged: (!allowSelection || _country == null)
                        ? null
                        : (id) {
                            if (id == null) return;
                            final selected = items.firstWhere((e) => e.id == id);
                            setState(() {
                              _event = selected;
                              _eventCtrl.text = _eventLabel(selected);
                              _circuit = null;
                              _circuitCtrl.clear();
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
                    : widget.service.watchCircuits(
                        countryId: _country!.id,
                        eventId: _event!.id,
                      ),
                builder: (context, snap) {
                  final allCircuits = snap.data ?? const <MarketCircuit>[];

                  // Ne proposer dans le menu "Carte" que les circuits "On line".
                  final items = allCircuits
                      .where((c) => c.isVisible == true)
                      .toList(growable: false);

                  final selectedId = _circuit?.id;

                  if (!widget.disableKeyboardInput) {
                    final currentValue = items.any((c) => c.id == selectedId)
                        ? selectedId
                        : null;

                    return DropdownButtonFormField<String>(
                      initialValue: currentValue,
                      borderRadius: BorderRadius.circular(14),
                      dropdownColor: MasliveTokens.surface,
                      decoration: _selectorDecoration('CIRCUIT'),
                      items: [
                        for (final c in items)
                          DropdownMenuItem(
                            value: c.id,
                            child: Text(_circuitLabel(c)),
                          ),
                      ],
                      onChanged:
                          (!allowSelection ||
                              _country == null ||
                              _event == null)
                          ? null
                          : (id) {
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
                                _circuitCtrl.text = _circuitLabel(selected);
                                _layerIds = <String>{};
                                _layerSelectionInitialized = false;
                              });
                            },
                    );
                  }

                  MarketCircuit? initialSelection;
                  if (selectedId != null) {
                    for (final c in items) {
                      if (c.id == selectedId) {
                        initialSelection = c;
                        break;
                      }
                    }
                  }

                  return DropdownMenu<MarketCircuit>(
                    width: MediaQuery.sizeOf(context).width - 32,
                    controller: _circuitCtrl,
                    focusNode: _circuitFocus,
                    enabled: allowSelection && _country != null && _event != null,
                    label: const Text('CIRCUIT'),
                    enableSearch: true,
                    enableFilter: true,
                    requestFocusOnTap: true,
                    initialSelection: initialSelection,
                    dropdownMenuEntries: [
                      for (final c in items)
                        DropdownMenuEntry<MarketCircuit>(
                          value: c,
                          label: _circuitLabel(c),
                        ),
                    ],
                    onSelected:
                        (!allowSelection || _country == null || _event == null)
                        ? null
                        : (c) {
                            setState(() {
                              _circuit = c;
                              _circuitHasSelectedOption = c != null;
                              _updatingControllers = true;
                              if (c == null) {
                                _circuitCtrl.clear();
                              } else {
                                _circuitCtrl.text = _circuitLabel(c);
                              }
                              _updatingControllers = false;

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
                onPressed:
                    (_country != null && _event != null && _circuit != null)
                    ? () {
                        final selection = MarketMapPoiSelection.enabled(
                          country: _country!,
                          event: _event!,
                          circuit: _circuit!,
                          layerIds: widget.showLayers
                              ? {..._layerIds}
                              : <String>{},
                        );
                        Navigator.of(context).pop(selection);
                      }
                    : null,
                style: FilledButton.styleFrom(
                  backgroundColor: MasliveTokens.primary,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.check_rounded),
                label: const Text('Appliquer'),
              ),
                ],
              ),
            ),
          ),
        );
      },
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
