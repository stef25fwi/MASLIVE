#!/usr/bin/env python3
"""Ferme le contournement ownerRole dans le parcours vendeur."""

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
    module = ROOT / "functions/src/commerce-submissions.js"

    replace_once(
        module,
        '''async function evaluateSellerReadiness({ db, uid, ownerRole }) {
  switch (normalizeLower(ownerRole)) {''',
        '''const MASTER_ROLES = new Set([
  "admin",
  "admin_master",
  "superadmin",
  "super-admin",
]);

const GROUP_ROLES = new Set([
  "group",
  "group-admin",
  "admin_group",
  "admin_groupe",
]);

function hasCreatorActivity(userData) {
  const activities = Array.isArray(userData?.activities)
    ? userData.activities.map(normalizeLower)
    : [];
  return activities.includes("createur_digital") ||
    activities.includes("creator_digital");
}

async function authorizeDeclaredOwnerRole({ db, uid, ownerRole }) {
  const declaredRole = normalizeLower(ownerRole);

  if (declaredRole === "compte_pro") {
    const business = await db.collection("businesses").doc(uid).get();
    return business.exists
      ? { ready: true, code: "ready", message: "", actionRoute: null }
      : readinessFailure(
        "business_profile_missing",
        "Créez votre compte professionnel avant de publier.",
        "/business"
      );
  }

  const userSnapshot = await db.collection("users").doc(uid).get();
  const userData = userSnapshot.exists ? (userSnapshot.data() || {}) : {};
  const authoritativeRole = normalizeLower(userData.role);

  if (declaredRole === "superadmin") {
    const isAuthorized = userData.isAdmin === true ||
      MASTER_ROLES.has(authoritativeRole);
    return isAuthorized
      ? { ready: true, code: "ready", message: "", actionRoute: null }
      : readinessFailure(
        "seller_role_mismatch",
        "Le rôle vendeur déclaré ne correspond pas à votre profil.",
        "/account"
      );
  }

  if (declaredRole === "admin_groupe") {
    return GROUP_ROLES.has(authoritativeRole)
      ? { ready: true, code: "ready", message: "", actionRoute: null }
      : readinessFailure(
        "seller_role_mismatch",
        "Le rôle vendeur déclaré ne correspond pas à votre profil groupe.",
        "/group-admin"
      );
  }

  if (declaredRole === "createur_digital") {
    return hasCreatorActivity(userData)
      ? { ready: true, code: "ready", message: "", actionRoute: null }
      : readinessFailure(
        "seller_role_mismatch",
        "Activez votre profil créateur avant de publier.",
        "/media-marketplace"
      );
  }

  return readinessFailure(
    "seller_role_not_allowed",
    "Votre profil n’autorise pas la publication de produits vendables.",
    "/account"
  );
}

async function evaluateSellerReadiness({ db, uid, ownerRole }) {
  const roleAuthorization = await authorizeDeclaredOwnerRole({
    db,
    uid,
    ownerRole,
  });
  if (!roleAuthorization.ready) return roleAuthorization;

  switch (normalizeLower(ownerRole)) {''',
        "autorisation autoritaire du rôle",
    )

    old_early_pending = '''    if (submission.status === "pending") {
      return {
        success: true,
        status: "pending",
        idempotent: true,
        readinessCode: "ready",
      };
    }
    if (submission.status !== "draft" && submission.status !== "rejected") {'''
    new_early_pending = '''    if (submission.status !== "draft" &&
        submission.status !== "rejected" &&
        submission.status !== "pending") {'''
    replace_once(module, old_early_pending, new_early_pending, "validation pending avant idempotence")

    old_after_readiness = '''    if (!readiness.ready) throwBusinessError(HttpsError, readiness);

    return db.runTransaction(async (transaction) => {'''
    new_after_readiness = '''    if (!readiness.ready) throwBusinessError(HttpsError, readiness);

    if (submission.status === "pending") {
      return {
        success: true,
        status: "pending",
        idempotent: true,
        readinessCode: readiness.code,
      };
    }

    return db.runTransaction(async (transaction) => {'''
    replace_once(module, old_after_readiness, new_after_readiness, "idempotence après readiness")

    old_fresh_owner = '''      if (fresh.ownerUid !== uid) {
        throw new HttpsError("permission-denied", "Not publication owner", {
          code: "submission_owner_mismatch",
          message: "Vous n’êtes pas propriétaire de cette publication.",
        });
      }
      if (fresh.status === "pending") {'''
    new_fresh_owner = '''      if (fresh.ownerUid !== uid) {
        throw new HttpsError("permission-denied", "Not publication owner", {
          code: "submission_owner_mismatch",
          message: "Vous n’êtes pas propriétaire de cette publication.",
        });
      }
      if (fresh.ownerRole !== submission.ownerRole) {
        throw new HttpsError("failed-precondition", "Seller role changed", {
          code: "seller_role_changed",
          message: "Le rôle vendeur a changé pendant la soumission. Réessayez.",
        });
      }
      validateSubmissionPayload(HttpsError, fresh);
      if (fresh.status === "pending") {'''
    replace_once(module, old_fresh_owner, new_fresh_owner, "stabilité transactionnelle du rôle")

    replace_once(
        module,
        '''module.exports.evaluateSellerReadiness = evaluateSellerReadiness;
module.exports.isStripePayable = isStripePayable;''',
        '''module.exports.evaluateSellerReadiness = evaluateSellerReadiness;
module.exports.authorizeDeclaredOwnerRole = authorizeDeclaredOwnerRole;
module.exports.isStripePayable = isStripePayable;''',
        "export du contrôle de rôle",
    )

    tests = ROOT / "functions/test/commerce-submissions.test.js"
    replace_once(
        tests,
        '''const {
  evaluateSellerReadiness,
  isStripePayable,
} = require("../src/commerce-submissions");''',
        '''const {
  authorizeDeclaredOwnerRole,
  evaluateSellerReadiness,
  isStripePayable,
} = require("../src/commerce-submissions");''',
        "import test contrôle de rôle",
    )

    replace_once(
        tests,
        '''function buildDb({ submission, business, photographer }) {''',
        '''function buildDb({ submission, business, photographer, user }) {''',
        "fixture utilisateur",
    )

    replace_once(
        tests,
        '''      if (name === "businesses") {
        return { doc: () => ({ get: async () => snapshot(business) }) };
      }
      if (name === "photographers") {''',
        '''      if (name === "businesses") {
        return { doc: () => ({ get: async () => snapshot(business) }) };
      }
      if (name === "users") {
        return { doc: () => ({ get: async () => snapshot(user) }) };
      }
      if (name === "photographers") {''',
        "collection users simulée",
    )

    insert_before_submission_test = '''test("submitCommerceForReview est propriétaire, payable et idempotent", async () => {'''
    spoof_test = '''test("authorizeDeclaredOwnerRole refuse un faux superadmin", async () => {
  const { db } = buildDb({
    user: { role: "user", isAdmin: false },
  });
  const result = await authorizeDeclaredOwnerRole({
    db,
    uid: "seller-1",
    ownerRole: "superadmin",
  });
  assert.equal(result.ready, false);
  assert.equal(result.code, "seller_role_mismatch");
});

test("submitCommerceForReview refuse un ownerRole administrateur usurpé", async () => {
  const { db } = buildDb({
    submission: {
      ownerUid: "seller-1",
      ownerRole: "superadmin",
      status: "draft",
      type: "product",
    },
    user: { role: "user", isAdmin: false },
  });
  const handlers = createCommerceSubmissionHandlers({
    admin: { firestore: { FieldValue: { serverTimestamp: () => null } } },
    db,
    HttpsError: FakeHttpsError,
    onCall: (_options, handler) => handler,
  });

  await assert.rejects(
    handlers.submitCommerceForReview({
      auth: { uid: "seller-1" },
      data: { submissionId: "submission-1" },
    }),
    (error) => error.code === "failed-precondition" &&
      error.details.code === "seller_role_mismatch"
  );
});

''' + insert_before_submission_test
    replace_once(tests, insert_before_submission_test, spoof_test, "tests anti-usurpation")

    replace_once(
        tests,
        '''  assert.match(rulesSource, /request\\.resource\\.data\\.status == resource\\.data\\.status/);
  assert.match(dartSource, /httpsCallable\\('submitCommerceForReview'\\)/);''',
        '''  assert.match(rulesSource, /request\\.resource\\.data\\.status == resource\\.data\\.status/);
  assert.match(rulesSource, /request\\.resource\\.data\\.ownerRole == resource\\.data\\.ownerRole/);
  assert.match(rulesSource, /canDeclareCommerceOwnerRole/);
  assert.match(dartSource, /httpsCallable\\('submitCommerceForReview'\\)/);''',
        "assertions de câblage rôle",
    )

    rules = ROOT / "firestore.rules"
    helper_anchor = '''      // Helper: vérifier si l'utilisateur peut modérer
      function canModerate() {'''
    role_helper = '''      function canDeclareCommerceOwnerRole(ownerRole) {
        return (
          ownerRole == 'superadmin' && isMasterAdmin()
        ) || (
          ownerRole == 'admin_groupe'
          && userRole() in [
            'group',
            'group-admin',
            'admin_group',
            'admin_groupe'
          ]
        ) || (
          ownerRole == 'createur_digital'
          && getUserData().keys().hasAny(['activities'])
          && getUserData().activities is list
          && getUserData().activities.hasAny([
            'createur_digital',
            'creator_digital'
          ])
        ) || (
          ownerRole == 'compte_pro'
          && exists(/databases/$(database)/documents/businesses/$(request.auth.uid))
        );
      }

''' + helper_anchor
    replace_once(rules, helper_anchor, role_helper, "rôle déclaré lié au profil")

    replace_once(
        rules,
        '''        && canSubmitCommerceDraft()
        && request.resource.data.ownerUid == request.auth.uid
        && request.resource.data.status == 'draft' ''',
        '''        && canSubmitCommerceDraft()
        && canDeclareCommerceOwnerRole(request.resource.data.ownerRole)
        && request.resource.data.ownerUid == request.auth.uid
        && request.resource.data.status == 'draft' ''',
        "contrôle ownerRole à la création",
    )

    replace_once(
        rules,
        '''        (resource.data.ownerUid == request.auth.uid
         && resource.data.status in ['draft', 'rejected']
         && request.resource.data.status == resource.data.status
         && !request.resource.data.diff(resource.data).affectedKeys().hasAny([''',
        '''        (resource.data.ownerUid == request.auth.uid
         && resource.data.status in ['draft', 'rejected']
         && request.resource.data.status == resource.data.status
         && request.resource.data.ownerUid == resource.data.ownerUid
         && request.resource.data.ownerRole == resource.data.ownerRole
         && request.resource.data.type == resource.data.type
         && request.resource.data.createdAt == resource.data.createdAt
         && !request.resource.data.diff(resource.data).affectedKeys().hasAny([''',
        "champs d'identité immuables",
    )

    print("Durcissement ownerRole appliqué.")


if __name__ == "__main__":
    main()
