import 'package:flutter/material.dart';
import '../models/user_category_model.dart';
import '../services/user_category_service.dart';
import 'admin_gate.dart';

/// Page de gestion des catégories d'utilisateurs
class CategoryManagementPage extends StatefulWidget {
  const CategoryManagementPage({super.key});

  @override
  State<CategoryManagementPage> createState() => _CategoryManagementPageState();
}

class _CategoryManagementPageState extends State<CategoryManagementPage> {
  final _categoryService = UserCategoryService.instance;
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    return AdminGate(
      requireSuperAdmin: true,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Gestion des Catégories'),
          backgroundColor: const Color(0xFF2196F3), // Bleu
          actions: [
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: _showAddCategoryDialog,
              tooltip: 'Ajouter une catégorie',
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
                  hintText: 'Rechercher une catégorie...',
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

            // Liste des catégories
            Expanded(
              child: StreamBuilder<List<UserCategoryDefinition>>(
                stream: _categoryService.getCategoriesStream(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Text('Erreur: ${snapshot.error}'),
                    );
                  }

                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.category_outlined,
                            size: 64,
                            color: Colors.grey,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Aucune catégorie',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton.icon(
                            onPressed: _initializeCategories,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Initialiser les catégories'),
                          ),
                        ],
                      ),
                    );
                  }

                  var categories = snapshot.data!;

                  // Filtrer selon la recherche
                  if (_searchQuery.isNotEmpty) {
                    categories = categories
                        .where((cat) =>
                            cat.name.toLowerCase().contains(_searchQuery) ||
                            cat.description.toLowerCase().contains(_searchQuery))
                        .toList();
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: categories.length,
                    itemBuilder: (context, index) {
                      final category = categories[index];
                      return _buildCategoryCard(category);
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

  Widget _buildCategoryCard(UserCategoryDefinition category) {
    final badgeColor = category.badgeColor != null
        ? _hexToColor(category.badgeColor!)
        : Colors.grey;

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
            color: badgeColor,
            shape: BoxShape.circle,
          ),
          child: Icon(
            _getIconData(category.iconName ?? 'category'),
            color: Colors.white,
            size: 24,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                category.name,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            if (category.requiresApproval)
              const Chip(
                label: Text('Approbation', style: TextStyle(fontSize: 11)),
                backgroundColor: Colors.orange,
                labelStyle: TextStyle(color: Colors.white),
              ),
            if (!category.isActive)
              const SizedBox(width: 8),
            if (!category.isActive)
              const Chip(
                label: Text('Inactif', style: TextStyle(fontSize: 11)),
                backgroundColor: Colors.grey,
                labelStyle: TextStyle(color: Colors.white),
              ),
          ],
        ),
        subtitle: Text(
          category.description,
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

                // Informations détaillées
                _buildInfoRow('Type', category.categoryType.label),
                _buildInfoRow('Priorité', category.priority.toString()),
                _buildInfoRow(
                  'Auto-assignable',
                  category.canSelfAssign ? 'Oui' : 'Non',
                ),

                if (category.benefits.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Avantages:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...category.benefits.map((benefit) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            Icon(
                              _getIconData(benefit.iconName ?? 'check'),
                              size: 16,
                              color: badgeColor,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${benefit.title}: ${benefit.description}',
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      )),
                ],

                const SizedBox(height: 16),

                // Actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: () => _editCategory(category),
                      icon: const Icon(Icons.edit),
                      label: const Text('Modifier'),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: () => _toggleCategoryStatus(category),
                      icon: Icon(
                        category.isActive
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      label: Text(
                        category.isActive ? 'Désactiver' : 'Activer',
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor:
                            category.isActive ? Colors.orange : Colors.green,
                      ),
                    ),
                  ],
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
            width: 120,
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
      case 'check':
        return Icons.check_circle_outline;
      default:
        return Icons.category;
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

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Catégories initialisées avec succès'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Erreur: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showAddCategoryDialog() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Fonctionnalité en développement'),
      ),
    );
  }

  void _editCategory(UserCategoryDefinition category) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Édition de ${category.name}'),
      ),
    );
  }

  void _toggleCategoryStatus(UserCategoryDefinition category) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          category.isActive
              ? 'Désactivation de ${category.name}'
              : 'Activation de ${category.name}',
        ),
      ),
    );
  }
}
