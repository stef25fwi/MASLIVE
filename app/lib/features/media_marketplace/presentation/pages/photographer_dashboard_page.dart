import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../services/auth_service.dart';
import '../../data/models/media_gallery_model.dart';
import '../../data/models/media_order_model.dart';
import '../../data/models/photographer_profile_model.dart';
import '../controllers/photographer_dashboard_controller.dart';
import '../widgets/media_marketplace_back_to_catalog_button.dart';
import '../widgets/media_gallery_card.dart';
import '../widgets/media_marketplace_context_chips.dart';
import '../widgets/media_marketplace_message_card.dart';
import '../widgets/media_marketplace_metric_card.dart';
import '../widgets/media_marketplace_section_header.dart';
import '../widgets/media_marketplace_shell.dart';
import '../../../../ui/theme/maslive_theme.dart';

class PhotographerDashboardPage extends StatelessWidget {
  const PhotographerDashboardPage({
    super.key,
    this.ownerUid,
    this.eventId,
    this.eventName,
    this.circuitName,
    this.showContextHeader = true,
    this.embedded = false,
  });

  final String? ownerUid;
  final String? eventId;
  final String? eventName;
  final String? circuitName;
  final bool showContextHeader;
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<PhotographerDashboardController>(
      create: (_) {
        final controller = PhotographerDashboardController();
        Future<void>.microtask(() async {
          final resolvedOwnerUid = ownerUid ?? AuthService.instance.currentUser?.uid;
          if (resolvedOwnerUid == null || resolvedOwnerUid.isEmpty) {
            return;
          }
          await controller.loadForOwnerUid(resolvedOwnerUid);
        });
        return controller;
      },
      child: _PhotographerDashboardView(
        embedded: embedded,
        eventId: eventId,
        eventName: eventName,
        circuitName: circuitName,
        showContextHeader: showContextHeader,
      ),
    );
  }
}

class _PhotographerDashboardView extends StatelessWidget {
  const _PhotographerDashboardView({
    required this.embedded,
    required this.eventId,
    required this.eventName,
    required this.circuitName,
    required this.showContextHeader,
  });

  final bool embedded;
  final String? eventId;
  final String? eventName;
  final String? circuitName;
  final bool showContextHeader;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<PhotographerDashboardController>();
    final PhotographerProfileModel? profile = controller.profile;

    final content = controller.loading && profile == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(8, 16, 8, 24),
              children: <Widget>[
                if (controller.error != null)
                  MediaMarketplaceMessageCard.error(controller.error!),
                if (profile == null)
                  MediaMarketplaceMessageCard.empty(
                    title: 'Profil photographe introuvable',
                    message: 'Aucun profil photographe n\'est rattaché à cet utilisateur.',
                    icon: Icons.camera_alt_outlined,
                  )
                else ...<Widget>[
                  if (showContextHeader && eventId?.trim().isNotEmpty == true) ...<Widget>[
                    MediaMarketplaceSectionHeader(
                      title: eventName?.trim().isNotEmpty == true
                          ? eventName!.trim()
                          : 'Contexte d\'ouverture',
                      subtitle: 'Espace photographe ouvert depuis la carte active.',
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
                  _ProfileHeader(profile: profile),
                  const SizedBox(height: 16),
                  _StatsGrid(controller: controller),
                  const SizedBox(height: 16),
                  const MediaMarketplaceSectionHeader(
                    title: 'Galeries',
                    subtitle: 'Sélectionne une galerie pour voir ses volumes.',
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: controller.galleries
                        .map(
                          (MediaGalleryModel gallery) => MediaGalleryCard(
                            gallery: gallery,
                            width: 280,
                            selected:
                                controller.selectedGalleryId == gallery.galleryId,
                            trailing: Icon(
                              Icons.chevron_right,
                              color: controller.selectedGalleryId == gallery.galleryId
                                  ? Colors.white
                                  : null,
                            ),
                            onTap: () => controller.selectGallery(gallery.galleryId),
                          ),
                        )
                        .toList(growable: false),
                  ),
                  if (controller.selectedGalleryId != null) ...<Widget>[
                    const SizedBox(height: 24),
                    const MediaMarketplaceSectionHeader(
                      title: 'Galerie sélectionnée',
                      subtitle: 'Résumé rapide du contenu courant.',
                    ),
                    const SizedBox(height: 12),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text('Photos: ${controller.selectedGalleryPhotos.length}'),
                            const SizedBox(height: 8),
                            Text('Packs: ${controller.selectedGalleryPacks.length}'),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  const MediaMarketplaceSectionHeader(
                    title: 'Dernieres commandes',
                    subtitle: '10 commandes les plus recentes pour ce photographe.',
                  ),
                  const SizedBox(height: 12),
                  for (final MediaOrderModel order in controller.recentOrders.take(10))
                    Card(
                      child: ListTile(
                        title: Text(order.orderId),
                        subtitle: Text(
                          '${order.items.length} lignes • ${order.total.toStringAsFixed(2)} ${order.currency}',
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
      backgroundColor: MasliveTheme.surfaceAlt,
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: MasliveTheme.backgroundWash),
        child: SafeArea(
          child: Stack(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.only(left: 84),
                child: Column(
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 16, 8, 12),
                      child: MediaMarketplaceBrandHeader(
                        subtitle: 'ESPACE PHOTOGRAPHE',
                        onBack: () => Navigator.of(context).pop(),
                        trailing: IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: controller.refresh,
                          icon: const Icon(Icons.refresh, size: 20),
                        ),
                      ),
                    ),
                    Expanded(child: content),
                  ],
                ),
              ),
              MediaMarketplaceVerticalNav(
                selected: MediaMarketplaceNavSection.photographer,
                onOpenCatalog: () => Navigator.pushReplacementNamed(
                  context,
                  '/media-marketplace',
                  arguments: <String, dynamic>{'initialTab': 0},
                ),
                onOpenPhotographer: () {},
                onOpenCart: () => Navigator.pushReplacementNamed(
                  context,
                  '/media-marketplace',
                  arguments: <String, dynamic>{'initialTab': 1},
                ),
                onOpenDownloads: () => Navigator.pushReplacementNamed(
                  context,
                  '/media-marketplace',
                  arguments: <String, dynamic>{'initialTab': 2},
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.profile});

  final PhotographerProfileModel profile;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(profile.brandName, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(profile.email ?? 'Sans email'),
            if (profile.bio != null && profile.bio!.isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              Text(profile.bio!),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.controller});

  final PhotographerDashboardController controller;

  @override
  Widget build(BuildContext context) {
    final profile = controller.profile!;
    final stats = <MapEntry<String, String>>[
      MapEntry<String, String>('Photos publiees', '${profile.publishedPhotoCount}'),
      MapEntry<String, String>('Galeries actives', '${profile.activeGalleryCount}'),
      MapEntry<String, String>('Packs actifs', '${profile.activePackCount}'),
      MapEntry<String, String>('Ventes', '${profile.salesCount}'),
      MapEntry<String, String>('CA brut', profile.totalRevenueGross.toStringAsFixed(2)),
      MapEntry<String, String>('CA net', profile.totalRevenueNet.toStringAsFixed(2)),
    ];

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: stats
          .map(
            (entry) => SizedBox(
              width: 200,
              child: MediaMarketplaceMetricCard(
                label: entry.key,
                value: entry.value,
              ),
            ),
          )
          .toList(growable: false),
    );
  }
}
