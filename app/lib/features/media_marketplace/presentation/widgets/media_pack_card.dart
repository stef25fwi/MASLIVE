import 'package:flutter/material.dart';

import '../../data/models/media_pack_model.dart';

class MediaPackCard extends StatelessWidget {
  const MediaPackCard({
    super.key,
    required this.pack,
    this.onPrimaryAction,
    this.primaryActionLabel = 'Ajouter',
    this.primaryActionIcon = Icons.add_shopping_cart,
    this.width = 260,
  });

  final MediaPackModel pack;
  final VoidCallback? onPrimaryAction;
  final String primaryActionLabel;
  final IconData primaryActionIcon;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                height: 120,
                color: Colors.grey.shade100,
                alignment: Alignment.center,
                child: const Icon(Icons.collections_outlined, size: 42),
              ),
              const SizedBox(height: 12),
              Text(
                pack.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Text(
                '${pack.photoIds.length} photos • ${pack.price.toStringAsFixed(2)} ${pack.currency}',
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: onPrimaryAction,
                icon: Icon(primaryActionIcon),
                label: Text(primaryActionLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}