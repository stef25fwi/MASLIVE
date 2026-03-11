import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/live_table_state.dart';
import '../services/restaurant_subscription_guard.dart';

class LiveTableProPanel extends StatelessWidget {
  const LiveTableProPanel({
    super.key,
    required this.layerType,
    required this.isPremium,
    required this.isBusinessSubscribed,
    required this.isLoadingRemoteState,
    required this.enabled,
    required this.status,
    required this.availableCtrl,
    required this.capacityCtrl,
    required this.messageCtrl,
    required this.onToggleEnabled,
    required this.onStatusChanged,
    required this.onOpenPaywall,
  });

  final String layerType;
  final bool isPremium;
  final bool isBusinessSubscribed;
  final bool isLoadingRemoteState;
  final bool enabled;
  final LiveTableStatus status;
  final TextEditingController availableCtrl;
  final TextEditingController capacityCtrl;
  final TextEditingController messageCtrl;
  final ValueChanged<bool> onToggleEnabled;
  final ValueChanged<LiveTableStatus> onStatusChanged;
  final VoidCallback onOpenPaywall;

  @override
  Widget build(BuildContext context) {
    final guard = const RestaurantSubscriptionGuard();
    final isFoodPoi = layerType.trim().toLowerCase() == 'food';
    final canEdit = guard.canEditLiveTable(
      isFoodPoi: isFoodPoi,
      isPremium: isPremium,
      isBusinessSubscribed: isBusinessSubscribed,
    );
    final canInteract = canEdit && !isLoadingRemoteState;

    if (!isFoodPoi) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Statut live tables',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              if (!canEdit && !isLoadingRemoteState)
                TextButton(
                  onPressed: onOpenPaywall,
                  child: const Text('Debloquer'),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            isLoadingRemoteState
                ? 'Chargement du statut public actuel avant edition.'
                : canEdit
                ? 'Affiche l etat de vos tables en temps reel sur la fiche publique.'
                : 'Cette fonctionnalite est reservee aux restaurants avec abonnement actif.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (isLoadingRemoteState) ...[
            const SizedBox(height: 8),
            const LinearProgressIndicator(),
          ],
          const SizedBox(height: 8),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: enabled,
            onChanged: canInteract ? onToggleEnabled : null,
            title: const Text('Activer le statut live'),
          ),
          const SizedBox(height: 6),
          DropdownButtonFormField<LiveTableStatus>(
            initialValue: status,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Etat',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(
                value: LiveTableStatus.available,
                child: Text('Tables disponibles'),
              ),
              DropdownMenuItem(
                value: LiveTableStatus.limited,
                child: Text('Affluence moderee'),
              ),
              DropdownMenuItem(value: LiveTableStatus.full, child: Text('Complet')),
              DropdownMenuItem(value: LiveTableStatus.closed, child: Text('Ferme')),
            ],
            onChanged: canInteract
                ? (v) {
                    if (v != null) onStatusChanged(v);
                  }
                : null,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: availableCtrl,
                  keyboardType: TextInputType.number,
                  enabled: canInteract,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Tables libres',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: capacityCtrl,
                  keyboardType: TextInputType.number,
                  enabled: canInteract,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Capacite totale',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: messageCtrl,
            maxLines: 2,
            enabled: canInteract,
            decoration: const InputDecoration(
              labelText: 'Message court (optionnel)',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
    );
  }
}
