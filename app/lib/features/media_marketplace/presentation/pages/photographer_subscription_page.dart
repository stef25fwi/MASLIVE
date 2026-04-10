import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/models/photographer_plan_model.dart';
import '../controllers/photographer_subscription_controller.dart';
import '../widgets/media_marketplace_message_card.dart';
import '../widgets/media_marketplace_section_header.dart';
import '../widgets/media_marketplace_shell.dart';
import '../../../../ui/theme/maslive_theme.dart';

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

class _PhotographerSubscriptionView extends StatelessWidget {
  const _PhotographerSubscriptionView();

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<PhotographerSubscriptionController>();

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
                              padding: const EdgeInsets.all(16),
                              children: <Widget>[
                                if (controller.error != null)
                                  MediaMarketplaceMessageCard.error(controller.error!),
                                if (controller.activeSubscription != null)
                                  Card(
                                    child: ListTile(
                                      title: const Text('Formule active'),
                                      subtitle: Text(
                                        '${controller.activeSubscription!.planId} • ${controller.activeSubscription!.status.name}',
                                      ),
                                    ),
                                  ),
                                const SizedBox(height: 12),
                                const MediaMarketplaceSectionHeader(
                                  title: 'Formules disponibles',
                                  subtitle: 'Choisis une formule mensuelle ou annuelle.',
                                ),
                                const SizedBox(height: 12),
                                for (final PhotographerPlanModel plan in controller.plans)
                                  Card(
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: <Widget>[
                                          Text(plan.name, style: Theme.of(context).textTheme.titleLarge),
                                          const SizedBox(height: 8),
                                          Text(plan.description),
                                          const SizedBox(height: 8),
                                          Text('Mensuel: ${plan.monthlyPrice.toStringAsFixed(2)} EUR'),
                                          Text('Annuel: ${plan.annualPrice.toStringAsFixed(2)} EUR'),
                                          const SizedBox(height: 12),
                                          Wrap(
                                            spacing: 8,
                                            children: <Widget>[
                                              FilledButton(
                                                onPressed: controller.processingCheckout
                                                    ? null
                                                    : () async {
                                                        final url = await controller.startCheckout(
                                                          planId: plan.planId,
                                                          billingInterval: 'month',
                                                        );
                                                        if (url == null) return;
                                                        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                                                      },
                                                child: const Text('Choisir la formule mensuelle'),
                                              ),
                                              OutlinedButton(
                                                onPressed: controller.processingCheckout
                                                    ? null
                                                    : () async {
                                                        final url = await controller.startCheckout(
                                                          planId: plan.planId,
                                                          billingInterval: 'year',
                                                        );
                                                        if (url == null) return;
                                                        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                                                      },
                                                child: const Text('Choisir la formule annuelle'),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                if (controller.plans.isEmpty && !controller.loading)
                                  MediaMarketplaceMessageCard.empty(
                                    title: 'Aucune formule',
                                    message: 'Aucune formule photographe n\'est disponible pour le moment.',
                                    icon: Icons.workspace_premium_outlined,
                                  ),
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
                  arguments: <String, dynamic>{'initialTab': 0},
                ),
                onOpenPhotographer: () => Navigator.pushReplacementNamed(
                  context,
                  '/media-marketplace',
                  arguments: <String, dynamic>{'initialTab': 3},
                ),
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
