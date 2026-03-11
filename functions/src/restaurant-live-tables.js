module.exports = function createRestaurantLiveTablesHandlers(deps) {
  const {
    admin,
    db,
    onCall,
    HttpsError,
    toSafeInt,
    STRIPE_SECRET_KEY,
    getStripe,
    isAllowedRedirectUrl,
  } = deps

  const LIVE_TABLE_ALLOWED_PLAN_CODES = new Set([
    "food_pro_live",
    "food_premium",
    "restaurant_live_plus",
  ])

  const LIVE_TABLE_ACTIVE_STATUSES = new Set(["trialing", "active", "past_due"])

  function normalizeInterval(raw) {
    const value = (raw || "").toString().trim().toLowerCase()
    return value === "year" || value === "annual" ? "year" : "month"
  }

  function assertHttpsUrlOrDefault(value, fallback) {
    if (typeof value !== "string" || value.trim().length === 0) return fallback
    const normalized = value.trim()
    if (!isAllowedRedirectUrl || !isAllowedRedirectUrl(normalized)) {
      throw new HttpsError("invalid-argument", "Invalid redirect URL")
    }
    return normalized
  }

  function normalizePlanCode(raw) {
    const value = (raw || "").toString().trim().toLowerCase()
    return value || "food_pro_live"
  }

  function isLiveTablePlanAllowed(rawPlanCode) {
    return LIVE_TABLE_ALLOWED_PLAN_CODES.has(normalizePlanCode(rawPlanCode))
  }

  function resolveLiveTableStripePriceId({ planCode, interval }) {
    const plan = normalizePlanCode(planCode)
    const normalizedInterval = normalizeInterval(interval)
    const suffix = normalizedInterval === "year" ? "ANNUAL" : "MONTHLY"
    const envKey = `STRIPE_PRICE_${plan.toUpperCase()}_${suffix}`
    const raw = process.env[envKey]
    const priceId = typeof raw === "string" ? raw.trim() : ""
    if (!priceId) {
      throw new HttpsError(
        "failed-precondition",
        `Stripe price not configured for ${plan} (${normalizedInterval}). Missing env: ${envKey}`
      )
    }
    return priceId
  }

  function appendQueryParam(url, key, value) {
    const separator = url.includes("?") ? "&" : "?"
    return `${url}${separator}${encodeURIComponent(key)}=${encodeURIComponent(value)}`
  }

  function normalizeStatus(raw) {
    const value = (raw || "").toString().trim().toLowerCase()
    return value || "unknown"
  }

  function isApprovedBusinessStatus(status) {
    const normalized = (status || "").toString().trim().toLowerCase()
    return normalized === "approved" || normalized === "active"
  }

  function buildPoiRef({ countryId, eventId, circuitId, poiId }) {
    return db
      .collection("marketMap")
      .doc(countryId)
      .collection("events")
      .doc(eventId)
      .collection("circuits")
      .doc(circuitId)
      .collection("pois")
      .doc(poiId)
  }

  function buildStatusId({ countryId, eventId, circuitId, poiId }) {
    return `${countryId}__${eventId}__${circuitId}__${poiId}`
  }

  function normalizePoiRef(raw) {
    const ref = (raw && typeof raw === "object") ? raw : {}
    const countryId = (ref.countryId || "").toString().trim()
    const eventId = (ref.eventId || "").toString().trim()
    const circuitId = (ref.circuitId || "").toString().trim()
    const poiId = (ref.poiId || "").toString().trim()

    if (!countryId || !eventId || !circuitId || !poiId) {
      return null
    }

    return { countryId, eventId, circuitId, poiId }
  }

  function samePoiRef(left, right) {
    if (!left || !right) return false
    return left.countryId === right.countryId &&
      left.eventId === right.eventId &&
      left.circuitId === right.circuitId &&
      left.poiId === right.poiId
  }

  async function loadBusinessRestaurantContext(uid, ids) {
    const poiRef = buildPoiRef(ids)
    const [poiSnap, userSnap, businessSnap] = await Promise.all([
      poiRef.get(),
      db.collection("users").doc(uid).get(),
      db.collection("businesses").doc(uid).get(),
    ])

    if (!poiSnap.exists) {
      throw new HttpsError("not-found", "POI not found")
    }
    if (!businessSnap.exists) {
      throw new HttpsError("not-found", "Business profile not found")
    }

    const poi = poiSnap.data() || {}
    const business = businessSnap.data() || {}
    const user = userSnap.exists ? (userSnap.data() || {}) : {}
    const poiType = (poi.layerType || poi.type || "").toString().trim().toLowerCase()

    if (poiType !== "food" && poiType !== "restaurant") {
      throw new HttpsError("failed-precondition", "Live tables only available for restaurant POIs")
    }

    if (!isApprovedBusinessStatus(business.status)) {
      throw new HttpsError("failed-precondition", "Business must be approved before linking a restaurant")
    }

    const role = (user.role || "").toString().trim().toLowerCase()
    const isAdmin = user.isAdmin === true || role === "admin" || role === "superadmin" || role === "super-admin"
    const poiMeta = (poi.metadata && typeof poi.metadata === "object") ? poi.metadata : {}
    const ownerUid = (poiMeta.restaurantOwnerUid || "").toString().trim()

    return {
      poiRef,
      poi,
      poiMeta,
      business,
      user,
      isAdmin,
      ownerUid,
    }
  }

  const assignBusinessRestaurantPoi = onCall(
    {
      region: "us-east1",
      cpu: 0.083,
      memory: "256MiB",
      timeoutSeconds: 30,
    },
    async (request) => {
      if (!request.auth) {
        throw new HttpsError("unauthenticated", "Authentication required")
      }

      const uid = request.auth.uid
      const data = request.data || {}
      const countryId = (data.countryId || "").toString().trim()
      const eventId = (data.eventId || "").toString().trim()
      const circuitId = (data.circuitId || "").toString().trim()
      const poiId = (data.poiId || "").toString().trim()

      if (!countryId || !eventId || !circuitId || !poiId) {
        throw new HttpsError("invalid-argument", "Missing poi location identifiers")
      }

      const ids = { countryId, eventId, circuitId, poiId }
      const { poiRef, poi, poiMeta, business, isAdmin, ownerUid } = await loadBusinessRestaurantContext(uid, ids)

      if (ownerUid && ownerUid !== uid && !isAdmin) {
        throw new HttpsError("permission-denied", "This restaurant is already linked to another business")
      }

      const companyName = (business.companyName || "").toString().trim()
      const businessRef = db.collection("businesses").doc(uid)
      const previousLinkedRef = normalizePoiRef(business.restaurantPoiRef)
      const cleanupOps = []

      if (previousLinkedRef && !samePoiRef(previousLinkedRef, ids)) {
        const previousPoiRef = buildPoiRef(previousLinkedRef)
        const previousStatusRef = db.collection("restaurant_live_status").doc(buildStatusId(previousLinkedRef))
        const [previousPoiSnap, previousStatusSnap] = await Promise.all([
          previousPoiRef.get(),
          previousStatusRef.get(),
        ])

        const previousPoi = previousPoiSnap.exists ? (previousPoiSnap.data() || {}) : {}
        const previousPoiMeta =
          (previousPoi.metadata && typeof previousPoi.metadata === "object")
            ? previousPoi.metadata
            : {}
        const wasOwnedByUid =
          (previousPoiMeta.restaurantOwnerUid || "").toString().trim() === uid ||
          (previousPoiMeta.restaurantBusinessUid || "").toString().trim() === uid

        if (wasOwnedByUid) {
          cleanupOps.push(
            previousPoiRef.set(
              {
                metadata: {
                  ...previousPoiMeta,
                  restaurantOwnerUid: admin.firestore.FieldValue.delete(),
                  restaurantBusinessUid: admin.firestore.FieldValue.delete(),
                  restaurantCompanyName: admin.firestore.FieldValue.delete(),
                  liveTable: admin.firestore.FieldValue.delete(),
                },
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
              },
              { merge: true }
            )
          )
        }

        const previousStatus = previousStatusSnap.exists ? (previousStatusSnap.data() || {}) : {}
        const previousStatusOwnerUid = (previousStatus.ownerUid || "").toString().trim()
        if (!previousStatusSnap.exists || !previousStatusOwnerUid || previousStatusOwnerUid === uid) {
          cleanupOps.push(previousStatusRef.delete().catch(() => null))
        }
      }

      await Promise.all([
        businessRef.set(
          {
            restaurantPoiRef: {
              ...ids,
              name: (poi.name || "").toString(),
              linkedAt: admin.firestore.FieldValue.serverTimestamp(),
            },
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          },
          { merge: true }
        ),
        poiRef.set(
          {
            metadata: {
              ...poiMeta,
              restaurantOwnerUid: uid,
              restaurantBusinessUid: uid,
              ...(companyName ? { restaurantCompanyName: companyName } : {}),
            },
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          },
          { merge: true }
        ),
        ...cleanupOps,
      ])

      return {
        ok: true,
        linked: true,
        restaurantPoiRef: ids,
      }
    }
  )

  const setRestaurantLiveTableStatus = onCall(
    {
      region: "us-east1",
      cpu: 0.083,
      memory: "256MiB",
      timeoutSeconds: 30,
    },
    async (request) => {
      if (!request.auth) {
        throw new HttpsError("unauthenticated", "Authentication required")
      }

      const uid = request.auth.uid
      const data = request.data || {}
      const countryId = (data.countryId || "").toString().trim()
      const eventId = (data.eventId || "").toString().trim()
      const circuitId = (data.circuitId || "").toString().trim()
      const poiId = (data.poiId || "").toString().trim()
      const status = normalizeStatus(data.status)
      const enabled = data.enabled === true
      const message = (data.message || "").toString().trim().slice(0, 220)

      if (!countryId || !eventId || !circuitId || !poiId) {
        throw new HttpsError("invalid-argument", "Missing poi location identifiers")
      }

      const allowedStatus = new Set(["available", "limited", "full", "closed", "unknown"])
      if (!allowedStatus.has(status)) {
        throw new HttpsError("invalid-argument", "Invalid live table status")
      }

      const ids = { countryId, eventId, circuitId, poiId }
      const { poiRef, poiMeta, business, user, isAdmin, ownerUid } = await loadBusinessRestaurantContext(uid, ids)
      const isOwner = ownerUid && ownerUid === uid
      const premiumStatus = normalizeStatus(user.premium && user.premium.status)
      const isUserPremium = premiumStatus === "active" || premiumStatus === "trialing"
      const liveTableSub =
        (business.liveTableSubscription && typeof business.liveTableSubscription === "object")
          ? business.liveTableSubscription
          : {}
      const subscriptionStatus = normalizeStatus(liveTableSub.status)
      const subscriptionPlanCode = normalizePlanCode(liveTableSub.planCode)
      const isBusinessSubscribed =
        (subscriptionStatus === "active" || subscriptionStatus === "trialing") &&
        isLiveTablePlanAllowed(subscriptionPlanCode)
      const canWriteAsOwner = isOwner && (isUserPremium || isBusinessSubscribed)

      if (!isAdmin && !canWriteAsOwner) {
        throw new HttpsError(
          "permission-denied",
          "Live tables require owner access and an active subscription"
        )
      }

      const availableTables = data.availableTables == null ? null : toSafeInt(data.availableTables, Number.NaN)
      const capacity = data.capacity == null ? null : toSafeInt(data.capacity, Number.NaN)
      if (availableTables != null && (!Number.isFinite(availableTables) || availableTables < 0)) {
        throw new HttpsError("invalid-argument", "availableTables must be a non-negative integer")
      }
      if (capacity != null && (!Number.isFinite(capacity) || capacity < 0)) {
        throw new HttpsError("invalid-argument", "capacity must be a non-negative integer")
      }
      if (availableTables != null && capacity != null && availableTables > capacity) {
        throw new HttpsError("invalid-argument", "availableTables cannot exceed capacity")
      }

      const livePayload = {
        enabled,
        status,
        availableTables,
        capacity,
        message,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedBy: uid,
      }

      const statusId = buildStatusId(ids)
      const statusRef = db.collection("restaurant_live_status").doc(statusId)

      await Promise.all([
        statusRef.set(
          {
            ...livePayload,
            source: "manual",
            poiRef: ids,
            ownerUid: ownerUid || uid,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          },
          { merge: true }
        ),
        poiRef.set(
          {
            metadata: {
              ...poiMeta,
              liveTable: livePayload,
            },
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          },
          { merge: true }
        ),
      ])

      return {
        ok: true,
        statusId,
        source: "restaurant_live_status",
      }
    }
  )

  const createRestaurantLiveTableSubscriptionCheckoutSession = onCall(
    {
      region: "us-east1",
      cpu: 0.083,
      memory: "256MiB",
      timeoutSeconds: 30,
      secrets: STRIPE_SECRET_KEY ? [STRIPE_SECRET_KEY] : undefined,
    },
    async (request) => {
      if (!request.auth) {
        throw new HttpsError("unauthenticated", "Authentication required")
      }

      if (!getStripe) {
        throw new HttpsError("failed-precondition", "Stripe is not configured")
      }

      const uid = request.auth.uid
      const businessRef = db.collection("businesses").doc(uid)
      const businessSnap = await businessRef.get()
      if (!businessSnap.exists) {
        throw new HttpsError("not-found", "Business profile not found")
      }

      const business = businessSnap.data() || {}
      const ownerUid = (business.ownerUid || uid).toString().trim()
      if (ownerUid !== uid) {
        throw new HttpsError("permission-denied", "Only the business owner can subscribe")
      }

      if (!isApprovedBusinessStatus(business.status)) {
        throw new HttpsError("failed-precondition", "Business must be approved before subscribing")
      }

      const planCode = normalizePlanCode(request.data && request.data.planCode)
      if (!isLiveTablePlanAllowed(planCode)) {
        throw new HttpsError("invalid-argument", "Unsupported live table plan")
      }

      const billingInterval = normalizeInterval(request.data && request.data.billingInterval)
      const liveTableSubscription =
        (business.liveTableSubscription && typeof business.liveTableSubscription === "object")
          ? business.liveTableSubscription
          : {}
      const currentStatus = normalizeStatus(liveTableSubscription.status)
      const currentPlanCode = normalizePlanCode(liveTableSubscription.planCode)
      if (LIVE_TABLE_ACTIVE_STATUSES.has(currentStatus) && isLiveTablePlanAllowed(currentPlanCode)) {
        throw new HttpsError("failed-precondition", "An active live table subscription already exists")
      }

      const stripePriceId = resolveLiveTableStripePriceId({
        planCode,
        interval: billingInterval,
      })

      const successUrl = assertHttpsUrlOrDefault(
        request.data && request.data.successUrl,
        "https://maslive.web.app/business-account?liveTableSubscription=success"
      )
      const cancelUrl = assertHttpsUrlOrDefault(
        request.data && request.data.cancelUrl,
        "https://maslive.web.app/business-account?liveTableSubscription=cancel"
      )

      const stripeClient = getStripe()
      const session = await stripeClient.checkout.sessions.create(
        {
          mode: "subscription",
          line_items: [{ price: stripePriceId, quantity: 1 }],
          success_url: appendQueryParam(successUrl, "session_id", "{CHECKOUT_SESSION_ID}"),
          cancel_url: cancelUrl,
          customer_email: request.auth.token.email || business.email || undefined,
          metadata: {
            kind: "business_live_table_subscription",
            uid,
            businessId: uid,
            planCode,
            billingInterval,
          },
          subscription_data: {
            metadata: {
              kind: "business_live_table_subscription",
              uid,
              businessId: uid,
              planCode,
              billingInterval,
            },
          },
        },
        { idempotencyKey: `business_live_table_subscription_${uid}_${planCode}_${billingInterval}` }
      )

      await businessRef.set(
        {
          liveTableSubscription: {
            status: "checkout_pending",
            planCode,
            billingInterval,
            stripePriceId,
            stripeCustomerId: session.customer || null,
            pendingCheckoutSessionId: session.id,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          },
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      )

      return {
        checkoutUrl: session.url,
        stripeSessionId: session.id,
        planCode,
        billingInterval,
      }
    }
  )

  return {
    assignBusinessRestaurantPoi,
    setRestaurantLiveTableStatus,
    createRestaurantLiveTableSubscriptionCheckoutSession,
  }
}
