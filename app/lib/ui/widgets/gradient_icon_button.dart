import 'package:flutter/material.dart';
import '../theme/maslive_theme.dart';

class MasliveGradientIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final double size;
  final String? tooltip;

  const MasliveGradientIconButton({
    super.key,
    required this.icon,
    this.onTap,
    this.size = 46,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final button = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: MasliveTheme.actionGradient,
            boxShadow: MasliveTheme.floatingShadow,
          ),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      ),
    );

    if (tooltip == null) return button;
    return Tooltip(message: tooltip!, child: button);
  }
}
