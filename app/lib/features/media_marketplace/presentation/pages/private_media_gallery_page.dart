import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../models/cart_item_model.dart' as unified_cart;
import '../../../../providers/cart_provider.dart';
import '../../../../ui/widgets/storage_image.dart';
import '../../../../ui_kit/responsive/responsive.dart';
import '../../core/enums/media_asset_type.dart';
import '../../data/models/media_pack_model.dart';
import '../../data/models/media_photo_model.dart';
import '../controllers/media_marketplace_catalog_controller.dart';

class PrivateMediaGalleryPage extends StatelessWidget {
  const PrivateMediaGalleryPage({
    super.key,
    required this.galleryId,
    required this.accessToken,
    this.participantCode,
  });

  final String galleryId;
  final String accessToken;
  final String? participantCode;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<MediaMarketplaceCatalogController>(
      create: (_) {
        final controller = MediaMarketplaceCatalogController();
        Future<void>.microtask(
          () => controller.loadPrivateGallery(
            galleryId: galleryId,
            accessToken: accessToken,
            participantCode: participantCode,
          ),
        );
        return controller;
      },
      child: _PrivateMediaGalleryView(
        galleryId: galleryId,
        accessToken: accessToken,
        participantCode: participantCode,
      ),
    );
  }
}

class _PrivateMediaGalleryView extends StatelessWidget {
  const _PrivateMediaGalleryView({
    required this.galleryId,
    required this.accessToken,
    required this.participantCode,
  });

  final String galleryId;
  final String accessToken;
  final String? participantCode;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<MediaMarketplaceCatalogController>();
    final storefront = controller.accessStorefront;
    final photographer = controller.accessPhotographer;
    final gallery = controller.galleries.isEmpty
        ? null
        : controller.galleries.first;
    final headline = storefront['headline']?.toString().trim();
    final description = storefront['description']?.toString().trim();
    final layout = storefront['layout']?.toString() ?? 'grid';
    final showName = storefront['showPhotographerName'] as bool? ?? true;
    final showEvent = storefront['showEventContext'] as bool? ?? true;
    final accent = _parseColor(storefront['accentColor']?.toString());

    return Scaffold(
      appBar: AppBar(
        title: Text(gallery?.title ?? 'Galerie privée'),
        backgroundColor: accent,
        actions: <Widget>[
          IconButton(
            onPressed: controller.loading
                ? null
                : () => controller.loadPrivateGallery(
                    galleryId: galleryId,
                    accessToken: accessToken,
                    participantCode: participantCode,
                  ),
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Actualiser',
          ),
        ],
      ),
      body: controller.loading
          ? const Center(child: CircularProgressIndicator())
          : controller.error != null
          ? _AccessError(error: controller.error!)
          : ListView(
              padding: responsiveValue<EdgeInsets>(
                context,
                compact: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                medium: const EdgeInsets.fromLTRB(28, 20, 28, 36),
                expanded: const EdgeInsets.fromLTRB(64, 24, 64, 40),
                wide: const EdgeInsets.fromLTRB(120, 28, 120, 44),
              ),
              children: <Widget>[
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Row(
                      children: <Widget>[
                        if (photographer?.avatarUrl?.isNotEmpty == true)
                          CircleAvatar(
                            radius: 30,
                            backgroundImage: NetworkImage(
                              photographer!.avatarUrl!,
                            ),
                          )
                        else
                          const CircleAvatar(
                            radius: 30,
                            child: Icon(Icons.camera_alt_outlined),
                          ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              if (showName)
                                Text(
                                  photographer?.brandName ?? '',
                                  style: Theme.of(context).textTheme.titleLarge
                                      ?.copyWith(fontWeight: FontWeight.w900),
                                ),
                              if (headline?.isNotEmpty == true) Text(headline!),
                              if (description?.isNotEmpty == true)
                                Text(
                                  description!,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                            ],
                          ),
                        ),
                        const Chip(
                          avatar: Icon(Icons.lock_outline, size: 17),
                          label: Text('Accès sécurisé'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (gallery != null) ...<Widget>[
                  Text(
                    gallery.title,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (gallery.description?.isNotEmpty == true)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(gallery.description!),
                    ),
                  if (showEvent) ...<Widget>[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: <Widget>[
                        if (gallery.eventId.isNotEmpty)
                          Chip(
                            avatar: const Icon(
                              Icons.celebration_outlined,
                              size: 17,
                            ),
                            label: Text(gallery.eventId),
                          ),
                        if (gallery.linkedCircuitId?.isNotEmpty == true)
                          Chip(
                            avatar: const Icon(Icons.route_outlined, size: 17),
                            label: Text(gallery.linkedCircuitId!),
                          ),
                      ],
                    ),
                  ],
                ],
                const SizedBox(height: 18),
                if (controller.photos.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Text('Aucune photo publiée dans cette galerie.'),
                    ),
                  )
                else
                  _PrivatePhotoGrid(
                    photos: controller.photos,
                    layout: layout,
                    accent: accent,
                  ),
                if (controller.packs.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 26),
                  Text(
                    'Packs disponibles',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: controller.packs
                        .map((pack) => _PrivatePack(pack: pack, accent: accent))
                        .toList(growable: false),
                  ),
                ],
              ],
            ),
    );
  }

  static Color? _parseColor(String? value) {
    final raw = value?.replaceAll('#', '').trim();
    if (raw == null || (raw.length != 6 && raw.length != 8)) return null;
    final parsed = int.tryParse(raw, radix: 16);
    if (parsed == null) return null;
    return Color(raw.length == 6 ? 0xFF000000 | parsed : parsed);
  }
}

class _PrivatePhotoGrid extends StatelessWidget {
  const _PrivatePhotoGrid({
    required this.photos,
    required this.layout,
    required this.accent,
  });

  final List<MediaPhotoModel> photos;
  final String layout;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final baseColumns = constraints.maxWidth >= 1100
            ? 6
            : constraints.maxWidth >= 800
            ? 5
            : constraints.maxWidth >= 560
            ? 4
            : 2;
        final columns = layout == 'editorial'
            ? (baseColumns - 1).clamp(1, 5)
            : layout == 'minimal'
            ? (baseColumns + 1).clamp(2, 7)
            : baseColumns;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: layout == 'editorial' ? .68 : .78,
          ),
          itemCount: photos.length,
          itemBuilder: (context, index) {
            final photo = photos[index];
            final image = photo.watermarkedPath.isNotEmpty
                ? photo.watermarkedPath
                : photo.thumbnailPath;
            return Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Expanded(
                    child: image.isEmpty
                        ? const ColoredBox(
                            color: Colors.black12,
                            child: Icon(Icons.image_outlined, size: 42),
                          )
                        : StorageImage(url: image, fit: BoxFit.cover),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          photo.downloadFileName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${photo.unitPrice.toStringAsFixed(2)} ${photo.currency}',
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            style: accent == null
                                ? null
                                : FilledButton.styleFrom(
                                    backgroundColor: accent,
                                  ),
                            onPressed: () => _addPhoto(context, photo),
                            icon: const Icon(Icons.add_shopping_cart),
                            label: const Text('Ajouter'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _addPhoto(BuildContext context, MediaPhotoModel photo) async {
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
        sourceType: 'media_marketplace_private',
        metadata: <String, dynamic>{
          'assetType': MediaAssetType.photo.firestoreValue,
          'galleryId': photo.galleryId,
          'privateAccessValidated': true,
        },
      ),
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Photo ajoutée au panier.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class _PrivatePack extends StatelessWidget {
  const _PrivatePack({required this.pack, required this.accent});

  final MediaPackModel pack;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final viewportWidth = MediaQuery.sizeOf(context).width;
    final availableWidth = viewportWidth - 32;
    final cardWidth = availableWidth.clamp(0.0, 310.0).toDouble();

    return SizedBox(
      width: cardWidth,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Icon(Icons.collections_outlined, size: 38),
              const SizedBox(height: 10),
              Text(
                pack.title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
              ),
              if (pack.description?.isNotEmpty == true)
                Padding(
                  padding: const EdgeInsets.only(top: 5),
                  child: Text(pack.description!),
                ),
              const SizedBox(height: 8),
              Text(
                '${pack.pickCount ?? pack.photoIds.length} photo(s) • ${pack.price.toStringAsFixed(2)} ${pack.currency}',
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: accent == null
                      ? null
                      : FilledButton.styleFrom(backgroundColor: accent),
                  onPressed: () => _addPack(context),
                  icon: const Icon(Icons.add_shopping_cart),
                  label: const Text('Ajouter au panier'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _addPack(BuildContext context) async {
    await context.read<CartProvider>().addCartItem(
      unified_cart.CartItemModel(
        id: '',
        itemType: unified_cart.CartItemType.media,
        productId: pack.packId,
        sellerId: pack.photographerId,
        eventId: pack.eventId,
        title: pack.title,
        subtitle: pack.galleryId.isEmpty
            ? null
            : 'Pack galerie ${pack.galleryId}',
        imageUrl: pack.coverUrl ?? '',
        unitPrice: pack.price,
        quantity: 1,
        currency: pack.currency,
        isDigital: true,
        requiresShipping: false,
        sourceType: 'media_marketplace_private',
        metadata: <String, dynamic>{
          'assetType': MediaAssetType.pack.firestoreValue,
          'galleryId': pack.galleryId,
          'photoIds': pack.photoIds,
          'photoCount': pack.pickCount ?? pack.photoIds.length,
          'privateAccessValidated': true,
        },
      ),
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Pack ajouté au panier.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class _AccessError extends StatelessWidget {
  const _AccessError({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.lock_person_outlined, size: 58),
            const SizedBox(height: 14),
            Text(
              'Accès impossible',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(error.toString(), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
