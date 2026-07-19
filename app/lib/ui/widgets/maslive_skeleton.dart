import 'package:flutter/material.dart';

import '../../ui_kit/tokens/maslive_tokens.dart';

/// Placeholder de chargement anime (shimmer) — remplace les
/// `CircularProgressIndicator` centres qui vident l'ecran pendant le
/// premier chargement d'une liste/carte.
class MasliveSkeleton extends StatefulWidget {
  const MasliveSkeleton({
    super.key,
    this.width,
    this.height = 16,
    this.borderRadius,
  });

  final double? width;
  final double height;
  final double? borderRadius;

  @override
  State<MasliveSkeleton> createState() => _MasliveSkeletonState();
}

class _MasliveSkeletonState extends State<MasliveSkeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: Color.lerp(MasliveTokens.line, MasliveTokens.bg, t),
            borderRadius: BorderRadius.circular(widget.borderRadius ?? MasliveTokens.rS),
          ),
        );
      },
    );
  }
}

/// Ligne de carte skeleton prete a l'emploi (avatar + deux lignes de texte),
/// pour les listes en cours de chargement (commandes, produits, messages...).
class MasliveSkeletonListTile extends StatelessWidget {
  const MasliveSkeletonListTile({super.key, this.showLeading = true});

  final bool showLeading;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Row(
        children: [
          if (showLeading) ...[
            const MasliveSkeleton(width: 44, height: 44, borderRadius: MasliveTokens.rM),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                MasliveSkeleton(width: double.infinity, height: 14),
                SizedBox(height: 8),
                MasliveSkeleton(width: 120, height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
