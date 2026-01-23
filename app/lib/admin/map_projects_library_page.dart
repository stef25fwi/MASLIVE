import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../pages/circuit_editor_workflow_page.dart';

class MapProjectsLibraryPage extends StatelessWidget {
  const MapProjectsLibraryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final db = FirebaseFirestore.instance;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bibliothèque de cartes'),
        actions: [
          IconButton(
            tooltip: 'Nouveau',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CircuitEditorWorkflowPage()),
            ),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: db
            .collection('map_projects')
            .orderBy('year', descending: true)
            .orderBy('updatedAt', descending: true)
            .snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text('Erreur: ${snap.error}'));
          }
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snap.data?.docs ?? const [];
          if (docs.isEmpty) {
            return const Center(child: Text('Aucune carte enregistrée.'));
          }

          // Groupement simple par année / pays / commune
          final groups = <String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>{};
          for (final d in docs) {
            final m = d.data();
            final year = m['year']?.toString() ?? '—';
            final country = (m['country'] as String?) ?? '—';
            final commune = (m['commune'] as String?) ?? '—';
            final key = '$year / $country / $commune';
            groups.putIfAbsent(key, () => []).add(d);
          }

          final keys = groups.keys.toList();

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: keys.length,
            itemBuilder: (context, index) {
              final key = keys[index];
              final items = groups[key]!;
              return Card(
                child: ExpansionTile(
                  title: Text(key, style: const TextStyle(fontWeight: FontWeight.w900)),
                  children: items.map((d) {
                    final m = d.data();
                    final title = (m['title'] as String?) ?? 'Sans titre';
                    final status = (m['status'] as String?) ?? 'draft';
                    return ListTile(
                      title: Text(title),
                      subtitle: Text('Statut: $status'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => CircuitEditorWorkflowPage(projectId: d.id)),
                        );
                      },
                    );
                  }).toList(),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
