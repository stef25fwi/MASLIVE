import 'package:flutter/material.dart';
import 'honeycomb_background.dart';

class PrestoBottomNav extends StatelessWidget {
  final int index;
  final ValueChanged<int> onTap;
  final VoidCallback onPlus;

  const PrestoBottomNav({
    super.key,
    required this.index,
    required this.onTap,
    required this.onPlus,
  });

  static const barHeight = 78.0;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: barHeight + MediaQuery.of(context).padding.bottom,
      child: Stack(
        children: [
          // Barre sombre avec honeycomb
          Positioned.fill(
            child: Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).padding.bottom,
              ),
              decoration: const BoxDecoration(color: Color(0xFF171A20)),
              child: ClipRRect(
                child: Opacity(
                  opacity: 0.20,
                  child: HoneycombBackground(
                    child: Container(color: Colors.transparent),
                  ),
                ),
              ),
            ),
          ),

          // Items
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _NavIcon(
                    icon: Icons.near_me_rounded,
                    label: '',
                    selected: index == 0,
                    onTap: () => onTap(0),
                  ),
                  _NavIcon(
                    icon: Icons.search_rounded,
                    label: '',
                    selected: index == 1,
                    onTap: () => onTap(1),
                  ),
                  _NavIcon(
                    icon: Icons.movie_creation_outlined,
                    label: '',
                    selected: index == 2,
                    onTap: () => onTap(2),
                  ),
                  _NavIcon(
                    icon: Icons.person_rounded,
                    label: '',
                    selected: index == 3,
                    onTap: () => onTap(3),
                  ),
                ],
              ),
            ),
          ),

          // Bouton + (rond dégradé) en bas à droite
          Positioned(
            right: 14,
            bottom: 16 + MediaQuery.of(context).padding.bottom,
            child: _PlusButton(onTap: onPlus),
          ),
        ],
      ),
    );
  }
}

class _NavIcon extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavIcon({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? Colors.white : Colors.white.withOpacity(0.65);
    return InkResponse(
      onTap: onTap,
      radius: 28,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        child: Icon(icon, color: color, size: 24),
      ),
    );
  }
}

class _PlusButton extends StatelessWidget {
  final VoidCallback onTap;
  const _PlusButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFFFE36A), Color(0xFFFF7BC5), Color(0xFF7CE0FF)],
            ),
            boxShadow: [
              BoxShadow(
                blurRadius: 18,
                offset: Offset(0, 10),
                color: Color(0x59000000),
              ),
            ],
          ),
          child: const Icon(Icons.add_rounded, color: Colors.white, size: 30),
        ),
      ),
    );
  }
}
