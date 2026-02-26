import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/image_asset.dart' as img;
import '../models/market_circuit_models.dart';
import '../services/image_management_service.dart';
import '../services/webp_converter.dart';
import '../ui/snack/top_snack_bar.dart';

class PoiEditPopup extends StatefulWidget {
  final MarketMapPOI poi;

  /// Utilisé uniquement pour construire un parentId stable côté images.
  /// Si null, l'upload est désactivé.
  final String? projectId;

  const PoiEditPopup({super.key, required this.poi, required this.projectId});

  @override
  State<PoiEditPopup> createState() => _PoiEditPopupState();
}

class _PoiEditPopupState extends State<PoiEditPopup> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  final _picker = ImagePicker();
  final _imageService = ImageManagementService.instance;

  XFile? _selectedFile;
  Uint8List? _selectedPreviewBytes;
  XFile? _originalPickedFile;
  Uint8List? _originalPickedBytes;
  String? _uploadedImageUrl;
  String? _uploadedImageAssetId;

  bool _isSaving = false;
  bool _isUploading = false;
  bool _isConverting = false;
  double _uploadProgress = 0.0;

  bool _convertToWebp = true;
  bool _webpUnsupportedNotified = false;

  double _angleDeg = -1.7;
  double _grain = 0.35;

  Map<String, dynamic> get _initialMeta {
    final raw = widget.poi.metadata;
    if (raw == null) return <String, dynamic>{};
    return Map<String, dynamic>.from(raw);
  }

  @override
  void initState() {
    super.initState();

    _nameCtrl.text = widget.poi.name;
    _descCtrl.text = widget.poi.description ?? '';

    _uploadedImageUrl = widget.poi.imageUrl;

    final meta = _initialMeta;
    final polaroid = meta['polaroid'];
    if (polaroid is Map) {
      final a = polaroid['angleDeg'];
      final g = polaroid['grain'];
      if (a is num) _angleDeg = a.toDouble().clamp(-7.0, 7.0);
      if (g is num) _grain = g.toDouble().clamp(0.0, 1.0);
    }

    final image = meta['image'];
    if (image is Map) {
      final id = image['assetId'];
      if (id is String && id.trim().isNotEmpty) {
        _uploadedImageAssetId = id.trim();
      }
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  String? _poiImagesParentId() {
    final pid = widget.projectId?.trim();
    if (pid == null || pid.isEmpty) return null;
    return 'poi_${pid}_${widget.poi.id}';
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final file = await _picker.pickImage(
        source: source,
        // On limite la taille à la source pour éviter un refus Storage (règles: 5MB).
        // Cohérent avec le reste de l'app (souvent 85-88).
        imageQuality: 88,
        maxWidth: 1920,
        maxHeight: 1920,
      );
      if (file == null) return;
      if (!mounted) return;
      await _setSelectedFile(file);
    } catch (e) {
      if (!mounted) return;
      TopSnackBar.showMessage(
        context,
        '❌ Erreur sélection image: $e',
        isError: true,
      );
    }
  }

  String _withWebpExtension(String filename) {
    final lower = filename.toLowerCase();
    final dot = lower.lastIndexOf('.');
    if (dot <= 0) return '$filename.webp';
    return '${filename.substring(0, dot)}.webp';
  }

  Future<void> _toggleConvertToWebp(bool value) async {
    if (!mounted) return;
    setState(() {
      _convertToWebp = value;
      _isConverting = true;
    });

    final originalFile = _originalPickedFile;
    if (originalFile == null) {
      if (mounted) setState(() => _isConverting = false);
      return;
    }

    try {
      await _applyConversionFromOriginal(originalFile);
    } finally {
      if (mounted) setState(() => _isConverting = false);
    }
  }

  Future<void> _setSelectedFile(XFile file) async {
    if (!mounted) return;
    setState(() {
      _isConverting = true;
      _originalPickedFile = file;
      _selectedFile = file;
      _originalPickedBytes = null;
      _selectedPreviewBytes = null;
    });

    try {
      final originalBytes = await file.readAsBytes();

      if (!mounted) return;
      setState(() {
        _originalPickedBytes = originalBytes;
      });

      await _applyConversionFromOriginal(file);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _selectedFile = file;
        _selectedPreviewBytes = null;
      });
      TopSnackBar.showMessage(
        context,
        '⚠️ Lecture image impossible: $e',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() => _isConverting = false);
      }
    }
  }

  Future<void> _applyConversionFromOriginal(XFile originalFile) async {
    final originalBytes = _originalPickedBytes;
    if (originalBytes == null) {
      // On n'a pas encore les bytes (lecture en cours) => on garde l'original pour l'instant.
      if (!mounted) return;
      setState(() {
        _selectedFile = originalFile;
        _selectedPreviewBytes = null;
      });
      return;
    }

    try {
      if (_convertToWebp) {
        if (!supportsWebpConversion) {
          if (!_webpUnsupportedNotified && mounted) {
            _webpUnsupportedNotified = true;
            TopSnackBar.showMessage(
              context,
              'ℹ️ Conversion WebP disponible sur Web uniquement (pour l’instant).',
              isError: false,
            );
          }

          if (!mounted) return;
          setState(() {
            _selectedFile = originalFile;
            _selectedPreviewBytes = originalBytes;
          });
          return;
        }

        final webpBytes = await convertBytesToWebp(
          originalBytes,
          quality: 88,
        );

        final webpFile = XFile.fromData(
          webpBytes,
          name: _withWebpExtension(originalFile.name),
          mimeType: 'image/webp',
        );

        if (!mounted) return;
        setState(() {
          _selectedFile = webpFile;
          _selectedPreviewBytes = webpBytes;
        });
      } else {
        if (!mounted) return;
        setState(() {
          _selectedFile = originalFile;
          _selectedPreviewBytes = originalBytes;
        });
      }
    } catch (e) {
      if (!mounted) return;
      // Fallback: garder l'original (sans conversion)
      setState(() {
        _selectedFile = originalFile;
        _selectedPreviewBytes = originalBytes;
      });
      TopSnackBar.showMessage(
        context,
        '⚠️ Conversion WebP impossible, upload en original: $e',
        isError: true,
      );
    }
  }

  Future<void> _showSourcePicker() async {
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      builder: (ctx) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library_rounded),
                title: const Text('Galerie'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.gallery);
                },
              ),
              if (!kIsWeb)
                ListTile(
                  leading: const Icon(Icons.camera_alt_rounded),
                  title: const Text('Appareil photo'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickImage(ImageSource.camera);
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _uploadSelectedImageIfNeeded() async {
    if (_selectedFile == null) return;

    final parentId = _poiImagesParentId();
    if (parentId == null) {
      throw StateError('Projet non initialisé. Sauvegarde le brouillon avant l\'upload.');
    }

    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
    });

    try {
      final asset = await _imageService.uploadImage(
        file: _selectedFile!,
        contentType: img.ImageContentType.placePhoto,
        parentId: parentId,
        altText: _nameCtrl.text.trim().isEmpty ? widget.poi.name : _nameCtrl.text.trim(),
        onProgress: (p) {
          if (!mounted) return;
          setState(() => _uploadProgress = p);
        },
      );

      if (!mounted) return;
      setState(() {
        _uploadedImageUrl = asset.mediumUrl;
        _uploadedImageAssetId = asset.id;
        _selectedFile = null;
      });

      if (mounted) {
        TopSnackBar.showMessage(
          context,
          '✅ Photo uploadée',
          isError: false,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
          _uploadProgress = 0.0;
        });
      }
    }
  }

  MarketMapPOI _buildUpdatedPoi() {
    final nextName = _nameCtrl.text.trim().isEmpty
        ? widget.poi.name
        : _nameCtrl.text.trim();

    final nextDesc = _descCtrl.text.trim().isEmpty
        ? null
        : _descCtrl.text.trim();

    final meta = _initialMeta;

    meta['polaroid'] = <String, dynamic>{
      'angleDeg': _angleDeg,
      'grain': _grain,
    };

    if ((_uploadedImageUrl ?? '').trim().isNotEmpty) {
      meta['image'] = <String, dynamic>{
        'assetId': _uploadedImageAssetId,
        'url': _uploadedImageUrl,
      };
    }

    final nextImageUrl = (_uploadedImageUrl?.trim().isNotEmpty ?? false)
        ? _uploadedImageUrl!.trim()
        : ((widget.poi.imageUrl?.trim().isNotEmpty ?? false)
            ? widget.poi.imageUrl!.trim()
            : null);

    return MarketMapPOI(
      id: widget.poi.id,
      name: nextName,
      layerType: widget.poi.layerType,
      lng: widget.poi.lng,
      lat: widget.poi.lat,
      description: nextDesc,
      imageUrl: nextImageUrl,
      instagram: widget.poi.instagram,
      facebook: widget.poi.facebook,
      metadata: meta,
    );
  }

  Future<void> _save() async {
    if (_isSaving) return;

    setState(() => _isSaving = true);
    try {
      await _uploadSelectedImageIfNeeded();

      if (!mounted) return;
      Navigator.of(context).pop(_buildUpdatedPoi());
    } catch (e) {
      if (!mounted) return;
      TopSnackBar.showMessage(
        context,
        '❌ Impossible d\'enregistrer: $e',
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Widget _buildPolaroidPreview({required Widget image}) {
    final theme = Theme.of(context);
    final angleRad = _angleDeg * (math.pi / 180.0);

    return Transform.rotate(
      angle: angleRad,
      child: Container(
        width: 260,
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 22,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: CustomPaint(
                  painter: _PolaroidGrainPainter(
                    seed: widget.poi.id.hashCode,
                    intensity: _grain,
                  ),
                ),
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: AspectRatio(aspectRatio: 1, child: image),
                ),
                const SizedBox(height: 12),
                Text(
                  _nameCtrl.text.trim().isEmpty ? widget.poi.name : _nameCtrl.text.trim(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.poi.layerType,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.70),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePreview() {
    final selected = _selectedFile;
    final previewBytes = _selectedPreviewBytes;
    final url = (_uploadedImageUrl ?? '').trim().isNotEmpty ? _uploadedImageUrl! : null;

    Widget image;
    if (selected != null) {
      if (previewBytes != null) {
        image = Image.memory(previewBytes, fit: BoxFit.cover);
      } else {
        image = FutureBuilder<Uint8List>(
          future: selected.readAsBytes(),
          builder: (context, snap) {
            if (snap.hasData) {
              return Image.memory(snap.data!, fit: BoxFit.cover);
            }
            return const Center(child: CircularProgressIndicator());
          },
        );
      }
    } else if (url != null) {
      image = Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => const ColoredBox(
          color: Colors.black12,
          child: Center(child: Icon(Icons.broken_image_rounded, size: 42)),
        ),
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return const Center(child: CircularProgressIndicator());
        },
      );
    } else {
      image = const ColoredBox(
        color: Colors.black12,
        child: Center(child: Icon(Icons.photo_rounded, size: 42)),
      );
    }

    return Center(child: _buildPolaroidPreview(image: image));
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.viewInsetsOf(context);
    final canUpload = _poiImagesParentId() != null;

    return SingleChildScrollView(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 14,
        bottom: 16 + viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Éditer le POI',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                ),
              ),
              IconButton(
                tooltip: 'Fermer',
                onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          const SizedBox(height: 8),

          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(
              labelText: 'Nom',
              border: OutlineInputBorder(),
            ),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descCtrl,
            decoration: const InputDecoration(
              labelText: 'Description (optionnel)',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),

          const SizedBox(height: 14),
          _buildImagePreview(),

          const SizedBox(height: 12),
          FilledButton.tonalIcon(
            onPressed: (!canUpload || _isSaving || _isConverting) ? null : _showSourcePicker,
            icon: const Icon(Icons.add_a_photo_rounded),
            label: Text(
              (_selectedFile != null) ? 'Changer la photo' : 'Ajouter une photo',
            ),
          ),

          if (_selectedFile != null) ...[
            const SizedBox(height: 6),
            SwitchListTile.adaptive(
              value: _convertToWebp,
              onChanged: (_isSaving || _isUploading || _isConverting)
                  ? null
                  : _toggleConvertToWebp,
              title: const Text('Convertir en WebP'),
              subtitle: const Text('Réduit la taille et accélère le chargement.'),
              contentPadding: EdgeInsets.zero,
            ),
          ],

          if (!canUpload) ...[
            const SizedBox(height: 6),
            Text(
              'Astuce: enregistre d\'abord le brouillon du projet pour activer l\'upload photo.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],

          if (_selectedFile != null) ...[
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: (!canUpload || _isSaving || _isUploading || _isConverting)
                  ? null
                  : _uploadSelectedImageIfNeeded,
              icon: const Icon(Icons.cloud_upload_rounded),
              label: const Text('Uploader'),
            ),
          ],

          if (_isConverting) ...[
            const SizedBox(height: 8),
            const LinearProgressIndicator(),
            const SizedBox(height: 4),
            Text(
              'Conversion en WebP…',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],

          if (_isUploading) ...[
            const SizedBox(height: 10),
            LinearProgressIndicator(value: _uploadProgress == 0 ? null : _uploadProgress),
            const SizedBox(height: 4),
            Text(
              'Upload ${(100 * _uploadProgress).toStringAsFixed(0)}%',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],

          const SizedBox(height: 12),
          Text(
            'Effet polaroid',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const SizedBox(width: 76, child: Text('Angle')),
              Expanded(
                child: Slider(
                  value: _angleDeg,
                  min: -7,
                  max: 7,
                  divisions: 28,
                  label: '${_angleDeg.toStringAsFixed(1)}°',
                  onChanged: _isSaving
                      ? null
                      : (v) => setState(() => _angleDeg = v),
                ),
              ),
            ],
          ),
          Row(
            children: [
              const SizedBox(width: 76, child: Text('Grain')),
              Expanded(
                child: Slider(
                  value: _grain,
                  min: 0,
                  max: 1,
                  divisions: 20,
                  label: _grain.toStringAsFixed(2),
                  onChanged: _isSaving
                      ? null
                      : (v) => setState(() => _grain = v),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),
          FilledButton(
            onPressed: (_isSaving || _isUploading || _isConverting) ? null : _save,
            child: Text(_isSaving ? 'Enregistrement…' : 'Enregistrer'),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _PolaroidGrainPainter extends CustomPainter {
  final int seed;
  final double intensity;

  _PolaroidGrainPainter({required this.seed, required this.intensity});

  @override
  void paint(Canvas canvas, Size size) {
    if (intensity <= 0.001) return;

    final rnd = math.Random(seed);
    final count = (2200 * intensity).round().clamp(60, 2200);

    final paint = Paint()..style = PaintingStyle.fill;
    for (int i = 0; i < count; i++) {
      final x = rnd.nextDouble() * size.width;
      final y = rnd.nextDouble() * size.height;
      final r = 0.35 + rnd.nextDouble() * 0.9;
      final a = (0.025 + rnd.nextDouble() * 0.06) * intensity;
      paint.color = Colors.black.withValues(alpha: a);
      canvas.drawCircle(Offset(x, y), r, paint);
    }

    // Vignette très légère
    final vignette = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.transparent,
          Colors.black.withValues(alpha: 0.06 * intensity),
        ],
        stops: const [0.6, 1.0],
      ).createShader(Offset.zero & size);

    canvas.drawRect(Offset.zero & size, vignette);
  }

  @override
  bool shouldRepaint(covariant _PolaroidGrainPainter oldDelegate) {
    return oldDelegate.seed != seed || oldDelegate.intensity != intensity;
  }
}
