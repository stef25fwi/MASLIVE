import 'package:flutter/material.dart';

import '../glass/glass_panel.dart';
import '../tokens/maslive_tokens.dart';

class WizardBottomBar extends StatelessWidget {
  final VoidCallback? onPrevious;
  final VoidCallback onSave;
  final VoidCallback? onNext;

  final bool showPrevious;
  final bool showNext;

  final EdgeInsetsGeometry outerPadding;
  final EdgeInsetsGeometry panelPadding;

  const WizardBottomBar({
    super.key,
    required this.onSave,
    this.onPrevious,
    this.onNext,
    required this.showPrevious,
    required this.showNext,
    this.outerPadding = const EdgeInsets.fromLTRB(
      MasliveTokens.m,
      MasliveTokens.s,
      MasliveTokens.m,
      MasliveTokens.m,
    ),
    this.panelPadding = const EdgeInsets.all(MasliveTokens.s),
  });

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final scale = (w / 390.0).clamp(0.85, 1.15);
    final buttonHeight = 52.0 * scale;
    final buttonFontSize = 16.0 * scale;
    final saveIconSize = 20.0 * scale;

    return SafeArea(
      top: false,
      child: Padding(
        padding: outerPadding,
        child: GlassPanel(
          radius: MasliveTokens.rXL,
          opacity: 0.76,
          padding: panelPadding,
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: buttonHeight,
                  child: showPrevious
                      ? OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: MasliveTokens.primary,
                            side: BorderSide(
                              color: MasliveTokens.primary.withValues(alpha: 0.28),
                            ),
                            textStyle: TextStyle(
                              fontSize: buttonFontSize,
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
                  height: buttonHeight,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: MasliveTokens.text,
                      foregroundColor: Colors.white,
                      textStyle: TextStyle(
                        fontSize: buttonFontSize,
                        fontWeight: FontWeight.w800,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(MasliveTokens.rPill),
                      ),
                    ),
                    icon: Icon(Icons.save, size: saveIconSize, color: Colors.white),
                    onPressed: onSave,
                    label: const Text('Sauvegarder'),
                  ),
                ),
              ),
              const SizedBox(width: MasliveTokens.s),
              Expanded(
                child: SizedBox(
                  height: buttonHeight,
                  child: showNext
                      ? FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: MasliveTokens.primary,
                            foregroundColor: Colors.white,
                            textStyle: TextStyle(
                              fontSize: buttonFontSize,
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
