"use strict"

const assert = require("node:assert/strict")
const test = require("node:test")

const createLifecycle = require("../src/photographer-subscription-lifecycle")

function document(data) {
  return {
    exists: true,
    data: () => data,
    set: async () => {},
  }
}

function harness({ ownerUid = "owner-1", authUid = "owner-1" } = {}) {
  const writes = []
  const stripeCalls = []
  const refs = {
    photographers: document({
      ownerUid,
      activeSubscriptionId: "sub-doc-1",
    }),
    photographer_subscriptions: document({
      ownerUid,
      stripeSubscriptionId: "sub_123",
      stripeCustomerId: "cus_123",
      status: "active",
    }),
  }

  for (const ref of Object.values(refs)) {
    ref.set = async (payload) => writes.push(payload)
  }

  const db = {
    collection: (name) => ({
      doc: () => refs[name],
    }),
  }

  const onCall = (_options, handler) => handler
  class HttpsError extends Error {
    constructor(code, message) {
      super(message)
      this.code = code
    }
  }
  const stripe = {
    billingPortal: {
      sessions: {
        create: async (payload) => {
          stripeCalls.push(["portal", payload])
          return { url: "https://billing.stripe.test/session" }
        },
      },
    },
    subscriptions: {
      update: async (id, payload, options) => {
        stripeCalls.push(["subscription", id, payload, options])
        return { id, status: "active", current_period_end: 123456 }
      },
    },
  }

  const handlers = createLifecycle({
    admin: {
      firestore: {
        FieldValue: { serverTimestamp: () => "server-time" },
      },
    },
    db,
    onCall,
    HttpsError,
    STRIPE_SECRET_KEY: "secret",
    getStripe: () => stripe,
    isAllowedRedirectUrl: (url) => url.startsWith("https://maslive.web.app/"),
  })

  const request = {
    auth: authUid ? { uid: authUid } : null,
    data: { photographerId: "photographer-1" },
  }

  return { handlers, request, stripeCalls, writes }
}

test("refuse un appel non authentifié", async () => {
  const { handlers, request } = harness({ authUid: "" })
  await assert.rejects(
    handlers.cancelPhotographerSubscription(request),
    (error) => error.code === "unauthenticated",
  )
})

test("refuse de gérer l'abonnement d'un autre photographe", async () => {
  const { handlers, request } = harness({ ownerUid: "owner-2" })
  await assert.rejects(
    handlers.resumePhotographerSubscription(request),
    (error) => error.code === "permission-denied",
  )
})

test("crée un portail de facturation avec retour MASLIVE", async () => {
  const { handlers, request, stripeCalls } = harness()
  const result = await handlers.createPhotographerBillingPortalLink(request)
  assert.equal(result.url, "https://billing.stripe.test/session")
  assert.equal(stripeCalls[0][0], "portal")
  assert.equal(
    stripeCalls[0][1].return_url,
    "https://maslive.web.app/#/media-marketplace/subscription",
  )
})

test("programme l'annulation en fin de période", async () => {
  const { handlers, request, stripeCalls, writes } = harness()
  const result = await handlers.cancelPhotographerSubscription(request)
  assert.equal(result.cancelAtPeriodEnd, true)
  assert.equal(stripeCalls[0][2].cancel_at_period_end, true)
  assert.equal(writes[0].cancelAtPeriodEnd, true)
})

test("réactive un abonnement avec une action idempotente", async () => {
  const { handlers, request, stripeCalls, writes } = harness()
  const result = await handlers.resumePhotographerSubscription(request)
  assert.equal(result.cancelAtPeriodEnd, false)
  assert.equal(stripeCalls[0][2].cancel_at_period_end, false)
  assert.match(stripeCalls[0][3].idempotencyKey, /photographer_resume_sub_123/)
  assert.equal(writes[0].cancelAtPeriodEnd, false)
})
