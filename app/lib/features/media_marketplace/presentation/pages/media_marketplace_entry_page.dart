import 'package:flutter/material.dart';

import '../../../shop/pages/media_photo_shop_page.dart';

class MediaMarketplaceEntryPage extends StatelessWidget {
  const MediaMarketplaceEntryPage({
    super.key,
    this.countryId,
    this.countryName,
    this.eventId,
    this.eventName,
    this.circuitId,
    this.circuitName,
    this.photographerId,
    this.ownerUid,
    this.initialTabIndex = 0,
    this.embedded = false,
  });

  final String? countryId;
  final String? countryName;
  final String? eventId;
  final String? eventName;
  final String? circuitId;
  final String? circuitName;
  final String? photographerId;
  final String? ownerUid;
  final int initialTabIndex;
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    return MediaPhotoShopPage(
      countryId: countryId,
      countryName: countryName,
      eventId: eventId,
      eventName: eventName,
      circuitId: circuitId,
      circuitName: circuitName,
      photographerId: photographerId,
      ownerUid: ownerUid,
      initialTabIndex: initialTabIndex,
      embedded: embedded,
    );
  }
}

