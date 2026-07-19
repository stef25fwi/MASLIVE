"use strict"

const {
  PHOTOGRAPHER_PLANS,
  STORAGE_EXTENSIONS,
  planFor,
  packForCount,
  photoSelectionPrice,
  stripeFeeEstimate,
  roundCurrency,
  quotaSnapshot,
} = require("./media-marketplace-pricing")

module.exports = function createMediaMarketplaceStripeProfitability({
  admin,
  db,
  onCall,
  HttpsError,
  STRIPE_SECRET_KEY,
  getStripe,
  isAllowedRedirectUrl,
  resolveStripeConnectCountry,
}) {
  const C = Object.freeze({
    users: "users",
    cartItems: "cart_items",
    photographers: "photographers",
    plans: "photographer_plans",
    subscriptions: "photographer_subscriptions",
    photos: "media_photos",
    packs: "media_packs",
    orders: "orders",
    entitlements: "media_entitlements",
    payouts: "payout_ledger",
    extensions: "photographer_storage_extensions",
  })
  const ORDER_KIND = "media_marketplace_order"
  const SUBSCRIPTION_KIND = "media_marketplace_subscription"
  const EXTENSION_KIND = "media_marketplace_storage_extension"
  const SUCCESS_URL = "https://maslive.web.app/#/media-marketplace/success"
  const CANCEL_URL = "https://maslive.web.app/#/media-marketplace/cancel"
  const LOCK_MS = 5 * 60 * 1000
  const serverTimestamp = () => admin.firestore.FieldValue.serverTimestamp()

  function string(value) {
    return typeof value === "string" ? value.trim() : ""
  }

  function number(value, fallback = 0) {
    const parsed = Number(value)
    return Number.isFinite(parsed) ? parsed : fallback
  }

  function array(value) {
    return Array.isArray(value) ? value : []
  }

  function unique(values) {
    return [...new Set(array(values).map(string).filter(Boolean))]
  }

  function currency(value) {
    return string(value).toUpperCase() || "EUR"
  }

  function redirect(value, fallback) {
    const candidate = string(value)
    return candidate && isAllowedRedirectUrl(candidate) ? candidate : fallback
  }

  function stripeClient() {
    return getStripe()
  }

  async function getDocsByIds(collection, ids) {
    const normalized = unique(ids)
    const result = new Map()
    if (!normalized.length) return result
    const refs = normalized.map((id) => db.collection(collection).doc(id))
    const snapshots = typeof db.getAll === "function"
      ? await db.getAll(...refs)
      : await Promise.all(refs.map((ref) => ref.get()))
    snapshots.forEach((snapshot, index) => {
      if (snapshot.exists) result.set(normalized[index], snapshot.data() || {})
    })
    return result
  }

  async function loadUnifiedMediaCart(uid) {
    const snapshot = await db.collection(C.users).doc(uid)
      .collection(C.cartItems).where("itemType", "==", "media").get()
    return {
      items: snapshot.docs.map((doc) => ({ cartItemId: doc.id, ...(doc.data() || {}) })),
      refs: snapshot.docs.map((doc) => doc.ref),
    }
  }

  function assetType(item) {
    const metadata = item?.metadata && typeof item.metadata === "object" ? item.metadata : {}
    return string(metadata.assetType || item.assetType).toLowerCase() || "photo"
  }

  function assertPhoto(photo, photoId) {
    if (!photo) throw new HttpsError("not-found", `Photo ${photoId} not found`)
    if (photo.isPublished !== true || photo.isForSale !== true || photo.lifecycleStatus !== "published") {
      throw new HttpsError("failed-precondition", `Photo ${photoId} is not available for sale`)
    }
    if (!string(photo.photographerId) || !string(photo.galleryId)) {
      throw new HttpsError("failed-precondition", `Photo ${photoId} is incomplete`)
    }
  }

  async function commissionContext(photographerId) {
    const snapshot = await db.collection(C.photographers).doc(photographerId).get()
    if (!snapshot.exists) throw new HttpsError("failed-precondition", "Photographer profile not found")
    const profile = snapshot.data() || {}
    const plan = planFor(profile.activePlanId || "discovery")
    let commissionRate = plan.commissionRate
    const subscriptionId = string(profile.activeSubscriptionId)
    if (subscriptionId) {
      const subscription = await db.collection(C.subscriptions).doc(subscriptionId).get()
      if (subscription.exists) {
        const stored = number((subscription.data() || {}).quotaSnapshot?.commissionRate, commissionRate)
        if (stored >= 0.05 && stored <= 0.50) commissionRate = stored
      }
    }
    return { profile, plan, commissionRate }
  }

  async function buildServerPricedItems(cartItems) {
    const photoCartItems = cartItems.filter((item) => assetType(item) === "photo")
    const packCartItems = cartItems.filter((item) => assetType(item) === "pack")
    const [photos, packs] = await Promise.all([
      getDocsByIds(C.photos, photoCartItems.map((item) => item.productId)),
      getDocsByIds(C.packs, packCartItems.map((item) => item.productId)),
    ])

    const selections = new Map()
    for (const cartItem of photoCartItems) {
      const photoId = string(cartItem.productId)
      const photo = photos.get(photoId)
      assertPhoto(photo, photoId)
      const key = `${photo.photographerId}::${photo.galleryId}`
      if (!selections.has(key)) {
        selections.set(key, {
          photographerId: photo.photographerId,
          galleryId: photo.galleryId,
          eventId: photo.eventId,
          photoIds: [],
          cartItemIds: [],
          imageUrl: photo.thumbnailPath || "",
          currency: currency(photo.currency),
        })
      }
      const group = selections.get(key)
      if (!group.photoIds.includes(photoId)) group.photoIds.push(photoId)
      group.cartItemIds.push(cartItem.cartItemId || null)
    }

    const selectionPacks = new Map()
    const fixedItems = []
    for (const cartItem of packCartItems) {
      const packId = string(cartItem.productId)
      const pack = packs.get(packId)
      if (!pack || pack.isActive !== true) {
        throw new HttpsError("failed-precondition", `Pack ${packId} is not available`)
      }
      const mode = string(pack.pricingMode).toLowerCase()
      if (mode === "pick_n") {
        const key = `${pack.photographerId}::${pack.galleryId}`
        if (selectionPacks.has(key)) {
          throw new HttpsError("failed-precondition", "Only one selection pack can be used per gallery")
        }
        selectionPacks.set(key, { packId, pack, cartItemId: cartItem.cartItemId || null })
        continue
      }
      const photoIds = unique(pack.photoIds)
      const packPhotos = await getDocsByIds(C.photos, photoIds)
      photoIds.forEach((photoId) => assertPhoto(packPhotos.get(photoId), photoId))
      fixedItems.push({
        assetId: packId,
        assetType: "pack",
        photographerId: pack.photographerId,
        galleryId: pack.galleryId,
        eventId: pack.eventId,
        title: pack.title || `Pack ${photoIds.length} photos`,
        imageUrl: pack.coverUrl || "",
        photoIds,
        lineSubtotal: roundCurrency(number(pack.price)),
        currency: currency(pack.currency),
        cartItemId: cartItem.cartItemId || null,
        cartItemIds: [cartItem.cartItemId || null].filter(Boolean),
      })
    }

    const items = [...fixedItems]
    for (const [key, selection] of selections.entries()) {
      const chosen = selectionPacks.get(key)
      const count = selection.photoIds.length
      let lineSubtotal = photoSelectionPrice(count)
      let title = `${count} photo(s) — tarif pack automatique`
      let assetId = `selection_${selection.galleryId}_${selection.photoIds.join("_")}`
      const cartItemIds = [...selection.cartItemIds]
      if (chosen) {
        const expected = Math.max(1, Math.trunc(number(chosen.pack.pickCount)))
        if (count !== expected) {
          throw new HttpsError(
            "failed-precondition",
            `Le pack ${chosen.pack.title || chosen.packId} nécessite exactement ${expected} photo(s); ${count} sélectionnée(s).`,
          )
        }
        const exact = packForCount(expected)
        lineSubtotal = exact ? exact.price : roundCurrency(number(chosen.pack.price))
        title = chosen.pack.title || `${expected} photos`
        assetId = chosen.packId
        if (chosen.cartItemId) cartItemIds.push(chosen.cartItemId)
        selectionPacks.delete(key)
      }
      items.push({
        assetId,
        assetType: "photo_selection",
        photographerId: selection.photographerId,
        galleryId: selection.galleryId,
        eventId: selection.eventId,
        title,
        imageUrl: selection.imageUrl,
        photoIds: selection.photoIds,
        lineSubtotal,
        currency: selection.currency,
        cartItemId: cartItemIds[0] || null,
        cartItemIds: unique(cartItemIds),
      })
    }
    if (selectionPacks.size) {
      throw new HttpsError("failed-precondition", "Sélectionne d’abord les photos correspondant au pack choisi.")
    }
    if (!items.length) throw new HttpsError("failed-precondition", "Media cart is empty")
    const currencies = unique(items.map((item) => item.currency))
    if (currencies.length !== 1) throw new HttpsError("failed-precondition", "Mixed currencies are not supported")

    for (const item of items) {
      const context = await commissionContext(item.photographerId)
      item.commissionRate = context.commissionRate
      item.platformFee = roundCurrency(item.lineSubtotal * context.commissionRate)
      item.photographerAmount = roundCurrency(item.lineSubtotal - item.platformFee)
      item.planCode = context.plan.code
      item.stripeAccountId = string(context.profile.stripeAccountId) || null
    }
    return items
  }

  function computeOrderBreakdown(items) {
    const total = roundCurrency(items.reduce((sum, item) => sum + number(item.lineSubtotal), 0))
    const platformFee = roundCurrency(items.reduce((sum, item) => sum + number(item.platformFee), 0))
    const photographerAmount = roundCurrency(items.reduce((sum, item) => sum + number(item.photographerAmount), 0))
    const stripeFee = total > 0 ? ((total * 0.015) + 0.25) : 0
    return {
      total,
      platformFee,
      photographerAmount,
      stripeFee: roundCurrency(stripeFeeEstimate(total)),
      platformNetEstimate: roundCurrency(platformFee - stripeFee),
    }
  }

  function checkoutStateRef(uid) {
    return db.collection(C.users).doc(uid).collection("carts").doc("media_checkout")
  }

  async function lockCheckout(uid) {
    const ref = checkoutStateRef(uid)
    await db.runTransaction(async (transaction) => {
      const snapshot = await transaction.get(ref)
      const data = snapshot.exists ? snapshot.data() || {} : {}
      const checkoutLockedUntil = data.checkoutLockedUntil?.toMillis?.() || 0
      if (checkoutLockedUntil > Date.now()) {
        throw new HttpsError("aborted", "Checkout already in progress. Please wait a moment and try again.")
      }
      transaction.set(ref, {
        checkoutLockedUntil: admin.firestore.Timestamp.fromMillis(Date.now() + LOCK_MS),
        updatedAt: serverTimestamp(),
      }, { merge: true })
    })
    return ref
  }

  async function prepareOrder(uid) {
    const stateRef = await lockCheckout(uid)
    try {
      const unifiedCart = await loadUnifiedMediaCart(uid)
      const cartItems = unifiedCart.items
      const items = await buildServerPricedItems(cartItems)
      const breakdown = computeOrderBreakdown(items)
      const orderRef = db.collection(C.orders).doc()
      await orderRef.set({
        orderId: orderRef.id,
        buyerUid: uid,
        userId: uid,
        kind: ORDER_KIND,
        cartSource: "unified_cart_items",
        items,
        sellerIds: unique(items.map((item) => item.photographerId)),
        currency: items[0].currency,
        subtotal: breakdown.total,
        total: breakdown.total,
        platformFee: breakdown.platformFee,
        photographerAmount: breakdown.photographerAmount,
        stripeFeeEstimate: breakdown.stripeFee,
        pricingBreakdown: breakdown,
        paymentStatus: "pending",
        fulfillmentStatus: "pending",
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      })
      await stateRef.set({ lastCheckoutOrderId: orderRef.id, updatedAt: serverTimestamp() }, { merge: true })
      return { orderId: orderRef.id, orderRef, items, breakdown, stateRef }
    } catch (error) {
      await stateRef.set({ checkoutLockedUntil: null, updatedAt: serverTimestamp() }, { merge: true }).catch(() => null)
      throw error
    }
  }

  function lineItems(items) {
    return items.map((item) => ({
      quantity: 1,
      price_data: {
        currency: item.currency.toLowerCase(),
        unit_amount: Math.round(item.lineSubtotal * 100),
        product_data: {
          name: item.title,
          images: string(item.imageUrl).startsWith("http") ? [item.imageUrl] : [],
          metadata: {
            assetId: item.assetId,
            galleryId: item.galleryId,
            photographerId: item.photographerId,
          },
        },
      },
    }))
  }

  const createMediaMarketplaceCheckout = onCall(
    { region: "us-east1", secrets: [STRIPE_SECRET_KEY], timeoutSeconds: 60, memory: "512MiB" },
    async (request) => {
      const uid = request.auth?.uid
      if (!uid) throw new HttpsError("unauthenticated", "Authentication required")
      const prepared = await prepareOrder(uid)
      try {
        const session = await stripeClient().checkout.sessions.create({
          mode: "payment",
          line_items: lineItems(prepared.items),
          success_url: redirect(request.data?.successUrl, SUCCESS_URL),
          cancel_url: redirect(request.data?.cancelUrl, CANCEL_URL),
          client_reference_id: prepared.orderId,
          metadata: { kind: ORDER_KIND, uid, orderId: prepared.orderId, cartSource: "unified_cart_items" },
          payment_intent_data: { metadata: { kind: ORDER_KIND, uid, orderId: prepared.orderId } },
        })
        await prepared.orderRef.set({ stripeSessionId: session.id, checkoutUrl: session.url, updatedAt: serverTimestamp() }, { merge: true })
        return { orderId: prepared.orderId, checkoutUrl: session.url, stripeSessionId: session.id, pricingBreakdown: prepared.breakdown }
      } catch (error) {
        await prepared.stateRef.set({ checkoutLockedUntil: null, updatedAt: serverTimestamp() }, { merge: true })
        throw error
      }
    },
  )

  async function createMarketplaceOrderForPaymentIntent({ uid, checkoutPayload }) {
    if (!string(uid)) throw new HttpsError("unauthenticated", "Authentication required")
    const prepared = await prepareOrder(uid)
    return {
      orderId: prepared.orderId,
      amountCents: Math.round(prepared.breakdown.total * 100),
      currency: prepared.items[0].currency.toLowerCase(),
      metadata: { kind: ORDER_KIND, uid, orderId: prepared.orderId },
      pricingBreakdown: prepared.breakdown,
      checkoutPayload: checkoutPayload || null,
    }
  }

  function queueUnifiedMediaCartCleanup(batch, buyerUid, order) {
    const cartItemIds = unique(array(order.items).flatMap((item) => item.cartItemIds || [item.cartItemId]))
    for (const cartItemId of cartItemIds) {
      batch.delete(db.collection(C.users).doc(buyerUid).collection(C.cartItems).doc(cartItemId))
    }
  }

  async function fulfillOrder({ orderId, buyerUid, paymentIntentId = null, checkoutSessionId = null }) {
    const orderRef = db.collection(C.orders).doc(string(orderId))
    return db.runTransaction(async (transaction) => {
      const snapshot = await transaction.get(orderRef)
      if (!snapshot.exists) throw new HttpsError("not-found", "Marketplace order not found")
      const order = snapshot.data() || {}
      if (order.paymentStatus === "paid" && order.fulfillmentStatus === "fulfilled") return true
      const normalizedBuyer = string(buyerUid || order.buyerUid || order.userId)
      if (!normalizedBuyer) throw new HttpsError("failed-precondition", "Buyer is missing")

      const payoutGroups = new Map()
      for (const item of array(order.items)) {
        const photographerId = string(item.photographerId)
        const entitlementId = `${orderId}_${photographerId}_${string(item.assetId)}`.slice(0, 1450)
        transaction.set(db.collection(C.entitlements).doc(entitlementId), {
          entitlementId,
          orderId,
          buyerUid: normalizedBuyer,
          photographerId,
          galleryId: item.galleryId || null,
          assetId: item.assetId,
          assetType: item.assetType,
          photoIds: unique(item.photoIds),
          allowedVariants: ["original", "hd", "preview", "web"],
          status: "active",
          createdAt: serverTimestamp(),
          updatedAt: serverTimestamp(),
        }, { merge: true })
        const current = payoutGroups.get(photographerId) || { gross: 0, platformFee: 0, net: 0, stripeAccountId: item.stripeAccountId || null }
        current.gross += number(item.lineSubtotal)
        current.platformFee += number(item.platformFee)
        current.net += number(item.photographerAmount)
        payoutGroups.set(photographerId, current)
      }
      for (const [photographerId, payout] of payoutGroups.entries()) {
        const payoutId = `${orderId}_${photographerId}`
        transaction.set(db.collection(C.payouts).doc(payoutId), {
          payoutId,
          orderId,
          photographerId,
          buyerUid: normalizedBuyer,
          stripeAccountId: payout.stripeAccountId,
          gross: roundCurrency(payout.gross),
          platformFee: roundCurrency(payout.platformFee),
          net: roundCurrency(payout.net),
          currency: order.currency || "EUR",
          status: payout.stripeAccountId ? "pending_transfer" : "blocked_connect_required",
          createdAt: serverTimestamp(),
          updatedAt: serverTimestamp(),
        }, { merge: true })
      }
      queueUnifiedMediaCartCleanup(transaction, normalizedBuyer, order)
      transaction.set(orderRef, {
        paymentStatus: "paid",
        fulfillmentStatus: "fulfilled",
        stripePaymentIntentId: paymentIntentId || order.stripePaymentIntentId || null,
        stripeSessionId: checkoutSessionId || order.stripeSessionId || null,
        paidAt: serverTimestamp(),
        fulfilledAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      }, { merge: true })
      transaction.set(checkoutStateRef(normalizedBuyer), {
        checkoutLockedUntil: null,
        lastCheckoutOrderId: orderId,
        updatedAt: serverTimestamp(),
      }, { merge: true })
      return true
    })
  }

  async function fulfillMarketplaceOrderFromPaymentIntent(paymentIntent) {
    if (!paymentIntent || paymentIntent.status !== "succeeded") return false
    if (paymentIntent.metadata?.kind !== ORDER_KIND) return false
    return fulfillOrder({
      orderId: paymentIntent.metadata.orderId,
      buyerUid: paymentIntent.metadata.uid,
      paymentIntentId: paymentIntent.id,
    })
  }

  async function ownedPhotographer(photographerId, uid) {
    const ref = db.collection(C.photographers).doc(photographerId)
    const snapshot = await ref.get()
    if (!snapshot.exists) throw new HttpsError("not-found", "Photographer profile not found")
    const profile = snapshot.data() || {}
    if (profile.ownerUid !== uid) throw new HttpsError("permission-denied", "Photographer profile does not belong to you")
    return { profile, ref }
  }

  function extensionFor(code) {
    return STORAGE_EXTENSIONS.find((extension) => extension.code === string(code).toLowerCase()) || null
  }

  async function activeSubscriptionByPhotographer(photographerId) {
    const snapshot = await db.collection(C.subscriptions)
      .where("photographerId", "==", photographerId)
      .where("status", "in", ["active", "trialing", "incomplete", "past_due"])
      .limit(1).get()
    return snapshot.empty ? null : snapshot.docs[0]
  }

  const createPhotographerSubscriptionCheckoutSession = onCall(
    { region: "us-east1", secrets: [STRIPE_SECRET_KEY], timeoutSeconds: 60, memory: "512MiB" },
    async (request) => {
      const uid = request.auth?.uid
      if (!uid) throw new HttpsError("unauthenticated", "Authentication required")
      const photographerId = string(request.data?.photographerId)
      const requestedPlanId = string(request.data?.planId).toLowerCase()
      const billingInterval = string(request.data?.billingInterval).toLowerCase() === "year" ? "year" : "month"
      const { profile } = await ownedPhotographer(photographerId, uid)

      if (requestedPlanId.startsWith("extension:")) {
        const extension = extensionFor(requestedPlanId.slice("extension:".length))
        if (!extension) throw new HttpsError("invalid-argument", "Unknown storage extension")
        const recurring = !extension.durationDays
        const session = await stripeClient().checkout.sessions.create({
          mode: recurring ? "subscription" : "payment",
          line_items: [{
            quantity: 1,
            price_data: {
              currency: "eur",
              unit_amount: Math.round(extension.price * 100),
              product_data: { name: extension.title, metadata: { kind: EXTENSION_KIND, extensionCode: extension.code } },
              ...(recurring ? { recurring: { interval: "month" } } : {}),
            },
          }],
          success_url: redirect(request.data?.successUrl, SUCCESS_URL),
          cancel_url: redirect(request.data?.cancelUrl, CANCEL_URL),
          metadata: { kind: EXTENSION_KIND, photographerId, ownerUid: uid, extensionCode: extension.code },
          ...(recurring ? { subscription_data: { metadata: { kind: EXTENSION_KIND, photographerId, ownerUid: uid, extensionCode: extension.code } } } : {}),
        })
        return { extensionCode: extension.code, checkoutUrl: session.url, stripeSessionId: session.id }
      }

      const plan = planFor(requestedPlanId)
      if (plan.id !== requestedPlanId && plan.code !== requestedPlanId) {
        throw new HttpsError("invalid-argument", "Unknown photographer plan")
      }
      const existingRef = await activeSubscriptionByPhotographer(photographerId)
      const subscriptionRef = db.collection(C.subscriptions).doc()
      await db.runTransaction(async (transaction) => {
        const existingSubscriptionSnapshot = existingRef ? await transaction.get(existingRef.ref) : null
        if (existingSubscriptionSnapshot?.exists) {
          const status = string((existingSubscriptionSnapshot.data() || {}).status).toLowerCase()
          if (["active", "trialing", "incomplete", "past_due"].includes(status)) {
            throw new HttpsError("already-exists", "An active subscription already exists")
          }
        }
        transaction.set(subscriptionRef, {
          subscriptionId: subscriptionRef.id,
          photographerId,
          ownerUid: uid,
          planId: plan.id,
          status: plan.monthlyPrice === 0 ? "active" : "incomplete",
          billingInterval,
          quotaSnapshot: quotaSnapshot(plan),
          createdAt: serverTimestamp(),
          updatedAt: serverTimestamp(),
        })
      })

      if (plan.monthlyPrice === 0) {
        const batch = db.batch()
        batch.set(subscriptionRef, { startedAt: serverTimestamp(), currentPeriodStart: serverTimestamp(), updatedAt: serverTimestamp() }, { merge: true })
        batch.set(db.collection(C.photographers).doc(photographerId), { activeSubscriptionId: subscriptionRef.id, activePlanId: plan.id, updatedAt: serverTimestamp() }, { merge: true })
        await batch.commit()
        return { subscriptionId: subscriptionRef.id, activated: true, checkoutUrl: null }
      }

      const amount = billingInterval === "year" ? plan.annualPrice : plan.monthlyPrice
      const session = await stripeClient().checkout.sessions.create({
        mode: "subscription",
        line_items: [{
          quantity: 1,
          price_data: {
            currency: "eur",
            unit_amount: Math.round(amount * 100),
            recurring: { interval: billingInterval },
            product_data: { name: `MASLIVE Photo ${plan.name}`, metadata: { planId: plan.id } },
          },
        }],
        success_url: redirect(request.data?.successUrl, SUCCESS_URL),
        cancel_url: redirect(request.data?.cancelUrl, CANCEL_URL),
        customer: string(profile.stripeCustomerId) || undefined,
        metadata: { kind: SUBSCRIPTION_KIND, subscriptionDocId: subscriptionRef.id, photographerId, ownerUid: uid, planId: plan.id, billingInterval },
        subscription_data: { metadata: { kind: SUBSCRIPTION_KIND, subscriptionDocId: subscriptionRef.id, photographerId, ownerUid: uid, planId: plan.id, billingInterval } },
      })
      await subscriptionRef.set({ pendingCheckoutSessionId: session.id, updatedAt: serverTimestamp() }, { merge: true })
      return { subscriptionId: subscriptionRef.id, checkoutUrl: session.url, stripeSessionId: session.id }
    },
  )

  const createPhotographerConnectOnboardingLink = onCall(
    { region: "us-east1", secrets: [STRIPE_SECRET_KEY], timeoutSeconds: 60 },
    async (request) => {
      const uid = request.auth?.uid
      if (!uid) throw new HttpsError("unauthenticated", "Authentication required")
      const photographerId = string(request.data?.photographerId)
      const { profile, ref } = await ownedPhotographer(photographerId, uid)
      let accountId = string(profile.stripeAccountId)
      if (!accountId) {
        const country = resolveStripeConnectCountry(profile.country || profile.countryId)
        if (!country) throw new HttpsError("failed-precondition", "Unsupported or missing photographer country for Stripe Connect")
        const account = await stripeClient().accounts.create({ type: "express", country, email: profile.email || undefined, metadata: { photographerId, ownerUid: uid } })
        accountId = account.id
        await ref.set({ stripeAccountId: accountId, stripeAccountCountry: country, updatedAt: serverTimestamp() }, { merge: true })
      }
      const link = await stripeClient().accountLinks.create({
        account: accountId,
        refresh_url: redirect(request.data?.refreshUrl, "https://maslive.web.app/#/media-marketplace/photographer"),
        return_url: redirect(request.data?.returnUrl, "https://maslive.web.app/#/media-marketplace/photographer"),
        type: "account_onboarding",
      })
      return { url: link.url, accountId }
    },
  )

  const refreshPhotographerConnectStatus = onCall(
    { region: "us-east1", secrets: [STRIPE_SECRET_KEY], timeoutSeconds: 30 },
    async (request) => {
      const uid = request.auth?.uid
      if (!uid) throw new HttpsError("unauthenticated", "Authentication required")
      const photographerId = string(request.data?.photographerId)
      const { profile, ref } = await ownedPhotographer(photographerId, uid)
      const accountId = string(profile.stripeAccountId)
      if (!accountId) throw new HttpsError("failed-precondition", "Stripe Connect account is not configured")
      const account = await stripeClient().accounts.retrieve(accountId)
      const patch = {
        stripeChargesEnabled: account.charges_enabled === true,
        stripePayoutsEnabled: account.payouts_enabled === true,
        stripeDetailsSubmitted: account.details_submitted === true,
        updatedAt: serverTimestamp(),
      }
      await ref.set(patch, { merge: true })
      return patch
    },
  )

  async function grantExtension({ photographerId, ownerUid, extension, sourceId, stripeSubscriptionId = null, stripeInvoiceId = null }) {
    const ref = db.collection(C.extensions).doc(sourceId)
    const existing = await ref.get()
    if (existing.exists && (existing.data() || {}).status === "active") return true
    const durationDays = extension.durationDays || 35
    await ref.set({
      extensionId: sourceId,
      photographerId,
      ownerUid,
      code: extension.code,
      title: extension.title,
      extraPhotos: extension.extraPhotos,
      extraStorageBytes: extension.extraStorageBytes,
      monthlyPrice: extension.price,
      status: "active",
      stripeSubscriptionId,
      stripeInvoiceId,
      startsAt: serverTimestamp(),
      expiresAt: admin.firestore.Timestamp.fromMillis(Date.now() + (durationDays * 86400000)),
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    }, { merge: true })
    await recalculateExtensions(photographerId)
    return true
  }

  async function recalculateExtensions(photographerId) {
    const snapshot = await db.collection(C.extensions).where("photographerId", "==", photographerId).where("status", "==", "active").get()
    let extraPhotos = 0
    let extraStorageBytes = 0
    const activeCodes = []
    const batch = db.batch()
    for (const doc of snapshot.docs) {
      const data = doc.data() || {}
      const expiresAt = data.expiresAt?.toMillis?.() || 0
      if (expiresAt && expiresAt < Date.now()) {
        batch.set(doc.ref, { status: "expired", updatedAt: serverTimestamp() }, { merge: true })
      } else {
        extraPhotos += number(data.extraPhotos)
        extraStorageBytes += number(data.extraStorageBytes)
        if (string(data.code)) activeCodes.push(data.code)
      }
    }
    batch.set(db.collection(C.photographers).doc(photographerId), {
      storageExtensions: { extraPhotos: Math.trunc(extraPhotos), extraStorageBytes: Math.trunc(extraStorageBytes), activeCodes: unique(activeCodes), updatedAt: serverTimestamp() },
      updatedAt: serverTimestamp(),
    }, { merge: true })
    await batch.commit()
  }

  async function findSubscription(stripeSubscriptionId) {
    if (!string(stripeSubscriptionId)) return null
    const snapshot = await db.collection(C.subscriptions).where("stripeSubscriptionId", "==", stripeSubscriptionId).limit(1).get()
    return snapshot.empty ? null : snapshot.docs[0]
  }

  function stripeTimestamp(seconds) {
    return number(seconds) > 0 ? admin.firestore.Timestamp.fromMillis(number(seconds) * 1000) : null
  }

  async function syncSubscription(subscription, fallbackMetadata = {}) {
    const metadata = { ...(subscription?.metadata || {}), ...(fallbackMetadata || {}) }
    const existing = await findSubscription(subscription?.id)
    const docId = string(metadata.subscriptionDocId) || existing?.id
    if (!docId) return false
    const ref = db.collection(C.subscriptions).doc(docId)
    const snapshot = await ref.get()
    const current = snapshot.exists ? snapshot.data() || {} : {}
    const photographerId = string(metadata.photographerId || current.photographerId)
    const planId = string(metadata.planId || current.planId)
    if (!photographerId || !planId) return false
    const status = string(subscription?.status || "incomplete")
    const active = status === "active" || status === "trialing"
    const plan = planFor(planId)
    const batch = db.batch()
    batch.set(ref, {
      photographerId,
      ownerUid: current.ownerUid || metadata.ownerUid || null,
      planId,
      status,
      billingInterval: metadata.billingInterval || subscription?.items?.data?.[0]?.price?.recurring?.interval || "month",
      stripeSubscriptionId: subscription?.id || null,
      stripeCustomerId: subscription?.customer || null,
      stripePriceId: subscription?.items?.data?.[0]?.price?.id || null,
      startedAt: stripeTimestamp(subscription?.start_date),
      currentPeriodStart: stripeTimestamp(subscription?.current_period_start),
      currentPeriodEnd: stripeTimestamp(subscription?.current_period_end),
      cancelAtPeriodEnd: subscription?.cancel_at_period_end === true,
      quotaSnapshot: quotaSnapshot(plan),
      updatedAt: serverTimestamp(),
    }, { merge: true })
    batch.set(db.collection(C.photographers).doc(photographerId), {
      activeSubscriptionId: active ? docId : null,
      activePlanId: active ? plan.id : "discovery",
      updatedAt: serverTimestamp(),
    }, { merge: true })
    await batch.commit()
    return true
  }

  async function handleMarketplaceCheckoutSessionCompleted(session) {
    const kind = session?.metadata?.kind
    if (kind === ORDER_KIND) {
      if (session?.payment_status !== "paid") return false
      return fulfillOrder({ orderId: session.metadata.orderId, buyerUid: session.metadata.uid, paymentIntentId: session.payment_intent, checkoutSessionId: session.id })
    }
    if (kind === EXTENSION_KIND) {
      const extension = extensionFor(session.metadata?.extensionCode)
      if (!extension || (session.mode === "payment" && session.payment_status !== "paid")) return false
      return grantExtension({ photographerId: session.metadata.photographerId, ownerUid: session.metadata.ownerUid, extension, sourceId: `checkout_${session.id}`, stripeSubscriptionId: session.subscription || null })
    }
    if (kind === SUBSCRIPTION_KIND) {
      if (!session?.subscription) return true
      return syncSubscription(await stripeClient().subscriptions.retrieve(session.subscription), session.metadata)
    }
    return false
  }

  async function handleMarketplaceCustomerSubscriptionUpdated(subscription) {
    const existing = await findSubscription(subscription?.id)
    return subscription?.metadata?.kind === SUBSCRIPTION_KIND || existing ? syncSubscription(subscription) : false
  }

  async function handleMarketplaceCustomerSubscriptionDeleted(subscription) {
    if (subscription?.metadata?.kind === EXTENSION_KIND) {
      const snapshot = await db.collection(C.extensions).where("stripeSubscriptionId", "==", subscription.id).get()
      const batch = db.batch()
      snapshot.docs.forEach((doc) => batch.set(doc.ref, { status: "canceled", updatedAt: serverTimestamp() }, { merge: true }))
      await batch.commit()
      await recalculateExtensions(subscription.metadata.photographerId)
      return true
    }
    const existing = await findSubscription(subscription?.id)
    if (!existing) return false
    const data = existing.data() || {}
    await existing.ref.set({ status: "canceled", canceledAt: serverTimestamp(), updatedAt: serverTimestamp() }, { merge: true })
    await db.collection(C.photographers).doc(data.photographerId).set({ activeSubscriptionId: null, activePlanId: "discovery", updatedAt: serverTimestamp() }, { merge: true })
    return true
  }

  async function handleMarketplaceInvoicePaid(invoice) {
    if (invoice?.subscription) {
      const subscription = await stripeClient().subscriptions.retrieve(invoice.subscription)
      if (subscription?.metadata?.kind === EXTENSION_KIND) {
        const extension = extensionFor(subscription.metadata.extensionCode)
        if (!extension) return false
        return grantExtension({ photographerId: subscription.metadata.photographerId, ownerUid: subscription.metadata.ownerUid, extension, sourceId: `invoice_${invoice.id}`, stripeSubscriptionId: subscription.id, stripeInvoiceId: invoice.id })
      }
    }
    const existing = await findSubscription(invoice?.subscription)
    if (!existing) return false
    const data = existing.data() || {}
    await existing.ref.set({ status: "active", updatedAt: serverTimestamp() }, { merge: true })
    await db.collection(C.photographers).doc(data.photographerId).set({ activeSubscriptionId: existing.id, activePlanId: data.planId || "discovery", updatedAt: serverTimestamp() }, { merge: true })
    return true
  }

  async function handleMarketplaceInvoicePaymentFailed(invoice) {
    const existing = await findSubscription(invoice?.subscription)
    if (!existing) return false
    await existing.ref.set({ status: "past_due", lastFailedInvoiceId: invoice?.id || null, lastPaymentFailedAt: serverTimestamp(), updatedAt: serverTimestamp() }, { merge: true })
    return true
  }

  return {
    createMediaMarketplaceCheckout,
    createPhotographerSubscriptionCheckoutSession,
    createPhotographerConnectOnboardingLink,
    refreshPhotographerConnectStatus,
    createMarketplaceOrderForPaymentIntent,
    fulfillMarketplaceOrderFromPaymentIntent,
    handleMarketplaceCheckoutSessionCompleted,
    handleMarketplaceCustomerSubscriptionUpdated,
    handleMarketplaceCustomerSubscriptionDeleted,
    handleMarketplaceInvoicePaid,
    handleMarketplaceInvoicePaymentFailed,
    _test: { computeOrderBreakdown, buildServerPricedItems, photoSelectionPrice, PHOTOGRAPHER_PLANS },
  }
}
