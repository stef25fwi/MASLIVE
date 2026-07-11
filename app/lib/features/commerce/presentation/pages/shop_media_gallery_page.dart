import 'package:flutter/material.dart';

import '../../../../ui/widgets/storage_image.dart';
import '../../data/commerce_repository.dart';
import '../../domain/commerce_models.dart';

class ShopMediaGalleryPage extends StatelessWidget {
  final String shopId;
  const ShopMediaGalleryPage({super.key, required this.shopId});

  @override
  Widget build(BuildContext context) {
    final repo = CommerceRepository();

    return Scaffold(
      appBar: AppBar(title: const Text('Galerie photos boutique')),
      body: StreamBuilder<List<ShopMedia>>(
        stream: repo.streamShopMedia(shopId, onlyVisible: false),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text('Erreur: \'${snap.error}\''));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snap.data!;
          if (items.isEmpty) {
            return const Center(child: Text('Aucun média pour ce shop'));
          }

          final w = MediaQuery.of(context).size.width;
          final cross = w >= 1100 ? 5 : (w >= 800 ? 4 : (w >= 520 ? 3 : 2));

          return GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: cross,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final m = items[index];
              return GestureDetector(
                onTap: () {
                  showDialog<void>(
                    context: context,
                    builder: (_) => Dialog(
                      insetPadding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AspectRatio(
                            aspectRatio: 4 / 3,
                            child: m.isVideo
                                ? const Center(
                                    child: Icon(Icons.videocam_outlined),
                                  )
                                : StorageImage(
                                    url: m.url,
                                    fit: BoxFit.cover,
                                    cacheWidth: 800,
                                  ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text(
                              m.locationName ?? '',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      m.isVideo
                          ? Container(
                              color: Colors.black12,
                              child: const Icon(Icons.videocam_outlined),
                            )
                          : StorageImage(
                              url: m.url,
                              fit: BoxFit.cover,
                              cacheWidth: 400,
                            ),
                      if (!m.isVisible)
                        Container(
                          color: Colors.black38,
                          alignment: Alignment.topRight,
                          padding: const EdgeInsets.all(4),
                          child: const Icon(
                            Icons.visibility_off,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
