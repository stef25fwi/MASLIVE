import 'package:flutter/material.dart';

import 'account_admin_page.dart';
import '../services/auth_service.dart';
import '../services/auth_claims_service.dart';
import '../ui/theme/maslive_theme.dart';
import '../widgets/rainbow_header.dart';
import '../ui/widgets/honeycomb_background.dart';
import '../ui/widgets/maslive_card.dart';
import '../l10n/app_localizations.dart';

class AccountUiPage extends StatefulWidget {
  const AccountUiPage({super.key});

  @override
  State<AccountUiPage> createState() => _AccountUiPageState();
}

class _AccountUiPageState extends State<AccountUiPage> {
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _checkAdminStatus();
  }

  Future<void> _checkAdminStatus() async {
    try {
      final appUser = await AuthClaimsService.instance.getCurrentAppUser();
      if (!mounted) return;
      if (appUser != null) {
        setState(() {
          _isAdmin = appUser.isAdmin;
        });
      }
    } catch (e) {
      // Fallback to old method
      final user = AuthService.instance.currentUser;
      if (user != null) {
        final profile = await AuthService.instance.getUserProfile(user.uid);
        if (!mounted) return;
        setState(() {
          _isAdmin = profile?.isAdmin ?? false;
        });
      }
    }
  }

  void _navigateTo(BuildContext context, _AccountTileData t) {
    if (t.route == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${t.title} (mock)')));
      return;
    }
    try {
      Navigator.pushNamed(context, t.route!);
    } catch (_) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${t.title} indisponible')));
    }
  }

  @override
  Widget build(BuildContext context) {
    // Dummy data (remplace par SessionScope si besoin)
    const userName = 'Stéphane';
    final userSubtitle = AppLocalizations.of(context)!.premiumMember;

    final l10n = AppLocalizations.of(context)!;
    final tiles = <_AccountTileData>[
      _AccountTileData(
        icon: Icons.favorite_border,
        title: l10n.myFavorites,
        subtitle: l10n.savedPlacesGroups,
        route: '/favorites',
      ),
      _AccountTileData(
        icon: Icons.business_center_outlined,
        title: 'Compte professionnel',
        subtitle: 'Demande + paiements Stripe',
        route: '/business',
      ),
      _AccountTileData(
        icon: Icons.shopping_bag_outlined,
        title: 'Historique des achats',
        subtitle: 'Mes commandes et photos',
        route: '/purchase-history',
      ),
      _AccountTileData(
        icon: Icons.groups_2_rounded,
        title: l10n.myGroups,
        subtitle: l10n.accessYourCommunities,
        route: '/groups',
      ),
      _AccountTileData(
        icon: Icons.notifications_none_rounded,
        title: l10n.manageAlerts,
        subtitle: l10n.manageAlerts,
        route: '/alerts',
      ),
      _AccountTileData(
        icon: Icons.settings_outlined,
        title: l10n.languagePrivacy,
        subtitle: l10n.languagePrivacy,
        route: '/settings',
      ),
      _AccountTileData(
        icon: Icons.help_outline_rounded,
        title: l10n.help,
        subtitle: l10n.faqSupport,
        route: '/help',
      ),
    ];

    if (_isAdmin) {
      tiles.add(
        _AccountTileData(
          icon: Icons.verified_user_outlined,
          title: 'Demandes pro',
          subtitle: 'Valider/refuser les comptes professionnels',
          route: '/admin/business-requests',
        ),
      );
    }

    return Scaffold(
      body: HoneycombBackground(
        child: CustomScrollView(
          slivers: [
            const SliverToBoxAdapter(
              child: RainbowHeader(
                title: 'Mon Profil',
                trailing: Icon(
                  Icons.account_circle_outlined,
                  color: Colors.white,
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 16),
                child: _AvatarBlock(name: userName, subtitle: userSubtitle),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 18),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((context, i) {
                  if (i < tiles.length) {
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
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: MasliveTheme.textPrimary,
                              ),
                        ),
                        subtitle: Text(
                          t.subtitle,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: MasliveTheme.textSecondary),
                        ),
                        trailing: Icon(
                          Icons.chevron_right_rounded,
                          color: MasliveTheme.textSecondary,
                        ),
                        onTap: () => _navigateTo(context, t),
                      ),
                    );
                  }

                  if (_isAdmin && i == tiles.length) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: Text(
                            AppLocalizations.of(context)!.administration,
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: MasliveTheme.textSecondary,
                                ),
                          ),
                        ),
                      ],
                    );
                  }

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
                          child: const Icon(
                            Icons.admin_panel_settings_rounded,
                            color: MasliveTheme.textPrimary,
                          ),
                        ),
                        title: Text(
                          AppLocalizations.of(context)!.adminSpace,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: MasliveTheme.textPrimary,
                              ),
                        ),
                        subtitle: Text(
                          AppLocalizations.of(context)!.manageApp,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: MasliveTheme.textSecondary),
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

                  return const SizedBox.shrink();
                }, childCount: tiles.length + (_isAdmin ? 2 : 0)),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      await AuthService.instance.signOut();
                      if (context.mounted) {
                        Navigator.of(
                          context,
                        ).pushNamedAndRemoveUntil('/login', (route) => false);
                      }
                    },
                    icon: const Icon(Icons.logout_rounded),
                    label: Text(AppLocalizations.of(context)!.disconnect),
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

  const _AvatarBlock({required this.name, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: MasliveTheme.actionGradient,
            boxShadow: MasliveTheme.floatingShadow,
          ),
          child: const Center(
            child: CircleAvatar(
              radius: 36,
              backgroundColor: Colors.white,
              child: Icon(
                Icons.person_rounded,
                size: 38,
                color: MasliveTheme.textPrimary,
              ),
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
  final String? route;

  const _AccountTileData({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.route,
  });
}
