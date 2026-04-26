import 'package:flutter/material.dart';

import '../../models/cart_item_model.dart';

class CartItemTile extends StatelessWidget {
  const CartItemTile({
    super.key,
    required this.item,
    required this.onRemove,
    this.onIncrement,
    this.onDecrement,
  });

  final CartItemModel item;
  final VoidCallback onRemove;
  final VoidCallback? onIncrement;
  final VoidCallback? onDecrement;

  @override
  Widget build(BuildContext context) {
    final metadata = item.metadata ?? const <String, dynamic>{};
    final fallbackAssetPath = (metadata['imagePath'] ?? '').toString().trim();
    final effectiveImageRef = item.imageUrl.trim().isNotEmpty
      ? item.imageUrl.trim()
      : fallbackAssetPath;
    final usesAssetImage = effectiveImageRef.startsWith('assets/');
    final theme = Theme.of(context);
    final metadataEntries = metadata
        .entries
      .where(
        (entry) =>
          entry.key != 'imagePath' &&
          entry.value != null &&
          entry.value.toString().trim().isNotEmpty,
      )
        .take(3)
        .toList(growable: false);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0x1A0F172A)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: SizedBox(
              width: 88,
              height: 88,
              child: effectiveImageRef.isEmpty
                  ? Container(
                      color: const Color(0xFFE5E7EB),
                      child: const Icon(Icons.image_outlined),
                    )
                  : usesAssetImage
                  ? Image.asset(
                      effectiveImageRef,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: const Color(0xFFE5E7EB),
                          child: const Icon(Icons.broken_image_outlined),
                        );
                      },
                    )
                  : Image.network(
                      effectiveImageRef,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: const Color(0xFFE5E7EB),
                          child: const Icon(Icons.broken_image_outlined),
                        );
                      },
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        item.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF111827),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _TypeBadge(itemType: item.itemType),
                  ],
                ),
                if (item.subtitle != null && item.subtitle!.trim().isNotEmpty) ...<Widget>[
                  const SizedBox(height: 4),
                  Text(
                    item.subtitle!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF6B7280),
                    ),
                  ),
                ],
                if (item.isDigital || item.requiresShipping || metadataEntries.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      if (item.isDigital) const _InfoChip(label: 'Produit digital'),
                      if (item.requiresShipping) const _InfoChip(label: 'Livraison requise'),
                      for (final entry in metadataEntries)
                        _InfoChip(label: '${entry.key}: ${entry.value}'),
                    ],
                  ),
                ],
                const SizedBox(height: 10),
                Row(
                  children: <Widget>[
                    Text(
                      '${item.unitPrice.toStringAsFixed(2)} ${item.currency}',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF111827),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${item.totalPrice.toStringAsFixed(2)} ${item.currency}',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF111827),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: <Widget>[
                    if (item.canAdjustQuantity)
                      _QuantityStepper(
                        quantity: item.safeQuantity,
                        onIncrement: onIncrement,
                        onDecrement: onDecrement,
                      )
                    else
                      Text(
                        'Quantite ${item.safeQuantity}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF4B5563),
                        ),
                      ),
                    const Spacer(),
                    IconButton(
                      onPressed: onRemove,
                      tooltip: 'Supprimer',
                      icon: const Icon(Icons.delete_outline_rounded),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuantityStepper extends StatelessWidget {
  const _QuantityStepper({
    required this.quantity,
    this.onIncrement,
    this.onDecrement,
  });

  final int quantity;
  final VoidCallback? onIncrement;
  final VoidCallback? onDecrement;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0x1F0F172A)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: onDecrement,
              icon: const Icon(Icons.remove_rounded),
            ),
            Text(
              '$quantity',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: onIncrement,
              icon: const Icon(Icons.add_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.itemType});

  final CartItemType itemType;

  @override
  Widget build(BuildContext context) {
    final isMerch = itemType == CartItemType.merch;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isMerch
              ? const <Color>[Color(0xFFFFF3E6), Color(0xFFFFE2F0)]
              : const <Color>[Color(0xFFE8F4FF), Color(0xFFEAF9FF)],
        ),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        isMerch ? 'Merch' : 'Media',
        style: TextStyle(
          fontWeight: FontWeight.w800,
          color: isMerch ? const Color(0xFFB45309) : const Color(0xFF1D4ED8),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Color(0xFF4B5563),
        ),
      ),
    );
  }
}