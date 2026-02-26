import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/market_circuit.dart';
import '../models/market_country.dart';
import '../models/market_event.dart';
import '../services/market_map_service.dart';
import '../ui/snack/top_snack_bar.dart';
import '../ui/widgets/country_autocomplete_field.dart';

class MapMarketProjectsPage extends StatefulWidget {
  const MapMarketProjectsPage({super.key});

  @override
  State<MapMarketProjectsPage> createState() => _MapMarketProjectsPageState();
}

class _MapMarketProjectsPageState extends State<MapMarketProjectsPage> {
  final _db = FirebaseFirestore.instance;
  final MarketMapService _service = MarketMapService();

  MarketCountry? _country;
  MarketEvent? _event;
  MarketCircuit? _circuit;

  final TextEditingController _countryCtrl = TextEditingController();

  bool _defaultCountryApplied = false;
  bool _defaultEventApplied = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MapMarket — Cartes & Circuits'),
      ),
      body: Column(
        children: [
          _filtersBar(),
          const Divider(height: 1),
          Expanded(
            child: _buildCircuitsList(),
          ),
        ],
      ),
    );
  }

  Widget _filtersBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(width: 320, child: _buildCountryAutocomplete()),
          SizedBox(width: 320, child: _buildEventDropdown()),
          SizedBox(width: 320, child: _buildCircuitDropdown()),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _countryCtrl.dispose();
    super.dispose();
  }

  Widget _buildCountryAutocomplete() {
    return StreamBuilder<List<MarketCountry>>(
      stream: _service.watchCountries(),
      builder: (context, snap) {
        final items = snap.data ?? const <MarketCountry>[];

        // Sélection par défaut: Guadeloupe si dispo, sinon premier pays.
        if (!_defaultCountryApplied && _country == null && items.isNotEmpty) {
          final preferred = items.firstWhere(
            (c) => _countryCodeFor(c) == 'GP' ||
                c.id.toLowerCase() == 'gp' ||
                c.slug.toLowerCase() == 'guadeloupe' ||
                c.name.toLowerCase() == 'guadeloupe',
            orElse: () => items.first,
          );

          _defaultCountryApplied = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            setState(() {
              _country = preferred;
              _event = null;
              _defaultEventApplied = false;
              _countryCtrl.text = _countryDisplay(preferred);
            });
          });
        }

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
              _defaultEventApplied = false;
              if (c != null) {
                _countryCtrl.text = _countryDisplay(c);
              }
            });
          },
        );
      },
    );
  }

  Widget _buildEventDropdown() {
    if (_country == null) {
      return DropdownButtonFormField<String>(
        items: <DropdownMenuItem<String>>[],
        onChanged: null,
        decoration: const InputDecoration(
          labelText: 'Événement',
          border: OutlineInputBorder(),
        ),
      );
    }

    return StreamBuilder<List<MarketEvent>>(
      stream: _service.watchEvents(countryId: _country!.id),
      builder: (context, snap) {
        final items = snap.data ?? const <MarketEvent>[];

        // Sélection par défaut: premier événement du pays (le stream est déjà trié).
        if (!_defaultEventApplied && _event == null && items.isNotEmpty) {
          _defaultEventApplied = true;
          final preferred = items.first;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            setState(() => _event = preferred);
          });
        }

        final selectedId = _event?.id;
        final value = items.any((e) => e.id == selectedId) ? selectedId : null;

        return DropdownButtonFormField<String>(
          initialValue: value,
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
                countryId: _country!.id,
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
    );
  }

  Widget _buildCircuitDropdown() {
    if (_country == null || _event == null) {
      return DropdownButtonFormField<String>(
        items: <DropdownMenuItem<String>>[],
        onChanged: null,
        decoration: const InputDecoration(
          labelText: 'Circuit',
          border: OutlineInputBorder(),
        ),
      );
    }

    return StreamBuilder<List<MarketCircuit>>(
      stream: _service.watchCircuits(countryId: _country!.id, eventId: _event!.id),
      builder: (context, snap) {
        final items = snap.data ?? const <MarketCircuit>[];
        const allValue = '__all__';

        final selectedId = _circuit?.id;
        final value = (selectedId != null && items.any((c) => c.id == selectedId)) ? selectedId : allValue;

        return DropdownButtonFormField<String>(
          initialValue: value,
          decoration: const InputDecoration(
            labelText: 'Circuit',
            border: OutlineInputBorder(),
          ),
          items: [
            const DropdownMenuItem(value: allValue, child: Text('Tous les circuits')),
            for (final c in items) DropdownMenuItem(value: c.id, child: Text(c.name)),
          ],
          onChanged: (id) {
            if (id == null) return;
            if (id == allValue) {
              setState(() => _circuit = null);
              return;
            }
            final matches = items.where((c) => c.id == id);
            if (matches.isEmpty) return;
            setState(() => _circuit = matches.first);
          },
        );
      },
    );
  }

  Widget _buildCircuitsList() {
    final country = _country;
    final event = _event;
    final circuitFilterId = _circuit?.id;

    if (country == null || event == null) {
      return const Center(
        child: Text('Choisis un pays et un événement pour afficher les circuits.'),
      );
    }

    return StreamBuilder<List<MarketCircuit>>(
      stream: _service.watchCircuits(countryId: country.id, eventId: event.id),
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(child: Text('Erreur: ${snap.error}'));
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        var circuits = snap.data!;
        if (circuitFilterId != null) {
          circuits = circuits.where((c) => c.id == circuitFilterId).toList();
        }

        if (circuits.isEmpty) {
          return const Center(child: Text('Aucun circuit pour cet événement.'));
        }

        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: circuits.length,
          separatorBuilder: (context, index) => const SizedBox(height: 10),
          itemBuilder: (context, i) {
            final c = circuits[i];
            final isVisible = c.isVisible == true;
            final status = c.status;

            return Card(
              child: ListTile(
                leading: Icon(
                  isVisible ? Icons.wifi : Icons.wifi_off,
                  color: isVisible ? Colors.green : Colors.grey,
                ),
                title: Text(c.name),
                subtitle: Text('status: $status\nmarketMap/${country.id}/events/${event.id}/circuits/${c.id}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('On line'),
                    const SizedBox(width: 8),
                    Switch(
                      value: isVisible,
                      onChanged: (v) async {
                        try {
                          await _db
                              .collection('marketMap')
                              .doc(country.id)
                              .collection('events')
                              .doc(event.id)
                              .collection('circuits')
                              .doc(c.id)
                              .update({'isVisible': v});
                        } catch (e) {
                          if (!context.mounted) return;
                          TopSnackBar.showMessage(
                            context,
                            '❌ Erreur visibilité: $e',
                            isError: true,
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _countryDisplay(MarketCountry c) {
    final code = _countryCodeFor(c);
    final flag = _flagEmoji(code);
    final name = c.name.trim().isEmpty ? c.id : c.name.trim();
    final upperName = name.toUpperCase();
    return code.isEmpty ? '$flag $upperName' : '$flag $upperName $code';
  }

  String _countryCodeFor(MarketCountry c) {
    final id = c.id.trim();
    if (id.length == 2) return id.toUpperCase();

    final slug = c.slug.trim().toLowerCase();
    final name = c.name.trim().toLowerCase();
    const known = <String, String>{
      'guadeloupe': 'GP',
      'martinique': 'MQ',
      'guyane': 'GF',
      'reunion': 'RE',
      'réunion': 'RE',
      'saint-martin': 'MF',
      'saint martin': 'MF',
    };

    return known[slug] ?? known[name] ?? '';
  }

  String _flagEmoji(String code) {
    final c = code.trim().toUpperCase();
    if (c.length != 2) return '🏳️';

    final a = c.codeUnitAt(0);
    final b = c.codeUnitAt(1);
    if (a < 65 || a > 90 || b < 65 || b > 90) return '🏳️';

    final base = 0x1F1E6;
    return String.fromCharCode(base + (a - 65)) + String.fromCharCode(base + (b - 65));
  }
}
