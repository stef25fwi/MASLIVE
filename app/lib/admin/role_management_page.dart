import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'admin_gate.dart';

/// Page de gestion des rôles système
class RoleManagementPage extends StatefulWidget {
  const RoleManagementPage({super.key});

  @override
  State<RoleManagementPage> createState() => _RoleManagementPageState();
}

class _RoleManagementPageState extends State<RoleManagementPage> {
  final _functions = FirebaseFunctions.instance;
  final _firestore = FirebaseFirestore.instance;

  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    return AdminGate(
      requireSuperAdmin: true,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Gestion des Rôles'),
          backgroundColor: const Color(0xFF2196F3), // Bleu
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _initializeRoles,
              tooltip: 'Initialiser les rôles',
            ),
          ],
        ),
        body: Column(
          children: [
            // Barre de recherche
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Rechercher un rôle...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                onChanged: (value) {
                  setState(() => _searchQuery = value.toLowerCase());
                },
              ),
            ),

            // Liste des rôles
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _firestore.collection('roles').orderBy('priority').snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(child: Text('Erreur: ${snapshot.error}'));
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.admin_panel_settings,
                            size: 64,
                            color: Colors.grey,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Aucun rôle défini',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton.icon(
                            onPressed: _initializeRoles,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Initialiser les rôles'),
                          ),
                        ],
                      ),
                    );
                  }

                  var roles = snapshot.data!.docs;

                  // Filtrer selon la recherche
                  if (_searchQuery.isNotEmpty) {
                    roles = roles.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final name = (data['name'] ?? '').toString().toLowerCase();
                      final desc =
                          (data['description'] ?? '').toString().toLowerCase();
                      return name.contains(_searchQuery) ||
                          desc.contains(_searchQuery);
                    }).toList();
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: roles.length,
                    itemBuilder: (context, index) {
                      final roleDoc = roles[index];
                      final roleData = roleDoc.data() as Map<String, dynamic>;
                      return _buildRoleCard(roleDoc.id, roleData);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleCard(String roleId, Map<String, dynamic> roleData) {
    final name = roleData['name'] ?? 'Sans nom';
    final description = roleData['description'] ?? '';
    final priority = roleData['priority'] ?? 0;
    final roleType = roleData['roleType'] ?? roleId;
    final permissions = List<String>.from(roleData['permissions'] ?? []);
    final isActive = roleData['isActive'] ?? true;

    final color = _getRoleColor(roleType);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ExpansionTile(
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
          child: Icon(
            _getRoleIcon(roleType),
            color: Colors.white,
            size: 24,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                name,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            Chip(
              label: Text(
                'P$priority',
                style: const TextStyle(fontSize: 11, color: Colors.white),
              ),
              backgroundColor: color,
            ),
            if (!isActive) ...[
              const SizedBox(width: 8),
              const Chip(
                label: Text('Inactif', style: TextStyle(fontSize: 11)),
                backgroundColor: Colors.grey,
                labelStyle: TextStyle(color: Colors.white),
              ),
            ],
          ],
        ),
        subtitle: Text(
          description,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(),
                const SizedBox(height: 8),

                // Informations
                _buildInfoRow('ID', roleId),
                _buildInfoRow('Type', roleType),
                _buildInfoRow('Priorité', priority.toString()),
                _buildInfoRow('Statut', isActive ? 'Actif' : 'Inactif'),

                const SizedBox(height: 16),

                // Permissions
                const Text(
                  'Permissions:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),

                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: permissions.map((perm) {
                    return Chip(
                      label: Text(
                        _formatPermissionName(perm),
                        style: const TextStyle(fontSize: 11),
                      ),
                    backgroundColor: color.withValues(alpha: 0.2),
                      labelStyle: TextStyle(color: color),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 16),

                // Statistiques d'utilisation
                FutureBuilder<int>(
                  future: _countUsersWithRole(roleId),
                  builder: (context, snapshot) {
                    if (snapshot.hasData) {
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.people, color: color, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              '${snapshot.data} utilisateur(s) avec ce rôle',
                              style: const TextStyle(fontSize: 13),
                            ),
                          ],
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Color _getRoleColor(String roleType) {
    switch (roleType) {
      case 'superAdmin':
        return Colors.red;
      case 'admin':
        return Colors.blue;
      case 'group':
        return Colors.blue;
      case 'tracker':
        return Colors.orange;
      case 'user':
      default:
        return Colors.grey;
    }
  }

  IconData _getRoleIcon(String roleType) {
    switch (roleType) {
      case 'superAdmin':
        return Icons.admin_panel_settings;
      case 'admin':
        return Icons.verified_user;
      case 'group':
        return Icons.group;
      case 'tracker':
        return Icons.my_location;
      case 'user':
      default:
        return Icons.person;
    }
  }

  String _formatPermissionName(String permission) {
    return permission
        .replaceAllMapped(
          RegExp(r'([A-Z])'),
          (match) => ' ${match.group(0)}',
        )
        .trim();
  }

  Future<int> _countUsersWithRole(String roleId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: roleId)
          .get();
      return snapshot.docs.length;
    } catch (e) {
      return 0;
    }
  }

  Future<void> _initializeRoles() async {
    try {

      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final callable = _functions.httpsCallable('initializeRoles');
      final result = await callable.call();

      if (mounted) {
        Navigator.pop(context);
      }

      final stats = result.data['stats'] as Map<String, dynamic>;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✅ Rôles initialisés: ${stats['created']} créés, ${stats['updated']} mis à jour',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
