import 'package:flutter/material.dart';
import '../../models/commerce_submission.dart';
import '../../services/commerce/commerce_service.dart';
import '../../widgets/commerce/submission_tile.dart';
import 'create_product_page.dart';
import 'create_media_page.dart';

/// Page listant mes soumissions commerce
class MySubmissionsPage extends StatefulWidget {
  const MySubmissionsPage({super.key});

  @override
  State<MySubmissionsPage> createState() => _MySubmissionsPageState();
}

class _MySubmissionsPageState extends State<MySubmissionsPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _service = CommerceService.instance;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('Mes contenus', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.black87),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.deepPurple,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.deepPurple,
          tabs: const [
            Tab(text: 'Brouillons'),
            Tab(text: 'En attente'),
            Tab(text: 'Validés'),
            Tab(text: 'Refusés'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildList(SubmissionStatus.draft),
          _buildList(SubmissionStatus.pending),
          _buildList(SubmissionStatus.approved),
          _buildList(SubmissionStatus.rejected),
        ],
      ),
    );
  }

  Widget _buildList(SubmissionStatus status) {
    return StreamBuilder<List<CommerceSubmission>>(
      stream: _service.watchMySubmissions(status: status),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Erreur: ${snapshot.error}'));
        }

        final submissions = snapshot.data ?? [];

        if (submissions.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inbox, size: 80, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                Text(
                  'Aucun contenu ${_statusLabel(status)}',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: submissions.length,
          itemBuilder: (context, index) {
            return SubmissionTile(
              submission: submissions[index],
              onEdit: () => _edit(submissions[index]),
              onDelete: () => _delete(submissions[index]),
              onResubmit: () => _resubmit(submissions[index]),
            );
          },
        );
      },
    );
  }

  String _statusLabel(SubmissionStatus status) {
    switch (status) {
      case SubmissionStatus.draft:
        return 'en brouillon';
      case SubmissionStatus.pending:
        return 'en attente';
      case SubmissionStatus.approved:
        return 'validé';
      case SubmissionStatus.rejected:
        return 'refusé';
    }
  }

  void _edit(CommerceSubmission submission) {
    if (submission.isProduct) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => CreateProductPage(submissionId: submission.id)),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => CreateMediaPage(submissionId: submission.id)),
      );
    }
  }

  Future<void> _delete(CommerceSubmission submission) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmer la suppression'),
        content: const Text('Voulez-vous vraiment supprimer ce contenu ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _service.deleteSubmission(submission.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('✅ Contenu supprimé')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('❌ Erreur: $e')),
          );
        }
      }
    }
  }

  Future<void> _resubmit(CommerceSubmission submission) async {
    try {
      await _service.submitForReview(submission.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Re-soumis pour validation')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Erreur: $e')),
        );
      }
    }
  }
}
