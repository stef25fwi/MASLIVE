import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../../services/auth_service.dart';
import '../../../../ui/theme/maslive_theme.dart';
import '../../../../ui/widgets/marketmap_poi_selector_sheet.dart';
import '../../../../ui/widgets/storage_image.dart';
import '../../core/constants/media_marketplace_pricing.dart';
import '../../core/enums/gallery_status.dart';
import '../../core/enums/media_pack_pricing_mode.dart';
import '../../core/enums/media_visibility.dart';
import '../../data/models/media_gallery_model.dart';
import '../../data/models/media_pack_model.dart';
import '../../data/models/media_photo_model.dart';
import '../../data/models/photographer_profile_model.dart';
import '../../data/repositories/media_gallery_repository.dart';
import '../../data/repositories/media_pack_repository.dart';
import '../../data/repositories/media_photo_repository.dart';
import '../../data/repositories/photographer_repository.dart';
import '../../domain/services/media_bulk_upload_service.dart';

class PhotographerGalleryManagerPage extends StatefulWidget {
  const PhotographerGalleryManagerPage({
    super.key,
    this.initialEventId,
    this.initialEventName,
    this.initialCircuitId,
    this.initialCircuitName,
  });

  final String? initialEventId;
  final String? initialEventName;
  final String? initialCircuitId;
  final String? initialCircuitName;

  @override
  State<PhotographerGalleryManagerPage> createState() =>
      _PhotographerGalleryManagerPageState();
}

class _PhotographerGalleryManagerPageState
    extends State<PhotographerGalleryManagerPage> {
  final _photographers = PhotographerRepository();
  final _galleries = MediaGalleryRepository();
  final _packs = MediaPackRepository();
  final _photos = MediaPhotoRepository();
  final _upload = MediaBulkUploadService();

  PhotographerProfileModel? _profile;
  List<MediaGalleryModel> _items = const <MediaGalleryModel>[];
  String? _selectedId;
  bool _loading = true;
  bool _working = false;
  Object? _error;
  MediaUploadProgress? _progress;

  MediaGalleryModel? get _selected {
    for (final gallery in _items) {
      if (gallery.galleryId == _selectedId) return gallery;
    }
    return _items.isEmpty ? null : _items.first;
  }

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final uid = AuthService.instance.currentUser?.uid;
      if (uid == null || uid.isEmpty) {
        throw StateError('Connecte-toi pour gérer ta boutique photos.');
      }
      final profile = await _photographers.getByOwnerUid(uid);
      if (profile == null) {
        throw StateError('Crée d’abord ton profil photographe MASLIVE.');
      }
      final galleries = await _galleries.getByPhotographer(
        profile.photographerId,
      );
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _items = galleries;
        _selectedId = galleries.any((item) => item.galleryId == _selectedId)
            ? _selectedId
            : (galleries.isEmpty ? null : galleries.first.galleryId);
      });
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _createGallery() async {
    final profile = _profile;
    if (profile == null || _working) return;
    final plan = MediaMarketplacePricing.planFor(profile.activePlanId);
    if (profile.activeGalleryCount >= plan.maxActiveGalleries) {
      _message(
        'Quota de ${plan.maxActiveGalleries} galerie(s) active(s) atteint.',
        error: true,
      );
      return;
    }

    final selection = await showMarketMapCircuitSelectorSheet(
      context,
      disableKeyboardInput: true,
    );
    if (selection == null || !selection.enabled || !mounted) return;
    if (selection.country == null ||
        selection.event == null ||
        selection.circuit == null) {
      _message('Sélectionne un pays, un événement et un circuit.', error: true);
      return;
    }

    final title = TextEditingController(
      text: '${selection.circuit!.name} — ${_date(DateTime.now())}',
    );
    final description = TextEditingController();
    var eventDate = DateTime.now();
    var visibility = MediaVisibility.public;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, updateDialog) => AlertDialog(
          title: const Text('Créer une galerie'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '${selection.event!.name} • ${selection.circuit!.name}',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: title,
                    decoration: const InputDecoration(
                      labelText: 'Nom de la galerie',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: description,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Date de prise de vue'),
                    subtitle: Text(_date(eventDate)),
                    trailing: const Icon(Icons.calendar_month_outlined),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: eventDate,
                        firstDate: DateTime.now().subtract(
                          const Duration(days: 365),
                        ),
                        lastDate: DateTime.now().add(
                          const Duration(days: 730),
                        ),
                      );
                      if (picked != null) {
                        updateDialog(() => eventDate = picked);
                      }
                    },
                  ),
                  DropdownButtonFormField<MediaVisibility>(
                    value: visibility,
                    decoration: const InputDecoration(
                      labelText: 'Visibilité après publication',
                      border: OutlineInputBorder(),
                    ),
                    items: MediaVisibility.values
                        .map(
                          (item) => DropdownMenuItem<MediaVisibility>(
                            value: item,
                            child: Text(item.label),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: (value) {
                      if (value != null) {
                        updateDialog(() => visibility = value);
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Les cinq packs MASLIVE sont créés automatiquement. Conservation ${plan.retentionDays} jours.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
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
      ),
    );
    if (confirmed != true || !mounted) return;
    if (title.text.trim().isEmpty) {
      _message('Le nom de la galerie est obligatoire.', error: true);
      return;
    }

    setState(() => _working = true);
    try {
      final now = DateTime.now();
      final ref = FirebaseFirestore.instance.collection('media_galleries').doc();
      final gallery = MediaGalleryModel(
        galleryId: ref.id,
        photographerId: profile.photographerId,
        ownerUid: profile.ownerUid,
        eventId: selection.event!.id,
        title: title.text.trim(),
        description:
            description.text.trim().isEmpty ? null : description.text.trim(),
        visibility: MediaVisibility.private,
        status: GalleryStatus.draft,
        linkedCountry: selection.country!.id,
        linkedCircuitId: selection.circuit!.id,
        createdAt: now,
        updatedAt: now,
      );
      await _galleries.createGallery(gallery);
      final expiresAt = eventDate.add(Duration(days: plan.retentionDays));
      await _galleries.updateGallery(
        galleryId: gallery.galleryId,
        patch: <String, dynamic>{
          'eventName': selection.event!.name,
          'circuitName': selection.circuit!.name,
          'countryName': selection.country!.name,
          'eventDate': Timestamp.fromDate(eventDate),
          'plannedVisibility': visibility.firestoreValue,
          'planCode': plan.code,
          'retentionDays': plan.retentionDays,
          'expiresAt': Timestamp.fromDate(expiresAt),
          'archiveAt': Timestamp.fromDate(expiresAt),
          'purgeAt': Timestamp.fromDate(
            expiresAt.add(const Duration(days: 30)),
          ),
          'updatedAt': FieldValue.serverTimestamp(),
        },
      );
      await _createDefaultPacks(profile, gallery);
      _selectedId = gallery.galleryId;
      await _reload();
      _message('Galerie créée avec les cinq packs MASLIVE.');
    } catch (error) {
      _message(error.toString(), error: true);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _createDefaultPacks(
    PhotographerProfileModel profile,
    MediaGalleryModel gallery,
  ) async {
    final now = DateTime.now();
    for (var index = 0;
        index < MediaMarketplacePricing.buyerPacks.length;
        index++) {
      final tier = MediaMarketplacePricing.buyerPacks[index];
      await _packs.createPack(
        MediaPackModel(
          packId: '${gallery.galleryId}_${tier.code}',
          photographerId: profile.photographerId,
          ownerUid: profile.ownerUid,
          galleryId: gallery.galleryId,
          eventId: gallery.eventId,
          title: tier.title,
          description: tier.description,
          pricingMode: MediaPackPricingMode.pickN,
          pickCount: tier.photoCount,
          price: tier.price,
          currency: 'EUR',
          sortOrder: index,
          createdAt: now,
          updatedAt: now,
        ),
      );
    }
  }

  Future<void> _addPhotos() async {
    final profile = _profile;
    final gallery = _selected;
    if (profile == null || gallery == null || _working) return;
    final files = await _upload.pickPhotos();
    if (files.isEmpty || !mounted) return;
    setState(() {
      _working = true;
      _progress = MediaUploadProgress(
        completed: 0,
        total: files.length,
        currentFile: files.first.name,
        bytesTransferred: 0,
        totalBytes: 0,
      );
    });
    try {
      final result = await _upload.uploadPhotos(
        profile: profile,
        gallery: gallery,
        files: files,
        onProgress: (progress) {
          if (mounted) setState(() => _progress = progress);
        },
      );
      _message(
        '${result.uploadedPhotoIds.length} photo(s) envoyée(s), ${result.rejectedFiles.length} rejetée(s).',
        error: result.uploadedPhotoIds.isEmpty,
      );
      await _reload();
    } catch (error) {
      _message(error.toString(), error: true);
    } finally {
      if (mounted) {
        setState(() {
          _working = false;
          _progress = null;
        });
      }
    }
  }

  Future<void> _publish(MediaGalleryModel gallery) async {
    final profile = _profile;
    if (profile == null || _working) return;
    if (!profile.stripeChargesEnabled || !profile.stripePayoutsEnabled) {
      _message('Termine Stripe Connect avant de publier.', error: true);
      return;
    }
    if (gallery.photoCount <= 0) {
      _message('Ajoute au moins une photo avant publication.', error: true);
      return;
    }
    setState(() => _working = true);
    try {
      final document = await FirebaseFirestore.instance
          .collection('media_galleries')
          .doc(gallery.galleryId)
          .get();
      final visibility =
          document.data()?['plannedVisibility']?.toString() ?? 'public';
      await _galleries.updateGallery(
        galleryId: gallery.galleryId,
        patch: <String, dynamic>{
          'status': GalleryStatus.published.firestoreValue,
          'visibility': visibility,
          'publishedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
      );
      await _reload();
      _message('Galerie publiée dans la boutique photo.');
    } catch (error) {
      _message(error.toString(), error: true);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _archive(MediaGalleryModel gallery) async {
    if (_working) return;
    setState(() => _working = true);
    try {
      await _galleries.archiveGallery(gallery.galleryId);
      await _galleries.updateGallery(
        galleryId: gallery.galleryId,
        patch: <String, dynamic>{
          'visibility': MediaVisibility.private.firestoreValue,
          'archivedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
      );
      await _reload();
    } catch (error) {
      _message(error.toString(), error: true);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _useFirstPhotoAsCover(MediaGalleryModel gallery) async {
    try {
      final photos = await _photos.getByGallery(gallery.galleryId);
      if (photos.isEmpty) {
        _message('Aucune photo disponible.', error: true);
        return;
      }
      await _galleries.updateCounters(
        galleryId: gallery.galleryId,
        coverPhotoId: photos.first.photoId,
        coverUrl: photos.first.thumbnailPath,
      );
      await _reload();
    } catch (error) {
      _message(error.toString(), error: true);
    }
  }

  void _message(String text, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text.replaceFirst('Bad state: ', '')),
        backgroundColor: error ? Colors.red.shade700 : null,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _date(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';

  @override
  Widget build(BuildContext context) {
    final profile = _profile;
    final selected = _selected;
    return Scaffold(
      backgroundColor: MasliveTheme.surfaceAlt,
      appBar: AppBar(
        title: const Text('Ma boutique photos'),
        actions: <Widget>[
          IconButton(
            onPressed: _working ? null : _reload,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : profile == null
              ? Center(child: Text(_error?.toString() ?? 'Profil indisponible'))
              : RefreshIndicator(
                  onRefresh: _reload,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                    children: <Widget>[
                      _QuotaCard(profile: profile),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: <Widget>[
                          FilledButton.icon(
                            onPressed: _working ? null : _createGallery,
                            icon: const Icon(Icons.create_new_folder_outlined),
                            label: const Text('Créer une galerie'),
                          ),
                          FilledButton.tonalIcon(
                            onPressed:
                                selected == null || _working ? null : _addPhotos,
                            icon: const Icon(Icons.add_photo_alternate_outlined),
                            label: const Text('Ajouter des photos'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => Navigator.pushNamed(
                              context,
                              '/media-marketplace',
                              arguments: <String, dynamic>{
                                'initialTab': 0,
                                'photographerId': profile.photographerId,
                                if (selected != null) 'eventId': selected.eventId,
                                if (selected?.linkedCircuitId != null)
                                  'circuitId': selected!.linkedCircuitId,
                              },
                            ),
                            icon: const Icon(Icons.storefront_outlined),
                            label: const Text('Voir ma boutique'),
                          ),
                        ],
                      ),
                      if (_progress != null) ...<Widget>[
                        const SizedBox(height: 14),
                        LinearProgressIndicator(value: _progress!.fraction),
                        Text(
                          '${_progress!.completed}/${_progress!.total} • ${_progress!.currentFile}',
                        ),
                      ],
                      const SizedBox(height: 22),
                      Text(
                        'Galeries rattachées aux circuits',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                      const SizedBox(height: 10),
                      if (_items.isEmpty)
                        const Card(
                          child: Padding(
                            padding: EdgeInsets.all(18),
                            child: Text('Crée ta première galerie par circuit.'),
                          ),
                        )
                      else
                        for (final gallery in _items)
                          Card(
                            color: gallery.galleryId == _selectedId
                                ? Colors.black87
                                : null,
                            child: ListTile(
                              onTap: () => setState(
                                () => _selectedId = gallery.galleryId,
                              ),
                              leading: SizedBox(
                                width: 58,
                                height: 58,
                                child: gallery.coverUrl?.isNotEmpty == true
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: StorageImage(
                                          url: gallery.coverUrl!,
                                          fit: BoxFit.cover,
                                        ),
                                      )
                                    : const Icon(Icons.photo_library_outlined),
                              ),
                              title: Text(
                                gallery.title,
                                style: TextStyle(
                                  color: gallery.galleryId == _selectedId
                                      ? Colors.white
                                      : null,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              subtitle: Text(
                                '${gallery.photoCount} photos • ${gallery.packCount} packs • ${gallery.status.label}',
                                style: TextStyle(
                                  color: gallery.galleryId == _selectedId
                                      ? Colors.white70
                                      : null,
                                ),
                              ),
                              trailing: const Icon(Icons.chevron_right),
                            ),
                          ),
                      if (selected != null) ...<Widget>[
                        const SizedBox(height: 16),
                        _GalleryActions(
                          gallery: selected,
                          working: _working,
                          onUpload: _addPhotos,
                          onPublish: () => _publish(selected),
                          onArchive: () => _archive(selected),
                          onCover: () => _useFirstPhotoAsCover(selected),
                        ),
                        const SizedBox(height: 16),
                        _PhotoGrid(galleryId: selected.galleryId),
                      ],
                    ],
                  ),
                ),
    );
  }
}

class _QuotaCard extends StatelessWidget {
  const _QuotaCard({required this.profile});

  final PhotographerProfileModel profile;

  @override
  Widget build(BuildContext context) {
    final plan = MediaMarketplacePricing.planFor(profile.activePlanId);
    final photoRatio = plan.photoRatio(profile.publishedPhotoCount);
    final storageRatio = plan.storageRatio(profile.storageUsedBytes);
    final ratio = photoRatio > storageRatio ? photoRatio : storageRatio;
    final color = ratio >= .95
        ? Colors.red
        : ratio >= .8
            ? Colors.orange
            : Colors.green;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Formule ${plan.name}',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            Text(
              '${plan.qualityLabel} • ${(plan.commissionRate * 100).round()} % • ${plan.retentionDays} jours',
            ),
            const SizedBox(height: 12),
            Text('${profile.publishedPhotoCount} / ${plan.maxPublishedPhotos} photos'),
            LinearProgressIndicator(value: photoRatio.clamp(0, 1), color: color),
            const SizedBox(height: 10),
            Text(
              '${(profile.storageUsedBytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} / ${(plan.maxStorageBytes / (1024 * 1024 * 1024)).round()} Go',
            ),
            LinearProgressIndicator(
              value: storageRatio.clamp(0, 1),
              color: color,
            ),
            if (ratio >= .8) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                ratio >= .95
                    ? 'Quota presque atteint : les ventes restent actives, mais les imports seront bloqués à 100 %.'
                    : 'Plus de 80 % du quota est utilisé.',
                style: TextStyle(color: color, fontWeight: FontWeight.w700),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _GalleryActions extends StatelessWidget {
  const _GalleryActions({
    required this.gallery,
    required this.working,
    required this.onUpload,
    required this.onPublish,
    required this.onArchive,
    required this.onCover,
  });

  final MediaGalleryModel gallery;
  final bool working;
  final VoidCallback onUpload;
  final VoidCallback onPublish;
  final VoidCallback onArchive;
  final VoidCallback onCover;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            FilledButton.icon(
              onPressed: working ? null : onUpload,
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: const Text('Ajouter'),
            ),
            OutlinedButton.icon(
              onPressed: working ? null : onCover,
              icon: const Icon(Icons.wallpaper_outlined),
              label: const Text('Couverture'),
            ),
            if (gallery.status != GalleryStatus.published)
              FilledButton.tonalIcon(
                onPressed: working ? null : onPublish,
                icon: const Icon(Icons.publish_rounded),
                label: const Text('Publier'),
              ),
            if (gallery.status != GalleryStatus.archived)
              OutlinedButton.icon(
                onPressed: working ? null : onArchive,
                icon: const Icon(Icons.archive_outlined),
                label: const Text('Archiver'),
              ),
          ],
        ),
      ),
    );
  }
}

class _PhotoGrid extends StatelessWidget {
  const _PhotoGrid({required this.galleryId});

  final String galleryId;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<MediaPhotoModel>>(
      future: MediaPhotoRepository().getByGallery(galleryId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final photos = snapshot.data ?? const <MediaPhotoModel>[];
        if (photos.isEmpty) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(18),
              child: Text('Les miniatures apparaîtront après traitement.'),
            ),
          );
        }
        final visible = photos.take(24).toList(growable: false);
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 150,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
          ),
          itemCount: visible.length,
          itemBuilder: (context, index) {
            final photo = visible[index];
            final path = photo.thumbnailPath.isNotEmpty
                ? photo.thumbnailPath
                : photo.watermarkedPath;
            return ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: path.isEmpty
                  ? const ColoredBox(
                      color: Colors.black12,
                      child: Icon(Icons.hourglass_top_rounded),
                    )
                  : StorageImage(url: path, fit: BoxFit.cover),
            );
          },
        );
      },
    );
  }
}
