import 'package:flutter/material.dart';

import '../../../../ui/widgets/storage_image.dart';
import '../../data/models/media_photo_model.dart';

class MediaPhotoCard extends StatelessWidget {
  const MediaPhotoCard({
    super.key,
    required this.photo,
    this.onPrimaryAction,
    this.primaryActionLabel = 'Ajouter',
    this.primaryActionIcon = Icons.add_shopping_cart,
    this.width = 240,
  });

  final MediaPhotoModel photo;
  final VoidCallback? onPrimaryAction;
  final String primaryActionLabel;
  final IconData primaryActionIcon;
  final double width;

  @override
  Widget build(BuildContext context) {
    final previewUrl = photo.watermarkedPath.isNotEmpty
        ? photo.watermarkedPath
        : photo.previewPath.isNotEmpty
            ? photo.previewPath
            : photo.thumbnailPath;

    return SizedBox(
      width: width,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            AspectRatio(
              aspectRatio: 4 / 3,
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  StorageImage(
                    url: previewUrl,
                    fit: BoxFit.cover,
                    placeholder: const ColoredBox(
                      color: Color(0x11000000),
                      child: Center(child: Icon(Icons.photo_outlined)),
                    ),
                  ),
                  IgnorePointer(
                    child: Center(
                      child: Transform.rotate(
                        angle: -0.18,
                        child: Text(
                          'MASLIVE',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.62),
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2.4,
                            shadows: const <Shadow>[
                              Shadow(color: Colors.black54, blurRadius: 4),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 8,
                    bottom: 8,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.70),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        child: Text(
                          '${photo.unitPrice.toStringAsFixed(2)} ${photo.currency}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    photo.downloadFileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  if (photo.circuitName?.trim().isNotEmpty == true) ...<Widget>[
                    const SizedBox(height: 4),
                    Text(
                      photo.circuitName!.trim(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: onPrimaryAction,
                      icon: Icon(primaryActionIcon),
                      label: Text(primaryActionLabel),
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
