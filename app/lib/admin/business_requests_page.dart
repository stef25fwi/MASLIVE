import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/auth_claims_service.dart';
import '../ui/snack/top_snack_bar.dart';

class BusinessRequestsPage extends StatefulWidget {
  const BusinessRequestsPage({super.key});

  @override
  State<BusinessRequestsPage> createState() => _BusinessRequestsPageState();
}

class _BusinessRequestsPageState extends State<BusinessRequestsPage> with SingleTickerProviderStateMixin {
  bool _isAdmin = false;
  bool _loading = true;
  String? _error;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _checkAdmin();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
      'status': 'active',
      'reviewedAt': FieldValue.serverTimestamp(),
      'reviewedBy': adminUid,
      'rejectionReason': FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    if (!mounted) return;
    TopSnackBar.show(
      context,
      const SnackBar(content: Text('Compte professionnel activé ✓'), backgroundColor: Colors.green),
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
      TopSnackBar.show(
        context,
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Comptes Professionnels'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.pending_actions), text: 'En attente'),
            Tab(icon: Icon(Icons.check_circle), text: 'Actifs'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPendingList(),
          _buildActiveList(),
        ],
      ),
    );
  }

  Widget _buildPendingList() {
    final q = FirebaseFirestore.instance
        .collection('businesses')
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .limit(100);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
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
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inbox, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('Aucune demande en attente', style: TextStyle(fontSize: 16, color: Colors.grey)),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, i) {
            final d = docs[i];
            final data = d.data();
            return _buildBusinessCard(d.id, data, isPending: true);
          },
        );
      },
    );
  }

  Widget _buildActiveList() {
    final q = FirebaseFirestore.instance
        .collection('businesses')
        .where('status', isEqualTo: 'active')
        .orderBy('reviewedAt', descending: true)
        .limit(100);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
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
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.business, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('Aucun compte actif', style: TextStyle(fontSize: 16, color: Colors.grey)),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, i) {
            final d = docs[i];
            final data = d.data();
            return _buildBusinessCard(d.id, data, isPending: false);
          },
        );
      },
    );
  }

  Widget _buildBusinessCard(String uid, Map<String, dynamic> data, {required bool isPending}) {
    final company = (data['companyName'] ?? 'N/A').toString();
    final siret = (data['siret'] ?? 'N/A').toString();
    final email = (data['email'] ?? 'N/A').toString();
    final phone = (data['phone'] ?? 'N/A').toString();
    final legalForm = (data['legalForm'] ?? 'N/A').toString();
    final sector = (data['activitySector'] ?? 'N/A').toString();
    
    final createdAt = data['createdAt'] as Timestamp?;
    final createdDate = createdAt != null 
        ? DateFormat('dd/MM/yyyy HH:mm').format(createdAt.toDate())
        : 'N/A';

    return Card(
      elevation: 2,
      child: InkWell(
        onTap: () => _showBusinessDetails(uid, data, isPending: isPending),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isPending ? Colors.orange.withValues(alpha: 0.1) : Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.business,
                      color: isPending ? Colors.orange : Colors.green,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          company,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          legalForm,
                          style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                  if (isPending)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'En attente',
                        style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Actif',
                        style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                ],
              ),
              const Divider(height: 24),
              _buildInfoRow(Icons.tag, 'SIRET', siret),
              const SizedBox(height: 8),
              _buildInfoRow(Icons.email, 'Email', email),
              const SizedBox(height: 8),
              _buildInfoRow(Icons.phone, 'Téléphone', phone),
              const SizedBox(height: 8),
              _buildInfoRow(Icons.category, 'Secteur', sector),
              const SizedBox(height: 8),
              _buildInfoRow(Icons.access_time, 'Créé le', createdDate),
              if (isPending) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _reject(uid),
                        icon: const Icon(Icons.close, size: 18),
                        label: const Text('Refuser'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _approve(uid),
                        icon: const Icon(Icons.check, size: 18),
                        label: const Text('Valider'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(fontSize: 13, color: Colors.grey[600], fontWeight: FontWeight.w600),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 13),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  void _showBusinessDetails(String uid, Map<String, dynamic> data, {required bool isPending}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.9,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      const Icon(Icons.business, size: 32, color: Colors.blue),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          data['companyName'] ?? 'N/A',
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildDetailSection('Informations générales', [
                    _buildDetailItem('Forme juridique', data['legalForm']),
                    _buildDetailItem('SIRET', data['siret']),
                    _buildDetailItem('Secteur d\'activité', data['activitySector']),
                  ]),
                  const SizedBox(height: 20),
                  _buildDetailSection('Contact', [
                    _buildDetailItem('Email', data['email']),
                    _buildDetailItem('Téléphone', data['phone']),
                  ]),
                  const SizedBox(height: 20),
                  _buildDetailSection('Adresse', [
                    _buildDetailItem('Adresse', data['address']),
                    _buildDetailItem('Code postal', data['postalCode']),
                    _buildDetailItem('Ville', data['city']),
                    _buildDetailItem('Région', data['region']),
                    _buildDetailItem('Pays', data['country']),
                  ]),
                  const SizedBox(height: 20),
                  _buildDetailSection('Représentant légal', [
                    _buildDetailItem('Prénom', data['firstName']),
                    _buildDetailItem('Nom', data['lastName']),
                  ]),
                  const SizedBox(height: 20),
                  _buildDetailSection('Informations système', [
                    _buildDetailItem('UID', uid),
                    _buildDetailItem('Statut', data['status']),
                    _buildDetailItem('Créé le', _formatTimestamp(data['createdAt'])),
                    if (data['reviewedAt'] != null)
                      _buildDetailItem('Validé le', _formatTimestamp(data['reviewedAt'])),
                  ]),
                  if (isPending) ...[
                    const SizedBox(height: 32),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              _reject(uid);
                            },
                            icon: const Icon(Icons.close),
                            label: const Text('Refuser'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              side: const BorderSide(color: Colors.red),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              _approve(uid);
                            },
                            icon: const Icon(Icons.check),
                            label: const Text('Valider'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDetailSection(String title, List<Widget> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue),
        ),
        const SizedBox(height: 12),
        ...items,
      ],
    );
  }

  Widget _buildDetailItem(String label, dynamic value) {
    final displayValue = value?.toString() ?? 'N/A';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              '$label:',
              style: TextStyle(fontSize: 14, color: Colors.grey[600], fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Text(
              displayValue,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'N/A';
    if (timestamp is Timestamp) {
      return DateFormat('dd/MM/yyyy à HH:mm').format(timestamp.toDate());
    }
    return timestamp.toString();
  }
}
