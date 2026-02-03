import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import '../../models/commerce_submission.dart';
import '../../services/commerce/commerce_service.dart';

/// Page de création/édition d'un produit
class CreateProductPage extends StatefulWidget {
  final String? submissionId; // null = création, non-null = édition

  const CreateProductPage({super.key, this.submissionId});

  @override
  State<CreateProductPage> createState() => _CreateProductPageState();
}

class _CreateProductPageState extends State<CreateProductPage> {
  final _formKey = GlobalKey<FormState>();
  final _service = CommerceService.instance;
  final _picker = ImagePicker();

  bool _isLoading = false;
  bool _isEditing = false;
  CommerceSubmission? _existing;

  // Champs du formulaire
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _stockController = TextEditingController();

  ScopeType _selectedScopeType = ScopeType.global;
  String _scopeId = '';
  String _currency = 'EUR';
  bool _isActive = true;

  List<String> _mediaUrls = [];
  List<XFile> _selectedFiles = [];
  double _uploadProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _isEditing = widget.submissionId != null;
    if (_isEditing) {
      _loadSubmission();
    }
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
          _priceController.text = submission.price?.toString() ?? '0';
          _stockController.text = submission.stock?.toString() ?? '0';
          _selectedScopeType = submission.scopeType;
          _scopeId = submission.scopeId;
          _currency = submission.currency ?? 'EUR';
          _isActive = submission.isActive ?? true;
          _mediaUrls = List.from(submission.mediaUrls);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur de chargement: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImages() async {
    try {
      final files = await _picker.pickMultiImage(imageQuality: 88);
      if (files.isNotEmpty && mounted) {
        setState(() {
          _selectedFiles.addAll(files);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur sélection: $e')),
      );
    }
  }

  void _removeFile(int index) {
    setState(() {
      _selectedFiles.removeAt(index);
    });
  }

  void _removeUrl(int index) {
    setState(() {
      _mediaUrls.removeAt(index);
    });
  }

  Future<void> _saveDraft() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final role = await _service.getCurrentUserRole();
      if (role == null) {
        throw Exception('Vous n\'avez pas les permissions nécessaires');
      }

      // Upload des nouveaux fichiers
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
              onProgress: (progress) {
                setState(() => _uploadProgress = progress);
              },
            );
            _mediaUrls.add(url);
          }
        } else {
          final files = _selectedFiles.map((xf) => File(xf.path)).toList();
          final urls = await _service.uploadMediaFiles(
            scopeId: _scopeId.isEmpty ? 'global' : _scopeId,
            submissionId: submissionId,
            files: files,
            onProgress: (progress) {
              setState(() => _uploadProgress = progress);
            },
          );
          _mediaUrls.addAll(urls);
        }
        _selectedFiles.clear();
      }

      if (_isEditing && _existing != null) {
        // Mise à jour
        await _service.updateSubmission(_existing!.id, {
          'title': _titleController.text.trim(),
          'description': _descriptionController.text.trim(),
          'price': double.tryParse(_priceController.text) ?? 0.0,
          'stock': int.tryParse(_stockController.text) ?? 0,
          'currency': _currency,
          'isActive': _isActive,
          'mediaUrls': _mediaUrls,
          'scopeType': _selectedScopeType.toJson(),
          'scopeId': _scopeId.isEmpty ? 'global' : _scopeId,
        });
      } else {
        // Création
        await _service.createDraftSubmission(
          type: SubmissionType.product,
          ownerRole: role,
          scopeType: _selectedScopeType,
          scopeId: _scopeId.isEmpty ? 'global' : _scopeId,
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          mediaUrls: _mediaUrls,
          price: double.tryParse(_priceController.text) ?? 0.0,
          stock: int.tryParse(_stockController.text) ?? 0,
          currency: _currency,
          isActive: _isActive,
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
          SnackBar(content: Text('❌ Erreur: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _submitForReview() async {
    if (!_formKey.currentState!.validate()) return;

    // Vérifications supplémentaires
    if (_mediaUrls.isEmpty && _selectedFiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ajoutez au moins une image')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final role = await _service.getCurrentUserRole();
      if (role == null) {
        throw Exception('Vous n\'avez pas les permissions nécessaires');
      }

      // Upload des fichiers
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
              onProgress: (progress) {
                setState(() => _uploadProgress = progress);
              },
            );
            _mediaUrls.add(url);
          }
        } else {
          final files = _selectedFiles.map((xf) => File(xf.path)).toList();
          final urls = await _service.uploadMediaFiles(
            scopeId: _scopeId.isEmpty ? 'global' : _scopeId,
            submissionId: submissionId,
            files: files,
            onProgress: (progress) {
              setState(() => _uploadProgress = progress);
            },
          );
          _mediaUrls.addAll(urls);
        }
        _selectedFiles.clear();
      }

      String submissionId;

      if (_isEditing && _existing != null) {
        // Mise à jour puis soumission
        await _service.updateSubmission(_existing!.id, {
          'title': _titleController.text.trim(),
          'description': _descriptionController.text.trim(),
          'price': double.tryParse(_priceController.text) ?? 0.0,
          'stock': int.tryParse(_stockController.text) ?? 0,
          'currency': _currency,
          'isActive': _isActive,
          'mediaUrls': _mediaUrls,
          'scopeType': _selectedScopeType.toJson(),
          'scopeId': _scopeId.isEmpty ? 'global' : _scopeId,
        });
        submissionId = _existing!.id;
      } else {
        // Création
        submissionId = await _service.createDraftSubmission(
          type: SubmissionType.product,
          ownerRole: role,
          scopeType: _selectedScopeType,
          scopeId: _scopeId.isEmpty ? 'global' : _scopeId,
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          mediaUrls: _mediaUrls,
          price: double.tryParse(_priceController.text) ?? 0.0,
          stock: int.tryParse(_stockController.text) ?? 0,
          currency: _currency,
          isActive: _isActive,
        );
      }

      // Soumettre pour validation
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
          SnackBar(content: Text('❌ Erreur: $e')),
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
    _priceController.dispose();
    _stockController.dispose();
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
          _isEditing ? 'Modifier le produit' : 'Nouveau produit',
          style: const TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
          ),
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
                          // Titre
                          TextFormField(
                            controller: _titleController,
                            decoration: InputDecoration(
                              labelText: 'Titre du produit *',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                            ),
                            validator: (v) => v == null || v.trim().isEmpty
                                ? 'Titre obligatoire'
                                : null,
                          ),
                          const SizedBox(height: 16),

                          // Description
                          TextFormField(
                            controller: _descriptionController,
                            maxLines: 4,
                            decoration: InputDecoration(
                              labelText: 'Description *',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                            ),
                            validator: (v) => v == null || v.trim().isEmpty
                                ? 'Description obligatoire'
                                : null,
                          ),
                          const SizedBox(height: 16),

                          // Prix et Stock
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _priceController,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    labelText: 'Prix ($_currency) *',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    filled: true,
                                    fillColor: Colors.grey.shade50,
                                  ),
                                  validator: (v) {
                                    if (v == null || v.trim().isEmpty) {
                                      return 'Prix obligatoire';
                                    }
                                    if (double.tryParse(v) == null) {
                                      return 'Prix invalide';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: TextFormField(
                                  controller: _stockController,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    labelText: 'Stock *',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    filled: true,
                                    fillColor: Colors.grey.shade50,
                                  ),
                                  validator: (v) {
                                    if (v == null || v.trim().isEmpty) {
                                      return 'Stock obligatoire';
                                    }
                                    if (int.tryParse(v) == null) {
                                      return 'Stock invalide';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Scope
                          DropdownButtonFormField<ScopeType>(
                            value: _selectedScopeType,
                            decoration: InputDecoration(
                              labelText: 'Portée',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                            ),
                            items: ScopeType.values.map((type) {
                              return DropdownMenuItem(
                                value: type,
                                child: Text(type.name),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _selectedScopeType = val);
                              }
                            },
                          ),
                          const SizedBox(height: 16),

                          // Scope ID
                          TextFormField(
                            initialValue: _scopeId,
                            decoration: InputDecoration(
                              labelText: 'Scope ID (optionnel)',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                            ),
                            onChanged: (val) => _scopeId = val.trim(),
                          ),
                          const SizedBox(height: 16),

                          // Actif
                          SwitchListTile(
                            title: const Text('Produit actif'),
                            value: _isActive,
                            onChanged: (val) => setState(() => _isActive = val),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Images existantes
                          if (_mediaUrls.isNotEmpty) ...[
                            const Text(
                              'Images actuelles',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _mediaUrls.asMap().entries.map((entry) {
                                final idx = entry.key;
                                final url = entry.value;
                                return Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: Image.network(
                                        url,
                                        width: 100,
                                        height: 100,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                    Positioned(
                                      top: 4,
                                      right: 4,
                                      child: IconButton(
                                        icon: const Icon(Icons.close,
                                            color: Colors.white),
                                        style: IconButton.styleFrom(
                                          backgroundColor: Colors.black54,
                                        ),
                                        onPressed: () => _removeUrl(idx),
                                      ),
                                    ),
                                  ],
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 16),
                          ],

                          // Nouvelles images
                          if (_selectedFiles.isNotEmpty) ...[
                            const Text(
                              'Nouvelles images',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _selectedFiles.asMap().entries.map((entry) {
                                final idx = entry.key;
                                final file = entry.value;
                                return Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: kIsWeb
                                          ? FutureBuilder<List<int>>(
                                              future: file.readAsBytes(),
                                              builder: (context, snapshot) {
                                                if (snapshot.hasData) {
                                                  return Image.memory(
                                                  Uint8List.fromList(snapshot.data!),
                                                    width: 100,
                                                    height: 100,
                                                    fit: BoxFit.cover,
                                                  );
                                                }
                                                return const SizedBox(
                                                  width: 100,
                                                  height: 100,
                                                  child: Center(
                                                    child: CircularProgressIndicator(),
                                                  ),
                                                );
                                              },
                                            )
                                          : Image.file(
                                              File(file.path),
                                              width: 100,
                                              height: 100,
                                              fit: BoxFit.cover,
                                            ),
                                    ),
                                    Positioned(
                                      top: 4,
                                      right: 4,
                                      child: IconButton(
                                        icon: const Icon(Icons.close,
                                            color: Colors.white),
                                        style: IconButton.styleFrom(
                                          backgroundColor: Colors.black54,
                                        ),
                                        onPressed: () => _removeFile(idx),
                                      ),
                                    ),
                                  ],
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 16),
                          ],

                          // Bouton ajouter images
                          ElevatedButton.icon(
                            onPressed: _isLoading ? null : _pickImages,
                            icon: const Icon(Icons.add_photo_alternate),
                            label: const Text('Ajouter des images'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.all(16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Progress bar
                          if (_isLoading && _uploadProgress > 0) ...[
                            LinearProgressIndicator(value: _uploadProgress),
                            const SizedBox(height: 8),
                            Text(
                              'Upload: ${(_uploadProgress * 100).toInt()}%',
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                          ],

                          // Boutons d'action
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: _isLoading ? null : _saveDraft,
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.all(16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
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
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: _isLoading
                                      ? const SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
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
