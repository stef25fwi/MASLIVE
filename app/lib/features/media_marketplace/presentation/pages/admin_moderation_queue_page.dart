import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/admin_moderation_queue_model.dart';
import '../controllers/admin_moderation_queue_controller.dart';
import '../widgets/media_marketplace_message_card.dart';
import '../widgets/media_marketplace_section_header.dart';

class AdminModerationQueuePage extends StatelessWidget {
  const AdminModerationQueuePage({super.key, this.status, this.photographerId});

  final String? status;
  final String? photographerId;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AdminModerationQueueController>(
      create: (_) {
        final controller = AdminModerationQueueController();
        controller.watch(status: status, photographerId: photographerId);
        return controller;
      },
      child: const _AdminModerationQueueView(),
    );
  }
}

class _AdminModerationQueueView extends StatelessWidget {
  const _AdminModerationQueueView();

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AdminModerationQueueController>();

    return Scaffold(
      appBar: AppBar(title: const Text('Modération des contenus média')),
      body: controller.loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: <Widget>[
                if (controller.error != null)
                  MediaMarketplaceMessageCard.error(controller.error!),
                if (controller.items.isEmpty)
                  MediaMarketplaceMessageCard.empty(
                    title: 'Aucune modération en attente',
                    message: 'Aucun élément n\'attend une revue pour le moment.',
                    icon: Icons.fact_check_outlined,
                  )
                else ...<Widget>[
                  const MediaMarketplaceSectionHeader(
                    title: 'File de modération',
                    subtitle: 'Photos et packs en attente de vérification.',
                  ),
                  const SizedBox(height: 12),
                  for (final AdminModerationQueueModel item in controller.items)
                    Card(
                      child: ListTile(
                        title: Text('${item.entityType} • ${item.entityId}'),
                        subtitle: Text(
                          '${item.status.name}${item.photographerId != null ? ' • ${item.photographerId}' : ''}',
                        ),
                      ),
                    ),
                ],
              ],
            ),
    );
  }
}