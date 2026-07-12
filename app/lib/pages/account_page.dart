import 'package:flutter/material.dart';

import '../admin/admin_debug_logs_sheet.dart';
import '../l10n/app_localizations.dart';
import '../security/profile_capability_policy.dart';
import '../services/auth_service.dart';
import '../ui/theme/maslive_theme.dart';
import '../ui/widgets/honeycomb_background.dart';
import '../utils/debug_log_buffer.dart';
import '../widgets/cart/cart_icon_badge.dart';
import '../widgets/commerce/commerce_section_card.dart';
import '../widgets/rainbow_header.dart';
import '../ui/widgets/maslive_card.dart';
import 'account_admin_page.dart';
import 'user_facing_bottom_bar.dart';

class AccountUiPage extends StatefulWidget {
  const AccountUiPage({super.key, this.showBottomBar = true});

  final bool showBottomBar;

  @override
  State<AccountUiPage> createState() => _AccountUiPageState();
}

class _AccountUiPageState extends State<AccountUiPage> {
  late Future<ProfileCapabilities?> _profileFuture;

  @override
  void initState() {
    super.initState();
    DebugLogBuffer.setActiveScope('Mon Profil');
    _profileFuture = ProfileCapabilityPolicy.instance.resolveCurrent();
  }

  @override
  void dispose() {
    DebugLogBuffer.clearActiveScope();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() {
      _profileFuture = ProfileCapabilityPolicy.instance.resolveCurrent();
    });
    await _profileFuture;
  }

  void _navigateTo(BuildContext context, _AccountTileData tile) {
    if (tile.route == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${tile.title} indisponible')),
      );
      return;
    }
    try {
      Navigator.pushNamed(context, tile.route!, arguments: tile.arguments);
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${tile.title} indisponible')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return FutureBuilder<ProfileCapabilities?>(
      future: _profileFuture,
      builder: (context, snapshot) {
        final profile = snapshot.data;
        final isLoading = snapshot.connectionState == ConnectionState.waiting;
        final isAdmin = profile?.can(Capability.accessAdminPanel) ?? false;
        final tiles = profile == null ? <_AccountTileData>[] : _buildTiles(context, profile, l10n);

        return Scaffold(
          bottomNavigationBar: widget.showBottomBar
              ? const UserFacingBottomBar(currentTab: UserFacingBottomBarTab.profile)
              : null,
          body: HoneycombBackground(
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: RainbowHeader(
                      title: 'Mon Profil',
                      leading: IconButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: Colors.white,
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isAdmin) const AdminDebugLogsButton(scopeLabel: 'Mon Profil'),
                          if (isAdmin) const SizedBox(width: 4),
                          CartIconBadge(
                            iconColor: const Color(0xFF111827),
                            backgroundColor: Colors.white.withValues(alpha: 0.16),
                            borderColor: Colors.white.withValues(alpha: 0.22),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (isLoading)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (profile == null)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _SignedOutBlock(onRetry: _refresh),
                    )
                  else ...[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: _AvatarBlock(profile: profile),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(10, 14, 10, 0),
                        child: _CapabilitySummaryCard(profile: profile),
                      ),
                    ),
                    if (profile.canSubmitCommerce)
                      const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                          child: CommerceSectionCard(),
                        ),
                      ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(10, 20, 10, 18),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate((context, index) {
                          if (index < tiles.length) {
                            final tile = tiles[index];
                            return _AccountTile(tile: tile, onTap: () => _navigateTo(context, tile));
                          }

                          if (isAdmin && index == tiles.length) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              child: Text(
                                AppLocalizations.of(context)!.administration,
                                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      color: MasliveTheme.textSecondary,
                                    ),
                              ),
                            );
                          }

                          if (isAdmin && index == tiles.length + 1) {
                            return _AccountTile(
                              tile: _AccountTileData(
                                icon: Icons.admin_panel_settings_rounded,
                                title: AppLocalizations.of(context)!.adminSpace,
                                subtitle: AppLocalizations.of(context)!.manageApp,
                              ),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const AccountAndAdminPage()),
                                );
                              },
                            );
                          }

                          return const SizedBox.shrink();
                        }, childCount: tiles.length + (isAdmin ? 2 : 0)),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(10, 0, 10, 18),
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              await AuthService.instance.signOut();
                              if (context.mounted) {
                                Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
                              }
                            },
                            icon: const Icon(Icons.logout_rounded),
                            label: Text(AppLocalizations.of(context)!.disconnect),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue.shade600,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  List<_AccountTileData> _buildTiles(
    BuildContext context,
    ProfileCapabilities profile,
    AppLocalizations l10n,
  ) {
    final tiles = <_AccountTileData>[
      const _AccountTileData(
        icon: Icons.person_outline_rounded,
        title: 'Mon profil & sécurité',
        subtitle: 'Nom, photo, préférences et sécurité',
        route: '/account',
      ),
      const _AccountTileData(
        icon: Icons.favorite_border,
        title: 'Mes favoris & groupes',
        subtitle: 'Lieux et communautés enregistrés',
        route: '/favorites',
      ),
      const _AccountTileData(
        icon: Icons.shopping_bag_outlined,
        title: 'Historique des achats',
        subtitle: 'Mes commandes et photos',
        route: '/purchase-history',
      ),
      const _AccountTileData(
        icon: Icons.shopping_cart_outlined,
        title: 'Panier',
        subtitle: 'Retrouver tous mes achats en attente',
        route: '/cart',
      ),
      const _AccountTileData(
        icon: Icons.photo_library_outlined,
        title: 'Marché des médias',
        subtitle: 'Parcourir les galeries et packs photo',
        route: '/media-marketplace',
      ),
      const _AccountTileData(
        icon: Icons.download_outlined,
        title: 'Mes téléchargements',
        subtitle: 'Accéder à mes médias achetés',
        route: '/media-marketplace',
        arguments: <String, dynamic>{'initialTab': 'downloads'},
      ),
      _AccountTileData(
        icon: Icons.notifications_none_rounded,
        title: l10n.manageAlerts,
        subtitle: 'Alertes et notifications utiles',
        route: '/alerts',
      ),
      _AccountTileData(
        icon: Icons.settings_outlined,
        title: l10n.languagePrivacy,
        subtitle: 'Langue, confidentialité et préférences',
        route: '/settings',
      ),
      _AccountTileData(
        icon: Icons.help_outline_rounded,
        title: l10n.help,
        subtitle: l10n.faqSupport,
        route: '/help',
      ),
    ];

    if (profile.hasBusiness || profile.can(Capability.manageOwnBusiness)) {
      tiles.insert(
        1,
        _AccountTileData(
          icon: Icons.business_center_outlined,
          title: profile.hasBusiness ? 'Compte professionnel' : 'Demander un compte Pro',
          subtitle: profile.hasBusiness ? 'Demande + paiements Stripe' : 'Créer un espace de vente validé',
          route: profile.hasBusiness ? '/business' : '/business-request',
        ),
      );
    }

    if (profile.can(Capability.submitProduct)) {
      tiles.insert(
        2,
        const _AccountTileData(
          icon: Icons.add_business_outlined,
          title: 'Créer un produit',
          subtitle: 'Soumettre un article à la validation',
          route: '/commerce/create-product',
        ),
      );
    }

    if (profile.can(Capability.submitMedia)) {
      tiles.insert(
        3,
        const _AccountTileData(
          icon: Icons.add_photo_alternate_outlined,
          title: 'Créer un média',
          subtitle: 'Soumettre photo ou contenu digital',
          route: '/commerce/create-media',
        ),
      );
    }

    if (profile.hasPhotographerProfile || profile.can(Capability.manageOwnGallery)) {
      tiles.insertAll(4, const <_AccountTileData>[
        _AccountTileData(
          icon: Icons.camera_alt_outlined,
          title: 'Espace photographe',
          subtitle: 'Gérer mes galeries, ventes et stats',
          route: '/media-marketplace',
          arguments: <String, dynamic>{'initialTab': 'photographer'},
        ),
        _AccountTileData(
          icon: Icons.workspace_premium_outlined,
          title: 'Abonnement photographe',
          subtitle: 'Gérer ma formule marché des médias',
          route: '/media-marketplace/subscription',
        ),
      ]);
    }

    if (profile.can(Capability.manageGroupTracking)) {
      tiles.insert(
        1,
        const _AccountTileData(
          icon: Icons.groups_2_outlined,
          title: 'Admin Groupe',
          subtitle: 'Code, trackers, carte live et exports',
          route: '/group-admin',
        ),
      );
    } else if (profile.can(Capability.trackOwnLocation)) {
      tiles.insert(
        1,
        const _AccountTileData(
          icon: Icons.my_location_outlined,
          title: 'Tracker Groupe',
          subtitle: 'Rattachement, suivi GPS et historique',
          route: '/group-tracker',
        ),
      );
    } else if (profile.can(Capability.requestGroupAdmin)) {
      tiles.add(
        _AccountTileData(
          icon: profile.hasPendingGroupAdminRequest ? Icons.pending_actions_rounded : Icons.group_add_outlined,
          title: profile.hasPendingGroupAdminRequest ? 'Demande Admin Groupe en attente' : 'Demander Admin Groupe',
          subtitle: profile.hasPendingGroupAdminRequest
              ? 'Validation MASLIVE requise avant activation'
              : 'Créer un groupe de tracking après validation',
          route: '/group-admin',
        ),
      );
    }

    return tiles;
  }
}

class _AccountTile extends StatelessWidget {
  const _AccountTile({required this.tile, required this.onTap});

  final _AccountTileData tile;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
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
          child: Icon(tile.icon, color: MasliveTheme.textPrimary),
        ),
        title: Text(
          tile.title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: MasliveTheme.textPrimary,
              ),
        ),
        subtitle: Text(
          tile.subtitle,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: MasliveTheme.textSecondary),
        ),
        trailing: Icon(Icons.chevron_right_rounded, color: MasliveTheme.textSecondary),
        onTap: onTap,
      ),
    );
  }
}

class _AvatarBlock extends StatelessWidget {
  const _AvatarBlock({required this.profile});

  final ProfileCapabilities profile;

  @override
  Widget build(BuildContext context) {
    final photoUrl = profile.photoUrl;
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
          child: Center(
            child: CircleAvatar(
              radius: 36,
              backgroundColor: Colors.white,
              backgroundImage: photoUrl == null || photoUrl.isEmpty ? null : NetworkImage(photoUrl),
              child: photoUrl == null || photoUrl.isEmpty
                  ? const Icon(Icons.person_rounded, size: 38, color: MasliveTheme.textPrimary)
                  : null,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          profile.displayName.isEmpty ? profile.email : profile.displayName,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: MasliveTheme.textPrimary,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          profile.roleLabel,
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

class _CapabilitySummaryCard extends StatelessWidget {
  const _CapabilitySummaryCard({required this.profile});

  final ProfileCapabilities profile;

  @override
  Widget build(BuildContext context) {
    final chips = <String>[
      profile.roleLabel,
      if (profile.canSubmitCommerce) 'Commerce autorisé',
      if (profile.hasPhotographerProfile) 'Photographe validé',
      if (profile.can(Capability.trackOwnLocation)) 'Tracking GPS',
      if (profile.can(Capability.accessAdminPanel)) 'Admin',
      if (profile.hasPendingGroupAdminRequest) 'Demande groupe en attente',
    ];

    return MasliveCard(
      radius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Droits actifs',
            style: TextStyle(fontWeight: FontWeight.w900, color: MasliveTheme.textPrimary),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: chips
                .map(
                  (chip) => Chip(
                    label: Text(chip),
                    visualDensity: VisualDensity.compact,
                    backgroundColor: MasliveTheme.surfaceAlt,
                    side: const BorderSide(color: MasliveTheme.divider),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _SignedOutBlock extends StatelessWidget {
  const _SignedOutBlock({required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.lock_outline_rounded, size: 56, color: MasliveTheme.textSecondary),
          const SizedBox(height: 16),
          const Text(
            'Connectez-vous pour voir votre profil MASLIVE.',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Réessayer'),
          ),
        ],
      ),
    );
  }
}

class _AccountTileData {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? route;
  final Object? arguments;

  const _AccountTileData({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.route,
    this.arguments,
  });
}
