"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");

const createCommerceSubmissionHandlers = require("../src/commerce-submissions");
const {
  authorizeDeclaredOwnerRole,
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

function buildDb({ submission, business, photographer, user }) {
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
      if (name === "users") {
        return { doc: () => ({ get: async () => snapshot(user) }) };
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

test("evaluateSellerReadiness bloque un créateur refusé", async () => {
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

test("authorizeDeclaredOwnerRole refuse un faux superadmin", async () => {
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
  assert.match(indexSource, /createCommerceSubmissionHandlers\.evaluateSellerReadiness/);
  assert.match(rulesSource, /request\.resource\.data\.status == 'draft'/);
  assert.match(rulesSource, /request\.resource\.data\.status == resource\.data\.status/);
  assert.match(rulesSource, /request\.resource\.data\.ownerRole == resource\.data\.ownerRole/);
  assert.match(rulesSource, /canDeclareCommerceOwnerRole/);
  assert.match(dartSource, /httpsCallable\('submitCommerceForReview'\)/);
});
