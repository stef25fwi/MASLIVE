import 'package:flutter/material.dart';

import '../../../../ui/theme/maslive_theme.dart';
import '../../../../ui/widgets/marketmap_poi_selector_sheet.dart';
import '../../../../ui/widgets/storage_image.dart';
import '../../data/models/media_gallery_model.dart';
import '../../data/models/media_pack_model.dart';
import '../../data/models/media_photo_model.dart';
import '../../data/models/photographer_profile_model.dart';
import '../../data/models/photographer_subscription_model.dart';
import '../../data/repositories/media_gallery_repository.dart';
import '../../data/repositories/media_pack_repository.dart';
import '../../data/repositories/media_photo_repository.dart';
import '../../data/repositories/photographer_repository.dart';
import '../../data/repositories/photographer_subscription_repository.dart';
import '../../domain/catalog/photographer_commercial_catalog.dart';
import '../../data/services/photographer_media_upload_service.dart';

class PhotographerGalleryManagerPage extends StatefulWidget {
  const PhotographerGalleryManagerPage({
    super.key,
    required this.photographerId,
    this.initialEventId,
    this.initialEventName,
    this.initialCircuitId,
    this.initialCircuitName,
    this.initialCountryId,
    this.initialCountryName,
    this.openUploaderOnStart = false,
  });

  final String photographerId;
  final String? initialEventId;
  final String? initialEventName;
  final String? initialCircuitId;
  final String? initialCircuitName;
  final String? initialCountryId;
  final String? initialCountryName;
  final bool openUploaderOnStart;

  @override
  State<PhotographerGalleryManagerPage> createState() =>
      _PhotographerGalleryManagerPageState();
}

class _PhotographerGalleryManagerPageState
    extends State<PhotographerGalleryManagerPage> {
  final PhotographerRepository _photographerRepository = PhotographerRepository();
  final PhotographerSubscriptionRepository _subscriptionRepository =
      PhotographerSubscriptionRepository();
  final MediaGalleryRepository _galleryRepository = MediaGalleryRepository();
  final MediaPhotoRepository _photoRepository = MediaPhotoRepository();
  final MediaPackRepository _packRepository = MediaPackRepository();
  final PhotographerMediaUploadService _uploadService =
      PhotographerMediaUploadService();

  PhotographerProfileModel? _profile;
  PhotographerSubscriptionModel? _subscription;
  List<MediaGalleryModel> _galleries = const <MediaGalleryModel>[];
  List<MediaPhotoModel> _photos = const <MediaPhotoModel>[];
  List<MediaPackModel> _packs = const <MediaPackModel>[];
  String? _selectedGalleryId;
  bool _loading = true;
  bool _busy = false;
  bool _didOpenUploader = false;
  Object? _error;
  PhotographerUploadProgress? _uploadProgress;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({String? selectGalleryId}) async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final results = await Future.wait<dynamic>(<Future<dynamic>>[
        _photographerRepository.getById(widget.photographerId),
        _subscriptionRepository.getActiveByPhotographerId(widget.photographerId),
        _galleryRepository.getByPhotographer(widget.photographerId),
      ]);
      final profile = results[0] as PhotographerProfileModel?;
      final subscription = results[1] as PhotographerSubscriptionModel?;
      final galleries = results[2] as List<MediaGalleryModel>;
      final nextSelected = selectGalleryId ??
          (_selectedGalleryId != null &&
                  galleries.any((g) => g.galleryId == _selectedGalleryId)
              ? _selectedGalleryId
              : galleries.isNotEmpty
                  ? galleries.first.galleryId
                  : null);

      if (!mounted) return;
      setState(() {
        _profile = profile;
        _subscription = subscription;
        _galleries = galleries;
        _selectedGalleryId = nextSelected;
      });
      if (nextSelected != null) {
        await _loadGallery(nextSelected, showLoader: false);
      } else if (mounted) {
        setState(() {
          _photos = const <MediaPhotoModel>[];
          _packs = const <MediaPackModel>[];
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }

    if (widget.openUploaderOnStart &&
        !_didOpenUploader &&
        mounted &&
        _selectedGalleryId != null) {
      _didOpenUploader = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _addPhotos());
    }
  }

  Future<void> _loadGallery(String galleryId, {bool showLoader = true}) async {
    if (showLoader && mounted) setState(() => _busy = true);
    try {
      final results = await Future.wait<dynamic>(<Future<dynamic>>[
        _photoRepository.getByGallery(galleryId),
        _packRepository.getByGallery(galleryId),
      ]);
      if (!mounted) return;
      setState(() {
        _selectedGalleryId = galleryId;
        _photos = results[0] as List<MediaPhotoModel>;
        _packs = results[1] as List<MediaPackModel>;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (showLoader && mounted) setState(() => _busy = false);
    }
  }

  PhotographerPlanDefinition get _commercialPlan {
    final code = _subscription?.quotaSnapshot.planCode ??
        _profile?.activePlanId ??
        _subscription?.planId;
    return PhotographerCommercialCatalog.resolve(code);
  }

  int get _photoLimit {
    final snapshot = _subscription?.quotaSnapshot.maxPublishedPhotos ?? 0;
    return snapshot > 0 ? snapshot : _commercialPlan.maxPublishedPhotos;
  }

  int get _storageLimit {
    final snapshot = _subscription?.quotaSnapshot.maxStorageBytes ?? 0;
    return snapshot > 0 ? snapshot : _commercialPlan.maxStorageBytes;
  }

  int get _galleryLimit {
    final snapshot = _subscription?.quotaSnapshot.maxActiveGalleries ?? 0;
    return snapshot > 0 ? snapshot : _commercialPlan.maxActiveGalleries;
  }

  double get _commissionRate {
    final snapshot = _subscription?.quotaSnapshot.commissionRate ?? 0;
    return snapshot > 0 ? snapshot : _commercialPlan.commissionRate;
  }

  MediaGalleryModel? get _selectedGallery {
    final id = _selectedGalleryId;
    if (id == null) return null;
    for (final gallery in _galleries) {
      if (gallery.galleryId == id) return gallery;
    }
    return null;
  }

  Future<void> _createGallery() async {
    if (_profile == null || _busy) return;
    if (_profile!.activeGalleryCount >= _galleryLimit) {
      _showMessage('Le quota de galeries actives est atteint.', error: true);
      return;
    }

    final selection = await showMarketMapCircuitSelectorSheet(
      context,
      initial: null,
      disableKeyboardInput: true,
    );
    if (selection == null || !mounted) return;

    final circuit = selection.circuit;
    final event = selection.event;
    final country = selection.country;
    if (circuit == null || event == null || country == null) {
      _showMessage('Sélectionne un pays, un événement et un circuit.', error: true);
      return;
    }

    final titleController = TextEditingController(
      text: '${circuit.name} — ${DateTime.now().day.toString().padLeft(2, '0')}/'
          '${DateTime.now().month.toString().padLeft(2, '0')}',
    );
    final descriptionController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Créer une galerie'),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextField(
                controller: titleController,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Nom de la galerie'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descriptionController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Description facultative',
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${country.name} • ${event.name} • ${circuit.name}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Créer'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final title = titleController.text.trim();
    if (title.isEmpty) {
      _showMessage('Le nom de la galerie est obligatoire.', error: true);
      return;
    }

    await _runAction(() async {
      final galleryId = await _uploadService.createGallery(
        photographerId: widget.photographerId,
        title: title,
        description: descriptionController.text.trim(),
        eventId: event.id,
        eventName: event.name,
        circuitId: circuit.id,
        circuitName: circuit.name,
        countryId: country.id,
        countryName: country.name,
      );
      await _load(selectGalleryId: galleryId);
      _showMessage('Galerie créée. Tu peux maintenant ajouter tes photos.');
    });
  }

  Future<void> _addPhotos() async {
    final gallery = _selectedGallery;
    final profile = _profile;
    if (gallery == null || profile == null || _busy) return;
    final remainingPhotos = (_photoLimit - profile.publishedPhotoCount)
        .clamp(0, _photoLimit)
        .toInt();
    final maxCount = remainingPhotos < _commercialPlan.maxBatchUpload
        ? remainingPhotos
        : _commercialPlan.maxBatchUpload;
    if (maxCount <= 0) {
      _showMessage('Le quota photo est atteint.', error: true);
      return;
    }

    final files = await _uploadService.selectPhotos(maxCount: maxCount);
    if (files.isEmpty || !mounted) return;

    final priceController = TextEditingController(text: '6.90');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Ajouter ${files.length} photo${files.length > 1 ? 's' : ''}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Galerie : ${gallery.title}'),
            const SizedBox(height: 12),
            TextField(
              controller: priceController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Prix unitaire conseillé',
                suffixText: '€',
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Les originaux restent privés. La boutique affiche uniquement des miniatures et aperçus filigranés.',
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Importer'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final price = double.tryParse(priceController.text.replaceAll(',', '.')) ?? 6.90;

    await _runAction(() async {
      await _uploadService.uploadPhotos(
        photographerId: widget.photographerId,
        galleryId: gallery.galleryId,
        files: files,
        unitPrice: price.clamp(0.99, 99.0).toDouble(),
        onProgress: (progress) {
          if (mounted) setState(() => _uploadProgress = progress);
        },
      );
      await _load(selectGalleryId: gallery.galleryId);
      _showMessage('${files.length} photo${files.length > 1 ? 's ajoutées' : ' ajoutée'}.');
    });
  }

  Future<void> _publishGallery() async {
    final gallery = _selectedGallery;
    if (gallery == null || _busy) return;
    if (_photos.isEmpty) {
      _showMessage('Ajoute au moins une photo avant de publier.', error: true);
      return;
    }
    await _runAction(() async {
      await _uploadService.publishGallery(
        photographerId: widget.photographerId,
        galleryId: gallery.galleryId,
      );
      await _load(selectGalleryId: gallery.galleryId);
      _showMessage('Galerie publiée dans la boutique photo.');
    });
  }

  Future<void> _archiveGallery() async {
    final gallery = _selectedGallery;
    if (gallery == null || _busy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Archiver la galerie ?'),
        content: const Text(
          'Elle disparaîtra de la boutique mais les achats existants resteront téléchargeables.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Archiver'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _runAction(() async {
      await _uploadService.archiveGallery(
        photographerId: widget.photographerId,
        galleryId: gallery.galleryId,
      );
      await _load(selectGalleryId: gallery.galleryId);
      _showMessage('Galerie archivée.');
    });
  }

  Future<void> _ensurePacks() async {
    final gallery = _selectedGallery;
    if (gallery == null || _busy) return;
    await _runAction(() async {
      await _uploadService.createRecommendedPacks(
        photographerId: widget.photographerId,
        galleryId: gallery.galleryId,
      );
      await _loadGallery(gallery.galleryId, showLoader: false);
      _showMessage('Les packs recommandés ont été créés.');
    });
  }

  Future<void> _deletePhoto(MediaPhotoModel photo) async {
    if (_busy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Supprimer cette photo ?'),
        content: const Text(
          'L’original et ses miniatures seront supprimés. Une photo déjà achetée ne peut pas être supprimée.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _runAction(() async {
      await _uploadService.deletePhoto(
        photographerId: widget.photographerId,
        photoId: photo.photoId,
      );
      await _load(selectGalleryId: photo.galleryId);
      _showMessage('Photo supprimée.');
    });
  }

  Future<void> _runAction(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _uploadProgress = null;
    });
    try {
      await action();
    } catch (error) {
      if (mounted) {
        setState(() => _error = error);
        _showMessage(_friendlyError(error), error: true);
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _uploadProgress = null;
        });
      }
    }
  }

  String _friendlyError(Object error) {
    final raw = error.toString();
    return raw.replaceFirst('Exception: ', '').replaceFirst('StateError: ', '');
  }

  void _showMessage(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? Colors.red.shade700 : null,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profile;
    return Scaffold(
      backgroundColor: MasliveTheme.surfaceAlt,
      appBar: AppBar(
        title: const Text('Ma boutique photos'),
        actions: <Widget>[
          IconButton(
            onPressed: _busy ? null : () => _load(),
            tooltip: 'Actualiser',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading && profile == null
          ? const Center(child: CircularProgressIndicator())
          : profile == null
              ? _EmptyState(
                  title: 'Profil photographe introuvable',
                  message: _error?.toString() ??
                      'Aucun profil photographe n’est rattaché à ce compte.',
                )
              : Stack(
                  children: <Widget>[
                    RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(
                          parent: BouncingScrollPhysics(),
                        ),
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                        children: <Widget>[
                          _PlanAndQuotaCard(
                            plan: _commercialPlan,
                            profile: profile,
                            photoLimit: _photoLimit,
                            storageLimit: _storageLimit,
                            galleryLimit: _galleryLimit,
                            commissionRate: _commissionRate,
                          ),
                          const SizedBox(height: 16),
                          _ActionPanel(
                            hasGallery: _selectedGallery != null,
                            busy: _busy,
                            onCreateGallery: _createGallery,
                            onAddPhotos: _addPhotos,
                            onCreatePacks: _ensurePacks,
                            onPublish: _publishGallery,
                            onArchive: _archiveGallery,
                          ),
                          if (_uploadProgress != null) ...<Widget>[
                            const SizedBox(height: 16),
                            _UploadProgressCard(progress: _uploadProgress!),
                          ],
                          if (_error != null) ...<Widget>[
                            const SizedBox(height: 16),
                            Card(
                              color: Colors.red.shade50,
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Text(
                                  _friendlyError(_error!),
                                  style: TextStyle(color: Colors.red.shade900),
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 20),
                          Text(
                            'Galeries rattachées aux circuits',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'La boutique affiche automatiquement en premier les galeries du circuit choisi sur la carte d’accueil.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 12),
                          if (_galleries.isEmpty)
                            _EmptyState(
                              title: 'Aucune galerie',
                              message:
                                  'Crée une galerie, rattache-la à un circuit puis ajoute tes photos.',
                              actionLabel: 'Créer une galerie',
                              onAction: _createGallery,
                            )
                          else
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: _galleries
                                  .map(
                                    (gallery) => _GalleryChoiceCard(
                                      gallery: gallery,
                                      selected: gallery.galleryId ==
                                          _selectedGalleryId,
                                      onTap: () =>
                                          _loadGallery(gallery.galleryId),
                                    ),
                                  )
                                  .toList(growable: false),
                            ),
                          if (_selectedGallery != null) ...<Widget>[
                            const SizedBox(height: 24),
                            _SelectedGalleryHeader(
                              gallery: _selectedGallery!,
                              photoCount: _photos.length,
                              packCount: _packs.length,
                            ),
                            const SizedBox(height: 12),
                            _PackSummary(packs: _packs),
                            const SizedBox(height: 18),
                            Text(
                              'Miniatures de la galerie',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 10),
                            if (_photos.isEmpty)
                              _EmptyState(
                                title: 'Galerie vide',
                                message:
                                    'Ajoute des photos. Les originaux resteront privés et seules les miniatures filigranées seront visibles.',
                                actionLabel: 'Ajouter des photos',
                                onAction: _addPhotos,
                              )
                            else
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  final width = constraints.maxWidth;
                                  final columns = width >= 1100
                                      ? 5
                                      : width >= 760
                                          ? 4
                                          : width >= 520
                                              ? 3
                                              : 2;
                                  return GridView.builder(
                                    shrinkWrap: true,
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    itemCount: _photos.length,
                                    gridDelegate:
                                        SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: columns,
                                      crossAxisSpacing: 10,
                                      mainAxisSpacing: 10,
                                      childAspectRatio: 0.78,
                                    ),
                                    itemBuilder: (context, index) {
                                      final photo = _photos[index];
                                      return _OwnerPhotoTile(
                                        photo: photo,
                                        onDelete: () => _deletePhoto(photo),
                                      );
                                    },
                                  );
                                },
                              ),
                          ],
                        ],
                      ),
                    ),
                    if (_busy)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: ColoredBox(
                            color: Colors.black.withValues(alpha: 0.08),
                          ),
                        ),
                      ),
                  ],
                ),
    );
  }
}

class _PlanAndQuotaCard extends StatelessWidget {
  const _PlanAndQuotaCard({
    required this.plan,
    required this.profile,
    required this.photoLimit,
    required this.storageLimit,
    required this.galleryLimit,
    required this.commissionRate,
  });

  final PhotographerPlanDefinition plan;
  final PhotographerProfileModel profile;
  final int photoLimit;
  final int storageLimit;
  final int galleryLimit;
  final double commissionRate;

  @override
  Widget build(BuildContext context) {
    final photoRatio = _ratio(profile.publishedPhotoCount, photoLimit);
    final storageRatio = _ratio(profile.storageUsedBytes, storageLimit);
    final galleryRatio = _ratio(profile.activeGalleryCount, galleryLimit);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Icon(Icons.workspace_premium_outlined),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Offre ${plan.name}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                Text(
                  plan.monthlyPrice == 0
                      ? 'Gratuit'
                      : '${plan.monthlyPrice.toStringAsFixed(2)} €/mois',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Commission MASLIVE : ${(commissionRate * 100).round()} % • '
              'Qualité max : ${plan.maxMegapixels} Mpx • '
              'Conservation : ${plan.retentionDays} jours',
            ),
            const SizedBox(height: 16),
            _QuotaLine(
              label: 'Photos',
              value: '${profile.publishedPhotoCount} / $photoLimit',
              ratio: photoRatio,
            ),
            const SizedBox(height: 12),
            _QuotaLine(
              label: 'Stockage',
              value:
                  '${_formatBytes(profile.storageUsedBytes)} / ${_formatBytes(storageLimit)}',
              ratio: storageRatio,
            ),
            const SizedBox(height: 12),
            _QuotaLine(
              label: 'Galeries actives',
              value: '${profile.activeGalleryCount} / $galleryLimit',
              ratio: galleryRatio,
            ),
            if (photoRatio >= 0.8 || storageRatio >= 0.8 || galleryRatio >= 0.8) ...<Widget>[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: (photoRatio >= 0.95 ||
                          storageRatio >= 0.95 ||
                          galleryRatio >= 0.95)
                      ? Colors.red.shade50
                      : Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: <Widget>[
                    Icon(Icons.warning_amber_rounded),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Ton quota approche de sa limite. Archive une ancienne galerie ou change d’offre avant le prochain import.',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static double _ratio(int value, int max) {
    if (max <= 0) return 0;
    return (value / max).clamp(0.0, 1.0);
  }

  static String _formatBytes(int bytes) {
    const gb = 1024 * 1024 * 1024;
    const mb = 1024 * 1024;
    if (bytes >= gb) return '${(bytes / gb).toStringAsFixed(1)} Go';
    return '${(bytes / mb).toStringAsFixed(0)} Mo';
  }
}

class _QuotaLine extends StatelessWidget {
  const _QuotaLine({
    required this.label,
    required this.value,
    required this.ratio,
  });

  final String label;
  final String value;
  final double ratio;

  @override
  Widget build(BuildContext context) {
    final color = ratio >= 0.95
        ? Colors.red
        : ratio >= 0.8
            ? Colors.orange
            : Theme.of(context).colorScheme.primary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(child: Text(label)),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
        const SizedBox(height: 6),
        LinearProgressIndicator(
          value: ratio,
          minHeight: 8,
          borderRadius: BorderRadius.circular(999),
          color: color,
        ),
      ],
    );
  }
}

class _ActionPanel extends StatelessWidget {
  const _ActionPanel({
    required this.hasGallery,
    required this.busy,
    required this.onCreateGallery,
    required this.onAddPhotos,
    required this.onCreatePacks,
    required this.onPublish,
    required this.onArchive,
  });

  final bool hasGallery;
  final bool busy;
  final VoidCallback onCreateGallery;
  final VoidCallback onAddPhotos;
  final VoidCallback onCreatePacks;
  final VoidCallback onPublish;
  final VoidCallback onArchive;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Actions rapides', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: <Widget>[
                FilledButton.icon(
                  onPressed: busy ? null : onCreateGallery,
                  icon: const Icon(Icons.create_new_folder_outlined),
                  label: const Text('Créer une galerie'),
                ),
                FilledButton.tonalIcon(
                  onPressed: busy || !hasGallery ? null : onAddPhotos,
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  label: const Text('Ajouter des photos'),
                ),
                OutlinedButton.icon(
                  onPressed: busy || !hasGallery ? null : onCreatePacks,
                  icon: const Icon(Icons.inventory_2_outlined),
                  label: const Text('Créer les packs'),
                ),
                OutlinedButton.icon(
                  onPressed: busy || !hasGallery ? null : onPublish,
                  icon: const Icon(Icons.storefront_outlined),
                  label: const Text('Publier'),
                ),
                TextButton.icon(
                  onPressed: busy || !hasGallery ? null : onArchive,
                  icon: const Icon(Icons.archive_outlined),
                  label: const Text('Archiver'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _UploadProgressCard extends StatelessWidget {
  const _UploadProgressCard({required this.progress});

  final PhotographerUploadProgress progress;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(progress.stage, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(progress.fileName, maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 10),
            LinearProgressIndicator(value: progress.fraction),
            const SizedBox(height: 6),
            Text('${progress.completed} / ${progress.total}'),
          ],
        ),
      ),
    );
  }
}

class _GalleryChoiceCard extends StatelessWidget {
  const _GalleryChoiceCard({
    required this.gallery,
    required this.selected,
    required this.onTap,
  });

  final MediaGalleryModel gallery;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 280,
      child: Card(
        color: selected ? Theme.of(context).colorScheme.primaryContainer : null,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        gallery.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    if (selected) const Icon(Icons.check_circle),
                  ],
                ),
                const SizedBox(height: 8),
                Text('${gallery.photoCount} photos • ${gallery.packCount} packs'),
                const SizedBox(height: 4),
                Text(
                  gallery.status.name.toUpperCase(),
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectedGalleryHeader extends StatelessWidget {
  const _SelectedGalleryHeader({
    required this.gallery,
    required this.photoCount,
    required this.packCount,
  });

  final MediaGalleryModel gallery;
  final int photoCount;
  final int packCount;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.photo_library_outlined)),
        title: Text(gallery.title),
        subtitle: Text(
          '${gallery.linkedCountry ?? 'Pays'} • circuit ${gallery.linkedCircuitId ?? '--'}\n'
          '$photoCount photos • $packCount packs • ${gallery.status.name}',
        ),
        isThreeLine: true,
      ),
    );
  }
}

class _PackSummary extends StatelessWidget {
  const _PackSummary({required this.packs});

  final List<MediaPackModel> packs;

  @override
  Widget build(BuildContext context) {
    final definitions = PhotographerCommercialCatalog.buyerPacks;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('Packs acheteurs', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        SizedBox(
          height: 126,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: definitions.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final definition = definitions[index];
              final active = packs.any((pack) =>
                  pack.pickCount == definition.pickCount && pack.isActive);
              return Container(
                width: 210,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: definition.recommended
                      ? Theme.of(context).colorScheme.primaryContainer
                      : Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: active
                        ? Colors.green
                        : Theme.of(context).dividerColor,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            definition.title,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                        if (active)
                          const Icon(Icons.check_circle, color: Colors.green, size: 18),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text('${definition.price.toStringAsFixed(2)} €'),
                    const SizedBox(height: 4),
                    Text(
                      definition.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _OwnerPhotoTile extends StatelessWidget {
  const _OwnerPhotoTile({required this.photo, required this.onDelete});

  final MediaPhotoModel photo;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                StorageImage(
                  url: photo.thumbnailPath.isNotEmpty
                      ? photo.thumbnailPath
                      : photo.previewPath,
                  fit: BoxFit.cover,
                ),
                Center(
                  child: Transform.rotate(
                    angle: -0.18,
                    child: Text(
                      'MASLIVE',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.60),
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                        shadows: const <Shadow>[
                          Shadow(color: Colors.black45, blurRadius: 3),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: IconButton.filledTonal(
                    onPressed: onDelete,
                    tooltip: 'Supprimer',
                    icon: const Icon(Icons.delete_outline, size: 18),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(9),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  photo.downloadFileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 3),
                Text(
                  '${photo.unitPrice.toStringAsFixed(2)} ${photo.currency} • '
                  '${photo.isPublished ? 'publiée' : 'brouillon'}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: <Widget>[
            const Icon(Icons.photo_library_outlined, size: 44),
            const SizedBox(height: 10),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(message, textAlign: TextAlign.center),
            if (actionLabel != null && onAction != null) ...<Widget>[
              const SizedBox(height: 14),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
