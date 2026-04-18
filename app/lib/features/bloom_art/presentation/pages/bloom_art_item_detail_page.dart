import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../data/models/bloom_art_item.dart';
import '../../data/repositories/bloom_art_repository.dart';
import '../widgets/bloom_art_cta_button.dart';
import '../widgets/bloom_art_info_row.dart';
import 'bloom_art_make_offer_sheet.dart';

class BloomArtItemDetailPage extends StatelessWidget {
  BloomArtItemDetailPage({
    super.key,
    required this.itemId,
  });

  final String itemId;
  final BloomArtRepository _repository = BloomArtRepository();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFBF7),
      body: StreamBuilder<BloomArtItem?>(
        stream: _repository.watchItem(itemId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Impossible de charger la fiche : ${snapshot.error}'),
              ),
            );
          }

          final item = snapshot.data;
          if (item == null) {
            return const Center(child: Text('Creation introuvable.'));
          }

          final user = FirebaseAuth.instance.currentUser;
          final isOwner = user?.uid == item.sellerId;

          return CustomScrollView(
            slivers: <Widget>[
              SliverAppBar(
                backgroundColor: const Color(0xFFFFFBF7),
                pinned: true,
                elevation: 0,
                title: Text(
                  item.title,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      _BloomArtHeroImages(item: item),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(color: const Color(0xFFE9DED1)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              item.category.toUpperCase(),
                              style: const TextStyle(
                                letterSpacing: 1.2,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF8E6D4F),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              item.title,
                              style: const TextStyle(
                                fontSize: 28,
                                height: 1.1,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 10),
                            if (item.sellerDisplayName.trim().isNotEmpty)
                              Text(
                                item.sellerDisplayName,
                                style: const TextStyle(
                                  color: Color(0xFF6A645E),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            const SizedBox(height: 16),
                            Text(
                              item.description,
                              style: const TextStyle(
                                color: Color(0xFF1D1D1D),
                                height: 1.55,
                              ),
                            ),
                            const SizedBox(height: 18),
                            BloomArtInfoRow(
                              label: 'Etat',
                              value: item.condition,
                            ),
                            BloomArtInfoRow(
                              label: 'Dimensions',
                              value: item.dimensions,
                            ),
                            BloomArtInfoRow(
                              label: 'Materiaux',
                              value: item.materials.join(', '),
                            ),
                            BloomArtInfoRow(
                              label: 'Remise',
                              value: item.deliveryMode,
                            ),
                            BloomArtInfoRow(
                              label: 'Notes',
                              value: item.deliveryNotes,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      _BloomArtPublicCtaCard(
                        item: item,
                        isOwner: isOwner,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _BloomArtHeroImages extends StatelessWidget {
  const _BloomArtHeroImages({required this.item});

  final BloomArtItem item;

  @override
  Widget build(BuildContext context) {
    if (item.images.isEmpty) {
      return Container(
        height: 320,
        decoration: BoxDecoration(
          color: const Color(0xFFF7EEE5),
          borderRadius: BorderRadius.circular(32),
        ),
        child: const Center(
          child: Icon(
            Icons.palette_outlined,
            size: 64,
            color: Color(0xFF8E6D4F),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: AspectRatio(
            aspectRatio: 1.12,
            child: Image.network(item.images.first, fit: BoxFit.cover),
          ),
        ),
        if (item.images.length > 1) ...<Widget>[
          const SizedBox(height: 12),
          SizedBox(
            height: 84,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: item.images.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                return ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: Image.network(item.images[index], fit: BoxFit.cover),
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}

class _BloomArtPublicCtaCard extends StatelessWidget {
  const _BloomArtPublicCtaCard({
    required this.item,
    required this.isOwner,
  });

  final BloomArtItem item;
  final bool isOwner;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final canOffer = item.isAvailableForOffers && !isOwner;

    String subtitle;
    if (isOwner) {
      subtitle =
          'Vous etes le vendeur de cette piece. Retrouvez ses offres et son statut dans votre espace vendeur.';
    } else if (item.isSold) {
      subtitle = 'Cette piece a deja trouve acquereur.';
    } else if (item.isReserved) {
      subtitle = 'Une offre acceptee est actuellement en cours de paiement.';
    } else {
      subtitle =
          'Le prix de reference reste prive. Vous pouvez faire une offre et ajouter un message au vendeur.';
    }

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color(0xFFFFF5E7),
            Color(0xFFF7E9DD),
            Color(0xFFF1E2DA),
          ],
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'Proposer un prix',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: const TextStyle(color: Color(0xFF6A645E), height: 1.45),
          ),
          const SizedBox(height: 18),
          if (isOwner)
            BloomArtCtaButton(
              label: 'Ouvrir mon dashboard vendeur',
              icon: Icons.dashboard_customize_outlined,
              onPressed: () => Navigator.of(context).pushNamed('/bloom-art/dashboard'),
            )
          else if (canOffer)
            BloomArtCtaButton(
              label: user == null ? 'Se connecter pour proposer un prix' : 'Proposer un prix',
              icon: Icons.local_offer_outlined,
              onPressed: () {
                if (user == null) {
                  Navigator.of(context).pushNamed('/login');
                  return;
                }
                showBloomArtMakeOfferSheet(context, item: item);
              },
            )
          else
            const Text(
              'La negociation n\'est pas disponible pour cette piece en ce moment.',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
        ],
      ),
    );
  }
}