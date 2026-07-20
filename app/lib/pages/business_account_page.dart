import 'package:flutter/material.dart';

import 'business_request_page.dart';

/// Route de compatibilité pour les anciens liens `/business`.
///
/// Le profil « Compte Pro » générique est retiré : les droits et les paiements
/// sont désormais gérés dans les espaces métier Artisan d’art, Créateur digital
/// et Admin Groupe.
class BusinessAccountPage extends StatelessWidget {
  const BusinessAccountPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const BusinessRequestPage();
  }
}
