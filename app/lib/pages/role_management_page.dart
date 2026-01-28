import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_role_model.dart';
import '../models/user_profile_model.dart';
import '../services/permission_service.dart';
import '../widgets/permission_widgets.dart';

/// Page de gestion des rôles et permissions (accessible uniquement aux admins)
class RoleManagementPage extends StatefulWidget {
  const RoleManagementPage({super.key});

  @override
  State<RoleManagementPage> createState() => _RoleManagementPageState();
}

class _RoleManagementPageState extends State<RoleManagementPage> {
  List<RoleDefinition> _roles = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadRoles();
  }

  Future<void> _loadRoles() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final roles = await PermissionService.instance.getAllRoles();
      setState(() {
        _roles = roles;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _initializeRoles() async {
    try {
      await PermissionService.instance.initializeDefaultRoles();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Rôles initialisés avec succès'),
          backgroundColor: Colors.green,
        ),
      );
      await _loadRoles();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestion des Rôles'),
        actions: [
          PermissionGuard(
            permission: Permission.manageRoles,
            child: IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadRoles,
              tooltip: 'Recharger',
            ),
          ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: PermissionGuard(
        permission: Permission.manageRoles,
        child: FloatingActionButton.extended(
          onPressed: _initializeRoles,
          icon: const Icon(Icons.sync),
          label: const Text('Initialiser les rôles'),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text('Erreur: $_error'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadRoles,
              child: const Text('Réessayer'),
            ),
          ],
        ),
      );
    }

    if (_roles.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.info, size: 64),
            const SizedBox(height: 16),
            const Text('Aucun rôle défini'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _initializeRoles,
              child: const Text('Initialiser les rôles par défaut'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _roles.length,
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) {
        final role = _roles[index];
        return _RoleCard(role: role);
      },
    );
  }
}

class _RoleCard extends StatelessWidget {
  final RoleDefinition role;

  const _RoleCard({required this.role});

  Color _getPriorityColor() {
    if (role.priority >= 90) return Colors.red;
    if (role.priority >= 50) return Colors.orange;
    if (role.priority >= 20) return Colors.blue;
    return Colors.green;
  }

  IconData _getRoleIcon() {
    switch (role.roleType) {
      case UserRoleType.superAdmin:
        return Icons.admin_panel_settings;
      case UserRoleType.admin:
        return Icons.manage_accounts;
      case UserRoleType.group:
        return Icons.group;
      case UserRoleType.tracker:
        return Icons.location_on;
      case UserRoleType.user:
        return Icons.person;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: _getPriorityColor(),
          child: Icon(_getRoleIcon(), color: Colors.white),
        ),
        title: Text(
          role.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(role.description),
            const SizedBox(height: 4),
            Row(
              children: [
                Chip(
                  label: Text('Priorité ${role.priority}'),
                  backgroundColor: _getPriorityColor().withValues(alpha: 0.2),
                  labelStyle: TextStyle(
                    color: _getPriorityColor(),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                Chip(
                  label: Text('${role.permissions.length} permissions'),
                  backgroundColor: Colors.grey.shade200,
                ),
              ],
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Permissions:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                ..._buildPermissionsByCategory(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildPermissionsByCategory() {
    final Map<String, List<Permission>> grouped = {};

    for (final permission in role.permissions) {
      final category = permission.category;
      if (!grouped.containsKey(category)) {
        grouped[category] = [];
      }
      grouped[category]!.add(permission);
    }

    final widgets = <Widget>[];

    grouped.forEach((category, permissions) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 4),
          child: Text(
            category,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.blue,
            ),
          ),
        ),
      );

      for (final permission in permissions) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 4),
            child: Row(
              children: [
                const Icon(Icons.check, size: 16, color: Colors.green),
                const SizedBox(width: 8),
                Expanded(child: Text(permission.displayName)),
              ],
            ),
          ),
        );
      }
    });

    return widgets;
  }
}

/// Page de gestion des utilisateurs avec leurs rôles
class UserRolesManagementPage extends StatefulWidget {
  const UserRolesManagementPage({super.key});

  @override
  State<UserRolesManagementPage> createState() =>
      _UserRolesManagementPageState();
}

class _UserRolesManagementPageState extends State<UserRolesManagementPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gestion des Utilisateurs')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .orderBy('createdAt', descending: true)
            .limit(50)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Erreur: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final users = snapshot.data?.docs ?? [];

          if (users.isEmpty) {
            return const Center(child: Text('Aucun utilisateur'));
          }

          return ListView.builder(
            itemCount: users.length,
            padding: const EdgeInsets.all(16),
            itemBuilder: (context, index) {
              final userData = users[index].data() as Map<String, dynamic>;
              final userId = users[index].id;

              return _UserCard(
                userId: userId,
                userData: userData,
                onRoleChanged: () => setState(() {}),
              );
            },
          );
        },
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  final String userId;
  final Map<String, dynamic> userData;
  final VoidCallback onRoleChanged;

  const _UserCard({
    required this.userId,
    required this.userData,
    required this.onRoleChanged,
  });

  Future<void> _changeRole(BuildContext context) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final canManage = await PermissionService.instance.canManageUser(
      currentUser.uid,
      userId,
    );

    if (!context.mounted) return;

    if (!canManage) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Vous n\'avez pas la permission de modifier cet utilisateur',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final selectedRole = await showDialog<UserRoleType>(
      context: context,
      builder: (context) => _RoleSelectionDialog(
        currentRole: UserProfile.parseRole(userData['role'] as String?),
      ),
    );

    if (!context.mounted) return;

    if (selectedRole != null) {
      try {
        String? groupId;
        if (selectedRole == UserRoleType.group) {
          groupId = await _selectGroup(context);
          if (!context.mounted) return;
          if (groupId == null) return; // Annulé
        }

        await PermissionService.instance.assignRole(
          userId: userId,
          roleType: selectedRole,
          groupId: groupId,
        );

        if (!context.mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Rôle modifié avec succès'),
            backgroundColor: Colors.green,
          ),
        );

        onRoleChanged();
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<String?> _selectGroup(BuildContext context) async {
    final groupsSnapshot = await FirebaseFirestore.instance
        .collection('groups')
        .get();

    if (!context.mounted) return null;

    if (groupsSnapshot.docs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Aucun groupe disponible'),
          backgroundColor: Colors.orange,
        ),
      );
      return null;
    }

    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sélectionner un groupe'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: groupsSnapshot.docs.map((doc) {
              final groupData = doc.data();
              return ListTile(
                title: Text(groupData['name'] ?? 'Sans nom'),
                onTap: () => Navigator.of(context).pop(doc.id),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final role = userData['role'] as String? ?? 'user';
    final displayName = userData['displayName'] as String? ?? 'Sans nom';
    final email = userData['email'] as String? ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundImage: userData['photoUrl'] != null
              ? NetworkImage(userData['photoUrl'] as String)
              : null,
          child: userData['photoUrl'] == null
              ? Text(displayName[0].toUpperCase())
              : null,
        ),
        title: Text(displayName),
        subtitle: Text('$email\nRôle: $role'),
        isThreeLine: true,
        trailing: PermissionGuard(
          permission: Permission.manageAllUsers,
          child: IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => _changeRole(context),
          ),
        ),
      ),
    );
  }
}

class _RoleSelectionDialog extends StatelessWidget {
  final UserRole currentRole;

  const _RoleSelectionDialog({required this.currentRole});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Sélectionner un rôle'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: UserRoleType.values.map((roleType) {
            final roleDef = RoleDefinition.defaultRoles.firstWhere(
              (r) => r.roleType == roleType,
            );

            return RadioListTile<UserRoleType>(
              title: Text(roleDef.name),
              subtitle: Text(roleDef.description),
              value: roleType,
              // ignore: deprecated_member_use
              groupValue: _getCurrentRoleType(),
              // ignore: deprecated_member_use
              onChanged: (value) {
                if (value != null) {
                  Navigator.of(context).pop(value);
                }
              },
            );
          }).toList(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
      ],
    );
  }

  UserRoleType _getCurrentRoleType() {
    switch (currentRole) {
      case UserRole.user:
        return UserRoleType.user;
      case UserRole.group:
        return UserRoleType.group;
      case UserRole.admin:
        return UserRoleType.admin;
    }
  }
}
