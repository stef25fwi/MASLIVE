import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/models/bloom_art_item.dart';
import '../../data/models/bloom_art_offer.dart';
import '../../data/models/bloom_art_seller_profile.dart';
import '../../data/repositories/bloom_art_offer_repository.dart';
import '../../data/repositories/bloom_art_repository.dart';
import '../widgets/bloom_art_cta_button.dart';
import '../widgets/bloom_art_item_card.dart';
import '../widgets/bloom_art_offer_status_badge.dart';
import 'package:masslive/ui_kit/tokens/maslive_tokens.dart';

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
      backgroundColor: MasliveTokens.surfaceEditorial,
      appBar: AppBar(
        backgroundColor: MasliveTokens.surfaceEditorial,
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
          final canSell = profile?.canSell == true;
          final isLaunchGuide = profile?.isLaunchGuide == true;

          return ListView(
            padding: const EdgeInsets.fromLTRB(10, 16, 10, 28),
            children: <Widget>[
              _DashboardHero(profile: profile),
              const SizedBox(height: 18),
              if (profile == null)
                _NoSellerProfileCard()
              else if (!canSell)
                _BlockedSellerCard(profile: profile, isLaunchGuide: isLaunchGuide)
              else
                BloomArtCtaButton(
                  label: 'Déposer une nouvelle création',
                  icon: Icons.add_photo_alternate_outlined,
                  onPressed: () => Navigator.of(context).pushNamed(
                    '/bloom-art/create',
                    arguments: <String, dynamic>{'profileType': profile.profileType},
                  ),
                ),
              if (canSell) ...<Widget>[
                const SizedBox(height: 18),
                _BloomArtStripeConnectCard(profile: profile!),
                const SizedBox(height: 24),
                const Text(
                  'Mes créations',
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
                            'Aucune création déposée pour le moment. Publiez votre première pièce Bloom Art.',
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
                  'Offres reçues',
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
                            'Aucune offre reçue pour le moment. Les visiteurs pourront proposer un prix depuis la fiche publique de vos pièces.',
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
        : 'Votre espace Bloom Art';
    final statusLabel = profile == null
        ? 'Profil vendeur non configuré'
        : profile!.canSell
            ? 'SIRET vérifié · Galerie active'
            : profile!.isLaunchGuide
                ? 'Guide création d’entreprise'
                : 'Vérification SIRET requise';

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
            statusLabel,
            style: const TextStyle(color: MasliveTokens.textEditorialMuted, height: 1.45),
          ),
          if (profile?.canSell == true) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              '${profile!.businessName} · ${profile!.siret} · ${profile!.city} ${profile!.postalCode}',
              style: const TextStyle(color: MasliveTokens.textEditorialMuted, height: 1.35),
            ),
          ],
        ],
      ),
    );
  }
}

class _NoSellerProfileCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: MasliveTokens.lineEditorial),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'Aucun profil vendeur configuré',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          const Text(
            'Choisissez votre parcours Bloom Art : artiste déjà déclaré avec SIRET, ou guide “Je me lance” si vous devez encore créer votre activité.',
            style: TextStyle(color: MasliveTokens.textEditorialMuted, height: 1.45),
          ),
          const SizedBox(height: 14),
          BloomArtCtaButton(
            label: 'Configurer mon profil vendeur',
            icon: Icons.storefront_outlined,
            onPressed: () => Navigator.of(context).pushNamed('/bloom-art/sell'),
          ),
        ],
      ),
    );
  }
}

class _BlockedSellerCard extends StatelessWidget {
  const _BlockedSellerCard({required this.profile, required this.isLaunchGuide});

  final BloomArtSellerProfile profile;
  final bool isLaunchGuide;

  @override
  Widget build(BuildContext context) {
    final title = isLaunchGuide
        ? 'Parcours création d’entreprise en cours'
        : 'Compte vendeur non vérifié';
    final message = isLaunchGuide
        ? 'Votre parcours est enregistré, mais la vente reste bloquée tant que vous n’avez pas obtenu puis vérifié votre SIRET.'
        : 'Vérifiez votre SIRET pour activer la galerie, déposer vos œuvres et recevoir des offres.';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: MasliveTokens.lineEditorial),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: const TextStyle(color: MasliveTokens.textEditorialMuted, height: 1.45),
          ),
          const SizedBox(height: 14),
          BloomArtCtaButton(
            label: 'Vérifier mon SIRET',
            icon: Icons.verified_user_outlined,
            onPressed: () => Navigator.of(context).pushNamed(
              '/bloom-art/sell',
              arguments: <String, dynamic>{'selectedType': 'artisan_art'},
            ),
          ),
        ],
      ),
    );
  }
}

class _BloomArtStripeConnectCard extends StatefulWidget {
  const _BloomArtStripeConnectCard({required this.profile});

  final BloomArtSellerProfile profile;

  @override
  State<_BloomArtStripeConnectCard> createState() => _BloomArtStripeConnectCardState();
}

class _BloomArtStripeConnectCardState extends State<_BloomArtStripeConnectCard> {
  bool _loading = false;
  String? _error;

  FirebaseFunctions get _functions => FirebaseFunctions.instanceFor(region: 'us-east1');

  Future<void> _startOrResumeOnboarding() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final callable = _functions.httpsCallable('createBloomArtConnectOnboardingLink');
      final res = await callable.call(<String, dynamic>{});
      final data = res.data;

      final url = (data is Map) ? data['url'] : null;
      if (url is! String || url.isEmpty) {
        throw Exception('URL Stripe invalide');
      }

      final uri = Uri.parse(url);
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok) {
        throw Exception('Impossible d\'ouvrir le navigateur');
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _refreshStatus() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final callable = _functions.httpsCallable('refreshBloomArtConnectStatus');
      await callable.call(<String, dynamic>{});
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasAccount = widget.profile.stripeAccountLinked;
    final payoutActive = widget.profile.payoutStatus == 'active';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: MasliveTokens.lineEditorial),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'Paiements (Stripe Connect Express)',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(
            !hasAccount
                ? 'Aucun compte Stripe lié : vos ventes ne sont pas reversées tant que ce compte n\'est pas configuré (commission plateforme 10%).'
                : payoutActive
                    ? 'Compte Stripe actif : vos ventes vous sont reversées automatiquement (90% du prix, commission plateforme 10%).'
                    : 'Compte Stripe créé mais incomplet : terminez la configuration pour être payé.',
            style: const TextStyle(color: MasliveTokens.textEditorialMuted, height: 1.4),
          ),
          if (_error != null) ...<Widget>[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              BloomArtCtaButton(
                label: hasAccount ? 'Reprendre la configuration' : 'Configurer Stripe',
                icon: Icons.account_balance_outlined,
                onPressed: _loading ? null : _startOrResumeOnboarding,
              ),
              if (hasAccount)
                OutlinedButton(
                  onPressed: _loading ? null : _refreshStatus,
                  child: const Text('Rafraîchir le statut'),
                ),
            ],
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
      onTap: () => Navigator.of(context).pushNamed('/bloom-art/offers/${offer.id}'),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: MasliveTokens.lineEditorial),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    'Offre sur ${offer.itemId}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
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
                color: MasliveTokens.text,
              ),
            ),
            if (offer.buyerMessage.trim().isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                offer.buyerMessage,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: MasliveTokens.textEditorialMuted, height: 1.4),
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
        border: Border.all(color: MasliveTokens.lineEditorial),
      ),
      child: Text(
        message,
        style: const TextStyle(color: MasliveTokens.textEditorialMuted, height: 1.45),
      ),
    );
  }
}
