import 'package:flutter/material.dart';

import '../widgets/seller_profile_choice_card.dart';

Future<String?> showBloomArtProfileChoiceSheet(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const BloomArtProfileChoiceSheet(),
  );
}

class BloomArtProfileChoiceSheet extends StatelessWidget {
  const BloomArtProfileChoiceSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFFFFBF7),
        borderRadius: BorderRadius.vertical(top: Radius.circular(34)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 26),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Center(
            child: Container(
              width: 48,
              height: 5,
              decoration: BoxDecoration(
                color: const Color(0xFFD7CABD),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Quel type de vendeur êtes-vous ?',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Choisissez votre profil pour ouvrir le bon parcours Bloom Art.',
            style: TextStyle(
              color: Color(0xFF6A645E),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 18),
          SellerProfileChoiceCard(
            title: 'Artiste créateur',
            subtitle:
                'Vous avez déjà un statut vendeur et pouvez déposer votre création sans détour.',
            icon: Icons.palette_outlined,
            onTap: () => Navigator.of(context).pop('artist_creator'),
          ),
          const SizedBox(height: 12),
          SellerProfileChoiceCard(
            title: 'Je me lance',
            subtitle:
                'Vous vendez une première création et devez compléter votre profil avant dépôt.',
            icon: Icons.auto_awesome_outlined,
            onTap: () => Navigator.of(context).pop('je_me_lance'),
          ),
        ],
      ),
    );
  }
}
