module.exports = function createRestaurantLiveTablesHandlers(deps) {
  const { admin, db, onCall, HttpsError, toSafeInt } = deps

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
      const subscriptionStatus = normalizeStatus(business.liveTableSubscription && business.liveTableSubscription.status)
      const isBusinessSubscribed = subscriptionStatus === "active" || subscriptionStatus === "trialing"
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

  return {
    assignBusinessRestaurantPoi,
    setRestaurantLiveTableStatus,
  }
}
