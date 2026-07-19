#!/usr/bin/env python3
"""Ajoute la revalidation vendeur avant publication par un modérateur."""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def replace_once(path: Path, old: str, new: str, label: str) -> None:
    text = path.read_text(encoding="utf-8")
    if new in text:
        print(f"[ok] {label} déjà appliqué")
        return
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"[erreur] {label}: attendu 1 marqueur, trouvé {count}")
    path.write_text(text.replace(old, new, 1), encoding="utf-8")
    print(f"[ok] {label}")


def main() -> None:
    index = ROOT / "functions/index.js"
    anchor = '''  if (submission.status !== "pending") {
    throw new HttpsError("failed-precondition", `Submission status is ${submission.status}, must be pending`);
  }

  // Vérifier les permissions du modérateur'''
    replacement = '''  if (submission.status !== "pending") {
    throw new HttpsError("failed-precondition", `Submission status is ${submission.status}, must be pending`);
  }

  // Revalide la capacité de reversement au dernier moment. Un compte Stripe
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

  // Vérifier les permissions du modérateur'''
    replace_once(index, anchor, replacement, "readiness avant approbation")

    tests = ROOT / "functions/test/commerce-submissions.test.js"
    old = '''  assert.match(indexSource, /exports\\.submitCommerceForReview/);
  assert.match(rulesSource, /request\\.resource\\.data\\.status == 'draft'/);'''
    new = '''  assert.match(indexSource, /exports\\.submitCommerceForReview/);
  assert.match(
    indexSource,
    /createCommerceSubmissionHandlers\\.evaluateSellerReadiness/
  );
  assert.match(rulesSource, /request\\.resource\\.data\\.status == 'draft'/);'''
    replace_once(tests, old, new, "test du contrôle à l'approbation")


if __name__ == "__main__":
    main()
