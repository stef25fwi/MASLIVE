enum PhotographerStatus {
  pending,
  approved,
  rejected,
  suspended,
}

PhotographerStatus photographerStatusFromString(
  String? value, {
  PhotographerStatus fallback = PhotographerStatus.pending,
}) {
  switch ((value ?? '').trim().toLowerCase()) {
    case 'pending':
      return PhotographerStatus.pending;
    case 'approved':
      return PhotographerStatus.approved;
    case 'rejected':
      return PhotographerStatus.rejected;
    case 'suspended':
      return PhotographerStatus.suspended;
    default:
      return fallback;
  }
}

extension PhotographerStatusX on PhotographerStatus {
  String get firestoreValue => name;

  String get label {
    switch (this) {
      case PhotographerStatus.pending:
        return 'En attente';
      case PhotographerStatus.approved:
        return 'Approuve';
      case PhotographerStatus.rejected:
        return 'Rejete';
      case PhotographerStatus.suspended:
        return 'Suspendu';
    }
  }
}