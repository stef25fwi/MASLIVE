import 'package:flutter/material.dart';

import '../models/mock_shop_models.dart';
import '../widgets/category_chip_row.dart';
import '../widgets/rounded_product_card.dart';
import '../widgets/section_header.dart';
import '../widgets/shop_app_header.dart';

class MarketplacePremiumPage extends StatelessWidget {
  const MarketplacePremiumPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F8),
      bottomNavigationBar: const MerchBottomNav(),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const SizedBox(height: 4),
              const ShopAppHeader(
                centeredLogoText: 'MASLIVE',
                showMenu: true,
                showSearch: true,
                showBag: true,
                compact: true,
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: const _MerchHeroBanner(),
              ),
              const SizedBox(height: 18),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 18),
                child: SectionHeader(
                  title: 'NOUVEAUTÉS',
                  actionLabel: 'Voir tout',
                ),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: ShopMockData.merchProducts.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 13,
                    crossAxisSpacing: 13,
                    childAspectRatio: 0.69,
                  ),
                  itemBuilder: (BuildContext context, int index) {
                    final MerchProduct product = ShopMockData.merchProducts[index];
                    return RoundedProductCard(
                      imageUrl: product.imageUrl,
                      title: product.title,
                      price: product.price,
                      isFavorite: product.isFavorite,
                      backgroundColor: const Color(0xFFF0F1F3),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 18),
                child: SectionHeader(
                  title: 'CATÉGORIES',
                ),
              ),
              const SizedBox(height: 10),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 18),
                child: CategoryChipRow(
                  labels: ShopMockData.merchCategories,
                  darkStyle: true,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MerchHeroBanner extends StatelessWidget {
  const _MerchHeroBanner();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: Stack(
        children: <Widget>[
          AspectRatio(
            aspectRatio: 16 / 8.7,
            child: Image.network(
              ShopMockData.merchHeroImage,
              fit: BoxFit.cover,
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: <Color>[
                  Colors.black.withValues(alpha: 0.15),
                  Colors.black.withValues(alpha: 0.35),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: const SizedBox.expand(),
          ),
          const Positioned(
            left: 18,
            bottom: 18,
            child: Text(
              'MASLIVE',
              style: TextStyle(
                color: Colors.white,
                fontSize: 31,
                fontWeight: FontWeight.w900,
                letterSpacing: -1.1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
