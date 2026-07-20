import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../admin/admin_debug_logs_sheet.dart';
import '../security/profile_capability_policy.dart';
import '../ui/theme/maslive_theme.dart';
import '../utils/debug_log_buffer.dart';
import '../widgets/rainbow_header.dart';
import 'login_page.dart';
import 'user_facing_bottom_bar.dart';

class AccountAndAdminPage extends StatefulWidget {
  const AccountAndAdminPage({super.key});

  @override
  State<AccountAndAdminPage> createState() => _AccountAndAdminPageState();
}

class _AccountAndAdminPageState extends State<AccountAndAdminPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  late Future<ProfileCapabilities?> _capabilitiesFuture;

  User? get user => _auth.currentUser;
  bool get _isAdminRoute => ModalRoute.of(context)?.settings.name == '/account-admin';

  @override
  void initState() {
    super.initState();
    DebugLogBuffer.setActiveScope('Compte et administration');
    _capabilitiesFuture = ProfileCapabilityPolicy.instance.resolveCurrent();
  }

  @override
  void dispose() {
    DebugLogBuffer.clearActiveScope();
    super.dispose();
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> _userDocStream() {
    final uid = user?.uid;
    if (uid == null) return const Stream.empty();
    return _db.collection('users').doc(uid).snapshots();
  }

  @override
  Widget build(BuildContext context) {
    if (user == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(builder: (_) => const LoginPage()),
        );
      });
      return const SizedBox.shrink();
    }

    return FutureBuilder<ProfileCapabilities?>(
      future: _capabilitiesFuture,
      builder: (context, capabilitySnapshot) {
        if (capabilitySnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final profile = capabilitySnapshot.data;
        if (profile == null || !profile.isActive) {
          return const _DeniedPage(
            message: 'Ce compte est indisponible ou désactivé.',
          );
        }
        if (_isAdminRoute && !profile.can(Capability.accessAdminPanel)) {
          return const _DeniedPage(
            message: 'Votre profil ne possède pas les droits administrateur.',
          );
        }

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: _userDocStream(),
          builder: (context, snapshot) {
            final data = snapshot.data?.data() ?? <String, dynamic>{};
            return _isAdminRoute
                ? _buildAdminPage(profile, data)
                : _buildPersonalAccountPage(profile, data);
          },
        );
      },
    );
  }

  Widget _buildPersonalAccountPage(
    ProfileCapabilities profile,
    Map<String, dynamic> data,
  ) {
    return Scaffold(
      bottomNavigationBar: const UserFacingBottomBar(
        currentTab: UserFacingBottomBarTab.profile,
      ),
      body: CustomScrollView(
        slivers: <Widget>[
          SliverToBoxAdapter(
            child: RainbowHeader(
              title: 'Mon compte',
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList.list(
              children: <Widget>[
                _AccountHeader(
                  displayName: profile.displayName,
                  email: profile.email,
                  photoUrl: profile.photoUrl,
                  labels: profile.activeRoleLabels,
                ),
                const SizedBox(height: 16),
                _SectionCard(
                  title: 'Modifier mon profil',
                  subtitle: 'Nom affiché et photo de profil',
                  icon: Icons.manage_accounts_outlined,
                  onTap: () => _showEditProfileSheet(data),
                ),
                const SizedBox(height: 12),
                _SectionCard(
                  title: 'Confidentialité et préférences',
                  subtitle: 'Langue, notifications et paramètres du compte',
                  icon: Icons.shield_outlined,
                  onTap: () => Navigator.of(context).pushNamed('/settings'),
                ),
                const SizedBox(height: 12),
                _SectionCard(
                  title: 'Mes favoris',
                  subtitle: 'Points, circuits et groupes enregistrés',
                  icon: Icons.favorite_border,
                  onTap: () => Navigator.of(context).pushNamed('/favorites'),
                ),
                const SizedBox(height: 12),
                _SectionCard(
                  title: 'Historique des achats',
                  subtitle: 'Commandes, œuvres et médias achetés',
                  icon: Icons.receipt_long_outlined,
                  onTap: () => Navigator.of(context).pushNamed('/purchase-history'),
                ),
                if (profile.canManageSellerInbox) ...<Widget>[
                  const SizedBox(height: 12),
                  _SectionCard(
                    title: 'Inbox vendeur',
                    subtitle: 'Commandes et actions liées à vos espaces vendeurs',
                    icon: Icons.inbox_outlined,
                    onTap: () => Navigator.of(context).pushNamed('/seller-inbox'),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminPage(
    ProfileCapabilities profile,
    Map<String, dynamic> data,
  ) {
    final isSuperAdmin = profile.hasKind(ProfileKind.superAdmin);
    return Scaffold(
      bottomNavigationBar: const UserFacingBottomBar(
        currentTab: UserFacingBottomBarTab.profile,
      ),
      body: CustomScrollView(
        slivers: <Widget>[
          SliverToBoxAdapter(
            child: RainbowHeader(
              title: 'Espace administrateur',
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
              trailing: const AdminDebugLogsButton(
                scopeLabel: 'Espace administrateur',
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList.list(
              children: <Widget>[
                _AccountHeader(
                  displayName: profile.displayName,
                  email: profile.email,
                  photoUrl: profile.photoUrl,
                  labels: profile.activeRoleLabels,
                ),
                const SizedBox(height: 18),
                _SectionCard(
                  title: 'Dashboard Administrateur',
                  subtitle: 'Vue globale de la gestion MASLIVE',
                  icon: Icons.dashboard_outlined,
                  onTap: () => Navigator.of(context).pushNamed('/admin'),
                ),
                if (profile.can(Capability.manageAllUsers)) ...<Widget>[
                  const SizedBox(height: 12),
                  _SectionCard(
                    title: 'Utilisateurs',
                    subtitle: 'Rechercher, modifier, désactiver et gérer les rôles',
                    icon: Icons.manage_accounts_outlined,
                    onTap: () => Navigator.of(context).pushNamed('/admin/users'),
                  ),
                ],
                if (profile.can(Capability.manageAllGroups)) ...<Widget>[
                  const SizedBox(height: 12),
                  _SectionCard(
                    title: 'Admin Groupe et Trackers',
                    subtitle: 'Demandes, comptes, codes et rattachements',
                    icon: Icons.groups_2_outlined,
                    onTap: () =>
                        Navigator.of(context).pushNamed('/admin/group-accounts'),
                  ),
                ],
                if (profile.can(Capability.moderateCommerce)) ...<Widget>[
                  const SizedBox(height: 12),
                  _SectionCard(
                    title: 'Modération',
                    subtitle: 'Produits, médias, œuvres et signalements',
                    icon: Icons.fact_check_outlined,
                    onTap: () => Navigator.of(context).pushNamed('/admin/moderation'),
                  ),
                ],
                if (profile.can(Capability.manageAllProducts)) ...<Widget>[
                  const SizedBox(height: 12),
                  _SectionCard(
                    title: 'Commerce',
                    subtitle: 'Catalogue, stocks et commandes globales',
                    icon: Icons.store_mall_directory_outlined,
                    onTap: () => Navigator.of(context).pushNamed('/admin/commerce'),
                  ),
                ],
                if (profile.can(Capability.manageCircuits)) ...<Widget>[
                  const SizedBox(height: 12),
                  _SectionCard(
                    title: 'Circuits et cartes',
                    subtitle: 'POI, circuits, styles et publication',
                    icon: Icons.route_outlined,
                    onTap: () => Navigator.of(context).pushNamed('/admin/circuits'),
                  ),
                ],
                if (isSuperAdmin) ...<Widget>[
                  const SizedBox(height: 12),
                  _SectionCard(
                    title: 'SuperAdmin',
                    subtitle: 'Rôles, permissions et fonctions critiques',
                    icon: Icons.security_outlined,
                    onTap: () => Navigator.of(context).pushNamed('/admin/superadmin'),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showEditProfileSheet(Map<String, dynamic> initial) async {
    final nameController = TextEditingController(
      text: (initial['displayName'] ?? user?.displayName ?? '').toString(),
    );
    final photoController = TextEditingController(
      text: (initial['photoUrl'] ?? user?.photoURL ?? '').toString(),
    );
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          12,
          16,
          MediaQuery.of(sheetContext).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Text(
              'Modifier mon profil',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Nom affiché'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: photoController,
              decoration: const InputDecoration(labelText: 'URL photo'),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () async {
                  await _db.collection('users').doc(user!.uid).set(
                    <String, dynamic>{
                      'displayName': nameController.text.trim(),
                      'photoUrl': photoController.text.trim().isEmpty
                          ? null
                          : photoController.text.trim(),
                      'updatedAt': FieldValue.serverTimestamp(),
                    },
                    SetOptions(merge: true),
                  );
                  if (sheetContext.mounted) Navigator.of(sheetContext).pop();
                  setState(() {
                    _capabilitiesFuture =
                        ProfileCapabilityPolicy.instance.resolveCurrent();
                  });
                },
                icon: const Icon(Icons.save_outlined),
                label: const Text('Enregistrer'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeniedPage extends StatelessWidget {
  const _DeniedPage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Accès refusé')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(Icons.lock_outline_rounded, size: 56),
              const SizedBox(height: 16),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: () => Navigator.of(context).pushReplacementNamed('/account-ui'),
                child: const Text('Retour à mon profil'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccountHeader extends StatelessWidget {
  const _AccountHeader({
    required this.displayName,
    required this.email,
    required this.photoUrl,
    required this.labels,
  });

  final String displayName;
  final String email;
  final String? photoUrl;
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: <Widget>[
            CircleAvatar(
              radius: 30,
              backgroundImage:
                  photoUrl == null || photoUrl!.isEmpty ? null : NetworkImage(photoUrl!),
              child: photoUrl == null || photoUrl!.isEmpty
                  ? const Icon(Icons.person_outline_rounded)
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    displayName,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                  Text(email),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: labels
                        .map((label) => Chip(label: Text(label)))
                        .toList(growable: false),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: MasliveTheme.textPrimary),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      ),
    );
  }
}
