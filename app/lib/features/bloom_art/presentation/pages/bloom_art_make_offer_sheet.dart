import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../data/models/bloom_art_item.dart';
import '../../data/repositories/bloom_art_offer_repository.dart';
import '../../services/bloom_art_checkout_service.dart';
import '../../services/bloom_art_notification_service.dart';
import '../widgets/bloom_art_cta_button.dart';

Future<void> showBloomArtMakeOfferSheet(
  BuildContext context, {
  required BloomArtItem item,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => BloomArtMakeOfferSheet(
      rootContext: context,
      item: item,
    ),
  );
}

class BloomArtMakeOfferSheet extends StatefulWidget {
  const BloomArtMakeOfferSheet({
    super.key,
    required this.rootContext,
    required this.item,
  });

  final BuildContext rootContext;
  final BloomArtItem item;

  @override
  State<BloomArtMakeOfferSheet> createState() => _BloomArtMakeOfferSheetState();
}

class _BloomArtMakeOfferSheetState extends State<BloomArtMakeOfferSheet> {
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  final BloomArtOfferRepository _offerRepository = BloomArtOfferRepository();
  final BloomArtCheckoutService _checkoutService = BloomArtCheckoutService();
  final BloomArtNotificationService _notificationService =
      const BloomArtNotificationService();

  bool _submitting = false;

  @override
  void dispose() {
    _priceController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final rootContext = widget.rootContext;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        Navigator.of(context).pop();
      }
      if (widget.rootContext.mounted) {
        Navigator.of(widget.rootContext).pushNamed('/login');
      }
      return;
    }

    final proposedPrice = double.tryParse(
      _priceController.text.trim().replaceAll(',', '.'),
    );
    if (proposedPrice == null || proposedPrice <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saisissez un montant valide.')),
      );
      return;
    }

    setState(() {
      _submitting = true;
    });

    try {
      final offer = await _offerRepository.submitOffer(
        itemId: widget.item.id,
        proposedPrice: proposedPrice,
        buyerMessage: _messageController.text.trim(),
      );

      await _notificationService.notifySellerOfferReceived(
        sellerId: widget.item.sellerId,
        itemId: widget.item.id,
        offerId: offer.id,
      );

      if (!mounted) return;
      Navigator.of(context).pop();

      if (!rootContext.mounted) return;

      if (offer.checkoutEligible) {
        final payNow = await showDialog<bool>(
          context: rootContext,
          builder: (dialogContext) {
            return AlertDialog(
              title: const Text('Offre auto-acceptée'),
              content: const Text(
                'Votre offre atteint le seuil d’acceptation automatique. Voulez-vous ouvrir Stripe Checkout maintenant ?',
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Plus tard'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: const Text('Payer maintenant'),
                ),
              ],
            );
          },
        );

        if (payNow == true && rootContext.mounted) {
          await _notificationService.notifyBuyerOfferAutoAccepted(
            buyerId: user.uid,
            offerId: offer.id,
          );
          await _checkoutService.startCheckout(
            offerId: offer.id,
            itemId: widget.item.id,
          );
          if (!rootContext.mounted) return;
          ScaffoldMessenger.of(rootContext).showSnackBar(
            const SnackBar(
              content: Text('Checkout Bloom Art ouvert dans Stripe'),
            ),
          );
        }
        return;
      }

      ScaffoldMessenger.of(rootContext).showSnackBar(
        const SnackBar(
          content: Text('Offre envoyée. Le vendeur doit maintenant répondre.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossible d’envoyer l’offre : $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFFFFFBF7),
          borderRadius: BorderRadius.vertical(top: Radius.circular(34)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
        child: SingleChildScrollView(
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
              Text(
                'Proposer un prix pour ${widget.item.title}',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Le prix de référence reste privé. Saisissez votre meilleure proposition et un message pour le vendeur.',
                style: TextStyle(
                  color: Color(0xFF6A645E),
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 18),
              TextField(
                controller: _priceController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Prix proposé (€)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _messageController,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Message au vendeur',
                  hintText: 'Expliquez votre intention, le contexte ou vos attentes.',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 18),
              BloomArtCtaButton(
                label: _submitting ? 'Envoi en cours...' : 'Envoyer mon offre',
                icon: Icons.local_offer_outlined,
                onPressed: _submitting ? null : _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
