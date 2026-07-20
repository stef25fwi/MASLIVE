import 'package:flutter/material.dart';

import 'photographer_complete_flow_page.dart';

/// Point d’entrée rétrocompatible du centre photographe.
///
/// Les anciens index restent supportés :
/// 0 Profil, 1 Photos, 2 Ventes, 3 Abonnement.
class PhotographerBusinessCenterPage extends StatelessWidget {
  const PhotographerBusinessCenterPage({
    super.key,
    this.initialTab = 0,
  });

  final int initialTab;

  int get _completeFlowSection {
    switch (initialTab) {
      case 0:
        return 1;
      case 1:
        return 4;
      case 2:
        return 5;
      case 3:
        return 7;
      default:
        return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return PhotographerCompleteFlowPage(
      initialSection: _completeFlowSection,
    );
  }
}
