import 'package:flutter/material.dart';

class MediaPhotoShopPage extends StatelessWidget {
  const MediaPhotoShopPage({super.key});

  @override
  Widget build(BuildContext context) {
    const Color pageBg = Color(0xFFF7F7F7);
    const Color textPrimary = Color(0xFF111111);
    const Color textSecondary = Color(0xFF7A7A7A);
    const Color borderColor = Color(0xFFEDEDED);

    return Scaffold(
      backgroundColor: pageBg,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),

                    // ---------------- TOP LOGO AREA ----------------
                    const Center(
                      child: Text(
                        'MASLIVE',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.8,
                          color: textPrimary,
                          height: 1,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Center(
                      child: Text(
                        'LA BOUTIQUE PHOTO',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 2.2,
                          color: Color(0xFF4A4A4A),
                          height: 1,
                        ),
                      ),
                    ),

                    const SizedBox(height: 22),

                    // ---------------- CATEGORY CHIPS ----------------
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: const [
                          _CategoryChip(label: 'ÉVÉNEMENTS'),
                          SizedBox(width: 12),
                          _CategoryChip(label: 'PHOTOS'),
                          SizedBox(width: 12),
                          _CategoryChip(label: 'PACKS'),
                          SizedBox(width: 12),
                          _CategoryChip(label: 'ARTISTES'),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ---------------- HERO CARD ----------------
                    const _HeroCarnavalCard(),

                    const SizedBox(height: 22),

                    // ---------------- SECTION HEADER ----------------
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: const [
                        Text(
                          'PHOTOS POPULAIRES',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.2,
                            color: textPrimary,
                            height: 1.1,
                          ),
                        ),
                        Spacer(),
                        Text(
                          'Voir tout',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w500,
                            color: textSecondary,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // ---------------- PHOTO MOSAIC ----------------
                    const _PhotosMosaic(),

                    const SizedBox(height: 18),
                  ],
                ),
              ),
            ),

            // ---------------- BOTTOM NAV ----------------
            Container(
              height: 88,
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(
                    color: borderColor,
                    width: 1,
                  ),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _BottomNavItem(
                    icon: Icons.home_outlined,
                    label: 'Accueil',
                    active: false,
                  ),
                  _BottomNavItem(
                    icon: Icons.photo_camera_outlined,
                    label: 'Photos',
                    active: true,
                  ),
                  _BottomNavItem(
                    icon: Icons.arrow_downward_rounded,
                    label: 'Téléchargements',
                    active: false,
                  ),
                  _BottomNavItem(
                    icon: Icons.person_outline,
                    label: 'Profil',
                    active: false,
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

class _CategoryChip extends StatelessWidget {
  final String label;

  const _CategoryChip({
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 13.5,
          fontWeight: FontWeight.w700,
          color: Color(0xFF111111),
          letterSpacing: 0.1,
        ),
      ),
    );
  }
}

class _HeroCarnavalCard extends StatelessWidget {
  const _HeroCarnavalCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 240,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?auto=format&fit=crop&w=1200&q=80',
            fit: BoxFit.cover,
          ),

          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Colors.black.withValues(alpha: 0.50),
                  Colors.black.withValues(alpha: 0.14),
                  Colors.black.withValues(alpha: 0.10),
                ],
                stops: const [0.0, 0.38, 1.0],
              ),
            ),
          ),

          Positioned(
            left: 18,
            bottom: 22,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'CARNAVAL 2024',
                  style: TextStyle(
                    fontSize: 27,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: -0.6,
                    height: 1,
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  'DÉCOUVRIR  >',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 0.2,
                    height: 1,
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

class _PhotosMosaic extends StatelessWidget {
  const _PhotosMosaic();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 434,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // LEFT COLUMN
          Expanded(
            child: Column(
              children: const [
                Expanded(
                  flex: 11,
                  child: _PhotoCard(
                    imageUrl:
                        'https://images.unsplash.com/photo-1501386761578-eac5c94b800a?auto=format&fit=crop&w=900&q=80',
                    showHeart: true,
                    filledHeart: false,
                  ),
                ),
                SizedBox(height: 10),
                Expanded(
                  flex: 9,
                  child: _PhotoCard(
                    imageUrl:
                        'https://images.unsplash.com/photo-1493225457124-a3eb161ffa5f?auto=format&fit=crop&w=900&q=80',
                    showHeart: true,
                    filledHeart: true,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 10),

          // RIGHT COLUMN
          Expanded(
            flex: 1,
            child: Column(
              children: const [
                Expanded(
                  flex: 9,
                  child: _PhotoCard(
                    imageUrl:
                        'https://images.unsplash.com/photo-1516280440614-37939bbacd81?auto=format&fit=crop&w=900&q=80',
                    showHeart: true,
                    filledHeart: false,
                  ),
                ),
                SizedBox(height: 10),
                Expanded(
                  flex: 8,
                  child: Row(
                    children: [
                      Expanded(
                        child: _PhotoCard(
                          imageUrl:
                              'https://images.unsplash.com/photo-1500530855697-b586d89ba3ee?auto=format&fit=crop&w=900&q=80',
                          showHeart: false,
                          filledHeart: false,
                        ),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          children: [
                            Expanded(
                              child: _PhotoCard(
                                imageUrl:
                                    'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?auto=format&fit=crop&w=900&q=80',
                                showHeart: false,
                                filledHeart: false,
                              ),
                            ),
                            SizedBox(height: 10),
                            Expanded(
                              child: _PhotoCard(
                                imageUrl:
                                    'https://images.unsplash.com/photo-1492684223066-81342ee5ff30?auto=format&fit=crop&w=900&q=80',
                                showHeart: false,
                                filledHeart: false,
                              ),
                            ),
                            SizedBox(height: 10),
                            Expanded(
                              child: _PhotoCard(
                                imageUrl:
                                    'https://images.unsplash.com/photo-1506157786151-b8491531f063?auto=format&fit=crop&w=900&q=80',
                                showHeart: true,
                                filledHeart: false,
                                heartSmall: true,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
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

class _PhotoCard extends StatelessWidget {
  final String imageUrl;
  final bool showHeart;
  final bool filledHeart;
  final bool heartSmall;

  const _PhotoCard({
    required this.imageUrl,
    required this.showHeart,
    required this.filledHeart,
    this.heartSmall = false,
  });

  @override
  Widget build(BuildContext context) {
    final double heartBoxSize = heartSmall ? 22 : 34;
    final double heartIconSize = heartSmall ? 14 : 20;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            imageUrl,
            fit: BoxFit.cover,
          ),
          if (showHeart)
            Positioned(
              top: 10,
              right: 10,
              child: Container(
                width: heartBoxSize,
                height: heartBoxSize,
                decoration: BoxDecoration(
                  color: filledHeart ? const Color(0xFFFF3D86) : Colors.transparent,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(
                  filledHeart ? Icons.favorite : Icons.favorite_border,
                  size: heartIconSize,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _BottomNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;

  const _BottomNavItem({
    required this.icon,
    required this.label,
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    final Color activeColor = const Color(0xFF111111);
    final Color inactiveColor = const Color(0xFF858585);

    return SizedBox(
      width: 86,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 29,
            color: active ? activeColor : inactiveColor,
          ),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11.8,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              color: active ? activeColor : inactiveColor,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}
