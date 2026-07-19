#!/usr/bin/env python3
"""Finalise l'ordre d'autorisation et la couverture Functions vendeur."""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def main() -> None:
    index_path = ROOT / "functions/index.js"
    text = index_path.read_text(encoding="utf-8")
    approval_start = text.find("exports.approveCommerceSubmission = onCall(")
    if approval_start < 0:
        raise SystemExit("approveCommerceSubmission introuvable")

    guard_start = text.find("  // Revalide la capacité de reversement", approval_start)
    permission_marker = text.find("  // Vérifier les permissions du modérateur", approval_start)
    target_marker = text.find("  // Déterminer la collection cible", approval_start)
    if guard_start < 0 or permission_marker < 0 or target_marker < 0:
        raise SystemExit("structure approveCommerceSubmission inattendue")

    if guard_start < permission_marker:
        guard = text[guard_start:permission_marker]
        text = text[:guard_start] + text[permission_marker:]
        approval_start = text.find("exports.approveCommerceSubmission = onCall(")
        target_marker = text.find("  // Déterminer la collection cible", approval_start)
        text = text[:target_marker] + guard + text[target_marker:]
        index_path.write_text(text, encoding="utf-8")
        print("[ok] readiness déplacée après autorisation modérateur")
    else:
        print("[ok] ordre autorisation/readiness déjà sécurisé")

    test_path = ROOT / "functions/test/commerce-submissions.test.js"
    tests = test_path.read_text(encoding="utf-8")

    creator_signature = 'test("evaluateSellerReadiness bloque un créateur refusé"'
    if creator_signature not in tests:
        marker = 'test("authorizeDeclaredOwnerRole refuse un faux superadmin", async () => {'
        if tests.count(marker) != 1:
            raise SystemExit("marqueur test créateur ambigu")
        creator_test = '''test("evaluateSellerReadiness bloque un créateur refusé", async () => {
  const { db } = buildDb({
    user: { role: "user", activities: ["createur_digital"] },
    photographer: {
      ownerUid: "creator-1",
      status: "rejected",
      stripe: payableStripe,
    },
  });
  const result = await evaluateSellerReadiness({
    db,
    uid: "creator-1",
    ownerRole: "createur_digital",
  });
  assert.equal(result.ready, false);
  assert.equal(result.code, "photographer_verification_required");
});

'''
        tests = tests.replace(marker, creator_test + marker, 1)
        print("[ok] test créateur refusé ajouté")

    wiring_signature = "createCommerceSubmissionHandlers\\.evaluateSellerReadiness"
    if wiring_signature not in tests:
        marker = '  assert.match(indexSource, /exports\\.submitCommerceForReview/);\n'
        if tests.count(marker) != 1:
            raise SystemExit("marqueur câblage approbation ambigu")
        assertion = (
            "  assert.match(indexSource, "
            "/createCommerceSubmissionHandlers\\.evaluateSellerReadiness/);\n"
        )
        tests = tests.replace(marker, marker + assertion, 1)
        print("[ok] assertion câblage approbation ajoutée")

    test_path.write_text(tests, encoding="utf-8")


if __name__ == "__main__":
    main()
