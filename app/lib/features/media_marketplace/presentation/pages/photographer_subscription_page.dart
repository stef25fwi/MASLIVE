import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/models/photographer_plan_model.dart';
import '../controllers/photographer_subscription_controller.dart';
import '../widgets/media_marketplace_message_card.dart';
import '../widgets/media_marketplace_section_header.dart';

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
      appBar: AppBar(title: const Text('Abonnement photographe')),
      body: controller.loading
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
    );
  }
}
