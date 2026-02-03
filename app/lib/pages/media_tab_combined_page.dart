import 'package:flutter/material.dart';

import 'media_gallery_maslive_instagram_page.dart';
import 'media_shop_page.dart';

/// Page combinée "Médias" :
/// - Onglet 1 : Galerie Instagram MAS'LIVE (lecture seule)
/// - Onglet 2 : Boutique media (MediaShopWrapper + panier)
class MediaTabCombinedPage extends StatelessWidget {
  const MediaTabCombinedPage({super.key, required this.groupId});

  final String groupId;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'Médias',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Galerie'),
              Tab(text: 'Boutique'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            MediaGalleryMasliveInstagramPage(),
            MediaShopPage(),
          ],
        ),
      ),
    );
  }
}
