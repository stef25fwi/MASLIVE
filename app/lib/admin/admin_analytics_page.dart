import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/user_repo.dart';
import '../theme/maslive_theme.dart';

/// Page d'analytics avancées pour les administrateurs
class AdminAnalyticsPage extends StatefulWidget {
  const AdminAnalyticsPage({super.key});

  @override
  State<AdminAnalyticsPage> createState() => _AdminAnalyticsPageState();
}

class _AdminAnalyticsPageState extends State<AdminAnalyticsPage> {
  final _userRepo = UserRepository.instance;
  
  Map<String, dynamic> _stats = {};
  List<Map<String, dynamic>> _recentActivity = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    setState(() => _isLoading = true);

    try {
      final now = DateTime.now();
      final last7Days = now.subtract(const Duration(days: 7));
      final last30Days = now.subtract(const Duration(days: 30));

      final results = await Future.wait([
        _userRepo.getTotalUsersCount(),
        _userRepo.getActiveUsersCount(),
        _userRepo.getUserStatsByRole(),
        _getUsersCreatedSince(last7Days),
        _getUsersCreatedSince(last30Days),
        _getRecentActivity(),
        _getLoginStats(last7Days),
      ]);

      setState(() {
        _stats = {
          'total': results[0],
          'active': results[1],
          'byRole': results[2],
          'newLast7Days': results[3],
          'newLast30Days': results[4],
          'loginStats': results[6],
        };
        _recentActivity = results[5] as List<Map<String, dynamic>>;
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

  Future<int> _getUsersCreatedSince(DateTime date) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(date))
        .count()
        .get();
    return snapshot.count ?? 0;
  }

  Future<List<Map<String, dynamic>>> _getRecentActivity() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .orderBy('updatedAt', descending: true)
        .limit(20)
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'userId': doc.id,
        'email': data['email'],
        'displayName': data['displayName'],
        'role': data['role'],
        'updatedAt': (data['updatedAt'] as Timestamp?)?.toDate(),
      };
    }).toList();
  }

  Future<Map<String, int>> _getLoginStats(DateTime since) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('lastLoginAt', isGreaterThanOrEqualTo: Timestamp.fromDate(since))
        .get();

    return {
      'uniqueLogins': snapshot.docs.length,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics Admin'),
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
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildOverviewCards(),
                    const SizedBox(height: 24),
                    _buildGrowthChart(),
                    const SizedBox(height: 24),
                    _buildRoleDistribution(),
                    const SizedBox(height: 24),
                    _buildActivityTimeline(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildOverviewCards() {
    final total = _stats['total'] ?? 0;
    final active = _stats['active'] ?? 0;
    final new7Days = _stats['newLast7Days'] ?? 0;
    final new30Days = _stats['newLast30Days'] ?? 0;
    final activeRate = total > 0 ? (active / total * 100).toStringAsFixed(1) : '0';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Vue d\'ensemble',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.5,
          children: [
            _buildMetricCard(
              'Utilisateurs totaux',
              total.toString(),
              Icons.people,
              Colors.blue,
            ),
            _buildMetricCard(
              'Taux d\'activation',
              '$activeRate%',
              Icons.trending_up,
              Colors.green,
            ),
            _buildMetricCard(
              'Nouveaux (7j)',
              new7Days.toString(),
              Icons.person_add,
              Colors.orange,
            ),
            _buildMetricCard(
              'Nouveaux (30j)',
              new30Days.toString(),
              Icons.group_add,
              Colors.purple,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricCard(String label, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGrowthChart() {
    final new7Days = _stats['newLast7Days'] ?? 0;
    final new30Days = _stats['newLast30Days'] ?? 0;
    final avgPerDay = new30Days / 30;
    final growth7Days = new7Days / 7;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Croissance',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildGrowthMetric(
                    'Moy. quotidienne (30j)',
                    avgPerDay.toStringAsFixed(1),
                    Icons.calendar_today,
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildGrowthMetric(
                    'Moy. quotidienne (7j)',
                    growth7Days.toStringAsFixed(1),
                    Icons.today,
                    Colors.green,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGrowthMetric(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[700],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildRoleDistribution() {
    final roleStats = _stats['byRole'] as Map<String, int>? ?? {};
    final total = _stats['total'] ?? 1;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Distribution des rôles',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            ...roleStats.entries.map((entry) {
              final count = entry.value;
              final percentage = (count / total * 100).toStringAsFixed(1);
              
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          entry.key,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        Text(
                          '$count ($percentage%)',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    LinearProgressIndicator(
                      value: count / total,
                      backgroundColor: Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation<Color>(
                        MasLiveTheme.getRoleColor(entry.key),
                      ),
                      minHeight: 6,
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityTimeline() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Activité récente',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                TextButton(
                  onPressed: () {
                    // Navigation vers page détaillée
                  },
                  child: const Text('Voir tout'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_recentActivity.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                  child: Text('Aucune activité récente'),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _recentActivity.take(10).length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final activity = _recentActivity[index];
                  final updatedAt = activity['updatedAt'] as DateTime?;
                  
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: MasLiveTheme.getRoleColor(activity['role']),
                      child: Text(
                        (activity['displayName'] as String?)?.substring(0, 1).toUpperCase() ??
                            (activity['email'] as String).substring(0, 1).toUpperCase(),
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    title: Text(
                      activity['displayName'] ?? activity['email'],
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    subtitle: Text(
                      'Mis à jour ${_formatDateTime(updatedAt)}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    trailing: Chip(
                      label: Text(
                        activity['role'],
                        style: const TextStyle(fontSize: 11),
                      ),
                    backgroundColor: MasLiveTheme.getRoleColor(activity['role']).withValues(alpha: 0.2),
                      padding: EdgeInsets.zero,
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime? date) {
    if (date == null) return 'jamais';
    
    final now = DateTime.now();
    final diff = now.difference(date);
    
    if (diff.inDays > 0) return 'il y a ${diff.inDays}j';
    if (diff.inHours > 0) return 'il y a ${diff.inHours}h';
    if (diff.inMinutes > 0) return 'il y a ${diff.inMinutes}min';
    return 'à l\'instant';
  }
}
