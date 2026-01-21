import 'package:flutter/material.dart';
import '../models/app_user.dart';
import '../models/user_role_model.dart';
import '../services/user_repo.dart';
import '../services/auth_claims_service.dart';
import '../theme/maslive_theme.dart';
import 'user_edit_page.dart';

class UserManagementPage extends StatefulWidget {
  const UserManagementPage({super.key});

  @override
  State<UserManagementPage> createState() => _UserManagementPageState();
}

class _UserManagementPageState extends State<UserManagementPage> {
  final _userRepo = UserRepository.instance;
  final _authService = AuthClaimsService.instance;
  final _searchController = TextEditingController();

  List<AppUser> _users = [];
  AppUser? _currentUser;
  bool _isLoading = true;
  bool _isSearching = false;
  UserRoleType? _filterRole;
  String? _filterGroupId;
  bool? _filterActive;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final currentUser = await _authService.getCurrentAppUser();
      List<AppUser> users;

      if (_searchController.text.isNotEmpty) {
        users = await _userRepo.searchUsers(_searchController.text);
      } else if (_filterRole != null) {
        final roleKey = _filterRole!.toString().split('.').last;
        users = await _userRepo.getUsersByRole(roleKey);
      } else if (_filterGroupId != null) {
        users = await _userRepo.getUsersByGroup(_filterGroupId!);
      } else {
        users = await _userRepo.getAllUsers();
      }

      // Appliquer le filtre actif/inactif si défini
      if (_filterActive != null) {
        users = users.where((user) => user.isActive == _filterActive).toList();
      }

      setState(() {
        _currentUser = currentUser;
        _users = users;
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

  void _onSearch(String query) {
    if (query.isEmpty) {
      _loadData();
    } else {
      setState(() => _isSearching = true);
      _userRepo.searchUsers(query).then((users) {
        if (mounted) {
          setState(() {
            _users = users;
            _isSearching = false;
          });
        }
      }).catchError((e) {
        if (mounted) {
          setState(() => _isSearching = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur de recherche: $e')),
          );
        }
      });
    }
  }

  void _clearFilters() {
    setState(() {
      _filterRole = null;
      _filterGroupId = null;
      _filterActive = null;
      _searchController.clear();
    });
    _loadData();
  }

  Future<void> _toggleUserActive(AppUser user) async {
    try {
      await _userRepo.toggleUserActive(user.uid, !user.isActive);
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              user.isActive 
                  ? 'Utilisateur désactivé' 
                  : 'Utilisateur activé',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
  }

  Future<void> _confirmDelete(AppUser user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmer la suppression'),
        content: Text(
          'Voulez-vous vraiment supprimer l\'utilisateur ${user.displayNameOrEmail} ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _userRepo.deleteUser(user.uid);
        await _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Utilisateur supprimé')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestion des utilisateurs'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          _buildFilters(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _isSearching
                    ? const Center(child: CircularProgressIndicator())
                    : _users.isEmpty
                        ? _buildEmptyState()
                        : _buildUserList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Rechercher un utilisateur...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    _loadData();
                  },
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onChanged: _onSearch,
      ),
    );
  }

  Widget _buildFilters() {
    final hasFilters = _filterRole != null || 
                       _filterGroupId != null || 
                       _filterActive != null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // Filtre par rôle
            _buildFilterChip(
              label: _filterRole != null
                  ? RoleDefinition.getRoleLabel(_filterRole!)
                  : 'Rôle',
              icon: Icons.security,
              isSelected: _filterRole != null,
              onTap: () => _showRoleFilter(),
            ),
            const SizedBox(width: 8),
            // Filtre actif/inactif
            _buildFilterChip(
              label: _filterActive == null
                  ? 'Statut'
                  : _filterActive!
                      ? 'Actifs'
                      : 'Inactifs',
              icon: Icons.check_circle,
              isSelected: _filterActive != null,
              onTap: () => _showStatusFilter(),
            ),
            if (hasFilters) ...[
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: _clearFilters,
                icon: const Icon(Icons.clear_all, size: 16),
                label: const Text('Effacer'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 4),
          Text(label),
        ],
      ),
      selected: isSelected,
      onSelected: (_) => onTap(),
    );
  }

  void _showRoleFilter() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Filtrer par rôle',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            ...UserRoleType.values.map((role) => ListTile(
                  leading: Icon(
                    MasLiveTheme.getRoleIcon(role),
                    color: MasLiveTheme.getRoleColor(role),
                  ),
                  title: Text(RoleDefinition.getRoleLabel(role)),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() => _filterRole = role);
                    _loadData();
                  },
                )),
            ListTile(
              leading: const Icon(Icons.clear),
              title: const Text('Effacer le filtre'),
              onTap: () {
                Navigator.pop(context);
                setState(() => _filterRole = null);
                _loadData();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showStatusFilter() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Filtrer par statut',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.check_circle, color: Colors.green),
              title: const Text('Actifs uniquement'),
              onTap: () {
                Navigator.pop(context);
                setState(() => _filterActive = true);
                _loadData();
              },
            ),
            ListTile(
              leading: const Icon(Icons.cancel, color: Colors.red),
              title: const Text('Inactifs uniquement'),
              onTap: () {
                Navigator.pop(context);
                setState(() => _filterActive = false);
                _loadData();
              },
            ),
            ListTile(
              leading: const Icon(Icons.clear),
              title: const Text('Tous les utilisateurs'),
              onTap: () {
                Navigator.pop(context);
                setState(() => _filterActive = null);
                _loadData();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'Aucun utilisateur trouvé',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserList() {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        itemCount: _users.length,
        itemBuilder: (context, index) {
          final user = _users[index];
          return _buildUserCard(user);
        },
      ),
    );
  }

  Widget _buildUserCard(AppUser user) {
    final isCurrentUser = _currentUser?.uid == user.uid;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: MasLiveTheme.getRoleColor(user.role),
          child: Text(
            user.initials,
            style: const TextStyle(color: Colors.white),
          ),
        ),
        title: Row(
          children: [
            Expanded(child: Text(user.displayNameOrEmail)),
            if (isCurrentUser)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Vous',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.blue.shade700,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(user.email),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  MasLiveTheme.getRoleIcon(user.role),
                  size: 14,
                  color: MasLiveTheme.getRoleColor(user.role),
                ),
                const SizedBox(width: 4),
                Text(
                  user.roleLabel,
                  style: TextStyle(
                    color: MasLiveTheme.getRoleColor(user.role),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  user.isActive ? Icons.check_circle : Icons.cancel,
                  size: 14,
                  color: user.isActive ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 4),
                Text(
                  user.isActive ? 'Actif' : 'Inactif',
                  style: TextStyle(
                    color: user.isActive ? Colors.green : Colors.red,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            switch (value) {
              case 'edit':
                _navigateToEditUser(user);
                break;
              case 'toggle':
                _toggleUserActive(user);
                break;
              case 'delete':
                if (!isCurrentUser) {
                  _confirmDelete(user);
                }
                break;
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  Icon(Icons.edit),
                  SizedBox(width: 8),
                  Text('Modifier'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'toggle',
              child: Row(
                children: [
                  Icon(user.isActive ? Icons.cancel : Icons.check_circle),
                  const SizedBox(width: 8),
                  Text(user.isActive ? 'Désactiver' : 'Activer'),
                ],
              ),
            ),
            if (!isCurrentUser)
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Supprimer', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _navigateToEditUser(AppUser user) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UserEditPage(user: user),
      ),
    ).then((_) => _loadData());
  }
}
