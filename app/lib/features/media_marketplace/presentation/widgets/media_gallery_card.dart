import 'package:flutter/material.dart';

import '../../data/models/media_gallery_model.dart';

class MediaGalleryCard extends StatelessWidget {
  const MediaGalleryCard({
    super.key,
    required this.gallery,
    this.selected = false,
    this.onTap,
    this.width,
    this.trailing,
  });

  final MediaGalleryModel gallery;
  final bool selected;
  final VoidCallback? onTap;
  final double? width;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final card = Card(
      color: selected ? Colors.black87 : null,
      child: ListTile(
        onTap: onTap,
        title: Text(
          gallery.title,
          style: TextStyle(color: selected ? Colors.white : null),
        ),
        subtitle: Text(
          '${gallery.photoCount} photos • ${gallery.packCount} packs',
          style: TextStyle(color: selected ? Colors.white70 : null),
        ),
        trailing: trailing,
      ),
    );

    if (width == null) {
      return card;
    }

    return SizedBox(width: width, child: card);
  }
}