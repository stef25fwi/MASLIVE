import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ProfessionalArticleFormPage extends StatefulWidget {
  final String? articleId;

  const ProfessionalArticleFormPage({super.key, this.articleId});

  @override
  State<ProfessionalArticleFormPage> createState() => _ProfessionalArticleFormPageState();
}

class _ProfessionalArticleFormPageState extends State<ProfessionalArticleFormPage> {
  late Future<DocumentSnapshot<Map<String, dynamic>>?> _articleFuture;
  final _formKey = GlobalKey<FormState>();
  
  final _titleCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _stockCtrl = TextEditingController();
  final _imageUrlCtrl = TextEditingController();

  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.articleId != null) {
      _loadArticle();
    } else {
      _articleFuture = Future.value(null);
    }
  }

  void _loadArticle() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      _articleFuture = Future.error('Non authentifié');
      return;
    }

    _articleFuture = FirebaseFirestore.instance
        .collection('businesses')
        .doc(uid)
        .collection('articles')
        .doc(widget.articleId!)
        .get()
        .then((doc) {
          if (doc.exists) {
            final data = doc.data();
            _titleCtrl.text = data?['title'] ?? '';
            _descriptionCtrl.text = data?['description'] ?? '';
            _priceCtrl.text = (data?['price'] ?? 0).toString();
            _stockCtrl.text = (data?['stock'] ?? 0).toString();
            _imageUrlCtrl.text = data?['imageUrl'] ?? '';
            return doc;
          }
          return null;
        });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw Exception('Non authentifié');

      final data = {
        'title': _titleCtrl.text.trim(),
        'description': _descriptionCtrl.text.trim(),
        'price': double.parse(_priceCtrl.text),
        'stock': int.parse(_stockCtrl.text),
        'imageUrl': _imageUrlCtrl.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (widget.articleId == null) {
        data['createdAt'] = FieldValue.serverTimestamp();
        await FirebaseFirestore.instance
            .collection('businesses')
            .doc(uid)
            .collection('articles')
            .add(data);
      } else {
        await FirebaseFirestore.instance
            .collection('businesses')
            .doc(uid)
            .collection('articles')
            .doc(widget.articleId!)
            .update(data);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.articleId == null ? 'Article créé ✓' : 'Article mis à jour ✓'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descriptionCtrl.dispose();
    _priceCtrl.dispose();
    _stockCtrl.dispose();
    _imageUrlCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>?>(
      future: _articleFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            appBar: AppBar(),
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(widget.articleId == null ? 'Ajouter un article' : 'Modifier l\'article'),
            elevation: 0,
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_error != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: Colors.red, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _error!,
                              style: const TextStyle(color: Colors.red, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (_error != null) const SizedBox(height: 16),

                  _buildSection('Informations de base', [
                    TextFormField(
                      controller: _titleCtrl,
                      decoration: InputDecoration(
                        labelText: 'Titre de l\'article *',
                        prefixIcon: const Icon(Icons.title),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      validator: (v) => v?.trim().isEmpty ?? true ? 'Titre requis' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _descriptionCtrl,
                      decoration: InputDecoration(
                        labelText: 'Description',
                        prefixIcon: const Icon(Icons.description),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      maxLines: 4,
                    ),
                  ]),
                  const SizedBox(height: 24),

                  _buildSection('Tarification et stock', [
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _priceCtrl,
                            decoration: InputDecoration(
                              labelText: 'Prix (€) *',
                              prefixIcon: const Icon(Icons.euro),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            validator: (v) {
                              if (v?.trim().isEmpty ?? true) return 'Prix requis';
                              try {
                                double.parse(v!);
                                return null;
                              } catch (e) {
                                return 'Prix invalide';
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _stockCtrl,
                            decoration: InputDecoration(
                              labelText: 'Stock *',
                              prefixIcon: const Icon(Icons.inventory),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            keyboardType: TextInputType.number,
                            validator: (v) {
                              if (v?.trim().isEmpty ?? true) return 'Stock requis';
                              try {
                                int.parse(v!);
                                return null;
                              } catch (e) {
                                return 'Stock invalide';
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ]),
                  const SizedBox(height: 24),

                  _buildSection('Image', [
                    TextFormField(
                      controller: _imageUrlCtrl,
                      decoration: InputDecoration(
                        labelText: 'URL de l\'image',
                        prefixIcon: const Icon(Icons.image),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_imageUrlCtrl.text.isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          _imageUrlCtrl.text,
                          height: 200,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              height: 200,
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Center(
                                child: Icon(Icons.broken_image, size: 48, color: Colors.grey),
                              ),
                            );
                          },
                        ),
                      ),
                  ]),
                  const SizedBox(height: 32),

                  // Boutons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _loading ? null : () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text('Annuler'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _loading ? null : _submit,
                          icon: _loading ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ) : const Icon(Icons.save, size: 18),
                          label: Text(widget.articleId == null ? 'Ajouter' : 'Mettre à jour'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue),
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }
}
