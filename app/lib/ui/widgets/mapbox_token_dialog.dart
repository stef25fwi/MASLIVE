import 'package:flutter/material.dart';

import '../../services/mapbox_token_service.dart';

class MapboxTokenDialog {
  static Future<String?> show(
    BuildContext context, {
    required String initialValue,
  }) {
    final controller = TextEditingController(text: initialValue);

    return showDialog<String?>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Configurer Mapbox'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Collez votre token public Mapbox.\n'
              'Il sera stocké localement (SharedPreferences).',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'MAPBOX_ACCESS_TOKEN',
                hintText: 'pk.eyJ1Ijoi....',
                border: OutlineInputBorder(),
              ),
              autocorrect: false,
              enableSuggestions: false,
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(null),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () async {
              await MapboxTokenService.clearToken();
              if (context.mounted) Navigator.of(context).pop('');
            },
            child: const Text('Effacer'),
          ),
          FilledButton(
            onPressed: () async {
              final token = controller.text.trim();
              await MapboxTokenService.setToken(token);
              if (context.mounted) Navigator.of(context).pop(token);
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }
}
