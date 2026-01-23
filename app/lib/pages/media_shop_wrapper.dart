import 'package:flutter/material.dart';
import 'media_galleries_page_v2.dart';

/// Wrapper pour ajouter le GalleryCartScope à la page média
/// 
/// Utilisation:
/// 
/// ```dart
/// // Dans votre navigation:
/// Navigator.push(
///   context,
///   MaterialPageRoute(
///     builder: (_) => const MediaShopWrapper(groupId: 'all'),
///   ),
/// );
/// ```
class MediaShopWrapper extends StatefulWidget {
  const MediaShopWrapper({super.key, required this.groupId});

  final String groupId;

  @override
  State<MediaShopWrapper> createState() => _MediaShopWrapperState();
}

class _MediaShopWrapperState extends State<MediaShopWrapper> {
  late final GalleryCartProvider _cartProvider;

  @override
  void initState() {
    super.initState();
    _cartProvider = GalleryCartProvider();
  }

  @override
  void dispose() {
    _cartProvider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GalleryCartScope(
      notifier: _cartProvider,
      child: MediaGalleriesPage(groupId: widget.groupId),
    );
  }
}
