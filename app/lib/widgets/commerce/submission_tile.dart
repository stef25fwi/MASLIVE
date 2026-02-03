import 'package:flutter/material.dart';
import '../../models/commerce_submission.dart';

/// Tuile d'affichage d'une soumission commerce
class SubmissionTile extends StatelessWidget {
  final CommerceSubmission submission;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onResubmit;

  const SubmissionTile({
    super.key,
    required this.submission,
    this.onEdit,
    this.onDelete,
    this.onResubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Image
                if (submission.mediaUrls.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      submission.mediaUrls.first,
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 60,
                        height: 60,
                        color: Colors.grey.shade200,
                        child: const Icon(Icons.broken_image),
                      ),
                    ),
                  )
                else
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(submission.isProduct ? Icons.shopping_bag : Icons.image, color: Colors.grey),
                  ),
                const SizedBox(width: 12),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(submission.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 4),
                      Text(
                        submission.isProduct
                            ? 'Produit • ${submission.price?.toStringAsFixed(2)} ${submission.currency}'
                            : 'Média • ${submission.mediaType?.name}',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                // Badge statut
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _statusColor),
                  ),
                  child: Text(
                    _statusLabel,
                    style: TextStyle(color: _statusColor, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            // Note de refus
            if (submission.isRejected && submission.moderationNote != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        submission.moderationNote!,
                        style: TextStyle(color: Colors.red.shade700, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            // Actions
            if (submission.canEdit || submission.canSubmit) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (submission.canEdit && onDelete != null)
                    TextButton.icon(
                      onPressed: onDelete,
                      icon: const Icon(Icons.delete, size: 18),
                      label: const Text('Supprimer'),
                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                    ),
                  if (submission.canEdit && onEdit != null)
                    TextButton.icon(
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit, size: 18),
                      label: const Text('Modifier'),
                    ),
                  if (submission.isRejected && onResubmit != null)
                    TextButton.icon(
                      onPressed: onResubmit,
                      icon: const Icon(Icons.send, size: 18),
                      label: const Text('Re-soumettre'),
                      style: TextButton.styleFrom(foregroundColor: Colors.green),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color get _statusColor {
    switch (submission.status) {
      case SubmissionStatus.draft:
        return Colors.grey;
      case SubmissionStatus.pending:
        return Colors.orange;
      case SubmissionStatus.approved:
        return Colors.green;
      case SubmissionStatus.rejected:
        return Colors.red;
    }
  }

  String get _statusLabel {
    switch (submission.status) {
      case SubmissionStatus.draft:
        return 'Brouillon';
      case SubmissionStatus.pending:
        return 'En attente';
      case SubmissionStatus.approved:
        return 'Validé';
      case SubmissionStatus.rejected:
        return 'Refusé';
    }
  }
}
