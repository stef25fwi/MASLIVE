import 'package:flutter/material.dart';

import '../../../../security/profile_capability_policy.dart';
import '../../../../widgets/capability_guard.dart';
import 'bloom_art_item_create_page.dart' as implementation_create;
import 'bloom_art_seller_dashboard_page.dart' as implementation_dashboard;

export 'bloom_art_artist_creator_form_page.dart';
export 'bloom_art_home_page.dart';
export 'bloom_art_item_detail_page.dart';
export 'bloom_art_je_me_lance_form_page.dart';
export 'bloom_art_make_offer_sheet.dart';
export 'bloom_art_offer_detail_page.dart';
export 'bloom_art_profile_choice_sheet.dart';
export 'bloom_art_sell_entry_page.dart';

class BloomArtSellerDashboardPage extends StatelessWidget {
  const BloomArtSellerDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return CapabilityGuard(
      capability: Capability.manageArtGallery,
      fullPage: true,
      message: 'Un profil Artisan d’art est requis pour ouvrir ce dashboard.',
      child: implementation_dashboard.BloomArtSellerDashboardPage(),
    );
  }
}

class BloomArtItemCreatePage extends StatelessWidget {
  const BloomArtItemCreatePage({super.key, this.profileType});

  final String? profileType;

  @override
  Widget build(BuildContext context) {
    return CapabilityGuard(
      capability: Capability.submitArtwork,
      fullPage: true,
      message: 'Votre profil ne peut pas déposer de création Bloom Art.',
      child: implementation_create.BloomArtItemCreatePage(
        profileType: profileType,
      ),
    );
  }
}
