import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../data/models/bloom_art_item.dart';
import '../../data/repositories/bloom_art_repository.dart';
import '../widgets/bloom_art_gallery_header.dart';
import '../widgets/bloom_art_item_card.dart';
import 'bloom_art_profile_choice_sheet.dart';

class BloomArtHomePage extends StatelessWidget {
  BloomArtHomePage({super.key});

  final BloomArtRepository _repository = BloomArtRepository();

  Future<void> _handleSellPressed(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      Navigator.of(context).pushNamed('/login');
      return;
    }

    final selectedType = await showBloomArtProfileChoiceSheet(context);
    if (!context.mounted || selectedType == null) return;

    Navigator.of(context).pushNamed(
      '/bloom-art/sell',
      arguments: <String, dynamic>{'selectedType': selectedType},
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFFFFBF7),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFFBF7),
        elevation: 0,
        title: const Text(
          'Bloom Art',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: <Widget>[
          if (user != null)
            IconButton(
              tooltip: 'Espace vendeur',
              onPressed: () => Navigator.of(context).pushNamed('/bloom-art/dashboard'),
              icon: const Icon(Icons.dashboard_customize_outlined),
            ),
        ],
      ),
      body: StreamBuilder<List<BloomArtItem>>(
        stream: _repository.watchPublishedItems(),
        builder: (context, snapshot) {
          final items = snapshot.data ?? const <BloomArtItem>[];

          return LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              int crossAxisCount = 1;
              if (width >= 1180) {
                crossAxisCount = 3;
              } else if (width >= 720) {
                crossAxisCount = 2;
              }

              return CustomScrollView(
                slivers: <Widget>[
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
                    sliver: SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          BloomArtGalleryHeader(
                            onSellPressed: () => _handleSellPressed(context),
                          ),
                          const SizedBox(height: 18),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: const <Widget>[
                              _BloomArtPill(label: 'Prix privé côté vendeur'),
                              _BloomArtPill(label: 'Offres négociées avec élégance'),
                              _BloomArtPill(label: 'Checkout Stripe centralisé'),
                            ],
                          ),
                          const SizedBox(height: 26),
                          const Text(
                            'Pièces disponibles',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF1A1A1A),
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Les visiteurs découvrent la matière, le geste et l’histoire de la pièce. Le prix de référence reste confidentiel.',
                            style: TextStyle(
                              color: Color(0xFF6A645E),
                              height: 1.45,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (snapshot.connectionState == ConnectionState.waiting)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (snapshot.hasError)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'Impossible de charger la galerie Bloom Art : ${snapshot.error}',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    )
                  else if (items.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'Aucune pièce n’est encore publiée. Revenez bientôt ou déposez la première création de la galerie.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Color(0xFF6A645E),
                              height: 1.45,
                            ),
                          ),
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
                      sliver: SliverGrid.builder(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: crossAxisCount == 1 ? 0.79 : 0.74,
                        ),
                        itemCount: items.length,
                        itemBuilder: (context, index) {
                          final item = items[index];
                          return BloomArtItemCard(
                            item: item,
                            onTap: () => Navigator.of(context).pushNamed(
                              '/bloom-art/item/${item.id}',
                            ),
                          );
                        },
                      ),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _BloomArtPill extends StatelessWidget {
  const _BloomArtPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE9DED1)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF6A645E),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
