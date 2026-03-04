import 'package:flutter/material.dart';

import '../tokens/maslive_tokens.dart';

/// Soft background wrapper (no layout impact).
class SoftBackground extends StatelessWidget {
  final Widget child;

  const SoftBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: MasliveTokens.bg,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            MasliveTokens.bg,
            MasliveTokens.primary.withValues(alpha: 0.06),
          ],
        ),
      ),
      child: child,
    );
  }
}
