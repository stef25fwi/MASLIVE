import 'package:flutter/material.dart';

class MediaMarketplaceMessageCard extends StatelessWidget {
  const MediaMarketplaceMessageCard({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  factory MediaMarketplaceMessageCard.error(Object error) {
    return MediaMarketplaceMessageCard(
      icon: Icons.error_outline,
      title: 'Erreur',
      message: error.toString(),
      backgroundColor: Colors.red.shade50,
      foregroundColor: Colors.red.shade700,
    );
  }

  factory MediaMarketplaceMessageCard.empty({
    required String title,
    required String message,
    IconData icon = Icons.inbox_outlined,
  }) {
    return MediaMarketplaceMessageCard(
      icon: icon,
      title: title,
      message: message,
      backgroundColor: Colors.grey.shade100,
      foregroundColor: Colors.grey.shade800,
    );
  }

  final IconData icon;
  final String title;
  final String message;
  final Color backgroundColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: backgroundColor,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(icon, color: foregroundColor),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: foregroundColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: foregroundColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}