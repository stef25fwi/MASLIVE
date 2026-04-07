
import 'package:flutter/material.dart';
import '../theme/maslive_theme.dart';

class MasliveGradientIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final double size;
  final double iconSize;
  final String? tooltip;
  final String? label;

  const MasliveGradientIconButton({
    super.key,
    required this.icon,
    this.onTap,
    this.size = 46,
    this.iconSize = 22,
    this.tooltip,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    final hasLabel = label != null && label!.trim().isNotEmpty;
    final Widget buttonChild = hasLabel
        ? Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(icon, color: Colors.white, size: iconSize),
              const SizedBox(height: 2),
              Text(
                label!,
                maxLines: 1,
                overflow: TextOverflow.fade,
                softWrap: false,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 8.5,
                  fontWeight: FontWeight.w800,
                  height: 1,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          )
        : Icon(icon, color: Colors.white, size: iconSize);

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
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF9B6BFF).withValues(alpha: 0.22),
                blurRadius: 18,
                spreadRadius: 1,
                offset: const Offset(0, 10),
              ),
              BoxShadow(
                color: const Color(0xFFFF7AAE).withValues(alpha: 0.16),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: buttonChild,
        ),
      ),
    );

    if (tooltip == null) return button;
    return Tooltip(message: tooltip!, child: button);
  }
}
