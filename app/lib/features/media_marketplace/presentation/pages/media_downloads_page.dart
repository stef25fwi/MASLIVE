import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/models/media_entitlement_model.dart';
import '../controllers/media_download_controller.dart';
import '../widgets/media_marketplace_back_to_catalog_button.dart';
import '../widgets/media_marketplace_context_chips.dart';
import '../widgets/media_marketplace_message_card.dart';
import '../widgets/media_marketplace_section_header.dart';

class MediaDownloadsPage extends StatelessWidget {
  const MediaDownloadsPage({
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
    return ChangeNotifierProvider<MediaDownloadController>(
      create: (_) {
        final controller = MediaDownloadController();
        Future<void>.microtask(controller.loadCurrentUserEntitlements);
        return controller;
      },
      child: _MediaDownloadsView(
        eventId: eventId,
        eventName: eventName,
        circuitName: circuitName,
        showContextHeader: showContextHeader,
        embedded: embedded,
      ),
    );
  }
}

class _MediaDownloadsView extends StatelessWidget {
  const _MediaDownloadsView({
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
    final controller = context.watch<MediaDownloadController>();

    final content = controller.loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(0, 16, 0, 24),
              children: <Widget>[
                if (controller.error != null)
                  MediaMarketplaceMessageCard.error(controller.error!),
                if (showContextHeader && eventId?.trim().isNotEmpty == true) ...<Widget>[
                  MediaMarketplaceSectionHeader(
                    title: eventName?.trim().isNotEmpty == true
                        ? eventName!.trim()
                        : 'Contexte d\'ouverture',
                    subtitle: 'Téléchargements ouverts depuis la carte active.',
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
                if (controller.entitlements.isEmpty)
                  MediaMarketplaceMessageCard.empty(
                    title: 'Aucun téléchargement',
                    message: 'Les achats validés apparaissent ici avec leurs liens sécurisés.',
                    icon: Icons.download_outlined,
                  )
                else ...<Widget>[
                  const MediaMarketplaceSectionHeader(
                    title: 'Mes droits d acces',
                    subtitle: 'Chaque média est téléchargé via une URL signée.',
                  ),
                  const SizedBox(height: 12),
                  for (final MediaEntitlementModel entitlement
                      in controller.entitlements)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(entitlement.assetId),
                            const SizedBox(height: 8),
                            Text(
                              '${entitlement.assetType.name} • ${entitlement.downloadCount} téléchargements',
                            ),
                            const SizedBox(height: 12),
                            if (entitlement.assetType.name == 'photo')
                              FilledButton.icon(
                                onPressed: () async {
                                  final url = await controller.createDownloadUrl(
                                    entitlementId: entitlement.entitlementId,
                                    assetId: entitlement.assetId,
                                  );
                                  if (url == null) return;
                                  await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                                },
                                icon: const Icon(Icons.download_outlined),
                                label: const Text('Télécharger'),
                              )
                            else
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: entitlement.photoIds
                                    .map(
                                      (String photoId) => OutlinedButton(
                                        onPressed: () async {
                                          final url = await controller.createDownloadUrl(
                                            entitlementId: entitlement.entitlementId,
                                            assetId: entitlement.assetId,
                                            photoId: photoId,
                                          );
                                          if (url == null) return;
                                          await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                                        },
                                        child: Text(photoId),
                                      ),
                                    )
                                    .toList(growable: false),
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
      appBar: AppBar(title: const Text('Mes téléchargements')),
      body: content,
    );
  }
}
