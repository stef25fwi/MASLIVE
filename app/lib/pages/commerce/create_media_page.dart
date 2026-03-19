import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';

import '../../models/commerce_submission.dart';
import '../../models/market_circuit.dart';
import '../../models/market_country.dart';
import '../../models/market_event.dart';
import '../../services/commerce/commerce_service.dart';
import '../../ui/widgets/marketmap_poi_selector_sheet.dart';

/// Page de création/édition d'un média
class CreateMediaPage extends StatefulWidget {
  final String? submissionId;

  const CreateMediaPage({super.key, this.submissionId});

  @override
  State<CreateMediaPage> createState() => _CreateMediaPageState();
}

class _CreateMediaPageState extends State<CreateMediaPage> {
  final _formKey = GlobalKey<FormState>();
  final _service = CommerceService.instance;
  final _picker = ImagePicker();

  bool _isLoading = false;
  bool _isEditing = false;
  bool _showMarketScopeError = false;
  CommerceSubmission? _existing;

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _photographerController = TextEditingController();
  final _countryController = TextEditingController();
  final _eventController = TextEditingController();
  final _circuitController = TextEditingController();

  ScopeType _selectedScopeType = ScopeType.global;
  String _scopeId = '';
  MediaType _mediaType = MediaType.photo;
  String? _countryId;
  String? _countryName;
  String? _eventId;
  String? _eventName;
  String? _circuitId;
  String? _circuitName;

  List<String> _mediaUrls = [];
  final List<XFile> _selectedFiles = [];
  double _uploadProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _isEditing = widget.submissionId != null;
    if (_isEditing) _loadSubmission();
  }

  Future<void> _loadSubmission() async {
    setState(() => _isLoading = true);
    try {
      final submission = await _service.getSubmission(widget.submissionId!);
      if (submission != null && mounted) {
        setState(() {
          _existing = submission;
          _titleController.text = submission.title;
          _descriptionController.text = submission.description;
          _photographerController.text = submission.photographer ?? '';
          _selectedScopeType = submission.scopeType;
          _scopeId = submission.scopeId;
          _mediaType = submission.mediaType ?? MediaType.photo;
          _mediaUrls = List.from(submission.mediaUrls);
          _countryId = submission.countryId;
          _countryName = submission.countryName;
          _eventId = submission.eventId;
          _eventName = submission.eventName;
          _circuitId = submission.circuitId;
          _circuitName = submission.circuitName;
          _countryController.text = submission.countryName ?? submission.countryId ?? '';
          _eventController.text = submission.eventName ?? submission.eventId ?? '';
          _circuitController.text = submission.circuitName ?? submission.circuitId ?? '';
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImages() async {
    try {
      final files = await _picker.pickMultiImage(imageQuality: 88);
      if (!mounted) return;

      if (files.isNotEmpty) {
        setState(() => _selectedFiles.addAll(files));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    }
  }

  void _removeFile(int index) => setState(() => _selectedFiles.removeAt(index));
  void _removeUrl(int index) => setState(() => _mediaUrls.removeAt(index));

  MarketMapPoiSelection? _buildInitialSelection() {
    final resolvedCountryId = _countryId?.trim();
    final resolvedEventId = _eventId?.trim();
    final resolvedCircuitId = _circuitId?.trim();
    if (resolvedCountryId == null ||
        resolvedCountryId.isEmpty ||
        resolvedEventId == null ||
        resolvedEventId.isEmpty ||
        resolvedCircuitId == null ||
        resolvedCircuitId.isEmpty) {
      return null;
    }

    return MarketMapPoiSelection.enabled(
      country: MarketCountry(
        id: resolvedCountryId,
        name: (_countryName?.trim().isNotEmpty == true)
            ? _countryName!.trim()
            : resolvedCountryId,
        slug: resolvedCountryId,
      ),
      event: MarketEvent(
        id: resolvedEventId,
        countryId: resolvedCountryId,
        name: (_eventName?.trim().isNotEmpty == true)
            ? _eventName!.trim()
            : resolvedEventId,
        slug: resolvedEventId,
      ),
      circuit: MarketCircuit(
        id: resolvedCircuitId,
        countryId: resolvedCountryId,
        eventId: resolvedEventId,
        name: (_circuitName?.trim().isNotEmpty == true)
            ? _circuitName!.trim()
            : resolvedCircuitId,
        slug: resolvedCircuitId,
        status: 'draft',
        createdByUid: '',
        perimeterLocked: false,
        zoomLocked: false,
        center: const <String, double>{'lat': 0.0, 'lng': 0.0},
        initialZoom: 14,
        isVisible: true,
        wizardState: const <String, dynamic>{},
      ),
      layerIds: const <String>{},
    );
  }

  Future<void> _selectMarketScope() async {
    final selection = await showMarketMapCircuitSelectorSheet(
      context,
      initial: _buildInitialSelection(),
      disableKeyboardInput: true,
    );
    if (!mounted || selection == null) return;

    if (!selection.enabled ||
        selection.country == null ||
        selection.event == null ||
        selection.circuit == null) {
      setState(() {
        _countryId = null;
        _countryName = null;
        _eventId = null;
        _eventName = null;
        _circuitId = null;
        _circuitName = null;
        _countryController.clear();
        _eventController.clear();
        _circuitController.clear();
      });
      return;
    }

    setState(() {
      _showMarketScopeError = false;
      _countryId = selection.country!.id;
      _countryName = selection.country!.name;
      _eventId = selection.event!.id;
      _eventName = selection.event!.name;
      _circuitId = selection.circuit!.id;
      _circuitName = selection.circuit!.name;
      _countryController.text = selection.country!.name;
      _eventController.text = selection.event!.name;
      _circuitController.text = selection.circuit!.name;
    });
  }

  bool get _hasRequiredMarketScope =>
      (_countryId?.trim().isNotEmpty ?? false) &&
      (_eventId?.trim().isNotEmpty ?? false) &&
      (_circuitId?.trim().isNotEmpty ?? false);

  String? _marketScopeError() {
    if (_hasRequiredMarketScope) return null;
    return 'Pays, evenement et circuit sont obligatoires';
  }

  Future<void> _saveDraft() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final role = await _service.getCurrentUserRole();
      if (role == null) throw Exception('Permissions insuffisantes');

      // Upload
      if (_selectedFiles.isNotEmpty) {
        String submissionId = _existing?.id ?? 'temp_${DateTime.now().millisecondsSinceEpoch}';

        if (kIsWeb) {
          for (final file in _selectedFiles) {
            final bytes = await file.readAsBytes();
            final url = await _service.uploadMediaBytes(
              scopeId: _scopeId.isEmpty ? 'global' : _scopeId,
              submissionId: submissionId,
              bytes: bytes,
              filename: file.name,
              onProgress: (p) => setState(() => _uploadProgress = p),
            );
            _mediaUrls.add(url);
          }
        } else {
          final files = _selectedFiles.map((xf) => File(xf.path)).toList();
          final urls = await _service.uploadMediaFiles(
            scopeId: _scopeId.isEmpty ? 'global' : _scopeId,
            submissionId: submissionId,
            files: files,
            onProgress: (p) => setState(() => _uploadProgress = p),
          );
          _mediaUrls.addAll(urls);
        }
        _selectedFiles.clear();
      }

      if (_isEditing && _existing != null) {
        await _service.updateSubmission(_existing!.id, {
          'title': _titleController.text.trim(),
          'description': _descriptionController.text.trim(),
          'photographer': _photographerController.text.trim(),
          'mediaType': _mediaType.toJson(),
          'mediaUrls': _mediaUrls,
          'scopeType': _selectedScopeType.toJson(),
          'scopeId': _scopeId.isEmpty ? 'global' : _scopeId,
          'countryId': _countryId,
          'countryName': _countryName,
          'eventId': _eventId,
          'eventName': _eventName,
          'circuitId': _circuitId,
          'circuitName': _circuitName,
        });
      } else {
        await _service.createDraftSubmission(
          type: SubmissionType.media,
          ownerRole: role,
          scopeType: _selectedScopeType,
          scopeId: _scopeId.isEmpty ? 'global' : _scopeId,
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          mediaUrls: _mediaUrls,
          mediaType: _mediaType,
          photographer: _photographerController.text.trim(),
          countryId: _countryId,
          countryName: _countryName,
          eventId: _eventId,
          eventName: _eventName,
          circuitId: _circuitId,
          circuitName: _circuitName,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Brouillon enregistré')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _submitForReview() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _showMarketScopeError = true);
    final marketScopeError = _marketScopeError();
    if (marketScopeError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(marketScopeError)),
      );
      return;
    }

    if (_mediaUrls.isEmpty && _selectedFiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ajoutez au moins un média')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final role = await _service.getCurrentUserRole();
      if (role == null) throw Exception('Permissions insuffisantes');

      // Upload
      if (_selectedFiles.isNotEmpty) {
        String submissionId = _existing?.id ?? 'temp_${DateTime.now().millisecondsSinceEpoch}';

        if (kIsWeb) {
          for (final file in _selectedFiles) {
            final bytes = await file.readAsBytes();
            final url = await _service.uploadMediaBytes(
              scopeId: _scopeId.isEmpty ? 'global' : _scopeId,
              submissionId: submissionId,
              bytes: bytes,
              filename: file.name,
              onProgress: (p) => setState(() => _uploadProgress = p),
            );
            _mediaUrls.add(url);
          }
        } else {
          final files = _selectedFiles.map((xf) => File(xf.path)).toList();
          final urls = await _service.uploadMediaFiles(
            scopeId: _scopeId.isEmpty ? 'global' : _scopeId,
            submissionId: submissionId,
            files: files,
            onProgress: (p) => setState(() => _uploadProgress = p),
          );
          _mediaUrls.addAll(urls);
        }
        _selectedFiles.clear();
      }

      String submissionId;

      if (_isEditing && _existing != null) {
        await _service.updateSubmission(_existing!.id, {
          'title': _titleController.text.trim(),
          'description': _descriptionController.text.trim(),
          'photographer': _photographerController.text.trim(),
          'mediaType': _mediaType.toJson(),
          'mediaUrls': _mediaUrls,
          'scopeType': _selectedScopeType.toJson(),
          'scopeId': _scopeId.isEmpty ? 'global' : _scopeId,
          'countryId': _countryId,
          'countryName': _countryName,
          'eventId': _eventId,
          'eventName': _eventName,
          'circuitId': _circuitId,
          'circuitName': _circuitName,
        });
        submissionId = _existing!.id;
      } else {
        submissionId = await _service.createDraftSubmission(
          type: SubmissionType.media,
          ownerRole: role,
          scopeType: _selectedScopeType,
          scopeId: _scopeId.isEmpty ? 'global' : _scopeId,
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          mediaUrls: _mediaUrls,
          mediaType: _mediaType,
          photographer: _photographerController.text.trim(),
          countryId: _countryId,
          countryName: _countryName,
          eventId: _eventId,
          eventName: _eventName,
          circuitId: _circuitId,
          circuitName: _circuitName,
        );
      }

      await _service.submitForReview(submissionId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Soumis pour validation')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _photographerController.dispose();
    _countryController.dispose();
    _eventController.dispose();
    _circuitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          _isEditing ? 'Modifier le média' : 'Nouveau média',
          style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: _isLoading && _existing == null
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
              builder: (context, constraints) {
                final maxWidth = constraints.maxWidth > 900 ? 900.0 : constraints.maxWidth;
                return Center(
                  child: Container(
                    constraints: BoxConstraints(maxWidth: maxWidth),
                    child: Form(
                      key: _formKey,
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          TextFormField(
                            controller: _titleController,
                            decoration: InputDecoration(
                              labelText: 'Titre *',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                            ),
                            validator: (v) => v == null || v.trim().isEmpty ? 'Titre obligatoire' : null,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _descriptionController,
                            maxLines: 4,
                            decoration: InputDecoration(
                              labelText: 'Description *',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                            ),
                            validator: (v) => v == null || v.trim().isEmpty ? 'Description obligatoire' : null,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _photographerController,
                            decoration: InputDecoration(
                              labelText: 'Photographe',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _MarketScopeField(
                            label: 'PAYS *',
                            controller: _countryController,
                            onTap: _selectMarketScope,
                          ),
                          const SizedBox(height: 16),
                          _MarketScopeField(
                            label: 'EVENEMENT *',
                            controller: _eventController,
                            onTap: _selectMarketScope,
                          ),
                          const SizedBox(height: 16),
                          _MarketScopeField(
                            label: 'CIRCUIT *',
                            controller: _circuitController,
                            onTap: _selectMarketScope,
                            errorText: _showMarketScopeError ? _marketScopeError() : null,
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<MediaType>(
                            initialValue: _mediaType,
                            decoration: InputDecoration(
                              labelText: 'Type de média',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                            ),
                            items: MediaType.values.map((type) {
                              return DropdownMenuItem(value: type, child: Text(type.name));
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => _mediaType = val);
                            },
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<ScopeType>(
                            initialValue: _selectedScopeType,
                            decoration: InputDecoration(
                              labelText: 'Portée',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                            ),
                            items: ScopeType.values.map((type) {
                              return DropdownMenuItem(value: type, child: Text(type.name));
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => _selectedScopeType = val);
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            initialValue: _scopeId,
                            decoration: InputDecoration(
                              labelText: 'Scope ID (optionnel)',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                            ),
                            onChanged: (val) => _scopeId = val.trim(),
                          ),
                          const SizedBox(height: 24),
                          if (_mediaUrls.isNotEmpty) ...[
                            const Text('Médias actuels', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _mediaUrls.asMap().entries.map((entry) {
                                return Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: Image.network(entry.value, width: 100, height: 100, fit: BoxFit.cover),
                                    ),
                                    Positioned(
                                      top: 4,
                                      right: 4,
                                      child: IconButton(
                                        icon: const Icon(Icons.close, color: Colors.white),
                                        style: IconButton.styleFrom(backgroundColor: Colors.black54),
                                        onPressed: () => _removeUrl(entry.key),
                                      ),
                                    ),
                                  ],
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 16),
                          ],
                          if (_selectedFiles.isNotEmpty) ...[
                            const Text('Nouveaux médias', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _selectedFiles.asMap().entries.map((entry) {
                                return Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: kIsWeb
                                          ? FutureBuilder<List<int>>(
                                              future: entry.value.readAsBytes(),
                                              builder: (context, snapshot) {
                                                if (snapshot.hasData) {
                                                return Image.memory(Uint8List.fromList(snapshot.data!), width: 100, height: 100, fit: BoxFit.cover);
                                                }
                                                return const SizedBox(width: 100, height: 100, child: Center(child: CircularProgressIndicator()));
                                              },
                                            )
                                          : Image.file(File(entry.value.path), width: 100, height: 100, fit: BoxFit.cover),
                                    ),
                                    Positioned(
                                      top: 4,
                                      right: 4,
                                      child: IconButton(
                                        icon: const Icon(Icons.close, color: Colors.white),
                                        style: IconButton.styleFrom(backgroundColor: Colors.black54),
                                        onPressed: () => _removeFile(entry.key),
                                      ),
                                    ),
                                  ],
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 16),
                          ],
                          ElevatedButton.icon(
                            onPressed: _isLoading ? null : _pickImages,
                            icon: const Icon(Icons.add_photo_alternate),
                            label: const Text('Ajouter des médias'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.all(16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (_isLoading && _uploadProgress > 0) ...[
                            LinearProgressIndicator(value: _uploadProgress),
                            const SizedBox(height: 8),
                            Text('Upload: ${(_uploadProgress * 100).toInt()}%', textAlign: TextAlign.center),
                            const SizedBox(height: 16),
                          ],
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: _isLoading ? null : _saveDraft,
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.all(16),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  child: const Text('Enregistrer brouillon'),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _submitForReview,
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.all(16),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  child: _isLoading
                                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                      : const Text('Soumettre'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class _MarketScopeField extends StatelessWidget {
  const _MarketScopeField({
    required this.label,
    required this.controller,
    required this.onTap,
    this.errorText,
  });

  final String label;
  final TextEditingController controller;
  final VoidCallback onTap;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      readOnly: true,
      onTap: onTap,
      decoration: InputDecoration(
        labelText: label,
        hintText: 'Choisir via le menu Carte',
        errorText: errorText,
        suffixIcon: const Icon(Icons.keyboard_arrow_down_rounded),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.grey.shade50,
      ),
    );
  }
}
