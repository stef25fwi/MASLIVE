import 'package:flutter/material.dart';

import '../models/mock_shop_models.dart';
import '../widgets/shop_app_header.dart';
import '../../../ui/theme/maslive_theme.dart';

class MarketplacePremiumPage extends StatelessWidget {
  const MarketplacePremiumPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MasliveTheme.surfaceAlt,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: <Widget>[
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const _TopHeader(),
                    const SizedBox(height: 18),
                    const _HeroBanner(),
                    const SizedBox(height: 26),
                    const _SectionTitleRow(
                      title: 'NOUVEAUTÉS',
                      actionLabel: 'Voir tout',
                    ),
                    const SizedBox(height: 16),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: ShopMockData.merchProducts.length,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 14,
                        crossAxisSpacing: 14,
                        childAspectRatio: 0.735,
                      ),
                      itemBuilder: (context, index) {
                        final MerchProduct product = ShopMockData.merchProducts[index];
                        return _MerchProductCard(
                          title: product.title,
                          price: product.price,
                          imageUrl: product.imageUrl,
                          isFavorite: product.isFavorite,
                        );
                      },
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'CATÉGORIES',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.4,
                        color: MasliveTheme.textPrimary,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 46,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        itemCount: ShopMockData.merchCategories.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemBuilder: (context, i) {
                          return _CategoryChip(label: ShopMockData.merchCategories[i]);
                        },
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ),
            const MerchBottomNav(),
          ],
        ),
      ),
    );
  }
}

class _TopHeader extends StatelessWidget {
  const _TopHeader();

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          "MAS'LIVE",
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.9,
            color: MasliveTheme.textPrimary,
            height: 1,
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 8),
        Text(
          'LA BOUTIQUE',
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w500,
            letterSpacing: 2.2,
            color: MasliveTheme.textSecondary,
            height: 1,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _HeroBanner extends StatelessWidget {
  const _HeroBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 188,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Image.asset(
            ShopMockData.merchHeroImage,
            fit: BoxFit.cover,
          ),
          Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0.0, 0.0),
                radius: 1.15,
                colors: <Color>[
                  Colors.transparent,
                  MasliveTheme.textPrimary.withValues(alpha: 0.18),
                ],
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: <Color>[
                  MasliveTheme.textPrimary.withValues(alpha: 0.20),
                  Colors.transparent,
                  MasliveTheme.textPrimary.withValues(alpha: 0.08),
                ],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
            ),
          ),
          Center(
            child: Container(
              width: 232,
              height: 112,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: MasliveTheme.pink,
                  width: 6,
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: MasliveTheme.pink.withValues(alpha: 0.45),
                    blurRadius: 22,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
          ),
          const Center(
            child: Text(
              'MASLIVE',
              style: TextStyle(
                fontSize: 50,
                fontWeight: FontWeight.w900,
                letterSpacing: -1.6,
                color: MasliveTheme.pink,
                height: 1,
                shadows: <Shadow>[
                  Shadow(
                    color: Colors.black54,
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitleRow extends StatelessWidget {
  const _SectionTitleRow({required this.title, required this.actionLabel});

  final String title;
  final String actionLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.4,
            color: MasliveTheme.textPrimary,
            height: 1,
          ),
        ),
        const Spacer(),
        Text(
          actionLabel,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: MasliveTheme.textSecondary,
            height: 1,
          ),
        ),
      ],
    );
  }
}

class _MerchProductCard extends StatelessWidget {
  const _MerchProductCard({
    required this.title,
    required this.price,
    required this.imageUrl,
    required this.isFavorite,
  });

  final String title;
  final String price;
  final String imageUrl;
  final bool isFavorite;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: MasliveTheme.surface,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Stack(
              children: <Widget>[
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isFavorite ? Icons.favorite : Icons.favorite_border,
                      color: MasliveTheme.textPrimary,
                      size: 24,
                    ),
                  ),
                ),
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 22, 16, 16),
                    child: Center(
                      child: Image.asset(
                        imageUrl,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w500,
            color: MasliveTheme.textPrimary,
            height: 1,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          price,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w900,
            color: MasliveTheme.textPrimary,
            height: 1,
          ),
        ),
      ],
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: MasliveTheme.textPrimary,
        borderRadius: BorderRadius.circular(24),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w800,
          color: Colors.white,
          letterSpacing: 0.2,
          height: 1,
        ),
      ),
    );
  }
}
