import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../services/auth_service.dart';
import '../../../../ui/theme/maslive_theme.dart';
import '../../../../ui/widgets/maslive_button.dart';
import '../../core/constants/media_marketplace_pricing.dart';
import '../../data/models/media_gallery_model.dart';
import '../../data/models/media_order_model.dart';
import '../../data/models/photographer_profile_model.dart';
import '../controllers/photographer_dashboard_controller.dart';
import '../widgets/media_gallery_card.dart';
import '../widgets/media_marketplace_back_to_catalog_button.dart';
import '../widgets/media_marketplace_context_chips.dart';
import '../widgets/media_marketplace_message_card.dart';
import '../widgets/media_marketplace_metric_card.dart';
import '../widgets/media_marketplace_section_header.dart';
import '../widgets/media_marketplace_shell.dart';
import 'photographer_gallery_manager_page.dart';
import 'photographer_subscription_page.dart';

class PhotographerDashboardPage extends StatelessWidget {
  const PhotographerDashboardPage({
    super.key,
    this.ownerUid,
    this.eventId,
    this.eventName,
    this.circuitId,
    this.circuitName,
    this.showContextHeader = true,
    this.embedded = false,
  });

  final String? ownerUid;
  final String? eventId;
  final String? eventName;
  final String? circuitId;
  final String? circuitName;
  final bool showContextHeader;
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<PhotographerDashboardController>(
      create: (_) {
        final controller = PhotographerDashboardController();
        Future<void>.microtask(() async {
          final resolvedOwnerUid =
              ownerUid ?? AuthService.instance.currentUser?.uid;
          if (resolvedOwnerUid == null || resolvedOwnerUid.isEmpty) return;
          await controller.loadForOwnerUid(resolvedOwnerUid);
        });
        return controller;
      },
      child: _DashboardView(
        embedded: embedded,
        eventId: eventId,
        eventName: eventName,
        circuitId: circuitId,
        circuitName: circuitName,
        showContextHeader: showContextHeader,
      ),
    );
  }
}

class _DashboardView extends StatelessWidget {
  const _DashboardView({
    required this.embedded,
    required this.eventId,
    required this.eventName,
    required this.circuitId,
    required this.circuitName,
    required this.showContextHeader,
  });

  final bool embedded;
  final String? eventId;
  final String? eventName;
  final String? circuitId;
  final String? circuitName;
  final bool showContextHeader;

  Future<void> _openManager(BuildContext context) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => PhotographerGalleryManagerPage(
          initialEventId: eventId,
          initialEventName: eventName,
          initialCircuitId: circuitId,
          initialCircuitName: circuitName,
        ),
      ),
    );
    if (context.mounted) {
      await context.read<PhotographerDashboardController>().refresh();
    }
  }

  Future<void> _openSubscription(BuildContext context) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const PhotographerSubscriptionPage(),
      ),
    );
    if (context.mounted) {
      await context.read<PhotographerDashboardController>().refresh();
    }
  }

  void _openPublicShop(
    BuildContext context,
    PhotographerProfileModel profile,
  ) {
    Navigator.pushNamed(
      context,
      '/media-marketplace',
      arguments: <String, dynamic>{
        'initialTab': 0,
        'photographerId': profile.photographerId,
        if (eventId?.trim().isNotEmpty == true) 'eventId': eventId,
        if (eventName?.trim().isNotEmpty == true) 'eventName': eventName,
        if (circuitId?.trim().isNotEmpty == true) 'circuitId': circuitId,
        if (circuitName?.trim().isNotEmpty == true)
          'circuitName': circuitName,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<PhotographerDashboardController>();
    final profile = controller.profile;
    final content = controller.loading && profile == null
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: controller.refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              padding: const EdgeInsets.fromLTRB(10, 16, 10, 32),
              children: <Widget>[
                if (controller.error != null)
                  MediaMarketplaceMessageCard.error(controller.error!),
                if (profile == null)
                  MediaMarketplaceMessageCard.empty(
                    title: 'Profil photographe introuvable',
                    message:
                        'Aucun profil photographe n’est rattaché à cet utilisateur.',
                    icon: Icons.camera_alt_outlined,
                  )
                else ...<Widget>[
                  if (showContextHeader &&
                      eventId?.trim().isNotEmpty == true) ...<Widget>[
                    MediaMarketplaceSectionHeader(
                      title: eventName?.trim().isNotEmpty == true
                          ? eventName!.trim()
                          : 'Circuit sélectionné',
                      subtitle:
                          'La boutique publique affiche en priorité les photos liées à la carte choisie sur la Home.',
                    ),
                    const SizedBox(height: 10),
                    MediaMarketplaceContextChips(
                      eventId: eventId!.trim(),
                      circuitName: circuitName,
                    ),
                    const SizedBox(height: 10),
                    const MediaMarketplaceBackToCatalogButton(),
                    const SizedBox(height: 16),
                  ],
                  _ProfileHeader(profile: profile),
                  const SizedBox(height: 14),
                  _QuotaCard(
                    profile: profile,
                    onUpgrade: () => _openSubscription(context),
                  ),
                  const SizedBox(height: 14),
                  _QuickActions(
                    onCreateGallery: () => _openManager(context),
                    onAddPhotos: () => _openManager(context),
                    onSales: () => Navigator.pushNamed(
                      context,
                      '/media-marketplace',
                      arguments: const <String, dynamic>{'initialTab': 2},
                    ),
                    onPublicShop: () => _openPublicShop(context, profile),
                  ),
                  const SizedBox(height: 18),
                  _StatsGrid(controller: controller),
                  const SizedBox(height: 18),
                  _StripeConnectCard(
                    profile: profile,
                    onRefreshed: controller.refresh,
                  ),
                  const SizedBox(height: 22),
                  MediaMarketplaceSectionHeader(
                    title: 'Mes galeries',
                    subtitle:
                        'Galeries par circuit, miniatures, quotas et publication.',
                    trailing: TextButton.icon(
                      onPressed: () => _openManager(context),
                      icon: const Icon(Icons.tune_rounded),
                      label: const Text('Gérer'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (controller.galleries.isEmpty)
                    MediaMarketplaceMessageCard.empty(
                      title: 'Aucune galerie',
                      message:
                          'Crée une galerie, rattache-la à un circuit puis importe tes photos.',
                      icon: Icons.photo_library_outlined,
                    )
                  else
                    SizedBox(
                      height: 150,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: controller.galleries.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(width: 12),
                        itemBuilder: (context, index) {
                          final gallery = controller.galleries[index];
                          return MediaGalleryCard(
                            gallery: gallery,
                            width: 290,
                            selected: controller.selectedGalleryId ==
                                gallery.galleryId,
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () =>
                                controller.selectGallery(gallery.galleryId),
                          );
                        },
                      ),
                    ),
                  if (controller.selectedGalleryId != null) ...<Widget>[
                    const SizedBox(height: 16),
                    _SelectedGallerySummary(controller: controller),
                  ],
                  const SizedBox(height: 22),
                  const MediaMarketplaceSectionHeader(
                    title: 'Dernières ventes',
                    subtitle:
                        'Commandes récentes et revenus associés à la boutique.',
                  ),
                  const SizedBox(height: 10),
                  if (controller.recentOrders.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(18),
                        child: Text('Aucune vente pour le moment.'),
                      ),
                    )
                  else
                    for (final MediaOrderModel order
                        in controller.recentOrders.take(10))
                      Card(
                        child: ListTile(
                          leading: const Icon(Icons.receipt_long_outlined),
                          title: Text('${order.total.toStringAsFixed(2)} €'),
                          subtitle: Text(
                            '${order.items.length} ligne(s) • ${order.orderId}',
                          ),
                        ),
                      ),
                ],
              ],
            ),
          );

    if (embedded) return content;
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
                        subtitle: 'MA BOUTIQUE PHOTOS',
                        onBack: () => Navigator.of(context).pop(),
                        trailing: IconButton(
                          onPressed: controller.refresh,
                          icon: const Icon(Icons.refresh_rounded),
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
                  arguments: const <String, dynamic>{'initialTab': 0},
                ),
                onOpenPhotographer: () {},
                onOpenCart: () => Navigator.pushReplacementNamed(
                  context,
                  '/media-marketplace',
                  arguments: const <String, dynamic>{'initialTab': 1},
                ),
                onOpenDownloads: () => Navigator.pushReplacementNamed(
                  context,
                  '/media-marketplace',
                  arguments: const <String, dynamic>{'initialTab': 2},
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({
    required this.onCreateGallery,
    required this.onAddPhotos,
    required this.onSales,
    required this.onPublicShop,
  });

  final VoidCallback onCreateGallery;
  final VoidCallback onAddPhotos;
  final VoidCallback onSales;
  final VoidCallback onPublicShop;

  @override
  Widget build(BuildContext context) {
    final actions = <({IconData icon, String label, VoidCallback action})>[
      (
        icon: Icons.create_new_folder_outlined,
        label: 'Créer une galerie',
        action: onCreateGallery,
      ),
      (
        icon: Icons.add_photo_alternate_outlined,
        label: 'Ajouter des photos',
        action: onAddPhotos,
      ),
      (
        icon: Icons.payments_outlined,
        label: 'Gérer mes ventes',
        action: onSales,
      ),
      (
        icon: Icons.storefront_outlined,
        label: 'Voir ma boutique',
        action: onPublicShop,
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth >= 700
            ? (constraints.maxWidth - 36) / 4
            : (constraints.maxWidth - 12) / 2;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: actions
              .map(
                (item) => SizedBox(
                  width: width,
                  height: 112,
                  child: Card(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: item.action,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            Icon(item.icon, size: 30),
                            const SizedBox(height: 8),
                            Text(
                              item.label,
                              textAlign: TextAlign.center,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w800),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              )
              .toList(growable: false),
        );
      },
    );
  }
}

class _QuotaCard extends StatelessWidget {
  const _QuotaCard({required this.profile, required this.onUpgrade});

  final PhotographerProfileModel profile;
  final VoidCallback onUpgrade;

  @override
  Widget build(BuildContext context) {
    final plan = MediaMarketplacePricing.planFor(profile.activePlanId);
    final photoRatio = plan.photoRatio(profile.publishedPhotoCount);
    final storageRatio = plan.storageRatio(profile.storageUsedBytes);
    final ratio = photoRatio > storageRatio ? photoRatio : storageRatio;
    final color = ratio >= .95
        ? Colors.red
        : ratio >= .8
            ? Colors.orange
            : Colors.green;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Formule ${plan.name}',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                      Text(
                        '${plan.qualityLabel} • ${(plan.commissionRate * 100).round()} % de commission',
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: onUpgrade,
                  child: const Text('Changer'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text('${profile.publishedPhotoCount} / ${plan.maxPublishedPhotos} photos'),
            LinearProgressIndicator(value: photoRatio.clamp(0, 1), color: color),
            const SizedBox(height: 10),
            Text(
              '${(profile.storageUsedBytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} / ${(plan.maxStorageBytes / (1024 * 1024 * 1024)).round()} Go',
            ),
            LinearProgressIndicator(
              value: storageRatio.clamp(0, 1),
              color: color,
            ),
            const SizedBox(height: 8),
            Text(
              'Conservation ${plan.retentionDays} jours • fichier max ${(plan.maxFileBytes / (1024 * 1024)).round()} Mo',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (ratio >= .8) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                ratio >= .95
                    ? 'Quota presque atteint. Les ventes restent actives, mais les nouveaux imports seront bloqués à 100 %.'
                    : 'Plus de 80 % du quota est utilisé.',
                style: TextStyle(color: color, fontWeight: FontWeight.w700),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SelectedGallerySummary extends StatelessWidget {
  const _SelectedGallerySummary({required this.controller});

  final PhotographerDashboardController controller;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: MediaMarketplaceMetricCard(
            label: 'Photos',
            value: '${controller.selectedGalleryPhotos.length}',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: MediaMarketplaceMetricCard(
            label: 'Packs',
            value: '${controller.selectedGalleryPacks.length}',
          ),
        ),
      ],
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
        padding: const EdgeInsets.all(18),
        child: Row(
          children: <Widget>[
            CircleAvatar(
              radius: 34,
              backgroundImage: profile.avatarUrl?.isNotEmpty == true
                  ? NetworkImage(profile.avatarUrl!)
                  : null,
              child: profile.avatarUrl?.isNotEmpty == true
                  ? null
                  : const Icon(Icons.camera_alt_outlined, size: 30),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    profile.brandName,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  Text(profile.email ?? 'Sans email'),
                  if (profile.bio?.isNotEmpty == true)
                    Text(
                      profile.bio!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
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

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.controller});

  final PhotographerDashboardController controller;

  @override
  Widget build(BuildContext context) {
    final profile = controller.profile!;
    final stats = <MapEntry<String, String>>[
      MapEntry('Photos publiées', '${profile.publishedPhotoCount}'),
      MapEntry('Galeries actives', '${profile.activeGalleryCount}'),
      MapEntry('Packs actifs', '${profile.activePackCount}'),
      MapEntry('Ventes', '${profile.salesCount}'),
      MapEntry('CA brut', '${profile.totalRevenueGross.toStringAsFixed(2)} €'),
      MapEntry('Revenus nets', '${profile.totalRevenueNet.toStringAsFixed(2)} €'),
    ];
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: stats
          .map(
            (entry) => SizedBox(
              width: 190,
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

class _StripeConnectCard extends StatefulWidget {
  const _StripeConnectCard({required this.profile, required this.onRefreshed});

  final PhotographerProfileModel profile;
  final Future<void> Function() onRefreshed;

  @override
  State<_StripeConnectCard> createState() => _StripeConnectCardState();
}

class _StripeConnectCardState extends State<_StripeConnectCard> {
  bool _loading = false;
  String? _error;

  FirebaseFunctions get _functions =>
      FirebaseFunctions.instanceFor(region: 'us-east1');

  Future<void> _onboard() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _functions
          .httpsCallable('createPhotographerConnectOnboardingLink')
          .call(<String, dynamic>{
        'photographerId': widget.profile.photographerId,
      });
      final url = result.data is Map ? result.data['url'] : null;
      if (url is! String || url.isEmpty) {
        throw StateError('URL Stripe invalide.');
      }
      final opened = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
      if (!opened) throw StateError('Impossible d’ouvrir Stripe.');
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _functions
          .httpsCallable('refreshPhotographerConnectStatus')
          .call(<String, dynamic>{
        'photographerId': widget.profile.photographerId,
      });
      await widget.onRefreshed();
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.profile;
    final hasAccount = profile.stripeAccountId?.isNotEmpty == true;
    final ready = profile.stripeChargesEnabled && profile.stripePayoutsEnabled;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Stripe Connect',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              ready
                  ? 'Paiements et reversements actifs. Les galeries peuvent être publiées.'
                  : 'La publication est bloquée tant que les paiements et reversements ne sont pas actifs.',
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
                MasliveButton(
                  label: hasAccount
                      ? 'Reprendre la configuration'
                      : 'Configurer Stripe',
                  onPressed: _loading ? null : _onboard,
                  expand: false,
                ),
                if (hasAccount)
                  OutlinedButton(
                    onPressed: _loading ? null : _refresh,
                    child: const Text('Rafraîchir le statut'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
