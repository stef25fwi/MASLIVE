// Dashboard Administrateur Groupe
// Affiche profil, code 6 chiffres, liste trackers, boutons actions

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/group_admin.dart';
import '../../models/group_tracker.dart';
import '../../services/group/group_link_service.dart';
import '../../services/group/group_tracking_service.dart';
import '../../ui/snack/top_snack_bar.dart';
import '../../widgets/group_map_visibility_widget.dart';
import 'group_map_live_page.dart';
import 'group_track_history_page.dart';
import 'group_export_page.dart';

class AdminGroupDashboardPage extends StatefulWidget {
  const AdminGroupDashboardPage({super.key});

  @override
  State<AdminGroupDashboardPage> createState() => _AdminGroupDashboardPageState();
}

class _AdminGroupDashboardPageState extends State<AdminGroupDashboardPage> {
  final _linkService = GroupLinkService.instance;
  final _trackingService = GroupTrackingService.instance;

  GroupAdmin? _admin;
  bool _isLoading = false;
  bool _isTracking = false;

  @override
  void initState() {
    super.initState();
    _loadAdminProfile();
  }

  Future<void> _loadAdminProfile() async {
    setState(() => _isLoading = true);
    try {
      final uid = _linkService.currentUid;
      if (uid != null) {
        final admin = await _linkService.getAdminProfile(uid);
        setState(() => _admin = admin);
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _createAdminProfile() async {
    final nameController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Créer profil Administrateur'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'Nom d\'affichage',
            hintText: 'Ex: Groupe Trail 2026',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Créer'),
          ),
        ],
      ),
    );

    if (confirmed == true && nameController.text.isNotEmpty) {
      setState(() => _isLoading = true);
      try {
        final admin = await _linkService.createAdminProfile(
          displayName: nameController.text,
        );
        setState(() => _admin = admin);
        
        if (mounted) {
          TopSnackBar.show(context,
            SnackBar(
              content: Text('Profil créé ! Code: ${admin.adminGroupId}'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          TopSnackBar.show(context,
            SnackBar(content: Text('Erreur: $e')),
          );
        }
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _toggleTracking() async {
    if (_admin == null) return;

    setState(() => _isLoading = true);
    try {
      if (_isTracking) {
        await _trackingService.stopTracking();
        setState(() => _isTracking = false);
        if (mounted) {
          TopSnackBar.show(context,
            const SnackBar(content: Text('Tracking arrêté')),
          );
        }
      } else {
        await _trackingService.startTracking(
          adminGroupId: _admin!.adminGroupId,
          role: 'admin',
        );
        setState(() => _isTracking = true);
        if (mounted) {
          TopSnackBar.show(context,
            const SnackBar(content: Text('Tracking démarré')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        TopSnackBar.show(context,
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleVisibility() async {
    if (_admin == null) return;

    final newVisibility = !_admin!.isVisible;
    
    setState(() => _isLoading = true);
    try {
      await _linkService.updateAdminVisibility(
        adminUid: _admin!.uid,
        isVisible: newVisibility,
      );
      setState(() => _admin = _admin!.copyWith(isVisible: newVisibility));
      
      if (mounted) {
        TopSnackBar.show(context,
          SnackBar(
            content: Text(newVisibility ? 'Groupe visible' : 'Groupe masqué'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        TopSnackBar.show(context,
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _copyCodeToClipboard() {
    if (_admin != null) {
      Clipboard.setData(ClipboardData(text: _admin!.adminGroupId));
      TopSnackBar.show(context,
        const SnackBar(content: Text('Code copié dans le presse-papier')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_admin == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Admin Groupe')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.admin_panel_settings, size: 100, color: Colors.grey),
              const SizedBox(height: 24),
              const Text(
                'Vous n\'avez pas encore de profil\nAdministrateur Groupe',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: _createAdminProfile,
                icon: const Icon(Icons.add),
                label: const Text('Créer mon profil Admin'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard Admin Groupe'),
        actions: [
          IconButton(
            icon: Icon(_admin!.isVisible ? Icons.visibility : Icons.visibility_off),
            onPressed: _toggleVisibility,
            tooltip: _admin!.isVisible ? 'Masquer groupe' : 'Rendre visible',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadAdminProfile,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildAdminCard(),
            const SizedBox(height: 16),
            _buildTrackingCard(),
            const SizedBox(height: 16),
            GroupMapVisibilityWidget(
              adminUid: _admin!.uid,
              groupId: _admin!.adminGroupId,
            ),
            const SizedBox(height: 16),
            _buildActionsGrid(),
            const SizedBox(height: 24),
            _buildTrackersList(),
          ],
        ),
      ),
    );
  }

  Widget _buildAdminCard() {
    final primary = Theme.of(context).colorScheme.primary;
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.admin_panel_settings, size: 40, color: primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _admin!.displayName,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Admin Groupe',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Code Groupe',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _admin!.adminGroupId,
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 4,
                        color: primary,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.copy),
                  onPressed: _copyCodeToClipboard,
                  tooltip: 'Copier le code',
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Partagez ce code avec vos trackers',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrackingCard() {
    return Card(
      elevation: 4,
      color: _isTracking ? Colors.green[50] : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      _isTracking ? Icons.gps_fixed : Icons.gps_off,
                      color: _isTracking ? Colors.green : Colors.grey,
                      size: 32,
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isTracking ? 'Tracking actif' : 'Tracking inactif',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          _isTracking ? 'Position envoyée en temps réel' : 'Démarrez pour commencer',
                          style: TextStyle(color: Colors.grey[600], fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: _toggleTracking,
                  icon: Icon(_isTracking ? Icons.stop : Icons.play_arrow),
                  label: Text(_isTracking ? 'Arrêter' : 'Démarrer'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isTracking ? Colors.red : Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionsGrid() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      children: [
        _buildActionButton(
          icon: Icons.map,
          label: 'Carte Live',
          color: Colors.blue,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => GroupMapLivePage(adminGroupId: _admin!.adminGroupId),
            ),
          ),
        ),
        _buildActionButton(
          icon: Icons.history,
          label: 'Historique',
          color: Colors.orange,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => GroupTrackHistoryPage(adminGroupId: _admin!.adminGroupId),
            ),
          ),
        ),
        _buildActionButton(
          icon: Icons.file_download,
          label: 'Exports',
          color: Colors.purple,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => GroupExportPage(adminGroupId: _admin!.adminGroupId),
            ),
          ),
        ),
        _buildActionButton(
          icon: Icons.analytics,
          label: 'Statistiques',
          color: Colors.teal,
          onTap: () {
            TopSnackBar.show(context,
              const SnackBar(content: Text('Page Stats à venir')),
            );
          },
        ),
        _buildActionButton(
          icon: Icons.store,
          label: 'Boutique',
          color: Colors.pink,
          onTap: () {
            TopSnackBar.show(context,
              const SnackBar(content: Text('Page Boutique à venir')),
            );
          },
        ),
        _buildActionButton(
          icon: Icons.photo_library,
          label: 'Médias',
          color: Colors.indigo,
          onTap: () {
            TopSnackBar.show(context,
              const SnackBar(content: Text('Page Médias à venir')),
            );
          },
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: color),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrackersList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Trackers rattachés',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        StreamBuilder<List<GroupTracker>>(
          stream: _linkService.streamAdminTrackers(_admin!.adminGroupId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.people_outline, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          'Aucun tracker rattaché',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Partagez le code ${_admin!.adminGroupId}',
                          style: TextStyle(color: Colors.grey[600], fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            final trackers = snapshot.data!;
            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: trackers.length,
              itemBuilder: (context, index) {
                final tracker = trackers[index];
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      child: Text(tracker.displayName[0].toUpperCase()),
                    ),
                    title: Text(tracker.displayName),
                    subtitle: Text(
                      tracker.lastPosition != null
                          ? 'Position: ${DateTime.now().difference(tracker.lastPosition!.timestamp).inSeconds}s'
                          : 'Aucune position',
                    ),
                    trailing: Icon(
                      tracker.lastPosition != null &&
                              DateTime.now().difference(tracker.lastPosition!.timestamp).inSeconds < 30
                          ? Icons.gps_fixed
                          : Icons.gps_off,
                      color: tracker.lastPosition != null &&
                              DateTime.now().difference(tracker.lastPosition!.timestamp).inSeconds < 30
                          ? Colors.green
                          : Colors.grey,
                    ),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }
}
