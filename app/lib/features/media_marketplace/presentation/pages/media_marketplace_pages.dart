import 'package:flutter/material.dart';

import '../../../../security/profile_capability_policy.dart';
import '../../../../widgets/capability_guard.dart';
import 'photographer_dashboard_page.dart' as implementation_dashboard;
import 'photographer_gallery_manager_page.dart' as implementation_gallery;
import 'photographer_subscription_page.dart' as implementation_subscription;

export 'admin_moderation_queue_page.dart';
export 'media_downloads_page.dart';
export 'media_marketplace_entry_page.dart';
export 'media_marketplace_home_page.dart';

class PhotographerDashboardPage extends StatelessWidget {
  const PhotographerDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return CapabilityGuard(
      capability: Capability.manageOwnGallery,
      fullPage: true,
      message: 'Un profil Créateur digital validé est requis.',
      child: implementation_dashboard.PhotographerDashboardPage(),
    );
  }
}

class PhotographerGalleryManagerPage extends StatelessWidget {
  const PhotographerGalleryManagerPage({
    super.key,
    this.initialEventId,
    this.initialEventName,
    this.initialCircuitId,
    this.initialCircuitName,
  });

  final String? initialEventId;
  final String? initialEventName;
  final String? initialCircuitId;
  final String? initialCircuitName;

  @override
  Widget build(BuildContext context) {
    return CapabilityGuard(
      capability: Capability.manageOwnGallery,
      fullPage: true,
      message: 'Vous ne pouvez pas gérer les galeries de cet espace.',
      child: implementation_gallery.PhotographerGalleryManagerPage(
        initialEventId: initialEventId,
        initialEventName: initialEventName,
        initialCircuitId: initialCircuitId,
        initialCircuitName: initialCircuitName,
      ),
    );
  }
}

class PhotographerSubscriptionPage extends StatelessWidget {
  const PhotographerSubscriptionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return CapabilityGuard(
      capability: Capability.manageOwnGallery,
      fullPage: true,
      message: 'Un profil Créateur digital est requis pour gérer cette formule.',
      child: const implementation_subscription.PhotographerSubscriptionPage(),
    );
  }
}
