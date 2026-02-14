import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/market_circuit_models.dart';
import '../models/market_country.dart';
import '../models/market_event.dart';
import '../services/market_map_service.dart';
import '../utils/country_flag.dart';
import 'circuit_wizard_pro_page.dart';

class CircuitWizardEntryPage extends StatefulWidget {
  const CircuitWizardEntryPage({super.key});

  @override
  State<CircuitWizardEntryPage> createState() => _CircuitWizardEntryPageState();
}

class _CircuitWizardEntryPageState extends State<CircuitWizardEntryPage> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Création de Circuits'), elevation: 0),
      body: Column(
        children: [
          // Header
          Container(
            color: Colors.blue.withValues(alpha: 0.05),
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  '🗺️ Wizard Circuit Pro',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Créez des circuits professionnels avec périmètre, tracé, POI et validation automatique',
                  style: TextStyle(color: Colors.grey, fontSize: 14),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: _createNewProject,
                  icon: const Icon(Icons.add_circle),
                  label: const Text('+ Nouveau Circuit'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Projets en cours (brouillons)
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('map_projects')
                  .where('uid', isEqualTo: _auth.currentUser?.uid ?? '')
                  .orderBy('updatedAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error, size: 48, color: Colors.red),
                        const SizedBox(height: 16),
                        Text('Erreur: ${snapshot.error}'),
                      ],
                    ),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final projects =
                    snapshot.data?.docs
                        .map((doc) => CircuitProject.fromFirestore(doc))
                        .toList() ??
                    [];

                if (projects.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inbox_outlined,
                          size: 64,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Aucun circuit',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Créez votre premier circuit en cliquant ci-dessus',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: projects.length,
                  itemBuilder: (context, index) {
                    final project = projects[index];
                    return _buildProjectCard(project);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProjectCard(CircuitProject project) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: project.status == 'published'
                ? Colors.green.withValues(alpha: 0.2)
                : Colors.orange.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            project.status == 'published' ? Icons.check_circle : Icons.edit,
            color: project.status == 'published' ? Colors.green : Colors.orange,
          ),
        ),
        title: Text(
          project.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              '${project.countryId} • ${project.eventId}',
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              children: [
                Chip(
                  label: Text(
                    project.status == 'published' ? '✅ Publié' : '✏️ Brouillon',
                  ),
                  backgroundColor: project.status == 'published'
                      ? Colors.green.withValues(alpha: 0.2)
                      : Colors.orange.withValues(alpha: 0.2),
                  labelStyle: TextStyle(
                    fontSize: 10,
                    color: project.status == 'published'
                        ? Colors.green
                        : Colors.orange,
                  ),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                if (project.perimeter.isNotEmpty)
                  Chip(
                    label: Text('${project.perimeter.length} pts périm.'),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                if (project.route.isNotEmpty)
                  Chip(
                    label: Text('${project.route.length} pts tracé'),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton(
          itemBuilder: (ctx) => [
            PopupMenuItem(
              child: const Row(
                children: [
                  Icon(Icons.edit, size: 16),
                  SizedBox(width: 8),
                  Text('Continuer'),
                ],
              ),
              onTap: () => _openProject(project.id),
            ),
            if (project.status != 'published')
              PopupMenuItem(
                child: const Row(
                  children: [
                    Icon(Icons.delete, size: 16, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Supprimer', style: TextStyle(color: Colors.red)),
                  ],
                ),
                onTap: () => _deleteProject(project.id),
              ),
          ],
        ),
        onTap: () => _openProject(project.id),
      ),
    );
  }

  Future<void> _createNewProject() async {
    final input = await showDialog<_NewCircuitInput>(
      context: context,
      builder: (ctx) => _NewCircuitInputDialog(),
    );

    if (input == null || !mounted) return;

    final user = _auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vous devez être connecté.')),
      );
      return;
    }

    try {
      final countryId = input.countryId.trim();
      final eventId = input.eventId.trim();

      // Si l'utilisateur saisit un événement (editable), on s'assure que le doc existe.
      // (Sinon le wizard pro ne pourra pas charger les streams marketMap.)
      if (countryId.isNotEmpty && eventId.isNotEmpty) {
        final eventRef = _firestore
            .collection('marketMap')
            .doc(countryId)
            .collection('events')
            .doc(eventId);
        final snap = await eventRef.get();
        if (!snap.exists) {
          final eventName = input.eventName.trim().isEmpty
              ? eventId
              : input.eventName.trim();
          await eventRef.set({
            'name': eventName,
            'slug': eventId,
            'countryId': countryId,
            'startDate': null,
            'endDate': null,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
      }

      final ref = _firestore.collection('map_projects').doc();
      await ref.set({
        'name': input.name.trim(),
        'countryId': countryId,
        'eventId': eventId,
        'description': '',
        'styleUrl': '',
        'perimeter': <dynamic>[],
        'route': <dynamic>[],
        'status': 'draft',
        'uid': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) => CircuitWizardProPage(projectId: ref.id),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('❌ Erreur: $e')));
    }
  }

  void _openProject(String projectId) {
    Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => CircuitWizardProPage(projectId: projectId),
      ),
    );
  }

  Future<void> _deleteProject(String projectId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer ce circuit ?'),
        content: const Text('Cette action est irréversible.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _firestore.collection('map_projects').doc(projectId).delete();
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('✅ Circuit supprimé')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('❌ Erreur: $e')));
        }
      }
    }
  }
}

class _NewCircuitInput {
  final String countryId;
  final String eventId;
  final String eventName;
  final String name;

  const _NewCircuitInput({
    required this.countryId,
    required this.eventId,
    required this.eventName,
    required this.name,
  });
}

class _NewCircuitInputDialog extends StatefulWidget {
  @override
  State<_NewCircuitInputDialog> createState() => _NewCircuitInputDialogState();
}

class _NewCircuitInputDialogState extends State<_NewCircuitInputDialog> {
  final MarketMapService _marketMapService = MarketMapService();

  MarketCountry? _selectedCountry;
  MarketEvent? _selectedEvent;

  bool _defaultCountryApplied = false;
  bool _defaultEventApplied = false;

  final _countryController = TextEditingController();
  final _eventController = TextEditingController();
  final _nameController = TextEditingController();

  TextEditingController? _eventAutocompleteController;
  VoidCallback? _eventAutocompleteListener;

  void _attachEventAutocompleteController(TextEditingController controller) {
    if (_eventAutocompleteController == controller) return;

    final prevController = _eventAutocompleteController;
    final prevListener = _eventAutocompleteListener;
    if (prevController != null && prevListener != null) {
      prevController.removeListener(prevListener);
    }

    _eventAutocompleteController = controller;
    _eventAutocompleteListener = () {
      _eventController.value = controller.value;
    };
    controller.addListener(_eventAutocompleteListener!);
  }

  @override
  void dispose() {
    final prevEventController = _eventAutocompleteController;
    final prevEventListener = _eventAutocompleteListener;
    if (prevEventController != null && prevEventListener != null) {
      prevEventController.removeListener(prevEventListener);
    }
    _countryController.dispose();
    _eventController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  String get _countryId {
    return _selectedCountry?.id.trim() ?? _countryController.text.trim();
  }

  String get _eventName {
    final selected = _selectedEvent;
    if (selected != null) {
      final n = selected.name.trim();
      return n.isEmpty ? selected.id.trim() : n;
    }
    return _eventController.text.trim();
  }

  String get _eventId {
    final selected = _selectedEvent;
    if (selected != null) return selected.id.trim();
    final raw = _eventController.text.trim();
    if (raw.isEmpty) return '';
    return MarketMapService.slugify(raw);
  }

  bool get _isValid {
    return _countryId.isNotEmpty &&
        _eventId.isNotEmpty &&
        _nameController.text.trim().isNotEmpty;
  }

  String _countryDisplay(MarketCountry c) {
    final name = c.name.trim().isEmpty ? c.id : c.name.trim();
    return name.toUpperCase();
  }

  String _countrySuggestionLabel(MarketCountry c) {
    final iso2 = _countryCodeFor(c);
    final name = _countryDisplay(c);
    final withCode = iso2.isEmpty ? name : '$name ($iso2)';
    return formatCountryLabelWithFlag(name: withCode, iso2: iso2);
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

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nouveau circuit'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildCountryField(),
            const SizedBox(height: 12),
            _buildEventField(),
            const SizedBox(height: 12),
            TextField(
              controller: _nameController,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Nom du circuit',
                hintText: 'Ex: Circuit Côte Nord',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          onPressed: !_isValid
              ? null
              : () => Navigator.pop(
                    context,
                    _NewCircuitInput(
                      countryId: _countryId,
                      eventId: _eventId,
                      eventName: _eventName,
                      name: _nameController.text.trim(),
                    ),
                  ),
          child: const Text('Créer'),
        ),
      ],
    );
  }

  Widget _buildCountryField() {
    return StreamBuilder<List<MarketCountry>>(
      stream: _marketMapService.watchCountries(),
      builder: (context, snap) {
        if (snap.hasError) {
          return TextField(
            controller: _countryController,
            onChanged: (_) {
              setState(() {
                _selectedCountry = null;
                _selectedEvent = null;
              });
            },
            decoration: const InputDecoration(
              labelText: 'Pays',
              hintText: 'Ex: guadeloupe',
              border: OutlineInputBorder(),
              helperText:
                  'Impossible de charger la liste (marketMap). Vérifiez les droits Firestore. Saisie libre activée.',
              suffixIcon: Icon(Icons.warning_amber_rounded),
            ),
          );
        }

        final items = snap.data ?? const <MarketCountry>[];

        // Sélection par défaut: Guadeloupe si dispo, sinon premier pays.
        if (!_defaultCountryApplied &&
            _selectedCountry == null &&
            _countryController.text.trim().isEmpty &&
            items.isNotEmpty) {
          final preferred = items.firstWhere(
            (c) =>
                _countryCodeFor(c) == 'GP' ||
                c.id.toLowerCase() == 'gp' ||
                c.slug.toLowerCase() == 'guadeloupe' ||
                c.name.toLowerCase() == 'guadeloupe',
            orElse: () => items.first,
          );

          _defaultCountryApplied = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            setState(() {
              _selectedCountry = preferred;
              _selectedEvent = null;
              _defaultEventApplied = false;
              _countryController.text = _countryDisplay(preferred);
              _eventController.clear();
            });
          });
        }

        if (items.isEmpty) {
          return TextField(
            controller: _countryController,
            onChanged: (_) {
              setState(() {
                _selectedCountry = null;
                _selectedEvent = null;
              });
            },
            decoration: const InputDecoration(
              labelText: 'Pays',
              hintText: 'Ex: guadeloupe',
              border: OutlineInputBorder(),
              helperText:
                  'Aucun pays disponible dans marketMap. Saisie libre activée.',
            ),
          );
        }

        final selectedId = _selectedCountry?.id;
        final currentValue =
            items.any((c) => c.id == selectedId) ? selectedId : null;

        return DropdownButtonFormField<String>(
          initialValue: currentValue,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Pays',
            border: OutlineInputBorder(),
          ),
          items: [
            for (final c in items)
              DropdownMenuItem(
                value: c.id,
                child: Text(_countrySuggestionLabel(c)),
              ),
          ],
          onChanged: (id) {
            if (id == null) return;
            final selected = items.firstWhere(
              (c) => c.id == id,
              orElse: () => const MarketCountry(id: '', name: '', slug: ''),
            );
            if (selected.id.isEmpty) return;
            setState(() {
              _selectedCountry = selected;
              _selectedEvent = null;
              _defaultEventApplied = false;
              _countryController.text = _countryDisplay(selected);
              _eventController.clear();
            });
          },
        );
      },
    );
  }

  Widget _buildEventField() {
    final countryId = _countryId;
    if (countryId.isEmpty) {
      return TextField(
        controller: _eventController,
        enabled: false,
        decoration: const InputDecoration(
          labelText: 'Événement',
          border: OutlineInputBorder(),
          helperText: 'Sélectionnez d\'abord un pays',
        ),
      );
    }

    return StreamBuilder<List<MarketEvent>>(
      stream: _marketMapService.watchEvents(countryId: countryId),
      builder: (context, snap) {
        if (snap.hasError) {
          return TextField(
            controller: _eventController,
            onChanged: (_) {
              setState(() {
                _selectedEvent = null;
              });
            },
            decoration: const InputDecoration(
              labelText: 'Événement',
              hintText: 'Ex: TRAIL_2026',
              border: OutlineInputBorder(),
              helperText:
                  'Impossible de charger la liste (marketMap). Vérifiez les droits Firestore. Saisie libre activée.',
              suffixIcon: Icon(Icons.warning_amber_rounded),
            ),
          );
        }

        final items = snap.data ?? const <MarketEvent>[];

        // Sélection par défaut: premier événement du pays (le stream est déjà trié).
        if (!_defaultEventApplied &&
            _selectedEvent == null &&
            _eventController.text.trim().isEmpty &&
            items.isNotEmpty) {
          _defaultEventApplied = true;
          final preferred = items.first;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            setState(() {
              _selectedEvent = preferred;
              _eventController.text =
                  preferred.name.trim().isEmpty ? preferred.id : preferred.name.trim();
            });
          });
        }

        if (items.isEmpty) {
          return TextField(
            controller: _eventController,
            onChanged: (_) {
              setState(() {
                _selectedEvent = null;
              });
            },
            decoration: const InputDecoration(
              labelText: 'Événement',
              hintText: 'Ex: TRAIL_2026',
              border: OutlineInputBorder(),
              helperText:
                  'Aucun événement disponible pour ce pays dans marketMap. Saisie libre activée.',
            ),
          );
        }

        final helperText = _selectedCountry == null
            ? 'Pays saisi manuellement: vous pouvez saisir un nouvel événement'
            : 'Vous pouvez saisir un nouvel événement';

        return Autocomplete<MarketEvent>(
          initialValue: TextEditingValue(text: _eventController.text),
          displayStringForOption: (e) => e.name.trim().isEmpty ? e.id : e.name.trim(),
          optionsBuilder: (TextEditingValue value) {
            final q = value.text.trim().toLowerCase();
            if (q.isEmpty) return items;
            return items.where((e) {
              final name = (e.name.trim().isEmpty ? e.id : e.name).toLowerCase();
              return name.contains(q) || e.id.toLowerCase().contains(q);
            });
          },
          fieldViewBuilder: (context, textCtrl, focusNode, onFieldSubmitted) {
            textCtrl.value = _eventController.value;
            _attachEventAutocompleteController(textCtrl);

            return TextField(
              controller: textCtrl,
              focusNode: focusNode,
              onChanged: (_) {
                setState(() {
                  _selectedEvent = null;
                });
              },
              decoration: InputDecoration(
                labelText: 'Événement',
                hintText: 'Ex: Carnaval 2026',
                border: OutlineInputBorder(),
                helperText: helperText,
              ),
            );
          },
          optionsViewBuilder: (context, onSelected, options) {
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 4,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460, maxHeight: 260),
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: options.length,
                    itemBuilder: (context, i) {
                      final e = options.elementAt(i);
                      final name = e.name.trim().isEmpty ? e.id : e.name.trim();
                      return ListTile(
                        dense: true,
                        title: Text(name),
                        subtitle: Text(e.id),
                        onTap: () => onSelected(e),
                      );
                    },
                  ),
                ),
              ),
            );
          },
          onSelected: (e) {
            setState(() {
              _selectedEvent = e;
              _eventController.text = e.name.trim().isEmpty ? e.id : e.name.trim();
            });
          },
        );
      },
    );
  }
}
