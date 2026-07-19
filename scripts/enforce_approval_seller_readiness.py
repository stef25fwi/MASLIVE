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

    marker = "  // Vérifier les permissions du modérateur"
    count = text.count(marker)
    if count != 1:
        raise SystemExit(
            f"[erreur] readiness avant approbation: marqueur trouvé {count} fois"
        )

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
    path.write_text(text.replace(marker, guard + marker, 1), encoding="utf-8")
    print("[ok] readiness avant approbation appliquée")


if __name__ == "__main__":
    main()
