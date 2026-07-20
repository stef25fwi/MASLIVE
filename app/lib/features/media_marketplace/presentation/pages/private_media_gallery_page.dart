import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/media_pack_model.dart';
import '../../data/models/media_photo_model.dart';
import '../controllers/media_marketplace_cart_controller.dart';
import '../controllers/media_marketplace_catalog_controller.dart';
import '../widgets/media_pack_card.dart';
import '../widgets/media_photo_card.dart';

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
      child: const _PrivateMediaGalleryView(),
    );
  }
}

class _PrivateMediaGalleryView extends StatelessWidget {
  const _PrivateMediaGalleryView();

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<MediaMarketplaceCatalogController>();
    final storefront = controller.accessStorefront;
    final photographer = controller.accessPhotographer;
    final gallery = controller.galleries.isEmpty ? null : controller.galleries.first;
    final headline = storefront['headline']?.toString().trim();
    final description = storefront['description']?.toString().trim();
    final layout = storefront['layout']?.toString() ?? 'grid';
    final showName = storefront['showPhotographerName'] as bool? ?? true;
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
                      galleryId: controller.selectedGalleryId ?? '',
                      accessToken: Uri.base.queryParameters['access'] ?? '',
                      participantCode: Uri.base.queryParameters['participant'],
                    ),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: controller.loading
          ? const Center(child: CircularProgressIndicator())
          : controller.error != null
              ? _AccessError(error: controller.error!)
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
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
                                backgroundImage: NetworkImage(photographer!.avatarUrl!),
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
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge
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
                            Chip(
                              avatar: const Icon(Icons.lock_outline, size: 17),
                              label: const Text('Accès sécurisé'),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (gallery != null) ...<Widget>[
                      Text(
                        gallery.title,
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      if (gallery.description?.isNotEmpty == true)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(gallery.description!),
                        ),
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
                      ),
                    if (controller.packs.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 26),
                      Text(
                        'Packs disponibles',
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: controller.packs
                            .map((pack) => _PrivatePack(pack: pack))
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
  const _PrivatePhotoGrid({required this.photos, required this.layout});

  final List<MediaPhotoModel> photos;
  final String layout;

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
            childAspectRatio: layout == 'editorial' ? .72 : .82,
          ),
          itemCount: photos.length,
          itemBuilder: (context, index) {
            final photo = photos[index];
            return MediaPhotoCard(
              photo: photo,
              selected: false,
              onTap: () => _addPhoto(context, photo),
              onAddToCart: () => _addPhoto(context, photo),
            );
          },
        );
      },
    );
  }

  Future<void> _addPhoto(BuildContext context, MediaPhotoModel photo) async {
    final cart = context.read<MediaMarketplaceCartController>();
    await cart.addPhoto(photo);
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
  const _PrivatePack({required this.pack});

  final MediaPackModel pack;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 310,
      child: MediaPackCard(
        pack: pack,
        onAddToCart: () async {
          await context.read<MediaMarketplaceCartController>().addPack(pack);
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Pack ajouté au panier.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
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
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              error.toString(),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
