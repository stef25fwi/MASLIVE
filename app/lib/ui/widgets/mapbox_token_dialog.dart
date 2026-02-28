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
      builder: (context) {
        bool isLikelyValidToken(String token) {
          final t = token.trim();
          if (t.isEmpty) return true;
          return t.startsWith('pk.') ||
              t.startsWith('pk_') ||
              t.startsWith('sk.') ||
              t.startsWith('sk_');
        }

        String? tokenErrorText(String token) {
          final t = token.trim();
          if (t.isEmpty) return null;
          if (isLikelyValidToken(t)) return null;
          if (t.startsWith('mapbox://styles/')) {
            return 'Ceci ressemble à une URL de style (mapbox://styles/...), pas à un token.\nColle un token public (pk.*).';
          }
          if (t.startsWith('http://') || t.startsWith('https://')) {
            return 'Ceci ressemble à une URL. Colle un token public Mapbox (pk.*).';
          }
          return 'Token Mapbox invalide. Attendu: pk.* (token public).';
        }

        return StatefulBuilder(
          builder: (context, setState) {
            final token = controller.text.trim();
            final err = tokenErrorText(token);
            final canSave = err == null;

            return AlertDialog(
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
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: 'MAPBOX_ACCESS_TOKEN',
                      hintText: 'pk.eyJ1Ijoi....',
                      border: const OutlineInputBorder(),
                      errorText: err,
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
                  onPressed: !canSave
                      ? null
                      : () async {
                          final token = controller.text.trim();
                          await MapboxTokenService.setToken(token);
                          if (context.mounted) Navigator.of(context).pop(token);
                        },
                  child: const Text('Enregistrer'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
