import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../controllers/media_cart_controller.dart';
import '../widgets/media_marketplace_back_to_catalog_button.dart';
import '../widgets/media_marketplace_context_chips.dart';
import '../widgets/media_marketplace_message_card.dart';
import '../widgets/media_marketplace_section_header.dart';

class MediaCartPage extends StatelessWidget {
  const MediaCartPage({
    super.key,
    this.eventId,
    this.eventName,
    this.circuitName,
    this.showContextHeader = true,
    this.embedded = false,
  });

  final String? eventId;
  final String? eventName;
  final String? circuitName;
  final bool showContextHeader;
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<MediaCartController>(
      create: (_) {
        final controller = MediaCartController();
        Future<void>.microtask(controller.loadCurrentUserCart);
        return controller;
      },
      child: _MediaCartView(
        eventId: eventId,
        eventName: eventName,
        circuitName: circuitName,
        showContextHeader: showContextHeader,
        embedded: embedded,
      ),
    );
  }
}

class _MediaCartView extends StatelessWidget {
  const _MediaCartView({
    required this.eventId,
    required this.eventName,
    required this.circuitName,
    required this.showContextHeader,
    required this.embedded,
  });

  final String? eventId;
  final String? eventName;
  final String? circuitName;
  final bool showContextHeader;
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<MediaCartController>();
    final cart = controller.cart;
    final pricing = controller.pricingPreview;

    final content = cart == null && controller.loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: <Widget>[
                if (controller.error != null)
                  MediaMarketplaceMessageCard.error(controller.error!),
                if (showContextHeader && eventId?.trim().isNotEmpty == true) ...<Widget>[
                  MediaMarketplaceSectionHeader(
                    title: eventName?.trim().isNotEmpty == true
                        ? eventName!.trim()
                        : 'Contexte d\'ouverture',
                    subtitle: 'Panier ouvert depuis la carte active.',
                  ),
                  const SizedBox(height: 12),
                  MediaMarketplaceContextChips(
                    eventId: eventId!.trim(),
                    circuitName: circuitName,
                  ),
                  const SizedBox(height: 12),
                  const MediaMarketplaceBackToCatalogButton(),
                  const SizedBox(height: 16),
                ],
                if (cart == null || cart.items.isEmpty)
                  MediaMarketplaceMessageCard.empty(
                    title: 'Panier vide',
                    message: 'Ajoute des photos ou des packs pour lancer le paiement.',
                    icon: Icons.shopping_cart_outlined,
                  )
                else ...<Widget>[
                  const MediaMarketplaceSectionHeader(
                    title: 'Articles du panier',
                    subtitle: 'Vérifie les contenus avant le paiement.',
                  ),
                  const SizedBox(height: 12),
                  for (final item in cart.items)
                    Card(
                      child: ListTile(
                        title: Text(item.title),
                        subtitle: Text(
                          '${item.quantity} x ${item.unitPrice.toStringAsFixed(2)} ${item.currency}',
                        ),
                        trailing: IconButton(
                          onPressed: () => controller.removeItem(item.assetId),
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          const MediaMarketplaceSectionHeader(
                            title: 'Récapitulatif',
                            subtitle: 'Montants calculés avant redirection Stripe.',
                          ),
                          const SizedBox(height: 12),
                          Text('Sous-total: ${pricing['subtotal']}'),
                          Text('Frais Stripe: ${pricing['stripeFee']}'),
                          Text('Commission: ${pricing['platformFee']}'),
                          Text('Total: ${pricing['total']}'),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: controller.processingCheckout
                                ? null
                                : () async {
                                    final url = await controller.checkout();
                                    if (url == null) return;
                                    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                                  },
                            icon: const Icon(Icons.payment),
                            label: Text(
                              controller.processingCheckout
                                  ? 'Preparation...'
                                  : 'Payer avec Stripe',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            );

    if (embedded) {
      return content;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Panier medias')),
      body: content,
    );
  }
}
