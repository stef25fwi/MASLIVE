import 'package:flutter/material.dart';
import '../../models/commerce_submission.dart';
import '../../services/commerce/commerce_service.dart';
import '../../widgets/commerce/moderation_tile.dart';

/// Page de modération des soumissions commerce
class AdminModerationPage extends StatefulWidget {
  const AdminModerationPage({super.key});

  @override
  State<AdminModerationPage> createState() => _AdminModerationPageState();
}

class _AdminModerationPageState extends State<AdminModerationPage> {
  final _service = CommerceService.instance;
  SubmissionType? _typeFilter;
  ScopeType? _scopeTypeFilter;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('Modération Commerce', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.black87),
        actions: [
          PopupMenuButton<SubmissionType?>(
            icon: const Icon(Icons.filter_list),
            onSelected: (val) => setState(() => _typeFilter = val),
            itemBuilder: (context) => [
              const PopupMenuItem(value: null, child: Text('Tous les types')),
              const PopupMenuItem(value: SubmissionType.product, child: Text('Produits')),
              const PopupMenuItem(value: SubmissionType.media, child: Text('Médias')),
            ],
          ),
        ],
      ),
      body: StreamBuilder<List<CommerceSubmission>>(
        stream: _service.watchPendingSubmissions(type: _typeFilter, scopeType: _scopeTypeFilter),
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
                  Icon(Icons.check_circle_outline, size: 80, color: Colors.green.shade300),
                  const SizedBox(height: 16),
                  Text('Aucune soumission en attente', style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: submissions.length,
            itemBuilder: (context, index) {
              return ModerationTile(
                submission: submissions[index],
                onApprove: () => _approve(submissions[index]),
                onReject: () => _reject(submissions[index]),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _approve(CommerceSubmission submission) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Valider la soumission'),
        content: Text('Valider "${submission.title}" ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.green),
            child: const Text('Valider'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _service.approve(submission.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('✅ Soumission validée et publiée')),
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

  Future<void> _reject(CommerceSubmission submission) async {
    final controller = TextEditingController();
    final note = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Refuser la soumission'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Note de refus *',
            hintText: 'Expliquez pourquoi...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Refuser'),
          ),
        ],
      ),
    );

    if (note != null && note.isNotEmpty) {
      try {
        await _service.reject(submission.id, note);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('✅ Soumission refusée')),
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
}
