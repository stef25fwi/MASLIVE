import 'package:flutter/material.dart';

class MediaMarketplaceBackToCatalogButton extends StatelessWidget {
  const MediaMarketplaceBackToCatalogButton({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = DefaultTabController.maybeOf(context);
    if (controller == null) {
      return const SizedBox.shrink();
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: OutlinedButton.icon(
        onPressed: () => controller.animateTo(0),
        icon: const Icon(Icons.arrow_back_outlined),
        label: const Text('Retour au catalogue de cet événement'),
      ),
    );
  }
}