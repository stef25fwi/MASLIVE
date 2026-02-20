import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/market_circuit_models.dart';
import '../models/market_country.dart';
import '../services/market_map_service.dart';
import '../ui/wizard/pro_circuit_wizard_page.dart';

String _iso2ToFlagEmoji(String iso2) {
  final code = iso2.trim().toUpperCase();
  if (code.length != 2) return '🏳️';
  const base = 0x1F1E6;
  final first = base + (code.codeUnitAt(0) - 65);
  final second = base + (code.codeUnitAt(1) - 65);
  return String.fromCharCode(first) + String.fromCharCode(second);
}

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
            'startDate': Timestamp.fromDate(input.date),
            'endDate': Timestamp.fromDate(input.date),
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
      }

      final ref = _firestore.collection('map_projects').doc();
      await ref.set({
        'name': input.name.trim(),
        'countryId': countryId,
        'countryName': input.countryName,
        'countryIso2': input.countryIso2,
        'eventId': eventId,
        'eventName': input.eventName,
        'eventDate': Timestamp.fromDate(input.date),
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
          builder: (_) => ProCircuitWizardPage(projectId: ref.id),
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
        builder: (_) => ProCircuitWizardPage(projectId: projectId),
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
  final String countryName;
  final String? countryIso2;
  final String eventId;
  final String eventName;
  final String name;
  final DateTime date;

  const _NewCircuitInput({
    required this.countryId,
    required this.countryName,
    required this.countryIso2,
    required this.eventId,
    required this.eventName,
    required this.name,
    required this.date,
  });
}

class _NewCircuitInputDialog extends StatefulWidget {
  const _NewCircuitInputDialog();

  @override
  State<_NewCircuitInputDialog> createState() => _NewCircuitInputDialogState();
}

class _NewCircuitInputDialogState extends State<_NewCircuitInputDialog> {
  final MarketMapService _marketMapService = MarketMapService();

  final _countryController = TextEditingController();
  final _eventController = TextEditingController();
  final _nameController = TextEditingController();

  MarketCountry? _selectedCountry;
  DateTime _date = DateTime.now();
  String _countryQuery = '';

  @override
  void dispose() {
    _countryController.dispose();
    _eventController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  bool get _isValid {
    return _selectedCountry != null &&
        _eventController.text.trim().isNotEmpty &&
        _nameController.text.trim().isNotEmpty;
  }

  String _eventName() => _eventController.text.trim();

  String _eventId() {
    final name = _eventName();
    if (name.isEmpty) return '';
    return MarketMapService.slugify(name);
  }

  String _countryLabel(MarketCountry c) {
    final name = c.name.trim().isEmpty ? c.id : c.name.trim();
    return name;
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

  String _formatDate(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _date = DateTime(picked.year, picked.month, picked.day);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: SizedBox(
        width: 520,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: StreamBuilder<List<MarketCountry>>(
            stream: _marketMapService.watchCountries(),
            builder: (context, snapshot) {
              final countries = snapshot.data ?? const <MarketCountry>[];
              final filtered = countries
                  .where((c) => _countryLabel(c)
                      .toLowerCase()
                      .contains(_countryQuery.toLowerCase()))
                  .toList()
                ..sort((a, b) => _countryLabel(a).compareTo(_countryLabel(b)));

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Nouveau circuit',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _countryController,
                    decoration: InputDecoration(
                      labelText: 'Pays',
                      hintText: 'Rechercher un pays…',
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: Padding(
                        padding: const EdgeInsets.only(left: 12, right: 8),
                        child: Center(
                          widthFactor: 1,
                          child: Text(
                            _selectedCountry == null
                                ? '🏳️'
                                : _iso2ToFlagEmoji(_countryCodeFor(_selectedCountry!)),
                          ),
                        ),
                      ),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _countryQuery = value;
                        _selectedCountry = null;
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 180,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: filtered.isEmpty
                        ? Center(
                            child: Text(
                              'Aucun pays trouvé',
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          )
                        : ListView.separated(
                            itemCount: filtered.length,
                            separatorBuilder: (context, index) => Divider(
                              height: 1,
                              color: Colors.grey.shade200,
                            ),
                            itemBuilder: (_, i) {
                              final c = filtered[i];
                              final iso2 = _countryCodeFor(c);
                              return ListTile(
                                dense: true,
                                leading: Text(
                                  _iso2ToFlagEmoji(iso2),
                                  style: const TextStyle(fontSize: 18),
                                ),
                                title: Text(_countryLabel(c)),
                                subtitle: iso2.isEmpty ? null : Text(iso2),
                                onTap: () {
                                  setState(() {
                                    _selectedCountry = c;
                                    _countryController.text = _countryLabel(c);
                                    _countryQuery = _countryLabel(c);
                                  });
                                },
                              );
                            },
                          ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _eventController,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: 'Événement',
                      hintText: 'Ex: Carnaval, Festival…',
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _nameController,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: 'Nom du circuit',
                      hintText: 'Ex: Défilé Centre-ville…',
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Text('Date : ${_formatDate(_date)}'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: _pickDate,
                        icon: const Icon(Icons.calendar_month),
                        label: const Text('Choisir'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: !_isValid
                          ? null
                          : () {
                              final country = _selectedCountry;
                              if (country == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Sélectionnez un pays.'),
                                  ),
                                );
                                return;
                              }

                              Navigator.pop(
                                context,
                                _NewCircuitInput(
                                  countryId: country.id.trim(),
                                  countryName: _countryLabel(country),
                                  countryIso2: _countryCodeFor(country),
                                  eventId: _eventId(),
                                  eventName: _eventName(),
                                  name: _nameController.text.trim(),
                                  date: _date,
                                ),
                              );
                            },
                      child: const Text('Continuer'),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
