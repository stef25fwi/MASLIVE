import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../models/commerce_submission.dart';
import '../../services/commerce/commerce_service.dart';
import '../../ui/widgets/rainbow_loading_indicator.dart';

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
  late ImagePicker _picker;

  bool _isLoading = false;
  bool _isPickerBusy = false;
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
  final List<XFile> _selectedFiles = [];
  double _uploadProgress = 0.0;

  String _normalizeTitle(String input) {
    final cleaned = input.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (cleaned.isEmpty) return cleaned;
    return cleaned[0].toUpperCase() + cleaned.substring(1);
  }

  String _normalizeDescription(String input) {
    final lines = input.split('\n');
    return lines
        .map((line) => line.replaceAll(RegExp(r'[ \t]{2,}'), ' ').trimRight())
        .join('\n');
  }

  String _normalizePriceInput(String input) {
    final cleaned = input
        .replaceAll(',', '.')
        .replaceAll(RegExp(r'[^0-9.]'), '');
    final parts = cleaned.split('.');
    if (parts.length <= 1) return cleaned;
    return '${parts[0]}.${parts.sublist(1).join('')}';
  }

  String _normalizeStockInput(String input) {
    return input.replaceAll(RegExp(r'[^0-9]'), '');
  }

  void _setControllerValue(TextEditingController controller, String text) {
    controller.value = controller.value.copyWith(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
      composing: TextRange.empty,
    );
  }

  double? _parsePrice() {
    final normalized = _normalizePriceInput(_priceController.text);
    if (normalized.isEmpty) return null;
    return double.tryParse(normalized);
  }

  int? _parseStock() {
    final normalized = _normalizeStockInput(_stockController.text);
    if (normalized.isEmpty) return null;
    return int.tryParse(normalized);
  }

  void _normalizeInputs() {
    final title = _normalizeTitle(_titleController.text);
    if (title != _titleController.text) {
      _setControllerValue(_titleController, title);
    }

    final description = _normalizeDescription(_descriptionController.text);
    if (description != _descriptionController.text) {
      _setControllerValue(_descriptionController, description);
    }

    final price = _normalizePriceInput(_priceController.text);
    if (price != _priceController.text) {
      _setControllerValue(_priceController, price);
    }

    final stock = _normalizeStockInput(_stockController.text);
    if (stock != _stockController.text) {
      _setControllerValue(_stockController, stock);
    }
  }

  @override
  void initState() {
    super.initState();
    _picker = ImagePicker();
    _isEditing = widget.submissionId != null;
    if (_isEditing) {
      _loadSubmission();
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

  Future<bool> _checkGalleryPermission() async {
    debugPrint('🔐 Vérification permission galerie...');
    try {
      if (kIsWeb) {
        debugPrint('✅ Permission galerie: N/A sur web');
        return true;
      }

      if (Platform.isAndroid) {
        // Android 13+ a besoin de READ_MEDIA_IMAGES
        PermissionStatus status = await Permission.photos.request();
        debugPrint('📱 Android - Permission photos: $status');
        return status.isGranted;
      } else if (Platform.isIOS) {
        PermissionStatus status = await Permission.photos.request();
        debugPrint('📱 iOS - Permission photos: $status');
        return status.isGranted;
      }

      return true;
    } catch (e) {
      debugPrint('⚠️  Erreur vérification permission: $e');
      return false;
    }
  }

  Future<bool> _checkCameraPermission() async {
    debugPrint('🔐 Vérification permission caméra...');
    try {
      if (kIsWeb) return true;

      PermissionStatus status = await Permission.camera.request();
      debugPrint('📷 Permission caméra: $status');
      return status.isGranted;
    } catch (e) {
      debugPrint('⚠️  Erreur vérification caméra: $e');
      return false;
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

  Future<void> _pickFromGallery() async {
    if (_isPickerBusy) {
      debugPrint('⚠️  Sélection en cours, attendez...');
      return;
    }

    setState(() => _isPickerBusy = true);

    try {
      debugPrint('📸 Début sélection images...');

      // Vérifier les permissions
      final hasPermission = await _checkGalleryPermission();
      if (!hasPermission) {
        debugPrint('❌ Permission galerie refusée');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                '❌ Permission galerie refusée. Vérifiez les paramètres.'
              ),
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      // Réinitialiser le picker pour éviter les problèmes de cache
      _picker = ImagePicker();

      debugPrint('🎬 Ouverture galerie...');
      final files = await _picker.pickMultiImage(
        imageQuality: 88,
      ).timeout(
        const Duration(seconds: 60),
        onTimeout: () {
          debugPrint('⏱️  Timeout sélection galerie');
          return [];
        },
      );

      debugPrint('📸 ${files.length} images sélectionnées');

      if (!mounted) return;

      if (files.isNotEmpty) {
        setState(() {
          _selectedFiles.addAll(files);
        });
        debugPrint('✅ Images ajoutées: ${_selectedFiles.length} total');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ ${files.length} image(s) ajoutée(s)'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        debugPrint('ℹ️  Aucune image sélectionnée (annulation utilisateur)');
      }
    } on PlatformException catch (e) {
      debugPrint('❌ Erreur plateforme galerie: ${e.code} - ${e.message}');
      if (mounted) {
        String errorMsg = 'Erreur galerie';
        if (e.code == 'photo_access_denied') {
          errorMsg = '❌ Accès à la galerie refusé';
        } else if (e.code == 'photo_access_limited') {
          errorMsg = '⚠️  Accès limité à la galerie';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Erreur sélection galerie: $e (${e.runtimeType})');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erreur: ${e.toString().substring(0, 50)}...'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isPickerBusy = false);
      }
    }
  }

  Future<void> _pickFromCamera() async {
    if (kIsWeb) return;
    if (_isPickerBusy) {
      debugPrint('⚠️  Sélection en cours, attendez...');
      return;
    }

    setState(() => _isPickerBusy = true);

    try {
      debugPrint('📷 Ouverture caméra...');

      // Vérifier les permissions
      final hasPermission = await _checkCameraPermission();
      if (!hasPermission) {
        debugPrint('❌ Permission caméra refusée');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                '❌ Permission caméra refusée. Vérifiez les paramètres.'
              ),
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      // Réinitialiser le picker
      _picker = ImagePicker();

      final file = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 88,
        preferredCameraDevice: CameraDevice.rear,
      ).timeout(
        const Duration(seconds: 60),
        onTimeout: () {
          debugPrint('⏱️  Timeout sélection caméra');
          return null;
        },
      );

      if (!mounted) return;

      if (file != null) {
        setState(() {
          _selectedFiles.add(file);
        });
        debugPrint('✅ Photo ajoutée: ${_selectedFiles.length} total');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Photo ajoutée'),
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        debugPrint('ℹ️  Aucune photo prise (annulation utilisateur)');
      }
    } on PlatformException catch (e) {
      debugPrint('❌ Erreur plateforme caméra: ${e.code} - ${e.message}');
      if (mounted) {
        String errorMsg = 'Erreur caméra';
        if (e.code == 'camera_access_denied') {
          errorMsg = '❌ Accès à la caméra refusé';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Erreur caméra: $e (${e.runtimeType})');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erreur: ${e.toString().substring(0, 50)}...'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isPickerBusy = false);
      }
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

    _normalizeInputs();

    setState(() => _isLoading = true);

    try {
      final role = await _service.getCurrentUserRole();
      if (role == null) {
        throw Exception('Vous n\'avez pas les permissions nécessaires');
      }

      // Upload des nouveaux fichiers
      if (_selectedFiles.isNotEmpty) {
        debugPrint('📤 Début upload de ${_selectedFiles.length} fichiers...');
        String submissionId = _existing?.id ?? 'temp_${DateTime.now().millisecondsSinceEpoch}';
        debugPrint('📤 SubmissionId: $submissionId, ScopeId: ${_scopeId.isEmpty ? "global" : _scopeId}');

        if (kIsWeb) {
          debugPrint('📤 Mode WEB détecté');
          for (int i = 0; i < _selectedFiles.length; i++) {
            final file = _selectedFiles[i];
            debugPrint('📤 Upload fichier ${i + 1}/${_selectedFiles.length}: ${file.name}');
            try {
              final bytes = await file.readAsBytes();
              debugPrint('📤 Bytes lus: ${bytes.length}');
              
              final url = await _service.uploadMediaBytes(
                scopeId: _scopeId.isEmpty ? 'global' : _scopeId,
                submissionId: submissionId,
                bytes: bytes,
                filename: file.name,
                onProgress: (progress) {
                  debugPrint('📤 Progression: ${(progress * 100).toStringAsFixed(0)}%');
                  setState(() => _uploadProgress = progress);
                },
              );
              debugPrint('✅ Upload réussi: $url');
              _mediaUrls.add(url);
            } catch (e) {
              debugPrint('❌ Erreur upload fichier ${i + 1}: $e');
              throw Exception('Échec upload fichier ${file.name}: $e');
            }
          }
        } else {
          debugPrint('📤 Mode MOBILE détecté');
          try {
            final files = _selectedFiles.map((xf) => File(xf.path)).toList();
            final urls = await _service.uploadMediaFiles(
              scopeId: _scopeId.isEmpty ? 'global' : _scopeId,
              submissionId: submissionId,
              files: files,
              onProgress: (progress) {
                debugPrint('📤 Progression globale: ${(progress * 100).toStringAsFixed(0)}%');
                setState(() => _uploadProgress = progress);
              },
            );
            debugPrint('✅ Upload de ${urls.length} fichiers réussi');
            _mediaUrls.addAll(urls);
          } catch (e) {
            debugPrint('❌ Erreur upload mobile: $e');
            throw Exception('Échec upload: $e');
          }
        }
        _selectedFiles.clear();
        debugPrint('✅ Upload terminé, URLs totales: ${_mediaUrls.length}');
      }

      if (_isEditing && _existing != null) {
        // Mise à jour
        await _service.updateSubmission(_existing!.id, {
          'title': _titleController.text.trim(),
          'description': _descriptionController.text.trim(),
          'price': _parsePrice() ?? 0.0,
          'stock': _parseStock() ?? 0,
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
          price: _parsePrice() ?? 0.0,
          stock: _parseStock() ?? 0,
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

    _normalizeInputs();

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
        debugPrint('📤 [Review] Début upload de ${_selectedFiles.length} fichiers...');
        String submissionId = _existing?.id ?? 'temp_${DateTime.now().millisecondsSinceEpoch}';

        if (kIsWeb) {
          debugPrint('📤 [Review] Mode WEB');
          for (int i = 0; i < _selectedFiles.length; i++) {
            final file = _selectedFiles[i];
            debugPrint('📤 [Review] Upload ${i + 1}/${_selectedFiles.length}: ${file.name}');
            try {
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
              debugPrint('✅ [Review] Upload réussi: $url');
              _mediaUrls.add(url);
            } catch (e) {
              debugPrint('❌ [Review] Erreur upload: $e');
              throw Exception('Échec upload ${file.name}: $e');
            }
          }
        } else {
          debugPrint('📤 [Review] Mode MOBILE');
          try {
            final files = _selectedFiles.map((xf) => File(xf.path)).toList();
            final urls = await _service.uploadMediaFiles(
              scopeId: _scopeId.isEmpty ? 'global' : _scopeId,
              submissionId: submissionId,
              files: files,
              onProgress: (progress) {
                setState(() => _uploadProgress = progress);
              },
            );
            debugPrint('✅ [Review] ${urls.length} fichiers uploadés');
            _mediaUrls.addAll(urls);
          } catch (e) {
            debugPrint('❌ [Review] Erreur: $e');
            throw Exception('Échec upload: $e');
          }
        }
        _selectedFiles.clear();
      }

      String submissionId;

      if (_isEditing && _existing != null) {
        // Mise à jour puis soumission
        await _service.updateSubmission(_existing!.id, {
          'title': _titleController.text.trim(),
          'description': _descriptionController.text.trim(),
          'price': _parsePrice() ?? 0.0,
          'stock': _parseStock() ?? 0,
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
          price: _parsePrice() ?? 0.0,
          stock: _parseStock() ?? 0,
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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 2,
        title: Text(
          _isEditing ? 'Modifier le produit' : 'Nouveau produit',
          style: TextStyle(
            color: Colors.grey[800],
            fontWeight: FontWeight.w700,
          ),
        ),
        iconTheme: IconThemeData(color: Colors.grey[800]),
      ),
      body: _isLoading && _existing == null
          ? const Center(
              child: RainbowLoadingIndicator(
                size: 100,
                label: 'Chargement du produit...',
              ),
            )
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
                            textCapitalization: TextCapitalization.sentences,
                            autocorrect: true,
                            enableSuggestions: true,
                            onChanged: (value) {
                              final normalized = _normalizeTitle(value);
                              if (normalized != value) {
                                _setControllerValue(_titleController, normalized);
                              }
                            },
                            decoration: InputDecoration(
                              labelText: 'Titre du produit *',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: Colors.white,
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
                            textCapitalization: TextCapitalization.sentences,
                            autocorrect: true,
                            enableSuggestions: true,
                            onChanged: (value) {
                              final normalized = _normalizeDescription(value);
                              if (normalized != value) {
                                _setControllerValue(
                                  _descriptionController,
                                  normalized,
                                );
                              }
                            },
                            decoration: InputDecoration(
                              labelText: 'Description *',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: Colors.white,
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
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(
                                      RegExp(r'[0-9.,]'),
                                    ),
                                  ],
                                  onChanged: (value) {
                                    final normalized = _normalizePriceInput(value);
                                    if (normalized != value) {
                                      _setControllerValue(
                                        _priceController,
                                        normalized,
                                      );
                                    }
                                  },
                                  decoration: InputDecoration(
                                    labelText: 'Prix ($_currency) *',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    filled: true,
                                    fillColor: Colors.white,
                                  ),
                                  validator: (v) {
                                    if (v == null || v.trim().isEmpty) {
                                      return 'Prix obligatoire';
                                    }
                                    if (_parsePrice() == null) {
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
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                  onChanged: (value) {
                                    final normalized = _normalizeStockInput(value);
                                    if (normalized != value) {
                                      _setControllerValue(
                                        _stockController,
                                        normalized,
                                      );
                                    }
                                  },
                                  decoration: InputDecoration(
                                    labelText: 'Stock *',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    filled: true,
                                    fillColor: Colors.white,
                                  ),
                                  validator: (v) {
                                    if (v == null || v.trim().isEmpty) {
                                      return 'Stock obligatoire';
                                    }
                                    if (_parseStock() == null) {
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
                            initialValue: _selectedScopeType,
                            decoration: InputDecoration(
                              labelText: 'Portée',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: Colors.white,
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
                              fillColor: Colors.white,
                            ),
                            onChanged: (val) => _scopeId = val.trim(),
                          ),
                          const SizedBox(height: 16),

                          // Actif
                          SwitchListTile(
                            title: const Text('Produit actif'),
                            value: _isActive,
                            onChanged: (val) => setState(() => _isActive = val),
                            activeThumbColor: Colors.grey[700],
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
                                fontWeight: FontWeight.w700,
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
                                fontWeight: FontWeight.w700,
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
                                                return SizedBox(
                                                  width: 100,
                                                  height: 100,
                                                  child: Center(
                                                    child: RainbowLoadingIndicator(
                                                      size: 50,
                                                      showLabel: false,
                                                    ),
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

                          // Boutons ajouter images
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _isLoading ? null : _pickFromGallery,
                                  icon: const Icon(Icons.photo_library),
                                  label: const Text('Galerie'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.grey[800],
                                    padding: const EdgeInsets.all(16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                              if (!kIsWeb) ...[
                                const SizedBox(width: 12),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: _isLoading ? null : _pickFromCamera,
                                    icon: const Icon(Icons.photo_camera),
                                    label: const Text('Caméra'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.grey[700],
                                      side: BorderSide(
                                        color: Colors.grey[700]!,
                                      ),
                                      padding: const EdgeInsets.all(16),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Progress bar
                          if (_isLoading && _uploadProgress > 0)
                            Column(
                              children: [
                                const SizedBox(height: 24),
                                RainbowProgressIndicator(
                                  progress: _uploadProgress,
                                  label: '📄 Upload en cours...',
                                ),
                                const SizedBox(height: 24),
                              ],
                            ),

                          // Boutons d'action
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: _isLoading ? null : _saveDraft,
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.grey[700],
                                    side: BorderSide(color: Colors.grey[700]!),
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
                                    backgroundColor: Colors.grey[800],
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
                                            strokeWidth: 2.5,
                                            valueColor: AlwaysStoppedAnimation<Color>(
                                              Colors.white,
                                            ),
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
