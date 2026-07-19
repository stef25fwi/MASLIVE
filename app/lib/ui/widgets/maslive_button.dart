import 'package:flutter/material.dart';

import '../../ui_kit/tokens/maslive_tokens.dart';
import '../theme/maslive_theme.dart';

/// Style visuel du bouton. [primary] est le CTA par défaut de l'app
/// (couleur d'accent unique) ; [gradient] réserve le dégradé signature aux
/// moments hero (paiement, action principale d'un écran clé) ; [secondary]
/// et [ghost] pour les actions moins prioritaires.
enum MasliveButtonVariant { primary, gradient, secondary, ghost }

/// Bouton CTA unique de l'app — un seul composant plutôt qu'un
/// `ElevatedButton` redessiné par écran. Gère état pressé (via l'`InkWell`
/// Material), désactivé et chargement.
class MasliveButton extends StatelessWidget {
  const MasliveButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = MasliveButtonVariant.primary,
    this.icon,
    this.loading = false,
    this.expand = true,
    this.backgroundColor,
    this.foregroundColor,
  });

  final String label;
  final VoidCallback? onPressed;
  final MasliveButtonVariant variant;
  final IconData? icon;
  final bool loading;
  final bool expand;
  final Color? backgroundColor;
  final Color? foregroundColor;

  bool get _disabled => onPressed == null || loading;

  @override
  Widget build(BuildContext context) {
    final Color fg = foregroundColor ??
        switch (variant) {
          MasliveButtonVariant.primary => Colors.white,
          MasliveButtonVariant.gradient => Colors.white,
          MasliveButtonVariant.secondary => MasliveTokens.text,
          MasliveButtonVariant.ghost => MasliveTokens.primary,
        };
    final primaryColor = backgroundColor ?? MasliveTokens.primary;

    final content = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (loading)
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2.2, color: fg),
          )
        else ...[
          if (icon != null) ...[
            Icon(icon, size: 19, color: fg),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: fg,
                fontSize: 15,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.1,
              ),
            ),
          ),
        ],
      ],
    );

    final decoration = switch (variant) {
      MasliveButtonVariant.primary => BoxDecoration(
        color: _disabled
            ? primaryColor.withValues(alpha: 0.4)
            : primaryColor,
        borderRadius: BorderRadius.circular(MasliveTokens.rM),
      ),
      MasliveButtonVariant.gradient => BoxDecoration(
        gradient: _disabled ? null : MasliveTheme.actionGradient,
        color: _disabled ? MasliveTokens.textFaint : null,
        borderRadius: BorderRadius.circular(MasliveTokens.rM),
      ),
      MasliveButtonVariant.secondary => BoxDecoration(
        color: backgroundColor ?? MasliveTokens.surface,
        borderRadius: BorderRadius.circular(MasliveTokens.rM),
        border: Border.all(color: MasliveTokens.line, width: 1.2),
      ),
      MasliveButtonVariant.ghost => const BoxDecoration(),
    };

    return Opacity(
      opacity: _disabled && variant != MasliveButtonVariant.primary ? 0.5 : 1,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(MasliveTokens.rM),
          onTap: _disabled ? null : onPressed,
          child: Container(
            height: 52,
            width: expand ? double.infinity : null,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            decoration: decoration,
            alignment: Alignment.center,
            child: content,
          ),
        ),
      ),
    );
  }
}
