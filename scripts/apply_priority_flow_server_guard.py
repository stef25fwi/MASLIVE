#!/usr/bin/env python3
"""Applique de façon idempotente le garde serveur du parcours vendeur."""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def replace_once(path: Path, old: str, new: str, label: str) -> None:
    text = path.read_text(encoding="utf-8")
    if new in text:
        print(f"[ok] {label} déjà appliqué")
        return
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"[erreur] marqueur {label}: attendu 1, trouvé {count}")
    path.write_text(text.replace(old, new, 1), encoding="utf-8")
    print(f"[ok] {label}")


COMMERCE_MODULE = r'''"use strict";

const SUBMISSION_GUARD_VERSION = "2026-07-19-v1";

function normalizeString(value) {
  return typeof value === "string" ? value.trim() : "";
}

function normalizeLower(value) {
  return normalizeString(value).toLowerCase();
}

function readinessFailure(code, message, actionRoute = null) {
  return { ready: false, code, message, actionRoute };
}

function isStripePayable(stripe) {
  const data = stripe && typeof stripe === "object" ? stripe : {};
  return normalizeString(data.accountId).length > 0 &&
    data.detailsSubmitted === true &&
    data.chargesEnabled === true &&
    data.payoutsEnabled === true;
}

async function evaluateSellerReadiness({ db, uid, ownerRole }) {
  switch (normalizeLower(ownerRole)) {
    case "superadmin":
    case "admin_groupe":
      return { ready: true, code: "ready", message: "", actionRoute: null };

    case "compte_pro": {
      const snapshot = await db.collection("businesses").doc(uid).get();
      const data = snapshot.exists ? (snapshot.data() || {}) : null;
      if (!data) {
        return readinessFailure(
          "business_profile_missing",
          "Créez votre compte professionnel et renseignez votre identité/SIRET avant de publier.",
          "/business"
        );
      }

      const status = normalizeLower(data.status || "pending");
      const siret = normalizeString(data.siret);
      if (!siret || (status !== "approved" && status !== "active")) {
        return readinessFailure(
          "business_verification_required",
          "Votre identité et votre SIRET doivent être validés avant la publication.",
          "/business"
        );
      }
      if (!isStripePayable(data.stripe)) {
        return readinessFailure(
          "stripe_connect_not_payable",
          "Finalisez Stripe Connect : le compte doit autoriser les encaissements et les virements avant de publier.",
          "/business"
        );
      }
      return { ready: true, code: "ready", message: "", actionRoute: null };
    }

    case "createur_digital": {
      const query = await db.collection("photographers")
        .where("ownerUid", "==", uid)
        .limit(1)
        .get();
      if (query.empty) {
        return readinessFailure(
          "photographer_profile_missing",
          "Créez et faites valider votre profil créateur avant de publier.",
          "/media-marketplace"
        );
      }

      const data = query.docs[0].data() || {};
      if (normalizeLower(data.status || "pending") !== "approved") {
        return readinessFailure(
          "photographer_verification_required",
          "Votre profil créateur doit être validé avant la publication.",
          "/media-marketplace"
        );
      }
      if (!isStripePayable(data.stripe)) {
        return readinessFailure(
          "stripe_connect_not_payable",
          "Finalisez Stripe Connect : les encaissements et les virements doivent être actifs avant de publier.",
          "/media-marketplace"
        );
      }
      return { ready: true, code: "ready", message: "", actionRoute: null };
    }

    default:
      return readinessFailure(
        "seller_role_not_allowed",
        "Votre profil n’autorise pas la publication de produits vendables.",
        "/account"
      );
  }
}

function throwBusinessError(HttpsError, readiness) {
  throw new HttpsError("failed-precondition", readiness.message, {
    code: readiness.code,
    message: readiness.message,
    actionRoute: readiness.actionRoute,
  });
}

function validateSubmissionPayload(HttpsError, submission) {
  if (submission.type !== "media") return;

  if (!normalizeString(submission.countryId) ||
      !normalizeString(submission.eventId) ||
      !normalizeString(submission.circuitId)) {
    throw new HttpsError(
      "failed-precondition",
      "Pays, événement et circuit sont obligatoires pour un média.",
      {
        code: "media_context_required",
        message: "Pays, événement et circuit sont obligatoires pour un média.",
        actionRoute: "/commerce/create-media",
      }
    );
  }

  const price = Number(submission.price);
  if (!Number.isFinite(price) || price <= 0) {
    throw new HttpsError(
      "failed-precondition",
      "Le prix du média doit être supérieur à 0.",
      {
        code: "media_price_required",
        message: "Le prix du média doit être supérieur à 0.",
        actionRoute: "/commerce/create-media",
      }
    );
  }
}

function createCommerceSubmissionHandlers({ admin, db, onCall, HttpsError }) {
  async function submitCommerceForReviewImpl({ uid, submissionId }) {
    if (!uid) {
      throw new HttpsError("unauthenticated", "Utilisateur non connecté", {
        code: "authentication_required",
        message: "Connectez-vous avant de publier.",
        actionRoute: "/login",
      });
    }

    const normalizedSubmissionId = normalizeString(submissionId);
    if (!normalizedSubmissionId) {
      throw new HttpsError("invalid-argument", "submissionId est obligatoire", {
        code: "submission_id_required",
        message: "Publication introuvable.",
      });
    }

    const ref = db.collection("commerce_submissions").doc(normalizedSubmissionId);
    const snapshot = await ref.get();
    if (!snapshot.exists) {
      throw new HttpsError("not-found", "Submission not found", {
        code: "submission_not_found",
        message: "Publication introuvable.",
      });
    }

    const submission = snapshot.data() || {};
    if (submission.ownerUid !== uid) {
      throw new HttpsError("permission-denied", "Not publication owner", {
        code: "submission_owner_mismatch",
        message: "Vous n’êtes pas propriétaire de cette publication.",
      });
    }

    if (submission.status === "pending") {
      return {
        success: true,
        status: "pending",
        idempotent: true,
        readinessCode: "ready",
      };
    }
    if (submission.status !== "draft" && submission.status !== "rejected") {
      throw new HttpsError("failed-precondition", "Invalid submission status", {
        code: "submission_status_invalid",
        message: `La publication ne peut pas être soumise depuis l’état ${submission.status || "inconnu"}.`,
      });
    }

    validateSubmissionPayload(HttpsError, submission);
    const readiness = await evaluateSellerReadiness({
      db,
      uid,
      ownerRole: submission.ownerRole,
    });
    if (!readiness.ready) throwBusinessError(HttpsError, readiness);

    return db.runTransaction(async (transaction) => {
      const freshSnapshot = await transaction.get(ref);
      if (!freshSnapshot.exists) {
        throw new HttpsError("not-found", "Submission not found", {
          code: "submission_not_found",
          message: "Publication introuvable.",
        });
      }

      const fresh = freshSnapshot.data() || {};
      if (fresh.ownerUid !== uid) {
        throw new HttpsError("permission-denied", "Not publication owner", {
          code: "submission_owner_mismatch",
          message: "Vous n’êtes pas propriétaire de cette publication.",
        });
      }
      if (fresh.status === "pending") {
        return {
          success: true,
          status: "pending",
          idempotent: true,
          readinessCode: "ready",
        };
      }
      if (fresh.status !== "draft" && fresh.status !== "rejected") {
        throw new HttpsError("failed-precondition", "Invalid submission status", {
          code: "submission_status_invalid",
          message: `La publication ne peut pas être soumise depuis l’état ${fresh.status || "inconnu"}.`,
        });
      }

      transaction.update(ref, {
        status: "pending",
        submittedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        submissionGuard: {
          version: SUBMISSION_GUARD_VERSION,
          readinessCode: "ready",
          checkedOwnerUid: uid,
        },
      });

      return {
        success: true,
        status: "pending",
        idempotent: false,
        readinessCode: "ready",
      };
    });
  }

  return {
    submitCommerceForReview: onCall(
      {
        region: "us-east1",
        cpu: 0.083,
        memory: "256MiB",
        timeoutSeconds: 30,
        maxInstances: 10,
      },
      async (request) => submitCommerceForReviewImpl({
        uid: request.auth?.uid,
        submissionId: request.data?.submissionId,
      })
    ),
    submitCommerceForReviewImpl,
  };
}

module.exports = createCommerceSubmissionHandlers;
module.exports.evaluateSellerReadiness = evaluateSellerReadiness;
module.exports.isStripePayable = isStripePayable;
module.exports.SUBMISSION_GUARD_VERSION = SUBMISSION_GUARD_VERSION;
'''


COMMERCE_TEST = r'''"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");

const createCommerceSubmissionHandlers = require("../src/commerce-submissions");
const {
  evaluateSellerReadiness,
  isStripePayable,
} = require("../src/commerce-submissions");

class FakeHttpsError extends Error {
  constructor(code, message, details) {
    super(message);
    this.code = code;
    this.details = details;
  }
}

function snapshot(data) {
  return {
    exists: data != null,
    data: () => data,
  };
}

function buildDb({ submission, business, photographer }) {
  const state = { submission: submission ? { ...submission } : null };
  const submissionRef = {
    get: async () => snapshot(state.submission),
  };

  const db = {
    collection(name) {
      if (name === "commerce_submissions") {
        return { doc: () => submissionRef };
      }
      if (name === "businesses") {
        return { doc: () => ({ get: async () => snapshot(business) }) };
      }
      if (name === "photographers") {
        return {
          where() {
            return {
              limit() {
                return {
                  get: async () => ({
                    empty: !photographer,
                    docs: photographer ? [{ data: () => photographer }] : [],
                  }),
                };
              },
            };
          },
        };
      }
      throw new Error(`Unexpected collection ${name}`);
    },
    async runTransaction(callback) {
      return callback({
        get: async () => snapshot(state.submission),
        update: (_ref, patch) => {
          state.submission = { ...state.submission, ...patch };
        },
      });
    },
  };

  return { db, state };
}

const payableStripe = {
  accountId: "acct_ready",
  detailsSubmitted: true,
  chargesEnabled: true,
  payoutsEnabled: true,
};

test("isStripePayable exige encaissements et virements", () => {
  assert.equal(isStripePayable(payableStripe), true);
  assert.equal(isStripePayable({ ...payableStripe, payoutsEnabled: false }), false);
  assert.equal(isStripePayable({ ...payableStripe, accountId: "" }), false);
});

test("evaluateSellerReadiness valide un compte pro payable", async () => {
  const { db } = buildDb({
    business: {
      status: "approved",
      siret: "12345678901234",
      stripe: payableStripe,
    },
  });
  const result = await evaluateSellerReadiness({
    db,
    uid: "seller-1",
    ownerRole: "compte_pro",
  });
  assert.equal(result.ready, true);
  assert.equal(result.code, "ready");
});

test("evaluateSellerReadiness bloque les virements Stripe désactivés", async () => {
  const { db } = buildDb({
    business: {
      status: "approved",
      siret: "12345678901234",
      stripe: { ...payableStripe, payoutsEnabled: false },
    },
  });
  const result = await evaluateSellerReadiness({
    db,
    uid: "seller-1",
    ownerRole: "compte_pro",
  });
  assert.equal(result.ready, false);
  assert.equal(result.code, "stripe_connect_not_payable");
});

test("submitCommerceForReview est propriétaire, payable et idempotent", async () => {
  const { db, state } = buildDb({
    submission: {
      ownerUid: "seller-1",
      ownerRole: "compte_pro",
      status: "draft",
      type: "product",
    },
    business: {
      status: "active",
      siret: "12345678901234",
      stripe: payableStripe,
    },
  });
  const admin = {
    firestore: {
      FieldValue: { serverTimestamp: () => "SERVER_TIMESTAMP" },
    },
  };
  const handlers = createCommerceSubmissionHandlers({
    admin,
    db,
    HttpsError: FakeHttpsError,
    onCall: (_options, handler) => handler,
  });

  const first = await handlers.submitCommerceForReview({
    auth: { uid: "seller-1" },
    data: { submissionId: "submission-1" },
  });
  assert.equal(first.idempotent, false);
  assert.equal(state.submission.status, "pending");
  assert.equal(state.submission.submissionGuard.readinessCode, "ready");

  const second = await handlers.submitCommerceForReview({
    auth: { uid: "seller-1" },
    data: { submissionId: "submission-1" },
  });
  assert.equal(second.idempotent, true);
});

test("submitCommerceForReview refuse l’usurpation du propriétaire", async () => {
  const { db } = buildDb({
    submission: {
      ownerUid: "seller-1",
      ownerRole: "compte_pro",
      status: "draft",
      type: "product",
    },
  });
  const handlers = createCommerceSubmissionHandlers({
    admin: { firestore: { FieldValue: { serverTimestamp: () => null } } },
    db,
    HttpsError: FakeHttpsError,
    onCall: (_options, handler) => handler,
  });

  await assert.rejects(
    handlers.submitCommerceForReview({
      auth: { uid: "attacker" },
      data: { submissionId: "submission-1" },
    }),
    (error) => error.code === "permission-denied" &&
      error.details.code === "submission_owner_mismatch"
  );
});

test("le câblage interdit la transition client directe vers pending", () => {
  const root = path.resolve(__dirname, "../..");
  const indexSource = fs.readFileSync(path.join(root, "functions/index.js"), "utf8");
  const rulesSource = fs.readFileSync(path.join(root, "firestore.rules"), "utf8");
  const dartSource = fs.readFileSync(
    path.join(root, "app/lib/services/commerce/commerce_service.dart"),
    "utf8"
  );

  assert.match(indexSource, /exports\.submitCommerceForReview/);
  assert.match(rulesSource, /request\.resource\.data\.status == 'draft'/);
  assert.match(rulesSource, /request\.resource\.data\.status == resource\.data\.status/);
  assert.match(dartSource, /httpsCallable\('submitCommerceForReview'\)/);
});
'''


def main() -> None:
    functions_index = ROOT / "functions" / "index.js"
    replace_once(
        functions_index,
        'const createBloomArtHandlers = require("./src/bloom-art");\n',
        'const createBloomArtHandlers = require("./src/bloom-art");\n'
        'const createCommerceSubmissionHandlers = require("./src/commerce-submissions");\n',
        "import function commerce",
    )

    bloom_factory = '''const bloomArtHandlers = createBloomArtHandlers({
  admin,
  db,
  onCall,
  HttpsError,
  STRIPE_SECRET_KEY,
  getStripe,
  isAllowedRedirectUrl,
  resolveStripeConnectCountry,
});'''
    replace_once(
        functions_index,
        bloom_factory,
        bloom_factory + '''
const commerceSubmissionHandlers = createCommerceSubmissionHandlers({
  admin,
  db,
  onCall,
  HttpsError,
});''',
        "initialisation function commerce",
    )
    replace_once(
        functions_index,
        'exports.verifyBloomArtSiret = bloomArtHandlers.verifyBloomArtSiret;\n',
        'exports.verifyBloomArtSiret = bloomArtHandlers.verifyBloomArtSiret;\n'
        'exports.submitCommerceForReview =\n'
        '  commerceSubmissionHandlers.submitCommerceForReview;\n',
        "export callable commerce",
    )

    commerce_service = ROOT / "app" / "lib" / "services" / "commerce" / "commerce_service.dart"
    direct_update = '''    await _submissions.doc(submissionId).update({
      'status': SubmissionStatus.pending.toJson(),
      'submittedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });'''
    callable_update = '''    try {
      final callable = _functions.httpsCallable('submitCommerceForReview');
      await callable.call(<String, dynamic>{'submissionId': submissionId});
    } on FirebaseFunctionsException catch (error) {
      final details = error.details;
      final detailsMessage = details is Map ? details['message'] : null;
      throw StateError(
        detailsMessage is String && detailsMessage.trim().isNotEmpty
            ? detailsMessage
            : error.message ??
                  'Impossible de vérifier votre capacité de reversement.',
      );
    }'''
    replace_once(
        commerce_service,
        direct_update,
        callable_update,
        "appel callable Flutter",
    )

    rules = ROOT / "firestore.rules"
    old_can_submit = '''      // Helper: vérifier si l'utilisateur peut soumettre du commerce
      function canSubmitCommerce() {
        return hasUserDoc() && (
          isMasterAdmin()
          || userRole() == 'group'
          || userRole() == 'group-admin'
          || userRole() == 'admin_group'
          || userRole() == 'admin_groupe'
          || userRole() == 'superAdmin'
          || userRole() == 'superadmin'
        );
      }'''
    new_can_submit = '''      // Les vendeurs légitimes peuvent créer et modifier des brouillons.
      // La transition vers pending est exclusivement réalisée par la callable
      // submitCommerceForReview avec l'Admin SDK après contrôle du reversement.
      function canSubmitCommerceDraft() {
        return hasUserDoc() && (
          isMasterAdmin()
          || userRole() == 'group'
          || userRole() == 'group-admin'
          || userRole() == 'admin_group'
          || userRole() == 'admin_groupe'
          || userRole() == 'superAdmin'
          || userRole() == 'superadmin'
          || (
            getUserData().keys().hasAny(['activities'])
            && getUserData().activities is list
            && getUserData().activities.hasAny([
              'createur_digital',
              'creator_digital'
            ])
          )
          || exists(/databases/$(database)/documents/businesses/$(request.auth.uid))
        );
      }'''
    replace_once(rules, old_can_submit, new_can_submit, "rôles brouillon commerce")

    old_create = '''      // Création:
      // - Utilisateur autorisé avec un rôle valide
      // - Doit définir ownerUid = request.auth.uid
      // - Statut initial = 'draft' ou 'pending'
      allow create: if isSignedIn() 
        && canSubmitCommerce()
        && request.resource.data.ownerUid == request.auth.uid
        && request.resource.data.status in ['draft', 'pending']
        && !request.resource.data.keys().hasAny(['moderatedBy', 'moderatedAt', 'publishedRef']);'''
    new_create = '''      // Le client ne peut créer qu'un brouillon. Toute soumission à la
      // modération passe par la callable serveur après vérification Stripe.
      allow create: if isSignedIn()
        && canSubmitCommerceDraft()
        && request.resource.data.ownerUid == request.auth.uid
        && request.resource.data.status == 'draft'
        && !request.resource.data.keys().hasAny([
          'moderatedBy',
          'moderatedAt',
          'publishedRef',
          'submittedAt',
          'submissionGuard'
        ]);'''
    replace_once(rules, old_create, new_create, "création brouillon uniquement")

    old_owner_update = '''        (resource.data.ownerUid == request.auth.uid
         && resource.data.status in ['draft', 'rejected']
         && !request.resource.data.diff(resource.data).affectedKeys().hasAny(['moderatedBy', 'moderatedAt', 'publishedRef'])
         && request.resource.data.status != 'approved')'''
    new_owner_update = '''        (resource.data.ownerUid == request.auth.uid
         && resource.data.status in ['draft', 'rejected']
         && request.resource.data.status == resource.data.status
         && !request.resource.data.diff(resource.data).affectedKeys().hasAny([
           'moderatedBy',
           'moderatedAt',
           'publishedRef',
           'submittedAt',
           'submissionGuard'
         ]))'''
    replace_once(rules, old_owner_update, new_owner_update, "transition pending interdite au client")

    module_path = ROOT / "functions" / "src" / "commerce-submissions.js"
    module_path.write_text(COMMERCE_MODULE, encoding="utf-8")
    print(f"[ok] écrit {module_path.relative_to(ROOT)}")

    test_path = ROOT / "functions" / "test" / "commerce-submissions.test.js"
    test_path.write_text(COMMERCE_TEST, encoding="utf-8")
    print(f"[ok] écrit {test_path.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
