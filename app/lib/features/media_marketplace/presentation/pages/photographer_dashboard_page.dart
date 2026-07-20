import 'package:flutter/material.dart';

import 'photographer_complete_flow_page.dart';

/// Dashboard photographe rétrocompatible.
///
/// Le tableau de bord avancé centralise désormais les ventes mensuelles,
/// reversements, quotas, alertes d’expiration, circuits sans galerie,
/// renouvellement et accès direct à la boutique publique.
class PhotographerDashboardPage extends StatelessWidget {
  const PhotographerDashboardPage({
    super.key,
    this.ownerUid,
    this.eventId,
    this.eventName,
    this.circuitId,
    this.circuitName,
    this.showContextHeader = true,
    this.embedded = false,
  });

  final String? ownerUid;
  final String? eventId;
  final String? eventName;
  final String? circuitId;
  final String? circuitName;
  final bool showContextHeader;
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    return PhotographerCompleteFlowPage(
      initialSection: 0,
      eventId: eventId,
      eventName: eventName,
      circuitId: circuitId,
      circuitName: circuitName,
    );
  }
}
