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
    final buttonFontSize = 14.5 * scale;
    final buttonTextStyle = TextStyle(
      fontSize: buttonFontSize,
      fontWeight: FontWeight.w800,
      height: 1.0,
      letterSpacing: 0.1,
    );
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
                            textStyle: buttonTextStyle,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(MasliveTokens.rPill),
                            ),
                          ),
                          onPressed: onPrevious,
                          child: const Text(
                            'Précédent',
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.fade,
                            softWrap: false,
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ),
              const SizedBox(width: MasliveTokens.s),
              Expanded(
                child: SizedBox(
                  height: buttonHeight,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: MasliveTokens.text,
                      foregroundColor: Colors.white,
                      textStyle: buttonTextStyle,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(MasliveTokens.rPill),
                      ),
                    ),
                    onPressed: onSave,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.save,
                          size: saveIconSize,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Sauvegarder',
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.fade,
                          softWrap: false,
                        ),
                      ],
                    ),
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
                            textStyle: buttonTextStyle,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(MasliveTokens.rPill),
                            ),
                          ),
                          onPressed: onNext,
                          child: const Text(
                            'Suivant',
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.fade,
                            softWrap: false,
                          ),
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
