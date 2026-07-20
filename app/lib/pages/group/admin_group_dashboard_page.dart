import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../models/group_admin.dart';
import '../../security/profile_capability_policy.dart';
import '../../services/group/group_link_qr.dart';
import '../../services/group/group_link_service.dart';
import '../../services/group/group_tracking_service.dart';
import '../../ui/snack/top_snack_bar.dart';
import '../../ui/widgets/maslive_empty_state.dart';
import '../../widgets/capability_guard.dart';
import 'group_export_page.dart';
import 'group_map_live_page.dart';
import 'group_track_history_page.dart';

class AdminGroupDashboardPage extends StatefulWidget {
  const AdminGroupDashboardPage({super.key});

  @override
  State<AdminGroupDashboardPage> createState() =>
      _AdminGroupDashboardPageState();
}

class _AdminGroupDashboardPageState extends State<AdminGroupDashboardPage> {
  final GroupLinkService _linkService = GroupLinkService.instance;
  final GroupTrackingService _trackingService = GroupTrackingService.instance;

  late Future<ProfileCapabilities?> _capabilitiesFuture;
  GroupAdmin? _admin;
  bool _loading = true;
  bool _tracking = false;

  @override
  void initState() {
    super.initState();
    _capabilitiesFuture = ProfileCapabilityPolicy.instance.resolveCurrent();
    _reload();
  }

  Future<void> _reload() async {
    if (mounted) setState(() => _loading = true);
    try {
      final uid = _linkService.currentUid;
      final admin = uid == null ? null : await _linkService.getAdminProfile(uid);
      if (!mounted) return;
      setState(() {
        _admin = admin;
        _tracking = admin != null &&
            _trackingService.isTrackingFor(
              adminGroupId: admin.adminGroupId,
              role: 'admin',
            );
        _capabilitiesFuture = ProfileCapabilityPolicy.instance.resolveCurrent();
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _requestActivation() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Demander Admin Groupe'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Nom du groupe ou de l’organisation',
          ),
          autofocus: true,
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('Envoyer la demande'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;

    setState(() => _loading = true);
    try {
      await _linkService.requestAdminProfile(displayName: name);
      if (!mounted) return;
      TopSnackBar.show(
        context,
        const SnackBar(
          content: Text('Demande envoyée à MASLIVE.'),
          backgroundColor: Colors.green,
        ),
      );
      await _reload();
    } catch (error) {
      if (mounted) {
        TopSnackBar.show(
          context,
          SnackBar(content: Text('Demande impossible : $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleTracking() async {
    final admin = _admin;
    if (admin == null) return;
    setState(() => _loading = true);
    try {
      if (_tracking) {
        await _trackingService.stopTracking();
      } else {
        await _trackingService.startTracking(
          adminGroupId: admin.adminGroupId,
          role: 'admin',
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

  Future<void> _toggleVisibility() async {
    final admin = _admin;
    if (admin == null) return;
    setState(() => _loading = true);
    try {
      await _linkService.updateAdminVisibility(
        adminUid: admin.uid,
        isVisible: !admin.isVisible,
      );
      if (mounted) {
        setState(() => _admin = admin.copyWith(isVisible: !admin.isVisible));
      }
    } catch (error) {
      if (mounted) {
        TopSnackBar.show(context, SnackBar(content: Text('Erreur : $error')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _copyCode() {
    final code = _admin?.adminGroupId;
    if (code == null) return;
    Clipboard.setData(ClipboardData(text: code));
    TopSnackBar.show(
      context,
      const SnackBar(content: Text('Code groupe copié')),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return FutureBuilder<ProfileCapabilities?>(
      future: _capabilitiesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final profile = snapshot.data;
        if (profile == null || !profile.isActive) {
          return const _GroupAccessState(
            icon: Icons.lock_outline,
            title: 'Connexion requise',
            message: 'Connectez-vous pour demander ou gérer un groupe.',
          );
        }

        if (profile.can(Capability.manageGroupTracking) && _admin != null) {
          return CapabilityGuard(
            capability: Capability.manageGroupTracking,
            fullPage: true,
            child: _buildApprovedDashboard(_admin!),
          );
        }

        if (profile.hasPendingGroupAdminRequest) {
          return const _GroupAccessState(
            icon: Icons.pending_actions_rounded,
            title: 'Demande en attente',
            message:
                'MASLIVE doit valider votre demande avant de créer le code groupe et d’activer les commandes de gestion.',
          );
        }

        if (profile.hasRejectedGroupAdminRequest) {
          return _GroupAccessState(
            icon: Icons.cancel_outlined,
            title: 'Demande refusée',
            message:
                'Votre précédente demande n’a pas été validée. Vous pouvez corriger les informations puis envoyer une nouvelle demande.',
            actionLabel: 'Refaire une demande',
            onAction: _requestActivation,
          );
        }

        return _GroupAccessState(
          icon: Icons.group_add_outlined,
          title: 'Devenir Admin Groupe',
          message:
              'La création d’un groupe nécessite une validation MASLIVE. Aucun profil administrateur ni code de rattachement ne sera créé avant approbation.',
          actionLabel: 'Demander l’activation',
          onAction: _requestActivation,
        );
      },
    );
  }

  Widget _buildApprovedDashboard(GroupAdmin admin) {
    final qrData = buildGroupQrPayload(
      admin.adminGroupId,
      groupName: admin.displayName,
    );
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard Admin Groupe'),
        actions: <Widget>[
          IconButton(onPressed: _reload, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: <Widget>[
                  Text(
                    admin.displayName,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 12),
                  QrImageView(data: qrData, size: 180),
                  const SizedBox(height: 8),
                  Text(
                    admin.adminGroupId,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 5,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _copyCode,
                    icon: const Icon(Icons.copy),
                    label: const Text('Copier le code'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            value: admin.isVisible,
            onChanged: (_) => _toggleVisibility(),
            title: const Text('Visibilité publique du groupe'),
            subtitle: Text(admin.isVisible ? 'Groupe visible' : 'Groupe masqué'),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _toggleTracking,
            icon: Icon(_tracking ? Icons.stop : Icons.play_arrow),
            label: Text(_tracking ? 'Arrêter le tracking' : 'Démarrer le tracking'),
          ),
          const SizedBox(height: 12),
          _ActionTile(
            icon: Icons.map_outlined,
            title: 'Carte live du groupe',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => GroupMapLivePage(
                  adminGroupId: admin.adminGroupId,
                ),
              ),
            ),
          ),
          _ActionTile(
            icon: Icons.history,
            title: 'Historique du groupe',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => GroupTrackHistoryPage(
                  adminGroupId: admin.adminGroupId,
                ),
              ),
            ),
          ),
          _ActionTile(
            icon: Icons.file_download_outlined,
            title: 'Exports du groupe',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => GroupExportPage(
                  adminGroupId: admin.adminGroupId,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupAccessState extends StatelessWidget {
  const _GroupAccessState({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin Groupe')),
      body: Center(
        child: MasliveEmptyState(
          icon: icon,
          title: title,
          message: message,
          actionLabel: actionLabel,
          onAction: onAction,
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
