const test = require("node:test")
const assert = require("node:assert/strict")

const createRestaurantLiveTablesHandlers = require("../src/restaurant-live-tables")

function createFakeDb(initial = {}) {
  const store = new Map(Object.entries(initial))
  const DELETE_FIELD = Symbol("deleteField")

  function stripDeleteFields(value) {
    if (Array.isArray(value)) {
      return value.map(stripDeleteFields)
    }
    if (!value || typeof value !== "object") {
      return value
    }

    const output = {}
    for (const [key, entry] of Object.entries(value)) {
      if (entry === DELETE_FIELD) continue
      output[key] = stripDeleteFields(entry)
    }
    return output
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
      const nextValue = stripDeleteFields(data)
      if (options.merge) {
        store.set(this.path, { ...previous, ...nextValue })
      } else {
        store.set(this.path, { ...nextValue })
      }
    }

    async delete() {
      store.delete(this.path)
    }
  }

  class CollectionRef {
    constructor(path) {
      this.path = path
    }

    doc(id) {
      return new DocRef(`${this.path}/${id}`)
    }
  }

  return {
    collection(name) {
      return new CollectionRef(name)
    },
    _store: store,
    _deleteField: DELETE_FIELD,
  }
}

function createHandlers(storeSeed = {}, overrides = {}) {
  const db = createFakeDb(storeSeed)
  const DELETE_FIELD = db._deleteField
  class TestHttpsError extends Error {
    constructor(code, message) {
      super(message)
      this.code = code
    }
  }

  const admin = {
    firestore: {
      FieldValue: {
        serverTimestamp: () => "__ts__",
        delete: () => DELETE_FIELD,
      },
    },
  }

  const handlers = createRestaurantLiveTablesHandlers({
    admin,
    db,
    onCall: (_opts, handler) => handler,
    HttpsError: TestHttpsError,
    toSafeInt: (n, fallback = 0) => {
      const x = Number(n)
      if (!Number.isFinite(x)) return fallback
      return Math.trunc(x)
    },
    STRIPE_SECRET_KEY: {},
    getStripe: overrides.getStripe,
    isAllowedRedirectUrl: overrides.isAllowedRedirectUrl || (() => true),
  })

  return { db, handlers, TestHttpsError }
}

test("createRestaurantLiveTableSubscriptionCheckoutSession creates Stripe checkout and marks pending", async () => {
  const previousPrice = process.env.STRIPE_PRICE_FOOD_PRO_LIVE_MONTHLY
  process.env.STRIPE_PRICE_FOOD_PRO_LIVE_MONTHLY = "price_food_live_month"

  try {
    const { db, handlers } = createHandlers(
      {
        "businesses/biz_1": {
          ownerUid: "biz_1",
          status: "approved",
          email: "owner@example.com",
        },
      },
      {
        getStripe: () => ({
          checkout: {
            sessions: {
              create: async () => ({
                id: "cs_live_1",
                url: "https://checkout.stripe.test/live_1",
                customer: "cus_live_1",
              }),
            },
          },
        }),
      }
    )

    const result = await handlers.createRestaurantLiveTableSubscriptionCheckoutSession({
      auth: { uid: "biz_1", token: { email: "owner@example.com" } },
      data: {
        planCode: "food_pro_live",
        billingInterval: "month",
        successUrl: "https://maslive.web.app/business-account?ok=1",
        cancelUrl: "https://maslive.web.app/business-account?cancel=1",
      },
    })

    assert.equal(result.checkoutUrl, "https://checkout.stripe.test/live_1")
    assert.equal(result.stripeSessionId, "cs_live_1")

    const business = db._store.get("businesses/biz_1")
    assert.equal(business.liveTableSubscription.status, "checkout_pending")
    assert.equal(business.liveTableSubscription.planCode, "food_pro_live")
    assert.equal(business.liveTableSubscription.stripePriceId, "price_food_live_month")
    assert.equal(business.liveTableSubscription.pendingCheckoutSessionId, "cs_live_1")
  } finally {
    if (previousPrice == null) {
      delete process.env.STRIPE_PRICE_FOOD_PRO_LIVE_MONTHLY
    } else {
      process.env.STRIPE_PRICE_FOOD_PRO_LIVE_MONTHLY = previousPrice
    }
  }
})

test("assignBusinessRestaurantPoi links an approved business to a food poi", async () => {
  const { db, handlers } = createHandlers({
    "businesses/owner_1": {
      ownerUid: "owner_1",
      status: "approved",
      companyName: "Chez MASLIVE",
    },
    "users/owner_1": {
      role: "user",
      isAdmin: false,
    },
    "marketMap/fr/events/event_1/circuits/circuit_1/pois/poi_1": {
      name: "Restaurant test",
      layerType: "food",
      metadata: {},
    },
  })

  const result = await handlers.assignBusinessRestaurantPoi({
    auth: { uid: "owner_1" },
    data: {
      countryId: "fr",
      eventId: "event_1",
      circuitId: "circuit_1",
      poiId: "poi_1",
    },
  })

  assert.equal(result.ok, true)
  assert.deepEqual(db._store.get("businesses/owner_1").restaurantPoiRef, {
    countryId: "fr",
    eventId: "event_1",
    circuitId: "circuit_1",
    poiId: "poi_1",
    name: "Restaurant test",
    linkedAt: "__ts__",
  })
  assert.equal(
    db._store.get("marketMap/fr/events/event_1/circuits/circuit_1/pois/poi_1").metadata.restaurantOwnerUid,
    "owner_1"
  )
})

test("setRestaurantLiveTableStatus rejects non-owner without admin role", async () => {
  const { handlers, TestHttpsError } = createHandlers({
    "businesses/user_2": {
      ownerUid: "user_2",
      status: "approved",
    },
    "users/user_2": {
      role: "user",
      isAdmin: false,
      premium: { status: "active" },
    },
    "marketMap/fr/events/event_1/circuits/circuit_1/pois/poi_1": {
      name: "Restaurant test",
      layerType: "food",
      metadata: { restaurantOwnerUid: "other_owner" },
    },
  })

  await assert.rejects(
    () => handlers.setRestaurantLiveTableStatus({
      auth: { uid: "user_2" },
      data: {
        countryId: "fr",
        eventId: "event_1",
        circuitId: "circuit_1",
        poiId: "poi_1",
        enabled: true,
        status: "available",
      },
    }),
    (error) => {
      assert.ok(error instanceof TestHttpsError)
      assert.equal(error.code, "permission-denied")
      return true
    }
  )
})

test("assignBusinessRestaurantPoi rejects a restaurant already linked to another business", async () => {
  const { handlers, TestHttpsError } = createHandlers({
    "businesses/owner_4": {
      ownerUid: "owner_4",
      status: "approved",
      companyName: "Owner 4",
    },
    "users/owner_4": {
      role: "user",
      isAdmin: false,
    },
    "marketMap/fr/events/event_4/circuits/circuit_4/pois/poi_4": {
      name: "Restaurant 4",
      layerType: "food",
      metadata: { restaurantOwnerUid: "other_owner" },
    },
  })

  await assert.rejects(
    () => handlers.assignBusinessRestaurantPoi({
      auth: { uid: "owner_4" },
      data: {
        countryId: "fr",
        eventId: "event_4",
        circuitId: "circuit_4",
        poiId: "poi_4",
      },
    }),
    (error) => {
      assert.ok(error instanceof TestHttpsError)
      assert.equal(error.code, "permission-denied")
      return true
    }
  )
})

test("assignBusinessRestaurantPoi clears previous restaurant ownership and public status on relink", async () => {
  const { db, handlers } = createHandlers({
    "businesses/owner_relink": {
      ownerUid: "owner_relink",
      status: "approved",
      companyName: "Relink Inc",
      restaurantPoiRef: {
        countryId: "fr",
        eventId: "event_old",
        circuitId: "circuit_old",
        poiId: "poi_old",
      },
    },
    "users/owner_relink": {
      role: "user",
      isAdmin: false,
    },
    "marketMap/fr/events/event_old/circuits/circuit_old/pois/poi_old": {
      name: "Old Restaurant",
      layerType: "food",
      metadata: {
        restaurantOwnerUid: "owner_relink",
        restaurantBusinessUid: "owner_relink",
        restaurantCompanyName: "Relink Inc",
        liveTable: {
          enabled: true,
          status: "limited",
        },
      },
    },
    "restaurant_live_status/fr__event_old__circuit_old__poi_old": {
      ownerUid: "owner_relink",
      enabled: true,
      status: "limited",
    },
    "marketMap/fr/events/event_new/circuits/circuit_new/pois/poi_new": {
      name: "New Restaurant",
      layerType: "food",
      metadata: {},
    },
  })

  await handlers.assignBusinessRestaurantPoi({
    auth: { uid: "owner_relink" },
    data: {
      countryId: "fr",
      eventId: "event_new",
      circuitId: "circuit_new",
      poiId: "poi_new",
    },
  })

  const oldPoi = db._store.get("marketMap/fr/events/event_old/circuits/circuit_old/pois/poi_old")
  assert.equal(oldPoi.metadata.restaurantOwnerUid, undefined)
  assert.equal(oldPoi.metadata.restaurantBusinessUid, undefined)
  assert.equal(oldPoi.metadata.restaurantCompanyName, undefined)
  assert.equal(oldPoi.metadata.liveTable, undefined)
  assert.equal(db._store.has("restaurant_live_status/fr__event_old__circuit_old__poi_old"), false)

  const business = db._store.get("businesses/owner_relink")
  assert.equal(business.restaurantPoiRef.poiId, "poi_new")
})

test("setRestaurantLiveTableStatus accepts owner with active premium and mirrors public state", async () => {
  const { db, handlers } = createHandlers({
    "businesses/owner_3": {
      ownerUid: "owner_3",
      status: "approved",
      companyName: "Owner 3",
    },
    "users/owner_3": {
      role: "user",
      isAdmin: false,
      premium: { status: "active" },
    },
    "marketMap/fr/events/event_9/circuits/circuit_9/pois/poi_9": {
      name: "Restaurant 9",
      layerType: "food",
      metadata: { restaurantOwnerUid: "owner_3" },
    },
  })

  const result = await handlers.setRestaurantLiveTableStatus({
    auth: { uid: "owner_3" },
    data: {
      countryId: "fr",
      eventId: "event_9",
      circuitId: "circuit_9",
      poiId: "poi_9",
      enabled: true,
      status: "limited",
      availableTables: 3,
      capacity: 12,
      message: "Encore quelques places",
    },
  })

  assert.equal(result.ok, true)
  const publicDoc = db._store.get("restaurant_live_status/fr__event_9__circuit_9__poi_9")
  assert.equal(publicDoc.status, "limited")
  assert.equal(publicDoc.availableTables, 3)
  assert.equal(publicDoc.capacity, 12)
  assert.equal(publicDoc.ownerUid, "owner_3")

  const poiDoc = db._store.get("marketMap/fr/events/event_9/circuits/circuit_9/pois/poi_9")
  assert.equal(poiDoc.metadata.liveTable.status, "limited")
  assert.equal(poiDoc.metadata.liveTable.availableTables, 3)
})

test("setRestaurantLiveTableStatus rejects incoherent table counts", async () => {
  const { handlers, TestHttpsError } = createHandlers({
    "businesses/owner_10": {
      ownerUid: "owner_10",
      status: "approved",
      liveTableSubscription: { status: "active" },
    },
    "users/owner_10": {
      role: "user",
      isAdmin: false,
    },
    "marketMap/fr/events/event_10/circuits/circuit_10/pois/poi_10": {
      name: "Restaurant 10",
      layerType: "food",
      metadata: { restaurantOwnerUid: "owner_10" },
    },
  })

  await assert.rejects(
    () => handlers.setRestaurantLiveTableStatus({
      auth: { uid: "owner_10" },
      data: {
        countryId: "fr",
        eventId: "event_10",
        circuitId: "circuit_10",
        poiId: "poi_10",
        enabled: true,
        status: "available",
        availableTables: 12,
        capacity: 4,
      },
    }),
    (error) => {
      assert.ok(error instanceof TestHttpsError)
      assert.equal(error.code, "invalid-argument")
      return true
    }
  )
})
