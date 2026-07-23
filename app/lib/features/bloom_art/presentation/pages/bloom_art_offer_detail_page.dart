import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../services/checkout/unified_checkout_service.dart';
import '../../data/models/bloom_art_item.dart';
import '../../data/models/bloom_art_offer.dart';
import '../../data/repositories/bloom_art_offer_repository.dart';
import '../../data/repositories/bloom_art_repository.dart';
import '../widgets/bloom_art_cta_button.dart';
import '../widgets/bloom_art_offer_status_badge.dart';
import 'package:masslive/ui_kit/tokens/maslive_tokens.dart';
import '../../../../ui_kit/responsive/responsive.dart';

class BloomArtOfferDetailPage extends StatefulWidget {
  const BloomArtOfferDetailPage({super.key, required this.offerId});

  final String offerId;

  @override
  State<BloomArtOfferDetailPage> createState() =>
      _BloomArtOfferDetailPageState();
}

class _BloomArtOfferDetailPageState extends State<BloomArtOfferDetailPage> {
  final BloomArtOfferRepository _offerRepository = BloomArtOfferRepository();
  final BloomArtRepository _itemRepository = BloomArtRepository();
  bool _busy = false;

  Future<bool> _confirm({
    required String title,
    required String message,
    required String action,
    bool destructive = false,
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Annuler'),
              ),
              FilledButton(
                style: destructive
                    ? FilledButton.styleFrom(backgroundColor: Colors.red)
                    : null,
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(action),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _acceptOffer(BloomArtOffer offer) async {
    final fee = offer.proposedPrice * .10;
    final net = offer.proposedPrice - fee;
    final confirmed = await _confirm(
      title: 'Accepter cette offre ?',
      message:
          'Montant proposé : ${offer.proposedPrice.toStringAsFixed(2)} €\n'
          'Commission MASLIVE estimée : ${fee.toStringAsFixed(2)} €\n'
          'Revenu net estimé : ${net.toStringAsFixed(2)} €\n\n'
          'L’œuvre sera réservée pendant 48 heures pour permettre le paiement.',
      action: 'Accepter et réserver',
    );
    if (!confirmed || !mounted) return;

    setState(() => _busy = true);
    try {
      await _offerRepository.acceptOffer(offer.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Offre acceptée. L’acheteur dispose de 48 heures pour payer.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossible d’accepter l’offre : $error')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _declineOffer(BloomArtOffer offer) async {
    final confirmed = await _confirm(
      title: 'Refuser cette offre ?',
      message:
          'La proposition de ${offer.proposedPrice.toStringAsFixed(2)} € sera définitivement refusée.',
      action: 'Refuser',
      destructive: true,
    );
    if (!confirmed || !mounted) return;

    setState(() => _busy = true);
    try {
      await _offerRepository.declineOffer(offer.id);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Offre refusée.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossible de refuser l’offre : $error')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _startCheckout(BloomArtOffer offer) async {
    setState(() => _busy = true);
    try {
      await UnifiedCheckoutService.startBloomArtCheckout(
        offerId: offer.id,
        itemId: offer.itemId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Paiement sécurisé ouvert dans Stripe.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossible d’ouvrir le paiement : $error')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          Navigator.of(context).pushReplacementNamed('/login');
        }
      });
      return const Scaffold(body: SizedBox.shrink());
    }

    return Scaffold(
      backgroundColor: MasliveTokens.surface,
      appBar: AppBar(
        backgroundColor: MasliveTokens.surface,
        elevation: 0,
        title: const Text(
          'Détail de l’offre',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: StreamBuilder<BloomArtOffer?>(
        stream: _offerRepository.watchOffer(widget.offerId),
        builder: (context, offerSnapshot) {
          if (offerSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (offerSnapshot.hasError) {
            return Center(
              child: Text(
                'Impossible de charger l’offre : ${offerSnapshot.error}',
              ),
            );
          }

          final offer = offerSnapshot.data;
          if (offer == null) {
            return const Center(child: Text('Offre introuvable.'));
          }

          return StreamBuilder<BloomArtItem?>(
            stream: _itemRepository.watchItem(offer.itemId),
            builder: (context, itemSnapshot) {
              final item = itemSnapshot.data;
              return ResponsivePageContainer(
                maxContentWidth: 1120,
                compactPadding: EdgeInsets.zero,
                mediumPadding: EdgeInsets.zero,
                expandedPadding: EdgeInsets.zero,
                widePadding: EdgeInsets.zero,
                child: ListView(
                  padding: responsiveValue<EdgeInsets>(
                    context,
                    compact: const EdgeInsets.fromLTRB(12, 16, 12, 28),
                    medium: const EdgeInsets.fromLTRB(24, 20, 24, 32),
                    expanded: const EdgeInsets.fromLTRB(36, 24, 36, 36),
                    wide: const EdgeInsets.fromLTRB(44, 28, 44, 40),
                  ),
                  children: <Widget>[
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final summary = _OfferSummaryCard(
                          offer: offer,
                          item: item,
                        );
                        final actions = _ActionPanel(
                          offer: offer,
                          isSeller: currentUser.uid == offer.sellerId,
                          isBuyer: currentUser.uid == offer.buyerId,
                          busy: _busy,
                          onAccept: () => _acceptOffer(offer),
                          onDecline: () => _declineOffer(offer),
                          onCheckout: () => _startCheckout(offer),
                        );
                        if (context.isCompactLayout) {
                          return Column(
                            children: <Widget>[
                              summary,
                              const SizedBox(height: 18),
                              actions,
                            ],
                          );
                        }
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Expanded(flex: 3, child: summary),
                            const SizedBox(width: 20),
                            Expanded(flex: 2, child: actions),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _OfferSummaryCard extends StatelessWidget {
  const _OfferSummaryCard({required this.offer, required this.item});

  final BloomArtOffer offer;
  final BloomArtItem? item;

  @override
  Widget build(BuildContext context) {
    final referenceLength = offer.id.length < 8 ? offer.id.length : 8;
    final shortReference = offer.id.substring(0, referenceLength).toUpperCase();

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: MasliveTokens.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              if (item?.images.isNotEmpty == true) ...<Widget>[
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.network(
                    item!.images.first,
                    width: 64,
                    height: 64,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 12),
              ],
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
            NumberFormat.currency(
              locale: 'fr_FR',
              symbol: '€',
            ).format(offer.proposedPrice),
            style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          Text(
            offer.buyerMessage.trim().isEmpty
                ? 'Aucun message ajouté à cette offre.'
                : offer.buyerMessage,
            style: const TextStyle(
              color: MasliveTokens.textMuted,
              height: 1.45,
            ),
          ),
          if (offer.paymentDeadlineAt != null)
            _MetaLine(
              label: 'Paiement avant',
              value: DateFormat(
                'dd/MM/yyyy à HH:mm',
                'fr_FR',
              ).format(offer.paymentDeadlineAt!.toLocal()),
            ),
          if (item?.sellerDisplayName.trim().isNotEmpty == true)
            _MetaLine(label: 'Artiste', value: item!.sellerDisplayName),
          _MetaLine(label: 'Référence', value: shortReference),
        ],
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
    final deadlineExpired =
        offer.paymentDeadlineAt != null &&
        offer.paymentDeadlineAt!.isBefore(DateTime.now());

    final subtitle = switch (offer.status) {
      'paid' => 'Le paiement est confirmé. La vente est finalisée.',
      'declined' => 'Cette offre a été refusée.',
      'expired' => 'Cette offre a expiré et l’œuvre a été remise en vente.',
      'cancelled' => 'Cette réservation a été annulée.',
      'checkout_started' =>
        'Le paiement a été ouvert. Il doit être finalisé avant l’échéance.',
      _ when isSeller && offer.isPending =>
        'Acceptez ou refusez la proposition. Une acceptation réserve l’œuvre pendant 48 heures.',
      _ when isBuyer && offer.checkoutEligible && offer.isAccepted =>
        deadlineExpired
            ? 'Le délai de paiement est expiré.'
            : 'Votre offre est acceptée. Finalisez le paiement sécurisé.',
      _ => 'Suivez ici l’évolution de votre proposition Bloom Art.',
    };

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: MasliveTokens.line),
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
            style: const TextStyle(
              color: MasliveTokens.textMuted,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 18),
          if (isSeller && offer.isPending) ...<Widget>[
            BloomArtCtaButton(
              label: busy ? 'Acceptation…' : 'Accepter l’offre',
              icon: Icons.check_circle_outline,
              onPressed: busy ? null : onAccept,
            ),
            const SizedBox(height: 12),
            BloomArtCtaButton(
              label: busy ? 'Refus…' : 'Refuser l’offre',
              icon: Icons.block_outlined,
              onPressed: busy ? null : onDecline,
            ),
          ] else if (isBuyer &&
              offer.checkoutEligible &&
              offer.isAccepted &&
              !deadlineExpired) ...<Widget>[
            BloomArtCtaButton(
              label: busy ? 'Ouverture du paiement…' : 'Payer maintenant',
              icon: Icons.credit_card_outlined,
              onPressed: busy ? null : onCheckout,
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
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 118,
            child: Text(
              label,
              style: const TextStyle(
                color: MasliveTokens.textMuted,
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
