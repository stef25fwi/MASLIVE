#!/usr/bin/env python3
"""Unifie le parcours Admin Groupe autour du consentement et des étapes."""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TARGET = ROOT / "app/lib/pages/group/admin_group_dashboard_page.dart"


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if new in text:
        print(f"[ok] {label} déjà appliqué")
        return text
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"[erreur] {label}: attendu 1 marqueur, trouvé {count}")
    print(f"[ok] {label}")
    return text.replace(old, new, 1)


def replace_between(text: str, start: str, end: str, new: str, label: str) -> str:
    start_index = text.find(start)
    end_index = text.find(end, start_index)
    if start_index < 0 or end_index < 0:
        raise SystemExit(f"[erreur] structure introuvable: {label}")
    print(f"[ok] {label}")
    return text[:start_index] + new + text[end_index:]


def main() -> None:
    text = TARGET.read_text(encoding="utf-8")

    text = replace_once(
        text,
        "import '../../services/group/group_tracking_service.dart';\n",
        "import '../../services/group/group_tracking_consent_service.dart';\n"
        "import '../../services/group/group_tracking_service.dart';\n",
        "import consentement groupe",
    )

    text = replace_once(
        text,
        "  final _trackingService = GroupTrackingService.instance;\n",
        "  final _trackingService = GroupTrackingService.instance;\n"
        "  final _consentService = GroupTrackingConsentService.instance;\n",
        "service consentement admin",
    )

    flow_methods = r'''  Future<bool> _requestTrackingConsent() async {
    final admin = _admin;
    if (admin == null) return false;

    var accepted = false;
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Autoriser ma position pour le groupe'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Votre position administrateur sera partagée avec le groupe ${admin.displayName} pendant cette session.',
                ),
                const SizedBox(height: 12),
                const Text(
                  'Cadence adaptative : environ 15 s en mouvement, 45 s à faible vitesse et 60 s à l’arrêt. L’historique est enregistré moins souvent afin de limiter la batterie et les données.',
                ),
                const SizedBox(height: 12),
                const Text(
                  'Les trackers rattachés au groupe peuvent apparaître sur la carte live selon leur propre consentement. Vous pouvez arrêter votre partage à tout moment.',
                ),
                const SizedBox(height: 12),
                CheckboxListTile(
                  value: accepted,
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: const Text(
                    'J’accepte de partager ma position pour cette session.',
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
        ),
      ),
    );
    return result == true;
  }

  Future<void> _toggleTracking() async {
    final admin = _admin;
    if (admin == null) return;

    if (_isTracking) {
      await _stopTracking();
      return;
    }

    final accepted = await _requestTrackingConsent();
    if (!accepted || !mounted) return;

    setState(() => _isLoading = true);
    try {
      await _consentService.recordAcceptance(
        adminGroupId: admin.adminGroupId,
        role: 'admin',
      );
      await _trackingService.startTracking(
        adminGroupId: admin.adminGroupId,
        role: 'admin',
      );
      if (!mounted) return;
      setState(() => _isTracking = true);
      TopSnackBar.show(
        context,
        const SnackBar(
          content: Text('Session live démarrée pour le groupe'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (error) {
      if (mounted) {
        TopSnackBar.show(context, SnackBar(content: Text('Erreur: $error')));
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
    } catch (error) {
      if (mounted) {
        TopSnackBar.show(context, SnackBar(content: Text('Erreur: $error')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }

    if (!stopped || !mounted) return;
    final openHistory = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.check_circle, color: Colors.green, size: 42),
        title: const Text('Session du groupe arrêtée'),
        content: const Text(
          'Votre position administrateur n’est plus partagée. La session terminée est disponible dans l’historique du groupe.',
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
    if (openHistory == true && mounted) {
      await _openHistory();
    }
  }

  Future<void> _openHistory() async {
    final admin = _admin;
    if (admin == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GroupTrackHistoryPage(
          adminGroupId: admin.adminGroupId,
        ),
      ),
    );
  }

'''
    text = replace_between(
        text,
        "  Future<void> _toggleTracking() async {",
        "  Future<void> _toggleVisibility() async {",
        flow_methods,
        "cycle consentement/start/stop admin",
    )

    text = replace_once(
        text,
        "            _buildAdminCard(),\n            const SizedBox(height: 16),\n            _buildTrackingCard(),",
        "            _buildAdminCard(),\n            const SizedBox(height: 16),\n"
        "            _buildJourneyCard(),\n            const SizedBox(height: 16),\n"
        "            _buildTrackingCard(),",
        "carte parcours visible",
    )

    journey_widgets = r'''  Widget _buildJourneyCard() {
    return StreamBuilder<List<GroupTracker>>(
      stream: _linkService.streamAdminTrackers(_admin!.adminGroupId),
      builder: (context, trackersSnapshot) {
        final trackers = trackersSnapshot.data ?? const <GroupTracker>[];
        return StreamBuilder<Set<String>>(
          stream: _trackingService.streamActiveMemberUids(
            _admin!.adminGroupId,
          ),
          builder: (context, activeSnapshot) {
            final activeUids = activeSnapshot.data ?? const <String>{};
            final activeCount = trackers
                .where((tracker) => activeUids.contains(tracker.uid))
                .length;
            final hasTrackers = trackers.isNotEmpty;

            return Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Parcours du groupe',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Créer → Inviter → Associer → Consentir → Suivre → Historique',
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildJourneyStep(
                          icon: Icons.check_circle,
                          label: 'Groupe créé',
                          completed: true,
                        ),
                        _buildJourneyStep(
                          icon: Icons.qr_code_2,
                          label: 'Inviter',
                          completed: hasTrackers,
                          active: !hasTrackers,
                        ),
                        _buildJourneyStep(
                          icon: Icons.group,
                          label: '${trackers.length} associé(s)',
                          completed: hasTrackers,
                        ),
                        _buildJourneyStep(
                          icon: Icons.verified_user_outlined,
                          label: 'Consentement',
                          completed: _isTracking,
                          active: hasTrackers && !_isTracking,
                        ),
                        _buildJourneyStep(
                          icon: Icons.gps_fixed,
                          label: _isTracking ? 'Session active' : 'Démarrer',
                          completed: _isTracking,
                          active: hasTrackers && !_isTracking,
                        ),
                        _buildJourneyStep(
                          icon: Icons.history,
                          label: 'Historique',
                          completed: !_isTracking && hasTrackers,
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      hasTrackers
                          ? '$activeCount tracker(s) actif(s) sur ${trackers.length}. Chaque personne garde le contrôle de son partage GPS.'
                          : 'Partagez le code ou le QR pour associer le premier tracker.',
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildJourneyStep({
    required IconData icon,
    required String label,
    required bool completed,
    bool active = false,
  }) {
    final color = completed
        ? Colors.green
        : active
        ? Theme.of(context).colorScheme.primary
        : Colors.grey;
    return Chip(
      avatar: Icon(
        completed ? Icons.check_circle : icon,
        size: 18,
        color: color,
      ),
      label: Text(label),
      side: BorderSide(color: color.withValues(alpha: 0.35)),
      backgroundColor: color.withValues(alpha: 0.08),
    );
  }

'''
    text = replace_once(
        text,
        "  Widget _buildTrackingCard() {",
        journey_widgets + "  Widget _buildTrackingCard() {",
        "widgets étapes du groupe",
    )

    text = replace_once(
        text,
        "                              : 'Démarrez pour commencer',",
        "                              : 'Consentement requis avant chaque démarrage',",
        "message consentement tracking",
    )

    old_history = '''          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  GroupTrackHistoryPage(adminGroupId: _admin!.adminGroupId),
            ),
          ),'''
    text = replace_once(
        text,
        old_history,
        "          onTap: _openHistory,",
        "action historique unifiée",
    )

    TARGET.write_text(text, encoding="utf-8")

    test_path = ROOT / "app/test/pages/group/admin_group_flow_contract_test.dart"
    test_path.parent.mkdir(parents=True, exist_ok=True)
    test_path.write_text(
        r'''import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('le dashboard admin expose le parcours groupe unifié', () {
    final source = File(
      'lib/pages/group/admin_group_dashboard_page.dart',
    ).readAsStringSync();

    expect(source, contains('Parcours du groupe'));
    expect(source, contains('Créer → Inviter → Associer'));
    expect(source, contains('_requestTrackingConsent'));
    expect(source, contains("role: 'admin'"));
    expect(source, contains('recordAcceptance'));
    expect(source, contains('Session du groupe arrêtée'));
    expect(source, contains('Voir l’historique'));
  });
}
''',
        encoding="utf-8",
    )
    print("[ok] contrat Flutter du parcours Admin Groupe ajouté")


if __name__ == "__main__":
    main()
