from pathlib import Path
import re

popup_path = Path('app/lib/admin/poi_edit_popup.dart')
s = popup_path.read_text()

new_set = r'''  Future<void> _setSelectedFile(XFile file) async {
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
'''
s, count = re.subn(
    r'  Future<void> _setSelectedFile\(XFile file\) async \{.*?\n  \}\n\n  Future<void> _showSourcePicker',
    new_set + '\n  Future<void> _showSourcePicker',
    s,
    count=1,
    flags=re.S,
)
if count != 1:
    raise SystemExit(f'setSelectedFile replacement count={count}')

old_upload = r'''      if (!mounted) return;
      setState(() {
        _uploadedImageUrl = asset.mediumUrl;
        _uploadedImageAssetId = asset.id;
        _selectedFile = null;
        _selectedPreviewBytes = null;
        _previewBytesFuture = null;
      });'''
new_upload = r'''      final resolvedUrl = asset.mediumUrl.trim().isNotEmpty
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
      });'''
if old_upload not in s:
    raise SystemExit('upload success block not found')
s = s.replace(old_upload, new_upload, 1)

preview_pattern = re.compile(
    r'    Widget image;\n    if \(selected != null\) \{.*?\n    \} else if \(url != null\) \{\n      image = StorageImage\(\n        url: url,',
    re.S,
)
preview_replacement = r'''    Widget image;
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
        url: url,'''
s, count = preview_pattern.subn(preview_replacement, s, count=1)
if count != 1:
    raise SystemExit(f'image preview replacement count={count}')

old_button = r'''                    FilledButton.icon(
                      onPressed: (!canUpload || _isSaving || _isUploading)
                          ? null
                          : _uploadSelectedImageIfNeeded,
                      style: FilledButton.styleFrom('''
new_button = r'''                    FilledButton.icon(
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
                      style: FilledButton.styleFrom('''
if old_button not in s:
    raise SystemExit('upload button block not found')
s = s.replace(old_button, new_button, 1)
popup_path.write_text(s)

wizard_path = Path('app/lib/admin/poi_marketmap_wizard_page.dart')
w = wizard_path.read_text()
old_data = r'''    final data = <String, dynamic>{
      ...updated.toFirestore(),
      // Normalisation: dans cette page on édite les POI d'UNE couche.'''
new_data = r'''    final normalizedImageUrl = updated.imageUrl?.trim();
    final data = <String, dynamic>{
      ...updated.toFirestore(),
      if (normalizedImageUrl != null && normalizedImageUrl.isNotEmpty)
        'photoUrl': normalizedImageUrl,
      // Normalisation: dans cette page on édite les POI d'UNE couche.'''
if old_data not in w:
    raise SystemExit('wizard data block not found')
w = w.replace(old_data, new_data, 1)
wizard_path.write_text(w)

test_path = Path('app/test/admin/poi_photo_pipeline_test.dart')
test_path.parent.mkdir(parents=True, exist_ok=True)
test_path.write_text(r'''import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('POI editor keeps local preview bytes after upload', () {
    final source = File('lib/admin/poi_edit_popup.dart').readAsStringSync();

    expect(source, contains('if (previewBytes != null)'));
    expect(source, contains('Conserver les octets locaux après upload'));
  });

  test('POI upload validates a non-empty returned URL', () {
    final source = File('lib/admin/poi_edit_popup.dart').readAsStringSync();

    expect(source, contains('Aucune URL image retournée après upload'));
    expect(source, contains('asset.originalUrl.trim()'));
  });

  test('MarketMap POI persistence keeps legacy photoUrl alias', () {
    final source = File('lib/admin/poi_marketmap_wizard_page.dart')
        .readAsStringSync();

    expect(source, contains("'photoUrl': normalizedImageUrl"));
  });
}
''')
