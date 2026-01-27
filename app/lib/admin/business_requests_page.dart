import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/auth_claims_service.dart';

class BusinessRequestsPage extends StatefulWidget {
  const BusinessRequestsPage({super.key});

  @override
  State<BusinessRequestsPage> createState() => _BusinessRequestsPageState();
}

class _BusinessRequestsPageState extends State<BusinessRequestsPage> {
  bool _isAdmin = false;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _checkAdmin();
  }

  Future<void> _checkAdmin() async {
    try {
      final appUser = await AuthClaimsService.instance.getCurrentAppUser();
      if (!mounted) return;
      setState(() {
        _isAdmin = appUser?.isAdmin == true;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isAdmin = false;
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _approve(String uid) async {
    final adminUid = FirebaseAuth.instance.currentUser?.uid;
    if (adminUid == null) return;

    await FirebaseFirestore.instance.collection('businesses').doc(uid).update({
      'status': 'approved',
      'reviewedAt': FieldValue.serverTimestamp(),
      'reviewedBy': adminUid,
      'rejectionReason': FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Demande approuvée')),
    );
  }

  Future<void> _reject(String uid) async {
    final adminUid = FirebaseAuth.instance.currentUser?.uid;
    if (adminUid == null) return;

    final ctrl = TextEditingController();
    
    try {
      final res = await showDialog<String?>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Refuser la demande'),
            content: TextField(
              controller: ctrl,
              decoration: const InputDecoration(labelText: 'Motif (optionnel)'),
              maxLines: 3,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, null),
                child: const Text('Annuler'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, ctrl.text.trim()),
                child: const Text('Refuser'),
              ),
            ],
          );
        },
      );

      if (res == null) return; // Dialog annulé

      final reason = res.trim();

      await FirebaseFirestore.instance.collection('businesses').doc(uid).update({
        'status': 'rejected',
        'reviewedAt': FieldValue.serverTimestamp(),
        'reviewedBy': adminUid,
        if (reason.isNotEmpty) 'rejectionReason': reason,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Demande refusée')),
      );
    } finally {
      ctrl.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!_isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Demandes pro')),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            _error ?? 'Accès réservé aux administrateurs.',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      );
    }

    final q = FirebaseFirestore.instance
        .collection('businesses')
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .limit(100); // Limite pour éviter trop de données

    return Scaffold(
      appBar: AppBar(title: const Text('Demandes pro (pending)')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: q.snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text('Erreur: ${snap.error}'));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snap.data!.docs;
          if (docs.isEmpty) {
            return const Center(child: Text('Aucune demande en attente.'));
          }

          return ListView.separated(
            itemCount: docs.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final d = docs[i];
              final data = d.data();
              final company = (data['companyName'] ?? '').toString();
              final siret = (data['siret'] ?? '').toString();
              final email = (data['email'] ?? '').toString();

              return ListTile(
                leading: const Icon(Icons.business),
                title: Text(company.isEmpty ? d.id : company),
                subtitle: Text('SIRET: $siret\n$email'),
                isThreeLine: true,
                trailing: Wrap(
                  spacing: 8,
                  children: [
                    IconButton(
                      tooltip: 'Refuser',
                      onPressed: () => _reject(d.id),
                      icon: const Icon(Icons.close, color: Colors.red),
                    ),
                    IconButton(
                      tooltip: 'Approuver',
                      onPressed: () => _approve(d.id),
                      icon: const Icon(Icons.check, color: Colors.green),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
