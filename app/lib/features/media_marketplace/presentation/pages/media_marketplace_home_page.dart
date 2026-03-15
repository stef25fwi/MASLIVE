import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/enums/media_asset_type.dart';
import '../../data/models/media_gallery_model.dart';
import '../../data/models/media_pack_model.dart';
import '../../data/models/media_photo_model.dart';
import '../../presentation/controllers/media_marketplace_catalog_controller.dart';
import '../../../../models/cart_item_model.dart' as unified_cart;
import '../../../../providers/cart_provider.dart';
import '../../../../ui/snack/top_snack_bar.dart';
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
    return ChangeNotifierProvider<MediaMarketplaceCatalogController>(
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
    final cart = context.watch<CartProvider>();

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
                                  onPrimaryAction: () => _addMediaPhoto(context, photo),
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
                                  onPrimaryAction: () => _addMediaPack(context, pack),
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
              child: Text('Panier ${cart.mediaItems.length}'),
            ),
          ),
        ],
      ),
      body: content,
    );
  }

  Future<void> _addMediaPhoto(BuildContext context, MediaPhotoModel photo) async {
    await context.read<CartProvider>().addCartItem(
      unified_cart.CartItemModel(
        id: '',
        itemType: unified_cart.CartItemType.media,
        productId: photo.photoId,
        sellerId: photo.photographerId,
        eventId: photo.eventId,
        title: photo.downloadFileName,
        subtitle: photo.galleryId.isEmpty ? null : 'Galerie ${photo.galleryId}',
        imageUrl: photo.thumbnailPath,
        unitPrice: photo.unitPrice,
        quantity: 1,
        currency: photo.currency,
        isDigital: true,
        requiresShipping: false,
        sourceType: 'media_marketplace',
        metadata: <String, dynamic>{
          'assetType': MediaAssetType.photo.firestoreValue,
          'galleryId': photo.galleryId,
        },
      ),
    );
    if (!context.mounted) return;
    TopSnackBar.show(
      context,
      SnackBar(content: Text('${photo.downloadFileName} ajoute au panier')),
    );
  }

  Future<void> _addMediaPack(BuildContext context, MediaPackModel pack) async {
    await context.read<CartProvider>().addCartItem(
      unified_cart.CartItemModel(
        id: '',
        itemType: unified_cart.CartItemType.media,
        productId: pack.packId,
        sellerId: pack.photographerId,
        eventId: pack.eventId,
        title: pack.title,
        subtitle: pack.galleryId.isEmpty ? null : 'Pack galerie ${pack.galleryId}',
        imageUrl: pack.coverUrl ?? '',
        unitPrice: pack.price,
        quantity: 1,
        currency: pack.currency,
        isDigital: true,
        requiresShipping: false,
        sourceType: 'media_marketplace',
        metadata: <String, dynamic>{
          'assetType': MediaAssetType.pack.firestoreValue,
          'galleryId': pack.galleryId,
          'photoIds': pack.photoIds,
          'photoCount': pack.photoIds.length,
        },
      ),
    );
    if (!context.mounted) return;
    TopSnackBar.show(
      context,
      SnackBar(content: Text('${pack.title} ajoute au panier')),
    );
  }
}
