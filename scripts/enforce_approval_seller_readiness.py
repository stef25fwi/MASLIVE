#!/usr/bin/env python3
"""Ajoute la revalidation vendeur avant publication par un modérateur."""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def main() -> None:
    path = ROOT / "functions/index.js"
    text = path.read_text(encoding="utf-8")
    signature = (
        "const sellerReadiness = await "
        "createCommerceSubmissionHandlers.evaluateSellerReadiness"
    )
    if signature in text:
        print("[ok] readiness avant approbation déjà appliquée")
        return

    approval_start = text.find("exports.approveCommerceSubmission = onCall(")
    if approval_start < 0:
        raise SystemExit("[erreur] fonction approveCommerceSubmission introuvable")

    permission_text = "permissions du mod"
    permission_index = text.find(permission_text, approval_start)
    if permission_index < 0:
        raise SystemExit("[erreur] point d'insertion des permissions introuvable")

    line_start = text.rfind("\n", approval_start, permission_index) + 1
    guard = '''  // Revalide la capacité de reversement au dernier moment. Un compte Stripe
  // peut devenir non payable entre la soumission et la décision du modérateur.
  const sellerReadiness = await createCommerceSubmissionHandlers.evaluateSellerReadiness({
    db,
    uid: submission.ownerUid,
    ownerRole: submission.ownerRole,
  });
  if (!sellerReadiness.ready) {
    throw new HttpsError("failed-precondition", sellerReadiness.message, {
      code: sellerReadiness.code,
      message: sellerReadiness.message,
      actionRoute: sellerReadiness.actionRoute,
    });
  }

'''
    path.write_text(text[:line_start] + guard + text[line_start:], encoding="utf-8")
    print("[ok] readiness avant approbation appliquée")


if __name__ == "__main__":
    main()
