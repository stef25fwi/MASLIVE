import 'package:flutter/material.dart';

class PhotoGridCard extends StatelessWidget {
  const PhotoGridCard({
    super.key,
    required this.imageUrl,
    this.showFavorite = false,
    this.radius = 22,
  });

  final String imageUrl;
  final bool showFavorite;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Image.network(
            imageUrl,
            fit: BoxFit.cover,
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[
                  Colors.black.withValues(alpha: 0.02),
                  Colors.black.withValues(alpha: 0.10),
                ],
              ),
            ),
          ),
          if (showFavorite)
            Positioned(
              top: 10,
              right: 10,
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.favorite_border,
                  size: 17,
                  color: Color(0xFF141414),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
