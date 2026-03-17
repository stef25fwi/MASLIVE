import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/enums/media_asset_type.dart';
import '../../data/models/media_gallery_model.dart';
import '../../data/models/media_pack_model.dart';
import '../../data/models/media_photo_model.dart';
import '../../presentation/controllers/media_marketplace_catalog_controller.dart';
import '../../../../models/cart_item_model.dart' as unified_cart;
import '../../../../providers/cart_provider.dart';
import '../../../../ui/theme/maslive_theme.dart';
import '../../../../ui/snack/top_snack_bar.dart';
import '../widgets/media_marketplace_context_chips.dart';
import '../widgets/media_marketplace_message_card.dart';

class MediaMarketplaceHomePage extends StatelessWidget {
  const MediaMarketplaceHomePage({
    super.key,
    this.countryId,
    this.countryName,
    this.eventId,
    this.eventName,
    this.circuitId,
    this.circuitName,
    this.photographerId,
    this.showContextHeader = true,
    this.embedded = false,
    this.showBranding = true,
    this.onOpenFilters,
  });

  final String? countryId;
  final String? countryName;
  final String? eventId;
  final String? eventName;
  final String? circuitId;
  final String? circuitName;
  final String? photographerId;
  final bool showContextHeader;
  final bool embedded;
  final bool showBranding;
  final VoidCallback? onOpenFilters;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<MediaMarketplaceCatalogController>(
      create: (_) {
        final controller = MediaMarketplaceCatalogController();
        Future<void>.microtask(() async {
          if (eventId != null && eventId!.isNotEmpty) {
            await controller.loadEventGalleries(
              eventId!,
              countryId: countryId,
              circuitId: circuitId,
            );
          } else if (photographerId != null && photographerId!.isNotEmpty) {
            await controller.loadPhotographerGalleries(photographerId!);
          }
        });
        return controller;
      },
      child: _MediaMarketplaceHomeView(
        embedded: embedded,
        countryName: countryName,
        eventName: eventName,
        circuitName: circuitName,
        showContextHeader: showContextHeader,
        showBranding: showBranding,
        onOpenFilters: onOpenFilters,
      ),
    );
  }
}

class _MediaMarketplaceHomeView extends StatelessWidget {
  const _MediaMarketplaceHomeView({
    required this.embedded,
    required this.countryName,
    required this.eventName,
    required this.circuitName,
    required this.showContextHeader,
    required this.showBranding,
    required this.onOpenFilters,
  });

  final bool embedded;
  final String? countryName;
  final String? eventName;
  final String? circuitName;
  final bool showContextHeader;
  final bool showBranding;
  final VoidCallback? onOpenFilters;

  @override
  Widget build(BuildContext context) {
    final catalog = context.watch<MediaMarketplaceCatalogController>();
    final cart = context.watch<CartProvider>();

    // UX: si on a des galeries mais aucune sélection, on auto-sélectionne la 1ère.
    // Ça permet d'afficher immédiatement du contenu dans le layout Premium.
    if (!catalog.loading &&
        catalog.error == null &&
        catalog.selectedGalleryId == null &&
        catalog.galleries.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final controller = context.read<MediaMarketplaceCatalogController>();
        if (controller.selectedGalleryId == null && controller.galleries.isNotEmpty) {
          controller.selectGallery(controller.galleries.first.galleryId);
        }
      });
    }

    final MediaGalleryModel? selectedGallery = catalog.selectedGalleryId == null
        ? null
        : catalog.galleries
            .cast<MediaGalleryModel?>()
            .firstWhere(
              (g) => g?.galleryId == catalog.selectedGalleryId,
              orElse: () => null,
            );

    final String? heroImageUrl = selectedGallery?.coverUrl?.trim().isNotEmpty == true
        ? selectedGallery!.coverUrl!.trim()
        : (catalog.photos.isNotEmpty
            ? catalog.photos.first.thumbnailPath
            : (catalog.packs.isNotEmpty ? catalog.packs.first.coverUrl : null));

    final body = DecoratedBox(
      decoration: const BoxDecoration(
        color: MasliveTheme.surfaceAlt,
      ),
      child: Column(
        children: <Widget>[
          if (catalog.loading) const LinearProgressIndicator(minHeight: 2),
          if (catalog.error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 16, 8, 0),
              child: MediaMarketplaceMessageCard.error(catalog.error!),
            ),
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(8, 18, 8, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const SizedBox(height: 4),
                  if (showBranding) ...<Widget>[
                    Center(
                      child: Text(
                        'MASLIVE',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.8,
                          color: MasliveTheme.textPrimary,
                          height: 1,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        'LA BOUTIQUE PHOTO',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 2.2,
                          color: MasliveTheme.textSecondary,
                          height: 1,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                  _CatalogFilterTrigger(
                    countryName: countryName,
                    eventName: eventName,
                    circuitName: circuitName,
                    onTap: onOpenFilters,
                  ),
                  const SizedBox(height: 14),
                  if (showContextHeader && catalog.currentEventId != null) ...<Widget>[
                    MediaMarketplaceContextChips(
                      eventId: catalog.currentEventId!,
                      circuitName: circuitName,
                    ),
                    const SizedBox(height: 14),
                  ],
                  if (!(catalog.galleries.isEmpty && !catalog.loading))
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: catalog.galleries
                            .map(
                              (MediaGalleryModel gallery) => Padding(
                                padding: const EdgeInsets.only(right: 12),
                                child: _CategoryChip(
                                  label: gallery.title.isEmpty
                                      ? 'GALERIE'
                                      : gallery.title.toUpperCase(),
                                  selected: catalog.selectedGalleryId == gallery.galleryId,
                                  onTap: () => catalog.selectGallery(gallery.galleryId),
                                ),
                              ),
                            )
                            .toList(growable: false),
                      ),
                    ),
                  const SizedBox(height: 20),
                  _HeroGalleryCard(
                    title: selectedGallery?.title.trim().isNotEmpty == true
                        ? selectedGallery!.title.trim().toUpperCase()
                        : (eventName?.trim().isNotEmpty == true
                            ? eventName!.trim().toUpperCase()
                            : 'GALERIE'),
                    imageUrl: heroImageUrl,
                    onTap: catalog.selectedGalleryId == null
                        ? null
                        : () {},
                  ),
                  const SizedBox(height: 22),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: const <Widget>[
                      Text(
                        'PHOTOS POPULAIRES',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.2,
                          color: MasliveTheme.textPrimary,
                          height: 1.1,
                        ),
                      ),
                      Spacer(),
                      Text(
                        'Voir tout',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                          color: MasliveTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (catalog.selectedGalleryId == null)
                    MediaMarketplaceMessageCard.empty(
                      title: 'Sélectionne une galerie',
                      message: 'Choisis une catégorie ci-dessus pour afficher les médias disponibles.',
                      icon: Icons.photo_library_outlined,
                    )
                  else
                    _PhotosMosaic(
                      photos: catalog.photos,
                      packs: catalog.packs,
                      cart: cart,
                      onAddPhoto: (photo) => _addMediaPhoto(context, photo),
                      onAddPack: (pack) => _addMediaPack(context, pack),
                    ),
                  const SizedBox(height: 18),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    if (embedded) return body;

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
      body: body,
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

class _CatalogFilterTrigger extends StatelessWidget {
  const _CatalogFilterTrigger({
    required this.countryName,
    required this.eventName,
    required this.circuitName,
    required this.onTap,
  });

  final String? countryName;
  final String? eventName;
  final String? circuitName;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final summary = <String>[
      if (countryName?.trim().isNotEmpty == true) countryName!.trim(),
      if (eventName?.trim().isNotEmpty == true) eventName!.trim(),
      if (circuitName?.trim().isNotEmpty == true) circuitName!.trim(),
    ].join(' / ');

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: MasliveTheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: MasliveTheme.divider),
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      'CATALOGUE DES MEDIAS',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: MasliveTheme.textPrimary,
                        letterSpacing: 0.2,
                        height: 1,
                      ),
                    ),
                    if (summary.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 6),
                      Text(
                        summary,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          color: MasliveTheme.textSecondary,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: MasliveTheme.textPrimary,
                size: 26,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: selected
              ? Border.all(
                  color: MasliveTheme.textPrimary.withValues(alpha: 0.22),
                  width: 1,
                )
              : null,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: MasliveTheme.textPrimary,
            letterSpacing: 0.1,
            height: 1,
          ),
        ),
      ),
    );
  }
}

class _HeroGalleryCard extends StatelessWidget {
  const _HeroGalleryCard({
    required this.title,
    required this.imageUrl,
    required this.onTap,
  });

  final String title;
  final String? imageUrl;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(28),
      child: Container(
        height: 240,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          color: MasliveTheme.surface,
          boxShadow: MasliveTheme.cardShadow,
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            if (imageUrl?.trim().isNotEmpty == true)
              Image.network(
                imageUrl!.trim(),
                fit: BoxFit.cover,
              )
            else
              Image.asset(
                'assets/images/maslivesmall.png',
                fit: BoxFit.cover,
              ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: <Color>[
                    MasliveTheme.textPrimary.withValues(alpha: 0.50),
                    MasliveTheme.textPrimary.withValues(alpha: 0.14),
                    MasliveTheme.textPrimary.withValues(alpha: 0.10),
                  ],
                  stops: const <double>[0.0, 0.38, 1.0],
                ),
              ),
            ),
            Positioned(
              left: 18,
              bottom: 22,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 27,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: -0.6,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'DÉCOUVRIR  >',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 0.2,
                      height: 1,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotosMosaic extends StatelessWidget {
  const _PhotosMosaic({
    required this.photos,
    required this.packs,
    required this.cart,
    required this.onAddPhoto,
    required this.onAddPack,
  });

  final List<MediaPhotoModel> photos;
  final List<MediaPackModel> packs;
  final CartProvider cart;
  final ValueChanged<MediaPhotoModel> onAddPhoto;
  final ValueChanged<MediaPackModel> onAddPack;

  @override
  Widget build(BuildContext context) {
    final List<_MosaicItem> items = <_MosaicItem>[];

    for (final photo in photos) {
      if (items.length >= 7) break;
      items.add(
        _MosaicItem(
          imageUrl: photo.thumbnailPath,
          showHeart: true,
          filledHeart: cart.mediaItems.any((i) => i.productId == photo.photoId),
          heartSmall: items.length == 6,
          onTap: () => onAddPhoto(photo),
        ),
      );
    }

    for (final pack in packs) {
      if (items.length >= 7) break;
      final String? url = pack.coverUrl?.trim().isNotEmpty == true ? pack.coverUrl!.trim() : null;
      items.add(
        _MosaicItem(
          imageUrl: url,
          showHeart: false,
          filledHeart: false,
          heartSmall: items.length == 6,
          onTap: () => onAddPack(pack),
        ),
      );
    }

    if (items.isEmpty) {
      return MediaMarketplaceMessageCard.empty(
        title: 'Aucun média',
        message: 'Cette galerie ne contient pas encore de photos ou packs vendables.',
        icon: Icons.collections_outlined,
      );
    }

    while (items.length < 7) {
      items.add(const _MosaicItem.placeholder());
    }

    return SizedBox(
      height: 434,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Column(
              children: <Widget>[
                Expanded(
                  flex: 11,
                  child: _PhotoCard(
                    item: items[0],
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  flex: 9,
                  child: _PhotoCard(
                    item: items[1],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 1,
            child: Column(
              children: <Widget>[
                Expanded(
                  flex: 9,
                  child: _PhotoCard(
                    item: items[2],
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  flex: 8,
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: _PhotoCard(
                          item: items[3],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          children: <Widget>[
                            Expanded(
                              child: _PhotoCard(
                                item: items[4],
                              ),
                            ),
                            const SizedBox(height: 10),
                            Expanded(
                              child: _PhotoCard(
                                item: items[5],
                              ),
                            ),
                            const SizedBox(height: 10),
                            Expanded(
                              child: _PhotoCard(
                                item: items[6],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MosaicItem {
  const _MosaicItem({
    required this.imageUrl,
    required this.showHeart,
    required this.filledHeart,
    required this.heartSmall,
    required this.onTap,
  });

  const _MosaicItem.placeholder()
      : imageUrl = null,
        showHeart = false,
        filledHeart = false,
        heartSmall = false,
        onTap = null;

  final String? imageUrl;
  final bool showHeart;
  final bool filledHeart;
  final bool heartSmall;
  final VoidCallback? onTap;
}

class _PhotoCard extends StatelessWidget {
  const _PhotoCard({required this.item});

  final _MosaicItem item;

  @override
  Widget build(BuildContext context) {
    final double heartBoxSize = item.heartSmall ? 22 : 34;
    final double heartIconSize = item.heartSmall ? 14 : 20;

    return InkWell(
      onTap: item.onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          color: MasliveTheme.surface,
          boxShadow: MasliveTheme.cardShadow,
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            if (item.imageUrl?.trim().isNotEmpty == true)
              Image.network(
                item.imageUrl!.trim(),
                fit: BoxFit.cover,
              )
            else
              Container(
                color: MasliveTheme.surface,
                alignment: Alignment.center,
                child: const Icon(
                  Icons.image_outlined,
                  size: 34,
                  color: MasliveTheme.textSecondary,
                ),
              ),
            if (item.showHeart)
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  width: heartBoxSize,
                  height: heartBoxSize,
                  decoration: BoxDecoration(
                    color: item.filledHeart ? MasliveTheme.pink : Colors.transparent,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    item.filledHeart ? Icons.favorite : Icons.favorite_border,
                    size: heartIconSize,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
