import 'package:flutter/material.dart';

import '../../../../security/profile_capability_policy.dart';
import '../../../../widgets/capability_guard.dart';
import 'photographer_complete_flow_page.dart';

/// Point d'entrée historique conservé pour les anciens liens.
///
/// La sélection d'espace photographe est désormais gérée par le centre complet
/// et ses rôles collaborateur. Cette page ne maintient plus une seconde politique
/// locale devenue incompatible avec les capacités cumulables.
class PhotographerWorkspaceGatePage extends StatelessWidget {
  const PhotographerWorkspaceGatePage({
    super.key,
    this.initialSection = 0,
    this.eventId,
    this.eventName,
    this.circuitId,
    this.circuitName,
  });

  final int initialSection;
  final String? eventId;
  final String? eventName;
  final String? circuitId;
  final String? circuitName;

  @override
  Widget build(BuildContext context) {
    return CapabilityGuard(
      capability: Capability.manageOwnGallery,
      fullPage: true,
      message:
          'Un profil Créateur digital ou une collaboration photographe active est requis.',
      child: PhotographerCompleteFlowPage(
        initialSection: initialSection,
        eventId: eventId,
        eventName: eventName,
        circuitId: circuitId,
        circuitName: circuitName,
      ),
    );
  }
}
