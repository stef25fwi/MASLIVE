import 'package:flutter/material.dart';

@immutable
class MerchProduct {
  const MerchProduct({
    required this.id,
    required this.title,
    required this.price,
    required this.imageUrl,
    this.isFavorite = false,
  });

  final String id;
  final String title;
  final String price;
  final String imageUrl;
  final bool isFavorite;
}

@immutable
class PhotoItem {
  const PhotoItem({
    required this.id,
    required this.imageUrl,
    required this.crossAxisCellCount,
    required this.mainAxisCellCount,
    this.isFavorite = false,
  });

  final String id;
  final String imageUrl;
  final int crossAxisCellCount;
  final int mainAxisCellCount;
  final bool isFavorite;
}

class ShopMockData {
  ShopMockData._();

  static const String merchHeroImage = 'assets/images/maslivesmall.png';

  static const String mediaHeroImage = 'assets/images/maslivesmall.png';

  static const List<MerchProduct> merchProducts = <MerchProduct>[
    MerchProduct(
      id: 'merch_1',
      title: 'T-Shirt MASLIVE',
      price: '35,00 €',
      imageUrl: 'assets/shop/tshirt.png',
      isFavorite: true,
    ),
    MerchProduct(
      id: 'merch_2',
      title: 'Bandana MASLIVE',
      price: '20,00 €',
      imageUrl: 'assets/shop/bandana.png',
    ),
    MerchProduct(
      id: 'merch_3',
      title: 'Hoodie MASLIVE',
      price: '45,00 €',
      imageUrl: 'assets/shop/hoodie.png',
    ),
    MerchProduct(
      id: 'merch_4',
      title: 'Casquette MASLIVE',
      price: '26,00 €',
      imageUrl: 'assets/shop/cap.png',
    ),
  ];

  static const List<String> merchCategories = <String>[
    'T-SHIRTS',
    'PHOTO',
    'ACCESSOIRES',
    'BANDANAS',
    'GOODIES',
  ];

  static const List<String> photoCategories = <String>[
    'ÉVÉNEMENTS',
    'PHOTOS',
    'PACKS',
    'ARTISTES',
  ];

  static const List<PhotoItem> popularPhotos = <PhotoItem>[
    PhotoItem(
      id: 'photo_1',
      imageUrl:
          'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?auto=format&fit=crop&w=1100&q=80',
      crossAxisCellCount: 2,
      mainAxisCellCount: 2,
      isFavorite: true,
    ),
    PhotoItem(
      id: 'photo_2',
      imageUrl:
          'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?auto=format&fit=crop&w=900&q=80',
      crossAxisCellCount: 1,
      mainAxisCellCount: 1,
    ),
    PhotoItem(
      id: 'photo_3',
      imageUrl:
          'https://images.unsplash.com/photo-1493225457124-a3eb161ffa5f?auto=format&fit=crop&w=900&q=80',
      crossAxisCellCount: 1,
      mainAxisCellCount: 1,
      isFavorite: true,
    ),
    PhotoItem(
      id: 'photo_4',
      imageUrl:
          'https://images.unsplash.com/photo-1500530855697-b586d89ba3ee?auto=format&fit=crop&w=900&q=80',
      crossAxisCellCount: 1,
      mainAxisCellCount: 1,
      isFavorite: true,
    ),
    PhotoItem(
      id: 'photo_5',
      imageUrl:
          'https://images.unsplash.com/photo-1516280440614-37939bbacd81?auto=format&fit=crop&w=900&q=80',
      crossAxisCellCount: 1,
      mainAxisCellCount: 1,
    ),
  ];
}
