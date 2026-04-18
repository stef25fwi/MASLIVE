import 'package:flutter/material.dart';

import 'bloom_art_cta_button.dart';

class BloomArtGalleryHeader extends StatelessWidget {
  const BloomArtGalleryHeader({
    super.key,
    this.onSellPressed,
  });

  final VoidCallback? onSellPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color(0xFFFFF5E7),
            Color(0xFFF9E8D7),
            Color(0xFFF2DED5),
          ],
        ),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 24,
            offset: Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Text(
              'Galerie Bloom Art',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: Color(0xFF6D4C41),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'L\'artisanat d\'art entre galerie privee, negotiation elegante et paiement centralise.',
            style: TextStyle(
              fontSize: 30,
              height: 1.1,
              fontWeight: FontWeight.w900,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Exposez une piece, recevez des offres et basculez vers le checkout Stripe deja en place dans MASLIVE.',
            style: TextStyle(
              fontSize: 15,
              height: 1.45,
              color: Color(0xFF5F564F),
            ),
          ),
          const SizedBox(height: 18),
          BloomArtCtaButton(
            label: 'Je souhaite vendre une creation',
            icon: Icons.auto_awesome_rounded,
            onPressed: onSellPressed,
          ),
        ],
      ),
    );
  }
}