import 'package:flutter/material.dart';

import '../features/media_marketplace/presentation/pages/media_marketplace_entry_page.dart';

@Deprecated('Use MediaMarketplaceEntryPage instead.')
class MediaShopPage extends StatelessWidget {
  const MediaShopPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const MediaMarketplaceEntryPage();
  }
}
