import 'package:flutter/material.dart';

import '../models/mock_shop_models.dart';
import '../widgets/category_chip_row.dart';
import '../widgets/photo_grid_card.dart';
import '../widgets/section_header.dart';
import '../widgets/shop_app_header.dart';

class MediaPhotoShopPage extends StatelessWidget {
  const MediaPhotoShopPage({super.key});

  @override
  Widget build(BuildContext context) {
    final List<PhotoItem> photos = ShopMockData.popularPhotos;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F9),
      bottomNavigationBar: const MediaBottomNav(),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const SizedBox(height: 4),
              const ShopAppHeader(
                centeredLogoText: 'MASLIVE',
                subtitle: 'LA BOUTIQUE PHOTO',
                compact: true,
              ),
              const SizedBox(height: 16),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 18),
                child: CategoryChipRow(
                  labels: ShopMockData.photoCategories,
                  darkStyle: false,
                  selectedIndex: 0,
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: const _CarnivalHeroCard(),
              ),
              const SizedBox(height: 16),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 18),
                child: SectionHeader(
                  title: 'PHOTOS POPULAIRES',
                  actionLabel: 'Voir tout',
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: _PremiumMosaic(photos: photos),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PremiumMosaic extends StatelessWidget {
  const _PremiumMosaic({required this.photos});

  final List<PhotoItem> photos;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 352,
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              children: <Widget>[
                Expanded(
                  flex: 6,
                  child: PhotoGridCard(
                    imageUrl: photos[0].imageUrl,
                    showFavorite: photos[0].isFavorite,
                    radius: 21,
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  flex: 5,
                  child: PhotoGridCard(
                    imageUrl: photos[3].imageUrl,
                    showFavorite: photos[3].isFavorite,
                    radius: 21,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              children: <Widget>[
                Expanded(
                  flex: 5,
                  child: PhotoGridCard(
                    imageUrl: photos[1].imageUrl,
                    showFavorite: photos[1].isFavorite,
                    radius: 21,
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  flex: 4,
                  child: PhotoGridCard(
                    imageUrl: photos[2].imageUrl,
                    showFavorite: photos[2].isFavorite,
                    radius: 21,
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  flex: 3,
                  child: PhotoGridCard(
                    imageUrl: photos[4].imageUrl,
                    showFavorite: photos[4].isFavorite,
                    radius: 21,
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

class _CarnivalHeroCard extends StatelessWidget {
  const _CarnivalHeroCard();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Stack(
        children: <Widget>[
          AspectRatio(
            aspectRatio: 16 / 10.2,
            child: Image.network(
              ShopMockData.mediaHeroImage,
              fit: BoxFit.cover,
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: <Color>[
                  Colors.black.withValues(alpha: 0.10),
                  Colors.black.withValues(alpha: 0.50),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: const SizedBox.expand(),
          ),
          const Positioned(
            left: 18,
            bottom: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'CARNAVAL 2024',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 31,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.9,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'DÉCOUVRIR  >',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.1,
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
