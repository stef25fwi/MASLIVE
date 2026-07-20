import 'package:flutter/material.dart';

import '../../data/models/media_photo_model.dart';
import '../controllers/media_marketplace_catalog_controller.dart';

int mediaPhotoGridColumnCount(double width) {
  if (width >= 1500) return 6;
  if (width >= 1180) return 5;
  if (width >= 900) return 4;
  if (width >= 620) return 3;
  return 2;
}

class PaginatedMediaPhotoGrid extends StatelessWidget {
  const PaginatedMediaPhotoGrid({
    super.key,
    required this.controller,
    required this.itemBuilder,
    this.padding = EdgeInsets.zero,
    this.mainAxisSpacing = 12,
    this.crossAxisSpacing = 12,
    this.childAspectRatio = .76,
  });

  final MediaMarketplaceCatalogController controller;
  final Widget Function(BuildContext context, MediaPhotoModel photo) itemBuilder;
  final EdgeInsetsGeometry padding;
  final double mainAxisSpacing;
  final double crossAxisSpacing;
  final double childAspectRatio;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final photos = controller.photos;
        return LayoutBuilder(
          builder: (context, constraints) {
            final columns = mediaPhotoGridColumnCount(constraints.maxWidth);
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                GridView.builder(
                  key: const Key('paginated_media_photo_grid'),
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: padding,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    mainAxisSpacing: mainAxisSpacing,
                    crossAxisSpacing: crossAxisSpacing,
                    childAspectRatio: childAspectRatio,
                  ),
                  itemCount: photos.length,
                  itemBuilder: (context, index) => itemBuilder(context, photos[index]),
                ),
                if (controller.hasMorePhotos || controller.loadingMorePhotos) ...<Widget>[
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.tonalIcon(
                      key: const Key('load_more_media_photos'),
                      onPressed: controller.canLoadMorePhotos
                          ? controller.loadMorePhotos
                          : null,
                      icon: controller.loadingMorePhotos
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.expand_more_rounded),
                      label: Text(
                        controller.loadingMorePhotos
                            ? 'Chargement des photos…'
                            : 'Charger plus de photos',
                      ),
                    ),
                  ),
                ],
              ],
            );
          },
        );
      },
    );
  }
}
