import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../pages/circuit_editor_workflow_page.dart';

class MapProjectsLibraryPage extends StatefulWidget {
  const MapProjectsLibraryPage({super.key});

  @override
  State<MapProjectsLibraryPage> createState() => _MapProjectsLibraryPageState();
}

class _MapProjectsLibraryPageState extends State<MapProjectsLibraryPage> {
  String? _selectedMapId;
  String? _selectedMapTitle;

  @override
  Widget build(BuildContext context) {
    final db = FirebaseFirestore.instance;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bibliothèque de cartes'),
        actions: [
          if (_selectedMapId != null)
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.teal.shade600,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle, color: Colors.white, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    _selectedMapTitle ?? 'Map sélectionnée',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedMapId = null;
                        _selectedMapTitle = null;
                      });
                    },
                    child: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ],
              ),
            ),
          IconButton(
            tooltip: 'Nouveau',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const CircuitEditorWorkflowPage(),
              ),
            ),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: Column(
        children: [
          // Banner d'instructions
          if (_selectedMapId == null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.teal.shade50, Colors.cyan.shade50],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border(
                  bottom: BorderSide(color: Colors.teal.shade200, width: 2),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.teal.shade600,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.touch_app,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '🎯 Sélectionnez une map',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.teal,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Cliquez sur une carte pour l\'utiliser avec les outils et le wizard',
                          style: TextStyle(fontSize: 13, color: Colors.black87),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          // Liste des maps
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: db
                  .collection('map_projects')
                  .orderBy('updatedAt', descending: true)
                  .snapshots(),
              builder: (context, snap) {
                if (snap.hasError) {
                  return Center(child: Text('Erreur: ${snap.error}'));
                }
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final mapProjectDocs = snap.data?.docs ?? const [];

                // Charger aussi les cartes POI
                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: db
                      .collection('poi_maps')
                      .orderBy('updatedAt', descending: true)
                      .snapshots(),
                  builder: (context, poiSnap) {
                    if (poiSnap.hasError) {
                      return Center(
                        child: Text('Erreur POI: ${poiSnap.error}'),
                      );
                    }

                    final poiMapDocs = poiSnap.data?.docs ?? const [];
                    final docs = [...mapProjectDocs, ...poiMapDocs];

                    if (docs.isEmpty) {
                      return const Center(
                        child: Text('Aucune carte enregistrée.'),
                      );
                    }

                    // Groupement par pays
                    final groups =
                        <
                          String,
                          List<QueryDocumentSnapshot<Map<String, dynamic>>>
                        >{};
                    for (final d in docs) {
                      final m = d.data();
                      final country = (m['country'] as String?) ?? 'Autre';
                      groups.putIfAbsent(country, () => []).add(d);
                    }

                    final keys = groups.keys.toList()..sort();

                    return ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: keys.length,
                      itemBuilder: (context, index) {
                        final country = keys[index];
                        final items = groups[country]!;
                        return Card(
                          child: ExpansionTile(
                            title: Row(
                              children: [
                                const Icon(Icons.location_on_outlined),
                                const SizedBox(width: 8),
                                Text(
                                  country,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade100,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '${items.length}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue.shade900,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            children: items.map((d) {
                              final m = d.data();
                              final title =
                                  (m['title'] ?? m['name'] as String?) ??
                                  'Sans titre';
                              final status =
                                  (m['status'] as String?) ?? 'draft';
                              final poiCount = (m['poiCount'] as int?) ?? 0;
                              final isSelected = _selectedMapId == d.id;
                              final isPOIMap =
                                  d.reference.parent.id == 'poi_maps';

                              return Container(
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? Colors.teal.shade50
                                      : null,
                                  border: isSelected
                                      ? Border.all(
                                          color: Colors.teal.shade600,
                                          width: 2,
                                        )
                                      : null,
                                ),
                                child: ListTile(
                                  leading: Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? Colors.teal.shade600
                                          : (isPOIMap
                                                ? Colors.purple.shade300
                                                : Colors.grey.shade300),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      isSelected
                                          ? Icons.check_circle
                                          : Icons.map,
                                      color: isSelected
                                          ? Colors.white
                                          : Colors.grey.shade700,
                                    ),
                                  ),
                                  title: Text(
                                    title,
                                    style: TextStyle(
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                  ),
                                  subtitle: Row(
                                    children: [
                                      Text('Statut: $status'),
                                      if (poiCount > 0) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 4,
                                            vertical: 1,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.orange.shade100,
                                            borderRadius: BorderRadius.circular(
                                              3,
                                            ),
                                          ),
                                          child: Text(
                                            '$poiCount POI',
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: Colors.orange.shade900,
                                            ),
                                          ),
                                        ),
                                      ],
                                      if (isPOIMap) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 4,
                                            vertical: 1,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.purple.shade100,
                                            borderRadius: BorderRadius.circular(
                                              3,
                                            ),
                                          ),
                                          child: Text(
                                            'POI',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.purple.shade900,
                                            ),
                                          ),
                                        ),
                                      ],
                                      if (isSelected) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.teal.shade600,
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                          child: const Text(
                                            'EN COURS',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  trailing: Icon(
                                    isSelected
                                        ? Icons.radio_button_checked
                                        : Icons.radio_button_unchecked,
                                    color: isSelected
                                        ? Colors.teal.shade600
                                        : Colors.grey,
                                  ),
                                  onTap: () {
                                    setState(() {
                                      if (_selectedMapId == d.id) {
                                        _selectedMapId = null;
                                        _selectedMapTitle = null;
                                      } else {
                                        _selectedMapId = d.id;
                                        _selectedMapTitle = title;
                                      }
                                    });
                                  },
                                ),
                              );
                            }).toList(),
                          ),
                        );
                      },
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
