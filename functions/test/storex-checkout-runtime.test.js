const test = require("node:test")
const assert = require("node:assert/strict")
const path = require("node:path")
const Module = require("node:module")

// Regression test for the production incident of 2026-07-18: every Storex
// checkout ("Payment error: [firebase_functions/internal] INTERNAL") failed
// because assertHttpsUrlOrDefault was called in index.js but never defined
// there (it only existed as a local helper inside src/media-marketplace-stripe.js
// and src/bloom-art.js). This test loads the REAL index.js (not a stub) with
// Firestore/Stripe/onCall mocked out, and actually invokes the real
// createStorexCheckoutSession handler end-to-end, so it fails loudly again if
// this class of "used but never defined" bug reappears.

function createFakeFirestore() {
  const store = new Map()

  function normalize(data) {
    const out = {}
    for (const [key, value] of Object.entries(data || {})) {
      if (value && typeof value === "object" && value.__isServerTimestamp) {
        out[key] = "__SERVER_TIMESTAMP__"
      } else {
        out[key] = value
      }
    }
    return out
  }

  class DocRef {
    constructor(path) {
      this.path = path
      this.id = path.split("/").pop()
    }

    collection(name) {
      return new CollectionRef(`${this.path}/${name}`)
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
      const next = normalize(data)
      store.set(this.path, options.merge ? { ...previous, ...next } : next)
    }

    async update(data) {
      const previous = store.get(this.path) || {}
      store.set(this.path, { ...previous, ...normalize(data) })
    }
  }

  class CollectionRef {
    constructor(name) {
      this.name = name
      this._filters = []
    }

    doc(id) {
      const docId = id || `auto_${Math.random().toString(36).slice(2, 10)}`
      return new DocRef(`${this.name}/${docId}`)
    }

    where(field, op, value) {
      const next = new CollectionRef(this.name)
      next._filters = [...this._filters, { field, op, value }]
      return next
    }

    async get() {
      const docs = []
      for (const [docPath, data] of store.entries()) {
        if (!docPath.startsWith(`${this.name}/`)) continue
        const rest = docPath.slice(this.name.length + 1)
        if (rest.includes("/")) continue // only direct children, not sub-subcollections
        const ok = this._filters.every(({ field, op, value }) => {
          const got = data?.[field]
          if (op === "==") return got === value
          return false
        })
        if (!ok) continue
        docs.push({ id: rest, ref: new DocRef(docPath), data: () => ({ ...data }) })
      }
      return { empty: docs.length === 0, docs }
    }
  }

  function seed(path, data) {
    store.set(path, normalize(data))
  }

  const db = {
    collection(name) {
      return new CollectionRef(name)
    },
    async getAll(...refs) {
      return refs.map((ref) => {
        const value = store.get(ref.path)
        return {
          exists: value != null,
          id: ref.id,
          data: () => (value == null ? undefined : { ...value }),
        }
      })
    },
  }

  return { db, seed, store }
}

test("createStorexCheckoutSession (real index.js) no longer throws ReferenceError on assertHttpsUrlOrDefault", async () => {
  process.env.GCLOUD_PROJECT = process.env.GCLOUD_PROJECT || "maslive-test"
  process.env.FIREBASE_CONFIG = process.env.FIREBASE_CONFIG || JSON.stringify({
    projectId: "maslive-test",
    storageBucket: "maslive-test.appspot.com",
  })

  const { db: fakeDb, seed } = createFakeFirestore()

  // --- Mock firebase-admin ---
  const adminPath = require.resolve("firebase-admin")
  const fakeAdmin = {
    apps: [],
    initializeApp: () => {},
    firestore: Object.assign(() => fakeDb, {
      FieldValue: {
        serverTimestamp: () => ({ __isServerTimestamp: true }),
        delete: () => ({ __isDeleteField: true }),
      },
      Timestamp: { fromMillis: (ms) => ({ toMillis: () => ms }) },
    }),
    auth: () => ({ verifyIdToken: async () => ({ uid: "test-uid" }) }),
    messaging: () => ({ sendEachForMulticast: async () => ({ responses: [] }) }),
  }
  require.cache[adminPath] = { id: adminPath, filename: adminPath, loaded: true, exports: fakeAdmin }

  // --- Mock stripe ---
  const stripePath = require.resolve("stripe")
  let capturedSessionCreateArgs = null
  const fakeStripeClient = {
    checkout: {
      sessions: {
        create: async (args) => {
          capturedSessionCreateArgs = args
          return { id: "cs_test_fake123", url: "https://checkout.stripe.com/pay/cs_test_fake123" }
        },
      },
    },
  }
  const fakeStripeModule = () => fakeStripeClient
  require.cache[stripePath] = { id: stripePath, filename: stripePath, loaded: true, exports: fakeStripeModule }

  // --- Mock firebase-functions/params (secrets) ---
  const paramsPath = require.resolve("firebase-functions/params")
  const fakeParams = {
    defineSecret: (name) => ({
      name,
      value: () => `fake_${name.toLowerCase()}_for_tests`,
    }),
  }
  require.cache[paramsPath] = { id: paramsPath, filename: paramsPath, loaded: true, exports: fakeParams }

  // --- Capture the real onCall handlers instead of registering live Cloud Functions ---
  const httpsPath = require.resolve("firebase-functions/v2/https")
  const realHttps = require(httpsPath)
  const capturedHandlers = {}
  let currentExportName = null
  const fakeOnCall = (optionsOrHandler, maybeHandler) => {
    const handler = typeof optionsOrHandler === "function" ? optionsOrHandler : maybeHandler
    return { __isFakeCallable: true, __handler: handler }
  }
  const fakeHttps = { ...realHttps, onCall: fakeOnCall, onRequest: () => ({ __isFakeCallable: true }) }
  require.cache[httpsPath] = { id: httpsPath, filename: httpsPath, loaded: true, exports: fakeHttps }

  // --- Load the REAL index.js with the above mocks in place ---
  const indexPath = path.join(__dirname, "..", "index.js")
  delete require.cache[indexPath]
  let indexExports
  try {
    indexExports = require(indexPath)
  } finally {
    // Clean up module cache mutations so other test files aren't affected.
    delete require.cache[adminPath]
    delete require.cache[stripePath]
    delete require.cache[paramsPath]
    delete require.cache[httpsPath]
    delete require.cache[indexPath]
  }

  const createStorexCheckoutSession = indexExports.createStorexCheckoutSession
  assert.ok(createStorexCheckoutSession && createStorexCheckoutSession.__handler, "createStorexCheckoutSession must be exported as a callable")

  // --- Seed a realistic cart + product so the handler reaches the Stripe call ---
  seed("users/test-uid/cart_items/cart_item_1", {
    itemType: "merch",
    productId: "product_1",
    quantity: 2,
    metadata: { groupId: "group_1", size: "M", color: "Noir" },
  })
  seed("shops/global/products/product_1", {
    title: "T-shirt MASLIVE",
    priceCents: 2500,
    isActive: true,
    moderationStatus: "approved",
    ownerId: "seller_1",
  })

  const fakeRequest = {
    auth: { uid: "test-uid", token: { email: "buyer@example.com" } },
    data: {
      currency: "eur",
      shippingCents: 500,
      shippingMethod: "flat_rate",
      address: {
        firstName: "Jean",
        lastName: "Dupont",
        country: "FR",
        addressLine1: "1 rue de Paris",
        zip: "75001",
        email: "buyer@example.com",
        phone: "0600000000",
      },
      successUrl: "https://maslive.web.app/#/storex/paymentComplete",
      cancelUrl: "https://maslive.web.app/#/boutique",
    },
  }

  const result = await createStorexCheckoutSession.__handler(fakeRequest)

  assert.equal(result.checkoutUrl, "https://checkout.stripe.com/pay/cs_test_fake123", "handler must return the Stripe checkout URL")
  assert.ok(capturedSessionCreateArgs, "stripe.checkout.sessions.create must have been called")
  assert.equal(capturedSessionCreateArgs.success_url.startsWith("https://maslive.web.app/#/storex/paymentComplete"), true, "success_url must be preserved (assertHttpsUrlOrDefault must resolve, not throw)")
  assert.equal(capturedSessionCreateArgs.line_items.length, 2, "checkout session must contain the cart line item + shipping line item")
  assert.equal(capturedSessionCreateArgs.line_items[0].price_data.unit_amount, 2500, "line item price must come from the product, not the client cart")
  assert.equal(capturedSessionCreateArgs.line_items[0].quantity, 2, "line item quantity must match the cart quantity")
})
