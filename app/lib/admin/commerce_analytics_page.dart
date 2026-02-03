import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Dashboard analytics commerce avec CA, conversions, stats
class CommerceAnalyticsPage extends StatefulWidget {
  const CommerceAnalyticsPage({super.key});

  @override
  State<CommerceAnalyticsPage> createState() => _CommerceAnalyticsPageState();
}

class _CommerceAnalyticsPageState extends State<CommerceAnalyticsPage> {
  final _firestore = FirebaseFirestore.instance;
  bool _isLoading = true;
  
  // Stats globales
  int _totalSubmissions = 0;
  int _pendingSubmissions = 0;
  int _approvedSubmissions = 0;
  int _rejectedSubmissions = 0;
  
  // Stats par type
  int _productSubmissions = 0;
  int _mediaSubmissions = 0;
  
  // Stats temporelles
  int _submissionsThisWeek = 0;
  int _submissionsThisMonth = 0;
  
  // Taux de conversion
  double _approvalRate = 0.0;
  double _rejectionRate = 0.0;

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    setState(() => _isLoading = true);
    
    try {
      final now = DateTime.now();
      final weekAgo = now.subtract(const Duration(days: 7));
      final monthAgo = now.subtract(const Duration(days: 30));
      
      // Query toutes les soumissions
      final allSnapshot = await _firestore.collection('commerce_submissions').get();
      final allDocs = allSnapshot.docs;
      
      _totalSubmissions = allDocs.length;
      
      // Compteurs
      var pending = 0;
      var approved = 0;
      var rejected = 0;
      var products = 0;
      var media = 0;
      var thisWeek = 0;
      var thisMonth = 0;
      
      for (final doc in allDocs) {
        final data = doc.data();
        final status = data['status'] as String?;
        final type = data['type'] as String?;
        final submittedAt = (data['submittedAt'] as Timestamp?)?.toDate();
        
        // Par statut
        if (status == 'pending') pending++;
        if (status == 'approved') approved++;
        if (status == 'rejected') rejected++;
        
        // Par type
        if (type == 'product') products++;
        if (type == 'media') media++;
        
        // Temporel
        if (submittedAt != null) {
          if (submittedAt.isAfter(weekAgo)) thisWeek++;
          if (submittedAt.isAfter(monthAgo)) thisMonth++;
        }
      }
      
      // Calculs
      _pendingSubmissions = pending;
      _approvedSubmissions = approved;
      _rejectedSubmissions = rejected;
      _productSubmissions = products;
      _mediaSubmissions = media;
      _submissionsThisWeek = thisWeek;
      _submissionsThisMonth = thisMonth;
      
      // Taux
      final processed = approved + rejected;
      if (processed > 0) {
        _approvalRate = (approved / processed) * 100;
        _rejectionRate = (rejected / processed) * 100;
      }
      
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur chargement analytics: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Analytics Commerce',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.black87),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAnalytics,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadAnalytics,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Stats globales
                  _buildSectionTitle('Vue d\'ensemble'),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          title: 'Total',
                          value: _totalSubmissions.toString(),
                          icon: Icons.inventory_2,
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          title: 'En attente',
                          value: _pendingSubmissions.toString(),
                          icon: Icons.hourglass_empty,
                          color: Colors.orange,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          title: 'Validés',
                          value: _approvedSubmissions.toString(),
                          icon: Icons.check_circle,
                          color: Colors.green,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          title: 'Refusés',
                          value: _rejectedSubmissions.toString(),
                          icon: Icons.cancel,
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  _buildSectionTitle('Par type'),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          title: 'Produits',
                          value: _productSubmissions.toString(),
                          icon: Icons.shopping_bag,
                          color: Colors.deepPurple,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          title: 'Médias',
                          value: _mediaSubmissions.toString(),
                          icon: Icons.photo_library,
                          color: Colors.orange,
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  _buildSectionTitle('Période récente'),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          title: '7 derniers jours',
                          value: _submissionsThisWeek.toString(),
                          icon: Icons.calendar_today,
                          color: Colors.teal,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          title: '30 derniers jours',
                          value: _submissionsThisMonth.toString(),
                          icon: Icons.calendar_month,
                          color: Colors.indigo,
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  _buildSectionTitle('Taux de conversion'),
                  const SizedBox(height: 12),
                  _buildProgressCard(
                    title: 'Taux d\'approbation',
                    percentage: _approvalRate,
                    color: Colors.green,
                  ),
                  const SizedBox(height: 12),
                  _buildProgressCard(
                    title: 'Taux de refus',
                    percentage: _rejectionRate,
                    color: Colors.red,
                  ),
                  
                  const SizedBox(height: 24),
                  _buildSectionTitle('Actions rapides'),
                  const SizedBox(height: 12),
                  _buildActionButton(
                    icon: Icons.pending_actions,
                    label: 'Voir les soumissions en attente',
                    onTap: () => Navigator.pushNamed(context, '/admin/moderation'),
                  ),
                  const SizedBox(height: 8),
                  _buildActionButton(
                    icon: Icons.list_alt,
                    label: 'Toutes les soumissions',
                    onTap: () {
                      // Navigation vers liste complète (à créer)
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Fonctionnalité à venir')),
                      );
                    },
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressCard({
    required String title,
    required double percentage,
    required Color color,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${percentage.toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: percentage / 100,
                minHeight: 8,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.blue.shade200),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.blue),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.blue,
                ),
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.blue),
          ],
        ),
      ),
    );
  }
}
