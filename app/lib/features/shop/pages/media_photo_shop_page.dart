import 'package:flutter/material.dart';

class MaslivePhotoShopPage extends StatelessWidget {
  const MaslivePhotoShopPage({super.key});

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFFF7F7F7);
    const textDark = Color(0xFF18151F);
    const textSoft = Color(0xFF7D7884);
    const chipBg = Color(0xFFFFFFFF);

    return Scaffold(
      backgroundColor: bg,
      bottomNavigationBar: const _BottomBar(),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              _TopTimeAndIcons(),
              SizedBox(height: 18),
              Center(
                child: Text(
                  'MASLIVE',
                  style: TextStyle(
                    color: textDark,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1.1,
                    height: 1,
                  ),
                ),
              ),
              SizedBox(height: 6),
              Center(
                child: Text(
                  'LA BOUTIQUE PHOTO',
                  style: TextStyle(
                    color: textSoft,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2.1,
                    height: 1,
                  ),
                ),
              ),
              SizedBox(height: 20),
              _TopChipsRow(
                labels: ['ÉVÉNEMENTS', 'PHOTOS', 'PACKS', 'ARTISTES'],
                backgroundColor: chipBg,
              ),
              SizedBox(height: 18),
              _HeroCard(),
              SizedBox(height: 22),
              _SectionHeader(),
              SizedBox(height: 14),
              _PhotosMosaic(),
              SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopTimeAndIcons extends StatelessWidget {
  const _TopTimeAndIcons();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        SizedBox(width: 4),
        Text(
          '9:41',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Colors.black,
          ),
        ),
        Spacer(),
        Icon(Icons.signal_cellular_alt, size: 16, color: Colors.black),
        SizedBox(width: 4),
        Icon(Icons.wifi, size: 16, color: Colors.black),
        SizedBox(width: 4),
        _BatteryIcon(),
      ],
    );
  }
}

class _BatteryIcon extends StatelessWidget {
  const _BatteryIcon();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 26,
      height: 12,
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
          Container(
            width: 22,
            height: 12,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.black, width: 1.5),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          Positioned(
            right: 0,
            child: Container(
              width: 2.5,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ),
          Positioned(
            left: 2,
            top: 2,
            bottom: 2,
            child: Container(
              width: 15,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(1.5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopChipsRow extends StatelessWidget {
  final List<String> labels;
  final Color backgroundColor;

  const _TopChipsRow({
    required this.labels,
    required this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: labels
          .map(
            (label) => Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: label == labels.last ? 0 : 10),
                child: Container(
                  height: 42,
                  decoration: BoxDecoration(
                    color: backgroundColor,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x0A000000),
                        blurRadius: 6,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1D1A22),
                      letterSpacing: 0.2,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: SizedBox(
        height: 242,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?auto=format&fit=crop&w=1200&q=80',
              fit: BoxFit.cover,
            ),
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomLeft,
                  end: Alignment.topRight,
                  colors: [
                    Color(0x95000000),
                    Color(0x25000000),
                  ],
                ),
              ),
            ),
            const Positioned(
              left: 18,
              bottom: 28,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'CARNAVAL 2024',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 33,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1,
                      height: 1,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'DÉCOUVRIR  >',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                    ),
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

class _SectionHeader extends StatelessWidget {
  const _SectionHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        Text(
          'PHOTOS POPULAIRES',
          style: TextStyle(
            color: Color(0xFF18151F),
            fontSize: 19,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.2,
          ),
        ),
        Spacer(),
        Text(
          'Voir tout',
          style: TextStyle(
            color: Color(0xFF75707B),
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _PhotosMosaic extends StatelessWidget {
  const _PhotosMosaic();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 498,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 41,
            child: Column(
              children: const [
                Expanded(
                  child: _PhotoTile(
                    imageUrl:
                        'https://images.unsplash.com/photo-1501386761578-eac5c94b800a?auto=format&fit=crop&w=900&q=80',
                    showHeart: true,
                    heartFilled: false,
                  ),
                ),
                SizedBox(height: 10),
                Expanded(
                  child: _PhotoTile(
                    imageUrl:
                        'https://images.unsplash.com/photo-1516280440614-37939bbacd81?auto=format&fit=crop&w=900&q=80',
                    showHeart: true,
                    heartFilled: true,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 59,
            child: Column(
              children: [
                const Expanded(
                  flex: 42,
                  child: _PhotoTile(
                    imageUrl:
                        'https://images.unsplash.com/photo-1493225457124-a3eb161ffa5f?auto=format&fit=crop&w=1200&q=80',
                    showHeart: true,
                    heartFilled: false,
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  flex: 33,
                  child: Row(
                    children: const [
                      Expanded(
                        flex: 56,
                        child: _PhotoTile(
                          imageUrl:
                              'https://images.unsplash.com/photo-1500530855697-b586d89ba3ee?auto=format&fit=crop&w=900&q=80',
                        ),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        flex: 44,
                        child: Column(
                          children: [
                            Expanded(
                              child: _PhotoTile(
                                imageUrl:
                                    'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?auto=format&fit=crop&w=900&q=80',
                              ),
                            ),
                            SizedBox(height: 10),
                            Expanded(
                              child: _PhotoTile(
                                imageUrl:
                                    'https://images.unsplash.com/photo-1509824227185-9c5a01ceba0d?auto=format&fit=crop&w=900&q=80',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                const Expanded(
                  flex: 18,
                  child: _PhotoTile(
                    imageUrl:
                        'https://images.unsplash.com/photo-1521334884684-d80222895322?auto=format&fit=crop&w=1200&q=80',
                    partialHeartBottomRight: true,
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

class _PhotoTile extends StatelessWidget {
  final String imageUrl;
  final bool showHeart;
  final bool heartFilled;
  final bool partialHeartBottomRight;

  const _PhotoTile({
    required this.imageUrl,
    this.showHeart = false,
    this.heartFilled = false,
    this.partialHeartBottomRight = false,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            imageUrl,
            fit: BoxFit.cover,
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.06),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          if (showHeart)
            Positioned(
              top: 10,
              right: 10,
              child: heartFilled
                  ? const _FilledHeartBadge()
                  : const _HeartBadge(),
            ),
          if (partialHeartBottomRight)
            const Positioned(
              right: -7,
              bottom: -7,
              child: _HeartBadge(
                size: 24,
                iconSize: 13,
              ),
            ),
        ],
      ),
    );
  }
}

class _HeartBadge extends StatelessWidget {
  final double size;
  final double iconSize;

  const _HeartBadge({
    this.size = 34,
    this.iconSize = 20,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: Color(0x14FFFFFF),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Icon(
          Icons.favorite_border,
          size: iconSize,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _FilledHeartBadge extends StatelessWidget {
  const _FilledHeartBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: const BoxDecoration(
        color: Color(0x1AFFFFFF),
        shape: BoxShape.circle,
      ),
      child: const Center(
        child: Icon(
          Icons.favorite,
          size: 19,
          color: Color(0xFFFF2F8B),
        ),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar();

  @override
  Widget build(BuildContext context) {
    const inactive = Color(0xFF2A2432);
    const active = Color(0xFF17131D);

    return Container(
      height: 90,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Color(0xFFE8E8E8), width: 1),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: const [
          _BottomItem(
            icon: Icons.home_outlined,
            label: 'Accueil',
            color: inactive,
          ),
          _BottomItem(
            icon: Icons.photo_camera_outlined,
            label: 'Photos',
            color: active,
            isActive: true,
          ),
          _BottomItem(
            icon: Icons.arrow_downward_rounded,
            label: 'Téléchargements',
            color: inactive,
          ),
          _BottomItem(
            icon: Icons.person_outline,
            label: 'Profil',
            color: inactive,
          ),
        ],
      ),
    );
  }
}

class _BottomItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool isActive;

  const _BottomItem({
    required this.icon,
    required this.label,
    required this.color,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    final textStyle = TextStyle(
      fontSize: 12,
      fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
      color: color,
      letterSpacing: -0.1,
    );

    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 28, color: color),
          const SizedBox(height: 5),
          Text(
            label,
            style: textStyle,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.visible,
          ),
        ],
      ),
    );
  }
}
