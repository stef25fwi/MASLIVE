import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class PendingProductsPage extends StatelessWidget {
  const PendingProductsPage({super.key});

  bool _isMasterAdmin(Map<String, dynamic>? userData) {
    if (userData == null) return false;
    if (userData['isAdmin'] == true) return true;
    return (userData['role'] ?? '').toString() == 'admin';
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> _userDocStream() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const Stream.empty();
    return FirebaseFirestore.instance.collection('users').doc(uid).snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _pendingProductsStream() {
    return FirebaseFirestore.instance
        .collectionGroup('products')
        .where('moderationStatus', isEqualTo: 'pending')
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _userDocStream(),
      builder: (context, userSnap) {
        final userData = userSnap.data?.data();
        final isMaster = _isMasterAdmin(userData);

        if (!isMaster) {
          return Scaffold(
            appBar: AppBar(title: const Text('Articles à valider')),
            body: const Center(child: Text('Accès refusé')),
          );
        }

        return Scaffold(
          appBar: AppBar(title: const Text('Articles à valider')),
          body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _pendingProductsStream(),
            builder: (context, snap) {
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final docs = snap.data!.docs;
              if (docs.isEmpty) {
                return const Center(child: Text('Aucun article en attente'));
              }

              // Tri: plus récent d'abord si timestampMs ou createdAt, sinon alpha
              docs.sort((a, b) {
                final ad = a.data();
                final bd = b.data();
                final at = ad['createdAt'];
                final bt = bd['createdAt'];
                if (at is Timestamp && bt is Timestamp) {
                  return bt.compareTo(at);
                }
                return (ad['title'] ?? '').toString().compareTo((bd['title'] ?? '').toString());
              });

              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: docs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, i) {
                  final doc = docs[i];
                  final data = doc.data();

                  final title = (data['title'] ?? '').toString();
                  final category = (data['category'] ?? '').toString();
                  final priceCents = (data['priceCents'] ?? 0) as int;
                  final priceLabel = '€${(priceCents / 100).toStringAsFixed(0)}';
                  final imageUrl = (data['imageUrl'] ?? '').toString();

                  final groupId = doc.reference.parent.parent?.id ?? 'unknown';

                  return InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => PendingProductReviewPage(
                            ref: doc.reference,
                            groupId: groupId,
                          ),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.black12),
                      ),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: SizedBox(
                              width: 70,
                              height: 70,
                              child: imageUrl.isEmpty
                                  ? Container(color: Colors.black.withValues(alpha: 0.06))
                                  : Image.network(imageUrl, fit: BoxFit.cover),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
                                const SizedBox(height: 4),
                                Text(
                                  '$priceLabel • $category',
                                  style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Groupe: $groupId',
                                  style: TextStyle(
                                    color: Colors.black.withValues(alpha: 0.55),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}

class PendingProductReviewPage extends StatefulWidget {
  const PendingProductReviewPage({
    super.key,
    required this.ref,
    required this.groupId,
  });

  final DocumentReference<Map<String, dynamic>> ref;
  final String groupId;

  @override
  State<PendingProductReviewPage> createState() => _PendingProductReviewPageState();
}

class _PendingProductReviewPageState extends State<PendingProductReviewPage> {
  final _titleCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _reasonCtrl = TextEditingController();
  String _category = 'T-shirts';
  bool _saving = false;

  final List<String> _categories = const [
    'T-shirts',
    'Casquettes',
    'Stickers',
    'Accessoires',
  ];

  @override
  void dispose() {
    _titleCtrl.dispose();
    _priceCtrl.dispose();
    _reasonCtrl.dispose();
    super.dispose();
  }

  int? _parsePriceCents() {
    final raw = _priceCtrl.text.trim().replaceAll(',', '.');
    if (raw.isEmpty) return null;
    final value = double.tryParse(raw);
    if (value == null || value < 0) return null;
    return (value * 100).round();
  }

  Future<void> _saveEdits() async {
    final title = _titleCtrl.text.trim();
    final priceCents = _parsePriceCents();

    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Titre requis')));
      return;
    }
    if (priceCents == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Prix invalide')));
      return;
    }

    setState(() => _saving = true);
    try {
      await widget.ref.set(
        {
          'title': title,
          'priceCents': priceCents,
          'category': _category,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Modifications enregistrées')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ Erreur: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _toggleValidate(bool v) async {
    setState(() => _saving = true);
    try {
      if (v) {
        await widget.ref.set(
          {
            'isActive': true,
            'moderationStatus': 'approved',
            'approvedAt': FieldValue.serverTimestamp(),
            'approvedBy': FirebaseAuth.instance.currentUser?.uid,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      } else {
        await widget.ref.set(
          {
            'isActive': false,
            'moderationStatus': 'pending',
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(v ? '✅ Article validé' : '⏳ Remis en attente')),
      );

      if (v) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ Erreur: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _reject() async {
    final reason = _reasonCtrl.text.trim();
    if (reason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Motif requis pour refuser')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await widget.ref.set(
        {
          'isActive': false,
          'moderationStatus': 'rejected',
          'moderationReason': reason,
          'rejectedAt': FieldValue.serverTimestamp(),
          'rejectedBy': FirebaseAuth.instance.currentUser?.uid,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⛔ Article refusé')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ Erreur: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: widget.ref.snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final data = snap.data!.data() ?? {};
        final title = (data['title'] ?? '').toString();
        final category = (data['category'] ?? 'T-shirts').toString();
        final priceCents = (data['priceCents'] ?? 0) as int;
        final price = (priceCents / 100).toStringAsFixed(2);
        final imageUrl = (data['imageUrl'] ?? '').toString();
        final imageUrl2 = (data['imageUrl2'] ?? '').toString();

        final status = (data['moderationStatus'] ?? '').toString();
        final isActive = (data['isActive'] ?? false) == true;
        final isPending = status == 'pending' || !isActive;
        final moderationReason = (data['moderationReason'] ?? '').toString();

        // initialiser les contrôleurs une fois
        if (_titleCtrl.text.isEmpty && title.isNotEmpty) {
          _titleCtrl.text = title;
        }
        if (_priceCtrl.text.isEmpty && priceCents > 0) {
          _priceCtrl.text = price;
        }
        _category = _categories.contains(category) ? category : _category;

        return Scaffold(
          appBar: AppBar(title: const Text('Validation article')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Groupe: ${widget.groupId}',
                style: TextStyle(color: Colors.black.withValues(alpha: 0.6), fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              _imagesCard(imageUrl, imageUrl2),
              const SizedBox(height: 12),
              TextField(
                controller: _titleCtrl,
                decoration: const InputDecoration(labelText: 'Titre', prefixIcon: Icon(Icons.label)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _priceCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Prix (€)', prefixIcon: Icon(Icons.euro)),
              ),
              const SizedBox(height: 12),
              InputDecorator(
                decoration: const InputDecoration(labelText: 'Catégorie', prefixIcon: Icon(Icons.category)),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _category,
                    isExpanded: true,
                    items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                    onChanged: _saving ? null : (v) => setState(() => _category = v ?? _category),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _saving ? null : _saveEdits,
                      icon: const Icon(Icons.save),
                      label: const Text('Enregistrer'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.black12),
                ),
                child: SwitchListTile(
                  value: !isPending,
                  onChanged: _saving ? null : _toggleValidate,
                  title: const Text('Valider et publier dans la boutique'),
                  subtitle: Text(isPending ? 'Statut: en attente' : 'Statut: validé'),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.black12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Refuser', style: TextStyle(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _reasonCtrl,
                      enabled: !_saving,
                      minLines: 2,
                      maxLines: 5,
                      decoration: InputDecoration(
                        labelText: 'Motif de refus',
                        hintText: 'Explique ce qu’il faut corriger (ex: prix, titre, photos...)',
                        prefixIcon: const Icon(Icons.report_gmailerrorred_outlined),
                        helperText: moderationReason.isNotEmpty
                            ? 'Motif actuel: $moderationReason'
                            : null,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: _saving ? null : _reject,
                        icon: const Icon(Icons.block),
                        label: const Text('Refuser l’article'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _imagesCard(String url1, String url2) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black12),
      ),
      child: Row(
        children: [
          Expanded(
            child: AspectRatio(
              aspectRatio: 1,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: url1.isEmpty
                    ? Container(color: Colors.black.withValues(alpha: 0.06))
                    : Image.network(url1, fit: BoxFit.cover),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: AspectRatio(
              aspectRatio: 1,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: url2.isEmpty
                    ? Container(color: Colors.black.withValues(alpha: 0.06))
                    : Image.network(url2, fit: BoxFit.cover),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
