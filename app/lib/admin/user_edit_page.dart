import 'package:flutter/material.dart';
import '../models/app_user.dart';
import '../models/user_role_model.dart';
import '../services/user_repo.dart';
import '../services/permission_service.dart';
import '../services/auth_claims_service.dart';
import '../theme/maslive_theme.dart';
import '../ui/widgets/maslive_text_field.dart';

class UserEditPage extends StatefulWidget {
  final AppUser user;

  const UserEditPage({
    super.key,
    required this.user,
  });

  @override
  State<UserEditPage> createState() => _UserEditPageState();
}

class _UserEditPageState extends State<UserEditPage> {
  final _formKey = GlobalKey<FormState>();
  final _userRepo = UserRepository.instance;
  final _permissionService = PermissionService.instance;
  final _authService = AuthClaimsService.instance;

  late TextEditingController _displayNameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _groupIdController;

  late UserRoleType _selectedRole;
  late bool _isActive;
  bool _isLoading = false;
  bool _isSaving = false;
  AppUser? _currentUser;

  @override
  void initState() {
    super.initState();
    _displayNameController = TextEditingController(text: widget.user.displayName);
    _emailController = TextEditingController(text: widget.user.email);
    _phoneController = TextEditingController(text: widget.user.phone);
    _groupIdController = TextEditingController(text: widget.user.groupId ?? '');
    _selectedRole = RoleDefinition.roleFromString(widget.user.role);
    _isActive = widget.user.isActive;
    _loadCurrentUser();
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _groupIdController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentUser() async {
    setState(() => _isLoading = true);
    try {
      final user = await _authService.getCurrentAppUser();
      setState(() {
        _currentUser = user;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
  }

  bool _canEditRole() {
    if (_currentUser == null) return false;
    
    // Super admin peut tout modifier
    if (_currentUser!.isSuperAdmin) return true;
    
    // Admin peut modifier les rôles inférieurs
    final currentRole = RoleDefinition.roleFromString(_currentUser!.role);
    final targetRole = RoleDefinition.roleFromString(widget.user.role);
    if (currentRole == UserRoleType.admin) {
      return targetRole != UserRoleType.superAdmin && 
             targetRole != UserRoleType.admin;
    }
    
    return false;
  }

  bool _canEditUser() {
    if (_currentUser == null) return false;
    
    // Ne peut pas se modifier soi-même (sauf displayName et phone)
    if (_currentUser!.uid == widget.user.uid) return false;
    
    // Super admin peut tout modifier
    if (_currentUser!.isSuperAdmin) return true;
    
    // Admin ne peut pas modifier les super admins
    final currentRole = RoleDefinition.roleFromString(_currentUser!.role);
    final targetRole = RoleDefinition.roleFromString(widget.user.role);
    if (currentRole == UserRoleType.admin) {
      return targetRole != UserRoleType.superAdmin;
    }
    
    return false;
  }

  Future<void> _saveUser() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_canEditUser()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vous n\'avez pas la permission de modifier cet utilisateur')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      // Mettre à jour les informations de base
      final Map<String, dynamic> updates = {
        'displayName': _displayNameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'isActive': _isActive,
        'updatedAt': DateTime.now(),
      };

      // Si le rôle a changé et qu'on peut le modifier
      final selectedRoleKey = RoleDefinition.roleToString(_selectedRole);
      if (selectedRoleKey != widget.user.role && _canEditRole()) {
        updates['role'] = selectedRoleKey;
        
        // Assigner le nouveau rôle via le service
        final newGroupId = _groupIdController.text.trim();
        if (_selectedRole == UserRoleType.group && newGroupId.isEmpty) {
          throw Exception('Un groupId est requis pour le rôle groupe');
        }
        await _permissionService.assignRole(
          userId: widget.user.uid,
          roleType: _selectedRole,
          groupId: newGroupId.isNotEmpty ? newGroupId : null,
        );
      }

      // Si le groupe a changé
      final newGroupId = _groupIdController.text.trim();
      if (newGroupId != widget.user.groupId) {
        if (newGroupId.isEmpty) {
          updates['groupId'] = null;
        } else {
          updates['groupId'] = newGroupId;
        }
      }

      // Mettre à jour l'utilisateur
      await _userRepo.updateUser(widget.user.uid, updates);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Utilisateur mis à jour')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final isCurrentUser = _currentUser?.uid == widget.user.uid;
    final canEdit = _canEditUser();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Modifier l\'utilisateur'),
        actions: [
          if (canEdit)
            TextButton(
              onPressed: _isSaving ? null : _saveUser,
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Enregistrer'),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar et info de base
              Center(
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: MasLiveTheme.getRoleColor(_selectedRole),
                      child: Text(
                        widget.user.initials,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      widget.user.email,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          MasLiveTheme.getRoleIcon(_selectedRole),
                          size: 16,
                          color: MasLiveTheme.getRoleColor(_selectedRole),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          RoleDefinition.getRoleLabel(_selectedRole),
                          style: TextStyle(
                            color: MasLiveTheme.getRoleColor(_selectedRole),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    if (isCurrentUser)
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Chip(
                          label: Text('C\'est vous'),
                          avatar: Icon(Icons.person, size: 16),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              if (!canEdit)
                Card(
                  color: Colors.orange.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(Icons.info, color: Colors.orange.shade700),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            isCurrentUser
                                ? 'Vous ne pouvez pas modifier votre propre rôle et statut'
                                : 'Vous n\'avez pas la permission de modifier cet utilisateur',
                            style: TextStyle(color: Colors.orange.shade700),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (!canEdit) const SizedBox(height: 16),

              // Nom d'affichage
              MasliveTextField(
                controller: _displayNameController,
                label: 'Nom d\'affichage',
                icon: Icons.person,
                enabled: canEdit || isCurrentUser,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Le nom d\'affichage est requis';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Email (lecture seule)
              MasliveTextField(
                controller: _emailController,
                label: 'Email',
                icon: Icons.email,
                enabled: false,
              ),
              const SizedBox(height: 16),

              // Téléphone
              MasliveTextField(
                controller: _phoneController,
                label: 'Téléphone',
                icon: Icons.phone,
                enabled: canEdit || isCurrentUser,
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),

              // Rôle
              DropdownButtonFormField<UserRoleType>(
                initialValue: _selectedRole,
                decoration: const InputDecoration(
                  labelText: 'Rôle',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.security),
                ),
                items: UserRoleType.values.map((role) {
                  return DropdownMenuItem(
                    value: role,
                    child: Row(
                      children: [
                        Icon(
                          MasLiveTheme.getRoleIcon(role),
                          size: 20,
                          color: MasLiveTheme.getRoleColor(role),
                        ),
                        const SizedBox(width: 8),
                        Text(RoleDefinition.getRoleLabel(role)),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: _canEditRole() ? (value) {
                  if (value != null) {
                    setState(() => _selectedRole = value);
                  }
                } : null,
              ),
              const SizedBox(height: 16),

              // Groupe ID
              MasliveTextField(
                controller: _groupIdController,
                label: 'ID du groupe (optionnel)',
                icon: Icons.group,
                helperText: 'Pour les rôles Tracker et Groupe Admin',
                enabled: canEdit,
              ),
              const SizedBox(height: 16),

              // Statut actif
              Card(
                child: SwitchListTile(
                  title: const Text('Compte actif'),
                  subtitle: Text(
                    _isActive 
                        ? 'L\'utilisateur peut se connecter' 
                        : 'L\'utilisateur ne peut pas se connecter',
                  ),
                  value: _isActive,
                  onChanged: canEdit ? (value) {
                    setState(() => _isActive = value);
                  } : null,
                  secondary: Icon(
                    _isActive ? Icons.check_circle : Icons.cancel,
                    color: _isActive ? Colors.green : Colors.red,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Informations supplémentaires
              Text(
                'Informations',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoRow(
                        'ID',
                        widget.user.uid,
                        Icons.fingerprint,
                      ),
                      const Divider(),
                      _buildInfoRow(
                        'Créé le',
                        _formatDate(widget.user.createdAt),
                        Icons.calendar_today,
                      ),
                      if (widget.user.updatedAt != null) ...[
                        const Divider(),
                        _buildInfoRow(
                          'Modifié le',
                          _formatDate(widget.user.updatedAt!),
                          Icons.update,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} à ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}
