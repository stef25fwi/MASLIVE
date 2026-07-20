import 'package:flutter/material.dart';

import '../../data/models/media_gallery_model.dart';
import '../../data/models/photographer_profile_model.dart';
import '../../data/repositories/photographer_complete_flow_repository.dart';
import '../../domain/services/photographer_import_session_service.dart';

class PhotographerImportPanel extends StatefulWidget {
  const PhotographerImportPanel({
    super.key,
    required this.profile,
    required this.repository,
  });

  final PhotographerProfileModel profile;
  final PhotographerCompleteFlowRepository repository;

  @override
  State<PhotographerImportPanel> createState() => _PhotographerImportPanelState();
}

class _PhotographerImportPanelState extends State<PhotographerImportPanel> {
  final PhotographerImportSessionService _service =
      PhotographerImportSessionService.instance;
  List<MediaGalleryModel> _galleries = const <MediaGalleryModel>[];
  String? _galleryId;
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _service.addListener(_onServiceChanged);
    _load();
  }

  @override
  void dispose() {
    _service.removeListener(_onServiceChanged);
    super.dispose();
  }

  void _onServiceChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _service.load();
      final galleries = await widget.repository.loadGalleries(
        widget.profile.photographerId,
      );
      if (!mounted) return;
      setState(() {
        _galleries = galleries;
        _galleryId = galleries.any((gallery) => gallery.galleryId == _galleryId)
            ? _galleryId
            : (galleries.isEmpty ? null : galleries.first.galleryId);
      });
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  MediaGalleryModel? _gallery(String? id) {
    for (final gallery in _galleries) {
      if (gallery.galleryId == id) return gallery;
    }
    return null;
  }

  Future<String?> _askFolderName({String? initial}) async {
    final controller = TextEditingController(text: initial ?? '');
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nom de l’import'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Dossier ou lot',
            hintText: 'Carnaval Pointe-à-Pitre — matin',
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Continuer'),
          ),
        ],
      ),
    );
    controller.dispose();
    return value;
  }

  Future<void> _start({PhotographerImportSession? previous}) async {
    final gallery = _gallery(previous?.galleryId ?? _galleryId);
    if (gallery == null) {
      _message('Sélectionne une galerie avant l’import.', error: true);
      return;
    }
    final files = await _service.pickFolderOrBatch();
    if (files.isEmpty || !mounted) return;
    final folderName = await _askFolderName(initial: previous?.folderName);
    if (folderName == null || !mounted) return;
    try {
      final result = await _service.startOrResume(
        profile: widget.profile,
        gallery: gallery,
        files: files,
        previous: previous,
        folderName: folderName,
      );
      if (!mounted || result == null) return;
      final failed = result.failedFiles.length;
      _message(
        result.status == 'completed'
            ? 'Import terminé : ${result.completedFiles.length}/${result.totalFiles} fichiers.'
            : 'Import enregistré. ${result.completedFiles.length}/${result.totalFiles} terminés, $failed échec(s).',
        error: result.status == 'failed',
      );
    } catch (error) {
      _message(error.toString(), error: true);
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
                  'Import de dossier ou de lot',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Sélectionne toutes les images d’un dossier. La session est sauvegardée localement et côté serveur : après une fermeture ou une coupure, resélectionne le même dossier et MASLIVE ignore les fichiers déjà terminés.',
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _galleryId,
                  decoration: const InputDecoration(labelText: 'Galerie de destination'),
                  items: _galleries
                      .map(
                        (gallery) => DropdownMenuItem<String>(
                          value: gallery.galleryId,
                          child: Text(gallery.title),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: _service.working
                      ? null
                      : (value) => setState(() => _galleryId = value),
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: _service.working || _galleries.isEmpty ? null : _start,
                  icon: const Icon(Icons.drive_folder_upload_outlined),
                  label: const Text('Importer un dossier / lot'),
                ),
                if (_service.progress != null) ...<Widget>[
                  const SizedBox(height: 14),
                  LinearProgressIndicator(value: _service.progress!.fraction),
                  const SizedBox(height: 6),
                  Text(
                    '${_service.progress!.completed}/${_service.progress!.total} • ${_service.progress!.currentFile}',
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'Sessions persistantes',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(height: 10),
        if (_service.sessions.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(18),
              child: Text('Aucune session d’import enregistrée.'),
            ),
          )
        else
          for (final session in _service.sessions)
            Card(
              child: ListTile(
                leading: CircleAvatar(
                  child: Text('${(session.fraction * 100).round()}%'),
                ),
                title: Text(session.folderName),
                subtitle: Text(
                  '${session.completedFiles.length}/${session.totalFiles} • ${session.status} • ${session.failedFiles.length} échec(s)',
                ),
                trailing: Wrap(
                  spacing: 4,
                  children: <Widget>[
                    if (session.canResume)
                      IconButton(
                        tooltip: 'Reprendre avec le même dossier',
                        onPressed: _service.working
                            ? null
                            : () => _start(previous: session),
                        icon: const Icon(Icons.play_circle_outline),
                      ),
                    IconButton(
                      tooltip: 'Retirer de l’historique local',
                      onPressed: _service.working
                          ? null
                          : () => _service.removeSession(session.sessionId),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
            ),
        const SizedBox(height: 18),
        const Card(
          child: ListTile(
            leading: Icon(Icons.cloud_sync_outlined),
            title: Text('Traitement en arrière-plan dans MASLIVE'),
            subtitle: Text(
              'Tu peux changer d’onglet pendant l’envoi. Les fichiers terminés sont mémorisés à chaque étape. Sur mobile ou navigateur fermé, la reprise s’effectue en resélectionnant le lot.',
            ),
          ),
        ),
      ],
    );
  }
}
