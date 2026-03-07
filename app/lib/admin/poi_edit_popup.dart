import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';

import '../models/image_asset.dart' as img;
import '../models/market_circuit_models.dart';
import '../services/image_management_service.dart';
import '../services/poi_popup_service.dart';
import '../services/webp_converter.dart';
import '../ui/map/maslive_poi_style.dart';
import '../ui/snack/top_snack_bar.dart';

class PoiEditPopup extends StatefulWidget {
  final MarketMapPOI poi;

  /// Utilisé uniquement pour construire un parentId stable côté images.
  /// Si null, l'upload est désactivé.
  final String? projectId;

  /// Optionnel: liste de presets d'apparence (persistés dans metadata.appearance).
  /// Si null ou vide, l'apparence n'est pas éditable dans ce popup.
  final List<MasLivePoiAppearancePreset>? appearancePresets;

  const PoiEditPopup({
    super.key,
    required this.poi,
    required this.projectId,
    this.appearancePresets,
  });

  @override
  State<PoiEditPopup> createState() => _PoiEditPopupState();
}

class _PoiEditPopupState extends State<PoiEditPopup> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  final _addressCtrl = TextEditingController();
  final _openingHoursCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _websiteCtrl = TextEditingController();
  final _instagramCtrl = TextEditingController();
  final _facebookCtrl = TextEditingController();
  final _whatsappCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _mapsUrlCtrl = TextEditingController();

  final _latCtrl = TextEditingController();
  final _lngCtrl = TextEditingController();

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

  String? _appearanceId;

  bool _popupEnabled = true;
  bool _isVisible = true;

  String _textFromOpeningHours(Object? value) {
    if (value == null) return '';
    if (value is String) return value;
    return value.toString();
  }

  double? _parseDouble(String raw) {
    final norm = raw.trim().replaceAll(',', '.');
    return double.tryParse(norm);
  }

  bool get _hasAnyImage {
    if (_selectedFile != null) return true;
    if ((_uploadedImageUrl ?? '').trim().isNotEmpty) return true;
    if ((_uploadedImageAssetId ?? '').trim().isNotEmpty) return true;
    return false;
  }

  Widget _buildFineAdjustSlider({
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String displayValue,
    required ValueChanged<double>? onChanged,
  }) {
    final clamped = value.clamp(min, max);
    final step = (max - min) / divisions;

    void nudge(double delta) {
      if (onChanged == null) return;
      final next = (clamped + delta).clamp(min, max);
      if ((next - clamped).abs() < 0.0000001) return;
      onChanged(next);
    }

    return Row(
      children: [
        SizedBox(width: 76, child: Text(label)),
        IconButton.outlined(
          tooltip: 'Diminuer $label',
          visualDensity: VisualDensity.compact,
          onPressed: onChanged == null || clamped <= min
              ? null
              : () => nudge(-step),
          icon: const Icon(Icons.remove_rounded, size: 18),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Slider(
            value: clamped,
            min: min,
            max: max,
            divisions: divisions,
            label: displayValue,
            onChanged: onChanged,
          ),
        ),
        const SizedBox(width: 6),
        IconButton.outlined(
          tooltip: 'Augmenter $label',
          visualDensity: VisualDensity.compact,
          onPressed: onChanged == null || clamped >= max
              ? null
              : () => nudge(step),
          icon: const Icon(Icons.add_rounded, size: 18),
        ),
      ],
    );
  }

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

    _addressCtrl.text = widget.poi.address ?? '';
    _openingHoursCtrl.text = _textFromOpeningHours(widget.poi.openingHours);
    _phoneCtrl.text = widget.poi.phone ?? '';
    _websiteCtrl.text = widget.poi.website ?? '';
    _instagramCtrl.text = widget.poi.instagram ?? '';
    _facebookCtrl.text = widget.poi.facebook ?? '';
    _whatsappCtrl.text = widget.poi.whatsapp ?? '';
    _emailCtrl.text = widget.poi.email ?? '';
    _mapsUrlCtrl.text = widget.poi.mapsUrl ?? '';

    _latCtrl.text = widget.poi.lat.toStringAsFixed(6);
    _lngCtrl.text = widget.poi.lng.toStringAsFixed(6);

    _isVisible = widget.poi.isVisible;

    _uploadedImageUrl = widget.poi.imageUrl;

    final meta = _initialMeta;

    // Pour certains flows de création, on veut forcer l'utilisateur à saisir des coordonnées.
    // Signal interne (non persisté) : __coordsUnset.
    if (meta['__coordsUnset'] == true) {
      _latCtrl.text = '';
      _lngCtrl.text = '';
    }

    final presets = widget.appearancePresets;
    if (presets != null && presets.isNotEmpty) {
      final rawId = meta[kMasLivePoiAppearanceKey];
      final existing = rawId is String ? rawId.trim() : '';
      if (existing.isNotEmpty && presets.any((p) => p.id == existing)) {
        _appearanceId = existing;
      } else {
        _appearanceId = presets.first.id;
      }
    }

    // Back-compat imageUrl: certains POIs stockent l'image dans metadata.image.url
    if ((_uploadedImageUrl ?? '').trim().isEmpty) {
      final image = meta['image'];
      if (image is Map) {
        final url = image['url'];
        if (url is String && url.trim().isNotEmpty) {
          _uploadedImageUrl = url.trim();
        }
      }
    }

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

    _popupEnabled = PoiPopupService.isPopupEnabled(
      type: widget.poi.layerType,
      meta: meta,
      requireImage: true,
      hasImage: _hasAnyImage,
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _addressCtrl.dispose();
    _openingHoursCtrl.dispose();
    _phoneCtrl.dispose();
    _websiteCtrl.dispose();
    _instagramCtrl.dispose();
    _facebookCtrl.dispose();
    _whatsappCtrl.dispose();
    _emailCtrl.dispose();
    _mapsUrlCtrl.dispose();
    _latCtrl.dispose();
    _lngCtrl.dispose();
    super.dispose();
  }

  bool _validateInputs() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      TopSnackBar.showMessage(
        context,
        'Nom requis.',
        isError: true,
      );
      return false;
    }

    final lat = _parseDouble(_latCtrl.text);
    final lng = _parseDouble(_lngCtrl.text);
    if (lat == null || lng == null) {
      TopSnackBar.showMessage(
        context,
        'Lat/Lng requis.',
        isError: true,
      );
      return false;
    }
    if (lat < -90 || lat > 90) {
      TopSnackBar.showMessage(
        context,
        'Latitude invalide (entre -90 et 90).',
        isError: true,
      );
      return false;
    }
    if (lng < -180 || lng > 180) {
      TopSnackBar.showMessage(
        context,
        'Longitude invalide (entre -180 et 180).',
        isError: true,
      );
      return false;
    }
    return true;
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
      
      // Proposer l'édition avec les outils système natifs
      await _editImageWithSystemTools(file);
    } catch (e) {
      if (!mounted) return;
      TopSnackBar.showMessage(
        context,
        '❌ Erreur sélection image: $e',
        isError: true,
      );
    }
  }

  /// Édite la photo avec les outils natifs (filtres système iOS/Android)
  Future<void> _editImageWithSystemTools(XFile pickedFile) async {
    if (kIsWeb) {
      // Sur Web, on ne peut pas utiliser l'éditeur natif
      await _setSelectedFile(pickedFile);
      return;
    }

    try {
      // Demander à l'utilisateur s'il veut éditer
      final shouldEdit = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Éditer la photo ?'),
          content: const Text(
            'Voulez-vous éditer cette photo avec les outils système '
            '(filtres, ajustements, recadrage) avant de l\'ajouter ?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Non, continuer'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(ctx, true),
              icon: const Icon(Icons.edit_rounded),
              label: const Text('Oui, éditer'),
            ),
          ],
        ),
      );

      if (shouldEdit != true) {
        if (!mounted) return;
        await _setSelectedFile(pickedFile);
        return;
      }

      // Après un await (dialog), vérifier mounted avant toute utilisation de context.
      if (!mounted) return;

      // Lancer l'éditeur natif avec support des filtres système
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: pickedFile.path,
        compressQuality: 88,
        maxWidth: 1920,
        maxHeight: 1920,
        uiSettings: [
          // Configuration iOS : utilise l'éditeur Photos natif
          IOSUiSettings(
            title: 'Éditer la photo',
            // Active l'accès aux filtres et outils natifs d'iOS
            aspectRatioPickerButtonHidden: false,
            resetButtonHidden: false,
            rotateButtonsHidden: false,
            aspectRatioLockEnabled: false,
            // Permet à l'utilisateur d'accéder aux filtres Photos
            showActivitySheetOnDone: false,
          ),
          // Configuration Android : utilise l'éditeur natif UCrop amélioré
          AndroidUiSettings(
            toolbarTitle: 'Éditer la photo',
            toolbarColor: Theme.of(context).colorScheme.primary,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.original,
            lockAspectRatio: false,
            // Active tous les outils d'édition
            hideBottomControls: false,
            showCropGrid: true,
            // Menu d'ajustements (luminosité, contraste, saturation)
            activeControlsWidgetColor: Theme.of(context).colorScheme.primary,
          ),
          // Configuration Web (fallback basique)
          WebUiSettings(
            context: context,
            presentStyle: WebPresentStyle.dialog,
            size: const CropperSize(width: 720, height: 720),
          ),
        ],
      );

      if (croppedFile == null) {
        // L'utilisateur a annulé l'édition => on utilise l'image originale
        if (!mounted) return;
        await _setSelectedFile(pickedFile);
        return;
      }

      // Convertir CroppedFile en XFile
      final editedFile = XFile(croppedFile.path);
      
      if (!mounted) return;
      await _setSelectedFile(editedFile);

      if (mounted) {
        TopSnackBar.showMessage(
          context,
          '✅ Photo éditée avec succès',
          isError: false,
        );
      }
    } catch (e) {
      if (!mounted) return;
      
      // En cas d'erreur, on utilise l'image originale
      await _setSelectedFile(pickedFile);

      if (!mounted) return;
      
      TopSnackBar.showMessage(
        context,
        '⚠️ Édition impossible, photo originale utilisée: $e',
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

      // Si l'utilisateur ajoute une image, on peut re-permettre le popup.
      if (!mounted) return;
      if (!_popupEnabled) {
        setState(() {
          _popupEnabled = PoiPopupService.isPopupEnabled(
            type: widget.poi.layerType,
            meta: _initialMeta,
            requireImage: true,
            hasImage: _hasAnyImage,
          );
        });
      }
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

    final nextAddress = _addressCtrl.text.trim().isEmpty
      ? null
      : _addressCtrl.text.trim();

    final nextOpeningHours = _openingHoursCtrl.text.trim().isEmpty
      ? null
      : _openingHoursCtrl.text.trim();

    final nextPhone = _phoneCtrl.text.trim().isEmpty
      ? null
      : _phoneCtrl.text.trim();

    final nextWebsite = _websiteCtrl.text.trim().isEmpty
      ? null
      : _websiteCtrl.text.trim();

    final nextInstagram = _instagramCtrl.text.trim().isEmpty
      ? null
      : _instagramCtrl.text.trim();

    final nextFacebook = _facebookCtrl.text.trim().isEmpty
      ? null
      : _facebookCtrl.text.trim();

    final nextWhatsapp = _whatsappCtrl.text.trim().isEmpty
      ? null
      : _whatsappCtrl.text.trim();

    final nextEmail = _emailCtrl.text.trim().isEmpty
      ? null
      : _emailCtrl.text.trim();

    final nextMapsUrl = _mapsUrlCtrl.text.trim().isEmpty
      ? null
      : _mapsUrlCtrl.text.trim();

    final nextLat = _parseDouble(_latCtrl.text) ?? widget.poi.lat;
    final nextLng = _parseDouble(_lngCtrl.text) ?? widget.poi.lng;

    final meta = _initialMeta;

    // Nettoyage des flags internes (non destinés à Firestore).
    meta.remove('__coordsUnset');

    final nextAppearanceId = _appearanceId;
    if (nextAppearanceId != null && nextAppearanceId.trim().isNotEmpty) {
      meta[kMasLivePoiAppearanceKey] = nextAppearanceId.trim();
    }

    meta['popupEnabled'] = _popupEnabled;

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
      lng: nextLng,
      lat: nextLat,
      isVisible: _isVisible,
      layerId: widget.poi.layerId,
      description: nextDesc,
      imageUrl: nextImageUrl,
      address: nextAddress,
      openingHours: nextOpeningHours,
      phone: nextPhone,
      website: nextWebsite,
      instagram: nextInstagram,
      facebook: nextFacebook,
      whatsapp: nextWhatsapp,
      email: nextEmail,
      mapsUrl: nextMapsUrl,
      metadata: meta,
    );
  }

  Future<void> _save() async {
    if (_isSaving) return;

    if (!mounted) return;
    if (!_validateInputs()) return;

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

          if ((widget.appearancePresets?.isNotEmpty ?? false) && _appearanceId != null) ...[
            const SizedBox(height: 12),
            InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Apparence',
                border: OutlineInputBorder(),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _appearanceId,
                  isExpanded: true,
                  items: [
                    for (final p in widget.appearancePresets!)
                      DropdownMenuItem(value: p.id, child: Text(p.label)),
                  ],
                  onChanged: (_isSaving || _isUploading || _isConverting)
                      ? null
                      : (v) {
                          if (v == null) return;
                          setState(() => _appearanceId = v);
                        },
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: _descCtrl,
            decoration: const InputDecoration(
              labelText: 'Description (optionnel)',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),

          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _latCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Lat *',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _lngCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Lng *',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: _isVisible,
            onChanged: _isSaving ? null : (v) => setState(() => _isVisible = v),
            title: const Text('Visible (liste + couche)'),
          ),

          const SizedBox(height: 12),
          TextField(
            controller: _addressCtrl,
            decoration: const InputDecoration(
              labelText: 'Adresse (optionnel)',
              border: OutlineInputBorder(),
            ),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _openingHoursCtrl,
            decoration: const InputDecoration(
              labelText: 'Horaires (optionnel)',
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _phoneCtrl,
            decoration: const InputDecoration(
              labelText: 'Téléphone (optionnel)',
              border: OutlineInputBorder(),
            ),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _websiteCtrl,
            decoration: const InputDecoration(
              labelText: 'Site web (optionnel)',
              border: OutlineInputBorder(),
            ),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _instagramCtrl,
            decoration: const InputDecoration(
              labelText: 'Instagram (optionnel)',
              border: OutlineInputBorder(),
            ),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _facebookCtrl,
            decoration: const InputDecoration(
              labelText: 'Facebook (optionnel)',
              border: OutlineInputBorder(),
            ),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _whatsappCtrl,
            decoration: const InputDecoration(
              labelText: 'WhatsApp (optionnel)',
              border: OutlineInputBorder(),
            ),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _emailCtrl,
            decoration: const InputDecoration(
              labelText: 'Email (optionnel)',
              border: OutlineInputBorder(),
            ),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _mapsUrlCtrl,
            decoration: const InputDecoration(
              labelText: 'Lien Google Maps (optionnel)',
              border: OutlineInputBorder(),
            ),
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
          if (!kIsWeb) ...[
            const SizedBox(height: 6),
            Text(
              'Vous pourrez éditer la photo avec les filtres et outils système après sélection.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontStyle: FontStyle.italic,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],

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

          const SizedBox(height: 8),
          SwitchListTile.adaptive(
            value: _popupEnabled,
            onChanged: (_isSaving || _isUploading || _isConverting || !_hasAnyImage)
                ? null
                : (v) => setState(() => _popupEnabled = v),
            title: const Text('Popup'),
            subtitle: Text(
              _hasAnyImage
                  ? 'Le POI est cliquable et ouvre la fiche photo.'
                  : 'Ajoute une photo pour activer la fiche photo.',
            ),
            contentPadding: EdgeInsets.zero,
          ),

          const SizedBox(height: 12),
          Text(
            'Effet polaroid',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          _buildFineAdjustSlider(
            label: 'Angle',
            value: _angleDeg,
            min: -7,
            max: 7,
            divisions: 28,
            displayValue: '${_angleDeg.toStringAsFixed(1)}°',
            onChanged: _isSaving
                ? null
                : (v) => setState(() => _angleDeg = v),
          ),
          _buildFineAdjustSlider(
            label: 'Grain',
            value: _grain,
            min: 0,
            max: 1,
            divisions: 20,
            displayValue: _grain.toStringAsFixed(2),
            onChanged: _isSaving
                ? null
                : (v) => setState(() => _grain = v),
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
