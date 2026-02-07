import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MapMarketProjectsPage extends StatefulWidget {
  const MapMarketProjectsPage({super.key});

  @override
  State<MapMarketProjectsPage> createState() => _MapMarketProjectsPageState();
}

class _MapMarketProjectsPageState extends State<MapMarketProjectsPage> {
  final _db = FirebaseFirestore.instance;

  String? _countryId;
  String? _eventId;

  @override
  Widget build(BuildContext context) {
    Query query = _db.collection('map_projects').orderBy('updatedAt', descending: true);

    if (_countryId != null && _countryId!.isNotEmpty) {
      query = query.where('countryId', isEqualTo: _countryId);
    }
    if (_eventId != null && _eventId!.isNotEmpty) {
      query = query.where('eventId', isEqualTo: _eventId);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('MapMarket — Cartes & Circuits'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Créer un circuit',
            onPressed: _createProjectDialog,
          )
        ],
      ),
      body: Column(
        children: [
          _filtersBar(),
          const Divider(height: 1),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: query.snapshots(),
              builder: (context, snap) {
                if (snap.hasError) return Center(child: Text('Erreur: ${snap.error}'));
                if (!snap.hasData) return const Center(child: CircularProgressIndicator());

                final docs = snap.data!.docs;
                if (docs.isEmpty) {
                  return const Center(child: Text('Aucun projet MapMarket.'));
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: docs.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final d = docs[i];
                    final m = d.data() as Map<String, dynamic>;

                    final name = (m['name'] ?? d.id).toString();
                    final status = (m['status'] ?? 'draft').toString();
                    final visible = (m['isVisible'] ?? false) == true;
                    final publishAt = m['publishAt'];

                    return Card(
                      child: ListTile(
                        leading: Icon(
                          visible ? Icons.public : Icons.lock_outline,
                          color: visible ? Colors.green : Colors.grey,
                        ),
                        title: Text(name),
                        subtitle: Text(
                          'status: $status'
                          '${publishAt != null ? ' • planifié' : ''}',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.pushNamed(
                            context,
                            '/admin/mapmarket/wizard',
                            arguments: {'projectId': d.id},
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
      ),
    );
  }

  Widget _filtersBar() {
    // Tu peux remplacer par tes dropdowns réels (countries/events depuis Firestore)
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 220,
            child: TextField(
              decoration: const InputDecoration(
                labelText: 'Pays (countryId)',
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => setState(() => _countryId = v.trim().isEmpty ? null : v.trim()),
            ),
          ),
          SizedBox(
            width: 220,
            child: TextField(
              decoration: const InputDecoration(
                labelText: 'Événement (eventId)',
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => setState(() => _eventId = v.trim().isEmpty ? null : v.trim()),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _createProjectDialog() async {
    final nameCtrl = TextEditingController();
    final countryCtrl = TextEditingController(text: _countryId ?? '');
    final eventCtrl = TextEditingController(text: _eventId ?? '');

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800, maxHeight: 700),
          child: AlertDialog(
            title: const Text('Créer un circuit (MapMarket)'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: countryCtrl,
                  decoration: const InputDecoration(labelText: 'countryId'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: eventCtrl,
                  decoration: const InputDecoration(labelText: 'eventId'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Nom du circuit'),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Annuler'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Créer'),
              ),
            ],
          ),
        ),
      ),
    );

    if (ok != true) return;

    final projectId = await _createProject(
      name: nameCtrl.text.trim().isEmpty ? 'Nouveau circuit' : nameCtrl.text.trim(),
      countryId: countryCtrl.text.trim(),
      eventId: eventCtrl.text.trim(),
    );

    if (!mounted) return;

    Navigator.pushNamed(
      context,
      '/admin/mapmarket/wizard',
      arguments: {'projectId': projectId},
    );
  }

  Future<String> _createProject({
    required String name,
    required String countryId,
    required String eventId,
  }) async {
    final ref = _db.collection('map_projects').doc();

    final now = FieldValue.serverTimestamp();

    // Projet créé immédiatement (folder logique)
    await ref.set({
      'name': name,
      'countryId': countryId,
      'eventId': eventId,
      'status': 'draft',
      'isVisible': false,
      'styleUrl': 'mapbox://styles/mapbox/streets-v12',
      'perimeter': [],
      'route': [],
      'createdAt': now,
      'updatedAt': now,
    });

    // Création auto des layers (tu peux adapter)
    final layers = [
      {'type': 'tracking', 'label': 'Tracking', 'iconKey': 'tracking', 'zIndex': 10},
      {'type': 'visited', 'label': 'Visité', 'iconKey': 'visited', 'zIndex': 20},
      {'type': 'full', 'label': 'Full', 'iconKey': 'full', 'zIndex': 30},
      {'type': 'assistance', 'label': 'Assistance', 'iconKey': 'assistance', 'zIndex': 40},
      {'type': 'parking', 'label': 'Parking', 'iconKey': 'parking', 'zIndex': 50},
      {'type': 'wc', 'label': 'WC', 'iconKey': 'wc', 'zIndex': 60},
    ];

    final batch = _db.batch();
    for (final l in layers) {
      final doc = ref.collection('layers').doc(l['type'] as String);
      batch.set(doc, {
        ...l,
        'isVisibleByDefault': true,
        'isEditable': true,
      });
    }
    await batch.commit();

    return ref.id;
  }
}
