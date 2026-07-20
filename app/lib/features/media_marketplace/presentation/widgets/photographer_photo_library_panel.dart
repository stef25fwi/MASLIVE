import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../../services/auth_service.dart';
import '../../../../ui/widgets/storage_image.dart';
import '../../data/models/media_gallery_model.dart';
import '../../data/models/media_photo_model.dart';
import '../../data/models/photographer_profile_model.dart';
import '../../data/repositories/photographer_complete_flow_repository.dart';

class PhotographerPhotoLibraryPanel extends StatefulWidget {
  const PhotographerPhotoLibraryPanel({
    super.key,
    required this.profile,
    required this.repository,
  });

  final PhotographerProfileModel profile;
  final PhotographerCompleteFlowRepository repository;

  @override
  State<PhotographerPhotoLibraryPanel> createState() =>
      _PhotographerPhotoLibraryPanelState();
}

class _PhotographerPhotoLibraryPanelState
    extends State<PhotographerPhotoLibraryPanel> {
  final TextEditingController _search = TextEditingController();
  final TextEditingController _bib = TextEditingController();
  final List<MediaPhotoModel> _photos = <MediaPhotoModel>[];
  final Map<String, QueryDocumentSnapshot<Map<String, dynamic>>> _documents =
      <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
  final Set<String> _selected = <String>{};
  List<MediaGalleryModel> _galleries = const <MediaGalleryModel>[];
  String? _galleryId;
  String _status = 'all';
  DateTimeRange? _range;
  DocumentSnapshot<Map<String, dynamic>>? _cursor;
  bool _hasMore = true;
  bool _loading = true;
  bool _working = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _initialLoad();
  }

  @override
  void dispose() {
    _search.dispose();
    _bib.dispose();
    super.dispose();
  }

  Future<void> _initialLoad() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _galleries = await widget.repository.loadGalleries(
        widget.profile.photographerId,
      );
      await _load(reset: true);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _load({required bool reset}) async {
    if (_working || (!reset && !_hasMore)) return;
    setState(() => _working = true);
    try {
      if (reset) {
        _photos.clear();
        _documents.clear();
        _selected.clear();
        _cursor = null;
        _hasMore = true;
      }
      final page = await widget.repository.loadPhotoPage(
        photographerId: widget.profile.photographerId,
        galleryId: _galleryId,
        status: _status,
        queryText: _search.text,
        bibNumber: _bib.text,
        from: _range?.start,
        to: _range == null
            ? null
            : DateTime(
                _range!.end.year,
                _range!.end.month,
                _range!.end.day,
                23,
                59,
                59,
              ),
        cursor: _cursor,
      );
      for (var index = 0; index < page.photos.length; index++) {
        final photo = page.photos[index];
        if (!_documents.containsKey(photo.photoId)) {
          _photos.add(photo);
          _documents[photo.photoId] = page.documents[index];
        }
      }
      _cursor = page.cursor;
      _hasMore = page.hasMore;
      _error = null;
    } catch (error) {
      _error = error;
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _pickRange() async {
    final value = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: _range,
    );
    if (value != null) {
      setState(() => _range = value);
      await _load(reset: true);
    }
  }

  Future<double?> _askPrice({double? initial}) async {
    final controller = TextEditingController(
      text: (initial ?? 6.90).toStringAsFixed(2),
    );
    final value = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Prix des photos sélectionnées'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(suffixText: '€'),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              context,
              double.tryParse(controller.text.replaceAll(',', '.')),
            ),
            child: const Text('Appliquer'),
          ),
        ],
      ),
    );
    controller.dispose();
    return value;
  }

  Future<List<String>?> _askTags() async {
    final controller = TextEditingController();
    final value = await showDialog<List<String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ajouter des tags'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'costume rouge, groupe A, scène, dossard:142',
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              context,
              controller.text
                  .split(RegExp(r'[,;\n]+'))
                  .map((value) => value.trim())
                  .where((value) => value.isNotEmpty)
                  .toList(growable: false),
            ),
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );
    controller.dispose();
    return value;
  }

  Future<String?> _askGallery() async {
    var value = _galleryId ?? (_galleries.isEmpty ? null : _galleries.first.galleryId);
    return showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: const Text('Déplacer vers une galerie'),
          content: DropdownButtonFormField<String>(
            initialValue: value,
            items: _galleries
                .map(
                  (gallery) => DropdownMenuItem<String>(
                    value: gallery.galleryId,
                    child: Text(gallery.title),
                  ),
                )
                .toList(growable: false),
            onChanged: (next) => update(() => value = next),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: value == null ? null : () => Navigator.pop(context, value),
              child: const Text('Déplacer'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _bulk({
    double? price,
    String? galleryId,
    bool? published,
    List<String>? tags,
  }) async {
    if (_selected.isEmpty) return;
    setState(() => _working = true);
    try {
      await widget.repository.bulkUpdatePhotos(
        photoIds: _selected,
        actorUid: AuthService.instance.currentUser?.uid ?? '',
        unitPrice: price,
        galleryId: galleryId,
        published: published,
        addTags: tags,
      );
      await _load(reset: true);
      _message('${_selected.length} photo(s) mises à jour.');
    } catch (error) {
      _message(error.toString(), error: true);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _deleteSelected() async {
    if (_selected.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer les photos ?'),
        content: const Text(
          'La suppression sera refusée si au moins une photo a été achetée.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _working = true);
    try {
      final firestore = FirebaseFirestore.instance;
      final ids = _selected.toList(growable: false);
      for (var offset = 0; offset < ids.length; offset += 10) {
        final chunk = ids.skip(offset).take(10).toList(growable: false);
        final entitlements = await firestore
            .collection('media_entitlements')
            .where('photoIds', arrayContainsAny: chunk)
            .limit(1)
            .get();
        if (entitlements.docs.isNotEmpty) {
          throw StateError('Une photo achetée ne peut pas être supprimée. Archive-la.');
        }
      }
      final batch = firestore.batch();
      for (final id in ids) {
        batch.delete(firestore.collection('media_photos').doc(id));
      }
      await batch.commit();
      await _load(reset: true);
      _message('${ids.length} photo(s) supprimée(s).');
    } catch (error) {
      _message(error.toString(), error: true);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _edit(MediaPhotoModel photo) async {
    final document = _documents[photo.photoId];
    if (document == null) return;
    final data = document.data();
    final tags = TextEditingController(
      text: (data['tags'] as Iterable? ?? const <dynamic>[]).join(', '),
    );
    final faces = TextEditingController(
      text: (data['faceTags'] as Iterable? ?? const <dynamic>[]).join(', '),
    );
    final bibs = TextEditingController(
      text: (data['bibNumbers'] as Iterable? ??
              <dynamic>[if (photo.bibNumber != null) photo.bibNumber])
          .join(', '),
    );
    final colors = TextEditingController(
      text: (data['colorTags'] as Iterable? ?? const <dynamic>[]).join(', '),
    );
    final price = TextEditingController(text: photo.unitPrice.toStringAsFixed(2));
    var galleryId = photo.galleryId;
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: const Text('Métadonnées de la photo'),
          content: SizedBox(
            width: 620,
            child: SingleChildScrollView(
              child: Column(
                children: <Widget>[
                  DropdownButtonFormField<String>(
                    initialValue: galleryId,
                    decoration: const InputDecoration(labelText: 'Galerie'),
                    items: _galleries
                        .map(
                          (gallery) => DropdownMenuItem<String>(
                            value: gallery.galleryId,
                            child: Text(gallery.title),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: (value) => update(() => galleryId = value ?? galleryId),
                  ),
                  TextField(
                    controller: price,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Prix', suffixText: '€'),
                  ),
                  TextField(controller: tags, maxLines: 2, decoration: const InputDecoration(labelText: 'Tags')),
                  TextField(controller: bibs, maxLines: 2, decoration: const InputDecoration(labelText: 'Dossards détectés')),
                  TextField(controller: colors, maxLines: 2, decoration: const InputDecoration(labelText: 'Couleurs de tenue')),
                  TextField(
                    controller: faces,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Groupes visage anonymes',
                      helperText: 'Identifiants techniques sans nom ni identité civile.',
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
    if (saved == true) {
      setState(() => _working = true);
      try {
        await widget.repository.updatePhotoMetadata(
          photoId: photo.photoId,
          actorUid: AuthService.instance.currentUser?.uid ?? '',
          galleryId: galleryId,
          unitPrice: double.tryParse(price.text.replaceAll(',', '.')),
          tags: _split(tags.text),
          faceTags: _split(faces.text),
          bibNumbers: _split(bibs.text),
          colorTags: _split(colors.text),
        );
        await _load(reset: true);
      } catch (error) {
        _message(error.toString(), error: true);
      } finally {
        if (mounted) setState(() => _working = false);
      }
    }
    for (final controller in <TextEditingController>[tags, faces, bibs, colors, price]) {
      controller.dispose();
    }
  }

  Future<void> _history(MediaPhotoModel photo) async {
    final history = _documents[photo.photoId]?.data()['history'];
    final rows = history is Iterable
        ? history.whereType<Map>().map((value) => Map<String, dynamic>.from(value)).toList(growable: false)
        : const <Map<String, dynamic>>[];
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Historique des modifications'),
        content: SizedBox(
          width: 520,
          child: rows.isEmpty
              ? const Text('Aucune modification manuelle enregistrée.')
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: rows.length,
                  itemBuilder: (context, index) {
                    final row = rows[rows.length - index - 1];
                    final at = row['at'];
                    return ListTile(
                      leading: const Icon(Icons.history_rounded),
                      title: Text(row['action']?.toString() ?? 'modification'),
                      subtitle: Text(
                        '${row['actorUid'] ?? ''}${at is Timestamp ? ' • ${at.toDate().toLocal()}' : ''}',
                      ),
                    );
                  },
                ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  List<String> _split(String value) => value
      .split(RegExp(r'[,;\n]+'))
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toSet()
      .toList(growable: false);

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
    if (_loading) return const Center(child: CircularProgressIndicator());
    return RefreshIndicator(
      onRefresh: () => _load(reset: true),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              SizedBox(
                width: 280,
                child: TextField(
                  controller: _search,
                  decoration: const InputDecoration(
                    labelText: 'Recherche',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onSubmitted: (_) => _load(reset: true),
                ),
              ),
              SizedBox(
                width: 180,
                child: TextField(
                  controller: _bib,
                  decoration: const InputDecoration(labelText: 'Dossard'),
                  onSubmitted: (_) => _load(reset: true),
                ),
              ),
              SizedBox(
                width: 260,
                child: DropdownButtonFormField<String?>(
                  initialValue: _galleryId,
                  decoration: const InputDecoration(labelText: 'Galerie'),
                  items: <DropdownMenuItem<String?>>[
                    const DropdownMenuItem<String?>(value: null, child: Text('Toutes les galeries')),
                    ..._galleries.map(
                      (gallery) => DropdownMenuItem<String?>(
                        value: gallery.galleryId,
                        child: Text(gallery.title),
                      ),
                    ),
                  ],
                  onChanged: (value) async {
                    setState(() => _galleryId = value);
                    await _load(reset: true);
                  },
                ),
              ),
              SizedBox(
                width: 210,
                child: DropdownButtonFormField<String>(
                  initialValue: _status,
                  decoration: const InputDecoration(labelText: 'Statut'),
                  items: const <DropdownMenuItem<String>>[
                    DropdownMenuItem(value: 'all', child: Text('Tous')),
                    DropdownMenuItem(value: 'pending', child: Text('En attente')),
                    DropdownMenuItem(value: 'draft', child: Text('Brouillons')),
                    DropdownMenuItem(value: 'published', child: Text('Publiées')),
                    DropdownMenuItem(value: 'archived', child: Text('Archivées')),
                  ],
                  onChanged: (value) async {
                    setState(() => _status = value ?? 'all');
                    await _load(reset: true);
                  },
                ),
              ),
              OutlinedButton.icon(
                onPressed: _pickRange,
                icon: const Icon(Icons.date_range_outlined),
                label: Text(_range == null ? 'Période' : '${_range!.start.day}/${_range!.start.month} → ${_range!.end.day}/${_range!.end.month}'),
              ),
              FilledButton.icon(
                onPressed: _working ? null : () => _load(reset: true),
                icon: const Icon(Icons.filter_alt_outlined),
                label: const Text('Appliquer'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              OutlinedButton.icon(
                onPressed: _photos.isEmpty
                    ? null
                    : () => setState(() {
                          if (_selected.length == _photos.length) {
                            _selected.clear();
                          } else {
                            _selected
                              ..clear()
                              ..addAll(_photos.map((photo) => photo.photoId));
                          }
                        }),
                icon: const Icon(Icons.select_all),
                label: Text(
                  _selected.length == _photos.length && _photos.isNotEmpty
                      ? 'Tout désélectionner'
                      : 'Sélectionner la page',
                ),
              ),
              FilledButton.tonalIcon(
                onPressed: _selected.isEmpty || _working
                    ? null
                    : () async {
                        final price = await _askPrice();
                        if (price != null) await _bulk(price: price);
                      },
                icon: const Icon(Icons.euro),
                label: const Text('Prix groupé'),
              ),
              FilledButton.tonalIcon(
                onPressed: _selected.isEmpty || _working
                    ? null
                    : () async {
                        final gallery = await _askGallery();
                        if (gallery != null) await _bulk(galleryId: gallery);
                      },
                icon: const Icon(Icons.drive_file_move_outline),
                label: const Text('Déplacer'),
              ),
              FilledButton.tonalIcon(
                onPressed: _selected.isEmpty || _working
                    ? null
                    : () async {
                        final tags = await _askTags();
                        if (tags?.isNotEmpty == true) await _bulk(tags: tags);
                      },
                icon: const Icon(Icons.sell_outlined),
                label: const Text('Ajouter des tags'),
              ),
              OutlinedButton.icon(
                onPressed: _selected.isEmpty || _working ? null : () => _bulk(published: true),
                icon: const Icon(Icons.publish_outlined),
                label: const Text('Publier'),
              ),
              OutlinedButton.icon(
                onPressed: _selected.isEmpty || _working ? null : () => _bulk(published: false),
                icon: const Icon(Icons.archive_outlined),
                label: const Text('Archiver'),
              ),
              OutlinedButton.icon(
                onPressed: _selected.isEmpty || _working ? null : _deleteSelected,
                icon: const Icon(Icons.delete_outline),
                label: const Text('Supprimer'),
              ),
              Chip(label: Text('${_selected.length} sélectionnée(s)')),
            ],
          ),
          if (_error != null) ...<Widget>[
            const SizedBox(height: 12),
            Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(_error.toString()),
              ),
            ),
          ],
          const SizedBox(height: 16),
          if (_photos.isEmpty && !_working)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('Aucune photo ne correspond aux filtres.'),
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 1200
                    ? 6
                    : constraints.maxWidth >= 900
                        ? 5
                        : constraints.maxWidth >= 680
                            ? 4
                            : constraints.maxWidth >= 460
                                ? 3
                                : 2;
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: .72,
                  ),
                  itemCount: _photos.length,
                  itemBuilder: (context, index) {
                    final photo = _photos[index];
                    final selected = _selected.contains(photo.photoId);
                    final raw = _documents[photo.photoId]?.data() ?? const <String, dynamic>{};
                    final bibs = (raw['bibNumbers'] as Iterable? ?? const <dynamic>[]).join(', ');
                    return Card(
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => setState(() {
                          selected ? _selected.remove(photo.photoId) : _selected.add(photo.photoId);
                        }),
                        child: Column(
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
                                  Positioned(
                                    top: 4,
                                    right: 4,
                                    child: Checkbox(
                                      value: selected,
                                      onChanged: (_) => setState(() {
                                        selected ? _selected.remove(photo.photoId) : _selected.add(photo.photoId);
                                      }),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(8, 6, 4, 4),
                              child: Row(
                                children: <Widget>[
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: <Widget>[
                                        Text(
                                          '${photo.unitPrice.toStringAsFixed(2)} € • ${photo.lifecycleStatus.name}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontWeight: FontWeight.w800),
                                        ),
                                        Text(
                                          bibs.isEmpty ? photo.moderationStatus.name : 'Dossard $bibs',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: Theme.of(context).textTheme.bodySmall,
                                        ),
                                      ],
                                    ),
                                  ),
                                  PopupMenuButton<String>(
                                    onSelected: (value) {
                                      if (value == 'edit') _edit(photo);
                                      if (value == 'history') _history(photo);
                                    },
                                    itemBuilder: (context) => const <PopupMenuEntry<String>>[
                                      PopupMenuItem(value: 'edit', child: Text('Modifier')),
                                      PopupMenuItem(value: 'history', child: Text('Historique')),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          if (_hasMore)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: OutlinedButton.icon(
                onPressed: _working ? null : () => _load(reset: false),
                icon: _working
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.expand_more),
                label: const Text('Charger plus de photos'),
              ),
            ),
        ],
      ),
    );
  }
}
