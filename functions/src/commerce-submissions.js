"use strict";

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

const MASTER_ROLES = new Set([
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

    if (submission.status !== "draft" &&
        submission.status !== "rejected" &&
        submission.status !== "pending") {
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

    if (submission.status === "pending") {
      return {
        success: true,
        status: "pending",
        idempotent: true,
        readinessCode: readiness.code,
      };
    }

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
      if (fresh.ownerRole !== submission.ownerRole) {
        throw new HttpsError("failed-precondition", "Seller role changed", {
          code: "seller_role_changed",
          message: "Le rôle vendeur a changé pendant la soumission. Réessayez.",
        });
      }
      validateSubmissionPayload(HttpsError, fresh);
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
module.exports.authorizeDeclaredOwnerRole = authorizeDeclaredOwnerRole;
module.exports.isStripePayable = isStripePayable;
module.exports.SUBMISSION_GUARD_VERSION = SUBMISSION_GUARD_VERSION;
