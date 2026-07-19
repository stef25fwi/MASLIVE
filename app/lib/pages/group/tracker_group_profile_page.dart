// Page profil Tracker Groupe - Rattachement à un admin

import 'package:flutter/material.dart';

import '../../models/group_tracker.dart';
import '../../services/group/group_link_qr.dart';
import '../../services/group/group_link_service.dart';
import '../../services/group/group_tracking_consent_service.dart';
import '../../services/group/group_tracking_service.dart';
import '../../ui/snack/top_snack_bar.dart';
import '../../ui/widgets/maslive_button.dart';
import 'group_export_page.dart';
import 'group_qr_scanner_page.dart';
import 'group_track_history_page.dart';

class TrackerGroupProfilePage extends StatefulWidget {
  const TrackerGroupProfilePage({super.key});

  @override
  State<TrackerGroupProfilePage> createState() =>
      _TrackerGroupProfilePageState();
}

class _TrackerGroupProfilePageState extends State<TrackerGroupProfilePage> {
  final _linkService = GroupLinkService.instance;
  final _trackingService = GroupTrackingService.instance;
  final _consentService = GroupTrackingConsentService.instance;
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

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadTrackerProfile() async {
    setState(() => _isLoading = true);
    try {
      final uid = _linkService.currentUid;
      if (uid != null) {
        final tracker = await _linkService.getTrackerProfile(uid);
        if (!mounted) return;
        setState(() {
          _tracker = tracker;
          final groupId = tracker?.adminGroupId;
          _isTracking =
              groupId != null &&
              _trackingService.isTrackingFor(
                adminGroupId: groupId,
                role: 'tracker',
              );
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
        const SnackBar(
          content: Text('QR non reconnu (code groupe introuvable)'),
        ),
      );
      return;
    }

    setState(() => _codeController.text = payload.code);

    final groupLabel =
        (payload.groupName != null && payload.groupName!.trim().isNotEmpty)
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

    if (_nameController.text.trim().isNotEmpty) {
      await _linkToAdmin();
    } else {
      TopSnackBar.show(
        context,
        const SnackBar(
          content: Text('Code validé. Saisis ton nom puis rattache-toi.'),
        ),
      );
    }
  }

  Future<void> _linkToAdmin() async {
    if (_codeController.text.length != 6 ||
        _nameController.text.trim().isEmpty) {
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
        displayName: _nameController.text.trim(),
      );
      if (!mounted) return;
      setState(() => _tracker = tracker);

      TopSnackBar.show(
        context,
        const SnackBar(
          content: Text('Rattachement réussi !'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (mounted) {
        TopSnackBar.show(context, SnackBar(content: Text('Erreur: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<bool> _requestTrackingConsent() async {
    final groupId = _tracker?.adminGroupId;
    if (groupId == null) return false;

    var accepted = false;
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: const Text('Autoriser le tracking du groupe'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Votre position sera partagée avec le groupe $groupId pendant cette session.',
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Cadence adaptative : environ 15 s en mouvement, 45 s à faible vitesse et 60 s à l’arrêt. L’historique est enregistré moins souvent afin de limiter la batterie et les données.',
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Vous pouvez arrêter le partage à tout moment depuis cet écran. L’arrêt ferme la session et la rend disponible dans votre historique.',
                    ),
                    const SizedBox(height: 12),
                    CheckboxListTile(
                      value: accepted,
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: const Text(
                        'J’accepte le partage de ma position pour cette session.',
                      ),
                      onChanged: (value) {
                        setDialogState(() => accepted = value == true);
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Annuler'),
                ),
                FilledButton.icon(
                  onPressed: accepted
                      ? () => Navigator.of(dialogContext).pop(true)
                      : null,
                  icon: const Icon(Icons.gps_fixed),
                  label: const Text('Autoriser et démarrer'),
                ),
              ],
            );
          },
        );
      },
    );

    return result == true;
  }

  Future<void> _toggleTracking() async {
    final groupId = _tracker?.adminGroupId;
    if (groupId == null) return;

    if (_isTracking) {
      await _stopTracking();
      return;
    }

    final accepted = await _requestTrackingConsent();
    if (!accepted || !mounted) return;

    setState(() => _isLoading = true);
    try {
      await _consentService.recordAcceptance(
        adminGroupId: groupId,
        role: 'tracker',
      );
      await _trackingService.startTracking(
        adminGroupId: groupId,
        role: 'tracker',
      );
      if (!mounted) return;
      setState(() => _isTracking = true);
      TopSnackBar.show(
        context,
        const SnackBar(
          content: Text('Tracking démarré. Votre groupe peut vous suivre.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (mounted) {
        TopSnackBar.show(context, SnackBar(content: Text('Erreur: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _stopTracking() async {
    setState(() => _isLoading = true);
    var stopped = false;
    try {
      await _trackingService.stopTracking();
      stopped = true;
      if (!mounted) return;
      setState(() => _isTracking = false);
    } catch (e) {
      if (mounted) {
        TopSnackBar.show(context, SnackBar(content: Text('Erreur: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }

    if (stopped && mounted) {
      await _showTrackingStoppedDialog();
    }
  }

  Future<void> _showTrackingStoppedDialog() async {
    final viewHistory = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.check_circle, color: Colors.green, size: 42),
        title: const Text('Tracking arrêté'),
        content: const Text(
          'La session est fermée. Votre position live n’est plus partagée et le parcours est disponible dans votre historique.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Fermer'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            icon: const Icon(Icons.history),
            label: const Text('Voir l’historique'),
          ),
        ],
      ),
    );

    if (viewHistory == true && mounted) {
      await _openHistory();
    }
  }

  Future<void> _openHistory() async {
    final groupId = _tracker?.adminGroupId;
    if (groupId == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GroupTrackHistoryPage(
          adminGroupId: groupId,
          uid: _linkService.currentUid,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
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
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          const Text(
            'Scannez le QR transmis par l’administrateur ou saisissez son code à 6 chiffres.',
            textAlign: TextAlign.center,
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
          MasliveButton(
            label: 'Se rattacher avec le code',
            icon: Icons.link,
            onPressed: _isLoading ? null : _linkToAdmin,
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
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
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
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _isTracking
                      ? 'Votre position est partagée avec le groupe. Arrêtez la session dès que le suivi n’est plus nécessaire.'
                      : 'Un consentement clair vous sera demandé avant chaque démarrage.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                MasliveButton(
                  label: _isTracking ? 'Arrêter le tracking' : 'Démarrer le tracking',
                  icon: _isTracking ? Icons.stop : Icons.play_arrow,
                  backgroundColor: _isTracking ? Colors.red : Colors.green,
                  onPressed: _toggleTracking,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.battery_saver_outlined),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Cadence et batterie',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      SizedBox(height: 6),
                      Text(
                        '15 s en mouvement, 45 s à faible vitesse et 60 s à l’arrêt. L’historique est enregistré environ toutes les 2 minutes ou après un déplacement significatif.',
                      ),
                    ],
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
          subtitle: const Text('Retrouver les sessions terminées'),
          trailing: const Icon(Icons.chevron_right),
          onTap: _openHistory,
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
