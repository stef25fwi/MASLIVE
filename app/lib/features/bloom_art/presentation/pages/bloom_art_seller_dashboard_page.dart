import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../data/models/bloom_art_item.dart';
import '../../data/models/bloom_art_offer.dart';
import '../../data/models/bloom_art_seller_profile.dart';
import '../../data/repositories/bloom_art_offer_repository.dart';
import '../../data/repositories/bloom_art_repository.dart';
import '../widgets/bloom_art_cta_button.dart';
import '../widgets/bloom_art_item_card.dart';
import '../widgets/bloom_art_offer_status_badge.dart';

class BloomArtSellerDashboardPage extends StatelessWidget {
  BloomArtSellerDashboardPage({super.key});

  final BloomArtRepository _repository = BloomArtRepository();
  final BloomArtOfferRepository _offerRepository = BloomArtOfferRepository();

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        Navigator.of(context).pushReplacementNamed('/login');
      });
      return const Scaffold(body: SizedBox.shrink());
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFFFBF7),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFFBF7),
        elevation: 0,
        title: const Text(
          'Dashboard Bloom Art',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: StreamBuilder<BloomArtSellerProfile?>(
        stream: _repository.watchSellerProfile(user.uid),
        builder: (context, profileSnapshot) {
          final profile = profileSnapshot.data;
          return ListView(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 28),
            children: <Widget>[
              _DashboardHero(profile: profile),
              const SizedBox(height: 18),
              if (profile == null)
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFFE9DED1)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text(
                        'Aucun profil vendeur configure',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Commencez par choisir votre profil Bloom Art avant de deposer une creation.',
                        style: TextStyle(color: Color(0xFF6A645E), height: 1.45),
                      ),
                      const SizedBox(height: 14),
                      BloomArtCtaButton(
                        label: 'Configurer mon profil vendeur',
                        icon: Icons.storefront_outlined,
                        onPressed: () => Navigator.of(context).pushNamed('/bloom-art/sell'),
                      ),
                    ],
                  ),
                )
              else
                BloomArtCtaButton(
                  label: 'Deposer une nouvelle creation',
                  icon: Icons.add_photo_alternate_outlined,
                  onPressed: () => Navigator.of(context).pushNamed(
                    '/bloom-art/create',
                    arguments: <String, dynamic>{
                      'profileType': profile.profileType,
                    },
                  ),
                ),
              const SizedBox(height: 24),
              const Text(
                'Mes creations',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 12),
              StreamBuilder<List<BloomArtItem>>(
                stream: _repository.watchSellerItems(user.uid),
                builder: (context, itemsSnapshot) {
                  final items = itemsSnapshot.data ?? const <BloomArtItem>[];
                  if (itemsSnapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (items.isEmpty) {
                    return const _EmptyBloomArtBlock(
                      message:
                          'Aucune creation deposee pour le moment. Publiez votre premiere piece Bloom Art.',
                    );
                  }

                  return Column(
                    children: items
                        .map(
                          (item) => Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: BloomArtItemCard(
                              item: item,
                              showSellerMeta: false,
                              onTap: () => Navigator.of(context).pushNamed(
                                '/bloom-art/item/${item.id}',
                              ),
                            ),
                          ),
                        )
                        .toList(growable: false),
                  );
                },
              ),
              const SizedBox(height: 24),
              const Text(
                'Offres recues',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 12),
              StreamBuilder<List<BloomArtOffer>>(
                stream: _offerRepository.watchSellerOffers(user.uid),
                builder: (context, offersSnapshot) {
                  final offers = offersSnapshot.data ?? const <BloomArtOffer>[];
                  if (offersSnapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (offers.isEmpty) {
                    return const _EmptyBloomArtBlock(
                      message:
                          'Aucune offre recue pour le moment. Les visiteurs pourront proposer un prix depuis la fiche publique de vos pieces.',
                    );
                  }

                  return Column(
                    children: offers
                        .map(
                          (offer) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _OfferPreviewCard(offer: offer),
                          ),
                        )
                        .toList(growable: false),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DashboardHero extends StatelessWidget {
  const _DashboardHero({required this.profile});

  final BloomArtSellerProfile? profile;

  @override
  Widget build(BuildContext context) {
    final displayName = profile?.displayName.trim().isNotEmpty == true
        ? profile!.displayName
        : 'Votre espace vendeur';
    final payoutStatus = profile?.payoutStatus ?? 'pending';

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color(0xFFFFF5E7),
            Color(0xFFF8E6D7),
            Color(0xFFF2DDD7),
          ],
        ),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            displayName,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(
            profile == null
                ? 'Finalisez votre profil pour deposer des oeuvres et gerer les offres recues.'
                : 'Type: ${profile!.profileType}  |  payout: $payoutStatus  |  Stripe relie: ${profile!.stripeAccountLinked ? 'oui' : 'non'}',
            style: const TextStyle(color: Color(0xFF6A645E), height: 1.45),
          ),
        ],
      ),
    );
  }
}

class _OfferPreviewCard extends StatelessWidget {
  const _OfferPreviewCard({required this.offer});

  final BloomArtOffer offer;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: () => Navigator.of(context).pushNamed(
        '/bloom-art/offers/${offer.id}',
      ),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFE9DED1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    'Offre sur ${offer.itemId}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                BloomArtOfferStatusBadge(status: offer.status),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '${offer.proposedPrice.toStringAsFixed(2)} EUR',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: Color(0xFF1A1A1A),
              ),
            ),
            if (offer.buyerMessage.trim().isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                offer.buyerMessage,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF6A645E),
                  height: 1.4,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EmptyBloomArtBlock extends StatelessWidget {
  const _EmptyBloomArtBlock({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE9DED1)),
      ),
      child: Text(
        message,
        style: const TextStyle(color: Color(0xFF6A645E), height: 1.45),
      ),
    );
  }
}