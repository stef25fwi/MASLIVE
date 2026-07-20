import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../services/auth_service.dart';
import '../../../../ui/theme/maslive_theme.dart';
import '../../../../ui/widgets/maslive_button.dart';
import '../../core/constants/media_marketplace_pricing.dart';
import '../../data/models/media_order_model.dart';
import '../../data/models/photographer_profile_model.dart';
import '../controllers/photographer_dashboard_controller.dart';
import '../widgets/media_gallery_card.dart';
import '../widgets/media_marketplace_context_chips.dart';
import '../widgets/media_marketplace_message_card.dart';
import '../widgets/media_marketplace_metric_card.dart';
import '../widgets/media_marketplace_section_header.dart';
import '../widgets/media_marketplace_shell.dart';
import 'photographer_business_center_page.dart';
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
          final uid = ownerUid ?? AuthService.instance.currentUser?.uid;
          if (uid != null && uid.isNotEmpty) {
            await controller.loadForOwnerUid(uid);
          }
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

  Future<void> _open(BuildContext context, Widget page) async {
    await Navigator.of(
      context,
    ).push<void>(MaterialPageRoute<void>(builder: (_) => page));
    if (context.mounted) {
      await context.read<PhotographerDashboardController>().refresh();
    }
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
              padding: const EdgeInsets.fromLTRB(12, 16, 12, 32),
              children: <Widget>[
                if (controller.error != null)
                  MediaMarketplaceMessageCard.error(controller.error!),
                if (profile == null)
                  _CreateProfileCard(
                    onCreate: () => _open(
                      context,
                      const PhotographerBusinessCenterPage(initialTab: 0),
                    ),
                  )
                else ...<Widget>[
                  if (showContextHeader &&
                      eventId?.trim().isNotEmpty == true) ...<Widget>[
                    MediaMarketplaceSectionHeader(
                      title: eventName?.trim().isNotEmpty == true
                          ? eventName!.trim()
                          : 'Circuit sélectionné',
                      subtitle:
                          'Les galeries liées à la carte choisie sont prioritaires dans la boutique.',
                    ),
                    const SizedBox(height: 10),
                    MediaMarketplaceContextChips(
                      eventId: eventId!.trim(),
                      circuitName: circuitName,
                    ),
                    const SizedBox(height: 16),
                  ],
                  _ProfileHeader(
                    profile: profile,
                    onEdit: () => _open(
                      context,
                      const PhotographerBusinessCenterPage(initialTab: 0),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _QuotaCard(
                    profile: profile,
                    onUpgrade: () => _open(
                      context,
                      const PhotographerSubscriptionPage(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _ActionGrid(
                    onCreateGallery: () => _open(
                      context,
                      PhotographerGalleryManagerPage(
                        initialEventId: eventId,
                        initialEventName: eventName,
                        initialCircuitId: circuitId,
                        initialCircuitName: circuitName,
                      ),
                    ),
                    onPhotos: () => _open(
                      context,
                      const PhotographerBusinessCenterPage(initialTab: 1),
                    ),
                    onSales: () => _open(
                      context,
                      const PhotographerBusinessCenterPage(initialTab: 2),
                    ),
                    onBilling: () => _open(
                      context,
                      const PhotographerBusinessCenterPage(initialTab: 3),
                    ),
                  ),
                  const SizedBox(height: 18),
                  _StatsGrid(profile: profile),
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
                      onPressed: () => _open(
                        context,
                        PhotographerGalleryManagerPage(
                          initialEventId: eventId,
                          initialEventName: eventName,
                          initialCircuitId: circuitId,
                          initialCircuitName: circuitName,
                        ),
                      ),
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
                        separatorBuilder: (context, index) =>
                            const SizedBox(width: 12),
                        itemBuilder: (context, index) {
                          final gallery = controller.galleries[index];
                          return MediaGalleryCard(
                            gallery: gallery,
                            width: 290,
                            selected:
                                controller.selectedGalleryId == gallery.galleryId,
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () =>
                                controller.selectGallery(gallery.galleryId),
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 22),
                  const MediaMarketplaceSectionHeader(
                    title: 'Dernières ventes',
                    subtitle:
                        'Résumé des commandes récentes et accès au détail complet.',
                  ),
                  const SizedBox(height: 10),
                  if (controller.recentOrders.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(18),
                        child: Text('Aucune vente pour le moment.'),
                      ),
                    )
                  else ...<Widget>[
                    for (final MediaOrderModel order
                        in controller.recentOrders.take(5))
                      Card(
                        child: ListTile(
                          leading: const Icon(Icons.receipt_long_outlined),
                          title: Text(
                            '${order.total.toStringAsFixed(2)} ${order.currency}',
                          ),
                          subtitle: Text(
                            '${order.paymentStatus.name} • ${order.items.length} ligne(s)',
                          ),
                          trailing: Text(
                            '${order.photographerNetTotal.toStringAsFixed(2)} € net',
                          ),
                        ),
                      ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () => _open(
                          context,
                          const PhotographerBusinessCenterPage(initialTab: 2),
                        ),
                        icon: const Icon(Icons.open_in_new),
                        label: const Text('Voir toutes les ventes'),
                      ),
                    ),
                  ],
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

class _CreateProfileCard extends StatelessWidget {
  const _CreateProfileCard({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: <Widget>[
            const Icon(Icons.camera_alt_outlined, size: 54),
            const SizedBox(height: 12),
            Text(
              'Crée ton profil photographe',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            const Text(
              'Renseigne ta marque, ton territoire et tes coordonnées. La formule Découverte sera utilisée par défaut.',
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add),
              label: const Text('Créer mon profil'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.profile, required this.onEdit});

  final PhotographerProfileModel profile;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final hasAvatar = profile.avatarUrl?.isNotEmpty == true;
    final cityAndCountry = <String>[
      if (profile.city?.trim().isNotEmpty == true) profile.city!.trim(),
      if (profile.country?.trim().isNotEmpty == true) profile.country!.trim(),
    ].join(' • ');

    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          radius: 34,
          backgroundImage: hasAvatar ? NetworkImage(profile.avatarUrl!) : null,
          child: hasAvatar ? null : const Icon(Icons.camera_alt_outlined),
        ),
        title: Text(
          profile.brandName,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
        ),
        subtitle: Text(
          '$cityAndCountry\n${profile.bio ?? ''}',
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: IconButton(
          onPressed: onEdit,
          icon: const Icon(Icons.edit_outlined),
          tooltip: 'Modifier le profil',
        ),
      ),
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
    final photo = plan
        .photoRatio(profile.publishedPhotoCount)
        .clamp(0.0, 1.0)
        .toDouble();
    final storage = plan
        .storageRatio(profile.storageUsedBytes)
        .clamp(0.0, 1.0)
        .toDouble();
    final galleries = plan.maxActiveGalleries <= 0
        ? 0.0
        : (profile.activeGalleryCount / plan.maxActiveGalleries)
              .clamp(0.0, 1.0)
              .toDouble();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    'Formule ${plan.name}',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                TextButton(onPressed: onUpgrade, child: const Text('Changer')),
              ],
            ),
            Text(
              '${plan.qualityLabel} • ${(plan.commissionRate * 100).round()} % de commission',
            ),
            const SizedBox(height: 14),
            _QuotaLine(
              label:
                  '${profile.publishedPhotoCount} / ${plan.maxPublishedPhotos} photos',
              value: photo,
            ),
            _QuotaLine(
              label:
                  '${(profile.storageUsedBytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} / ${(plan.maxStorageBytes / (1024 * 1024 * 1024)).round()} Go',
              value: storage,
            ),
            _QuotaLine(
              label:
                  '${profile.activeGalleryCount} / ${plan.maxActiveGalleries} galeries actives',
              value: galleries,
            ),
            const SizedBox(height: 6),
            Text(
              'Conservation ${plan.retentionDays} jours • fichier max ${(plan.maxFileBytes / (1024 * 1024)).round()} Mo',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _QuotaLine extends StatelessWidget {
  const _QuotaLine({required this.label, required this.value});

  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    final normalizedValue = value.clamp(0.0, 1.0).toDouble();
    final color = normalizedValue >= .95
        ? Theme.of(context).colorScheme.error
        : normalizedValue >= .8
        ? Colors.orange
        : Colors.green;

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label),
          const SizedBox(height: 4),
          LinearProgressIndicator(value: normalizedValue, color: color),
        ],
      ),
    );
  }
}

class _ActionGrid extends StatelessWidget {
  const _ActionGrid({
    required this.onCreateGallery,
    required this.onPhotos,
    required this.onSales,
    required this.onBilling,
  });

  final VoidCallback onCreateGallery;
  final VoidCallback onPhotos;
  final VoidCallback onSales;
  final VoidCallback onBilling;

  @override
  Widget build(BuildContext context) {
    final actions = <({IconData icon, String label, VoidCallback action})>[
      (
        icon: Icons.create_new_folder_outlined,
        label: 'Galeries et imports',
        action: onCreateGallery,
      ),
      (
        icon: Icons.photo_library_outlined,
        label: 'Gérer les photos',
        action: onPhotos,
      ),
      (
        icon: Icons.payments_outlined,
        label: 'Ventes et reversements',
        action: onSales,
      ),
      (
        icon: Icons.receipt_long_outlined,
        label: 'Abonnement et factures',
        action: onBilling,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth >= 760
            ? (constraints.maxWidth - 36) / 4
            : (constraints.maxWidth - 12) / 2;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: actions
              .map(
                (item) => SizedBox(
                  width: width,
                  height: 110,
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
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
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

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.profile});

  final PhotographerProfileModel profile;

  @override
  Widget build(BuildContext context) {
    final stats = <MapEntry<String, String>>[
      MapEntry('Photos publiées', '${profile.publishedPhotoCount}'),
      MapEntry('Galeries actives', '${profile.activeGalleryCount}'),
      MapEntry('Packs actifs', '${profile.activePackCount}'),
      MapEntry('Ventes', '${profile.salesCount}'),
      MapEntry('CA brut', '${profile.totalRevenueGross.toStringAsFixed(2)} €'),
      MapEntry(
        'Revenus nets',
        '${profile.totalRevenueNet.toStringAsFixed(2)} €',
      ),
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
  const _StripeConnectCard({
    required this.profile,
    required this.onRefreshed,
  });

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

  Future<void> _call(String name, {bool openUrl = false}) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = await _functions.httpsCallable(name).call(
        <String, dynamic>{'photographerId': widget.profile.photographerId},
      );
      final data = result.data;
      final url = data is Map ? data['url']?.toString() : null;
      if (openUrl && url != null && url.isNotEmpty) {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      }
      await widget.onRefreshed();
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasAccount = widget.profile.stripeAccountId?.isNotEmpty == true;
    final ready = widget.profile.stripeChargesEnabled &&
        widget.profile.stripePayoutsEnabled;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Stripe Connect',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(
              ready
                  ? 'Paiements et reversements actifs.'
                  : 'La publication reste bloquée tant que Stripe Connect n’est pas payable.',
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _error!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                MasliveButton(
                  label: hasAccount
                      ? 'Reprendre la configuration'
                      : 'Configurer Stripe',
                  onPressed: _loading
                      ? null
                      : () => _call(
                          'createPhotographerConnectOnboardingLink',
                          openUrl: true,
                        ),
                  expand: false,
                ),
                if (hasAccount)
                  OutlinedButton(
                    onPressed: _loading
                        ? null
                        : () => _call('refreshPhotographerConnectStatus'),
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
