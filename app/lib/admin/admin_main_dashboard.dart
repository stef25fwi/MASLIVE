import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/app_user.dart';
import '../services/auth_claims_service.dart';
import '../theme/maslive_theme.dart';
import 'admin_circuits_page.dart';
import 'admin_pois_simple_page.dart';
import 'admin_tracking_page.dart';
import 'admin_products_page.dart';
import 'admin_analytics_page.dart';
import 'admin_logs_page.dart';
import 'admin_system_settings_page.dart';
import 'user_management_page.dart';

/// Dashboard admin principal 10/10 avec toutes les fonctionnalités
class AdminMainDashboard extends StatefulWidget {
  const AdminMainDashboard({super.key});

  @override
  State<AdminMainDashboard> createState() => _AdminMainDashboardState();
}

class _AdminMainDashboardState extends State<AdminMainDashboard> {
  final _authService = AuthClaimsService.instance;
  AppUser? _currentUser;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    setState(() => _isLoading = true);
    try {
      final user = await _authService.getCurrentAppUser();
      setState(() {
        _currentUser = user;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Administration MASLIVE'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadUser,
            tooltip: 'Rafraîchir',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header avec info utilisateur
            _buildWelcomeCard(),
            const SizedBox(height: 24),

            // Section Carte & Navigation
            _buildSectionTitle('Carte & Navigation', Icons.map),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildDashboardCard(
                    title: 'Parcours',
                    subtitle: 'Créer et gérer les circuits',
                    icon: Icons.route,
                    color: Colors.blue,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AdminCircuitsPage(),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildDashboardCard(
                    title: 'Points d\'intérêt',
                    subtitle: 'Gérer les POIs',
                    icon: Icons.place,
                    color: Colors.orange,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AdminPOIsSimplePage(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Section Tracking & Groupes
            _buildSectionTitle('Tracking & Groupes', Icons.groups),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildDashboardCard(
                    title: 'Tracking Live',
                    subtitle: 'Suivre les groupes en temps réel',
                    icon: Icons.my_location,
                    color: Colors.green,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AdminTrackingPage(),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildDashboardCard(
                    title: 'Groupes',
                    subtitle: 'Gérer les groupes',
                    icon: Icons.group,
                    color: Colors.purple,
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Page groupes à venir')),
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Section Commerce
            _buildSectionTitle('Commerce', Icons.shopping_bag),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildDashboardCard(
                    title: 'Produits',
                    subtitle: 'Gérer le catalogue',
                    icon: Icons.inventory,
                    color: Colors.teal,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AdminProductsPage(),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildDashboardCard(
                    title: 'Commandes',
                    subtitle: 'Suivi des commandes',
                    icon: Icons.receipt_long,
                    color: Colors.amber,
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Page commandes à venir')),
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildDashboardCard(
              title: 'Test Stripe',
              subtitle: 'Vérifier la connexion Stripe',
              icon: Icons.payment,
              color: Colors.deepPurple,
              onTap: () => _showStripeTestDialog(),
            ),
            const SizedBox(height: 24),

            // Section Utilisateurs
            _buildSectionTitle('Utilisateurs', Icons.people),
            const SizedBox(height: 12),
            _buildDashboardCard(
              title: 'Gestion des utilisateurs',
              subtitle: 'Créer, modifier, gérer les rôles',
              icon: Icons.admin_panel_settings,
              color: Colors.indigo,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const UserManagementPage(),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Section Analytics & Système
            _buildSectionTitle('Analytics & Système', Icons.analytics),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildDashboardCard(
                    title: 'Analytics',
                    subtitle: 'Statistiques détaillées',
                    icon: Icons.bar_chart,
                    color: Colors.cyan,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AdminAnalyticsPage(),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildDashboardCard(
                    title: 'Logs',
                    subtitle: 'Journaux système',
                    icon: Icons.description,
                    color: Colors.blueGrey,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AdminLogsPage(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_currentUser?.isSuperAdmin == true)
              _buildDashboardCard(
                title: 'Paramètres système',
                subtitle: 'Configuration avancée (Super Admin)',
                icon: Icons.settings,
                color: Colors.red,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AdminSystemSettingsPage(),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _showStripeTestDialog() async {
    bool isLoading = false;
    String status = 'Préparation du test...';
    String? result;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Test de connexion Stripe'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isLoading)
                  const SizedBox(
                    height: 100,
                    child: Center(child: CircularProgressIndicator()),
                  )
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Ce test appelle la Cloud Function Stripe et vérifie la connexion au service de paiement.',
                        style: TextStyle(fontSize: 12),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          status,
                          style: TextStyle(
                            fontSize: 13,
                            fontFamily: 'monospace',
                            color: Colors.grey[700],
                          ),
                        ),
                      ),
                      if (result != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: result!.contains('Erreur')
                                ? Colors.red[50]
                                : Colors.green[50],
                            border: Border.all(
                              color: result!.contains('Erreur')
                                  ? Colors.red
                                  : Colors.green,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    result!.contains('Erreur')
                                        ? Icons.error
                                        : Icons.check_circle,
                                    color: result!.contains('Erreur')
                                        ? Colors.red
                                        : Colors.green,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      result!.contains('Erreur')
                                          ? 'Erreur'
                                          : 'Succès',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: result!.contains('Erreur')
                                            ? Colors.red
                                            : Colors.green,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                result!,
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
              ],
            ),
          ),
          actions: [
            if (!isLoading)
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Fermer'),
              ),
            if (!isLoading && result == null)
              ElevatedButton.icon(
                onPressed: () async {
                  setState(() {
                    isLoading = true;
                    status = 'Appel de la Cloud Function...';
                  });

                  try {
                    final user = FirebaseAuth.instance.currentUser;
                    if (user == null) {
                      setState(() {
                        result =
                            'Erreur: Utilisateur non authentifié\n\nVous devez être connecté pour lancer le test.';
                        isLoading = false;
                      });
                      return;
                    }

                    setState(() {
                      status = 'Création d\'une commande de test...';
                    });

                    final functionsInstance =
                        FirebaseFunctions.instanceFor(region: 'europe-west1');
                    final callable = functionsInstance
                        .httpsCallable('createCheckoutSessionForOrder');

                    setState(() {
                      status = 'Appel de createCheckoutSessionForOrder...';
                    });

                    final response = await callable.call({
                      'orderId': 'test_${DateTime.now().millisecondsSinceEpoch}',
                    }).timeout(
                      const Duration(seconds: 10),
                      onTimeout: () => throw TimeoutException(
                          'Le test a dépassé le délai (10s)'),
                    );

                    setState(() {
                      status = 'Test terminé avec succès';
                      result = '''✓ Connexion Stripe établie

Réponse reçue:
${response.data.toString()}

La Cloud Function a réussi à communiquer avec Stripe.''';
                      isLoading = false;
                    });
                  } catch (e) {
                    setState(() {
                      result = '''Erreur lors du test Stripe

$e

Vérifiez:
• La clé Stripe est configurée
• La connexion Internet fonctionne
• Les Cloud Functions sont déployées''';
                      isLoading = false;
                    });
                  }
                },
                icon: const Icon(Icons.play_arrow),
                label: const Text('Lancer le test'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: MasLiveTheme.getRoleColor(_currentUser?.role ?? 'admin'),
              child: Text(
                _currentUser?.initials ?? 'AD',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bonjour, ${_currentUser?.displayName ?? _currentUser?.email ?? 'Admin'}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _currentUser?.roleLabel ?? 'Administrateur',
                    style: TextStyle(
                      color: MasLiveTheme.getRoleColor(_currentUser?.role ?? 'admin'),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 24, color: Colors.grey[700]),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildDashboardCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
