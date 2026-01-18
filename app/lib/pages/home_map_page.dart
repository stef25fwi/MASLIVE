import 'package:flutter/material.dart';
import '../ui/theme/maslive_theme.dart';
import '../ui/widgets/gradient_header.dart';
import '../ui/widgets/gradient_icon_button.dart';
import '../ui/widgets/honeycomb_background.dart';
import '../ui/widgets/maslive_bottom_nav.dart';
import '../ui/widgets/maslive_card.dart';

enum _MapAction { ville, tracking, visiter, encadrement, food }

class HomeMapPage extends StatefulWidget {
  const HomeMapPage({super.key});

  @override
  State<HomeMapPage> createState() => _HomeMapPageState();
}

class _HomeMapPageState extends State<HomeMapPage> {
  _MapAction _selected = _MapAction.ville;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: HoneycombBackground(
        opacity: 0.08,
        child: Stack(
          children: [
            Column(
              children: [
                MasliveGradientHeader(
                  height: 170,
                  child: Row(
                    children: [
                      Expanded(
                        child: _SearchPill(
                          hint: 'Recherche / Ville',
                          onTap: () {},
                        ),
                      ),
                      const SizedBox(width: 12),
                      MasliveGradientIconButton(
                        icon: Icons.menu_rounded,
                        tooltip: 'Menu',
                        onTap: () {
                          Navigator.pushNamed(context, '/account-ui');
                        },
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                    child: Stack(
                      children: [
                        // Carte (mock)
                        MasliveCard(
                          radius: 22,
                          padding: EdgeInsets.zero,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(22),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Container(
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Color(0xFFF1F4FF),
                                        Color(0xFFFFF3F8),
                                        Color(0xFFF8F7FF),
                                      ],
                                    ),
                                  ),
                                ),
                                Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.map_rounded, color: MasliveTheme.textSecondary.withOpacity(0.7), size: 44),
                                      const SizedBox(height: 10),
                                      Text(
                                        'Carte',
                                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                              color: MasliveTheme.textPrimary,
                                              fontWeight: FontWeight.w800,
                                            ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        'Mockup UI/UX (à connecter à la vraie carte)',
                                        style: Theme.of(context).textTheme.bodySmall,
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Actions verticales à droite
                        Positioned(
                          right: 12,
                          top: 18,
                          child: _RightActions(
                            selected: _selected,
                            onChanged: (v) => setState(() => _selected = v),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Bottom bar + FAB
                MasliveBottomNav(
                  index: 0,
                  onTap: (i) {
                    if (i == 0) return;
                    if (i == 2) Navigator.pushNamed(context, '/shop-ui');
                    if (i == 3) Navigator.pushNamed(context, '/account-ui');
                  },
                  onPlus: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Action + (mock)')),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchPill extends StatelessWidget {
  final String hint;
  final VoidCallback onTap;

  const _SearchPill({
    required this.hint,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(MasliveTheme.rPill),
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.86),
          borderRadius: BorderRadius.circular(MasliveTheme.rPill),
          border: Border.all(color: Colors.white.withOpacity(0.55)),
          boxShadow: MasliveTheme.cardShadow,
        ),
        child: Row(
          children: [
            Icon(Icons.search_rounded, color: MasliveTheme.textSecondary.withOpacity(0.9)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                hint,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: MasliveTheme.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.75),
                borderRadius: BorderRadius.circular(MasliveTheme.rPill),
                border: Border.all(color: MasliveTheme.divider),
              ),
              child: Text(
                'Ville',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: MasliveTheme.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RightActions extends StatelessWidget {
  final _MapAction selected;
  final ValueChanged<_MapAction> onChanged;

  const _RightActions({
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ActionItem(
          label: 'Ville',
          icon: Icons.location_city_rounded,
          selected: selected == _MapAction.ville,
          onTap: () => onChanged(_MapAction.ville),
        ),
        const SizedBox(height: 12),
        _ActionItem(
          label: 'Tracking',
          icon: Icons.track_changes_rounded,
          selected: selected == _MapAction.tracking,
          onTap: () => onChanged(_MapAction.tracking),
        ),
        const SizedBox(height: 12),
        _ActionItem(
          label: 'Visiter',
          icon: Icons.map_outlined,
          selected: selected == _MapAction.visiter,
          onTap: () => onChanged(_MapAction.visiter),
        ),
        const SizedBox(height: 12),
        _ActionItem(
          label: 'Encad.',
          icon: Icons.shield_outlined,
          selected: selected == _MapAction.encadrement,
          onTap: () => onChanged(_MapAction.encadrement),
        ),
        const SizedBox(height: 12),
        _ActionItem(
          label: 'Food',
          icon: Icons.restaurant_rounded,
          selected: selected == _MapAction.food,
          onTap: () => onChanged(_MapAction.food),
        ),
      ],
    );
  }
}

class _ActionItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _ActionItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Opacity(
          opacity: selected ? 1.0 : 0.75,
          child: MasliveGradientIconButton(
            icon: icon,
            tooltip: label,
            onTap: onTap,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.86),
            borderRadius: BorderRadius.circular(MasliveTheme.rPill),
            border: Border.all(color: MasliveTheme.divider),
            boxShadow: selected ? MasliveTheme.cardShadow : const [],
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: selected ? MasliveTheme.textPrimary : MasliveTheme.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
      ],
    );
  }
}
