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
    title: "MAP'MARKET",
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
  static const LinearGradient _headerGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: <Color>[
      Color(0xFFFFC857),
      Color(0xFFFF6BB5),
      Color(0xFF9B6BFF),
      Color(0xFF57C7FF),
    ],
  );

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

  Set<String> _layerFilterTokens(MarketLayer layer) {
    final tokens = <String>{};
    final id = layer.id.trim().toLowerCase();
    if (id.isNotEmpty) tokens.add(id);
    final type = layer.type.trim().toLowerCase();
    if (type.isNotEmpty) tokens.add(type);
    return tokens;
  }

  bool _isLayerSelected(MarketLayer layer) {
    return _layerFilterTokens(layer).any(_layerIds.contains);
  }

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
        if (_countryCtrl.text.trim().isNotEmpty) _countryCtrl.clear();
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
        if (_eventCtrl.text.trim().isNotEmpty) _eventCtrl.clear();
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
        if (_circuitCtrl.text.trim().isNotEmpty) _circuitCtrl.clear();
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
          height: 1.2,
          color: Theme.of(context).colorScheme.onSurface,
        ) ??
        const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, height: 1.2);
  }

  TextStyle _selectorValueTextStyle(BuildContext context) {
    return Theme.of(context).textTheme.titleMedium?.copyWith(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          height: 1.25,
          color: Theme.of(context).colorScheme.onSurface,
        ) ??
        const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          height: 1.25,
        );
  }

  TextStyle _selectorLabelTextStyle(BuildContext context) {
    return Theme.of(context).textTheme.labelLarge?.copyWith(
          fontSize: 14,
          fontWeight: FontWeight.w800,
          height: 1.1,
          color: MasliveTokens.textSoft,
          letterSpacing: 0.3,
        ) ??
        const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w800,
          height: 1.1,
          letterSpacing: 0.3,
        );
  }

  InputDecoration _selectorDecoration(String label, {bool loading = false}) {
    const radius = BorderRadius.all(Radius.circular(14));
    final border = OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: MasliveTokens.borderSoft),
    );
    return InputDecoration(
      labelText: label,
      labelStyle: _selectorLabelTextStyle(context),
      floatingLabelStyle: _selectorLabelTextStyle(context),
      floatingLabelBehavior: FloatingLabelBehavior.always,
      filled: true,
      fillColor: MasliveTokens.surface,
      isDense: false,
      alignLabelWithHint: true,
      border: border,
      enabledBorder: border,
      focusedBorder: border.copyWith(
        borderSide: BorderSide(color: Colors.grey.shade400),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
      // Subtle spinner suffix while data loads, without blocking the field.
      suffixIcon: loading
          ? const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          : null,
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

  Widget _countryFieldValueLabel(
    BuildContext context,
    MarketCountry c,
    TextStyle textStyle,
  ) {
    final iso2 = _countryIso2(c);
    final flag = countryFlagEmojiFromIso2(iso2);
    final label = _countryLabel(c).toUpperCase();

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
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textStyle,
          ),
        ),
      ],
    );
  }

  Widget _fixedSelectorField(Widget child) {
    return SizedBox(height: 84, child: child);
  }

  String _eventDisplayLabel(MarketEvent e) => _eventLabel(e).toUpperCase();

  String _circuitDisplayLabel(MarketCircuit c) => _circuitLabel(c).toUpperCase();

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
    final selectorTextStyle = _selectorValueTextStyle(context);
    final selectorLabelStyle = _selectorLabelTextStyle(context);
    final sheetTheme = baseTheme.copyWith(
      colorScheme: baseTheme.colorScheme.copyWith(
        primary: MasliveTokens.text,
        secondary: MasliveTokens.text,
      ),
      inputDecorationTheme: baseTheme.inputDecorationTheme.copyWith(
        filled: true,
        fillColor: MasliveTokens.surface,
        labelStyle: selectorLabelStyle,
        floatingLabelStyle: selectorLabelStyle,
        floatingLabelBehavior: FloatingLabelBehavior.always,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 20,
        ),
      ),
    );

    return StreamBuilder<VisibleCircuitsIndex>(
      stream: widget.service.watchVisibleCircuitsIndex(),
      builder: (context, visibleSnap) {
        // Index is loaded in the background — never blocks the UI.
        // Dropdowns are usable immediately; items are filtered once index arrives.
        final indexReady = visibleSnap.hasData;
        final indexLoading = !visibleSnap.hasData && !visibleSnap.hasError;
        final visibleIndexHasError = visibleSnap.hasError;

        final visibleIndex = visibleSnap.data;
        final visibleCountryIds = indexReady
            ? (visibleIndex?.countryIds ?? const <String>{})
            : const <String>{};
        final visibleEventIds =
            (!indexReady || _country == null)
            ? const <String>{}
            : visibleIndex?.eventIdsForCountry(_country!.id) ??
                  const <String>{};

        return Theme(
          data: sheetTheme,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {},
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
                    if (widget.title.trim().isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          gradient: _headerGradient,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: <BoxShadow>[
                            BoxShadow(
                              color: const Color(0xFF9B6BFF).withValues(
                                alpha: 0.22,
                              ),
                              blurRadius: 18,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.map_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                widget.title,
                                style: const TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: 0.3,
                                  height: 1.1,
                                ),
                              ),
                            ),
                            // Subtle pulsing indicator while index loads
                            if (indexLoading)
                              const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white70,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (visibleIndexHasError)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          "Mode dégradé — toutes les cartes sont affichées.",
                          style: TextStyle(
                            fontSize: 12,
                            color: MasliveTokens.textSoft,
                          ),
                        ),
                      ),
                    const SizedBox(height: 8),

                    // ── PAYS ─────────────────────────────────────────────
                    StreamBuilder<List<MarketCountry>>(
                      stream: widget.service.watchCountries(),
                      builder: (context, snap) {
                        final countryLoading =
                            snap.connectionState == ConnectionState.waiting &&
                            !snap.hasData;
                        final all = snap.data ?? const <MarketCountry>[];

                        // Filter to visible countries only when index is ready.
                        // While index loads, show the full list so the user
                        // doesn't wait.
                        final items = (indexReady && visibleCountryIds.isNotEmpty)
                            ? all
                                  .where((c) => visibleCountryIds.contains(c.id))
                                  .toList(growable: true)
                            : all.toList(growable: true);

                        items.sort(
                          (a, b) =>
                              _countrySortKey(a).compareTo(_countrySortKey(b)),
                        );

                        if (widget.disableKeyboardInput) {
                          final selectedId = _country?.id;
                          final currentValue =
                              items.any((c) => c.id == selectedId)
                              ? selectedId
                              : null;

                          return _fixedSelectorField(
                            DropdownButtonFormField<String>(
                              initialValue: currentValue,
                              isExpanded: true,
                              isDense: false,
                              style: selectorTextStyle,
                              menuMaxHeight: 420,
                              borderRadius: BorderRadius.circular(14),
                              dropdownColor: MasliveTokens.surface,
                              decoration: _selectorDecoration(
                                'PAYS',
                                loading: countryLoading,
                              ),
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
                                        vertical: 8,
                                      ),
                                      child: _countryOptionLabel(context, c),
                                    ),
                                  ),
                              ],
                              selectedItemBuilder: (context) => [
                                for (final c in items)
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: _countryFieldValueLabel(
                                      context,
                                      c,
                                      selectorTextStyle,
                                    ),
                                  ),
                              ],
                              onChanged: items.isEmpty
                                  ? null
                                  : (id) {
                                      if (id == null) return;
                                      final selected = items.firstWhere(
                                        (c) => c.id == id,
                                      );
                                      setState(() {
                                        _country = selected;
                                        _countryHasSelectedOption = true;
                                        _countryCtrl.text =
                                            _countryLabel(selected);
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
                            ),
                          );
                        }

                        return _fixedSelectorField(
                          MarketCountryAutocompleteField(
                            items: items,
                            controller: _countryCtrl,
                            labelText: 'Pays',
                            hintText: 'Rechercher un pays…',
                            enabled: !countryLoading || items.isNotEmpty,
                            strictSelection: widget.disableKeyboardInput,
                            onSelected: (c) {
                              setState(() {
                                _country = c;
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
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 12),

                    // ── ÉVÉNEMENT ─────────────────────────────────────────
                    StreamBuilder<List<MarketEvent>>(
                      stream: _country == null
                          ? const Stream.empty()
                          : widget.service.watchEvents(
                              countryId: _country!.id,
                            ),
                      builder: (context, snap) {
                        final eventLoading =
                            _country != null &&
                            snap.connectionState == ConnectionState.waiting &&
                            !snap.hasData;
                        final all = snap.data ?? const <MarketEvent>[];

                        // Filter by visible index only when index is ready and
                        // we have event ids for this country. Otherwise show all.
                        final items = (indexReady &&
                                visibleEventIds.isNotEmpty &&
                                _country != null)
                            ? all
                                  .where(
                                    (e) => visibleEventIds.contains(e.id),
                                  )
                                  .toList(growable: false)
                            : all;

                        final selectedId = _event?.id;
                        final currentValue =
                            items.any((e) => e.id == selectedId)
                            ? selectedId
                            : null;

                        // Use DropdownButtonFormField for both keyboard modes —
                        // DropdownMenu has overlay positioning bugs on web desktop
                        // when rendered inside a ModalBottomSheet.
                        return _fixedSelectorField(
                          DropdownButtonFormField<String>(
                            initialValue: currentValue,
                            isExpanded: true,
                            isDense: false,
                            style: selectorTextStyle,
                            menuMaxHeight: 420,
                            borderRadius: BorderRadius.circular(14),
                            dropdownColor: MasliveTokens.surface,
                            decoration: _selectorDecoration(
                              'ÉVÉNEMENT',
                              loading: eventLoading,
                            ),
                            items: [
                              for (final e in items)
                                DropdownMenuItem<String>(
                                  value: e.id,
                                  child: Text(
                                    _eventDisplayLabel(e),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: selectorTextStyle,
                                  ),
                                ),
                            ],
                            onChanged:
                                (_country == null || items.isEmpty)
                                ? null
                                : (id) {
                                    if (id == null) return;
                                    final selected = items.firstWhere(
                                      (e) => e.id == id,
                                    );
                                    setState(() {
                                      _event = selected;
                                      _eventHasSelectedOption = true;
                                      _updatingControllers = true;
                                      _eventCtrl.text =
                                          _eventDisplayLabel(selected);
                                      _updatingControllers = false;
                                      _circuit = null;
                                      _circuitCtrl.clear();
                                      _circuitHasSelectedOption = false;
                                      _layerIds = <String>{};
                                      _layerSelectionInitialized = false;
                                    });
                                  },
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 12),

                    // ── CIRCUIT ───────────────────────────────────────────
                    StreamBuilder<List<MarketCircuit>>(
                      stream: (_country == null || _event == null)
                          ? const Stream.empty()
                          : widget.service.watchCircuits(
                              countryId: _country!.id,
                              eventId: _event!.id,
                            ),
                      builder: (context, snap) {
                        final circuitLoading =
                            _country != null &&
                            _event != null &&
                            snap.connectionState == ConnectionState.waiting &&
                            !snap.hasData;
                        final allCircuits = snap.data ?? const <MarketCircuit>[];

                        // Only show published, visible circuits.
                        // Filtered entirely client-side — no index needed.
                        final items = allCircuits
                            .where(
                              (c) =>
                                  c.isVisible == true &&
                                  c.status == 'published',
                            )
                            .toList(growable: false);

                        final selectedId = _circuit?.id;
                        final currentValue =
                            items.any((c) => c.id == selectedId)
                            ? selectedId
                            : null;

                        return _fixedSelectorField(
                          DropdownButtonFormField<String>(
                            initialValue: currentValue,
                            isExpanded: true,
                            isDense: false,
                            style: selectorTextStyle,
                            menuMaxHeight: 420,
                            borderRadius: BorderRadius.circular(14),
                            dropdownColor: MasliveTokens.surface,
                            decoration: _selectorDecoration(
                              'CIRCUIT',
                              loading: circuitLoading,
                            ),
                            items: [
                              for (final c in items)
                                DropdownMenuItem<String>(
                                  value: c.id,
                                  child: Text(
                                    _circuitDisplayLabel(c),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: selectorTextStyle,
                                  ),
                                ),
                            ],
                            onChanged:
                                (_country == null ||
                                    _event == null ||
                                    items.isEmpty)
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
                                      _circuitHasSelectedOption = true;
                                      _updatingControllers = true;
                                      _circuitCtrl.text =
                                          _circuitDisplayLabel(selected);
                                      _updatingControllers = false;
                                      _layerIds = <String>{};
                                      _layerSelectionInitialized = false;
                                    });
                                  },
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 12),
                    if (widget.showLayers) _buildLayerChooser(),
                    if (widget.showLayers) const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed:
                          (_country != null &&
                              _event != null &&
                              _circuit != null)
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
          _layerIds = layers
              .where((l) => l.isEnabled)
              .expand(_layerFilterTokens)
              .toSet();
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
              final enabled = _isLayerSelected(layer);
              return CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                value: enabled,
                onChanged: (v) {
                  setState(() {
                    final tokens = _layerFilterTokens(layer);
                    if (v == true) {
                      _layerIds.addAll(tokens);
                    } else {
                      _layerIds.removeAll(tokens);
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
