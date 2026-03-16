import 'package:flutter/material.dart';
import '../models/mock_shop_models.dart';

final List<String> photoCategories = ShopMockData.photoCategories;
final List<PhotoItem> popularPhotos = ShopMockData.popularPhotos;

class MediaPhotoShopPage extends StatelessWidget {
  const MediaPhotoShopPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F9),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 1,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.black54,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: 'Accueil'),
          BottomNavigationBarItem(icon: Icon(Icons.photo_camera_outlined), label: 'Photos'),
          BottomNavigationBarItem(icon: Icon(Icons.download_outlined), label: 'Téléchargements'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Profil'),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Center(
                child: Text(
                  'MASLIVE',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -0.8),
                ),
              ),
              const SizedBox(height: 6),
              const Center(
                child: Text(
                  'LA BOUTIQUE PHOTO',
                  style: TextStyle(fontSize: 13, color: Colors.black54, fontWeight: FontWeight.w500, letterSpacing: 1.2),
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                height: 40,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: photoCategories.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (context, index) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFEFF1),
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Text(
                        photoCategories[index],
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 18),
              const _CarnivalHeroCard(),
              const SizedBox(height: 18),
              Row(
                children: const [
                  Text(
                    'PHOTOS POPULAIRES',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: 0.3),
                  ),
                  Spacer(),
                  Text(
                    'Voir tout',
                    style: TextStyle(fontSize: 13.5, color: Colors.black54, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const _PhotoMosaicGrid(),
            ],
          ),
        ),
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
            aspectRatio: 16 / 10,
            child: Image.network(
              'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=1200',
              fit: BoxFit.cover,
            ),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.black.withValues(alpha: 0.10),
                  Colors.black.withValues(alpha: 0.50),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          const Positioned(
            left: 18,
            bottom: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CARNAVAL 2024',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.8,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'DÉCOUVRIR  >',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
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

class _PhotoMosaicGrid extends StatelessWidget {
  const _PhotoMosaicGrid();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 360,
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              children: [
                Expanded(
                  flex: 6,
                  child: _photoCard(popularPhotos[0].imageUrl, true),
                ),
                const SizedBox(height: 10),
                Expanded(
                  flex: 5,
                  child: _photoCard(popularPhotos[3].imageUrl, true),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              children: [
                Expanded(
                  flex: 5,
                  child: _photoCard(popularPhotos[1].imageUrl, true),
                ),
                const SizedBox(height: 10),
                Expanded(
                  flex: 4,
                  child: _photoCard(popularPhotos[2].imageUrl, false),
                ),
                const SizedBox(height: 10),
                Expanded(
                  flex: 3,
                  child: _photoCard(popularPhotos[4].imageUrl, false),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _photoCard(String url, bool favorite) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.network(url, fit: BoxFit.cover),
          if (favorite)
            Positioned(
              top: 10,
              right: 10,
              child: Container(
                width: 34,
                height: 34,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.favorite_border, size: 18),
              ),
            ),
        ],
      ),
    );
  }
}
