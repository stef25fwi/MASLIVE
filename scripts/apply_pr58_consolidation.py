#!/usr/bin/env python3
from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    file = Path(path)
    text = file.read_text(encoding="utf-8")
    if new in text:
        return
    if old not in text:
        raise SystemExit(f"Motif introuvable dans {path}: {old[:80]!r}")
    file.write_text(text.replace(old, new, 1), encoding="utf-8")


replace_once(
    "app/lib/services/commerce/commerce_service.dart",
    "  final FirebaseFunctions _functions = FirebaseFunctions.instance;",
    "  final FirebaseFunctions _functions =\n      FirebaseFunctions.instanceFor(region: 'us-east1');",
)

replace_once(
    "app/lib/services/commerce/commerce_service.dart",
    """    await _submissions.doc(submissionId).update({
      'status': SubmissionStatus.pending.toJson(),
      'submittedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });""",
    """    try {
      final callable = _functions.httpsCallable('submitCommerceForReview');
      await callable.call(<String, dynamic>{'submissionId': submissionId});
    } on FirebaseFunctionsException catch (error) {
      final details = error.details;
      if (details is Map && details['message'] is String) {
        throw Exception(details['message'] as String);
      }
      throw Exception(error.message ?? 'Impossible de soumettre la publication.');
    }""",
)

rules = Path("firestore.rules")
text = rules.read_text(encoding="utf-8")
marker = "match /commerce_submissions/{submissionId}"
if marker not in text:
    raise SystemExit("Bloc commerce_submissions introuvable dans firestore.rules")

# Renforce sans remplacer les règles récentes : une création cliente reste un brouillon
# et une mise à jour ne peut ni changer le propriétaire/rôle ni passer directement pending.
text = text.replace(
    "allow create: if",
    "allow create: if request.resource.data.status == 'draft' &&",
    1,
) if "request.resource.data.status == 'draft'" not in text[text.index(marker):text.index(marker)+2200] else text

block_start = text.index(marker)
block_slice = text[block_start:block_start + 2600]
if "request.resource.data.status == resource.data.status" not in block_slice:
    candidates = [
        "request.resource.data.ownerUid == resource.data.ownerUid",
        "request.resource.data.ownerUid == request.auth.uid",
    ]
    inserted = False
    for candidate in candidates:
        pos = text.find(candidate, block_start, block_start + 2600)
        if pos >= 0:
            end = pos + len(candidate)
            text = text[:end] + " &&\n          request.resource.data.ownerRole == resource.data.ownerRole &&\n          request.resource.data.status == resource.data.status" + text[end:]
            inserted = True
            break
    if not inserted:
        raise SystemExit("Impossible de renforcer la mise à jour commerce_submissions")
rules.write_text(text, encoding="utf-8")
