import 'package:flutter/material.dart';

import '../widgets/seller_profile_choice_card.dart';
import 'package:masslive/ui_kit/tokens/maslive_tokens.dart';

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
        color: MasliveTokens.surfaceEditorial,
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
            'Quel parcours Bloom Art ?',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: MasliveTokens.text,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Le dépôt d’œuvre est réservé aux artistes déclarés avec SIRET vérifié. Le parcours “Je me lance” sert à préparer la création d’entreprise.',
            style: TextStyle(
              color: MasliveTokens.textEditorialMuted,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 18),
          SellerProfileChoiceCard(
            title: 'Artisan d’art déclaré',
            subtitle:
                'J’ai un SIRET : vérifier mon activité, créer ma galerie et accéder au dashboard.',
            icon: Icons.verified_rounded,
            onTap: () => Navigator.of(context).pop('artisan_art'),
          ),
          const SizedBox(height: 12),
          SellerProfileChoiceCard(
            title: 'Je me lance',
            subtitle:
                'Je n’ai pas encore de SIRET : suivre le guide de création d’entreprise.',
            icon: Icons.auto_awesome_outlined,
            onTap: () => Navigator.of(context).pop('je_me_lance'),
          ),
        ],
      ),
    );
  }
}
