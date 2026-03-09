import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/enums/media_asset_type.dart';
import '../../data/models/cart_item_model.dart';
import '../../data/models/media_gallery_model.dart';
import '../../data/models/media_pack_model.dart';
import '../../data/models/media_photo_model.dart';
import '../../presentation/controllers/media_cart_controller.dart';
import '../../presentation/controllers/media_marketplace_catalog_controller.dart';
import '../widgets/media_gallery_card.dart';
import '../widgets/media_marketplace_context_chips.dart';
import '../widgets/media_marketplace_message_card.dart';
import '../widgets/media_marketplace_section_header.dart';
import '../widgets/media_pack_card.dart';
import '../widgets/media_photo_card.dart';

class MediaMarketplaceHomePage extends StatelessWidget {
  const MediaMarketplaceHomePage({
    super.key,
    this.eventId,
    this.eventName,
    this.circuitName,
    this.photographerId,
    this.showContextHeader = true,
    this.embedded = false,
  });

  final String? eventId;
  final String? eventName;
  final String? circuitName;
  final String? photographerId;
  final bool showContextHeader;
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: <ChangeNotifierProvider<dynamic>>[
        ChangeNotifierProvider<MediaMarketplaceCatalogController>(
          create: (_) {
            final controller = MediaMarketplaceCatalogController();
            Future<void>.microtask(() async {
              if (eventId != null && eventId!.isNotEmpty) {
                await controller.loadEventGalleries(eventId!);
              } else if (photographerId != null && photographerId!.isNotEmpty) {
                await controller.loadPhotographerGalleries(photographerId!);
              }
            });
            return controller;
          },
        ),
        ChangeNotifierProvider<MediaCartController>(
          create: (_) {
            final controller = MediaCartController();
            Future<void>.microtask(controller.loadCurrentUserCart);
            return controller;
          },
        ),
      ],
      child: _MediaMarketplaceHomeView(
        embedded: embedded,
        eventName: eventName,
        circuitName: circuitName,
        showContextHeader: showContextHeader,
      ),
    );
  }
}

class _MediaMarketplaceHomeView extends StatelessWidget {
  const _MediaMarketplaceHomeView({
    required this.embedded,
    required this.eventName,
    required this.circuitName,
    required this.showContextHeader,
  });

  final bool embedded;
  final String? eventName;
  final String? circuitName;
  final bool showContextHeader;

  @override
  Widget build(BuildContext context) {
    final catalog = context.watch<MediaMarketplaceCatalogController>();
    final cart = context.watch<MediaCartController>();

    final content = Column(
        children: <Widget>[
          if (catalog.loading)
            const LinearProgressIndicator(minHeight: 2),
          if (catalog.error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: MediaMarketplaceMessageCard.error(catalog.error!),
            ),
          Expanded(
            child: Row(
              children: <Widget>[
                SizedBox(
                  width: 320,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      border: Border(
                        right: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: <Widget>[
                        const MediaMarketplaceSectionHeader(
                          title: 'Galeries',
                          subtitle: 'Choisis un catalogue puis un contenu.',
                        ),
                        const SizedBox(height: 12),
                        if (catalog.galleries.isEmpty && !catalog.loading)
                          MediaMarketplaceMessageCard.empty(
                            title: 'Aucune galerie',
                            message: 'Aucune galerie disponible pour cette source.',
                            icon: Icons.photo_library_outlined,
                          ),
                        for (final MediaGalleryModel gallery in catalog.galleries)
                          MediaGalleryCard(
                            gallery: gallery,
                            selected: catalog.selectedGalleryId == gallery.galleryId,
                            onTap: () => catalog.selectGallery(gallery.galleryId),
                          ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: <Widget>[
                      if (showContextHeader && catalog.currentEventId != null) ...<Widget>[
                        MediaMarketplaceSectionHeader(
                          title: eventName?.trim().isNotEmpty == true
                              ? eventName!.trim()
                              : 'Catalogue événement',
                          subtitle: 'Catalogue ciblé depuis la carte active.',
                        ),
                        const SizedBox(height: 12),
                        MediaMarketplaceContextChips(
                          eventId: catalog.currentEventId!,
                          circuitName: circuitName,
                        ),
                        const SizedBox(height: 16),
                      ],
                      if (catalog.selectedGalleryId == null &&
                          catalog.galleries.isEmpty &&
                          !catalog.loading) ...<Widget>[
                        MediaMarketplaceMessageCard.empty(
                          title: 'Catalogue des médias',
                          message:
                              'Ouvre cette page avec un eventId ou un photographerId pour charger un catalogue ciblé.',
                          icon: Icons.filter_center_focus,
                        ),
                        const SizedBox(height: 16),
                      ],
                      MediaMarketplaceSectionHeader(
                        title: catalog.selectedGalleryId == null
                            ? 'Sélectionne une galerie'
                            : 'Contenu de la galerie',
                        subtitle: catalog.selectedGalleryId == null
                            ? 'La colonne de droite affiche les photos et packs de la galerie choisie.'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      if (catalog.selectedGalleryId != null) ...<Widget>[
                        const MediaMarketplaceSectionHeader(
                          title: 'Photos',
                          subtitle: 'Achat à l\'unité.',
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: catalog.photos
                              .map(
                                (MediaPhotoModel photo) => MediaPhotoCard(
                                  photo: photo,
                                  onPrimaryAction: () => cart.addItem(
                                    CartItemModel(
                                      assetId: photo.photoId,
                                      assetType: MediaAssetType.photo,
                                      photographerId: photo.photographerId,
                                      galleryId: photo.galleryId,
                                      eventId: photo.eventId,
                                      title: photo.downloadFileName,
                                      thumbnailUrl: photo.thumbnailPath,
                                      unitPrice: photo.unitPrice,
                                      currency: photo.currency,
                                    ),
                                  ),
                                ),
                              )
                              .toList(growable: false),
                        ),
                        const SizedBox(height: 24),
                        const MediaMarketplaceSectionHeader(
                          title: 'Packs',
                          subtitle: 'Sélection de photos groupées.',
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: catalog.packs
                              .map(
                                (MediaPackModel pack) => MediaPackCard(
                                  pack: pack,
                                  onPrimaryAction: () => cart.addItem(
                                    CartItemModel(
                                      assetId: pack.packId,
                                      assetType: MediaAssetType.pack,
                                      photographerId: pack.photographerId,
                                      galleryId: pack.galleryId,
                                      eventId: pack.eventId,
                                      title: pack.title,
                                      thumbnailUrl: pack.coverUrl,
                                      unitPrice: pack.price,
                                      currency: pack.currency,
                                      metadata: <String, dynamic>{
                                        'photoIds': pack.photoIds,
                                      },
                                    ),
                                  ),
                                ),
                              )
                              .toList(growable: false),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
    );

    if (embedded) {
      return content;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Marché des médias'),
        actions: <Widget>[
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Text('Panier ${cart.itemCount}'),
            ),
          ),
        ],
      ),
      body: content,
    );
  }
}
