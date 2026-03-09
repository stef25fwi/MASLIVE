enum ModerationStatus {
  pending,
  approved,
  flagged,
  rejected,
}

ModerationStatus moderationStatusFromString(
  String? value, {
  ModerationStatus fallback = ModerationStatus.pending,
}) {
  switch ((value ?? '').trim().toLowerCase()) {
    case 'pending':
      return ModerationStatus.pending;
    case 'approved':
      return ModerationStatus.approved;
    case 'flagged':
      return ModerationStatus.flagged;
    case 'rejected':
      return ModerationStatus.rejected;
    default:
      return fallback;
  }
}

extension ModerationStatusX on ModerationStatus {
  String get firestoreValue => name;

  String get label {
    switch (this) {
      case ModerationStatus.pending:
        return 'En attente';
      case ModerationStatus.approved:
        return 'Approuve';
      case ModerationStatus.flagged:
        return 'Signale';
      case ModerationStatus.rejected:
        return 'Rejete';
    }
  }
}