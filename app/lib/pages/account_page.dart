import 'package:flutter/material.dart';

import '../admin/admin_debug_logs_sheet.dart';
import '../l10n/app_localizations.dart';
import '../security/profile_capability_policy.dart';
import '../services/auth_service.dart';
import '../ui/theme/maslive_theme.dart';
import '../ui/widgets/honeycomb_background.dart';
import '../ui/widgets/maslive_card.dart';
import '../utils/debug_log_buffer.dart';
import '../widgets/cart/cart_icon_badge.dart';
import '../widgets/commerce/commerce_section_card.dart';
import '../widgets/rainbow_header.dart';
import 'user_facing_bottom_bar.dart';
import 'package:masslive/ui_kit/tokens/maslive_tokens.dart';

class AccountUiPage extends StatefulWidget {
  const AccountUiPage({super.key, this.showBottomBar = true});

  final bool showBottomBar;

  @override
  State<AccountUiPage> createState() => _AccountUiPageState();
}

class _AccountUiPageState extends State<AccountUiPage> {
  late Future<ProfileCapabilities?> _profileFuture;
  bool _isSigningOut = false;

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

  void _navigateTo(_AccountTileData tile) {
    try {
      Navigator.pushNamed(context, tile.route, arguments: tile.arguments);
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
        final loading = snapshot.connectionState == ConnectionState.waiting;
        final isAdmin = profile?.can(Capability.accessAdminPanel) ?? false;
        final tiles = profile == null
            ? const <_AccountTileData>[]
            : _buildTiles(profile, l10n);

        return Scaffold(
          bottomNavigationBar: widget.showBottomBar
              ? const UserFacingBottomBar(
                  currentTab: UserFacingBottomBarTab.profile,
                )
              : null,
          body: HoneycombBackground(
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: <Widget>[
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
                        children: <Widget>[
                          if (isAdmin)
                            const AdminDebugLogsButton(scopeLabel: 'Mon Profil'),
                          if (isAdmin) const SizedBox(width: 4),
                          CartIconBadge(
                            iconColor: MasliveTokens.text,
                            backgroundColor:
                                Colors.white.withValues(alpha: 0.16),
                            borderColor: Colors.white.withValues(alpha: 0.22),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (loading)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (profile == null)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _SignedOutBlock(
                        onLogin: () => Navigator.of(context).pushNamed('/login'),
                        onRetry: _refresh,
                      ),
                    )
                  else ...<Widget>[
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
                          padding: EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 12,
                          ),
                          child: CommerceSectionCard(),
                        ),
                      ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(10, 20, 10, 18),
                      sliver: SliverList.builder(
                        itemCount: tiles.length,
                        itemBuilder: (context, index) {
                          final tile = tiles[index];
                          return _AccountTile(
                            tile: tile,
                            onTap: () => _navigateTo(tile),
                          );
                        },
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(10, 0, 10, 18),
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _isSigningOut
                                ? null
                                : () async {
                                    setState(() => _isSigningOut = true);
                                    try {
                                      await AuthService.instance.signOut();
                                    } catch (error) {
                                      if (!context.mounted) return;
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Déconnexion impossible : $error',
                                          ),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    } finally {
                                      if (mounted) {
                                        setState(() => _isSigningOut = false);
                                      }
                                    }
                                  },
                            icon: _isSigningOut
                                ? const SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.logout_rounded),
                            label: Text(
                              _isSigningOut
                                  ? 'Déconnexion...'
                                  : l10n.disconnect,
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
    ProfileCapabilities profile,
    AppLocalizations l10n,
  ) {
    final tiles = <_AccountTileData>[
      const _AccountTileData(
        icon: Icons.manage_accounts_outlined,
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
        route: '/media-marketplace/downloads',
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
          subtitle: 'Position, historique et export personnels',
          route: '/group-tracker',
        ),
      );
    } else if (profile.hasPendingGroupAdminRequest) {
      tiles.insert(
        1,
        const _AccountTileData(
          icon: Icons.pending_actions_rounded,
          title: 'Demande Admin Groupe en attente',
          subtitle: 'Validation MASLIVE requise avant activation',
          route: '/group-admin',
        ),
      );
    } else if (profile.can(Capability.requestGroupAdmin)) {
      tiles.insert(
        1,
        _AccountTileData(
          icon: profile.hasRejectedGroupAdminRequest
              ? Icons.replay_circle_filled_outlined
              : Icons.group_add_outlined,
          title: profile.hasRejectedGroupAdminRequest
              ? 'Refaire une demande Admin Groupe'
              : 'Demander Admin Groupe',
          subtitle: profile.hasRejectedGroupAdminRequest
              ? 'La précédente demande a été refusée'
              : 'Créer un groupe après validation MASLIVE',
          route: '/group-admin',
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

    if (profile.can(Capability.manageGroupShop)) {
      tiles.insert(
        3,
        const _AccountTileData(
          icon: Icons.storefront_outlined,
          title: 'Boutique du groupe',
          subtitle: 'Produits, commandes et ventes du groupe',
          route: '/shop',
        ),
      );
    }

    if (profile.can(Capability.manageOwnGallery)) {
      tiles.insertAll(3, const <_AccountTileData>[
        _AccountTileData(
          icon: Icons.camera_alt_outlined,
          title: 'Espace créateur digital',
          subtitle: 'Médias, galeries, ventes et statistiques',
          route: '/media-marketplace/photographer',
        ),
        _AccountTileData(
          icon: Icons.workspace_premium_outlined,
          title: 'Abonnement créateur digital',
          subtitle: 'Formule, stockage et crédits IA',
          route: '/media-marketplace/subscription',
        ),
      ]);
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

    if (profile.can(Capability.manageArtGallery)) {
      tiles.insertAll(3, const <_AccountTileData>[
        _AccountTileData(
          icon: Icons.palette_outlined,
          title: 'Galerie Bloom Art',
          subtitle: 'Créations, offres et paiements',
          route: '/bloom-art/dashboard',
        ),
        _AccountTileData(
          icon: Icons.add_box_outlined,
          title: 'Déposer une création',
          subtitle: 'Publier une œuvre après vérification',
          route: '/bloom-art/create',
        ),
      ]);
    }

    if (profile.canManageSellerInbox) {
      tiles.add(
        const _AccountTileData(
          icon: Icons.inbox_outlined,
          title: 'Inbox vendeur',
          subtitle: 'Commandes et actions à traiter',
          route: '/seller-inbox',
        ),
      );
    }

    if (profile.can(Capability.accessAdminPanel)) {
      tiles.add(
        const _AccountTileData(
          icon: Icons.admin_panel_settings_rounded,
          title: 'Espace administrateur',
          subtitle: 'Gestion MASLIVE selon mes autorisations',
          route: '/account-admin',
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: MasliveCard(
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
          subtitle: Text(tile.subtitle),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: onTap,
        ),
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
      children: <Widget>[
        CircleAvatar(
          radius: 40,
          backgroundColor: Colors.white,
          backgroundImage: photoUrl == null || photoUrl.isEmpty
              ? null
              : NetworkImage(photoUrl),
          child: photoUrl == null || photoUrl.isEmpty
              ? const Icon(Icons.person_rounded, size: 38)
              : null,
        ),
        const SizedBox(height: 10),
        Text(
          profile.displayName.isEmpty ? profile.email : profile.displayName,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 4),
        Text(profile.activeRoleLabels.join(' • '), textAlign: TextAlign.center),
      ],
    );
  }
}

class _CapabilitySummaryCard extends StatelessWidget {
  const _CapabilitySummaryCard({required this.profile});

  final ProfileCapabilities profile;

  @override
  Widget build(BuildContext context) {
    final chips = <String>{
      ...profile.activeRoleLabels,
      if (profile.canSubmitCommerce) 'Commerce autorisé',
      if (profile.can(Capability.trackOwnLocation)) 'Tracking GPS',
      if (profile.can(Capability.accessAdminPanel)) 'Administration',
      if (profile.hasPendingGroupAdminRequest) 'Demande groupe en attente',
    };
    return MasliveCard(
      radius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'Droits actifs',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: chips
                .map(
                  (label) => Chip(
                    label: Text(label),
                    visualDensity: VisualDensity.compact,
                  ),
                )
                .toList(growable: false),
          ),
        ],
      ),
    );
  }
}

class _SignedOutBlock extends StatelessWidget {
  const _SignedOutBlock({required this.onLogin, required this.onRetry});

  final VoidCallback onLogin;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.lock_outline_rounded, size: 56),
            const SizedBox(height: 16),
            const Text(
              'Connectez-vous pour voir votre profil MASLIVE.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onLogin,
              icon: const Icon(Icons.login_rounded),
              label: const Text('Se connecter'),
            ),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountTileData {
  const _AccountTileData({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.route,
    this.arguments,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String route;
  final Object? arguments;
}
