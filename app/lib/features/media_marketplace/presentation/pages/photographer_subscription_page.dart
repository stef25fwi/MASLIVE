import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../ui/theme/maslive_theme.dart';
import '../../core/constants/media_marketplace_pricing.dart';
import '../../data/models/photographer_plan_model.dart';
import '../controllers/photographer_subscription_controller.dart';
import '../widgets/media_marketplace_message_card.dart';
import '../widgets/media_marketplace_section_header.dart';
import '../widgets/media_marketplace_shell.dart';

class PhotographerSubscriptionPage extends StatelessWidget {
  const PhotographerSubscriptionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<PhotographerSubscriptionController>(
      create: (_) {
        final controller = PhotographerSubscriptionController();
        Future<void>.microtask(controller.loadForCurrentOwner);
        return controller;
      },
      child: const _PhotographerSubscriptionView(),
    );
  }
}

class _PhotographerSubscriptionView extends StatefulWidget {
  const _PhotographerSubscriptionView();

  @override
  State<_PhotographerSubscriptionView> createState() =>
      _PhotographerSubscriptionViewState();
}

class _PhotographerSubscriptionViewState
    extends State<_PhotographerSubscriptionView> {
  String _billingInterval = 'month';

  Future<void> _openCheckout(
    BuildContext context,
    PhotographerSubscriptionController controller, {
    required String planId,
    required String billingInterval,
  }) async {
    final url = await controller.startCheckout(
      planId: planId,
      billingInterval: billingInterval,
    );
    if (!context.mounted) return;
    if (controller.activatedWithoutCheckout) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Formule Découverte activée.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (url == null || url.trim().isEmpty) return;
    final opened = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impossible d’ouvrir le paiement sécurisé.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<PhotographerSubscriptionController>();
    final activePlanCode =
        controller.activeSubscription?.quotaSnapshot.planCode ??
            controller.profile?.activePlanId ??
            'discovery';

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
                        subtitle: 'ABONNEMENT PHOTO',
                        onBack: () => Navigator.of(context).pop(),
                      ),
                    ),
                    Expanded(
                      child: controller.loading
                          ? const Center(child: CircularProgressIndicator())
                          : ListView(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                              children: <Widget>[
                                if (controller.error != null)
                                  MediaMarketplaceMessageCard.error(
                                    controller.error!,
                                  ),
                                _ActivePlanCard(
                                  planCode: activePlanCode,
                                  status:
                                      controller.activeSubscription?.status.name,
                                ),
                                const SizedBox(height: 18),
                                MediaMarketplaceSectionHeader(
                                  title: 'Formules photographes',
                                  subtitle:
                                      'Quotas, qualité, conservation et commission selon la formule.',
                                  trailing: SegmentedButton<String>(
                                    segments: const <ButtonSegment<String>>[
                                      ButtonSegment<String>(
                                        value: 'month',
                                        label: Text('Mensuel'),
                                      ),
                                      ButtonSegment<String>(
                                        value: 'year',
                                        label: Text('Annuel'),
                                      ),
                                    ],
                                    selected: <String>{_billingInterval},
                                    onSelectionChanged: (selection) {
                                      setState(
                                        () => _billingInterval =
                                            selection.first,
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(height: 14),
                                LayoutBuilder(
                                  builder: (context, constraints) {
                                    final columns = constraints.maxWidth >= 1100
                                        ? 4
                                        : constraints.maxWidth >= 720
                                            ? 2
                                            : 1;
                                    final cardWidth = columns == 1
                                        ? constraints.maxWidth
                                        : (constraints.maxWidth -
                                                ((columns - 1) * 12)) /
                                            columns;
                                    return Wrap(
                                      spacing: 12,
                                      runSpacing: 12,
                                      children: controller.plans.map((plan) {
                                        final spec =
                                            MediaMarketplacePricing.planFor(
                                          plan.code,
                                        );
                                        return SizedBox(
                                          width: cardWidth,
                                          child: _PlanCard(
                                            plan: plan,
                                            spec: spec,
                                            annual:
                                                _billingInterval == 'year',
                                            active:
                                                spec.code == activePlanCode,
                                            loading:
                                                controller.processingCheckout,
                                            onSelect: () => _openCheckout(
                                              context,
                                              controller,
                                              planId: plan.planId,
                                              billingInterval:
                                                  _billingInterval,
                                            ),
                                          ),
                                        );
                                      }).toList(growable: false),
                                    );
                                  },
                                ),
                                if (controller.plans.isEmpty)
                                  MediaMarketplaceMessageCard.empty(
                                    title: 'Catalogue indisponible',
                                    message:
                                        'Les tarifs MASLIVE seront rechargés automatiquement.',
                                    icon: Icons.workspace_premium_outlined,
                                  ),
                                const SizedBox(height: 26),
                                const MediaMarketplaceSectionHeader(
                                  title: 'Extensions de stockage',
                                  subtitle:
                                      'Les ventes restent actives. À 100 %, seuls les nouveaux imports sont suspendus.',
                                ),
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 12,
                                  runSpacing: 12,
                                  children: MediaMarketplacePricing
                                      .storageExtensions
                                      .map(
                                        (extension) => SizedBox(
                                          width: 310,
                                          child: _ExtensionCard(
                                            extension: extension,
                                            loading:
                                                controller.processingCheckout,
                                            onSelect: () => _openCheckout(
                                              context,
                                              controller,
                                              planId:
                                                  'extension:${extension.code}',
                                              billingInterval:
                                                  extension.durationDays == null
                                                      ? 'month'
                                                      : 'one_time',
                                            ),
                                          ),
                                        ),
                                      )
                                      .toList(growable: false),
                                ),
                                const SizedBox(height: 26),
                                const _CommercialReminder(),
                              ],
                            ),
                    ),
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
                onOpenPhotographer: () => Navigator.pushReplacementNamed(
                  context,
                  '/media-marketplace',
                  arguments: const <String, dynamic>{'initialTab': 3},
                ),
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

class _ActivePlanCard extends StatelessWidget {
  const _ActivePlanCard({required this.planCode, this.status});

  final String planCode;
  final String? status;

  @override
  Widget build(BuildContext context) {
    final plan = MediaMarketplacePricing.planFor(planCode);
    return Card(
      child: ListTile(
        leading: const CircleAvatar(
          child: Icon(Icons.workspace_premium_rounded),
        ),
        title: Text('Formule active : ${plan.name}'),
        subtitle: Text(
          '${plan.maxPublishedPhotos} photos • '
          '${(plan.maxStorageBytes / (1024 * 1024 * 1024)).round()} Go • '
          '${(plan.commissionRate * 100).round()} % de commission'
          '${status == null ? '' : ' • $status'}',
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.spec,
    required this.annual,
    required this.active,
    required this.loading,
    required this.onSelect,
  });

  final PhotographerPlanModel plan;
  final PhotographerPlanSpec spec;
  final bool annual;
  final bool active;
  final bool loading;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final recommended = spec.code == 'pro';
    final price = annual ? plan.annualPrice : plan.monthlyPrice;
    return Card(
      elevation: recommended ? 5 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: active
              ? Colors.green
              : recommended
                  ? MasliveTheme.pink
                  : Colors.black12,
          width: active || recommended ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: <Widget>[
                Text(
                  plan.name,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                if (recommended) const Chip(label: Text('RECOMMANDÉ')),
                if (active) const Chip(label: Text('ACTIF')),
              ],
            ),
            const SizedBox(height: 8),
            Text(plan.description),
            const SizedBox(height: 12),
            Text(
              price == 0
                  ? 'Gratuit'
                  : '${price.toStringAsFixed(2)} € / ${annual ? 'an' : 'mois'}',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 12),
            _FeatureLine('${spec.maxPublishedPhotos} photos actives'),
            _FeatureLine(
              '${(spec.maxStorageBytes / (1024 * 1024 * 1024)).round()} Go de stockage',
            ),
            _FeatureLine('${spec.maxActiveGalleries} galeries actives'),
            _FeatureLine(spec.qualityLabel),
            _FeatureLine(
              'Fichier max ${(spec.maxFileBytes / (1024 * 1024)).round()} Mo',
            ),
            _FeatureLine('Conservation ${spec.retentionDays} jours'),
            _FeatureLine(
              'Commission MASLIVE ${(spec.commissionRate * 100).round()} %',
            ),
            for (final feature in spec.features) _FeatureLine(feature),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: active || loading ? null : onSelect,
                child: Text(
                  active
                      ? 'Formule active'
                      : spec.monthlyPrice == 0
                          ? 'Activer gratuitement'
                          : 'Choisir ${spec.name}',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureLine extends StatelessWidget {
  const _FeatureLine(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(Icons.check_circle_rounded, size: 18, color: Colors.green),
          const SizedBox(width: 8),
          Expanded(child: Text(label)),
        ],
      ),
    );
  }
}

class _ExtensionCard extends StatelessWidget {
  const _ExtensionCard({
    required this.extension,
    required this.loading,
    required this.onSelect,
  });

  final StorageExtensionSpec extension;
  final bool loading;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              extension.title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              '${extension.monthlyPrice.toStringAsFixed(2)} €'
              '${extension.durationDays == null ? ' / mois' : ' pour ${extension.durationDays} jours'}',
            ),
            const SizedBox(height: 6),
            Text(
              '+${extension.extraPhotos} photos • '
              '+${(extension.extraStorageBytes / (1024 * 1024 * 1024)).round()} Go',
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: loading ? null : onSelect,
              icon: const Icon(Icons.add_circle_outline_rounded),
              label: const Text('Ajouter cette extension'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CommercialReminder extends StatelessWidget {
  const _CommercialReminder();

  @override
  Widget build(BuildContext context) {
    return const Card(
      color: Colors.black87,
      child: Padding(
        padding: EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Packs acheteurs MASLIVE',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: 8),
            Text(
              '1 photo 6,90 € • 2 photos 10,90 € • 5 photos 19,90 € • 10 photos 29,90 € • 20 photos 44,90 €',
              style: TextStyle(color: Colors.white70),
            ),
            SizedBox(height: 6),
            Text(
              'Le panier applique automatiquement la combinaison de packs la plus avantageuse.',
              style: TextStyle(color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }
}
