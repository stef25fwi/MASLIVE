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
  PhotographerUploadProgress? _uploadProgress;
  bool _loadingQuota = false;
  bool _actionInProgress = false;
  String? _error;

  MediaGalleryModel? get _selectedGallery {
    final selectedId = widget.selectedGalleryId;
    if (selectedId == null || selectedId.isEmpty) return null;
    for (final gallery in widget.galleries) {
      if (gallery.galleryId == selectedId) return gallery;
    }
    return null;
  }

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
    setState(() {
      _loadingQuota = true;
      _error = null;
    });
    try {
      final quota = await _service.getQuota(widget.profile.photographerId);
      if (!mounted) return;
      setState(() => _quota = quota);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = _friendlyError(error));
    } finally {
      if (mounted) setState(() => _loadingQuota = false);
    }
  }

  Future<void> _runAction(Future<void> Function() action) async {
    if (_actionInProgress) return;
    setState(() {
      _actionInProgress = true;
      _error = null;
    });
    try {
      await action();
      await widget.onRefresh();
      await _loadQuota();
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = _friendlyError(error));
    } finally {
      if (mounted) {
        setState(() {
          _actionInProgress = false;
          _uploadProgress = null;
        });
      }
    }
  }

  String _friendlyError(Object error) {
    final message = error.toString().replaceFirst('Exception: ', '');
    if (message.contains('resource-exhausted')) {
      return 'Le quota de votre abonnement est atteint. Archivez des médias ou changez d’offre.';
    }
    if (message.contains('failed-precondition')) {
      return 'Cette action n’est pas encore possible. Vérifiez la galerie, la validation du profil et les photos.';
    }
    if (message.contains('permission-denied')) {
      return 'Vous n’avez pas l’autorisation de modifier cette galerie.';
    }
    return message;
  }

  bool get _hasCompleteCircuitContext =>
      widget.countryId?.trim().isNotEmpty == true &&
      widget.eventId?.trim().isNotEmpty == true &&
      widget.circuitId?.trim().isNotEmpty == true;

  Future<void> _createGallery() async {
    if (!_hasCompleteCircuitContext) {
      setState(() {
        _error =
            'Sélectionnez d’abord un pays, un événement et un circuit dans la boutique photo.';
      });
      return;
    }

    final titleController = TextEditingController(
      text: widget.circuitName?.trim().isNotEmpty == true
          ? '${widget.circuitName} • ${_formattedDate(DateTime.now())}'
          : 'Nouvelle galerie • ${_formattedDate(DateTime.now())}',
    );
    final descriptionController = TextEditingController();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Créer une galerie'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              TextField(
                controller: titleController,
                autofocus: true,
                maxLength: 120,
                decoration: const InputDecoration(
                  labelText: 'Nom de la galerie',
                  hintText: 'Sortie du samedi matin',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: descriptionController,
                minLines: 2,
                maxLines: 4,
                maxLength: 1000,
                decoration: const InputDecoration(
                  labelText: 'Description facultative',
                ),
              ),
              const SizedBox(height: 8),
              _ContextSummary(
                country: widget.countryName ?? widget.countryId!,
                event: widget.eventName ?? widget.eventId!,
                circuit: widget.circuitName ?? widget.circuitId!,
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

    String? createdGalleryId;
    await _runAction(() async {
      createdGalleryId = await _service.createGallery(
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
    if (createdGalleryId?.isNotEmpty == true && mounted) {
      await widget.onSelectGallery(createdGalleryId!);
    }
  }

  Future<void> _uploadPhotos() async {
    final gallery = _selectedGallery;
    if (gallery == null) {
      setState(() => _error = 'Sélectionnez une galerie avant l’import.');
      return;
    }
    final quota = _quota;
    if (quota == null) {
      await _loadQuota();
      if (!mounted) return;
    }
    final resolvedQuota = _quota;
    if (resolvedQuota == null) return;

    final maxCount = math.min(
      resolvedQuota.maxBatchUpload,
      resolvedQuota.photoCapacityRemaining,
    );
    if (maxCount <= 0) {
      setState(() => _error = 'Votre quota photo est atteint.');
      return;
    }

    final files = await _service.selectPhotos(maxCount: maxCount);
    if (files.isEmpty || !mounted) return;

    await _runAction(() async {
      await _service.uploadPhotos(
        photographerId: widget.profile.photographerId,
        galleryId: gallery.galleryId,
        files: files,
        unitPrice: 6.90,
        onProgress: (progress) {
          if (mounted) setState(() => _uploadProgress = progress);
        },
      );
      await widget.onSelectGallery(gallery.galleryId);
    });
  }

  Future<void> _publishGallery() async {
    final gallery = _selectedGallery;
    if (gallery == null) return;
    await _runAction(() async {
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
    await _runAction(() async {
      final created = await _service.createRecommendedPacks(
        photographerId: widget.profile.photographerId,
        galleryId: gallery.galleryId,
      );
      if (mounted && created == 0) {
        setState(() {
          _error =
              'Les packs disponibles sont déjà créés ou la galerie ne contient pas assez de photos.';
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
          'Les photos disparaîtront de la boutique. Les achats déjà réalisés resteront téléchargeables.',
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
    await _runAction(() async {
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
          'Une photo déjà achetée sera seulement archivée afin de préserver le téléchargement du client.',
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
    final galleryId = photo.galleryId;
    await _runAction(() async {
      await _service.deletePhoto(
        photographerId: widget.profile.photographerId,
        photoId: photo.photoId,
      );
      await widget.onSelectGallery(galleryId);
    });
  }

  String _formattedDate(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    return '$day/$month/${value.year}';
  }

  @override
  Widget build(BuildContext context) {
    final quota = _quota;
    final gallery = _selectedGallery;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _QuotaCard(
          quota: quota,
          loading: _loadingQuota,
          fallbackPhotoCount: widget.profile.publishedPhotoCount,
          fallbackStorageBytes: widget.profile.storageUsedBytes,
          onRefresh: _loadQuota,
        ),
        const SizedBox(height: 16),
        _ActionBar(
          disabled: _actionInProgress,
          canCreateGallery: _hasCompleteCircuitContext,
          hasSelectedGallery: gallery != null,
          onCreateGallery: _createGallery,
          onUploadPhotos: _uploadPhotos,
          onPublish: _publishGallery,
          onCreatePacks: _createPacks,
          onArchive: _archiveGallery,
        ),
        if (_uploadProgress != null) ...<Widget>[
          const SizedBox(height: 12),
          _UploadProgressCard(progress: _uploadProgress!),
        ],
        if (_error != null) ...<Widget>[
          const SizedBox(height: 12),
          _ErrorBanner(
            message: _error!,
            onClose: () => setState(() => _error = null),
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
                'Choisissez un circuit puis créez votre première galerie photo.',
          )
        else
          SizedBox(
            height: 190,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: widget.galleries.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final item = widget.galleries[index];
                return _GalleryThumbnailCard(
                  gallery: item,
                  selected: item.galleryId == widget.selectedGalleryId,
                  onTap: () => widget.onSelectGallery(item.galleryId),
                );
              },
            ),
          ),
        if (gallery != null) ...<Widget>[
          const SizedBox(height: 24),
          _SelectedGalleryHeader(
            gallery: gallery,
            photoCount: widget.selectedPhotos.length,
            packCount: widget.selectedPacks.length,
          ),
          const SizedBox(height: 14),
          if (widget.selectedPhotos.isEmpty)
            const _EmptyPanel(
              icon: Icons.add_photo_alternate_outlined,
              title: 'Galerie vide',
              message:
                  'Ajoutez des photos. Les miniatures et le filigrane seront générés automatiquement.',
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 1000
                    ? 5
                    : constraints.maxWidth >= 720
                        ? 4
                        : constraints.maxWidth >= 480
                            ? 3
                            : 2;
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.78,
                  ),
                  itemCount: widget.selectedPhotos.length,
                  itemBuilder: (context, index) {
                    final photo = widget.selectedPhotos[index];
                    return _ManagedPhotoTile(
                      photo: photo,
                      disabled: _actionInProgress,
                      onDelete: () => _deletePhoto(photo),
                    );
                  },
                );
              },
            ),
          if (widget.selectedPacks.isNotEmpty) ...<Widget>[
            const SizedBox(height: 22),
            Text(
              'Packs actifs',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: widget.selectedPacks
                  .map((pack) => _PackChip(pack: pack))
                  .toList(growable: false),
            ),
          ],
        ],
      ],
    );
  }
}

class _QuotaCard extends StatelessWidget {
  const _QuotaCard({
    required this.quota,
    required this.loading,
    required this.fallbackPhotoCount,
    required this.fallbackStorageBytes,
    required this.onRefresh,
  });

  final PhotographerMediaQuota? quota;
  final bool loading;
  final int fallbackPhotoCount;
  final int fallbackStorageBytes;
  final VoidCallback onRefresh;

  String _formatBytes(int bytes) {
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} Ko';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} Mo';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} Go';
  }

  @override
  Widget build(BuildContext context) {
    final resolved = quota;
    final photoCount = resolved?.publishedPhotoCount ?? fallbackPhotoCount;
    final storageBytes = resolved?.storageUsedBytes ?? fallbackStorageBytes;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: MasliveTheme.border),
        boxShadow: MasliveTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: MasliveTheme.pink.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.cloud_outlined, color: MasliveTheme.pink),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      resolved == null
                          ? 'Stockage photographe'
                          : 'Offre ${resolved.planName}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    if (resolved != null)
                      Text(
                        '${resolved.commissionPercent} % de commission • conservation ${resolved.retentionDays} jours',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
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
          const SizedBox(height: 18),
          _QuotaLine(
            label: 'Photos publiées',
            value: resolved == null
                ? '$photoCount'
                : '$photoCount / ${resolved.maxPublishedPhotos}',
            fraction: resolved?.photoUsageFraction ?? 0,
          ),
          const SizedBox(height: 14),
          _QuotaLine(
            label: 'Stockage',
            value: resolved == null
                ? _formatBytes(storageBytes)
                : '${_formatBytes(storageBytes)} / ${_formatBytes(resolved.maxStorageBytes)}',
            fraction: resolved?.storageUsageFraction ?? 0,
          ),
          if (resolved != null) ...<Widget>[
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                _InfoPill(
                  icon: Icons.photo_library_outlined,
                  label:
                      '${resolved.galleryCapacityRemaining} galerie(s) disponible(s)',
                ),
                _InfoPill(
                  icon: Icons.upload_file_outlined,
                  label: '${resolved.maxBatchUpload} photos/import',
                ),
                _InfoPill(
                  icon: Icons.high_quality_outlined,
                  label: '${resolved.maxMegapixels} Mpx max',
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _QuotaLine extends StatelessWidget {
  const _QuotaLine({
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
        const SizedBox(height: 7),
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

class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.disabled,
    required this.canCreateGallery,
    required this.hasSelectedGallery,
    required this.onCreateGallery,
    required this.onUploadPhotos,
    required this.onPublish,
    required this.onCreatePacks,
    required this.onArchive,
  });

  final bool disabled;
  final bool canCreateGallery;
  final bool hasSelectedGallery;
  final VoidCallback onCreateGallery;
  final VoidCallback onUploadPhotos;
  final VoidCallback onPublish;
  final VoidCallback onCreatePacks;
  final VoidCallback onArchive;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: <Widget>[
        FilledButton.icon(
          onPressed: disabled || !canCreateGallery ? null : onCreateGallery,
          icon: const Icon(Icons.create_new_folder_outlined),
          label: const Text('Créer une galerie'),
        ),
        FilledButton.tonalIcon(
          onPressed: disabled || !hasSelectedGallery ? null : onUploadPhotos,
          icon: const Icon(Icons.add_photo_alternate_outlined),
          label: const Text('Ajouter des photos'),
        ),
        OutlinedButton.icon(
          onPressed: disabled || !hasSelectedGallery ? null : onPublish,
          icon: const Icon(Icons.publish_outlined),
          label: const Text('Publier'),
        ),
        OutlinedButton.icon(
          onPressed: disabled || !hasSelectedGallery ? null : onCreatePacks,
          icon: const Icon(Icons.sell_outlined),
          label: const Text('Créer les packs'),
        ),
        TextButton.icon(
          onPressed: disabled || !hasSelectedGallery ? null : onArchive,
          icon: const Icon(Icons.archive_outlined),
          label: const Text('Archiver'),
        ),
      ],
    );
  }
}

class _UploadProgressCard extends StatelessWidget {
  const _UploadProgressCard({required this.progress});

  final PhotographerUploadProgress progress;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF8FF),
        borderRadius: BorderRadius.circular(18),
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
          const SizedBox(height: 8),
          LinearProgressIndicator(value: progress.fraction),
          const SizedBox(height: 6),
          Text('${progress.completed} / ${progress.total} photo(s)'),
        ],
      ),
    );
  }
}

class _GalleryThumbnailCard extends StatelessWidget {
  const _GalleryThumbnailCard({
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
      width: 230,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: selected ? MasliveTheme.pink : MasliveTheme.border,
              width: selected ? 2 : 1,
            ),
            boxShadow: MasliveTheme.cardShadow,
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    if (gallery.coverUrl?.trim().isNotEmpty == true)
                      StorageImage(
                        url: gallery.coverUrl!.trim(),
                        fit: BoxFit.cover,
                        cacheWidth: 600,
                      )
                    else
                      Container(
                        color: MasliveTheme.surfaceAlt,
                        child: const Icon(Icons.photo_library_outlined, size: 42),
                      ),
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.62),
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(
                          gallery.status.label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      gallery.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${gallery.photoCount} photos • ${gallery.packCount} packs',
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                gallery.title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 4),
              Text('$photoCount photo(s) • $packCount pack(s)'),
            ],
          ),
        ),
        _InfoPill(
          icon: gallery.status == GalleryStatus.published
              ? Icons.public
              : Icons.edit_outlined,
          label: gallery.status.label,
        ),
      ],
    );
  }
}

class _ManagedPhotoTile extends StatelessWidget {
  const _ManagedPhotoTile({
    required this.photo,
    required this.disabled,
    required this.onDelete,
  });

  final MediaPhotoModel photo;
  final bool disabled;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final imageUrl = photo.thumbnailPath.trim().isNotEmpty
        ? photo.thumbnailPath.trim()
        : photo.previewPath.trim();
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: MasliveTheme.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                StorageImage(
                  url: imageUrl,
                  fit: BoxFit.cover,
                  cacheWidth: 500,
                ),
                Positioned(
                  top: 7,
                  right: 7,
                  child: Material(
                    color: Colors.black.withValues(alpha: 0.58),
                    shape: const CircleBorder(),
                    child: IconButton(
                      tooltip: 'Supprimer',
                      onPressed: disabled ? null : onDelete,
                      icon: const Icon(
                        Icons.delete_outline,
                        color: Colors.white,
                        size: 19,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 9, 10, 11),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  photo.downloadFileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 3),
                Text(
                  '${photo.unitPrice.toStringAsFixed(2)} ${photo.currency} • ${photo.lifecycleStatus.name}',
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

class _PackChip extends StatelessWidget {
  const _PackChip({required this.pack});

  final MediaPackModel pack;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: pack.sortOrder == 30
            ? MasliveTheme.pink.withValues(alpha: 0.12)
            : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: pack.sortOrder == 30
              ? MasliveTheme.pink.withValues(alpha: 0.40)
              : MasliveTheme.border,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(Icons.sell_outlined, size: 18),
          const SizedBox(width: 8),
          Text(
            '${pack.title} • ${pack.price.toStringAsFixed(2)} ${pack.currency}',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _ContextSummary extends StatelessWidget {
  const _ContextSummary({
    required this.country,
    required this.event,
    required this.circuit,
  });

  final String country;
  final String event;
  final String circuit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: MasliveTheme.surfaceAlt,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Pays : $country'),
          Text('Événement : $event'),
          Text('Circuit : $circuit'),
        ],
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: MasliveTheme.surfaceAlt,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 16),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onClose});

  final String message;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFDA4AF)),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.error_outline, color: Color(0xFFBE123C)),
          const SizedBox(width: 10),
          Expanded(child: Text(message)),
          IconButton(onPressed: onClose, icon: const Icon(Icons.close)),
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
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MasliveTheme.border),
      ),
      child: Column(
        children: <Widget>[
          Icon(icon, size: 42, color: MasliveTheme.textSecondary),
          const SizedBox(height: 10),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 5),
          Text(message, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
