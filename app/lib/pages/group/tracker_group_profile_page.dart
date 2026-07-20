import 'package:flutter/material.dart';

import '../../models/group_tracker.dart';
import '../../security/profile_capability_policy.dart';
import '../../services/group/group_link_qr.dart';
import '../../services/group/group_link_service.dart';
import '../../services/group/group_tracking_service.dart';
import '../../ui/snack/top_snack_bar.dart';
import '../../ui/widgets/maslive_button.dart';
import '../../widgets/capability_guard.dart';
import 'group_export_page.dart';
import 'group_qr_scanner_page.dart';
import 'group_track_history_page.dart';

class TrackerGroupProfilePage extends StatelessWidget {
  const TrackerGroupProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return CapabilityGuard(
      capability: Capability.trackOwnLocation,
      fullPage: true,
      message: 'Un profil Tracker Groupe rattaché est requis.',
      child: const _TrackerGroupProfileContent(),
    );
  }
}

class _TrackerGroupProfileContent extends StatefulWidget {
  const _TrackerGroupProfileContent();

  @override
  State<_TrackerGroupProfileContent> createState() =>
      _TrackerGroupProfileContentState();
}

class _TrackerGroupProfileContentState
    extends State<_TrackerGroupProfileContent> {
  final GroupLinkService _linkService = GroupLinkService.instance;
  final GroupTrackingService _trackingService = GroupTrackingService.instance;
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();

  GroupTracker? _tracker;
  bool _loading = false;
  bool _tracking = false;

  @override
  void initState() {
    super.initState();
    _loadTrackerProfile();
  }

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadTrackerProfile() async {
    setState(() => _loading = true);
    try {
      final uid = _linkService.currentUid;
      final tracker = uid == null ? null : await _linkService.getTrackerProfile(uid);
      if (!mounted) return;
      setState(() {
        _tracker = tracker;
        final groupId = tracker?.adminGroupId;
        _tracking = groupId != null &&
            _trackingService.isTrackingFor(
              adminGroupId: groupId,
              role: 'tracker',
            );
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _scanQr() async {
    final raw = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(builder: (_) => const GroupQrScannerPage()),
    );
    if (!mounted || raw == null) return;
    final payload = parseGroupQrPayload(raw);
    if (payload == null) {
      TopSnackBar.show(
        context,
        const SnackBar(content: Text('QR groupe invalide')),
      );
      return;
    }
    _codeController.text = payload.code;
    if (_nameController.text.trim().isNotEmpty) await _linkToAdmin();
  }

  Future<void> _linkToAdmin() async {
    final code = _codeController.text.trim();
    final name = _nameController.text.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(code) || name.isEmpty) {
      TopSnackBar.show(
        context,
        const SnackBar(content: Text('Code 6 chiffres et nom requis')),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      final tracker = await _linkService.linkTrackerToAdmin(
        adminGroupId: code,
        displayName: name,
      );
      if (!mounted) return;
      setState(() => _tracker = tracker);
      TopSnackBar.show(
        context,
        const SnackBar(
          content: Text('Rattachement réussi'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (error) {
      if (mounted) {
        TopSnackBar.show(context, SnackBar(content: Text('Erreur : $error')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleTracking() async {
    final groupId = _tracker?.adminGroupId;
    if (groupId == null) return;
    setState(() => _loading = true);
    try {
      if (_tracking) {
        await _trackingService.stopTracking();
      } else {
        await _trackingService.startTracking(
          adminGroupId: groupId,
          role: 'tracker',
        );
      }
      if (mounted) setState(() => _tracking = !_tracking);
    } catch (error) {
      if (mounted) {
        TopSnackBar.show(context, SnackBar(content: Text('Erreur : $error')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Tracker Groupe')),
      body: _tracker?.isLinked == true ? _buildLinkedView() : _buildUnlinkedView(),
    );
  }

  Widget _buildUnlinkedView() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            children: <Widget>[
              const Icon(Icons.link_off, size: 88, color: Colors.grey),
              const SizedBox(height: 20),
              const Text(
                'Rattachement à un groupe',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Votre nom',
                  prefixIcon: Icon(Icons.person),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _codeController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: const InputDecoration(
                  labelText: 'Code Admin Groupe',
                  prefixIcon: Icon(Icons.numbers),
                  border: OutlineInputBorder(),
                ),
              ),
              OutlinedButton.icon(
                onPressed: _scanQr,
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('Scanner le QR du groupe'),
              ),
              const SizedBox(height: 12),
              MasliveButton(
                label: 'Se rattacher avec le code',
                icon: Icons.link,
                onPressed: _linkToAdmin,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLinkedView() {
    final tracker = _tracker!;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        Card(
          child: ListTile(
            leading: const CircleAvatar(
              child: Icon(Icons.check_circle_outline),
            ),
            title: Text(
              tracker.displayName,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            subtitle: Text('Groupe : ${tracker.adminGroupId}'),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          color: _tracking ? Colors.green.shade50 : null,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: <Widget>[
                Icon(
                  _tracking ? Icons.gps_fixed : Icons.gps_off,
                  size: 48,
                  color: _tracking ? Colors.green : Colors.grey,
                ),
                const SizedBox(height: 10),
                Text(
                  _tracking ? 'Tracking actif' : 'Tracking inactif',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _toggleTracking,
                  icon: Icon(_tracking ? Icons.stop : Icons.play_arrow),
                  label: Text(_tracking ? 'Arrêter' : 'Démarrer'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        ListTile(
          leading: const Icon(Icons.history),
          title: const Text('Mon historique'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => GroupTrackHistoryPage(
                adminGroupId: tracker.adminGroupId!,
                uid: _linkService.currentUid,
              ),
            ),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.file_download_outlined),
          title: const Text('Mes exports'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => GroupExportPage(
                adminGroupId: tracker.adminGroupId!,
                uid: _linkService.currentUid,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
