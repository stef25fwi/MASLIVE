import 'package:flutter/material.dart';

const double mediaHdUpgradePrice = 2.90;

Future<bool?> showMediaDeliveryOptionDialog(BuildContext context) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const MediaDeliveryOptionDialog(),
  );
}

class MediaDeliveryOptionDialog extends StatelessWidget {
  const MediaDeliveryOptionDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      title: const Text('Qualité de téléchargement'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Choisis la qualité appliquée à toutes les photos de cette commande.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              _DeliveryOptionTile(
                key: const Key('media_delivery_standard'),
                icon: Icons.web_asset_rounded,
                title: 'Version Web incluse',
                priceLabel: 'Inclus',
                description:
                    'Aperçus optimisés pour téléphone, réseaux sociaux et consultation en ligne. Les fichiers originaux ne sont pas inclus.',
                onTap: () => Navigator.of(context).pop(false),
              ),
              const SizedBox(height: 12),
              _DeliveryOptionTile(
                key: const Key('media_delivery_hd'),
                icon: Icons.hd_rounded,
                title: 'Fichiers HD et originaux',
                priceLabel: '+${mediaHdUpgradePrice.toStringAsFixed(2)} €',
                description:
                    'Ajoute les variantes haute définition et les fichiers originaux à toute la commande. Supplément unique, quel que soit le nombre de photos.',
                emphasized: true,
                onTap: () => Navigator.of(context).pop(true),
              ),
              const SizedBox(height: 12),
              Text(
                'Le choix est enregistré dans la commande et ne peut plus être modifié après l’ouverture de Stripe.',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          key: const Key('media_delivery_cancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
      ],
    );
  }
}

class _DeliveryOptionTile extends StatelessWidget {
  const _DeliveryOptionTile({
    super.key,
    required this.icon,
    required this.title,
    required this.priceLabel,
    required this.description,
    required this.onTap,
    this.emphasized = false,
  });

  final IconData icon;
  final String title;
  final String priceLabel;
  final String description;
  final VoidCallback onTap;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: emphasized
          ? colorScheme.primaryContainer.withValues(alpha: .55)
          : colorScheme.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: emphasized ? colorScheme.primary : colorScheme.outlineVariant,
              width: emphasized ? 2 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              CircleAvatar(
                backgroundColor: emphasized
                    ? colorScheme.primary
                    : colorScheme.surfaceContainerHighest,
                foregroundColor:
                    emphasized ? colorScheme.onPrimary : colorScheme.onSurfaceVariant,
                child: Icon(icon),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      alignment: WrapAlignment.spaceBetween,
                      children: <Widget>[
                        Text(
                          title,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        Text(
                          priceLabel,
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            color: emphasized ? colorScheme.primary : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(description),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}
