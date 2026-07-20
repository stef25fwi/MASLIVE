import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/models/media_gallery_model.dart';
import '../../data/models/photographer_profile_model.dart';
import '../../data/repositories/photographer_complete_flow_repository.dart';
import '../pages/photographer_gallery_manager_page.dart';

class PhotographerGalleryStudioPanel extends StatefulWidget {
  const PhotographerGalleryStudioPanel({
    super.key,
    required this.profile,
    required this.repository,
  });

  final PhotographerProfileModel profile;
  final PhotographerCompleteFlowRepository repository;

  @override
  State<PhotographerGalleryStudioPanel> createState() =>
      _PhotographerGalleryStudioPanelState();
}

class _PhotographerGalleryStudioPanelState
    extends State<PhotographerGalleryStudioPanel> {
  List<MediaGalleryModel> _galleries = const <MediaGalleryModel>[];
  String? _selectedId;
  bool _loading = true;
  bool _working = false;
  Object? _error;

  MediaGalleryModel? get _selected {
    for (final gallery in _galleries) {
      if (gallery.galleryId == _selectedId) return gallery;
    }
    return _galleries.isEmpty ? null : _galleries.first;
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
      final galleries = await widget.repository.loadGalleries(
        widget.profile.photographerId,
      );
      if (!mounted) return;
      setState(() {
        _galleries = galleries;
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

  Future<void> _openCreator() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const PhotographerGalleryManagerPage(),
      ),
    );
    await _reload();
  }

  Future<void> _editGallery(MediaGalleryModel gallery) async {
    final firestore = FirebaseFirestore.instance;
    final gallerySnapshot =
        await firestore.collection('media_galleries').doc(gallery.galleryId).get();
    final data = gallerySnapshot.data() ?? const <String, dynamic>{};
    final packSnapshot = await firestore
        .collection('media_packs')
        .where('galleryId', isEqualTo: gallery.galleryId)
        .orderBy('sortOrder')
        .get();

    final title = TextEditingController(text: gallery.title);
    final description = TextEditingController(text: gallery.description ?? '');
    final startTime = TextEditingController(
      text: data['shootStartTime']?.toString() ?? '',
    );
    final endTime = TextEditingController(
      text: data['shootEndTime']?.toString() ?? '',
    );
    final startPoint = TextEditingController(
      text: data['startPoint']?.toString() ?? '',
    );
    final endPoint = TextEditingController(
      text: data['endPoint']?.toString() ?? '',
    );
    final participants = TextEditingController(
      text: (data['participantAllowList'] as Iterable? ?? const <dynamic>[])
          .join(', '),
    );
    final watermarkText = TextEditingController(
      text: data['watermarkText']?.toString() ?? widget.profile.brandName,
    );
    final maxMegapixels = TextEditingController(
      text: ((data['maxDownloadMegapixels'] as num?)?.toInt() ?? 24).toString(),
    );
    final downloadHours = TextEditingController(
      text: ((data['downloadWindowHours'] as num?)?.toInt() ?? 72).toString(),
    );
    final brandId = TextEditingController(text: data['brandId']?.toString() ?? '');
    final priceControllers = <String, TextEditingController>{};
    for (final doc in packSnapshot.docs) {
      final pack = doc.data();
      priceControllers[doc.id] = TextEditingController(
        text: ((pack['price'] as num?)?.toDouble() ?? 0).toStringAsFixed(2),
      );
    }

    var visibility = data['plannedVisibility']?.toString() ??
        data['visibility']?.toString() ??
        gallery.visibility.name;
    if (!const <String>['public', 'private', 'unlisted'].contains(visibility)) {
      visibility = 'private';
    }
    var watermarkEnabled = data['watermarkEnabled'] as bool? ?? true;
    var faceGroupingEnabled = data['faceGroupingEnabled'] as bool? ?? false;
    var participantRestricted =
        data['participantRestricted'] as bool? ?? false;
    var shopLayout = data['shopLayout']?.toString() ?? 'grid';
    var eventDate = data['eventDate'] is Timestamp
        ? (data['eventDate'] as Timestamp).toDate()
        : DateTime.now();

    if (!mounted) return;
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: const Text('Éditer la galerie'),
          content: SizedBox(
            width: 760,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  TextField(
                    controller: title,
                    decoration: const InputDecoration(labelText: 'Nom de la galerie'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: description,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'Description'),
                  ),
                  const SizedBox(height: 10),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Date de prise de vue'),
                    subtitle: Text(
                      '${eventDate.day.toString().padLeft(2, '0')}/${eventDate.month.toString().padLeft(2, '0')}/${eventDate.year}',
                    ),
                    trailing: const Icon(Icons.calendar_month_outlined),
                    onTap: () async {
                      final value = await showDatePicker(
                        context: context,
                        initialDate: eventDate,
                        firstDate: DateTime.now().subtract(const Duration(days: 730)),
                        lastDate: DateTime.now().add(const Duration(days: 1095)),
                      );
                      if (value != null) update(() => eventDate = value);
                    },
                  ),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: <Widget>[
                      _field(startTime, 'Heure de début', width: 180, hint: '08:30'),
                      _field(endTime, 'Heure de fin', width: 180, hint: '14:00'),
                      _field(startPoint, 'Point de départ', width: 300),
                      _field(endPoint, 'Point d’arrivée', width: 300),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: visibility,
                    decoration: const InputDecoration(labelText: 'Visibilité'),
                    items: const <DropdownMenuItem<String>>[
                      DropdownMenuItem(value: 'public', child: Text('Publique')),
                      DropdownMenuItem(value: 'unlisted', child: Text('Lien privé')),
                      DropdownMenuItem(value: 'private', child: Text('Privée')),
                    ],
                    onChanged: (value) => update(() => visibility = value ?? 'private'),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: participantRestricted,
                    title: const Text('Réserver aux participants autorisés'),
                    subtitle: const Text('Les e-mails ou identifiants sont contrôlés avant accès.'),
                    onChanged: (value) => update(() => participantRestricted = value),
                  ),
                  if (participantRestricted)
                    TextField(
                      controller: participants,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Participants autorisés',
                        hintText: 'email1@exemple.fr, dossard:142, groupe:nom',
                      ),
                    ),
                  const Divider(height: 28),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: watermarkEnabled,
                    title: const Text('Filigrane sur les aperçus'),
                    onChanged: (value) => update(() => watermarkEnabled = value),
                  ),
                  if (watermarkEnabled)
                    TextField(
                      controller: watermarkText,
                      decoration: const InputDecoration(labelText: 'Texte du filigrane'),
                    ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: faceGroupingEnabled,
                    title: const Text('Regroupement anonyme des visages'),
                    subtitle: const Text(
                      'Activé uniquement si le consentement biométrique a été validé dans Équipe & marque.',
                    ),
                    onChanged: (value) => update(() => faceGroupingEnabled = value),
                  ),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: <Widget>[
                      _field(maxMegapixels, 'Résolution max téléchargement (MP)', width: 270),
                      _field(downloadHours, 'Durée du lien (heures)', width: 220),
                      _field(brandId, 'Marque / boutique associée', width: 280),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: shopLayout,
                    decoration: const InputDecoration(labelText: 'Présentation de la boutique'),
                    items: const <DropdownMenuItem<String>>[
                      DropdownMenuItem(value: 'grid', child: Text('Grille')),
                      DropdownMenuItem(value: 'editorial', child: Text('Éditoriale')),
                      DropdownMenuItem(value: 'minimal', child: Text('Minimaliste')),
                    ],
                    onChanged: (value) => update(() => shopLayout = value ?? 'grid'),
                  ),
                  if (packSnapshot.docs.isNotEmpty) ...<Widget>[
                    const Divider(height: 30),
                    Text(
                      'Tarifs des packs',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: packSnapshot.docs.map((doc) {
                        final pack = doc.data();
                        return _field(
                          priceControllers[doc.id]!,
                          '${pack['title'] ?? 'Pack'} (€)',
                          width: 220,
                        );
                      }).toList(growable: false),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Annuler'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(dialogContext, true),
              icon: const Icon(Icons.save_outlined),
              label: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );

    if (saved != true || !mounted) {
      for (final controller in <TextEditingController>[
        title,
        description,
        startTime,
        endTime,
        startPoint,
        endPoint,
        participants,
        watermarkText,
        maxMegapixels,
        downloadHours,
        brandId,
        ...priceControllers.values,
      ]) {
        controller.dispose();
      }
      return;
    }

    setState(() => _working = true);
    try {
      final allowList = participants.text
          .split(RegExp(r'[,\n;]+'))
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty)
          .toSet()
          .toList(growable: false);
      await widget.repository.updateGallery(
        galleryId: gallery.galleryId,
        patch: <String, dynamic>{
          'title': title.text.trim(),
          'description': description.text.trim(),
          'eventDate': Timestamp.fromDate(eventDate),
          'shootStartTime': startTime.text.trim(),
          'shootEndTime': endTime.text.trim(),
          'startPoint': startPoint.text.trim(),
          'endPoint': endPoint.text.trim(),
          'plannedVisibility': visibility,
          if (gallery.status.name != 'published') 'visibility': 'private',
          'participantRestricted': participantRestricted,
          'participantAllowList': allowList,
          'watermarkEnabled': watermarkEnabled,
          'watermarkText': watermarkText.text.trim(),
          'faceGroupingEnabled': faceGroupingEnabled,
          'maxDownloadMegapixels': int.tryParse(maxMegapixels.text) ?? 24,
          'downloadWindowHours': int.tryParse(downloadHours.text) ?? 72,
          'brandId': brandId.text.trim(),
          'shopLayout': shopLayout,
        },
      );
      final batch = firestore.batch();
      for (final doc in packSnapshot.docs) {
        final price = double.tryParse(
          priceControllers[doc.id]!.text.replaceAll(',', '.'),
        );
        if (price != null && price >= 0) {
          batch.set(
            doc.reference,
            <String, dynamic>{
              'price': price,
              'updatedAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true),
          );
        }
      }
      await batch.commit();
      await _reload();
      _message('Galerie, accès, filigrane et tarifs mis à jour.');
    } catch (error) {
      _message(error.toString(), error: true);
    } finally {
      for (final controller in <TextEditingController>[
        title,
        description,
        startTime,
        endTime,
        startPoint,
        endPoint,
        participants,
        watermarkText,
        maxMegapixels,
        downloadHours,
        brandId,
        ...priceControllers.values,
      ]) {
        controller.dispose();
      }
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _privateLink(MediaGalleryModel gallery) async {
    setState(() => _working = true);
    try {
      final link = await widget.repository.generatePrivateLink(
        photographerId: widget.profile.photographerId,
        galleryId: gallery.galleryId,
      );
      await Clipboard.setData(ClipboardData(text: link));
      _message('Lien privé copié dans le presse-papiers.');
      await _reload();
    } catch (error) {
      _message(error.toString(), error: true);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _duplicate(MediaGalleryModel gallery) async {
    setState(() => _working = true);
    try {
      final id = await widget.repository.duplicateGallery(
        photographerId: widget.profile.photographerId,
        galleryId: gallery.galleryId,
      );
      _selectedId = id;
      await _reload();
      _message('Galerie dupliquée sans copier les photos.');
    } catch (error) {
      _message(error.toString(), error: true);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _delete(MediaGalleryModel gallery) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer la galerie ?'),
        content: const Text(
          'La suppression est définitive. Elle sera refusée si une photo a déjà été achetée.',
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
      await widget.repository.deleteGallery(
        photographerId: widget.profile.photographerId,
        galleryId: gallery.galleryId,
      );
      _selectedId = null;
      await _reload();
      _message('Galerie supprimée.');
    } catch (error) {
      _message(error.toString(), error: true);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    double width = 260,
    String? hint,
  }) {
    return SizedBox(
      width: width,
      child: TextField(
        controller: controller,
        decoration: InputDecoration(labelText: label, hintText: hint),
      ),
    );
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

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: FilledButton.icon(
          onPressed: _reload,
          icon: const Icon(Icons.refresh_rounded),
          label: Text('Réessayer : $_error'),
        ),
      );
    }
    final selected = _selected;
    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: <Widget>[
              FilledButton.icon(
                onPressed: _working ? null : _openCreator,
                icon: const Icon(Icons.create_new_folder_outlined),
                label: const Text('Créer une galerie'),
              ),
              if (selected != null) ...<Widget>[
                FilledButton.tonalIcon(
                  onPressed: _working ? null : () => _editGallery(selected),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Éditer complètement'),
                ),
                OutlinedButton.icon(
                  onPressed: _working ? null : () => _privateLink(selected),
                  icon: const Icon(Icons.link_rounded),
                  label: const Text('Créer un lien privé'),
                ),
                OutlinedButton.icon(
                  onPressed: _working ? null : () => _duplicate(selected),
                  icon: const Icon(Icons.copy_all_outlined),
                  label: const Text('Dupliquer'),
                ),
                OutlinedButton.icon(
                  onPressed: _working ? null : () => _delete(selected),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Supprimer'),
                ),
              ],
            ],
          ),
          const SizedBox(height: 18),
          if (_galleries.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('Crée ta première galerie rattachée à un circuit.'),
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 1050
                    ? 3
                    : constraints.maxWidth >= 680
                        ? 2
                        : 1;
                final width = columns == 1
                    ? constraints.maxWidth
                    : (constraints.maxWidth - ((columns - 1) * 12)) / columns;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: _galleries.map((gallery) {
                    final active = gallery.galleryId == selected?.galleryId;
                    return SizedBox(
                      width: width,
                      child: Card(
                        elevation: active ? 5 : 1,
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () => setState(() => _selectedId = gallery.galleryId),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Row(
                                  children: <Widget>[
                                    Expanded(
                                      child: Text(
                                        gallery.title,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(fontWeight: FontWeight.w900),
                                      ),
                                    ),
                                    if (active) const Icon(Icons.check_circle_rounded),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '${gallery.photoCount} photos • ${gallery.packCount} packs • ${gallery.status.label}',
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Circuit ${gallery.linkedCircuitId ?? 'non renseigné'} • ${gallery.visibility.label}',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(growable: false),
                );
              },
            ),
        ],
      ),
    );
  }
}
