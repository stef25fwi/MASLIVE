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
    final theme = Theme.of(context);
    final orientation = MediaQuery.of(context).orientation;
    final total = item.totalPrice;
    final metadataEntries = (item.metadata ?? const <String, dynamic>{})
        .entries
        .where((entry) => entry.value != null && entry.value.toString().trim().isNotEmpty)
        .take(3)
        .toList(growable: false);
    final infoChips = <Widget>[
      if (item.requiresShipping) const _PrimaryInfoChip(label: 'Livraison requise'),
      if (item.isDigital) const _PrimaryInfoChip(label: 'Produit digital'),
      for (final entry in metadataEntries)
        _SecondaryInfoChip(label: '${entry.key}: ${entry.value}'),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 360;
        final isWide = orientation == Orientation.landscape ||
            constraints.maxWidth > 560;

        final imageSize = isCompact ? 84.0 : (isWide ? 112.0 : 104.0);
        final titleFont = isCompact ? 18.0 : (isWide ? 24.0 : 22.0);
        final subtitleFont = isCompact ? 14.0 : (isWide ? 17.0 : 16.0);
        final unitPriceFont = isCompact ? 17.0 : (isWide ? 21.0 : 20.0);
        final totalFont = isCompact ? 19.0 : (isWide ? 24.0 : 22.0);
        final quantityFont = isCompact ? 14.0 : 16.0;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: const Color(0xFFEAEAEA)),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Color(0x0A000000),
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: imageSize,
                height: imageSize,
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F7),
                  borderRadius: BorderRadius.circular(isCompact ? 20 : 24),
                ),
                clipBehavior: Clip.antiAlias,
                child: item.imageUrl.trim().isEmpty
                    ? const Center(
                        child: Icon(
                          Icons.image_outlined,
                          size: 30,
                          color: Color(0xFF7B7B85),
                        ),
                      )
                    : Image.network(
                        item.imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return const Center(
                            child: Icon(
                              Icons.image_outlined,
                              size: 30,
                              color: Color(0xFF7B7B85),
                            ),
                          );
                        },
                      ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            item.title,
                            maxLines: isCompact ? 3 : 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontSize: titleFont,
                              height: 1.1,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF111827),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        _TypeBadge(itemType: item.itemType, sourceType: item.sourceType),
                      ],
                    ),
                    if (item.subtitle != null && item.subtitle!.trim().isNotEmpty) ...<Widget>[
                      const SizedBox(height: 8),
                      Text(
                        item.subtitle!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontSize: subtitleFont,
                          height: 1.2,
                          color: const Color(0xFF6B7280),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                    if (infoChips.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: infoChips,
                      ),
                    ],
                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: <Widget>[
                        Flexible(
                          child: Text(
                            '${item.unitPrice.toStringAsFixed(2)} ${item.currency}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontSize: unitPriceFont,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF111827),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'unite',
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF9CA3AF),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Spacer(),
                        Flexible(
                          child: Text(
                            '${total.toStringAsFixed(2)} ${item.currency}',
                            maxLines: 1,
                            textAlign: TextAlign.right,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontSize: totalFont,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFF111827),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: <Widget>[
                        if (item.canAdjustQuantity)
                          _QuantityStepper(
                            quantity: item.safeQuantity,
                            onIncrement: onIncrement,
                            onDecrement: onDecrement,
                          )
                        else
                          Container(
                            height: 46,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF9F9FB),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: const Color(0xFFEAEAEA)),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              'Quantite ${item.safeQuantity}',
                              style: TextStyle(
                                fontSize: quantityFont,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF111827),
                              ),
                            ),
                          ),
                        const Spacer(),
                        InkWell(
                          borderRadius: BorderRadius.circular(999),
                          onTap: onRemove,
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF6F6),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: const Color(0xFFFFE2E2)),
                            ),
                            child: const Icon(
                              Icons.delete_outline_rounded,
                              color: Color(0xFF7C5C63),
                              size: 22,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
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
    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: const Color(0xFFF9F9FB),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFEAEAEA)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _QtyButton(
            icon: Icons.remove,
            onTap: onDecrement,
          ),
          SizedBox(
            width: 40,
            child: Center(
              child: Text(
                '$quantity',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF111827),
                ),
              ),
            ),
          ),
          _QtyButton(
            icon: Icons.add,
            onTap: onIncrement,
          ),
        ],
      ),
    );
  }
}

class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.itemType, this.sourceType});

  final CartItemType itemType;
  final String? sourceType;

  @override
  Widget build(BuildContext context) {
    final isMerch = itemType == CartItemType.merch;
    final label = (sourceType != null && sourceType!.trim().isNotEmpty)
        ? sourceType!.trim().toUpperCase()
        : (isMerch ? 'MERCH' : 'MEDIA');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        gradient: LinearGradient(
          colors: isMerch
              ? const <Color>[Color(0xFFFFE7CF), Color(0xFFF9D8F0)]
              : const <Color>[Color(0xFFE8F4FF), Color(0xFFDFF4FF)],
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: isMerch ? const Color(0xFF9A5B12) : const Color(0xFF1D4ED8),
        ),
      ),
    );
  }
}

class _PrimaryInfoChip extends StatelessWidget {
  const _PrimaryInfoChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8F8),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE9E9E9)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Color(0xFF4B5563),
        ),
      ),
    );
  }
}

class _SecondaryInfoChip extends StatelessWidget {
  const _SecondaryInfoChip({required this.label});

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

class _QtyButton extends StatelessWidget {
  const _QtyButton({required this.icon, this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: SizedBox(
        width: 42,
        height: 46,
        child: Icon(
          icon,
          size: 20,
          color: const Color(0xFF4B5563),
        ),
      ),
    );
  }
}