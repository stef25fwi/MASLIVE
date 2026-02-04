// Dashboard admin principal 10/10 avec toutes les fonctionnalités premium
// Section Assistant (step-by-step), quick actions, grid responsive, cards premium, badges, Stripe test avancé

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/app_user.dart';
import '../services/auth_claims_service.dart';
import '../theme/maslive_theme.dart';
import 'admin_tracking_page.dart';
import 'admin_orders_page.dart';
import 'admin_stock_page.dart';
import 'admin_product_categories_page.dart';
import 'admin_analytics_page.dart';
import 'admin_logs_page.dart';
import 'admin_system_settings_page.dart';
import 'user_management_page.dart';
import 'business_requests_page.dart';
import 'create_circuit_assistant_page.dart';
import 'poi_marketmap_wizard_page.dart';
import '../commerce_module_single_file.dart';
import 'admin_moderation_page.dart';
import 'commerce_analytics_page.dart';
import 'user_profile_preview_page.dart';

/// Dashboard admin principal 10/10 avec toutes les fonctionnalités
class AdminMainDashboard extends StatefulWidget {
  const AdminMainDashboard({super.key});

  @override
  State<AdminMainDashboard> createState() => _AdminMainDashboardState();
}

class _AdminMainDashboardState extends State<AdminMainDashboard> {
  final _authService = AuthClaimsService.instance;
  final _firestore = FirebaseFirestore.instance;
  AppUser? _currentUser;
  bool _isLoading = true;

  Stream<int> _watchProductsCount({String? shopId}) {
    final col = (shopId != null && shopId.trim().isNotEmpty)
        ? _firestore.collection('shops').doc(shopId).collection('products')
        : _firestore.collection('products');

    return col.snapshots().map((snap) => snap.size);
  }

  /// Compte les articles en attente de validation dans commerce_submissions
  Stream<int> _watchPendingCommerceSubmissionsCount() {
    return _firestore
        .collection('commerce_submissions')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snap) => snap.size);
  }

  int _computeTotalStock(Map<String, dynamic> data) {
    final raw = data['stockByVariant'];
    if (raw is Map) {
      var sum = 0;
      for (final v in raw.values) {
        if (v is int) sum += v;
        if (v is num) sum += v.toInt();
      }
      return sum;
    }

    final stock = data['stock'];
    if (stock is int) return stock;
    if (stock is num) return stock.toInt();
    return int.tryParse(stock?.toString() ?? '') ?? 0;
  }

  Stream<({int out, int low})> _watchStockAlerts({String? shopId}) {
    Query<Map<String, dynamic>> q = (shopId != null && shopId.trim().isNotEmpty)
        ? _firestore.collection('shops').doc(shopId).collection('products')
        : _firestore.collection('products');

    q = q.orderBy('updatedAt', descending: true).limit(400);

    return q.snapshots().map((snap) {
      var out = 0;
      var low = 0;
      for (final doc in snap.docs) {
        final stock = _computeTotalStock(doc.data());
        if (stock <= 0) {
          out++;
        } else if (stock <= 5) {
          low++;
        }
      }
      return (out: out, low: low);
    });
  }

  Widget _countBadge({required String text, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w900,
          color: color,
        ),
      ),
    );
  }

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
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
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
            // Tuiles "Parcours", "Points d'intérêt" et "Bibliothèque de Maps"
            // retirées pour simplifier le dashboard. L'entrée principale
            // pour les circuits et POI reste l'Assistant Wizard plus bas.
            _buildDashboardCard(
              title: 'MapMarket',
              subtitle: 'Créer / éditer / publier des cartes (Mapbox-only)',
              icon: Icons.map,
              color: Colors.blue,
              onTap: () => Navigator.pushNamed(context, '/admin/mapmarket'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildDashboardCard(
                    title: 'Mapbox Web (GL JS)',
                    subtitle: 'Carte Mapbox via HtmlElementView',
                    icon: Icons.public,
                    color: Colors.teal,
                    onTap: () => Navigator.pushNamed(context, '/mapbox-web'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildDashboardCard(
                    title: 'Assistant Wizard',
                    subtitle: 'Création guidée de circuits étape par étape',
                    icon: Icons.assistant,
                    color: Colors.purple,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            const AdminAssistantStepByStepHomePage(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildDashboardCard(
              title: 'Debug MarketMap (Firestore)',
              subtitle:
                  'Lister les pays / événements / circuits (structure marketMap)',
              icon: Icons.bug_report,
              color: Colors.grey,
              onTap: () => Navigator.pushNamed(
                context,
                '/admin/marketmap-debug',
              ),
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
                  child: StreamBuilder<int>(
                    stream: _watchProductsCount(shopId: 'global'),
                    builder: (context, snap) {
                      final count = snap.data;
                      return _buildDashboardCard(
                        title: 'Produits',
                        subtitle: 'Gestion produits (monolithique)',
                        icon: Icons.inventory,
                        color: Colors.teal,
                        badge: count == null
                            ? null
                            : _countBadge(text: '$count', color: Colors.teal),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ProductManagementPage(
                              shopId: 'global',
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildDashboardCard(
                    title: 'Commandes',
                    subtitle: 'Suivi & historique',
                    icon: Icons.receipt_long,
                    color: Colors.amber,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AdminOrdersPage(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildDashboardCard(
                    title: 'Aperçu boutique',
                    subtitle: 'Panier + checkout (monolithique)',
                    icon: Icons.storefront,
                    color: Colors.blue,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => BoutiquePage(
                          shopId: 'global',
                          userId:
                              FirebaseAuth.instance.currentUser?.uid ?? 'guest',
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: StreamBuilder<int>(
                    stream: _watchPendingCommerceSubmissionsCount(),
                    builder: (context, snap) {
                      final count = snap.data ?? 0;
                      return _buildDashboardCard(
                        title: 'Articles à valider',
                        subtitle: 'Modération des articles commerce',
                        icon: Icons.pending_actions,
                        color: Colors.orange,
                        badge: count <= 0
                            ? null
                            : _countBadge(
                                text: '$count',
                                color: const Color(0xFFB54708),
                              ),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AdminModerationPage(),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StreamBuilder<({int out, int low})>(
                    stream: _watchStockAlerts(shopId: 'global'),
                    builder: (context, snap) {
                      final d = snap.data;
                      final out = d?.out ?? 0;
                      final low = d?.low ?? 0;
                      final badge = out > 0
                          ? _countBadge(
                              text: 'Rupture $out',
                              color: const Color(0xFFB42318),
                            )
                          : (low > 0
                                ? _countBadge(
                                    text: 'Faible $low',
                                    color: const Color(0xFFB54708),
                                  )
                                : null);

                      return _buildDashboardCard(
                        title: 'Stock',
                        subtitle: 'Gestion des stocks',
                        icon: Icons.warehouse,
                        color: Colors.indigo,
                        badge: badge,
                        onTap: () => _showStockManagement(),
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildDashboardCard(
                    title: 'Modération Commerce',
                    subtitle: 'Valider produits & médias soumis',
                    icon: Icons.fact_check,
                    color: Colors.deepPurple,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AdminModerationPage(),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildDashboardCard(
                    title: 'Analytics Commerce',
                    subtitle: 'Stats & conversions',
                    icon: Icons.analytics,
                    color: Colors.blue,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const CommerceAnalyticsPage(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: _firestore
                        .collection('productCategories')
                        .limit(200)
                        .snapshots(),
                    builder: (context, catSnap) {
                      return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: _firestore
                            .collection('products')
                            .orderBy('updatedAt', descending: true)
                            .limit(800)
                            .snapshots(),
                        builder: (context, prodSnap) {
                          int? count;
                          if (catSnap.hasData || prodSnap.hasData) {
                            final set = <String>{};
                            if (catSnap.hasData) {
                              for (final d in catSnap.data!.docs) {
                                final name = (d.data()['name'] ?? '')
                                    .toString()
                                    .trim();
                                if (name.isNotEmpty) set.add(name);
                              }
                            }
                            if (prodSnap.hasData) {
                              for (final d in prodSnap.data!.docs) {
                                final c = (d.data()['category'] ?? '')
                                    .toString()
                                    .trim();
                                if (c.isNotEmpty) set.add(c);
                              }
                            }
                            count = set.length;
                          }

                          return _buildDashboardCard(
                            title: 'Catégories',
                            subtitle: 'Organiser les produits',
                            icon: Icons.category,
                            color: Colors.purple,
                            badge: count == null
                                ? null
                                : _countBadge(
                                    text: '$count',
                                    color: Colors.purple,
                                  ),
                            onTap: () => _showCategoryManagement(),
                          );
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildDashboardCard(
                    title: 'Test Stripe',
                    subtitle: 'Vérifier paiements',
                    icon: Icons.payment,
                    color: Colors.deepPurple,
                    onTap: () => _showStripeTestDialog(),
                  ),
                ),
              ],
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
                MaterialPageRoute(builder: (_) => const UserManagementPage()),
              ),
            ),
            const SizedBox(height: 12),
            _buildDashboardCard(
              title: 'Aperçu Profils',
              subtitle: 'Visualiser les types de profils utilisateurs',
              icon: Icons.preview,
              color: Colors.teal,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => UserProfilePreviewPage()),
              ),
            ),
            const SizedBox(height: 24),

            // Section Comptes Professionnels
            _buildSectionTitle('Comptes Professionnels', Icons.business),
            const SizedBox(height: 12),
            _buildDashboardCard(
              title: 'Demandes Pro',
              subtitle: 'Valider les demandes de comptes professionnels',
              icon: Icons.request_page,
              color: Colors.deepOrange,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BusinessRequestsPage()),
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
                      MaterialPageRoute(builder: (_) => const AdminLogsPage()),
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

            const SizedBox(height: 24),

            // Section Déploiement & CI/CD
            if (_currentUser?.isSuperAdmin == true) ...[
              _buildSectionTitle('Déploiement & CI/CD', Icons.rocket_launch),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildDashboardCard(
                      title: 'Commit & Push',
                      subtitle: 'Git commit et push vers GitHub',
                      icon: Icons.upload,
                      color: Colors.deepOrange,
                      onTap: () => _showCommitPushDialog(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildDashboardCard(
                      title: 'Build Web',
                      subtitle: 'Compiler l\'application Flutter',
                      icon: Icons.build_circle,
                      color: Colors.blue,
                      onTap: () => _showBuildDialog(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildDashboardCard(
                      title: 'Deploy Firebase',
                      subtitle: 'Déployer sur Firebase Hosting',
                      icon: Icons.cloud_upload,
                      color: Colors.amber,
                      onTap: () => _showDeployDialog(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildDashboardCard(
                      title: 'Pipeline Complet',
                      subtitle: 'Commit → Push → Build → Deploy',
                      icon: Icons.rocket,
                      color: Colors.green,
                      onTap: () => _showFullPipelineDialog(),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _showCommitPushDialog() async {
    final messageController = TextEditingController(
      text: 'Update via dashboard',
    );

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.upload, color: Colors.deepOrange),
            SizedBox(width: 12),
            Text('Commit & Push'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: messageController,
              decoration: const InputDecoration(
                labelText: 'Message de commit',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.message),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.orange.shade700,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Cette action va committer tous les changements et les pousser vers GitHub',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange.shade900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _executeGitCommitPush(messageController.text);
            },
            icon: const Icon(Icons.upload),
            label: const Text('Commit & Push'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepOrange,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _executeGitCommitPush(String message) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Commit & Push en cours...'),
          ],
        ),
      ),
    );

    try {
      // Exécuter les commandes Git
      final workingDir = '/workspaces/MASLIVE';

      // Git add
      await Process.run('git', ['add', '.'], workingDirectory: workingDir);

      // Git commit
      await Process.run('git', [
        'commit',
        '-m',
        message,
      ], workingDirectory: workingDir);

      // Git push
      final pushResult = await Process.run('git', [
        'push',
        'origin',
        'main',
      ], workingDirectory: workingDir);

      if (!mounted) return;
      Navigator.pop(context);

      if (pushResult.exitCode == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Text('Commit & Push réussi: "$message"'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      } else {
        throw Exception('Push failed: ${pushResult.stderr}');
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(child: Text('Erreur: ${e.toString()}')),
            ],
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  Future<void> _showBuildDialog() async {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.build_circle, color: Colors.blue),
            SizedBox(width: 12),
            Text('Build Web'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Compiler l\'application Flutter en mode Web:'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'flutter build web --release',
                style: TextStyle(fontFamily: 'monospace'),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.blue.shade700,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'La compilation peut prendre 1-2 minutes',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _executeBuild();
            },
            icon: const Icon(Icons.build),
            label: const Text('Compiler'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _executeBuild() async {
    // Afficher le dialogue de progression
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final workingDir = '/workspaces/MASLIVE/app';

      // Flutter build web
      final result = await Process.run('flutter', [
        'build',
        'web',
        '--release',
      ], workingDirectory: workingDir);

      if (!mounted) return;
      Navigator.pop(context);

      if (result.exitCode == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Text('Build réussi: app/build/web/'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      } else {
        throw Exception('Build failed: ${result.stderr}');
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur de build: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  Future<void> _showDeployDialog() async {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.cloud_upload, color: Colors.amber),
            SizedBox(width: 12),
            Text('Deploy Firebase'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Déployer l\'application sur Firebase Hosting:'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'firebase deploy --only hosting',
                    style: TextStyle(fontFamily: 'monospace'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning, color: Colors.orange.shade700, size: 20),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Assurez-vous que le build a été effectué',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _executeDeploy();
            },
            icon: const Icon(Icons.cloud_upload),
            label: const Text('Déployer'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _executeDeploy() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final workingDir = '/workspaces/MASLIVE';

      // Firebase deploy
      final result = await Process.run('firebase', [
        'deploy',
        '--only',
        'hosting',
      ], workingDirectory: workingDir);

      if (!mounted) return;
      Navigator.pop(context);

      if (result.exitCode == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Text('Déploiement réussi sur Firebase Hosting'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      } else {
        throw Exception('Deploy failed: ${result.stderr}');
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur de déploiement: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  Future<void> _showFullPipelineDialog() async {
    final messageController = TextEditingController(
      text: 'Deploy via dashboard',
    );

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.rocket, color: Colors.green),
            SizedBox(width: 12),
            Text('Pipeline Complet'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: messageController,
              decoration: const InputDecoration(
                labelText: 'Message de commit',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.message),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.green.shade700,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Étapes:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '1. Git commit & push',
                    style: TextStyle(fontSize: 12),
                  ),
                  const Text(
                    '2. Flutter build web',
                    style: TextStyle(fontSize: 12),
                  ),
                  const Text(
                    '3. Firebase deploy',
                    style: TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '⏱️ Durée estimée: 2-3 minutes',
                    style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              final message = messageController.text;
              Navigator.pop(context);
              _executeFullPipeline(message);
            },
            icon: const Icon(Icons.rocket_launch),
            label: const Text('Lancer'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _executeFullPipeline(String message) async {
    String currentStep = 'Initialisation...';
    late StateSetter dialogSetState;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) {
          dialogSetState = setState;
          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.rocket, color: Colors.green),
                SizedBox(width: 12),
                Text('Pipeline en cours'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(
                  currentStep,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const LinearProgressIndicator(),
              ],
            ),
          );
        },
      ),
    );

    try {
      final workingDir = '/workspaces/MASLIVE';
      final appDir = '/workspaces/MASLIVE/app';

      // Étape 1: Git commit & push
      dialogSetState(() => currentStep = '1/3 Git commit & push...');

      await Process.run('git', ['add', '.'], workingDirectory: workingDir);
      await Process.run('git', [
        'commit',
        '-m',
        message,
      ], workingDirectory: workingDir);
      final pushResult = await Process.run('git', [
        'push',
        'origin',
        'main',
      ], workingDirectory: workingDir);

      if (pushResult.exitCode != 0) {
        throw Exception('Git push failed: ${pushResult.stderr}');
      }

      if (!mounted) return;
      dialogSetState(() => currentStep = '✓ Git commit & push');

      // Étape 2: Build
      dialogSetState(() => currentStep = '2/3 Flutter build web...');

      final buildResult = await Process.run('flutter', [
        'build',
        'web',
        '--release',
      ], workingDirectory: appDir);

      if (buildResult.exitCode != 0) {
        throw Exception('Build failed: ${buildResult.stderr}');
      }

      if (!mounted) return;
      dialogSetState(() => currentStep = '✓ Flutter build web');

      // Étape 3: Deploy
      dialogSetState(() => currentStep = '3/3 Firebase deploy...');

      final deployResult = await Process.run('firebase', [
        'deploy',
        '--only',
        'hosting',
      ], workingDirectory: workingDir);

      if (deployResult.exitCode != 0) {
        throw Exception('Deploy failed: ${deployResult.stderr}');
      }

      if (!mounted) return;
      dialogSetState(() => currentStep = '✓ Firebase deploy');

      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;

      Navigator.pop(context); // Fermer loading dialog

      // Afficher succès
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 12),
                  Text(
                    'Pipeline terminé !',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text('Commit: "$message"', style: const TextStyle(fontSize: 12)),
            ],
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 5),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur pipeline: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  void _showStockManagement() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AdminStockPage(shopId: 'global')),
    );
  }

  void _showCategoryManagement() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AdminProductCategoriesPage()),
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

                    final functionsInstance = FirebaseFunctions.instanceFor(
                      region: 'europe-west1',
                    );
                    final callable = functionsInstance.httpsCallable(
                      'createCheckoutSessionForOrder',
                    );

                    setState(() {
                      status = 'Appel de createCheckoutSessionForOrder...';
                    });

                    final response = await callable
                        .call({
                          'orderId':
                              'test_${DateTime.now().millisecondsSinceEpoch}',
                        })
                        .timeout(
                          const Duration(seconds: 10),
                          onTimeout: () => throw TimeoutException(
                            'Le test a dépassé le délai (10s)',
                          ),
                        );

                    setState(() {
                      status = 'Test terminé avec succès';
                      result =
                          '''✓ Connexion Stripe établie

Réponse reçue:
${response.data.toString()}

La Cloud Function a réussi à communiquer avec Stripe.''';
                      isLoading = false;
                    });
                  } catch (e) {
                    setState(() {
                      result =
                          '''Erreur lors du test Stripe

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
              backgroundColor: MasLiveTheme.getRoleColor(
                _currentUser?.role ?? 'admin',
              ),
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
                      color: MasLiveTheme.getRoleColor(
                        _currentUser?.role ?? 'admin',
                      ),
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
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildDashboardCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    Widget? badge,
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
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (badge != null) ...[const SizedBox(width: 10), badge],
                ],
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AdminAssistantStepByStepHomePage extends StatelessWidget {
  const AdminAssistantStepByStepHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(title: const Text('Assistant (step-by-step)')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _AssistantCard(
            title: 'Créer un circuit (Wizard)',
            subtitle:
                'Périmètre → Offline → Tracé → Segments → Flèches → Styles → Publier',
            icon: Icons.route_rounded,
            color: const Color(0xFF1A73E8),
            badge: 'New',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const CreateCircuitAssistantPage(),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          _AssistantCard(
            title: 'Assistant POI (Wizard)',
            subtitle:
                'Pays → Événement → Circuit → Couches → POIs (visibilité)',
            icon: Icons.place_rounded,
            color: const Color(0xFFFF7A00),
            badge: 'New',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const POIMarketMapWizardPage()),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _AssistantCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String? badge;
  final VoidCallback onTap;

  const _AssistantCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.badge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 32),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (badge != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              badge!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }
}
