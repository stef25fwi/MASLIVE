import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/enums/gallery_status.dart';
import '../../data/models/media_gallery_model.dart';
import '../../data/models/media_pack_model.dart';
import '../../data/models/media_photo_model.dart';
import '../../data/models/photographer_profile_model.dart';
import '../../data/services/photographer_media_upload_service.dart';
import '../../../../ui/theme/maslive_theme.dart';
import '../../../../ui/widgets/storage_image.dart';

class PhotographerGalleryManager extends StatefulWidget {
  const PhotographerGalleryManager({
    super.key,
    required this.profile,
    required this.galleries,
    required this.selectedGalleryId,
    required this.selectedPhotos,
    required this.selectedPacks,
    required this.onSelectGallery,
    required this.onRefresh,
    this.countryId,
    this.countryName,
    this.eventId,
    this.eventName,
    this.circuitId,
    this.circuitName,
  });

  final PhotographerProfileModel profile;
  final List<MediaGalleryModel> galleries;
  final String? selectedGalleryId;
  final List<MediaPhotoModel> selectedPhotos;
  final List<MediaPackModel> selectedPacks;
  final Future<void> Function(String galleryId) onSelectGallery;
  final Future<void> Function() onRefresh;
  final String? countryId;
  final String? countryName;
  final String? eventId;
  final String? eventName;
  final String? circuitId;
  final String? circuitName;

  @override
  State<PhotographerGalleryManager> createState() =>
      _PhotographerGalleryManagerState();
}

class _PhotographerGalleryManagerState
    extends State<PhotographerGalleryManager> {
  final PhotographerMediaUploadService _service =
      PhotographerMediaUploadService();

  PhotographerMediaQuota? _quota;
  PhotographerUploadProgress? _progress;
  bool _busy = false;
  bool _loadingQuota = false;
  String? _error;

  MediaGalleryModel? get _selectedGallery {
    for (final gallery in widget.galleries) {
      if (gallery.galleryId == widget.selectedGalleryId) return gallery;
    }
    return null;
  }

  bool get _hasCircuitContext =>
      widget.countryId?.trim().isNotEmpty == true &&
      widget.eventId?.trim().isNotEmpty == true &&
      widget.circuitId?.trim().isNotEmpty == true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadQuota());
  }

  @override
  void didUpdateWidget(covariant PhotographerGalleryManager oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profile.photographerId != widget.profile.photographerId ||
        oldWidget.profile.publishedPhotoCount !=
            widget.profile.publishedPhotoCount ||
        oldWidget.profile.storageUsedBytes != widget.profile.storageUsedBytes ||
        oldWidget.profile.activeGalleryCount !=
            widget.profile.activeGalleryCount) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadQuota());
    }
  }

  Future<void> _loadQuota() async {
    if (_loadingQuota || !mounted) return;
    setState(() => _loadingQuota = true);
    try {
      final quota = await _service.getQuota(widget.profile.photographerId);
      if (mounted) setState(() => _quota = quota);
    } catch (error) {
      if (mounted) setState(() => _error = _friendlyError(error));
    } finally {
      if (mounted) setState(() => _loadingQuota = false);
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      await widget.onRefresh();
      await _loadQuota();
    } catch (error) {
      if (mounted) setState(() => _error = _friendlyError(error));
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _progress = null;
        });
      }
    }
  }

  String _friendlyError(Object error) {
    final raw = error.toString().replaceFirst('Exception: ', '');
    if (raw.contains('resource-exhausted')) {
      return 'Le quota de votre abonnement est atteint. Archivez des médias ou changez d’offre.';
    }
    if (raw.contains('permission-denied')) {
      return 'Vous n’avez pas l’autorisation de modifier cette galerie.';
    }
    if (raw.contains('failed-precondition')) {
      return 'Cette action n’est pas encore possible. Vérifiez la validation du profil et le contenu de la galerie.';
    }
    return raw;
  }

  Future<void> _createGallery() async {
    if (!_hasCircuitContext) {
      setState(() {
        _error =
            'Sélectionnez un pays, un événement et un circuit avant de créer une galerie.';
      });
      return;
    }

    final titleController = TextEditingController(
      text: widget.circuitName?.trim().isNotEmpty == true
          ? '${widget.circuitName} • ${_dateLabel(DateTime.now())}'
          : 'Nouvelle galerie • ${_dateLabel(DateTime.now())}',
    );
    final descriptionController = TextEditingController();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Créer une galerie'),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextField(
                controller: titleController,
                autofocus: true,
                maxLength: 120,
                decoration: const InputDecoration(labelText: 'Nom de la galerie'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: descriptionController,
                maxLength: 1000,
                minLines: 2,
                maxLines: 4,
                decoration:
                    const InputDecoration(labelText: 'Description facultative'),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${widget.countryName ?? widget.countryId} • '
                  '${widget.eventName ?? widget.eventId} • '
                  '${widget.circuitName ?? widget.circuitId}',
                  style: Theme.of(dialogContext).textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Créer'),
          ),
        ],
      ),
    );

    final title = titleController.text.trim();
    final description = descriptionController.text.trim();
    titleController.dispose();
    descriptionController.dispose();
    if (accepted != true || title.isEmpty || !mounted) return;

    String? createdId;
    await _run(() async {
      createdId = await _service.createGallery(
        photographerId: widget.profile.photographerId,
        title: title,
        description: description.isEmpty ? null : description,
        countryId: widget.countryId!.trim(),
        countryName: widget.countryName,
        eventId: widget.eventId!.trim(),
        eventName: widget.eventName,
        circuitId: widget.circuitId!.trim(),
        circuitName: widget.circuitName,
      );
    });
    if (createdId?.isNotEmpty == true && mounted) {
      await widget.onSelectGallery(createdId!);
    }
  }

  Future<void> _uploadPhotos() async {
    final gallery = _selectedGallery;
    if (gallery == null) {
      setState(() => _error = 'Sélectionnez une galerie avant l’import.');
      return;
    }
    if (_quota == null) await _loadQuota();
    final quota = _quota;
    if (quota == null || !mounted) return;

    final maxCount = math.min(
      quota.maxBatchUpload,
      quota.photoCapacityRemaining,
    );
    if (maxCount <= 0) {
      setState(() => _error = 'Votre quota photo est atteint.');
      return;
    }

    final files = await _service.selectPhotos(maxCount: maxCount);
    if (files.isEmpty || !mounted) return;

    await _run(() async {
      await _service.uploadPhotos(
        photographerId: widget.profile.photographerId,
        galleryId: gallery.galleryId,
        files: files,
        unitPrice: 6.90,
        onProgress: (progress) {
          if (mounted) setState(() => _progress = progress);
        },
      );
      await widget.onSelectGallery(gallery.galleryId);
    });
  }

  Future<void> _publishGallery() async {
    final gallery = _selectedGallery;
    if (gallery == null) return;
    await _run(() async {
      await _service.publishGallery(
        photographerId: widget.profile.photographerId,
        galleryId: gallery.galleryId,
      );
      await _service.createRecommendedPacks(
        photographerId: widget.profile.photographerId,
        galleryId: gallery.galleryId,
      );
      await widget.onSelectGallery(gallery.galleryId);
    });
  }

  Future<void> _createPacks() async {
    final gallery = _selectedGallery;
    if (gallery == null) return;
    await _run(() async {
      final created = await _service.createRecommendedPacks(
        photographerId: widget.profile.photographerId,
        galleryId: gallery.galleryId,
      );
      if (mounted && created == 0) {
        setState(() {
          _error =
              'Les packs sont déjà créés ou la galerie ne contient pas assez de photos.';
        });
      }
      await widget.onSelectGallery(gallery.galleryId);
    });
  }

  Future<void> _archiveGallery() async {
    final gallery = _selectedGallery;
    if (gallery == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Archiver la galerie ?'),
        content: const Text(
          'Elle disparaîtra de la boutique. Les achats déjà réalisés resteront accessibles.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Archiver'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _run(() async {
      await _service.archiveGallery(
        photographerId: widget.profile.photographerId,
        galleryId: gallery.galleryId,
      );
    });
  }

  Future<void> _deletePhoto(MediaPhotoModel photo) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Supprimer cette photo ?'),
        content: const Text(
          'Une photo déjà achetée sera archivée afin de préserver le téléchargement du client.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _run(() async {
      await _service.deletePhoto(
        photographerId: widget.profile.photographerId,
        photoId: photo.photoId,
      );
      await widget.onSelectGallery(photo.galleryId);
    });
  }

  String _dateLabel(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    return '$day/$month/${value.year}';
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selectedGallery;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _QuotaPanel(
          quota: _quota,
          fallbackPhotos: widget.profile.publishedPhotoCount,
          fallbackStorage: widget.profile.storageUsedBytes,
          loading: _loadingQuota,
          onRefresh: _loadQuota,
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 9,
          runSpacing: 9,
          children: <Widget>[
            FilledButton.icon(
              onPressed: _busy || !_hasCircuitContext ? null : _createGallery,
              icon: const Icon(Icons.create_new_folder_outlined),
              label: const Text('Créer une galerie'),
            ),
            FilledButton.tonalIcon(
              onPressed: _busy || selected == null ? null : _uploadPhotos,
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: const Text('Ajouter des photos'),
            ),
            OutlinedButton.icon(
              onPressed: _busy || selected == null ? null : _publishGallery,
              icon: const Icon(Icons.publish_outlined),
              label: const Text('Publier'),
            ),
            OutlinedButton.icon(
              onPressed: _busy || selected == null ? null : _createPacks,
              icon: const Icon(Icons.sell_outlined),
              label: const Text('Créer les packs'),
            ),
            TextButton.icon(
              onPressed: _busy || selected == null ? null : _archiveGallery,
              icon: const Icon(Icons.archive_outlined),
              label: const Text('Archiver'),
            ),
          ],
        ),
        if (_progress != null) ...<Widget>[
          const SizedBox(height: 12),
          _ProgressPanel(progress: _progress!),
        ],
        if (_error != null) ...<Widget>[
          const SizedBox(height: 12),
          MaterialBanner(
            content: Text(_error!),
            leading: const Icon(Icons.error_outline),
            actions: <Widget>[
              TextButton(
                onPressed: () => setState(() => _error = null),
                child: const Text('Fermer'),
              ),
            ],
          ),
        ],
        const SizedBox(height: 22),
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                'Mes galeries',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
            ),
            Text('${widget.galleries.length}'),
          ],
        ),
        const SizedBox(height: 12),
        if (widget.galleries.isEmpty)
          const _EmptyPanel(
            icon: Icons.photo_library_outlined,
            title: 'Aucune galerie',
            message:
                'Sélectionnez un circuit puis créez votre première galerie.',
          )
        else
          SizedBox(
            height: 180,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: widget.galleries.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final gallery = widget.galleries[index];
                return _GalleryCard(
                  gallery: gallery,
                  selected: gallery.galleryId == widget.selectedGalleryId,
                  onTap: () => widget.onSelectGallery(gallery.galleryId),
                );
              },
            ),
          ),
        if (selected != null) ...<Widget>[
          const SizedBox(height: 24),
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      selected.title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    Text(
                      '${widget.selectedPhotos.length} photo(s) • '
                      '${widget.selectedPacks.length} pack(s)',
                    ),
                  ],
                ),
              ),
              Chip(label: Text(selected.status.label)),
            ],
          ),
          const SizedBox(height: 12),
          if (widget.selectedPhotos.isEmpty)
            const _EmptyPanel(
              icon: Icons.add_photo_alternate_outlined,
              title: 'Galerie vide',
              message:
                  'Ajoutez des photos. MASLIVE créera les miniatures et le filigrane.',
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 960
                    ? 5
                    : constraints.maxWidth >= 700
                        ? 4
                        : constraints.maxWidth >= 480
                            ? 3
                            : 2;
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 0.78,
                  ),
                  itemCount: widget.selectedPhotos.length,
                  itemBuilder: (context, index) {
                    final photo = widget.selectedPhotos[index];
                    return _PhotoTile(
                      photo: photo,
                      disabled: _busy,
                      onDelete: () => _deletePhoto(photo),
                    );
                  },
                );
              },
            ),
          if (widget.selectedPacks.isNotEmpty) ...<Widget>[
            const SizedBox(height: 20),
            Text(
              'Packs actifs',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: widget.selectedPacks
                  .map(
                    (pack) => Chip(
                      avatar: const Icon(Icons.sell_outlined, size: 17),
                      label: Text(
                        '${pack.title} • ${pack.price.toStringAsFixed(2)} ${pack.currency}',
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
          ],
        ],
      ],
    );
  }
}

class _QuotaPanel extends StatelessWidget {
  const _QuotaPanel({
    required this.quota,
    required this.fallbackPhotos,
    required this.fallbackStorage,
    required this.loading,
    required this.onRefresh,
  });

  final PhotographerMediaQuota? quota;
  final int fallbackPhotos;
  final int fallbackStorage;
  final bool loading;
  final VoidCallback onRefresh;

  String _bytes(int value) {
    if (value < 1024 * 1024) return '${(value / 1024).toStringAsFixed(1)} Ko';
    if (value < 1024 * 1024 * 1024) {
      return '${(value / (1024 * 1024)).toStringAsFixed(1)} Mo';
    }
    return '${(value / (1024 * 1024 * 1024)).toStringAsFixed(1)} Go';
  }

  @override
  Widget build(BuildContext context) {
    final current = quota;
    final photos = current?.publishedPhotoCount ?? fallbackPhotos;
    final storage = current?.storageUsedBytes ?? fallbackStorage;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: MasliveTheme.divider),
        boxShadow: MasliveTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.cloud_outlined, color: MasliveTheme.pink),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  current == null
                      ? 'Stockage photographe'
                      : 'Offre ${current.planName}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ),
              IconButton(
                onPressed: loading ? null : onRefresh,
                icon: loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
              ),
            ],
          ),
          if (current != null)
            Text(
              '${current.commissionPercent} % de commission • '
              'conservation ${current.retentionDays} jours',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          const SizedBox(height: 15),
          _UsageLine(
            label: 'Photos publiées',
            value: current == null
                ? '$photos'
                : '$photos / ${current.maxPublishedPhotos}',
            fraction: current?.photoUsageFraction ?? 0,
          ),
          const SizedBox(height: 12),
          _UsageLine(
            label: 'Stockage',
            value: current == null
                ? _bytes(storage)
                : '${_bytes(storage)} / ${_bytes(current.maxStorageBytes)}',
            fraction: current?.storageUsageFraction ?? 0,
          ),
          if (current != null) ...<Widget>[
            const SizedBox(height: 12),
            Text(
              '${current.galleryCapacityRemaining} galerie(s) disponible(s) • '
              '${current.maxBatchUpload} photos/import • '
              '${current.maxMegapixels} Mpx max',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

class _UsageLine extends StatelessWidget {
  const _UsageLine({
    required this.label,
    required this.value,
    required this.fraction,
  });

  final String label;
  final String value;
  final double fraction;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
            Text(value),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: fraction.clamp(0, 1).toDouble(),
            minHeight: 8,
            backgroundColor: MasliveTheme.surfaceAlt,
          ),
        ),
      ],
    );
  }
}

class _ProgressPanel extends StatelessWidget {
  const _ProgressPanel({required this.progress});

  final PhotographerUploadProgress progress;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF8FF),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '${progress.stage} • ${progress.fileName}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 7),
          LinearProgressIndicator(value: progress.fraction),
          const SizedBox(height: 5),
          Text('${progress.completed} / ${progress.total} photo(s)'),
        ],
      ),
    );
  }
}

class _GalleryCard extends StatelessWidget {
  const _GalleryCard({
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
      width: 220,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? MasliveTheme.pink : MasliveTheme.divider,
              width: selected ? 2 : 1,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: gallery.coverUrl?.trim().isNotEmpty == true
                    ? StorageImage(
                        url: gallery.coverUrl!.trim(),
                        width: double.infinity,
                        fit: BoxFit.cover,
                        cacheWidth: 500,
                      )
                    : Container(
                        width: double.infinity,
                        color: MasliveTheme.surfaceAlt,
                        child: const Icon(Icons.photo_library_outlined, size: 40),
                      ),
              ),
              Padding(
                padding: const EdgeInsets.all(11),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      gallery.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    Text(
                      '${gallery.photoCount} photos • ${gallery.status.label}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({
    required this.photo,
    required this.disabled,
    required this.onDelete,
  });

  final MediaPhotoModel photo;
  final bool disabled;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final url = photo.thumbnailPath.trim().isNotEmpty
        ? photo.thumbnailPath
        : photo.previewPath;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MasliveTheme.divider),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                StorageImage(url: url, fit: BoxFit.cover, cacheWidth: 500),
                Positioned(
                  top: 5,
                  right: 5,
                  child: Material(
                    color: Colors.black54,
                    shape: const CircleBorder(),
                    child: IconButton(
                      tooltip: 'Supprimer',
                      onPressed: disabled ? null : onDelete,
                      icon: const Icon(
                        Icons.delete_outline,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
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
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                Text(
                  '${photo.unitPrice.toStringAsFixed(2)} ${photo.currency}',
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

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: MasliveTheme.divider),
      ),
      child: Column(
        children: <Widget>[
          Icon(icon, size: 40, color: MasliveTheme.textSecondary),
          const SizedBox(height: 8),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(message, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
