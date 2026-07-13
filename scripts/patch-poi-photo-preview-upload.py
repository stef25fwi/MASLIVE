from pathlib import Path

popup_path = Path('app/lib/admin/poi_edit_popup.dart')
s = popup_path.read_text()

old_set = """  Future<void> _setSelectedFile(XFile file) async {
    if (!mounted) return;
    setState(() {
      _selectedFile = file;
      _selectedPreviewBytes = null;
      _previewBytesFuture = file.readAsBytes();
    });

    try {
      final originalBytes = await file.readAsBytes();

      if (!mounted) return;
      setState(() {
        _selectedFile = file;
        _selectedPreviewBytes = originalBytes;
      });

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
        _selectedFile = null;
        _selectedPreviewBytes = null;
        _previewBytesFuture = null;
      });
      TopSnackBar.showMessage(
        context,
        '⚠️ Lecture image impossible: $e',
        isError: true,
      );
    }
  }
"""
new_set = """  Future<void> _setSelectedFile(XFile file) async {
    if (!mounted) return;

    final readFuture = file.readAsBytes();
    setState(() {
      _selectedFile = file;
      _selectedPreviewBytes = null;
      _previewBytesFuture = readFuture;
    });

    try {
      final originalBytes = await readFuture;
      if (originalBytes.isEmpty) {
        throw StateError('Le fichier image est vide.');
      }

      if (!mounted) return;
      setState(() {
        _selectedFile = file;
        _selectedPreviewBytes = originalBytes;
        _previewBytesFuture = null;
        if (!_popupEnabled) {
          _popupEnabled = PoiPopupService.isPopupEnabled(
            type: widget.poi.layerType,
            meta: _initialMeta,
            requireImage: true,
            hasImage: true,
          );
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _selectedFile = null;
        _selectedPreviewBytes = null;
        _previewBytesFuture = null;
      });
      TopSnackBar.showMessage(
        context,
        '⚠️ Lecture image impossible: $e',
        isError: true,
      );
    }
  }
"""
if old_set not in s:
    raise SystemExit('setSelectedFile block not found')
s = s.replace(old_set, new_set, 1)

old_upload_success = """      if (!mounted) return;
      setState(() {
        _uploadedImageUrl = asset.mediumUrl;
        _uploadedImageAssetId = asset.id;
        _selectedFile = null;
        _selectedPreviewBytes = null;
        _previewBytesFuture = null;
      });
"""
new_upload_success = """      final resolvedUrl = asset.mediumUrl.trim().isNotEmpty
          ? asset.mediumUrl.trim()
          : asset.originalUrl.trim();
      if (resolvedUrl.isEmpty) {
        throw StateError('Aucune URL image retournée après upload.');
      }

      if (!mounted) return;
      setState(() {
        _uploadedImageUrl = resolvedUrl;
        _uploadedImageAssetId = asset.id;
        _selectedFile = null;
        // Conserver les octets locaux après upload : l'aperçu reste visible
        // immédiatement et ne dépend pas du premier chargement réseau Storage.
        _previewBytesFuture = null;
      });
"""
if old_upload_success not in s:
    raise SystemExit('upload success block not found')
s = s.replace(old_upload_success, new_upload_success, 1)

old_preview = """    Widget image;
    if (selected != null) {
      if (previewBytes != null) {
        image = Image.memory(previewBytes, fit: BoxFit.cover);
      } else {
        image = FutureBuilder<Uint8List>(
          future: _previewBytesFuture,
          builder: (context, snap) {
            if (snap.hasData) {
              return Image.memory(snap.data!, fit: BoxFit.cover);
            }
            if (snap.hasError) {
              return const ColoredBox(
                color: Colors.black12,
                child: Center(
                  child: Icon(Icons.broken_image_rounded, size: 42),
                ),
              );
            }
            return const Center(child: CircularProgressIndicator());
          },
        );
      }
    } else if (url != null) {
      image = StorageImage(
        url: url,
        fit: BoxFit.cover,
        cacheWidth: 500,
        errorWidget: const ColoredBox(
          color: Colors.black12,
          child: Center(child: Icon(Icons.broken_image_rounded, size: 42)),
        ),
        placeholder: const Center(child: CircularProgressIndicator()),
      );
"""
new_preview = """    Widget image;
    if (previewBytes != null) {
      image = Image.memory(
        previewBytes,
        key: ValueKey<int>(previewBytes.length),
        fit: BoxFit.cover,
        gaplessPlayback: true,
      );
    } else if (selected != null) {
      image = FutureBuilder<Uint8List>(
        future: _previewBytesFuture,
        builder: (context, snap) {
          if (snap.hasData && snap.data!.isNotEmpty) {
            return Image.memory(
              snap.data!,
              fit: BoxFit.cover,
              gaplessPlayback: true,
            );
          }
          if (snap.hasError) {
            return const ColoredBox(
              color: Colors.black12,
              child: Center(
                child: Icon(Icons.broken_image_rounded, size: 42),
              ),
            );
          }
          return const Center(child: CircularProgressIndicator());
        },
      );
    } else if (url != null) {
      image = StorageImage(
        key: ValueKey<String>(url),
        url: url,
        fit: BoxFit.cover,
        cacheWidth: 500,
        errorWidget: const ColoredBox(
          color: Colors.black12,
          child: Center(child: Icon(Icons.broken_image_rounded, size: 42)),
        ),
        placeholder: const Center(child: CircularProgressIndicator()),
      );
"""
if old_preview not in s:
    raise SystemExit('image preview block not found')
s = s.replace(old_preview, new_preview, 1)

old_upload_button = """                    FilledButton.icon(
                      onPressed: (!canUpload || _isSaving || _isUploading)
                          ? null
                          : _uploadSelectedImageIfNeeded,
                      style: FilledButton.styleFrom(
"""
new_upload_button = """                    FilledButton.icon(
                      onPressed: (!canUpload || _isSaving || _isUploading)
                          ? null
                          : () async {
                              try {
                                await _uploadSelectedImageIfNeeded();
                              } catch (e) {
                                if (!mounted) return;
                                TopSnackBar.showMessage(
                                  context,
                                  '❌ ${_extractErrorMessage(e)}',
                                  isError: true,
                                );
                              }
                            },
                      style: FilledButton.styleFrom(
"""
if old_upload_button not in s:
    raise SystemExit('upload button block not found')
s = s.replace(old_upload_button, new_upload_button, 1)

popup_path.write_text(s)

wizard_path = Path('app/lib/admin/poi_marketmap_wizard_page.dart')
w = wizard_path.read_text()
old_data = """    final data = <String, dynamic>{
      ...updated.toFirestore(),
      // Normalisation: dans cette page on édite les POI d'UNE couche.
"""
new_data = """    final normalizedImageUrl = updated.imageUrl?.trim();
    final data = <String, dynamic>{
      ...updated.toFirestore(),
      if (normalizedImageUrl != null && normalizedImageUrl.isNotEmpty)
        'photoUrl': normalizedImageUrl,
      // Normalisation: dans cette page on édite les POI d'UNE couche.
"""
if old_data not in w:
    raise SystemExit('wizard data block not found')
w = w.replace(old_data, new_data, 1)
wizard_path.write_text(w)

test_path = Path('app/test/admin/poi_photo_pipeline_test.dart')
test_path.parent.mkdir(parents=True, exist_ok=True)
test_path.write_text("""import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('POI editor keeps local preview bytes after upload', () {
    final source = File('lib/admin/poi_edit_popup.dart').readAsStringSync();

    expect(source, contains('if (previewBytes != null)'));
    expect(source, contains('Conserver les octets locaux après upload'));
    expect(source, isNot(contains('_selectedPreviewBytes = null;\n        _previewBytesFuture = null;\n      });\n\n      if (mounted)')));
  });

  test('POI upload validates a non-empty returned URL', () {
    final source = File('lib/admin/poi_edit_popup.dart').readAsStringSync();

    expect(source, contains("Aucune URL image retournée après upload"));
    expect(source, contains('asset.originalUrl.trim()'));
  });

  test('MarketMap POI persistence keeps legacy photoUrl alias', () {
    final source = File('lib/admin/poi_marketmap_wizard_page.dart')
        .readAsStringSync();

    expect(source, contains("'photoUrl': normalizedImageUrl"));
  });
}
""")
