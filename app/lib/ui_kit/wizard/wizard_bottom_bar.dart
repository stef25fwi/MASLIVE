import 'package:flutter/material.dart';

import '../glass/glass_panel.dart';
import '../tokens/maslive_tokens.dart';

class WizardBottomBar extends StatelessWidget {
  final VoidCallback? onPrevious;
  final VoidCallback onSave;
  final VoidCallback? onNext;

  final bool showPrevious;
  final bool showNext;

  const WizardBottomBar({
    super.key,
    required this.onSave,
    this.onPrevious,
    this.onNext,
    required this.showPrevious,
    required this.showNext,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          MasliveTokens.m,
          MasliveTokens.s,
          MasliveTokens.m,
          MasliveTokens.m,
        ),
        child: GlassPanel(
          radius: MasliveTokens.rXL,
          opacity: 0.76,
          padding: const EdgeInsets.all(MasliveTokens.s),
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: showPrevious
                      ? OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: MasliveTokens.primary,
                            side: BorderSide(
                              color: MasliveTokens.primary.withValues(alpha: 0.28),
                            ),
                            textStyle: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(MasliveTokens.rPill),
                            ),
                          ),
                          onPressed: onPrevious,
                          child: const Text('Précédent'),
                        )
                      : const SizedBox.shrink(),
                ),
              ),
              const SizedBox(width: MasliveTokens.s),
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: MasliveTokens.text,
                      foregroundColor: Colors.white,
                      textStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(MasliveTokens.rPill),
                      ),
                    ),
                    icon: const Icon(Icons.save, size: 20, color: Colors.white),
                    onPressed: onSave,
                    label: const Text('Sauvegarder'),
                  ),
                ),
              ),
              const SizedBox(width: MasliveTokens.s),
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: showNext
                      ? FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: MasliveTokens.primary,
                            foregroundColor: Colors.white,
                            textStyle: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(MasliveTokens.rPill),
                            ),
                          ),
                          onPressed: onNext,
                          child: const Text('Suivant'),
                        )
                      : const SizedBox.shrink(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
