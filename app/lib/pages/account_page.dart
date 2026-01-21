import 'package:flutter/material.dart';

import 'account_admin_page.dart';
import '../services/auth_service.dart';
import '../services/auth_claims_service.dart';
import '../ui/theme/maslive_theme.dart';
import '../ui/widgets/gradient_header.dart';
import '../ui/widgets/honeycomb_background.dart';
import '../ui/widgets/maslive_card.dart';

class AccountUiPage extends StatefulWidget {
  const AccountUiPage({super.key});

  @override
  State<AccountUiPage> createState() => _AccountUiPageState();
}

class _AccountUiPageState extends State<AccountUiPage> {
  bool _isAdmin = false;
  bool _isSuperAdmin = false;

  @override
  void initState() {
    super.initState();
    _checkAdminStatus();
  }

  Future<void> _checkAdminStatus() async {
    try {
      final appUser = await AuthClaimsService.instance.getCurrentAppUser();
      if (appUser != null) {
        setState(() {
          _isAdmin = appUser.isAdmin;
          _isSuperAdmin = appUser.role.toString() == 'superAdmin';
        });
      }
    } catch (e) {
      // Fallback to old method
      final user = AuthService.instance.currentUser;
      if (user != null) {
        final profile = await AuthService.instance.getUserProfile(user.uid);
        setState(() {
          _isAdmin = profile?.isAdmin ?? false;
          _isSuperAdmin = profile?.role.toString() == 'superAdmin';
        });
      }
    }
  }

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
              height: 200,
              borderRadius: BorderRadius.zero,
              padding: const EdgeInsets.fromLTRB(20, 26, 20, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded),
                        color: MasliveTheme.textPrimary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
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
                itemCount: tiles.length + (_isAdmin ? 2 : 0),
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, i) {
                  // Section admin
                  if (_isAdmin && i == tiles.length) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Text(
                            'Administration',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: MasliveTheme.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    );
                  }
                  
                  // Bouton Espace Admin
                  if (_isAdmin && i == tiles.length + 1) {
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
                          child: const Icon(Icons.admin_panel_settings_rounded, color: MasliveTheme.textPrimary),
                        ),
                        title: Text(
                          'Espace Administrateur',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: MasliveTheme.textPrimary,
                          ),
                        ),
                        subtitle: Text(
                          'Gérer l\'application',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: MasliveTheme.textSecondary,
                          ),
                        ),
                        trailing: Icon(
                          Icons.chevron_right_rounded,
                          color: MasliveTheme.textSecondary,
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const AccountAndAdminPage(),
                            ),
                          );
                        },
                      ),
                    );
                  }

                  // Tiles normaux
                  final tileIndex = _isSuperAdmin ? (i - 1) : (_isAdmin && i > tiles.length ? i - 1 : i);
                  if (tileIndex < 0 || tileIndex >= tiles.length) return const SizedBox.shrink();
                  final t = tiles[tileIndex];
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
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    await AuthService().signOut();
                    if (context.mounted) {
                      Navigator.of(context).pushNamedAndRemoveUntil(
                        '/login',
                        (route) => false,
                      );
                    }
                  },
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('Se déconnecter'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
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
          width: 92,
          height: 92,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: MasliveTheme.actionGradient,
            boxShadow: MasliveTheme.floatingShadow,
          ),
          child: const Center(
            child: CircleAvatar(
              radius: 40,
              backgroundColor: Colors.white,
              child: Icon(Icons.person_rounded, size: 42, color: MasliveTheme.textPrimary),
            ),
          ),
        ),
        const SizedBox(height: 6),
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
