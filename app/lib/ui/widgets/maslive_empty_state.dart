import 'package:flutter/material.dart';

import '../../ui_kit/tokens/maslive_tokens.dart';
import 'maslive_button.dart';

/// État vide partagé : icône, message, action optionnelle. Remplace les
/// variantes ad-hoc dispersées par écran (listes vides, résultats de
/// recherche vides, dashboards sans données...).
class MasliveEmptyState extends StatelessWidget {
  const MasliveEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: MasliveTokens.l, vertical: MasliveTokens.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: MasliveTokens.bg,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 30, color: MasliveTokens.textFaint),
          ),
          const SizedBox(height: MasliveTokens.m),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: MasliveTokens.text,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: MasliveTokens.xs),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: MasliveTokens.textMuted,
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ],
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: MasliveTokens.l),
            MasliveButton(
              label: actionLabel!,
              onPressed: onAction,
              expand: false,
            ),
          ],
        ],
      ),
    );
  }
}
