import 'package:flutter/material.dart';
import 'package:masslive/ui_kit/tokens/maslive_tokens.dart';

import '../services/consent_service.dart';

/// Superpose une bannière de consentement (traceurs / mesure d'audience)
/// au-dessus de l'application tant que l'utilisateur n'a pas fait de choix.
///
/// À placer dans le `builder:` de MaterialApp, en enveloppant l'enfant.
class ConsentGate extends StatelessWidget {
  const ConsentGate({super.key, required this.child, this.onLearnMore});

  final Widget child;
  final VoidCallback? onLearnMore;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool?>(
      valueListenable: ConsentService.instance.analyticsConsent,
      builder: (context, consent, _) {
        return Stack(
          children: [
            child,
            if (consent == null)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _ConsentBanner(onLearnMore: onLearnMore),
              ),
          ],
        );
      },
    );
  }
}

class _ConsentBanner extends StatelessWidget {
  const _ConsentBanner({this.onLearnMore});
  final VoidCallback? onLearnMore;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Material(
          elevation: 12,
          borderRadius: BorderRadius.circular(16),
          color: Colors.white,
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: MasliveTokens.line),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.cookie_outlined,
                        size: 20, color: MasliveTokens.primary),
                    SizedBox(width: 8),
                    Text(
                      'Votre confidentialité',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: MasliveTokens.text,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Nous utilisons des traceurs de mesure d\'audience pour '
                  'améliorer l\'application. Ils ne sont activés qu\'avec votre '
                  'accord et vous pouvez changer d\'avis à tout moment.',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: MasliveTokens.textMuted,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () =>
                            ConsentService.instance.setAnalyticsConsent(false),
                        child: const Text('Refuser'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: MasliveTokens.primary,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () =>
                            ConsentService.instance.setAnalyticsConsent(true),
                        child: const Text('Accepter'),
                      ),
                    ),
                  ],
                ),
                if (onLearnMore != null)
                  Center(
                    child: TextButton(
                      onPressed: onLearnMore,
                      style: TextButton.styleFrom(
                        foregroundColor: MasliveTokens.textMuted,
                      ),
                      child: const Text('En savoir plus'),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
