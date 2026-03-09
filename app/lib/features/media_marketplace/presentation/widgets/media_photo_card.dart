import 'package:flutter/material.dart';

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
    return SizedBox(
      width: width,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                height: 120,
                color: Colors.grey.shade200,
                alignment: Alignment.center,
                child: const Icon(Icons.image_outlined, size: 42),
              ),
              const SizedBox(height: 12),
              Text(
                photo.downloadFileName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Text('${photo.unitPrice.toStringAsFixed(2)} ${photo.currency}'),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: onPrimaryAction,
                icon: Icon(primaryActionIcon),
                label: Text(primaryActionLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}