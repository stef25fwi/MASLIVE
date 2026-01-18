import 'package:flutter/material.dart';

import '../ui/theme/maslive_theme.dart';
import '../ui/widgets/gradient_header.dart';
import '../ui/widgets/honeycomb_background.dart';
import '../ui/widgets/maslive_card.dart';

class AccountUiPage extends StatelessWidget {
  const AccountUiPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Dummy data (remplace par SessionScope si besoin)
    const userName = 'Stéphane';
    const userSubtitle = 'Premium Member';

    final tiles = <_AccountTileData>[
      const _AccountTileData(
        icon: Icons.favorite_border,
        title: 'Mes favoris',
        subtitle: 'Lieux et groupes enregistrés',
      ),
      const _AccountTileData(
        icon: Icons.groups_2_rounded,
        title: 'Mes groupes',
        subtitle: 'Accéder à vos communautés',
      ),
      const _AccountTileData(
        icon: Icons.notifications_none_rounded,
        title: 'Notifications',
        subtitle: 'Gérer vos alertes',
      ),
      const _AccountTileData(
        icon: Icons.settings_outlined,
        title: 'Paramètres',
        subtitle: 'Langue, confidentialité…',
      ),
      const _AccountTileData(
        icon: Icons.help_outline_rounded,
        title: 'Aide',
        subtitle: 'FAQ & support',
      ),
    ];

    return Scaffold(
      body: HoneycombBackground(
        opacity: 0.08,
        child: Column(
          children: [
            MasliveGradientHeader(
              height: 210,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      const Spacer(),
                      Text(
                        'Mon compte',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: MasliveTheme.textPrimary,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded),
                        color: MasliveTheme.textPrimary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _AvatarBlock(
                    name: userName,
                    subtitle: userSubtitle,
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
                itemCount: tiles.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, i) {
                  final t = tiles[i];
                  return MasliveCard(
                    radius: 20,
                    padding: EdgeInsets.zero,
                    child: ListTile(
                      leading: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: MasliveTheme.surfaceAlt,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: MasliveTheme.divider),
                        ),
                        child: Icon(t.icon, color: MasliveTheme.textPrimary),
                      ),
                      title: Text(
                        t.title,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: MasliveTheme.textPrimary,
                            ),
                      ),
                      subtitle: Text(
                        t.subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: MasliveTheme.textSecondary,
                            ),
                      ),
                      trailing: Icon(
                        Icons.chevron_right_rounded,
                        color: MasliveTheme.textSecondary,
                      ),
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('${t.title} (mock)')),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AvatarBlock extends StatelessWidget {
  final String name;
  final String subtitle;

  const _AvatarBlock({
    required this.name,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 84,
          height: 84,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: MasliveTheme.actionGradient,
            boxShadow: MasliveTheme.floatingShadow,
          ),
          child: const Center(
            child: CircleAvatar(
              radius: 36,
              backgroundColor: Colors.white,
              child: Icon(Icons.person_rounded, size: 40, color: MasliveTheme.textPrimary),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          name,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: MasliveTheme.textPrimary,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: MasliveTheme.textSecondary,
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );
  }
}

class _AccountTileData {
  final IconData icon;
  final String title;
  final String subtitle;

  const _AccountTileData({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
}
