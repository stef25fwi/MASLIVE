import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../services/auth_service.dart';
import '../../../../ui/theme/maslive_theme.dart';
import '../../../../ui/widgets/maslive_button.dart';
import '../../data/models/media_order_model.dart';
import '../../data/models/photographer_profile_model.dart';
import '../../domain/catalog/photographer_commercial_catalog.dart';
import '../controllers/photographer_dashboard_controller.dart';
import '../widgets/media_gallery_card.dart';
import '../widgets/media_marketplace_back_to_catalog_button.dart';
import '../widgets/media_marketplace_context_chips.dart';
import '../widgets/media_marketplace_message_card.dart';
import '../widgets/media_marketplace_metric_card.dart';
import '../widgets/media_marketplace_section_header.dart';
import '../widgets/media_marketplace_shell.dart';
import 'photographer_gallery_manager_page.dart';

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
          final resolvedOwnerUid =
              ownerUid ?? AuthService.instance.currentUser?.uid;
          if (resolvedOwnerUid == null || resolvedOwnerUid.isEmpty) return;
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

  Future<void> _openManager(
    BuildContext context,
    PhotographerDashboardController controller, {
    bool openUploader = false,
  }) async {
    final profile = controller.profile;
    if (profile == null) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => PhotographerGalleryManagerPage(
          photographerId: profile.photographerId,
          initialEventId: eventId,
          initialEventName: eventName,
          initialCircuitName: circuitName,
          openUploaderOnStart: openUploader,
        ),
      ),
    );
    await controller.refresh();
  }

  void _openPublicShop(
    BuildContext context,
    PhotographerDashboardController controller,
  ) {
    final profile = controller.profile;
    if (profile == null) return;
    Navigator.of(context).pushNamed(
      '/media-marketplace',
      arguments: <String, dynamic>{
        'initialTab': 0,
        'photographerId': profile.photographerId,
        if (eventId?.trim().isNotEmpty == true) 'eventId': eventId,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<PhotographerDashboardController>();
    final profile = controller.profile;

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
                        : 'Contexte d’ouverture',
                    subtitle:
                        'Espace photographe ouvert depuis la carte active.',
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
                _PhotographerQuickActions(
                  onManage: () => _openManager(context, controller),
                  onUpload: () =>
                      _openManager(context, controller, openUploader: true),
                  onPublicShop: () => _openPublicShop(context, controller),
                ),
                const SizedBox(height: 16),
                _QuotaOverview(controller: controller),
                const SizedBox(height: 16),
                _StatsGrid(controller: controller),
                const SizedBox(height: 16),
                _StripeConnectCard(
                  profile: profile,
                  onRefreshed: controller.refresh,
                ),
                const SizedBox(height: 20),
                const MediaMarketplaceSectionHeader(
                  title: 'Galeries',
                  subtitle:
                      'Chaque galerie est rattachée à un circuit enregistré.',
                ),
                const SizedBox(height: 12),
                if (controller.galleries.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: <Widget>[
                          const Icon(Icons.photo_library_outlined, size: 42),
                          const SizedBox(height: 8),
                          const Text(
                            'Crée ta première galerie et ajoute tes photos depuis un seul espace.',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            onPressed: () => _openManager(context, controller),
                            icon: const Icon(Icons.create_new_folder_outlined),
                            label: const Text('Créer une galerie'),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: controller.galleries
                        .map(
                          (gallery) => MediaGalleryCard(
                            gallery: gallery,
                            width: 280,
                            selected: controller.selectedGalleryId ==
                                gallery.galleryId,
                            trailing: Icon(
                              Icons.chevron_right,
                              color: controller.selectedGalleryId ==
                                      gallery.galleryId
                                  ? Colors.white
                                  : null,
                            ),
                            onTap: () =>
                                controller.selectGallery(gallery.galleryId),
                          ),
                        )
                        .toList(growable: false),
                  ),
                if (controller.selectedGalleryId != null) ...<Widget>[
                  const SizedBox(height: 20),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  'Galerie sélectionnée',
                                  style:
                                      Theme.of(context).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '${controller.selectedGalleryPhotos.length} photos • '
                                  '${controller.selectedGalleryPacks.length} packs',
                                ),
                              ],
                            ),
                          ),
                          FilledButton.tonalIcon(
                            onPressed: () =>
                                _openManager(context, controller),
                            icon: const Icon(Icons.edit_outlined),
                            label: const Text('Gérer'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                const MediaMarketplaceSectionHeader(
                  title: 'Dernières commandes',
                  subtitle:
                      'Les 10 commandes les plus récentes pour ce photographe.',
                ),
                const SizedBox(height: 12),
                if (controller.recentOrders.isEmpty)
                  const Card(
                    child: ListTile(
                      leading: Icon(Icons.receipt_long_outlined),
                      title: Text('Aucune vente pour le moment'),
                      subtitle: Text(
                        'Les commandes apparaîtront ici après validation du paiement.',
                      ),
                    ),
                  )
                else
                  for (final order in controller.recentOrders.take(10))
                    _OrderTile(order: order),
              ],
            ],
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

class _PhotographerQuickActions extends StatelessWidget {
  const _PhotographerQuickActions({
    required this.onManage,
    required this.onUpload,
    required this.onPublicShop,
  });

  final VoidCallback onManage;
  final VoidCallback onUpload;
  final VoidCallback onPublicShop;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Ma boutique photos',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            const Text(
              'Crée des galeries par circuit, importe tes photos, surveille ton stockage et publie tes packs.',
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: <Widget>[
                FilledButton.icon(
                  onPressed: onManage,
                  icon: const Icon(Icons.dashboard_customize_outlined),
                  label: const Text('Gérer mes galeries'),
                ),
                FilledButton.tonalIcon(
                  onPressed: onUpload,
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  label: const Text('Ajouter des photos'),
                ),
                OutlinedButton.icon(
                  onPressed: onPublicShop,
                  icon: const Icon(Icons.storefront_outlined),
                  label: const Text('Voir ma boutique publique'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _QuotaOverview extends StatelessWidget {
  const _QuotaOverview({required this.controller});

  final PhotographerDashboardController controller;

  @override
  Widget build(BuildContext context) {
    final profile = controller.profile!;
    final subscription = controller.activeSubscription;
    final commercialPlan = PhotographerCommercialCatalog.resolve(
      subscription?.quotaSnapshot.planCode ??
          profile.activePlanId ??
          subscription?.planId,
    );
    final photoLimit = subscription?.quotaSnapshot.maxPublishedPhotos ?? 0;
    final storageLimit = subscription?.quotaSnapshot.maxStorageBytes ?? 0;
    final effectivePhotoLimit =
        photoLimit > 0 ? photoLimit : commercialPlan.maxPublishedPhotos;
    final effectiveStorageLimit =
        storageLimit > 0 ? storageLimit : commercialPlan.maxStorageBytes;
    final photoRatio = effectivePhotoLimit <= 0
        ? 0.0
        : (profile.publishedPhotoCount / effectivePhotoLimit)
            .clamp(0.0, 1.0);
    final storageRatio = effectiveStorageLimit <= 0
        ? 0.0
        : (profile.storageUsedBytes / effectiveStorageLimit)
            .clamp(0.0, 1.0);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Icon(Icons.cloud_outlined),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Stockage — offre ${commercialPlan.name}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Text(
                  commercialPlan.monthlyPrice == 0
                      ? 'Gratuit'
                      : '${commercialPlan.monthlyPrice.toStringAsFixed(2)} €/mois',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _DashboardQuotaLine(
              label: 'Photos',
              value:
                  '${profile.publishedPhotoCount} / $effectivePhotoLimit',
              ratio: photoRatio,
            ),
            const SizedBox(height: 10),
            _DashboardQuotaLine(
              label: 'Stockage',
              value:
                  '${_formatBytes(profile.storageUsedBytes)} / ${_formatBytes(effectiveStorageLimit)}',
              ratio: storageRatio,
            ),
            const SizedBox(height: 10),
            Text(
              'Qualité max ${commercialPlan.maxMegapixels} Mpx • '
              'fichier ${_formatBytes(commercialPlan.maxFileBytes)} max • '
              'commission ${commercialPlan.commissionPercent} %',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  static String _formatBytes(int bytes) {
    const gb = 1024 * 1024 * 1024;
    const mb = 1024 * 1024;
    if (bytes >= gb) return '${(bytes / gb).toStringAsFixed(1)} Go';
    return '${(bytes / mb).toStringAsFixed(0)} Mo';
  }
}

class _DashboardQuotaLine extends StatelessWidget {
  const _DashboardQuotaLine({
    required this.label,
    required this.value,
    required this.ratio,
  });

  final String label;
  final String value;
  final double ratio;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(child: Text(label)),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
        const SizedBox(height: 5),
        LinearProgressIndicator(
          value: ratio,
          minHeight: 7,
          borderRadius: BorderRadius.circular(999),
          color: ratio >= 0.95
              ? Colors.red
              : ratio >= 0.8
                  ? Colors.orange
                  : null,
        ),
      ],
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

  Future<void> _startOrResumeOnboarding() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final callable =
          _functions.httpsCallable('createPhotographerConnectOnboardingLink');
      final res = await callable.call(<String, dynamic>{
        'photographerId': widget.profile.photographerId,
      });
      final data = res.data;
      final url = data is Map ? data['url'] : null;
      if (url is! String || url.isEmpty) {
        throw Exception('URL Stripe invalide');
      }
      final ok = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
      if (!ok) throw Exception('Impossible d’ouvrir le navigateur');
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
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
    final hasAccount =
        profile.stripeAccountId != null && profile.stripeAccountId!.isNotEmpty;
    final payable = profile.stripeChargesEnabled && profile.stripePayoutsEnabled;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Paiements et reversements',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              !hasAccount
                  ? 'Configure Stripe Connect avant de publier tes galeries payantes.'
                  : payable
                      ? 'Compte payable : les ventes peuvent être reversées automatiquement.'
                      : 'Configuration incomplète : termine Stripe pour recevoir tes revenus.',
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
                  onPressed: _loading ? null : _startOrResumeOnboarding,
                  expand: false,
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
            Row(
              children: <Widget>[
                const CircleAvatar(child: Icon(Icons.camera_alt_outlined)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(profile.brandName,
                          style: Theme.of(context).textTheme.headlineSmall),
                      Text(profile.email ?? 'Sans email'),
                    ],
                  ),
                ),
                if (profile.isVerified)
                  const Chip(
                    avatar: Icon(Icons.verified, size: 18),
                    label: Text('Vérifié'),
                  ),
              ],
            ),
            if (profile.bio?.trim().isNotEmpty == true) ...<Widget>[
              const SizedBox(height: 10),
              Text(profile.bio!.trim()),
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
      MapEntry('Photos publiées', '${profile.publishedPhotoCount}'),
      MapEntry('Galeries actives', '${profile.activeGalleryCount}'),
      MapEntry('Packs actifs', '${profile.activePackCount}'),
      MapEntry('Ventes', '${profile.salesCount}'),
      MapEntry('CA brut', '${profile.totalRevenueGross.toStringAsFixed(2)} €'),
      MapEntry('Revenu net', '${profile.totalRevenueNet.toStringAsFixed(2)} €'),
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

class _OrderTile extends StatelessWidget {
  const _OrderTile({required this.order});

  final MediaOrderModel order;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.receipt_long_outlined),
        title: Text(order.orderId),
        subtitle: Text(
          '${order.items.length} ligne${order.items.length > 1 ? 's' : ''} • '
          '${order.total.toStringAsFixed(2)} ${order.currency}',
        ),
      ),
    );
  }
}
