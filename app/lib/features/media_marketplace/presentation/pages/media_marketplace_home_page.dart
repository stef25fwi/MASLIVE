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

    final premiumBody = DecoratedBox(
      decoration: const BoxDecoration(
        gradient: MasliveTheme.backgroundWash,
      ),
      child: Column(
        children: <Widget>[
          if (catalog.loading) const LinearProgressIndicator(minHeight: 2),
          if (catalog.error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: MediaMarketplaceMessageCard.error(catalog.error!),
            ),
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _MarketplacePremiumHeader(
                    cartCount: cart.totalQuantity,
                  ),
                  const SizedBox(height: 18),
                  _MarketplacePremiumHeroBanner(
                    title: eventName?.trim().isNotEmpty == true
                        ? eventName!.trim()
                        : 'MASLIVE',
                    subtitle: circuitName?.trim().isNotEmpty == true
                        ? circuitName!.trim()
                        : null,
                  ),
                  const SizedBox(height: 18),
                  if (showContextHeader && catalog.currentEventId != null) ...<Widget>[
                    MediaMarketplaceContextChips(
                      eventId: catalog.currentEventId!,
                      circuitName: circuitName,
                    ),
                    const SizedBox(height: 18),
                  ],
                  _PremiumTitleRow(
                    title: 'NOUVEAUTÉS',
                    trailing: 'Voir tout',
                    onTrailingTap: catalog.selectedGalleryId == null
                        ? null
                        : () {},
                  ),
                  const SizedBox(height: 14),
                  if (catalog.galleries.isEmpty && !catalog.loading)
                    MediaMarketplaceMessageCard.empty(
                      title: 'Catalogue des médias',
                      message:
                          'Ouvre cette page avec un eventId ou un photographerId pour charger un catalogue ciblé.',
                      icon: Icons.filter_center_focus,
                    )
                  else if (catalog.selectedGalleryId == null)
                    MediaMarketplaceMessageCard.empty(
                      title: 'Sélectionne une galerie',
                      message: 'Choisis une catégorie ci-dessous pour afficher les médias disponibles.',
                      icon: Icons.photo_library_outlined,
                    )
                  else
                    _PremiumProductsGrid(
                      photos: catalog.photos,
                      packs: catalog.packs,
                      onAddPhoto: (photo) => _addMediaPhoto(context, photo),
                      onAddPack: (pack) => _addMediaPack(context, pack),
                    ),
                  const SizedBox(height: 22),
                  const Text(
                    'CATÉGORIES',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.2,
                      color: MasliveTheme.textPrimary,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (catalog.galleries.isEmpty && !catalog.loading)
                    MediaMarketplaceMessageCard.empty(
                      title: 'Aucune galerie',
                      message: 'Aucune galerie disponible pour cette source.',
                      icon: Icons.photo_library_outlined,
                    )
                  else
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: catalog.galleries
                            .map(
                              (MediaGalleryModel gallery) => Padding(
                                padding: const EdgeInsets.only(right: 10),
                                child: _CategoryPill(
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
                ],
              ),
            ),
          ),
        ],
      ),
    );

    if (embedded) {
      return premiumBody;
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
      body: premiumBody,
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

class _MarketplacePremiumHeader extends StatelessWidget {
  const _MarketplacePremiumHeader({required this.cartCount});

  final int cartCount;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: Row(
        children: <Widget>[
          const Icon(
            Icons.menu,
            size: 28,
            color: MasliveTheme.textPrimary,
          ),
          const Spacer(),
          const Text(
            'MASLIVE',
            style: TextStyle(
              fontSize: 25,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.8,
              color: MasliveTheme.textPrimary,
              height: 1,
            ),
          ),
          const Spacer(),
          const Icon(
            Icons.search,
            size: 24,
            color: MasliveTheme.textPrimary,
          ),
          const SizedBox(width: 14),
          Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              const Icon(
                Icons.shopping_bag_outlined,
                size: 23,
                color: MasliveTheme.textPrimary,
              ),
              if (cartCount > 0)
                Positioned(
                  right: -10,
                  top: -8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: MasliveTheme.textPrimary,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      cartCount > 99 ? '99+' : '$cartCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        height: 1,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MarketplacePremiumHeroBanner extends StatelessWidget {
  const _MarketplacePremiumHeroBanner({required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 142,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: MasliveTheme.headerGradient,
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: <Color>[
                  MasliveTheme.textPrimary.withValues(alpha: 0.26),
                  MasliveTheme.textPrimary.withValues(alpha: 0.10),
                  MasliveTheme.textPrimary.withValues(alpha: 0.06),
                ],
                stops: const <double>[0.0, 0.45, 1.0],
              ),
            ),
          ),
          Positioned(
            left: 18,
            top: 18,
            bottom: 18,
            right: 18,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Spacer(),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: -1.0,
                    height: 1,
                  ),
                ),
                if (subtitle?.trim().isNotEmpty == true) ...<Widget>[
                  const SizedBox(height: 6),
                  Text(
                    subtitle!.trim(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      height: 1,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Container(
                  height: 34,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: MasliveTheme.textPrimary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    'VOIR',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 0.8,
                      height: 1,
                    ),
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

class _PremiumTitleRow extends StatelessWidget {
  const _PremiumTitleRow({required this.title, required this.trailing, this.onTrailingTap});

  final String title;
  final String trailing;
  final VoidCallback? onTrailingTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        const SizedBox(width: 0),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.2,
            color: MasliveTheme.textPrimary,
            height: 1.1,
          ),
        ),
        const Spacer(),
        GestureDetector(
          onTap: onTrailingTap,
          child: Text(
            trailing,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
              color: MasliveTheme.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

class _CategoryPill extends StatelessWidget {
  const _CategoryPill({
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
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          color: selected ? MasliveTheme.textPrimary : MasliveTheme.textPrimary.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(22),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 12.8,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            letterSpacing: 0.1,
            height: 1,
          ),
        ),
      ),
    );
  }
}

class _PremiumProductsGrid extends StatelessWidget {
  const _PremiumProductsGrid({
    required this.photos,
    required this.packs,
    required this.onAddPhoto,
    required this.onAddPack,
  });

  final List<MediaPhotoModel> photos;
  final List<MediaPackModel> packs;
  final ValueChanged<MediaPhotoModel> onAddPhoto;
  final ValueChanged<MediaPackModel> onAddPack;

  @override
  Widget build(BuildContext context) {
    final itemCount = photos.length + packs.length;
    if (itemCount == 0) {
      return MediaMarketplaceMessageCard.empty(
        title: 'Aucun média',
        message: 'Cette galerie ne contient pas encore de photos ou packs vendables.',
        icon: Icons.collections_outlined,
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.73,
      ),
      itemCount: itemCount,
      itemBuilder: (context, i) {
        final bool isPhoto = i < photos.length;
        if (isPhoto) {
          final photo = photos[i];
          return _PremiumProductCard(
            title: photo.downloadFileName,
            subtitle: 'PHOTO',
            price: _formatPrice(photo.unitPrice, photo.currency),
            icon: Icons.image_outlined,
            onTap: () => onAddPhoto(photo),
          );
        }
        final pack = packs[i - photos.length];
        return _PremiumProductCard(
          title: pack.title,
          subtitle: '${pack.photoIds.length} PHOTOS',
          price: _formatPrice(pack.price, pack.currency),
          icon: Icons.collections_outlined,
          onTap: () => onAddPack(pack),
        );
      },
    );
  }
}

class _PremiumProductCard extends StatelessWidget {
  const _PremiumProductCard({
    required this.title,
    required this.subtitle,
    required this.price,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String price;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        decoration: BoxDecoration(
          color: MasliveTheme.surface,
          borderRadius: BorderRadius.circular(24),
          boxShadow: MasliveTheme.cardShadow,
        ),
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Align(
              alignment: Alignment.topRight,
              child: Container(
                width: 34,
                height: 34,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.favorite_border,
                  size: 19,
                  color: MasliveTheme.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: Center(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: MasliveTheme.surfaceAlt,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  alignment: Alignment.center,
                  child: Icon(icon, size: 46, color: MasliveTheme.textSecondary),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: MasliveTheme.textSecondary,
                height: 1,
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: MasliveTheme.textPrimary,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              price,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: MasliveTheme.textPrimary,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatPrice(double value, String currency) {
  final formatted = value.toStringAsFixed(2).replaceAll('.', ',');
  final symbol = currency.toUpperCase() == 'EUR' ? '€' : currency.toUpperCase();
  return '$formatted $symbol';
}
