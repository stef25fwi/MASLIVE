import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../../shop/widgets/storex_page_header.dart';
import '../../data/models/bloom_art_item.dart';
import '../../data/models/bloom_art_seller_profile.dart';
import '../../data/repositories/bloom_art_repository.dart';
import '../widgets/bloom_art_item_card.dart';
import 'bloom_art_profile_choice_sheet.dart';

class _Ui {
  const _Ui._();
  static const Color pageBg = Color(0xFFF7F8FC);
  static const Color textMain = Color(0xFF101828);
  static const Color textMuted = Color(0xFF667085);
  static const LinearGradient rainbowGradient = LinearGradient(
    colors: [Color(0xFFFFE36A), Color(0xFFFF7BC5), Color(0xFF7CE0FF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class BloomArtHomePage extends StatelessWidget {
  BloomArtHomePage({super.key});

  final BloomArtRepository _repository = BloomArtRepository();
  final GlobalKey _gallerySectionKey = GlobalKey();

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
    final sellerProfileStream = user == null
        ? Stream<BloomArtSellerProfile?>.value(null)
        : _repository.watchSellerProfile(user.uid);

    return StreamBuilder<BloomArtSellerProfile?>(
      stream: sellerProfileStream,
      builder: (context, profileSnapshot) {
        final isArtCreator = profileSnapshot.data?.isArtisanArt == true;
        return _buildGallery(context, user, isArtCreator);
      },
    );
  }

  Widget _buildGallery(
    BuildContext context,
    User? user,
    bool isArtCreator,
  ) {
    return Scaffold(
      backgroundColor: _Ui.pageBg,
      appBar: AppBar(
        backgroundColor: const Color(0xFFF6F7FB),
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        toolbarHeight: 88,
        iconTheme: const IconThemeData(color: _Ui.textMain),
        centerTitle: true,
        title: const StorexPageHeaderTitle(subtitle: 'GALERIE BLOOMOOD ART'),
        actions: <Widget>[
          if (isArtCreator)
            IconButton(
              tooltip: 'Espace vendeur',
              onPressed: () =>
                  Navigator.of(context).pushNamed('/bloom-art/dashboard'),
              icon: const Icon(Icons.dashboard_customize_outlined),
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: StreamBuilder<List<BloomArtItem>>(
        stream: _repository.watchPublishedItems(),
        builder: (context, snapshot) {
          final items = snapshot.data ?? const <BloomArtItem>[];

          return LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              int crossAxisCount = 2;
              if (width >= 1180) crossAxisCount = 3;

              return CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: <Widget>[
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(10, 14, 10, 0),
                    sliver: SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          _BloomArtHeroBanner(
                            isArtCreator: isArtCreator,
                            onSellPressed: () => _handleSellPressed(context),
                            onExplorePressed: () {
                              final targetContext =
                                  _gallerySectionKey.currentContext;
                              if (targetContext != null) {
                                Scrollable.ensureVisible(
                                  targetContext,
                                  duration: const Duration(milliseconds: 450),
                                  curve: Curves.easeOutCubic,
                                );
                              }
                            },
                          ),
                          const SizedBox(height: 18),
                          SizedBox(
                            height: 46,
                            child: ListView(
                              scrollDirection: Axis.horizontal,
                              physics: const BouncingScrollPhysics(),
                              children: <Widget>[
                                _BloomArtChip(
                                  label: isArtCreator
                                      ? 'PRIX PRIVE'
                                      : 'ŒUVRES UNIQUES',
                                ),
                                const SizedBox(width: 12),
                                _BloomArtChip(
                                  label: isArtCreator
                                      ? 'OFFRES NEGOCIEES'
                                      : 'FAITES UNE OFFRE',
                                ),
                                const SizedBox(width: 12),
                                _BloomArtChip(
                                  label: isArtCreator
                                      ? 'CHECKOUT STRIPE'
                                      : 'PAIEMENT EN PLUSIEURS FOIS',
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 26),
                          Row(
                            key: _gallerySectionKey,
                            children: <Widget>[
                              const Text(
                                'PIECES DISPONIBLES',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.4,
                                  color: _Ui.textMain,
                                  height: 1,
                                ),
                              ),
                              const Spacer(),
                              if (isArtCreator)
                                GestureDetector(
                                  onTap: () => _handleSellPressed(context),
                                  child: const Text(
                                    'Vendre',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: _Ui.textMuted,
                                      height: 1,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
                  if (snapshot.connectionState == ConnectionState.waiting)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  else if (snapshot.hasError)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'Impossible de charger la galerie.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: _Ui.textMuted),
                          ),
                        ),
                      ),
                    )
                  else if (items.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            isArtCreator
                                ? 'Aucune pièce n’est encore publiée.\nDéposez la première création.'
                                : 'Aucune œuvre n’est disponible pour le moment.\nRevenez bientôt pour découvrir de nouvelles créations.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: _Ui.textMuted,
                              height: 1.45,
                            ),
                          ),
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(10, 0, 10, 28),
                      sliver: SliverGrid.builder(
                        gridDelegate:
                            SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          crossAxisSpacing: 14,
                          mainAxisSpacing: 14,
                          childAspectRatio:
                              crossAxisCount >= 2 ? 0.52 : 0.74,
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

class _BloomArtHeroBanner extends StatelessWidget {
  const _BloomArtHeroBanner({
    required this.isArtCreator,
    required this.onSellPressed,
    required this.onExplorePressed,
  });

  final bool isArtCreator;
  final VoidCallback onSellPressed;
  final VoidCallback onExplorePressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(2),
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: _Ui.rainbowGradient,
        borderRadius: BorderRadius.circular(30),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Container(
              color: Colors.white,
              height: 216,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              child: Image.asset(
                'assets/images/logobloom.webp',
                fit: BoxFit.contain,
                height: 200,
              ),
            ),
            Container(
              color: _Ui.textMain,
              padding: const EdgeInsets.fromLTRB(10, 14, 10, 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  Expanded(
                    child: Text(
                      isArtCreator
                          ? 'Exposez une création, recevez des offres'
                          : 'Achetez une œuvre, faites une offre et réglez en plusieurs fois',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed:
                        isArtCreator ? onSellPressed : onExplorePressed,
                    icon: Icon(
                      isArtCreator
                          ? Icons.add_circle_outline
                          : Icons.collections_outlined,
                      size: 18,
                    ),
                    label: Text(isArtCreator ? 'Déposer' : 'Découvrir'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: _Ui.textMain,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
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

class _BloomArtChip extends StatelessWidget {
  const _BloomArtChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: _Ui.textMain,
        borderRadius: BorderRadius.circular(24),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: Colors.white,
          letterSpacing: 0.3,
          height: 1,
        ),
      ),
    );
  }
}
