const test = require("node:test")
const assert = require("node:assert/strict")

const createMediaMarketplaceStripe = require("../src/media-marketplace-stripe")

function createFakeDb(initial = {}) {
  const store = new Map(Object.entries(initial))

  class DocRef {
    constructor(path) {
      this.path = path
      this.id = path.split("/").pop()
    }

    async get() {
      const value = store.get(this.path)
      return {
        exists: value != null,
        id: this.id,
        ref: this,
        data: () => (value == null ? undefined : { ...value }),
      }
    }

    async set(data, options = {}) {
      const previous = store.get(this.path) || {}
      if (options.merge) {
        store.set(this.path, { ...previous, ...data })
      } else {
        store.set(this.path, { ...data })
      }
    }
  }

  class CollectionRef {
    constructor(name) {
      this.name = name
      this._filters = []
      this._limit = null
    }

    doc(id) {
      const docId = id || `auto_${Math.random().toString(36).slice(2, 10)}`
      return new DocRef(`${this.name}/${docId}`)
    }

    where(field, op, value) {
      const next = new CollectionRef(this.name)
      next._filters = [...this._filters, { field, op, value }]
      next._limit = this._limit
      return next
    }

    limit(n) {
      const next = new CollectionRef(this.name)
      next._filters = [...this._filters]
      next._limit = n
      return next
    }

    async get() {
      let docs = []
      for (const [path, data] of store.entries()) {
        if (!path.startsWith(`${this.name}/`)) continue
        const id = path.slice(this.name.length + 1)
        const ok = this._filters.every(({ field, op, value }) => {
          const got = data?.[field]
          if (op === "==") return got === value
          if (op === "in") return Array.isArray(value) && value.includes(got)
          return false
        })
        if (!ok) continue
        const ref = new DocRef(path)
        docs.push({ id, ref, data: () => ({ ...data }) })
      }

      if (typeof this._limit === "number") {
        docs = docs.slice(0, this._limit)
      }

      return {
        empty: docs.length === 0,
        docs,
      }
    }
  }

  return {
    collection(name) {
      return new CollectionRef(name)
    },
    batch() {
      const ops = []
      return {
        set(ref, data, options = {}) {
          ops.push({ ref, data, options })
        },
        async commit() {
          for (const op of ops) {
            await op.ref.set(op.data, op.options)
          }
        },
      }
    },
    _store: store,
  }
}

function createStripeModule(db) {
  const admin = {
    firestore: {
      FieldValue: {
        serverTimestamp: () => "__ts__",
      },
      Timestamp: {
        fromMillis: (ms) => ({ _ms: ms, toDate: () => new Date(ms) }),
      },
    },
  }

  const onCall = (_opts, handler) => handler

  const deps = {
    admin,
    db,
    onCall,
    HttpsError: class extends Error {
      constructor(code, message) {
        super(message)
        this.code = code
      }
    },
    STRIPE_SECRET_KEY: {},
    getStripe: () => ({
      subscriptions: {
        retrieve: async () => ({ id: "sub_1", metadata: {} }),
      },
      checkout: {
        sessions: {
          create: async () => ({ id: "cs_1", url: "https://example.test", customer: "cus_1" }),
        },
      },
    }),
    isAllowedRedirectUrl: () => true,
  }

  return createMediaMarketplaceStripe(deps)
}

test("marketplace fulfillment is blocked when checkout session is not paid", async () => {
  const db = createFakeDb({
    "orders/order_1": {
      orderId: "order_1",
      metadata: { kind: "media_marketplace_order" },
      subtotal: 10,
      stripeFee: 1,
      currency: "EUR",
      items: [
        {
          assetId: "photo_1",
          assetType: "photo",
          photographerId: "p_1",
          lineSubtotal: 10,
          currency: "EUR",
          pricingSnapshot: { commissionRate: 0.1 },
          photoIds: ["photo_1"],
        },
      ],
    },
  })

  const stripeModule = createStripeModule(db)
  const fulfilled = await stripeModule.handleMarketplaceCheckoutSessionCompleted({
    id: "cs_test_unpaid",
    payment_status: "unpaid",
    metadata: {
      kind: "media_marketplace_order",
      orderId: "order_1",
      uid: "buyer_1",
    },
  })

  assert.equal(fulfilled, false)
  assert.equal(db._store.has("media_entitlements/order_1_photo_1"), false)
  assert.equal(db._store.has("payout_ledger/order_1_photo_1"), false)
})

test("marketplace fulfillment is idempotent on webhook replay", async () => {
  const db = createFakeDb({
    "orders/order_2": {
      orderId: "order_2",
      metadata: { kind: "media_marketplace_order" },
      subtotal: 10,
      stripeFee: 1,
      currency: "EUR",
      items: [
        {
          assetId: "photo_2",
          assetType: "photo",
          photographerId: "p_2",
          lineSubtotal: 10,
          currency: "EUR",
          pricingSnapshot: { commissionRate: 0.1 },
          photoIds: ["photo_2"],
        },
      ],
    },
  })

  const stripeModule = createStripeModule(db)
  const event = {
    id: "cs_test_paid",
    payment_status: "paid",
    payment_intent: "pi_1",
    customer: "cus_1",
    metadata: {
      kind: "media_marketplace_order",
      orderId: "order_2",
      uid: "buyer_2",
    },
  }

  const first = await stripeModule.handleMarketplaceCheckoutSessionCompleted(event)
  const second = await stripeModule.handleMarketplaceCheckoutSessionCompleted(event)

  assert.equal(first, true)
  assert.equal(second, true)

  const entitlementKeys = Array.from(db._store.keys()).filter((k) => k.startsWith("media_entitlements/"))
  const payoutKeys = Array.from(db._store.keys()).filter((k) => k.startsWith("payout_ledger/"))

  assert.equal(entitlementKeys.length, 1)
  assert.equal(payoutKeys.length, 1)
})
