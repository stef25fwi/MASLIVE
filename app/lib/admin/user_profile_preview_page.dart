import 'package:flutter/material.dart';

import '../widgets/rainbow_header.dart';
import '../widgets/honeycomb_background.dart';

/// Page de prévisualisation des différents types de profils utilisateurs
/// Permet au superadmin de voir comment se présente chaque type de profil
class UserProfilePreviewPage extends StatefulWidget {
  const UserProfilePreviewPage({super.key});

  @override
  State<UserProfilePreviewPage> createState() => _UserProfilePreviewPageState();
}

class _UserProfilePreviewPageState extends State<UserProfilePreviewPage> {
  // Types de profils à afficher
  final List<String> _profileTypes = [
    'Utilisateur standard',
    'Compte Pro',
    'Créateur digital',
    'Administrateur groupe',
    'Tracker groupe',
    'Admin',
    'SuperAdmin',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: HoneycombBackground(
        child: CustomScrollView(
          slivers: [
            const SliverToBoxAdapter(
              child: RainbowHeader(
                title: 'Aperçu Profils Utilisateurs',
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final profileType = _profileTypes[index];
                    return _ProfileTypeCard(
                      profileType: profileType,
                      onTap: () => _showProfilePreview(context, profileType),
                    );
                  },
                  childCount: _profileTypes.length,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showProfilePreview(BuildContext context, String profileType) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Aperçu: $profileType',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                const Divider(),
                Expanded(
                  child: _buildProfilePreviewContent(
                    scrollController,
                    profileType,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildProfilePreviewContent(
    ScrollController controller,
    String profileType,
  ) {
    return ListView(
      controller: controller,
      padding: const EdgeInsets.all(16),
      children: [
        // Avatar et infos basiques
        Center(
          child: Column(
            children: [
              CircleAvatar(
                radius: 50,
                backgroundColor: _getColorForProfile(profileType),
                child: Icon(
                  _getIconForProfile(profileType),
                  size: 50,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _getExampleName(profileType),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _getColorForProfile(profileType).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _getColorForProfile(profileType),
                    width: 1.5,
                  ),
                ),
                child: Text(
                  profileType,
                  style: TextStyle(
                    color: _getColorForProfile(profileType),
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),

        // Sections disponibles selon le type
        _buildSectionTitle('Sections disponibles'),
        const SizedBox(height: 12),
        ..._getSectionsForProfile(profileType).map(
          (section) => _buildSectionCard(
            section['title'] as String,
            section['subtitle'] as String,
            section['icon'] as IconData,
          ),
        ),
        const SizedBox(height: 24),

        // Permissions
        _buildSectionTitle('Permissions'),
        const SizedBox(height: 12),
        ..._getPermissionsForProfile(profileType).map(
          (permission) => _buildPermissionItem(
            permission['label'] as String,
            permission['granted'] as bool,
          ),
        ),
        const SizedBox(height: 24),

        // Fonctionnalités spéciales
        if (_getSpecialFeatures(profileType).isNotEmpty) ...[
          _buildSectionTitle('Fonctionnalités spéciales'),
          const SizedBox(height: 12),
          ..._getSpecialFeatures(profileType).map(
            (feature) => _buildFeatureItem(feature),
          ),
        ],
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w900,
        color: Colors.black87,
      ),
    );
  }

  Widget _buildSectionCard(String title, String subtitle, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.grey.shade700),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionItem(String label, bool granted) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: granted ? Colors.green.shade50 : Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: granted ? Colors.green.shade200 : Colors.red.shade200,
        ),
      ),
      child: Row(
        children: [
          Icon(
            granted ? Icons.check_circle : Icons.cancel,
            color: granted ? Colors.green : Colors.red,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: granted ? Colors.green.shade900 : Colors.red.shade900,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureItem(String feature) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.star, color: Colors.blue.shade700, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              feature,
              style: TextStyle(
                color: Colors.blue.shade900,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getColorForProfile(String profileType) {
    switch (profileType) {
      case 'SuperAdmin':
        return Colors.blue.shade900;
      case 'Admin':
        return Colors.indigo;
      case 'Administrateur groupe':
        return Colors.blue;
      case 'Tracker groupe':
        return Colors.green;
      case 'Créateur digital':
        return Colors.orange;
      case 'Compte Pro':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  IconData _getIconForProfile(String profileType) {
    switch (profileType) {
      case 'SuperAdmin':
        return Icons.shield;
      case 'Admin':
        return Icons.admin_panel_settings;
      case 'Administrateur groupe':
        return Icons.group;
      case 'Tracker groupe':
        return Icons.location_on;
      case 'Créateur digital':
        return Icons.photo_camera;
      case 'Compte Pro':
        return Icons.business;
      default:
        return Icons.person;
    }
  }

  String _getExampleName(String profileType) {
    switch (profileType) {
      case 'SuperAdmin':
        return 'Stéphane (SuperAdmin)';
      case 'Admin':
        return 'Marie Admin';
      case 'Administrateur groupe':
        return 'Luc Admin Groupe';
      case 'Tracker groupe':
        return 'Tom Tracker';
      case 'Créateur digital':
        return 'Jean Photographe';
      case 'Compte Pro':
        return 'Sarah Pro';
      default:
        return 'Pierre Utilisateur';
    }
  }

  List<Map<String, dynamic>> _getSectionsForProfile(String profileType) {
    final standard = [
      {
        'title': 'Mon Profil',
        'subtitle': 'Informations personnelles',
        'icon': Icons.person,
      },
      {
        'title': 'Favoris',
        'subtitle': 'Circuits et événements sauvegardés',
        'icon': Icons.favorite,
      },
      {
        'title': 'Historique',
        'subtitle': 'Achats et participations',
        'icon': Icons.history,
      },
    ];

    if (profileType == 'Compte Pro' || profileType == 'Créateur digital') {
      return [
        ...standard,
        {
          'title': 'Mon Commerce',
          'subtitle': 'Gestion boutique et produits',
          'icon': Icons.store,
        },
      ];
    }

    if (profileType == 'Administrateur groupe') {
      return [
        ...standard,
        {
          'title': 'Gestion Groupe',
          'subtitle': 'Membres, permissions, événements',
          'icon': Icons.group_work,
        },
        {
          'title': 'Circuits Groupe',
          'subtitle': 'Créer et gérer les circuits du groupe',
          'icon': Icons.route,
        },
        {
          'title': 'Statistiques',
          'subtitle': 'Analytics et suivi du groupe',
          'icon': Icons.bar_chart,
        },
      ];
    }

    if (profileType == 'Tracker groupe') {
      return [
        ...standard,
        {
          'title': 'Suivi GPS',
          'subtitle': 'Position en temps réel du groupe',
          'icon': Icons.my_location,
        },
        {
          'title': 'Carte Interactive',
          'subtitle': 'Visualiser le parcours et les membres',
          'icon': Icons.map,
        },
        {
          'title': 'Alertes',
          'subtitle': 'Notifications et sécurité',
          'icon': Icons.notifications_active,
        },
      ];
    }

    if (profileType == 'Admin' || profileType == 'SuperAdmin') {
      return [
        ...standard,
        {
          'title': 'Dashboard Admin',
          'subtitle': 'Vue d\'ensemble administration',
          'icon': Icons.dashboard,
        },
        {
          'title': 'Gestion Utilisateurs',
          'subtitle': 'CRUD utilisateurs et rôles',
          'icon': Icons.people,
        },
        {
          'title': 'Galerie Médias',
          'subtitle': 'Modération médias MAS\'LIVE',
          'icon': Icons.photo_library,
        },
      ];
    }

    return standard;
  }

  List<Map<String, dynamic>> _getPermissionsForProfile(String profileType) {
    switch (profileType) {
      case 'SuperAdmin':
        return [
          {'label': 'Accès complet administration', 'granted': true},
          {'label': 'Modifier tous les utilisateurs', 'granted': true},
          {'label': 'Supprimer contenus', 'granted': true},
          {'label': 'Upload médias', 'granted': true},
          {'label': 'Gérer boutique', 'granted': true},
          {'label': 'Accès analytics', 'granted': true},
        ];
      case 'Admin':
        return [
          {'label': 'Dashboard administration', 'granted': true},
          {'label': 'Gérer utilisateurs', 'granted': true},
          {'label': 'Modérer contenus', 'granted': true},
          {'label': 'Supprimer contenus', 'granted': false},
          {'label': 'Upload médias', 'granted': false},
        ];
      case 'Administrateur groupe':
        return [
          {'label': 'Gérer membres du groupe', 'granted': true},
          {'label': 'Créer événements groupe', 'granted': true},
          {'label': 'Créer circuits groupe', 'granted': true},
          {'label': 'Tracker en temps réel', 'granted': true},
          {'label': 'Modérer contenus', 'granted': false},
          {'label': 'Accès admin global', 'granted': false},
        ];
      case 'Tracker groupe':
        return [
          {'label': 'Voir position du groupe', 'granted': true},
          {'label': 'Recevoir alertes GPS', 'granted': true},
          {'label': 'Accès carte interactive', 'granted': true},
          {'label': 'Gérer membres', 'granted': false},
          {'label': 'Créer événements', 'granted': false},
        ];
      case 'Créateur digital':
        return [
          {'label': 'Upload photos/vidéos', 'granted': true},
          {'label': 'Gérer sa boutique', 'granted': true},
          {'label': 'Statistiques ventes', 'granted': true},
          {'label': 'Modérer contenus', 'granted': false},
        ];
      case 'Compte Pro':
        return [
          {'label': 'Créer boutique', 'granted': true},
          {'label': 'Vendre produits', 'granted': true},
          {'label': 'Statistiques ventes', 'granted': true},
          {'label': 'Upload médias', 'granted': false},
        ];
      default:
        return [
          {'label': 'Consulter circuits', 'granted': true},
          {'label': 'Acheter photos', 'granted': true},
          {'label': 'Sauvegarder favoris', 'granted': true},
          {'label': 'Créer boutique', 'granted': false},
          {'label': 'Upload médias', 'granted': false},
        ];
    }
  }

  List<String> _getSpecialFeatures(String profileType) {
    switch (profileType) {
      case 'SuperAdmin':
        return [
          'Accès complet Firebase Console',
          'Gestion des rôles et permissions',
          'Export données utilisateurs',
          'Configuration système',
        ];
      case 'Admin':
        return [
          'Dashboard analytics',
          'Validation comptes Pro',
          'Support utilisateurs',
        ];
      case 'Administrateur groupe':
        return [
          'Gestion complète du groupe',
          'Création circuits privés',
          'Tracking GPS temps réel',
          'Invitations membres illimitées',
        ];
      case 'Tracker groupe':
        return [
          'Suivi GPS en temps réel',
          'Alertes automatiques',
          'Historique trajets',
          'Export données parcours',
        ];
      case 'Créateur digital':
        return [
          'Upload illimité médias',
          'Galerie personnalisée',
          'Commission réduite (10%)',
        ];
      case 'Compte Pro':
        return [
          'Badge "Professionnel"',
          'Boutique personnalisée',
          'Statistiques ventes',
        ];
      default:
        return [];
    }
  }
}

class _ProfileTypeCard extends StatelessWidget {
  const _ProfileTypeCard({
    required this.profileType,
    required this.onTap,
  });

  final String profileType;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        elevation: 2,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _getColorForProfile(profileType).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _getIconForProfile(profileType),
                    color: _getColorForProfile(profileType),
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profileType,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _getDescription(profileType),
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 18,
                  color: Colors.grey.shade400,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getColorForProfile(String profileType) {
    switch (profileType) {
      case 'SuperAdmin':
        return Colors.blue.shade900;
      case 'Admin':
        return Colors.indigo;
      case 'Administrateur groupe':
        return Colors.blue;
      case 'Tracker groupe':
        return Colors.green;
      case 'Créateur digital':
        return Colors.orange;
      case 'Compte Pro':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  IconData _getIconForProfile(String profileType) {
    switch (profileType) {
      case 'SuperAdmin':
        return Icons.shield;
      case 'Admin':
        return Icons.admin_panel_settings;
      case 'Administrateur groupe':
        return Icons.group;
      case 'Tracker groupe':
        return Icons.location_on;
      case 'Créateur digital':
        return Icons.photo_camera;
      case 'Compte Pro':
        return Icons.business;
      default:
        return Icons.person;
    }
  }

  String _getDescription(String profileType) {
    switch (profileType) {
      case 'SuperAdmin':
        return 'Accès complet, tous les privilèges';
      case 'Admin':
        return 'Gestion utilisateurs et modération';
      case 'Administrateur groupe':
        return 'Gestion complète d\'un groupe carnaval';
      case 'Tracker groupe':
        return 'Suivi GPS temps réel du groupe';
      case 'Créateur digital':
        return 'Upload médias et vente photos';
      case 'Compte Pro':
        return 'Boutique et vente produits';
      default:
        return 'Accès standard à l\'application';
    }
  }
}
