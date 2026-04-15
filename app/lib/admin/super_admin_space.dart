import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/app_user.dart';
import '../models/user_category_model.dart';
import '../services/auth_claims_service.dart';
import '../services/startup_map_style_service.dart';
import '../services/user_category_service.dart';
import '../ui/snack/top_snack_bar.dart';
import '../utils/mapbox_style_url.dart';
import 'admin_gate.dart';

/// Espace SuperAdmin - Fonctionnalités avancées réservées aux superadmins
class SuperAdminSpace extends StatefulWidget {
  const SuperAdminSpace({super.key});

  @override
  State<SuperAdminSpace> createState() => _SuperAdminSpaceState();
}

class _SuperAdminSpaceState extends State<SuperAdminSpace> {
  final _authService = AuthClaimsService.instance;
  final _categoryService = UserCategoryService.instance;
  final _startupMapStyleService = StartupMapStyleService.instance;
  final TextEditingController _startupMapStyleController =
      TextEditingController();
  AppUser? _currentUser;
  bool _isLoading = true;
  bool _isSavingStartupMapStyle = false;

  // Statistiques
  int _totalUsers = 0;
  int _totalCategories = 0;
  int _pendingApprovals = 0;
  Map<String, int> _usersByRole = {};

  static const List<({String label, String url})> _startupMapStylePresets = <({
    String label,
    String url,
  })>[
    (label: 'Effacer', url: ''),
    (label: 'Streets', url: 'mapbox://styles/mapbox/streets-v12'),
    (label: 'Outdoors', url: 'mapbox://styles/mapbox/outdoors-v12'),
    (
      label: 'Satellite',
      url: 'mapbox://styles/mapbox/satellite-streets-v12',
    ),
    (label: 'Light', url: 'mapbox://styles/mapbox/light-v11'),
    (label: 'Dark', url: 'mapbox://styles/mapbox/dark-v11'),
    (label: 'Perso', url: kMasliveProMapboxStyleUrl),
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _startupMapStyleController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final user = await _authService.getCurrentAppUser();
      await Future.wait<void>([
        _loadStats(),
        _loadStartupMapStyle(),
      ]);
      setState(() {
        _currentUser = user;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadStartupMapStyle() async {
    try {
      final styleUrl = await _startupMapStyleService.getDefaultStyleUrl();
      if (!mounted) return;
      _startupMapStyleController.text = styleUrl ?? '';
    } catch (e) {
      debugPrint('Erreur chargement style de démarrage: $e');
    }
  }

  String get _normalizedStartupMapStyle {
    return tryNormalizeMapboxStyleUrl(_startupMapStyleController.text) ?? '';
  }

  void _applyStartupMapStylePreset(String url) {
    _startupMapStyleController.text = url;
    setState(() {});
  }

  Future<void> _saveStartupMapStyle() async {
    final rawValue = _startupMapStyleController.text.trim();
    final normalized = tryNormalizeMapboxStyleUrl(rawValue);
    final isClearing = rawValue.isEmpty;

    if (!isClearing && normalized == null) {
      TopSnackBar.show(
        context,
        const SnackBar(
          content: Text('❌ URL de style Mapbox invalide'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSavingStartupMapStyle = true);
    try {
      await _startupMapStyleService.saveDefaultStyleUrl(normalized);
      if (!mounted) return;
      _startupMapStyleController.text = normalized ?? '';
      setState(() => _isSavingStartupMapStyle = false);
      TopSnackBar.show(
        context,
        SnackBar(
          content: Text(
            normalized == null
                ? '✅ Style de démarrage supprimé'
                : '✅ Style de démarrage enregistré',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSavingStartupMapStyle = false);
      TopSnackBar.show(
        context,
        SnackBar(
          content: Text('❌ Erreur: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _loadStats() async {
    try {
      // Compter les utilisateurs
      final usersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .get();
      _totalUsers = usersSnapshot.docs.length;

      // Compter par rôle
      _usersByRole = {};
      for (var doc in usersSnapshot.docs) {
        final role = doc.data()['role']?.toString() ?? 'user';
        _usersByRole[role] = (_usersByRole[role] ?? 0) + 1;
      }

      // Compter les catégories
      final categoriesSnapshot = await FirebaseFirestore.instance
          .collection('userCategories')
          .where('isActive', isEqualTo: true)
          .get();
      _totalCategories = categoriesSnapshot.docs.length;

      // Compter les catégories en attente d'approbation
      int pending = 0;
      for (var catDoc in categoriesSnapshot.docs) {
        if (catDoc.data()['requiresApproval'] == true) {
          // Compter les assignations en attente pour cette catégorie
          // (Pour simplifier, on compte juste les catégories nécessitant approbation)
          pending++;
        }
      }
      _pendingApprovals = pending;
    } catch (e) {
      debugPrint('Erreur chargement stats: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminGate(
      requireSuperAdmin: true,
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          title: const Text('Espace SuperAdmin'),
          backgroundColor: const Color(0xFF2196F3), // Bleu
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadData,
              tooltip: 'Rafraîchir',
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Welcome Card
                    _buildWelcomeCard(),
                    const SizedBox(height: 24),

                    // Statistiques clés
                    _buildStatsSection(),
                    const SizedBox(height: 24),

                    // Actions principales
                    _buildQuickActions(),
                    const SizedBox(height: 24),

                    // Style de carte de démarrage
                    _buildStartupMapStyleTile(),
                    const SizedBox(height: 24),

                    // Gestion système
                    _buildSystemManagement(),
                    const SizedBox(height: 24),

                    // Gestion des catégories
                    _buildCategoryManagement(),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildWelcomeCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF2196F3), // Bleu
            const Color(0xFF1976D2), // Bleu foncé
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFB66CFF).withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.admin_panel_settings, color: Colors.white, size: 32),
              SizedBox(width: 12),
              Text(
                'SuperAdmin',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Bienvenue ${_currentUser?.displayName ?? 'Admin'}',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _currentUser?.email ?? '',
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Statistiques',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Utilisateurs',
                _totalUsers.toString(),
                Icons.people,
                Colors.blue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Catégories',
                _totalCategories.toString(),
                Icons.category,
                Colors.purple,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Admins',
                ((_usersByRole['admin'] ?? 0) + (_usersByRole['superAdmin'] ?? 0))
                    .toString(),
                Icons.verified_user,
                Colors.orange,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Approbations',
                _pendingApprovals.toString(),
                Icons.pending_actions,
                Colors.red,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(
      String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 28),
              Text(
                value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Actions rapides',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.5,
          children: [
            _buildActionCard(
              'Gérer Utilisateurs',
              Icons.people_outline,
              Colors.blue,
              () => Navigator.pushNamed(context, '/admin/users'),
            ),
            _buildActionCard(
              'Gérer Rôles',
              Icons.admin_panel_settings,
                Colors.blue,
              () => Navigator.pushNamed(context, '/admin/roles'),
            ),
            _buildActionCard(
              'Catégories',
              Icons.category_outlined,
              Colors.orange,
              () => Navigator.pushNamed(context, '/admin/categories'),
            ),
            _buildActionCard(
              'Analytics',
              Icons.analytics_outlined,
              Colors.green,
              () => Navigator.pushNamed(context, '/admin/analytics'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionCard(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSystemManagement() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Gestion Système',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        _buildManagementTile(
          'Initialiser les rôles',
          'Créer les définitions de rôles par défaut',
          Icons.verified_user,
          Colors.purple,
          _initializeRoles,
        ),
        const SizedBox(height: 8),
        _buildManagementTile(
          'Initialiser les catégories',
          'Créer les catégories d\'utilisateurs par défaut',
          Icons.category,
          Colors.orange,
          _initializeCategories,
        ),
        const SizedBox(height: 8),
        _buildManagementTile(
          'Logs système',
          'Consulter les journaux du système',
          Icons.list_alt,
          Colors.blue,
          () => Navigator.pushNamed(context, '/admin/logs'),
        ),
        const SizedBox(height: 8),
        _buildManagementTile(
          'Paramètres système',
          'Configuration avancée du système',
          Icons.settings,
          Colors.grey,
          () => Navigator.pushNamed(context, '/admin/settings'),
        ),
      ],
    );
  }

  Widget _buildStartupMapStyleTile() {
    final selectedStyle = _normalizedStartupMapStyle;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF0EA5E9).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.map_outlined,
                  color: Color(0xFF0EA5E9),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Style de carte au démarrage',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Définit le fond Mapbox affiché par défaut à l’ouverture de l’app.',
                      style: TextStyle(color: Colors.black54),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _startupMapStylePresets.map((preset) {
              final normalizedPreset = tryNormalizeMapboxStyleUrl(preset.url) ?? '';
              final isSelected = (normalizedPreset.isEmpty && selectedStyle.isEmpty) ||
                  (normalizedPreset.isNotEmpty && normalizedPreset == selectedStyle);
              return InkWell(
                onTap: () => _applyStartupMapStylePreset(preset.url),
                borderRadius: BorderRadius.circular(999),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF0EA5E9).withValues(alpha: 0.14)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF0EA5E9)
                          : Colors.grey.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Text(
                    preset.label,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: isSelected
                          ? const Color(0xFF0369A1)
                          : Colors.grey[800],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _startupMapStyleController,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'URL du style Mapbox',
              hintText: 'mapbox://styles/username/style-id',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isSavingStartupMapStyle
                      ? null
                      : () => _applyStartupMapStylePreset(''),
                  icon: const Icon(Icons.restart_alt),
                  label: const Text('Réinitialiser'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isSavingStartupMapStyle ? null : _saveStartupMapStyle,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0EA5E9),
                    foregroundColor: Colors.white,
                  ),
                  icon: _isSavingStartupMapStyle
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(
                    _isSavingStartupMapStyle ? 'Enregistrement...' : 'Enregistrer',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildManagementTile(
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }

  Widget _buildCategoryManagement() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Catégories d\'utilisateurs',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            TextButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/admin/categories'),
              icon: const Icon(Icons.arrow_forward),
              label: const Text('Voir tout'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        StreamBuilder<List<UserCategoryDefinition>>(
          stream: _categoryService.getCategoriesStream(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Text('Aucune catégorie. Initialisez les catégories.'),
                ),
              );
            }

            final categories = snapshot.data!.take(5).toList();

            return Column(
              children: categories.map((cat) => _buildCategoryTile(cat)).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildCategoryTile(UserCategoryDefinition category) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: category.badgeColor != null
                ? _hexToColor(category.badgeColor!)
                : Colors.grey,
            shape: BoxShape.circle,
          ),
          child: Icon(
            _getIconData(category.iconName ?? 'category'),
            color: Colors.white,
            size: 20,
          ),
        ),
        title: Text(
          category.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(category.description),
        trailing: Chip(
          label: Text(
            category.requiresApproval ? 'Approbation' : 'Auto',
            style: const TextStyle(fontSize: 11),
          ),
          backgroundColor: category.requiresApproval
            ? Colors.orange.withValues(alpha: 0.2)
            : Colors.green.withValues(alpha: 0.2),
        ),
      ),
    );
  }

  Color _hexToColor(String hexString) {
    final buffer = StringBuffer();
    if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
    buffer.write(hexString.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }

  IconData _getIconData(String name) {
    switch (name) {
      case 'sports_motorsports':
        return Icons.sports_motorsports;
      case 'airline_seat_recline_normal':
        return Icons.airline_seat_recline_normal;
      case 'event_note':
        return Icons.event_note;
      case 'store':
        return Icons.store;
      case 'local_hospital':
        return Icons.local_hospital;
      case 'star':
        return Icons.star;
      case 'photo_camera':
        return Icons.photo_camera;
      case 'volunteer_activism':
        return Icons.volunteer_activism;
      case 'visibility':
        return Icons.visibility;
      default:
        return Icons.category;
    }
  }

  Future<void> _initializeRoles() async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      // Vérifier que l'utilisateur est bien superAdmin
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser!.uid)
          .get();

      // Appeler la fonction Cloud
      // Note: Vous devrez implémenter l'appel à la fonction Cloud ici
      if (!mounted) return;
      
      Navigator.pop(context);
      
      TopSnackBar.show(
        context,
        const SnackBar(
          content: Text('✅ Rôles initialisés avec succès'),
          backgroundColor: Colors.green,
        ),
      );
      
      await _loadData();
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      TopSnackBar.show(
        context,
        SnackBar(
          content: Text('❌ Erreur: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _initializeCategories() async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      await _categoryService.initializeCategories();
      if (!mounted) return;
      
      Navigator.pop(context);
      
      TopSnackBar.show(
        context,
        const SnackBar(
          content: Text('✅ Catégories initialisées avec succès'),
          backgroundColor: Colors.green,
        ),
      );
      
      await _loadData();
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      TopSnackBar.show(
        context,
        SnackBar(
          content: Text('❌ Erreur: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
