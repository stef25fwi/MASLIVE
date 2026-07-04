// Page profil Tracker Groupe - Rattachement à un admin

import 'package:flutter/material.dart';
import '../../models/group_tracker.dart';
import '../../services/group/group_link_service.dart';
import '../../services/group/group_link_qr.dart';
import '../../services/group/group_tracking_service.dart';
import '../../ui/snack/top_snack_bar.dart';
import 'group_qr_scanner_page.dart';
import 'group_track_history_page.dart';
import 'group_export_page.dart';

class TrackerGroupProfilePage extends StatefulWidget {
  const TrackerGroupProfilePage({super.key});

  @override
  State<TrackerGroupProfilePage> createState() => _TrackerGroupProfilePageState();
}

class _TrackerGroupProfilePageState extends State<TrackerGroupProfilePage> {
  final _linkService = GroupLinkService.instance;
  final _trackingService = GroupTrackingService.instance;
  final _codeController = TextEditingController();
  final _nameController = TextEditingController();

  GroupTracker? _tracker;
  bool _isLoading = false;
  bool _isTracking = false;

  @override
  void initState() {
    super.initState();
    _loadTrackerProfile();
  }

  Future<void> _loadTrackerProfile() async {
    setState(() => _isLoading = true);
    try {
      final uid = _linkService.currentUid;
      if (uid != null) {
        final tracker = await _linkService.getTrackerProfile(uid);
        setState(() => _tracker = tracker);
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _scanQr() async {
    final raw = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const GroupQrScannerPage()),
    );
    if (!mounted || raw == null) return;

    final payload = parseGroupQrPayload(raw);
    if (payload == null) {
      TopSnackBar.show(
        context,
        const SnackBar(content: Text('QR non reconnu (code groupe introuvable)')),
      );
      return;
    }

    setState(() => _codeController.text = payload.code);

    // Confirmation affichant le nom du groupe (si présent dans le QR).
    final groupLabel = (payload.groupName != null &&
            payload.groupName!.trim().isNotEmpty)
        ? '« ${payload.groupName!.trim()} »'
        : 'ce groupe (code ${payload.code})';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rejoindre le groupe'),
        content: Text('Veux-tu rejoindre $groupLabel ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Rejoindre'),
          ),
        ],
      ),
    );
    if (!mounted || confirm != true) return;

    // Si le nom est déjà renseigné, on rattache directement après confirmation.
    if (_nameController.text.trim().isNotEmpty) {
      await _linkToAdmin();
    } else {
      TopSnackBar.show(
        context,
        const SnackBar(content: Text('Code validé. Saisis ton nom puis rattache-toi.')),
      );
    }
  }

  Future<void> _linkToAdmin() async {
    if (_codeController.text.length != 6 || _nameController.text.isEmpty) {
      TopSnackBar.show(
        context,
        const SnackBar(content: Text('Code 6 chiffres et nom requis')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final tracker = await _linkService.linkTrackerToAdmin(
        adminGroupId: _codeController.text,
        displayName: _nameController.text,
      );
      setState(() => _tracker = tracker);
      
      if (mounted) {
        TopSnackBar.show(
          context,
          const SnackBar(
            content: Text('Rattachement réussi !'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        TopSnackBar.show(
          context,
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleTracking() async {
    if (_tracker?.adminGroupId == null) return;

    setState(() => _isLoading = true);
    try {
      if (_isTracking) {
        await _trackingService.stopTracking();
        setState(() => _isTracking = false);
      } else {
        await _trackingService.startTracking(
          adminGroupId: _tracker!.adminGroupId!,
          role: 'tracker',
        );
        setState(() => _isTracking = true);
      }
    } catch (e) {
      if (mounted) {
        TopSnackBar.show(
          context,
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    } finally {
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
      appBar: AppBar(title: const Text('Tracker Groupe')),
      body: _tracker?.isLinked == true
          ? _buildLinkedView()
          : _buildUnlinkedView(),
    );
  }

  Widget _buildUnlinkedView() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.link_off, size: 100, color: Colors.grey),
          const SizedBox(height: 24),
          const Text(
            'Rattachement à un groupe',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 32),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Votre nom',
              prefixIcon: Icon(Icons.person),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _codeController,
            decoration: const InputDecoration(
              labelText: 'Code Admin (6 chiffres)',
              prefixIcon: Icon(Icons.numbers),
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
            maxLength: 6,
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _isLoading ? null : _scanQr,
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('Scanner le QR du groupe'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'ou',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: _isLoading ? null : _linkToAdmin,
            icon: const Icon(Icons.link),
            label: const Text('Se rattacher avec le code'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLinkedView() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const Icon(Icons.check_circle, size: 64, color: Colors.green),
                const SizedBox(height: 16),
                Text(
                  _tracker!.displayName,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text('Groupe: ${_tracker!.adminGroupId}'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          color: _isTracking ? Colors.green[50] : null,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Icon(
                  _isTracking ? Icons.gps_fixed : Icons.gps_off,
                  size: 48,
                  color: _isTracking ? Colors.green : Colors.grey,
                ),
                const SizedBox(height: 12),
                Text(
                  _isTracking ? 'Tracking actif' : 'Tracking inactif',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
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
          ),
        ),
        const SizedBox(height: 16),
        ListTile(
          leading: const Icon(Icons.history),
          title: const Text('Mon historique'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => GroupTrackHistoryPage(
                adminGroupId: _tracker!.adminGroupId!,
                uid: _linkService.currentUid,
              ),
            ),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.file_download),
          title: const Text('Mes exports'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => GroupExportPage(
                adminGroupId: _tracker!.adminGroupId!,
                uid: _linkService.currentUid,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
