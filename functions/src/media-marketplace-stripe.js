module.exports = function createMediaMarketplaceStripe(deps) {
  const {
    admin,
    db,
    onCall,
    HttpsError,
    STRIPE_SECRET_KEY,
    getStripe,
    isAllowedRedirectUrl,
  } = deps

  const COLLECTIONS = {
    carts: "carts",
    photographers: "photographers",
    photographerPlans: "photographer_plans",
    photographerSubscriptions: "photographer_subscriptions",
    mediaPhotos: "media_photos",
    mediaPacks: "media_packs",
    orders: "orders",
    mediaEntitlements: "media_entitlements",
    payoutLedger: "payout_ledger",
  }

  const MEDIA_MARKETPLACE_KIND_ORDER = "media_marketplace_order"
  const MEDIA_MARKETPLACE_KIND_SUBSCRIPTION = "media_marketplace_subscription"
  const ACTIVE_SUBSCRIPTION_STATUSES = new Set(["trialing", "active", "past_due"])

  function toNumber(value, fallback = 0) {
    const parsed = Number(value)
    return Number.isFinite(parsed) ? parsed : fallback
  }

  function toInteger(value, fallback = 0) {
    return Math.trunc(toNumber(value, fallback))
  }

  function clampPositiveAmount(value) {
    return Math.max(0, toNumber(value, 0))
  }

  function amountToCents(amount) {
    return Math.max(0, Math.round(clampPositiveAmount(amount) * 100))
  }

  function timestampFromUnixSeconds(value) {
    const seconds = toInteger(value, 0)
    if (seconds <= 0) return null
    return admin.firestore.Timestamp.fromMillis(seconds * 1000)
  }

  function serverTimestamp() {
    return admin.firestore.FieldValue.serverTimestamp()
  }

  function uniqueStrings(values) {
    return Array.from(
      new Set(
        (values || [])
          .filter((value) => typeof value === "string" && value.trim().length > 0)
          .map((value) => value.trim())
      )
    )
  }

  function buildQuotaSnapshotFromPlan(plan) {
    return {
      maxPublishedPhotos: toInteger(plan?.maxPublishedPhotos, 0),
      maxStorageBytes: toInteger(plan?.maxStorageBytes, 0),
      maxActiveGalleries: toInteger(plan?.maxActiveGalleries, 0),
      maxActivePacks: toInteger(plan?.maxActivePacks, 0),
      commissionRate: clampPositiveAmount(plan?.commissionRate),
      planCode: typeof plan?.code === "string" ? plan.code : null,
    }
  }

  function normalizeInterval(value) {
    const raw = typeof value === "string" ? value.trim().toLowerCase() : "month"
    return raw === "year" || raw === "annual" ? "year" : "month"
  }

  function assertHttpsUrlOrDefault(value, fallback) {
    if (typeof value !== "string" || value.trim().length === 0) return fallback
    if (!isAllowedRedirectUrl(value.trim())) {
      throw new HttpsError("invalid-argument", "Invalid redirect URL")
    }
    return value.trim()
  }

  async function getDocumentMap(collectionName, ids) {
    const uniqueIds = uniqueStrings(ids)
    if (!uniqueIds.length) return new Map()

    const refs = uniqueIds.map((id) => db.collection(collectionName).doc(id))
    const snapshots = await db.getAll(...refs)
    const out = new Map()

    for (let index = 0; index < uniqueIds.length; index += 1) {
      const id = uniqueIds[index]
      const snapshot = snapshots[index]
      if (snapshot.exists) {
        out.set(id, { id: snapshot.id, ...snapshot.data() })
      }
    }

    return out
  }

  async function getCommissionRatesByPhotographer(photographerIds) {
    const uniqueIds = uniqueStrings(photographerIds)
    const out = new Map()

    for (const photographerId of uniqueIds) {
      const snapshot = await db
        .collection(COLLECTIONS.photographerSubscriptions)
        .where("photographerId", "==", photographerId)
        .where("status", "in", Array.from(ACTIVE_SUBSCRIPTION_STATUSES))
        .limit(1)
        .get()

      if (snapshot.empty) {
        out.set(photographerId, 0)
        continue
      }

      const data = snapshot.docs[0].data() || {}
      const quotaSnapshot = data.quotaSnapshot && typeof data.quotaSnapshot === "object"
        ? data.quotaSnapshot
        : {}
      out.set(photographerId, clampPositiveAmount(quotaSnapshot.commissionRate))
    }

    return out
  }

  async function getPhotographerOwnerUids(photographerIds) {
    const uniqueIds = uniqueStrings(photographerIds)
    if (!uniqueIds.length) return []

    const refs = uniqueIds.map((photographerId) =>
      db.collection(COLLECTIONS.photographers).doc(photographerId)
    )
    const snapshots = await db.getAll(...refs)
    return uniqueStrings(
      snapshots.map((snapshot) => {
        const data = snapshot.exists ? snapshot.data() : null
        return data && typeof data.ownerUid === "string" ? data.ownerUid : ""
      })
    )
  }

  function assertValidPhotoForSale(photo, assetId) {
    if (!photo) {
      throw new HttpsError("failed-precondition", `Photo not found: ${assetId}`)
    }
    if (photo.isPublished !== true) {
      throw new HttpsError("failed-precondition", `Photo not published: ${assetId}`)
    }
    if (photo.lifecycleStatus && String(photo.lifecycleStatus) !== "published") {
      throw new HttpsError("failed-precondition", `Photo lifecycle not published: ${assetId}`)
    }
    const moderationStatus = String(photo.moderationStatus || "").toLowerCase()
    if (moderationStatus !== "approved") {
      throw new HttpsError("failed-precondition", `Photo moderation not approved: ${assetId}`)
    }
  }

  function assertValidPackForSale(pack, assetId, photosById) {
    if (!pack) {
      throw new HttpsError("failed-precondition", `Pack not found: ${assetId}`)
    }
    if (pack.isActive !== true) {
      throw new HttpsError("failed-precondition", `Pack inactive: ${assetId}`)
    }
    if (!Array.isArray(pack.photoIds) || pack.photoIds.length === 0) {
      throw new HttpsError("failed-precondition", `Pack empty: ${assetId}`)
    }

    const moderationStatus = String(pack.moderationStatus || "").toLowerCase()
    if (moderationStatus && moderationStatus !== "approved") {
      throw new HttpsError("failed-precondition", `Pack moderation not approved: ${assetId}`)
    }

    for (const photoId of uniqueStrings(pack.photoIds)) {
      const packPhoto = photosById.get(photoId)
      assertValidPhotoForSale(packPhoto, `${assetId}:${photoId}`)
    }
  }

  function buildOrderLineItemFromPhoto(cartItem, photo, commissionRate) {
    const quantity = Math.max(1, toInteger(cartItem.quantity, 1))
    const unitPrice = clampPositiveAmount(photo.unitPrice)
    const lineSubtotal = unitPrice * quantity
    return {
      assetId: photo.photoId || cartItem.assetId,
      assetType: "photo",
      photographerId: photo.photographerId || cartItem.photographerId || "",
      galleryId: photo.galleryId || cartItem.galleryId || null,
      eventId: photo.eventId || cartItem.eventId || null,
      title: photo.title || cartItem.title || "Photo",
      thumbnailUrl: photo.thumbnailUrl || photo.previewUrl || cartItem.thumbnailUrl || null,
      quantity,
      unitPrice,
      lineSubtotal,
      currency: photo.currency || cartItem.currency || "EUR",
      photoIds: [photo.photoId || cartItem.assetId],
      pricingSnapshot: {
        commissionRate,
        sourceUnitPrice: unitPrice,
      },
    }
  }

  function buildOrderLineItemFromPack(cartItem, pack, commissionRate) {
    const quantity = Math.max(1, toInteger(cartItem.quantity, 1))
    const unitPrice = clampPositiveAmount(pack.price)
    const lineSubtotal = unitPrice * quantity
    return {
      assetId: pack.packId || cartItem.assetId,
      assetType: "pack",
      photographerId: pack.photographerId || cartItem.photographerId || "",
      galleryId: pack.galleryId || cartItem.galleryId || null,
      eventId: pack.eventId || cartItem.eventId || null,
      title: pack.title || cartItem.title || "Pack",
      thumbnailUrl: pack.coverUrl || cartItem.thumbnailUrl || null,
      quantity,
      unitPrice,
      lineSubtotal,
      currency: pack.currency || cartItem.currency || "EUR",
      photoIds: Array.isArray(pack.photoIds) ? pack.photoIds : [],
      pricingSnapshot: {
        commissionRate,
        sourceUnitPrice: unitPrice,
        pricingMode: pack.pricingMode || "fixedPack",
      },
    }
  }

  function computeOrderBreakdown(items) {
    const subtotal = items.reduce((sum, item) => sum + clampPositiveAmount(item.lineSubtotal), 0)
    const platformFee = items.reduce((sum, item) => {
      const commissionRate = clampPositiveAmount(item?.pricingSnapshot?.commissionRate)
      return sum + (clampPositiveAmount(item.lineSubtotal) * commissionRate)
    }, 0)
    const taxAmount = 0
    const total = subtotal + taxAmount
    const stripeFee = total > 0 ? ((total * 0.029) + 0.30) : 0
    const photographerNetTotal = Math.max(0, subtotal - platformFee - stripeFee)

    return {
      subtotal,
      platformFee,
      taxAmount,
      total,
      stripeFee,
      photographerNetTotal,
    }
  }

  function buildStripeLineItems(items) {
    return items.map((item) => {
      const image = typeof item.thumbnailUrl === "string" && item.thumbnailUrl.startsWith("https://")
        ? [item.thumbnailUrl]
        : []

      return {
        price_data: {
          currency: String(item.currency || "EUR").toLowerCase(),
          product_data: {
            name: item.title,
            images: image,
            metadata: {
              assetId: item.assetId,
              assetType: item.assetType,
              photographerId: item.photographerId,
              galleryId: item.galleryId || "",
              eventId: item.eventId || "",
            },
          },
          unit_amount: amountToCents(item.unitPrice),
        },
        quantity: Math.max(1, toInteger(item.quantity, 1)),
      }
    })
  }

  async function resolvePlanByPriceId(priceId) {
    if (typeof priceId !== "string" || priceId.trim().length === 0) return null

    const monthly = await db
      .collection(COLLECTIONS.photographerPlans)
      .where("stripePriceMonthlyId", "==", priceId)
      .limit(1)
      .get()
    if (!monthly.empty) return { id: monthly.docs[0].id, ...monthly.docs[0].data() }

    const annual = await db
      .collection(COLLECTIONS.photographerPlans)
      .where("stripePriceAnnualId", "==", priceId)
      .limit(1)
      .get()
    if (!annual.empty) return { id: annual.docs[0].id, ...annual.docs[0].data() }

    return null
  }

  async function findMarketplaceSubscriptionByStripeId(stripeSubscriptionId) {
    if (typeof stripeSubscriptionId !== "string" || stripeSubscriptionId.trim().length === 0) {
      return null
    }

    const snapshot = await db
      .collection(COLLECTIONS.photographerSubscriptions)
      .where("stripeSubscriptionId", "==", stripeSubscriptionId)
      .limit(1)
      .get()

    if (snapshot.empty) return null
    return snapshot.docs[0]
  }

  async function syncMarketplaceSubscriptionFromStripeSubscription(subscription, fallbackMetadata = {}) {
    const existingDoc = await findMarketplaceSubscriptionByStripeId(subscription?.id)
    const metadata = {
      ...(fallbackMetadata || {}),
      ...((subscription && subscription.metadata) || {}),
    }

    let plan = null
    const priceId = subscription?.items?.data?.[0]?.price?.id || null
    const metadataPlanId = typeof metadata.planId === "string" ? metadata.planId : null
    if (metadataPlanId) {
      const planSnapshot = await db.collection(COLLECTIONS.photographerPlans).doc(metadataPlanId).get()
      if (planSnapshot.exists) {
        plan = { id: planSnapshot.id, ...planSnapshot.data() }
      }
    }
    if (!plan && priceId) {
      plan = await resolvePlanByPriceId(priceId)
    }

    const photographerId =
      (existingDoc?.data()?.photographerId) ||
      (typeof metadata.photographerId === "string" ? metadata.photographerId : "")
    const ownerUid =
      (existingDoc?.data()?.ownerUid) ||
      (typeof metadata.uid === "string" ? metadata.uid : "")
    const docId =
      existingDoc?.id ||
      (typeof metadata.subscriptionDocId === "string" && metadata.subscriptionDocId.trim().length > 0
        ? metadata.subscriptionDocId.trim()
        : db.collection(COLLECTIONS.photographerSubscriptions).doc().id)

    if (!photographerId || !ownerUid) {
      return false
    }

    const status = String(subscription?.status || "incomplete")
    const isActive = ACTIVE_SUBSCRIPTION_STATUSES.has(status)
    const payload = {
      subscriptionId: docId,
      photographerId,
      ownerUid,
      planId: plan?.id || metadataPlanId || existingDoc?.data()?.planId || "",
      stripeCustomerId: subscription?.customer || existingDoc?.data()?.stripeCustomerId || null,
      stripeSubscriptionId: subscription?.id || null,
      stripePriceId: priceId,
      status,
      billingInterval: normalizeInterval(subscription?.items?.data?.[0]?.price?.recurring?.interval),
      startedAt: timestampFromUnixSeconds(subscription?.start_date),
      currentPeriodStart: timestampFromUnixSeconds(subscription?.current_period_start),
      currentPeriodEnd: timestampFromUnixSeconds(subscription?.current_period_end),
      cancelAtPeriodEnd: subscription?.cancel_at_period_end === true,
      canceledAt: timestampFromUnixSeconds(subscription?.canceled_at),
      quotaSnapshot: buildQuotaSnapshotFromPlan(plan || existingDoc?.data()?.quotaSnapshot || {}),
      updatedAt: serverTimestamp(),
    }

    if (!existingDoc) {
      payload.createdAt = serverTimestamp()
    }

    await db.collection(COLLECTIONS.photographerSubscriptions).doc(docId).set(payload, { merge: true })

    await db.collection(COLLECTIONS.photographers).doc(photographerId).set(
      {
        activeSubscriptionId: isActive ? docId : null,
        activePlanId: plan?.id || metadataPlanId || existingDoc?.data()?.planId || null,
        updatedAt: serverTimestamp(),
      },
      { merge: true }
    )

    return true
  }

  async function fulfillMarketplaceOrder(session) {
    const orderId = session?.metadata?.orderId || session?.client_reference_id
    const buyerUid = session?.metadata?.uid || session?.metadata?.userId
    if (!orderId || !buyerUid) return false

    // Only fulfill when Stripe confirms the checkout session is actually paid.
    const paymentStatus = String(session?.payment_status || "").toLowerCase()
    if (paymentStatus !== "paid") {
      return false
    }

    const orderRef = db.collection(COLLECTIONS.orders).doc(orderId)
    const orderSnapshot = await orderRef.get()
    if (!orderSnapshot.exists) return false

    const order = orderSnapshot.data() || {}
    if (order?.metadata?.kind !== MEDIA_MARKETPLACE_KIND_ORDER) {
      return false
    }

    const items = Array.isArray(order.items) ? order.items : []
    const subtotal = clampPositiveAmount(order.subtotal)
    const stripeFeeTotal = clampPositiveAmount(order.stripeFee)
    const payoutBatch = db.batch()

    for (const item of items) {
      const assetId = item.assetId
      const lineSubtotal = clampPositiveAmount(item.lineSubtotal)
      const share = subtotal > 0 ? lineSubtotal / subtotal : 0
      const allocatedStripeFee = stripeFeeTotal * share
      const platformFee = clampPositiveAmount(
        item?.pricingSnapshot?.commissionRate
      ) * lineSubtotal
      const netAmount = Math.max(0, lineSubtotal - platformFee - allocatedStripeFee)

      const entitlementId = `${orderId}_${assetId}`
      payoutBatch.set(
        db.collection(COLLECTIONS.mediaEntitlements).doc(entitlementId),
        {
          entitlementId,
          buyerUid,
          orderId,
          assetId,
          assetType: item.assetType,
          photographerId: item.photographerId,
          photoIds: Array.isArray(item.photoIds) ? item.photoIds : [],
          allowedVariants: ["original"],
          downloadCount: 0,
          isActive: true,
          createdAt: serverTimestamp(),
          updatedAt: serverTimestamp(),
        },
        { merge: true }
      )

      const payoutId = `${orderId}_${assetId}`
      payoutBatch.set(
        db.collection(COLLECTIONS.payoutLedger).doc(payoutId),
        {
          ledgerId: payoutId,
          photographerId: item.photographerId,
          orderId,
          assetId,
          grossAmount: lineSubtotal,
          platformFee,
          stripeFee: allocatedStripeFee,
          taxAmount: 0,
          netAmount,
          currency: item.currency || order.currency || "EUR",
          payoutStatus: "available",
          metadata: {
            kind: MEDIA_MARKETPLACE_KIND_ORDER,
            assetType: item.assetType,
          },
          createdAt: serverTimestamp(),
          updatedAt: serverTimestamp(),
        },
        { merge: true }
      )
    }

    payoutBatch.set(
      orderRef,
      {
        paymentStatus: "paid",
        deliveryStatus: "delivered",
        stripeCheckoutSessionId: session.id,
        stripePaymentIntentId: session.payment_intent || null,
        stripeCustomerId: session.customer || null,
        paidAt: serverTimestamp(),
        deliveredAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      },
      { merge: true }
    )

    payoutBatch.set(
      db.collection(COLLECTIONS.carts).doc(buyerUid),
      {
        uid: buyerUid,
        items: [],
        updatedAt: serverTimestamp(),
      },
      { merge: true }
    )

    await payoutBatch.commit()
    return true
  }

  const createMediaMarketplaceCheckout = onCall(
    {
      region: "us-east1",
      cpu: 0.083,
      memory: "256MiB",
      timeoutSeconds: 30,
      secrets: [STRIPE_SECRET_KEY],
    },
    async (request) => {
      if (!request.auth) {
        throw new HttpsError("unauthenticated", "Authentication required")
      }

      const uid = request.auth.uid
      const successUrl = assertHttpsUrlOrDefault(
        request.data?.successUrl,
        "https://maslive.web.app/media-marketplace/success"
      )
      const cancelUrl = assertHttpsUrlOrDefault(
        request.data?.cancelUrl,
        "https://maslive.web.app/media-marketplace/cancel"
      )

      // Race condition protection: lock cart for checkout
      const cartRef = db.collection(COLLECTIONS.carts).doc(uid)
      let cart = null
      let cartItems = []

      await db.runTransaction(async (transaction) => {
        const cartSnapshot = await transaction.get(cartRef)
        if (!cartSnapshot.exists) {
          throw new HttpsError("failed-precondition", "Cart is empty")
        }

        const cartData = cartSnapshot.data() || {}
        const items = Array.isArray(cartData.items) ? cartData.items : []
        if (!items.length) {
          throw new HttpsError("failed-precondition", "Cart is empty")
        }

        // Check if checkout already in progress (prevent concurrent checkouts)
        const checkoutLockExpiry = cartData.checkoutLockedUntil?.toMillis?.()
        const now = Date.now()
        if (checkoutLockExpiry && checkoutLockExpiry > now) {
          throw new HttpsError(
            "failed-precondition",
            "Checkout already in progress. Please wait a moment and try again."
          )
        }

        // Lock cart for 5 minutes (timeout in case of error)
        transaction.update(cartRef, {
          checkoutLockedUntil: new Date(now + 5 * 60 * 1000),
          updatedAt: serverTimestamp(),
        })

        cart = cartData
        cartItems = items
      })

      const photoIds = cartItems
        .filter((item) => item.assetType === "photo")
        .map((item) => item.assetId)
      const packIds = cartItems
        .filter((item) => item.assetType === "pack")
        .map((item) => item.assetId)

      const [photosById, packsById] = await Promise.all([
        getDocumentMap(COLLECTIONS.mediaPhotos, photoIds),
        getDocumentMap(COLLECTIONS.mediaPacks, packIds),
      ])

      const packPhotoIds = uniqueStrings(
        Array.from(packsById.values()).flatMap((pack) =>
          Array.isArray(pack.photoIds) ? pack.photoIds : []
        )
      )
      const packPhotosById = await getDocumentMap(COLLECTIONS.mediaPhotos, packPhotoIds)

      const commissionRates = await getCommissionRatesByPhotographer(
        cartItems.map((item) => item.photographerId)
      )

      const orderItems = cartItems.map((item) => {
        const assetType = typeof item.assetType === "string" ? item.assetType : "photo"
        const assetId = typeof item.assetId === "string" ? item.assetId : ""
        const commissionRate = clampPositiveAmount(commissionRates.get(item.photographerId) || 0)

        if (assetType === "pack") {
          const pack = packsById.get(assetId)
          assertValidPackForSale(pack, assetId, packPhotosById)
          return buildOrderLineItemFromPack(item, pack, commissionRate)
        }

        const photo = photosById.get(assetId)
        assertValidPhotoForSale(photo, assetId)
        return buildOrderLineItemFromPhoto(item, photo, commissionRate)
      })

      const breakdown = computeOrderBreakdown(orderItems)
      const orderRef = db.collection(COLLECTIONS.orders).doc()
      const orderId = orderRef.id
      const photographerIds = uniqueStrings(orderItems.map((item) => item.photographerId))
      const photographerOwnerUids = await getPhotographerOwnerUids(photographerIds)
      const orderPayload = {
        orderId,
        buyerUid: uid,
        photographerIds,
        photographerOwnerUids,
        items: orderItems,
        currency: cart.currency || orderItems[0]?.currency || "EUR",
        subtotal: breakdown.subtotal,
        stripeFee: breakdown.stripeFee,
        platformFee: breakdown.platformFee,
        taxAmount: breakdown.taxAmount,
        total: breakdown.total,
        photographerNetTotal: breakdown.photographerNetTotal,
        paymentStatus: "pending",
        deliveryStatus: "pending",
        pricingBreakdown: breakdown,
        metadata: {
          kind: MEDIA_MARKETPLACE_KIND_ORDER,
          source: "media_marketplace",
          itemCount: orderItems.length,
        },
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      }

      await orderRef.set(orderPayload)

      const stripeClient = getStripe()
      const session = await stripeClient.checkout.sessions.create(
        {
          mode: "payment",
          line_items: buildStripeLineItems(orderItems),
          client_reference_id: orderId,
          success_url: `${successUrl}?orderId=${orderId}`,
          cancel_url: `${cancelUrl}?orderId=${orderId}`,
          metadata: {
            kind: MEDIA_MARKETPLACE_KIND_ORDER,
            orderId,
            uid,
            userId: uid,
          },
          customer_email: request.auth.token.email || undefined,
        },
        { idempotencyKey: `media_marketplace_checkout_${uid}_${orderId}` }
      )

      await orderRef.set(
        {
          stripeCheckoutSessionId: session.id,
          stripeCustomerId: session.customer || null,
          updatedAt: serverTimestamp(),
        },
        { merge: true }
      )

      // Clear cart and checkout lock after successful order creation
      await cartRef.set(
        {
          items: [],
          checkoutLockedUntil: null,
          lastCheckoutOrderId: orderId,
          updatedAt: serverTimestamp(),
        },
        { merge: true }
      )

      return {
        orderId,
        checkoutUrl: session.url,
        stripeSessionId: session.id,
      }
    }
  )

  const createPhotographerSubscriptionCheckoutSession = onCall(
    {
      region: "us-east1",
      cpu: 0.083,
      memory: "256MiB",
      timeoutSeconds: 30,
      secrets: [STRIPE_SECRET_KEY],
    },
    async (request) => {
      if (!request.auth) {
        throw new HttpsError("unauthenticated", "Authentication required")
      }

      const uid = request.auth.uid
      const photographerId = typeof request.data?.photographerId === "string"
        ? request.data.photographerId.trim()
        : ""
      const planId = typeof request.data?.planId === "string"
        ? request.data.planId.trim()
        : ""
      const interval = normalizeInterval(request.data?.billingInterval)

      if (!photographerId || !planId) {
        throw new HttpsError("invalid-argument", "photographerId and planId are required")
      }

      const [photographerSnapshot, planSnapshot] = await Promise.all([
        db.collection(COLLECTIONS.photographers).doc(photographerId).get(),
        db.collection(COLLECTIONS.photographerPlans).doc(planId).get(),
      ])

      if (!photographerSnapshot.exists) {
        throw new HttpsError("not-found", "Photographer not found")
      }
      const photographer = photographerSnapshot.data() || {}
      if (photographer.ownerUid !== uid) {
        throw new HttpsError("permission-denied", "Only the owner can subscribe")
      }

      if (!planSnapshot.exists) {
        throw new HttpsError("not-found", "Plan not found")
      }
      const plan = planSnapshot.data() || {}
      if (plan.isActive === false) {
        throw new HttpsError("failed-precondition", "Plan inactive")
      }

      // Race condition protection: check + create subscription in transaction
      const subscriptionRef = db.collection(COLLECTIONS.photographerSubscriptions).doc()
      const subscriptionId = subscriptionRef.id

      await db.runTransaction(async (transaction) => {
        // Re-check for existing active subscription inside transaction
        const existingSubscriptionSnapshot = await transaction.get(
          db
            .collection(COLLECTIONS.photographerSubscriptions)
            .where("photographerId", "==", photographerId)
            .where("status", "in", Array.from(ACTIVE_SUBSCRIPTION_STATUSES))
            .limit(1)
        )

        if (!existingSubscriptionSnapshot.empty) {
          throw new HttpsError("failed-precondition", "An active subscription already exists")
        }

        // Create subscription document atomically
        transaction.set(subscriptionRef, {
          subscriptionId,
          photographerId,
          ownerUid: uid,
          planId,
          status: "incomplete",
          billingInterval: interval,
          quotaSnapshot: buildQuotaSnapshotFromPlan(plan),
          createdAt: serverTimestamp(),
          updatedAt: serverTimestamp(),
        })
      })

      const priceId = interval === "year" ? plan.stripePriceAnnualId : plan.stripePriceMonthlyId
      if (typeof priceId !== "string" || priceId.trim().length === 0) {
        throw new HttpsError("failed-precondition", "Stripe price not configured for this interval")
      }

      const successUrl = assertHttpsUrlOrDefault(
        request.data?.successUrl,
        "https://maslive.web.app/media-marketplace/subscription-success"
      )
      const cancelUrl = assertHttpsUrlOrDefault(
        request.data?.cancelUrl,
        "https://maslive.web.app/media-marketplace/subscription-cancel"
      )

      const stripeClient = getStripe()
      const session = await stripeClient.checkout.sessions.create(
        {
          mode: "subscription",
          line_items: [{ price: priceId, quantity: 1 }],
          success_url: `${successUrl}?subscriptionId=${subscriptionId}`,
          cancel_url: `${cancelUrl}?subscriptionId=${subscriptionId}`,
          customer_email: request.auth.token.email || photographer.email || undefined,
          metadata: {
            kind: MEDIA_MARKETPLACE_KIND_SUBSCRIPTION,
            uid,
            photographerId,
            planId,
            billingInterval: interval,
            subscriptionDocId: subscriptionId,
          },
          subscription_data: {
            metadata: {
              kind: MEDIA_MARKETPLACE_KIND_SUBSCRIPTION,
              uid,
              photographerId,
              planId,
              billingInterval: interval,
              subscriptionDocId: subscriptionId,
            },
          },
        },
        { idempotencyKey: `media_marketplace_subscription_${photographerId}_${subscriptionId}` }
      )

      await subscriptionRef.set(
        {
          stripeCustomerId: session.customer || null,
          updatedAt: serverTimestamp(),
        },
        { merge: true }
      )

      return {
        subscriptionId,
        checkoutUrl: session.url,
        stripeSessionId: session.id,
      }
    }
  )

  async function handleMarketplaceCheckoutSessionCompleted(session) {
    const kind = session?.metadata?.kind
    if (kind === MEDIA_MARKETPLACE_KIND_ORDER) {
      return fulfillMarketplaceOrder(session)
    }

    if (kind === MEDIA_MARKETPLACE_KIND_SUBSCRIPTION) {
      if (!session?.subscription) return true
      const stripeClient = getStripe()
      const subscription = await stripeClient.subscriptions.retrieve(session.subscription)
      return syncMarketplaceSubscriptionFromStripeSubscription(subscription, session.metadata)
    }

    return false
  }

  async function handleMarketplaceCustomerSubscriptionUpdated(subscription) {
    const existingDoc = await findMarketplaceSubscriptionByStripeId(subscription?.id)
    const isMarketplace = subscription?.metadata?.kind === MEDIA_MARKETPLACE_KIND_SUBSCRIPTION || !!existingDoc
    if (!isMarketplace) return false
    return syncMarketplaceSubscriptionFromStripeSubscription(subscription)
  }

  async function handleMarketplaceCustomerSubscriptionDeleted(subscription) {
    const existingDoc = await findMarketplaceSubscriptionByStripeId(subscription?.id)
    const isMarketplace = subscription?.metadata?.kind === MEDIA_MARKETPLACE_KIND_SUBSCRIPTION || !!existingDoc
    if (!isMarketplace || !existingDoc) return false

    const data = existingDoc.data() || {}
    await existingDoc.ref.set(
      {
        status: "canceled",
        cancelAtPeriodEnd: false,
        canceledAt: timestampFromUnixSeconds(subscription?.canceled_at) || serverTimestamp(),
        updatedAt: serverTimestamp(),
      },
      { merge: true }
    )
    await db.collection(COLLECTIONS.photographers).doc(data.photographerId).set(
      {
        activeSubscriptionId: null,
        updatedAt: serverTimestamp(),
      },
      { merge: true }
    )
    return true
  }

  async function handleMarketplaceInvoicePaid(invoice) {
    const existingDoc = await findMarketplaceSubscriptionByStripeId(invoice?.subscription)
    if (!existingDoc) return false

    const data = existingDoc.data() || {}
    await existingDoc.ref.set(
      {
        status: "active",
        updatedAt: serverTimestamp(),
        metadata: {
          lastInvoiceId: invoice?.id || null,
          lastInvoicePaidAt: serverTimestamp(),
        },
      },
      { merge: true }
    )
    await db.collection(COLLECTIONS.photographers).doc(data.photographerId).set(
      {
        activeSubscriptionId: existingDoc.id,
        activePlanId: data.planId || null,
        updatedAt: serverTimestamp(),
      },
      { merge: true }
    )
    return true
  }

  async function handleMarketplaceInvoicePaymentFailed(invoice) {
    const existingDoc = await findMarketplaceSubscriptionByStripeId(invoice?.subscription)
    if (!existingDoc) return false

    await existingDoc.ref.set(
      {
        status: "past_due",
        updatedAt: serverTimestamp(),
        metadata: {
          lastFailedInvoiceId: invoice?.id || null,
          lastPaymentFailedAt: serverTimestamp(),
        },
      },
      { merge: true }
    )
    return true
  }

  return {
    createMediaMarketplaceCheckout,
    createPhotographerSubscriptionCheckoutSession,
    handleMarketplaceCheckoutSessionCompleted,
    handleMarketplaceCustomerSubscriptionUpdated,
    handleMarketplaceCustomerSubscriptionDeleted,
    handleMarketplaceInvoicePaid,
    handleMarketplaceInvoicePaymentFailed,
  }
}