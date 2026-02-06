import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/market_circuit_models.dart';
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
      appBar: AppBar(
        title: const Text('Création de Circuits'),
        elevation: 0,
      ),
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
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
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

                final projects = snapshot.data?.docs
                    .map((doc) => CircuitProject.fromFirestore(doc))
                    .toList() ?? [];

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
            color: project.status == 'published'
                ? Colors.green
                : Colors.orange,
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
                  label: Text(project.status == 'published' ? '✅ Publié' : '✏️ Brouillon'),
                  backgroundColor:
                      project.status == 'published'
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
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => _NameInputDialog(),
    );

    if (name != null && mounted) {
      Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) => CircuitWizardProPage(
            // Pas de projectId => nouveau projet
          ),
        ),
      );
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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('✅ Circuit supprimé')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('❌ Erreur: $e')),
          );
        }
      }
    }
  }
}

class _NameInputDialog extends StatefulWidget {
  @override
  State<_NameInputDialog> createState() => _NameInputDialogState();
}

class _NameInputDialogState extends State<_NameInputDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nom du circuit'),
      content: TextField(
        controller: _controller,
        onChanged: (_) => setState(() {}),
        decoration: const InputDecoration(
          hintText: 'Ex: Circuit Côte Nord',
          border: OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          onPressed: _controller.text.trim().isEmpty
              ? null
              : () => Navigator.pop(context, _controller.text.trim()),
          child: const Text('Créer'),
        ),
      ],
    );
  }
}
