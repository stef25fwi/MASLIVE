import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../services/auth_service.dart';
import '../../../../ui/theme/maslive_theme.dart';
import '../../core/constants/media_marketplace_pricing.dart';
import '../../data/models/photographer_profile_model.dart';
import '../../data/repositories/photographer_complete_flow_repository.dart';
import '../../data/repositories/photographer_repository.dart';
import '../../domain/services/photographer_avatar_service.dart';
import '../widgets/photographer_finance_panel.dart';
import '../widgets/photographer_gallery_studio_panel.dart';
import '../widgets/photographer_import_panel.dart';
import '../widgets/photographer_photo_library_panel.dart';
import '../widgets/photographer_team_brand_panel.dart';
import 'photographer_subscription_page.dart';

class PhotographerCompleteFlowPage extends StatefulWidget {
  const PhotographerCompleteFlowPage({
    super.key,
    this.initialSection = 0,
    this.eventId,
    this.eventName,
    this.circuitId,
    this.circuitName,
  });

  final int initialSection;
  final String? eventId;
  final String? eventName;
  final String? circuitId;
  final String? circuitName;

  @override
  State<PhotographerCompleteFlowPage> createState() =>
      _PhotographerCompleteFlowPageState();
}

class _PhotographerCompleteFlowPageState
    extends State<PhotographerCompleteFlowPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final PhotographerRepository _profiles = PhotographerRepository();
  final PhotographerCompleteFlowRepository _repository =
      PhotographerCompleteFlowRepository();
  PhotographerProfileModel? _profile;
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(
      length: 8,
      vsync: this,
      initialIndex: widget.initialSection.clamp(0, 7).toInt(),
    );
    _reload();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final uid = AuthService.instance.currentUser?.uid;
      if (uid == null || uid.isEmpty) throw StateError('Connexion requise.');
      _profile = await _profiles.getByOwnerUid(uid);
    } catch (error) {
      _error = error;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _requiresProfile(Widget Function(PhotographerProfileModel profile) child) {
    final profile = _profile;
    if (profile == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(Icons.camera_alt_outlined, size: 54),
              const SizedBox(height: 12),
              const Text('Crée d’abord ton profil photographe.'),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => _tabs.animateTo(1),
                child: const Text('Créer mon profil'),
              ),
            ],
          ),
        ),
      );
    }
    return child(profile);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MasliveTheme.surfaceAlt,
      appBar: AppBar(
        title: const Text('Centre photographe MASLIVE'),
        actions: <Widget>[
          IconButton(
            onPressed: _loading ? null : _reload,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Actualiser',
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabs: const <Tab>[
            Tab(icon: Icon(Icons.dashboard_outlined), text: 'Vue d’ensemble'),
            Tab(icon: Icon(Icons.badge_outlined), text: 'Profil'),
            Tab(icon: Icon(Icons.photo_library_outlined), text: 'Galeries'),
            Tab(icon: Icon(Icons.drive_folder_upload_outlined), text: 'Imports'),
            Tab(icon: Icon(Icons.photo_outlined), text: 'Photos'),
            Tab(icon: Icon(Icons.payments_outlined), text: 'Ventes'),
            Tab(icon: Icon(Icons.groups_2_outlined), text: 'Équipe & marque'),
            Tab(icon: Icon(Icons.workspace_premium_outlined), text: 'Abonnement'),
          ],
        ),
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: MasliveTheme.backgroundWash),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: FilledButton.icon(
                      onPressed: _reload,
                      icon: const Icon(Icons.refresh_rounded),
                      label: Text('Réessayer : $_error'),
                    ),
                  )
                : TabBarView(
                    controller: _tabs,
                    children: <Widget>[
                      _requiresProfile(
                        (profile) => _PhotographerOverviewPanel(
                          profile: profile,
                          repository: _repository,
                          eventId: widget.eventId,
                          eventName: widget.eventName,
                          circuitId: widget.circuitId,
                          circuitName: widget.circuitName,
                          onOpenSection: _tabs.animateTo,
                        ),
                      ),
                      _PhotographerProfilePanel(
                        profile: _profile,
                        onSaved: _reload,
                      ),
                      _requiresProfile(
                        (profile) => PhotographerGalleryStudioPanel(
                          profile: profile,
                          repository: _repository,
                        ),
                      ),
                      _requiresProfile(
                        (profile) => PhotographerImportPanel(
                          profile: profile,
                          repository: _repository,
                        ),
                      ),
                      _requiresProfile(
                        (profile) => PhotographerPhotoLibraryPanel(
                          profile: profile,
                          repository: _repository,
                        ),
                      ),
                      _requiresProfile(
                        (profile) => PhotographerFinancePanel(
                          profile: profile,
                          repository: _repository,
                        ),
                      ),
                      _requiresProfile(
                        (profile) => PhotographerTeamBrandPanel(
                          profile: profile,
                          repository: _repository,
                        ),
                      ),
                      _requiresProfile(
                        (profile) => _PhotographerSubscriptionPanel(
                          profile: profile,
                          onChanged: _reload,
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }
}

class _PhotographerOverviewPanel extends StatefulWidget {
  const _PhotographerOverviewPanel({
    required this.profile,
    required this.repository,
    required this.eventId,
    required this.eventName,
    required this.circuitId,
    required this.circuitName,
    required this.onOpenSection,
  });

  final PhotographerProfileModel profile;
  final PhotographerCompleteFlowRepository repository;
  final String? eventId;
  final String? eventName;
  final String? circuitId;
  final String? circuitName;
  final void Function(int index) onOpenSection;

  @override
  State<_PhotographerOverviewPanel> createState() =>
      _PhotographerOverviewPanelState();
}

class _PhotographerOverviewPanelState
    extends State<_PhotographerOverviewPanel> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _data = await widget.repository.loadAdvancedDashboard(
        photographerId: widget.profile.photographerId,
        eventId: widget.eventId,
      );
    } catch (error) {
      _error = error;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _money(dynamic value) => '${((value as num?)?.toDouble() ?? 0).toStringAsFixed(2)} €';

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: FilledButton.icon(
          onPressed: _load,
          icon: const Icon(Icons.refresh_rounded),
          label: Text('Réessayer : $_error'),
        ),
      );
    }
    final data = _data ?? const <String, dynamic>{};
    final warnings = (data['expiryWarnings'] as Iterable? ?? const <dynamic>[])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
    final missingCircuits =
        (data['circuitsWithoutGallery'] as Iterable? ?? const <dynamic>[])
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList(growable: false);
    final nextRenewal = DateTime.tryParse(data['nextRenewalAt']?.toString() ?? '');
    final plan = MediaMarketplacePricing.planFor(widget.profile.activePlanId);
    final photoRatio = plan.photoRatio(widget.profile.publishedPhotoCount);
    final storageRatio = plan.storageRatio(widget.profile.storageUsedBytes);

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: <Widget>[
                  CircleAvatar(
                    radius: 32,
                    backgroundImage: widget.profile.avatarUrl?.isNotEmpty == true
                        ? NetworkImage(widget.profile.avatarUrl!)
                        : null,
                    child: widget.profile.avatarUrl?.isNotEmpty == true
                        ? null
                        : const Icon(Icons.camera_alt_outlined),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          widget.profile.brandName,
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        Text(
                          'Formule ${plan.name}${widget.eventName?.isNotEmpty == true ? ' • ${widget.eventName}' : ''}${widget.circuitName?.isNotEmpty == true ? ' • ${widget.circuitName}' : ''}',
                        ),
                        if (nextRenewal != null)
                          Text(
                            '${data['cancelAtPeriodEnd'] == true ? 'Fin prévue' : 'Prochain renouvellement'} le ${nextRenewal.day.toString().padLeft(2, '0')}/${nextRenewal.month.toString().padLeft(2, '0')}/${nextRenewal.year}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                      ],
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: () => Navigator.pushNamed(
                      context,
                      '/media-marketplace',
                      arguments: <String, dynamic>{
                        'initialTab': 0,
                        'photographerId': widget.profile.photographerId,
                        if (widget.eventId?.isNotEmpty == true) 'eventId': widget.eventId,
                        if (widget.circuitId?.isNotEmpty == true) 'circuitId': widget.circuitId,
                      },
                    ),
                    icon: const Icon(Icons.storefront_outlined),
                    label: const Text('Voir ma boutique publique'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: <Widget>[
              _OverviewMetric(label: 'Ventes du mois', value: '${data['monthlySalesCount'] ?? 0}', icon: Icons.shopping_bag_outlined),
              _OverviewMetric(label: 'CA du mois', value: _money(data['monthlyRevenueGross']), icon: Icons.trending_up),
              _OverviewMetric(label: 'Net du mois', value: _money(data['monthlyRevenueNet']), icon: Icons.savings_outlined),
              _OverviewMetric(label: 'Disponible à reverser', value: _money(data['revenueAvailable']), icon: Icons.account_balance_wallet_outlined),
              _OverviewMetric(label: 'En attente', value: _money(data['revenuePending']), icon: Icons.schedule_outlined),
              _OverviewMetric(label: 'Déjà reversé', value: _money(data['revenueTransferred']), icon: Icons.check_circle_outline),
              _OverviewMetric(label: 'Photos à traiter', value: '${data['pendingPhotos'] ?? 0}', icon: Icons.hourglass_top_outlined),
              _OverviewMetric(label: 'Galeries actives', value: '${data['activeGalleryCount'] ?? 0}', icon: Icons.photo_library_outlined),
              _OverviewMetric(label: 'Circuits sans galerie', value: '${missingCircuits.length}', icon: Icons.route_outlined),
            ],
          ),
          const SizedBox(height: 18),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Quotas en temps réel',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 12),
                  _QuotaLine(
                    label: '${widget.profile.publishedPhotoCount} / ${plan.maxPublishedPhotos} photos',
                    value: photoRatio,
                  ),
                  _QuotaLine(
                    label: '${(widget.profile.storageUsedBytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} / ${(plan.maxStorageBytes / (1024 * 1024 * 1024)).round()} Go',
                    value: storageRatio,
                  ),
                  _QuotaLine(
                    label: '${widget.profile.activeGalleryCount} / ${plan.maxActiveGalleries} galeries',
                    value: plan.maxActiveGalleries <= 0
                        ? 0
                        : widget.profile.activeGalleryCount / plan.maxActiveGalleries,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: <Widget>[
              FilledButton.icon(
                onPressed: () => widget.onOpenSection(2),
                icon: const Icon(Icons.create_new_folder_outlined),
                label: const Text('Créer / gérer une galerie'),
              ),
              FilledButton.tonalIcon(
                onPressed: () => widget.onOpenSection(3),
                icon: const Icon(Icons.drive_folder_upload_outlined),
                label: const Text('Importer des photos'),
              ),
              FilledButton.tonalIcon(
                onPressed: () => widget.onOpenSection(4),
                icon: const Icon(Icons.photo_outlined),
                label: const Text('Gérer les photos'),
              ),
              FilledButton.tonalIcon(
                onPressed: () => widget.onOpenSection(5),
                icon: const Icon(Icons.payments_outlined),
                label: const Text('Ventes et reversements'),
              ),
            ],
          ),
          if (warnings.isNotEmpty) ...<Widget>[
            const SizedBox(height: 20),
            Text(
              'Alertes d’expiration',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            for (final warning in warnings)
              Card(
                color: Theme.of(context).colorScheme.tertiaryContainer,
                child: ListTile(
                  leading: const Icon(Icons.timer_outlined),
                  title: Text(warning['title']?.toString() ?? 'Galerie'),
                  subtitle: Text('Expiration : ${warning['expiresAt'] ?? ''}'),
                  trailing: TextButton(
                    onPressed: () => widget.onOpenSection(2),
                    child: const Text('Gérer'),
                  ),
                ),
              ),
          ],
          if (missingCircuits.isNotEmpty) ...<Widget>[
            const SizedBox(height: 20),
            Text(
              'Circuits sans galerie',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            for (final circuit in missingCircuits)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.route_outlined),
                  title: Text(circuit['name']?.toString() ?? circuit['circuitId']?.toString() ?? ''),
                  subtitle: const Text('Aucune galerie photographe pour ce circuit.'),
                  trailing: FilledButton.tonal(
                    onPressed: () => widget.onOpenSection(2),
                    child: const Text('Créer'),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _PhotographerProfilePanel extends StatefulWidget {
  const _PhotographerProfilePanel({
    required this.profile,
    required this.onSaved,
  });

  final PhotographerProfileModel? profile;
  final Future<void> Function() onSaved;

  @override
  State<_PhotographerProfilePanel> createState() =>
      _PhotographerProfilePanelState();
}

class _PhotographerProfilePanelState extends State<_PhotographerProfilePanel> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _brand;
  late final TextEditingController _bio;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  late final TextEditingController _country;
  late final TextEditingController _city;
  late final TextEditingController _website;
  late final TextEditingController _instagram;
  bool _saving = false;
  bool _uploadingAvatar = false;

  @override
  void initState() {
    super.initState();
    final profile = widget.profile;
    _brand = TextEditingController(text: profile?.brandName ?? '');
    _bio = TextEditingController(text: profile?.bio ?? '');
    _phone = TextEditingController(text: profile?.phone ?? '');
    _email = TextEditingController(
      text: profile?.email ?? AuthService.instance.currentUser?.email ?? '',
    );
    _country = TextEditingController(text: profile?.country ?? '');
    _city = TextEditingController(text: profile?.city ?? '');
    _website = TextEditingController(text: profile?.socialLinks['website'] ?? '');
    _instagram = TextEditingController(text: profile?.socialLinks['instagram'] ?? '');
  }

  @override
  void dispose() {
    for (final controller in <TextEditingController>[
      _brand,
      _bio,
      _phone,
      _email,
      _country,
      _city,
      _website,
      _instagram,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _saving) return;
    setState(() => _saving = true);
    try {
      final uid = AuthService.instance.currentUser!.uid;
      final ref = FirebaseFirestore.instance
          .collection('photographers')
          .doc(widget.profile?.photographerId ?? uid);
      await ref.set(
        <String, dynamic>{
          'photographerId': ref.id,
          'ownerUid': uid,
          'brandName': _brand.text.trim(),
          'bio': _bio.text.trim(),
          'phone': _phone.text.trim(),
          'email': _email.text.trim(),
          'country': _country.text.trim(),
          'city': _city.text.trim(),
          'socialLinks': <String, String>{
            'website': _website.text.trim(),
            'instagram': _instagram.text.trim(),
          },
          'activePlanId': widget.profile?.activePlanId ?? 'discovery',
          'status': widget.profile?.status.name ?? 'pending',
          'updatedAt': FieldValue.serverTimestamp(),
          if (widget.profile == null) ...<String, dynamic>{
            'createdAt': FieldValue.serverTimestamp(),
            'isVerified': false,
            'publishedPhotoCount': 0,
            'activeGalleryCount': 0,
            'activePackCount': 0,
            'storageUsedBytes': 0,
            'salesCount': 0,
            'totalRevenueGross': 0,
            'totalRevenueNet': 0,
          },
        },
        SetOptions(merge: true),
      );
      await widget.onSaved();
      _message('Profil photographe enregistré.');
    } catch (error) {
      _message(error.toString(), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _avatar() async {
    final profile = widget.profile;
    final uid = AuthService.instance.currentUser?.uid;
    if (profile == null || uid == null) {
      _message('Enregistre d’abord le profil, puis ajoute l’avatar.', error: true);
      return;
    }
    setState(() => _uploadingAvatar = true);
    try {
      await PhotographerAvatarService().pickCropCompressAndUpload(
        photographerId: profile.photographerId,
        ownerUid: uid,
      );
      await widget.onSaved();
      _message('Avatar recadré, compressé et mis à jour.');
    } catch (error) {
      _message(error.toString(), error: true);
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  void _message(String text, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text.replaceFirst('Bad state: ', '')),
        backgroundColor: error ? Colors.red.shade700 : null,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      CircleAvatar(
                        radius: 52,
                        backgroundImage: widget.profile?.avatarUrl?.isNotEmpty == true
                            ? NetworkImage(widget.profile!.avatarUrl!)
                            : null,
                        child: widget.profile?.avatarUrl?.isNotEmpty == true
                            ? null
                            : const Icon(Icons.camera_alt_outlined, size: 38),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              widget.profile == null
                                  ? 'Créer mon profil photographe'
                                  : 'Modifier mon profil photographe',
                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
                            ),
                            const SizedBox(height: 8),
                            FilledButton.tonalIcon(
                              onPressed: _uploadingAvatar ? null : _avatar,
                              icon: _uploadingAvatar
                                  ? const SizedBox.square(
                                      dimension: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Icon(Icons.add_a_photo_outlined),
                              label: const Text('Choisir, recadrer et compresser l’avatar'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  TextFormField(
                    controller: _brand,
                    decoration: const InputDecoration(labelText: 'Nom de marque'),
                    validator: (value) => value == null || value.trim().length < 2
                        ? 'Nom requis'
                        : null,
                  ),
                  TextFormField(
                    controller: _bio,
                    maxLines: 4,
                    decoration: const InputDecoration(labelText: 'Biographie'),
                  ),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: <Widget>[
                      _profileField(_email, 'E-mail'),
                      _profileField(_phone, 'Téléphone', width: 220),
                      _profileField(_country, 'Pays', width: 220),
                      _profileField(_city, 'Ville', width: 220),
                      _profileField(_website, 'Site web'),
                      _profileField(_instagram, 'Instagram'),
                    ],
                  ),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: const Icon(Icons.save_outlined),
                    label: Text(_saving ? 'Enregistrement…' : 'Enregistrer le profil'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _profileField(
    TextEditingController controller,
    String label, {
    double width = 300,
  }) {
    return SizedBox(
      width: width,
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }
}

class _PhotographerSubscriptionPanel extends StatefulWidget {
  const _PhotographerSubscriptionPanel({
    required this.profile,
    required this.onChanged,
  });

  final PhotographerProfileModel profile;
  final Future<void> Function() onChanged;

  @override
  State<_PhotographerSubscriptionPanel> createState() =>
      _PhotographerSubscriptionPanelState();
}

class _PhotographerSubscriptionPanelState
    extends State<_PhotographerSubscriptionPanel> {
  bool _working = false;
  final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(region: 'us-east1');

  Future<void> _call(String name) async {
    if (_working) return;
    setState(() => _working = true);
    try {
      final response = await _functions.httpsCallable(name).call(<String, dynamic>{
        'photographerId': widget.profile.photographerId,
      });
      final data = response.data is Map
          ? Map<String, dynamic>.from(response.data as Map)
          : const <String, dynamic>{};
      final url = data['url']?.toString();
      if (url?.isNotEmpty == true) {
        await launchUrl(Uri.parse(url!), mode: LaunchMode.externalApplication);
      }
      await widget.onChanged();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final plan = MediaMarketplacePricing.planFor(widget.profile.activePlanId);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Formule active : ${plan.name}',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                Text(
                  '${plan.maxPublishedPhotos} photos • ${(plan.maxStorageBytes / (1024 * 1024 * 1024)).round()} Go • ${plan.maxActiveGalleries} galeries • ${(plan.commissionRate * 100).round()} % de commission',
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: <Widget>[
                    FilledButton.icon(
                      onPressed: _working
                          ? null
                          : () => Navigator.of(context).push<void>(
                                MaterialPageRoute<void>(
                                  builder: (_) => const PhotographerSubscriptionPage(),
                                ),
                              ),
                      icon: const Icon(Icons.workspace_premium_outlined),
                      label: const Text('Changer de formule / stockage'),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: _working
                          ? null
                          : () => _call('createPhotographerBillingPortalLink'),
                      icon: const Icon(Icons.receipt_long_outlined),
                      label: const Text('Factures et moyen de paiement'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _working
                          ? null
                          : () => _call('cancelPhotographerSubscription'),
                      icon: const Icon(Icons.pause_circle_outline),
                      label: const Text('Annuler au prochain renouvellement'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _working
                          ? null
                          : () => _call('resumePhotographerSubscription'),
                      icon: const Icon(Icons.play_circle_outline),
                      label: const Text('Réactiver'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _OverviewMetric extends StatelessWidget {
  const _OverviewMetric({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 205,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(icon),
              const SizedBox(height: 8),
              Text(label, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 4),
              Text(
                value,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuotaLine extends StatelessWidget {
  const _QuotaLine({required this.label, required this.value});

  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    final normalized = value.clamp(0.0, 1.0).toDouble();
    final color = normalized >= .95
        ? Theme.of(context).colorScheme.error
        : normalized >= .8
            ? Colors.orange
            : Colors.green;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label),
          const SizedBox(height: 5),
          LinearProgressIndicator(value: normalized, color: color),
        ],
      ),
    );
  }
}
