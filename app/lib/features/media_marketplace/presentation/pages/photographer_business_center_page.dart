import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../services/auth_service.dart';
import '../../../../ui/theme/maslive_theme.dart';
import '../../../../ui/widgets/storage_image.dart';
import '../../core/constants/media_marketplace_pricing.dart';
import '../../data/models/media_order_model.dart';
import '../../data/models/media_photo_model.dart';
import '../../data/models/photographer_profile_model.dart';
import '../../data/repositories/media_order_repository.dart';
import '../../data/repositories/photographer_repository.dart';

class PhotographerBusinessCenterPage extends StatefulWidget {
  const PhotographerBusinessCenterPage({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  State<PhotographerBusinessCenterPage> createState() =>
      _PhotographerBusinessCenterPageState();
}

class _PhotographerBusinessCenterPageState
    extends State<PhotographerBusinessCenterPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _profiles = PhotographerRepository();
  PhotographerProfileModel? _profile;
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this, initialIndex: widget.initialTab.clamp(0, 3));
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MasliveTheme.surfaceAlt,
      appBar: AppBar(
        title: const Text('Centre photographe'),
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabs: const <Tab>[
            Tab(icon: Icon(Icons.badge_outlined), text: 'Profil'),
            Tab(icon: Icon(Icons.photo_library_outlined), text: 'Photos'),
            Tab(icon: Icon(Icons.payments_outlined), text: 'Ventes'),
            Tab(icon: Icon(Icons.workspace_premium_outlined), text: 'Abonnement'),
          ],
        ),
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: MasliveTheme.backgroundWash),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _ErrorState(error: _error!, onRetry: _reload)
                : TabBarView(
                    controller: _tabs,
                    children: <Widget>[
                      _ProfileEditor(profile: _profile, onSaved: _reload),
                      _PhotoManager(profile: _profile),
                      _SalesCenter(profile: _profile),
                      _SubscriptionLifecycle(profile: _profile, onChanged: _reload),
                    ],
                  ),
      ),
    );
  }
}

class _ProfileEditor extends StatefulWidget {
  const _ProfileEditor({required this.profile, required this.onSaved});
  final PhotographerProfileModel? profile;
  final Future<void> Function() onSaved;

  @override
  State<_ProfileEditor> createState() => _ProfileEditorState();
}

class _ProfileEditorState extends State<_ProfileEditor> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _brand;
  late final TextEditingController _bio;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  late final TextEditingController _country;
  late final TextEditingController _city;
  late final TextEditingController _avatar;
  late final TextEditingController _website;
  late final TextEditingController _instagram;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final p = widget.profile;
    _brand = TextEditingController(text: p?.brandName ?? '');
    _bio = TextEditingController(text: p?.bio ?? '');
    _phone = TextEditingController(text: p?.phone ?? '');
    _email = TextEditingController(text: p?.email ?? AuthService.instance.currentUser?.email ?? '');
    _country = TextEditingController(text: p?.country ?? '');
    _city = TextEditingController(text: p?.city ?? '');
    _avatar = TextEditingController(text: p?.avatarUrl ?? '');
    _website = TextEditingController(text: p?.socialLinks['website'] ?? '');
    _instagram = TextEditingController(text: p?.socialLinks['instagram'] ?? '');
  }

  @override
  void dispose() {
    for (final c in <TextEditingController>[_brand, _bio, _phone, _email, _country, _city, _avatar, _website, _instagram]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _saving) return;
    setState(() => _saving = true);
    try {
      final uid = AuthService.instance.currentUser!.uid;
      final ref = FirebaseFirestore.instance.collection('photographer_profiles').doc(widget.profile?.photographerId ?? uid);
      final now = FieldValue.serverTimestamp();
      await ref.set(<String, dynamic>{
        'photographerId': ref.id,
        'ownerUid': uid,
        'brandName': _brand.text.trim(),
        'bio': _bio.text.trim(),
        'phone': _phone.text.trim(),
        'email': _email.text.trim(),
        'country': _country.text.trim(),
        'city': _city.text.trim(),
        'avatarUrl': _avatar.text.trim(),
        'socialLinks': <String, String>{
          'website': _website.text.trim(),
          'instagram': _instagram.text.trim(),
        },
        'activePlanId': widget.profile?.activePlanId ?? 'discovery',
        'status': widget.profile?.status.firestoreValue ?? 'pending',
        'updatedAt': now,
        if (widget.profile == null) 'createdAt': now,
      }, SetOptions(merge: true));
      await widget.onSaved();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profil photographe enregistré.')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
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
                  Text(widget.profile == null ? 'Créer mon profil photographe' : 'Modifier mon profil photographe', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 16),
                  TextFormField(controller: _brand, decoration: const InputDecoration(labelText: 'Nom de marque'), validator: (v) => v == null || v.trim().length < 2 ? 'Nom requis' : null),
                  const SizedBox(height: 12),
                  TextFormField(controller: _bio, maxLines: 4, decoration: const InputDecoration(labelText: 'Biographie')),
                  const SizedBox(height: 12),
                  TextFormField(controller: _avatar, decoration: const InputDecoration(labelText: 'URL de l’avatar')),
                  const SizedBox(height: 12),
                  Wrap(spacing: 12, runSpacing: 12, children: <Widget>[
                    SizedBox(width: 300, child: TextFormField(controller: _email, decoration: const InputDecoration(labelText: 'E-mail'))),
                    SizedBox(width: 220, child: TextFormField(controller: _phone, decoration: const InputDecoration(labelText: 'Téléphone'))),
                    SizedBox(width: 220, child: TextFormField(controller: _country, decoration: const InputDecoration(labelText: 'Pays'))),
                    SizedBox(width: 220, child: TextFormField(controller: _city, decoration: const InputDecoration(labelText: 'Ville'))),
                    SizedBox(width: 300, child: TextFormField(controller: _website, decoration: const InputDecoration(labelText: 'Site web'))),
                    SizedBox(width: 300, child: TextFormField(controller: _instagram, decoration: const InputDecoration(labelText: 'Instagram'))),
                  ]),
                  const SizedBox(height: 18),
                  FilledButton.icon(onPressed: _saving ? null : _save, icon: const Icon(Icons.save_outlined), label: Text(_saving ? 'Enregistrement…' : 'Enregistrer')),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PhotoManager extends StatefulWidget {
  const _PhotoManager({required this.profile});
  final PhotographerProfileModel? profile;

  @override
  State<_PhotoManager> createState() => _PhotoManagerState();
}

class _PhotoManagerState extends State<_PhotoManager> {
  static const int _pageSize = 30;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> _docs = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
  final Set<String> _selected = <String>{};
  DocumentSnapshot<Map<String, dynamic>>? _cursor;
  bool _loading = false;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _loadMore();
  }

  Future<void> _loadMore() async {
    final photographerId = widget.profile?.photographerId;
    if (photographerId == null || _loading || !_hasMore) return;
    setState(() => _loading = true);
    Query<Map<String, dynamic>> query = FirebaseFirestore.instance.collection('media_photos').where('photographerId', isEqualTo: photographerId).orderBy('createdAt', descending: true).limit(_pageSize + 1);
    if (_cursor != null) query = query.startAfterDocument(_cursor!);
    final snapshot = await query.get();
    final page = snapshot.docs.take(_pageSize).toList(growable: false);
    setState(() {
      _docs.addAll(page.where((doc) => !_docs.any((existing) => existing.id == doc.id)));
      _cursor = page.isEmpty ? _cursor : page.last;
      _hasMore = snapshot.docs.length > _pageSize;
      _loading = false;
    });
  }

  Future<void> _batchPatch(Map<String, dynamic> patch) async {
    if (_selected.isEmpty) return;
    final batch = FirebaseFirestore.instance.batch();
    for (final id in _selected) {
      batch.set(FirebaseFirestore.instance.collection('media_photos').doc(id), <String, dynamic>{...patch, 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
    }
    await batch.commit();
    setState(() => _selected.clear());
    await _refresh();
  }

  Future<void> _deleteSelected() async {
    if (_selected.isEmpty) return;
    final owned = await FirebaseFirestore.instance.collection('media_entitlements').where('photoId', whereIn: _selected.take(10).toList()).limit(1).get();
    if (owned.docs.isNotEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Suppression refusée : au moins une photo a déjà été achetée.')));
      return;
    }
    final batch = FirebaseFirestore.instance.batch();
    for (final id in _selected) {
      batch.delete(FirebaseFirestore.instance.collection('media_photos').doc(id));
    }
    await batch.commit();
    setState(() => _selected.clear());
    await _refresh();
  }

  Future<void> _editPrice(QueryDocumentSnapshot<Map<String, dynamic>> doc) async {
    final controller = TextEditingController(text: ((doc.data()['unitPrice'] as num?)?.toDouble() ?? 6.9).toStringAsFixed(2));
    final value = await showDialog<double>(context: context, builder: (context) => AlertDialog(title: const Text('Prix de la photo'), content: TextField(controller: controller, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(suffixText: '€')), actions: <Widget>[TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')), FilledButton(onPressed: () => Navigator.pop(context, double.tryParse(controller.text.replaceAll(',', '.'))), child: const Text('Enregistrer'))]));
    controller.dispose();
    if (value == null || value < 0) return;
    await doc.reference.set(<String, dynamic>{'unitPrice': value, 'isForSale': true, 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
    await _refresh();
  }

  Future<void> _refresh() async {
    setState(() {
      _docs.clear();
      _cursor = null;
      _hasMore = true;
    });
    await _loadMore();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.profile == null) return const Center(child: Text('Crée d’abord ton profil photographe.'));
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Wrap(spacing: 8, runSpacing: 8, children: <Widget>[
            FilledButton.tonalIcon(onPressed: _selected.isEmpty ? null : () => _batchPatch(<String, dynamic>{'isPublished': true, 'lifecycleStatus': 'published'}), icon: const Icon(Icons.publish_outlined), label: const Text('Publier')),
            OutlinedButton.icon(onPressed: _selected.isEmpty ? null : () => _batchPatch(<String, dynamic>{'isPublished': false, 'lifecycleStatus': 'archived'}), icon: const Icon(Icons.archive_outlined), label: const Text('Archiver')),
            OutlinedButton.icon(onPressed: _selected.isEmpty ? null : _deleteSelected, icon: const Icon(Icons.delete_outline), label: const Text('Supprimer')),
            Text('${_selected.length} sélectionnée(s)'),
          ]),
          const SizedBox(height: 14),
          LayoutBuilder(builder: (context, constraints) {
            final columns = constraints.maxWidth >= 1200 ? 6 : constraints.maxWidth >= 900 ? 5 : constraints.maxWidth >= 680 ? 4 : constraints.maxWidth >= 460 ? 3 : 2;
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: columns, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: .78),
              itemCount: _docs.length,
              itemBuilder: (context, index) {
                final doc = _docs[index];
                final photo = MediaPhotoModel.fromDocument(doc);
                final selected = _selected.contains(doc.id);
                final image = photo.thumbnailPath.isNotEmpty ? photo.thumbnailPath : photo.watermarkedPath;
                return Card(
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => setState(() => selected ? _selected.remove(doc.id) : _selected.add(doc.id)),
                    onLongPress: () => _editPrice(doc),
                    child: Column(children: <Widget>[
                      Expanded(child: Stack(fit: StackFit.expand, children: <Widget>[
                        image.isEmpty ? const ColoredBox(color: Colors.black12, child: Icon(Icons.image_outlined)) : StorageImage(url: image, fit: BoxFit.cover),
                        Positioned(top: 6, right: 6, child: Checkbox(value: selected, onChanged: (_) => setState(() => selected ? _selected.remove(doc.id) : _selected.add(doc.id)))),
                      ])),
                      Padding(padding: const EdgeInsets.all(8), child: Row(children: <Widget>[Expanded(child: Text('${photo.unitPrice.toStringAsFixed(2)} €', style: const TextStyle(fontWeight: FontWeight.w800))), IconButton(tooltip: 'Modifier le prix', onPressed: () => _editPrice(doc), icon: const Icon(Icons.edit_outlined, size: 18))])),
                    ]),
                  ),
                );
              },
            );
          }),
          if (_hasMore) Padding(padding: const EdgeInsets.only(top: 16), child: OutlinedButton.icon(onPressed: _loading ? null : _loadMore, icon: _loading ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.expand_more), label: const Text('Charger plus de photos'))),
        ],
      ),
    );
  }
}

class _SalesCenter extends StatelessWidget {
  const _SalesCenter({required this.profile});
  final PhotographerProfileModel? profile;

  @override
  Widget build(BuildContext context) {
    final p = profile;
    if (p == null) return const Center(child: Text('Crée d’abord ton profil photographe.'));
    return FutureBuilder<List<MediaOrderModel>>(
      future: MediaOrderRepository().getByPhotographer(p.photographerId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        final orders = snapshot.data ?? const <MediaOrderModel>[];
        final gross = orders.fold<double>(0, (sum, order) => sum + order.total);
        final net = orders.fold<double>(0, (sum, order) => sum + order.photographerNetTotal);
        final fees = orders.fold<double>(0, (sum, order) => sum + order.platformFee + order.stripeFee);
        return ListView(padding: const EdgeInsets.all(16), children: <Widget>[
          Wrap(spacing: 12, runSpacing: 12, children: <Widget>[
            _Metric(label: 'Commandes', value: '${orders.length}'),
            _Metric(label: 'CA brut', value: '${gross.toStringAsFixed(2)} €'),
            _Metric(label: 'Frais', value: '${fees.toStringAsFixed(2)} €'),
            _Metric(label: 'Net photographe', value: '${net.toStringAsFixed(2)} €'),
          ]),
          const SizedBox(height: 16),
          for (final order in orders) Card(child: ExpansionTile(leading: const Icon(Icons.receipt_long_outlined), title: Text('${order.total.toStringAsFixed(2)} ${order.currency}'), subtitle: Text('${order.paymentStatus.name} • ${order.deliveryStatus.name} • ${order.createdAt.toLocal()}'), children: <Widget>[
            for (final item in order.items.where((item) => item.photographerId == p.photographerId)) ListTile(title: Text(item.title), subtitle: Text('${item.quantity} × ${item.unitPrice.toStringAsFixed(2)} € • galerie ${item.galleryId ?? '—'}'), trailing: Text('${item.lineSubtotal.toStringAsFixed(2)} €')),
            ListTile(title: const Text('Commission plateforme'), trailing: Text('${order.platformFee.toStringAsFixed(2)} €')),
            ListTile(title: const Text('Frais Stripe'), trailing: Text('${order.stripeFee.toStringAsFixed(2)} €')),
            ListTile(title: const Text('Net reversable'), trailing: Text('${order.photographerNetTotal.toStringAsFixed(2)} €', style: const TextStyle(fontWeight: FontWeight.w900))),
          ])),
        ]);
      },
    );
  }
}

class _SubscriptionLifecycle extends StatefulWidget {
  const _SubscriptionLifecycle({required this.profile, required this.onChanged});
  final PhotographerProfileModel? profile;
  final Future<void> Function() onChanged;

  @override
  State<_SubscriptionLifecycle> createState() => _SubscriptionLifecycleState();
}

class _SubscriptionLifecycleState extends State<_SubscriptionLifecycle> {
  bool _working = false;
  FirebaseFunctions get _functions => FirebaseFunctions.instanceFor(region: 'us-east1');

  Future<void> _call(String name) async {
    final p = widget.profile;
    if (p == null || _working) return;
    setState(() => _working = true);
    try {
      final result = await _functions.httpsCallable(name).call(<String, dynamic>{'photographerId': p.photographerId});
      final url = result.data is Map ? result.data['url']?.toString() : null;
      if (url != null && url.isNotEmpty) await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      await widget.onChanged();
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.profile;
    if (p == null) return const Center(child: Text('Crée d’abord ton profil photographe.'));
    final plan = MediaMarketplacePricing.planFor(p.activePlanId);
    return ListView(padding: const EdgeInsets.all(16), children: <Widget>[
      Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        Text('Formule active : ${plan.name}', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        Text('${plan.maxPublishedPhotos} photos • ${(plan.maxStorageBytes / (1024 * 1024 * 1024)).round()} Go • ${plan.maxActiveGalleries} galeries'),
        Text('${plan.qualityLabel} • ${(plan.commissionRate * 100).round()} % de commission • ${plan.retentionDays} jours de conservation'),
        const SizedBox(height: 16),
        Wrap(spacing: 8, runSpacing: 8, children: <Widget>[
          FilledButton.icon(onPressed: _working ? null : () => _call('createPhotographerBillingPortalLink'), icon: const Icon(Icons.open_in_new), label: const Text('Factures et moyen de paiement')),
          OutlinedButton.icon(onPressed: _working ? null : () => _call('cancelPhotographerSubscription'), icon: const Icon(Icons.pause_circle_outline), label: const Text('Annuler au prochain renouvellement')),
          OutlinedButton.icon(onPressed: _working ? null : () => _call('resumePhotographerSubscription'), icon: const Icon(Icons.play_circle_outline), label: const Text('Réactiver')),
        ]),
      ]))),
      const SizedBox(height: 14),
      Card(child: ListTile(leading: const Icon(Icons.storage_outlined), title: const Text('Extensions de stockage'), subtitle: const Text('Ajouter du stockage sans changer de formule.'), trailing: const Icon(Icons.chevron_right), onTap: () => Navigator.pushNamed(context, '/media-marketplace/subscription'))),
    ]);
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => SizedBox(width: 190, child: Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[Text(label, style: Theme.of(context).textTheme.bodySmall), const SizedBox(height: 6), Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900))]))));
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error, required this.onRetry});
  final Object error;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) => Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[Text(error.toString(), textAlign: TextAlign.center), const SizedBox(height: 12), FilledButton(onPressed: onRetry, child: const Text('Réessayer'))])));
}
