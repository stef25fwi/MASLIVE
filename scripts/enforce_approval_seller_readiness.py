#!/usr/bin/env python3
"""Ajoute la revalidation vendeur avant publication par un modérateur."""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def insert_before_once(path: Path, marker: str, insertion: str, signature: str, label: str) -> None:
    text = path.read_text(encoding="utf-8")
    if signature in text:
        print(f"[ok] {label} déjà appliqué")
        return
    count = text.count(marker)
    if count != 1:
        raise SystemExit(f"[erreur] {label}: attendu 1 marqueur, trouvé {count}")
    path.write_text(text.replace(marker, insertion + marker, 1), encoding="utf-8")
    print(f"[ok] {label}")


def insert_after_once(path: Path, marker: str, insertion: str, signature: str, label: str) -> None:
    text = path.read_text(encoding="utf-8")
    if signature in text:
        print(f"[ok] {label} déjà appliqué")
        return
    count = text.count(marker)
    if count != 1:
        raise SystemExit(f"[erreur] {label}: attendu 1 marqueur, trouvé {count}")
    path.write_text(text.replace(marker, marker + insertion, 1), encoding="utf-8")
    print(f"[ok] {label}")


def main() -> None:
    index = ROOT / "functions/index.js"
    insert_before_once(
        index,
        "  // Vérifier les permissions du modérateur",
        '''  // Revalide la capacité de reversement au dernier moment. Un compte Stripe
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

''',
        "const sellerReadiness = await createCommerceSubmissionHandlers.evaluateSellerReadiness",
        "readiness avant approbation",
    )

    tests = ROOT / "functions/test/commerce-submissions.test.js"
    insert_after_once(
        tests,
        "  assert.match(indexSource, /exports\\.submitCommerceForReview/);\n",
        "  assert.match(indexSource, /createCommerceSubmissionHandlers\\.evaluateSellerReadiness/);\n",
        "createCommerceSubmissionHandlers\\.evaluateSellerReadiness",
        "test du contrôle à l'approbation",
    )


if __name__ == "__main__":
    main()
