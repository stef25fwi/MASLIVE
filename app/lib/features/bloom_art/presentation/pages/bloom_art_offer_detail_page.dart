import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../data/models/bloom_art_item.dart';
import '../../data/models/bloom_art_offer.dart';
import '../../data/repositories/bloom_art_offer_repository.dart';
import '../../data/repositories/bloom_art_repository.dart';
import '../../services/bloom_art_checkout_service.dart';
import '../../services/bloom_art_notification_service.dart';
import '../widgets/bloom_art_cta_button.dart';
import '../widgets/bloom_art_offer_status_badge.dart';

class BloomArtOfferDetailPage extends StatefulWidget {
  const BloomArtOfferDetailPage({
    super.key,
    required this.offerId,
  });

  final String offerId;

  @override
  State<BloomArtOfferDetailPage> createState() => _BloomArtOfferDetailPageState();
}

class _BloomArtOfferDetailPageState extends State<BloomArtOfferDetailPage> {
  final BloomArtOfferRepository _offerRepository = BloomArtOfferRepository();
  final BloomArtRepository _repository = BloomArtRepository();
  final BloomArtCheckoutService _checkoutService = BloomArtCheckoutService();
  final BloomArtNotificationService _notificationService =
      const BloomArtNotificationService();

  bool _busy = false;

  Future<void> _acceptOffer(BloomArtOffer offer) async {
    setState(() {
      _busy = true;
    });
    try {
      await _offerRepository.acceptOffer(offer.id);
      await _notificationService.notifyBuyerOfferAccepted(
        buyerId: offer.buyerId,
        offerId: offer.id,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Offre acceptee.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossible d\'accepter l\'offre : $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _declineOffer(BloomArtOffer offer) async {
    setState(() {
      _busy = true;
    });
    try {
      await _offerRepository.declineOffer(offer.id);
      await _notificationService.notifyBuyerOfferDeclined(
        buyerId: offer.buyerId,
        offerId: offer.id,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Offre refusee.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossible de refuser l\'offre : $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _startCheckout(BloomArtOffer offer) async {
    setState(() {
      _busy = true;
    });
    try {
      await _checkoutService.startCheckout(
        context,
        offerId: offer.id,
        itemId: offer.itemId,
      );
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
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
          'Detail de l\'offre',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: StreamBuilder<BloomArtOffer?>(
        stream: _offerRepository.watchOffer(widget.offerId),
        builder: (context, offerSnapshot) {
          if (offerSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final offer = offerSnapshot.data;
          if (offer == null) {
            return const Center(child: Text('Offre introuvable.'));
          }

          final isSeller = currentUser.uid == offer.sellerId;
          final isBuyer = currentUser.uid == offer.buyerId;

          return StreamBuilder<BloomArtItem?>(
            stream: _repository.watchItem(offer.itemId),
            builder: (context, itemSnapshot) {
              final item = itemSnapshot.data;
              return ListView(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 28),
                children: <Widget>[
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
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                item?.title ?? 'Offre Bloom Art',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            BloomArtOfferStatusBadge(status: offer.status),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Text(
                          '${offer.proposedPrice.toStringAsFixed(2)} EUR',
                          style: const TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (offer.buyerMessage.trim().isNotEmpty)
                          Text(
                            offer.buyerMessage,
                            style: const TextStyle(
                              color: Color(0xFF6A645E),
                              height: 1.45,
                            ),
                          )
                        else
                          const Text(
                            'Aucun message ajoute a cette offre.',
                            style: TextStyle(color: Color(0xFF6A645E)),
                          ),
                        const SizedBox(height: 18),
                        _MetaLine(
                          label: 'Acheteur',
                          value: offer.buyerId,
                        ),
                        _MetaLine(
                          label: 'Vendeur',
                          value: offer.sellerId,
                        ),
                        _MetaLine(
                          label: 'Article',
                          value: offer.itemId,
                        ),
                        _MetaLine(
                          label: 'Prix prive snapshot',
                          value: '${offer.referencePriceSnapshot.toStringAsFixed(2)} EUR',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  _ActionPanel(
                    offer: offer,
                    isSeller: isSeller,
                    isBuyer: isBuyer,
                    busy: _busy,
                    onAccept: () => _acceptOffer(offer),
                    onDecline: () => _declineOffer(offer),
                    onCheckout: () => _startCheckout(offer),
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

class _ActionPanel extends StatelessWidget {
  const _ActionPanel({
    required this.offer,
    required this.isSeller,
    required this.isBuyer,
    required this.busy,
    required this.onAccept,
    required this.onDecline,
    required this.onCheckout,
  });

  final BloomArtOffer offer;
  final bool isSeller;
  final bool isBuyer;
  final bool busy;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final VoidCallback onCheckout;

  @override
  Widget build(BuildContext context) {
    String subtitle;
    if (isSeller && offer.isPending) {
      subtitle =
          'Vous pouvez accepter ou refuser cette offre. Une offre acceptee deviendra eligible au checkout Stripe centralise.';
    } else if (isBuyer && offer.checkoutEligible && offer.isAccepted) {
      subtitle =
          'Votre offre a ete acceptee. Vous pouvez maintenant ouvrir le paiement.';
    } else if (offer.isPaid) {
      subtitle = 'Le paiement est confirme pour cette offre.';
    } else {
      subtitle = 'Suivez ici l\'evolution de la negociation Bloom Art.';
    }

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFE9DED1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'Actions',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: const TextStyle(color: Color(0xFF6A645E), height: 1.45),
          ),
          const SizedBox(height: 18),
          if (isSeller && offer.isPending) ...<Widget>[
            BloomArtCtaButton(
              label: busy ? 'Acceptation...' : 'Accepter l\'offre',
              icon: Icons.check_circle_outline,
              onPressed: busy ? null : onAccept,
            ),
            const SizedBox(height: 12),
            BloomArtCtaButton(
              label: busy ? 'Refus...' : 'Refuser l\'offre',
              icon: Icons.block_outlined,
              onPressed: busy ? null : onDecline,
            ),
          ] else if (isBuyer && offer.checkoutEligible && offer.isAccepted) ...<Widget>[
            BloomArtCtaButton(
              label: busy ? 'Ouverture du paiement...' : 'Ouvrir Stripe Checkout',
              icon: Icons.credit_card_outlined,
              onPressed: busy ? null : onCheckout,
            ),
          ] else if (offer.status == 'checkout_started') ...<Widget>[
            const Text(
              'Le checkout a deja ete lance pour cette offre.',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ] else if (offer.status == 'declined') ...<Widget>[
            const Text(
              'Cette offre a ete refusee.',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ] else if (offer.status == 'paid') ...<Widget>[
            const Text(
              'Paiement confirme. La commande Bloom Art est enregistre.',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ],
      ),
    );
  }
}

class _MetaLine extends StatelessWidget {
  const _MetaLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 142,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF7D7067),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}