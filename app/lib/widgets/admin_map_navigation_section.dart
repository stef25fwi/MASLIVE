import 'package:flutter/material.dart';

/// Section "Carte & Navigation" clean (nouveau workflow)
/// - 2 tuiles en ligne (Créer un circuit / MapMarket)
/// - 1 tuile pleine largeur (Points d'intérêt)
class AdminMapNavigationSection extends StatelessWidget {
  final VoidCallback onCreateCircuit;
  final VoidCallback onOpenMapMarket;
  final VoidCallback onOpenPois;

  const AdminMapNavigationSection({
    super.key,
    required this.onCreateCircuit,
    required this.onOpenMapMarket,
    required this.onOpenPois,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          icon: Icons.map_outlined,
          title: 'Carte & Navigation',
        ),
        const SizedBox(height: 14),

        LayoutBuilder(
          builder: (context, c) {
            // Responsive: en très petit écran, on passe en 1 colonne.
            final isNarrow = c.maxWidth < 360;
            final gap = 14.0;

            if (isNarrow) {
              return Column(
                children: [
                  _AdminToolTile(
                    icon: Icons.auto_awesome_outlined,
                    iconBg: const Color(0xFFEFE7FF),
                    iconColor: const Color(0xFF7C3AED),
                    title: 'Créer un circuit',
                    subtitle: 'Création guidée\nétape par étape',
                    onTap: onCreateCircuit,
                  ),
                  const SizedBox(height: 14),
                  _AdminToolTile(
                    icon: Icons.folder_open_outlined,
                    iconBg: const Color(0xFFE8F4FF),
                    iconColor: const Color(0xFF2563EB),
                    title: 'MapMarket',
                    subtitle: 'Structurer, éditer et\npublier les cartes',
                    onTap: onOpenMapMarket,
                  ),
                  const SizedBox(height: 14),
                  _AdminToolTile(
                    icon: Icons.place_outlined,
                    iconBg: const Color(0xFFFFF1E6),
                    iconColor: const Color(0xFFF59E0B),
                    title: "Points d'intérêt",
                    subtitle: 'Gérer les points par couche',
                    onTap: onOpenPois,
                    fullWidth: true,
                  ),
                ],
              );
            }

            // 2 colonnes + dernière pleine largeur
            final tileW = (c.maxWidth - gap) / 2;

            return Column(
              children: [
                Row(
                  children: [
                    SizedBox(
                      width: tileW,
                      child: _AdminToolTile(
                        icon: Icons.auto_awesome_outlined,
                        iconBg: const Color(0xFFEFE7FF),
                        iconColor: const Color(0xFF7C3AED),
                        title: 'Créer un circuit',
                        subtitle: 'Création guidée\nétape par étape',
                        onTap: onCreateCircuit,
                      ),
                    ),
                    SizedBox(width: gap),
                    SizedBox(
                      width: tileW,
                      child: _AdminToolTile(
                        icon: Icons.folder_open_outlined,
                        iconBg: const Color(0xFFE8F4FF),
                        iconColor: const Color(0xFF2563EB),
                        title: 'MapMarket',
                        subtitle: 'Structurer, éditer et\npublier les cartes',
                        onTap: onOpenMapMarket,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _AdminToolTile(
                  icon: Icons.place_outlined,
                  iconBg: const Color(0xFFFFF1E6),
                  iconColor: const Color(0xFFF59E0B),
                  title: "Points d'intérêt",
                  subtitle: 'Gérer les points par couche',
                  onTap: onOpenPois,
                  fullWidth: true,
                ),
                const SizedBox(height: 2),
                // Optionnel : petit texte aide
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'Conseil : crée d\'abord le circuit avec le Wizard, puis gère la publication dans MapMarket.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.55),
                      height: 1.25,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;

  const _SectionHeader({
    required this.icon,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Icon(
          icon,
          size: 22,
          color: theme.colorScheme.onSurface.withOpacity(0.65),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.2,
          ),
        ),
      ],
    );
  }
}

class _AdminToolTile extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool fullWidth;

  const _AdminToolTile({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: theme.colorScheme.onSurface.withOpacity(0.06),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _IconBadge(
                  icon: icon,
                  bg: iconBg,
                  color: iconColor,
                ),
                const SizedBox(height: 14),
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    height: 1.22,
                    color: theme.colorScheme.onSurface.withOpacity(0.58),
                  ),
                ),
                const SizedBox(height: 2),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _IconBadge extends StatelessWidget {
  final IconData icon;
  final Color bg;
  final Color color;

  const _IconBadge({
    required this.icon,
    required this.bg,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
      ),
      alignment: Alignment.center,
      child: Icon(
        icon,
        color: color,
        size: 28,
      ),
    );
  }
}
