import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/market_circuit.dart';
import '../models/market_country.dart';
import '../models/market_event.dart';
import '../services/market_map_service.dart';
import '../utils/country_flag.dart';

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

        return Autocomplete<MarketCountry>(
          initialValue: TextEditingValue(text: _countryCtrl.text),
          displayStringForOption: _countryDisplay,
          optionsBuilder: (TextEditingValue value) {
            final q = value.text.trim().toLowerCase();
            if (q.isEmpty) return items;
            return items.where((c) {
              final text = _countryDisplay(c).toLowerCase();
              return text.contains(q);
            });
          },
          fieldViewBuilder: (context, textCtrl, focusNode, onFieldSubmitted) {
            // Synchronise notre controller (pour garder la saisie si rebuild)
            textCtrl.value = _countryCtrl.value;
            textCtrl.addListener(() {
              _countryCtrl.value = textCtrl.value;
            });

            return TextField(
              controller: textCtrl,
              focusNode: focusNode,
              decoration: const InputDecoration(
                labelText: 'Pays',
                border: OutlineInputBorder(),
              ),
            );
          },
          optionsViewBuilder: (context, onSelected, options) {
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 4,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460, maxHeight: 300),
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: options.length,
                    itemBuilder: (context, i) {
                      final c = options.elementAt(i);
                      return ListTile(
                        dense: true,
                        title: Text(
                          formatCountryLabelWithFlag(
                            name: _countryDisplay(c),
                            iso2: _countryCodeFor(c),
                          ),
                        ),
                        onTap: () => onSelected(c),
                      );
                    },
                  ),
                ),
              ),
            );
          },
          onSelected: (c) {
            setState(() {
              _country = c;
              _event = null;
              _defaultEventApplied = false;
              _countryCtrl.text = _countryDisplay(c);
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
            setState(() => _event = selected);
          },
        );
      },
    );
  }

  Widget _buildCircuitsList() {
    final country = _country;
    final event = _event;

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

        final circuits = snap.data!;
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
                  isVisible ? Icons.visibility : Icons.visibility_off,
                  color: isVisible ? Colors.green : Colors.grey,
                ),
                title: Text(c.name),
                subtitle: Text('status: $status\nmarketMap/${country.id}/events/${event.id}/circuits/${c.id}'),
                trailing: Switch(
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
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('❌ Erreur visibilité: $e')),
                      );
                    }
                  },
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
