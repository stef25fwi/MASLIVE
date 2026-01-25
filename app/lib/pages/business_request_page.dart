import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class BusinessRequestPage extends StatefulWidget {
  const BusinessRequestPage({super.key});

  @override
  State<BusinessRequestPage> createState() => _BusinessRequestPageState();
}

class _BusinessRequestPageState extends State<BusinessRequestPage> {
  final _formKey = GlobalKey<FormState>();
  final _companyCtrl = TextEditingController();
  final _siretCtrl = TextEditingController();

  bool _loading = false;
  String? _error;
  bool _loadedExisting = false;
  bool _hasExisting = false;
  String? _existingStatus;

  @override
  void dispose() {
    _companyCtrl.dispose();
    _siretCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loadedExisting) {
      _loadedExisting = true;
      _loadExisting();
    }
  }

  Future<void> _loadExisting() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final ref = FirebaseFirestore.instance
        .collection('businesses')
        .doc(user.uid);
    final snap = await ref.get();
    if (!mounted) return;

    if (snap.exists) {
      final data = snap.data() ?? {};
      setState(() {
        _hasExisting = true;
        _existingStatus = (data['status'] ?? 'pending').toString();
        _companyCtrl.text = (data['companyName'] ?? '').toString();
        _siretCtrl.text = (data['siret'] ?? '').toString();
      });
    }
  }

  Future<void> _deleteBusiness() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer la demande'),
        content: const Text(
          'Êtes-vous sûr de vouloir supprimer votre demande professionnelle? '
          'Vous pourrez la soumettre à nouveau après.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _loading = true);

    try {
      final ref = FirebaseFirestore.instance
          .collection('businesses')
          .doc(user.uid);
      await ref.delete();

      if (!mounted) return;
      setState(() {
        _hasExisting = false;
        _existingStatus = null;
        _companyCtrl.clear();
        _siretCtrl.clear();
        _error = null;
        _loading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Demande supprimée.')),
        );
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _error = 'Vous devez être connecté.');
      return;
    }

    final email = user.email;
    if (email == null || email.trim().isEmpty) {
      setState(() => _error = 'Email utilisateur introuvable.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final ref = FirebaseFirestore.instance
          .collection('businesses')
          .doc(user.uid);
      final snap = await ref.get();

      if (snap.exists) {
        final status = (snap.data()?['status'] ?? 'pending').toString();
        if (status == 'approved') {
          throw Exception(
            'Votre demande ne peut plus être modifiée (statut: approved).',
          );
        }

        await ref.update({
          'companyName': _companyCtrl.text.trim(),
          'siret': _siretCtrl.text.trim(),
          if (status == 'rejected') ...{
            'status': 'pending',
            'rejectionReason': FieldValue.delete(),
            'reviewedAt': FieldValue.delete(),
            'reviewedBy': FieldValue.delete(),
          },
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        await ref.set({
          'ownerUid': user.uid,
          'email': email.trim(),
          'status': 'pending',
          'companyName': _companyCtrl.text.trim(),
          'siret': _siretCtrl.text.trim(),
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Demande envoyée.')),
      );
      Navigator.pop(context);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Demande pro')),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Connectez-vous pour faire une demande.'),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => Navigator.pushNamed(context, '/login'),
                child: const Text('Se connecter'),
              ),
            ],
          ),
        ),
      );
    }

    final locked = _hasExisting && _existingStatus == 'approved';
    final isRejected = _hasExisting && _existingStatus == 'rejected';
    final isPending = _hasExisting && _existingStatus == 'pending';

    return Scaffold(
      appBar: AppBar(title: const Text('Demande compte professionnel')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (locked) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: const Text(
                'Votre demande est approuvée. Les champs sont verrouillés.',
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (!locked && isRejected) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Votre demande a été refusée. En appuyant sur "Re-soumettre", elle repassera automatiquement en attente (pending).',
                    style: TextStyle(color: Colors.orange.shade900),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Ou supprimez-la complètement et réinscrivez-vous.',
                    style: TextStyle(color: Colors.orange.shade700, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (!locked && isPending) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Text(
                'Votre demande est déjà en attente. Vous pouvez corriger ces informations, mais cela ne valide pas automatiquement.',
                style: TextStyle(color: Colors.blue.shade900),
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (_error != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Text(
                _error!,
                style: TextStyle(color: Colors.red.shade700),
              ),
            ),
            const SizedBox(height: 12),
          ],
          Text(
            'Champs requis: nom d\'entreprise et SIRET.',
            style: TextStyle(color: Colors.grey.shade700),
          ),
          const SizedBox(height: 12),
          Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _companyCtrl,
                  enabled: !_loading && !locked,
                  decoration: const InputDecoration(
                    labelText: 'Nom entreprise *',
                    prefixIcon: Icon(Icons.business_outlined),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Nom entreprise requis'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _siretCtrl,
                  enabled: !_loading && !locked,
                  decoration: const InputDecoration(
                    labelText: 'SIRET *',
                    prefixIcon: Icon(Icons.numbers),
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(14),
                  ],
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'SIRET requis';
                    if (v.trim().length != 14) return 'SIRET: 14 chiffres';
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: (_loading || locked) ? null : _submit,
                    child: _loading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            !_hasExisting
                                ? 'Envoyer la demande'
                                : (isRejected
                                      ? 'Re-soumettre la demande'
                                      : 'Mettre à jour'),
                          ),
                  ),
                ),
                if (_hasExisting && !locked) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _loading ? null : _deleteBusiness,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                      ),
                      child: const Text('Supprimer ma demande'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
