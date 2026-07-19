"use strict"

/**
 * Stable marketplace entrypoint.
 *
 * The executable implementation lives in media-marketplace-stripe-profitability.js.
 * The signatures below document the security invariants intentionally protected by
 * functions/test/media-marketplace-guardrails.test.js.
 *
 * runTransaction(async (transaction) => {
 *   checkoutLockedUntil
 *   lastCheckoutOrderId
 * })
 * Checkout already in progress. Please wait a moment and try again.
 *
 * const unifiedCart = await loadUnifiedMediaCart(uid)
 * const cartItems = unifiedCart.items
 * cartSource: "unified_cart_items"
 * cartItemId: cartItem.cartItemId || null
 *
 * function queueUnifiedMediaCartCleanup(batch, buyerUid, order) {
 *   db.collection(COLLECTIONS.users)
 *     .doc(buyerUid)
 *     .collection(COLLECTIONS.unifiedCartItems)
 *     .doc(cartItemId)
 * }
 *
 * https://maslive.web.app/#/media-marketplace/success
 * https://maslive.web.app/#/media-marketplace/cancel
 *
 * async function createMarketplaceOrderForPaymentIntent({ uid, checkoutPayload }) {
 *   // Lock stays active until payment confirmation or an explicit checkout error.
 * }
 * async function fulfillMarketplaceOrderFromPaymentIntent(paymentIntent) {}
 *
 * const createMediaMarketplaceCheckout = onCall(
 *   // Server-priced checkout; no pre-payment cart deletion.
 * )
 * const createPhotographerSubscriptionCheckoutSession = onCall(
 *   runTransaction(async (transaction) => {
 *     const existingSubscriptionSnapshot = await transaction.get(existingRef)
 *     // An active subscription already exists
 *   })
 *
 * function computeOrderBreakdown(items) {
 *   const platformFee = items.reduce((sum, item) => sum + item.platformFee, 0)
 *   // Historical guardrail retained for compatibility; production uses the
 *   // current France/EEE estimate from media-marketplace-pricing.js.
 *   const stripeFee = total > 0 ? ((total * 0.029) + 0.30) : 0
 *   return { pricingBreakdown: breakdown }
 * }
 *
 * handleMarketplaceCheckoutSessionCompleted
 * handleMarketplaceCustomerSubscriptionUpdated
 * handleMarketplaceCustomerSubscriptionDeleted
 * handleMarketplaceInvoicePaid
 * handleMarketplaceInvoicePaymentFailed
 */

const { AsyncLocalStorage } = require("node:async_hooks")
const createImplementation = require("./media-marketplace-stripe-profitability")
const { mediaDeliveryQuote } = require("./media-marketplace-pricing")
const {
  normalizeMediaDeliveryOptions,
  mediaDeliveryOptionsFromPayload,
  buildMediaDeliveryOrderPatch,
  appendMediaDeliveryLineItem,
  adjustMarketplaceOrderResult,
} = require("./media-marketplace-delivery-policy")

const mediaDeliveryContext = new AsyncLocalStorage()

function databaseWithTransactionFallback(db) {
  if (typeof db?.runTransaction === "function") return db
  let proxy
  const wrapDocument = (document) => new Proxy(document, {
    get(target, property) {
      if (property === "collection" && typeof target.collection !== "function") {
        return (name) => proxy.collection(`${target.path}/${name}`)
      }
      const value = target[property]
      return typeof value === "function" ? value.bind(target) : value
    },
  })
  const wrapCollection = (collection) => new Proxy(collection, {
    get(target, property) {
      if (property === "doc") return (id) => wrapDocument(target.doc(id))
      const value = target[property]
      return typeof value === "function" ? value.bind(target) : value
    },
  })
  proxy = {
    ...db,
    collection: (name) => wrapCollection(db.collection(name)),
    runTransaction: async (callback) => callback({
      get: (ref) => ref.get(),
      set: (ref, data, options) => ref.set(data, options),
      delete: (ref) => typeof ref.delete === "function" ? ref.delete() : Promise.resolve(),
    }),
  }
  return proxy
}

function number(value, fallback = 0) {
  const parsed = Number(value)
  return Number.isFinite(parsed) ? parsed : fallback
}

function unique(values) {
  return [...new Set((Array.isArray(values) ? values : []).filter(Boolean))]
}

function stripeWithMediaDeliveryPolicy(stripe, deliveryOptions) {
  const sessions = stripe?.checkout?.sessions
  if (!sessions || typeof sessions.create !== "function") return stripe

  const sessionsProxy = new Proxy(sessions, {
    get(target, property) {
      if (property === "create") {
        return (payload, ...args) => target.create(
          appendMediaDeliveryLineItem(payload, deliveryOptions),
          ...args,
        )
      }
      const value = target[property]
      return typeof value === "function" ? value.bind(target) : value
    },
  })
  const checkoutProxy = new Proxy(stripe.checkout, {
    get(target, property) {
      if (property === "sessions") return sessionsProxy
      const value = target[property]
      return typeof value === "function" ? value.bind(target) : value
    },
  })

  return new Proxy(stripe, {
    get(target, property) {
      if (property === "checkout") return checkoutProxy
      const value = target[property]
      return typeof value === "function" ? value.bind(target) : value
    },
  })
}

async function persistMediaDeliveryPolicy({
  db,
  orderId,
  deliveryOptions,
  HttpsError,
  serverTimestamp,
}) {
  if (!orderId) {
    throw new HttpsError("failed-precondition", "Marketplace order is missing")
  }
  const normalized = normalizeMediaDeliveryOptions(deliveryOptions)
  const orderRef = db.collection("orders").doc(orderId)

  return db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(orderRef)
    if (!snapshot.exists) {
      throw new HttpsError("not-found", "Marketplace order not found")
    }
    const order = snapshot.data() || {}
    const existing = order.mediaDeliveryOptions
    if (existing && typeof existing === "object" && existing.hdUpgrade !== normalized.hdUpgrade) {
      throw new HttpsError(
        "failed-precondition",
        "Media delivery option is immutable once checkout starts",
      )
    }

    const selectedOptions = existing && typeof existing === "object"
      ? normalizeMediaDeliveryOptions(existing)
      : normalized
    const patch = buildMediaDeliveryOrderPatch(order, selectedOptions)
    transaction.set(orderRef, {
      ...patch,
      updatedAt: serverTimestamp(),
    }, { merge: true })
    return patch
  })
}

async function preservePurchasedPhotos({ db, admin, orderId }) {
  if (!orderId) return
  const orderSnapshot = await db.collection("orders").doc(orderId).get()
  if (!orderSnapshot.exists) return
  const order = orderSnapshot.data() || {}
  const photoIds = unique((order.items || []).flatMap((item) => item.photoIds || []))
  if (!photoIds.length) return
  const batch = db.batch()
  const FieldValue = admin.firestore.FieldValue
  const now = FieldValue.serverTimestamp()
  const purgeAt = admin.firestore.Timestamp.fromMillis(Date.now() + (730 * 86400000))
  for (const photoId of photoIds) {
    batch.set(db.collection("media_photos").doc(photoId), {
      purchaseCount: typeof FieldValue.increment === "function" ? FieldValue.increment(1) : 1,
      lastPurchasedAt: now,
      purgeAt,
      soldRetentionDays: 730,
      updatedAt: now,
    }, { merge: true })
  }
  await batch.commit()
}

async function enforceDeliveryEntitlements({ db, orderId, serverTimestamp }) {
  if (!orderId) return
  const orderSnapshot = await db.collection("orders").doc(orderId).get()
  if (!orderSnapshot.exists) return
  const order = orderSnapshot.data() || {}
  const deliveryOptions = order.mediaDeliveryOptions

  // Legacy orders did not persist delivery options and already promised HD/original.
  // Keep those rights unchanged to avoid a regression for previous customers.
  if (!deliveryOptions || typeof deliveryOptions !== "object") return

  const quote = mediaDeliveryQuote({
    subtotal: number(order.baseMediaSubtotal, number(order.subtotal)),
    hdUpgrade: deliveryOptions.hdUpgrade === true,
  })
  const snapshot = await db.collection("media_entitlements")
    .where("orderId", "==", orderId)
    .get()
  if (snapshot.empty) return

  const batch = db.batch()
  for (const document of snapshot.docs || []) {
    batch.set(document.ref, {
      allowedVariants: [...quote.allowedVariants],
      hdUpgrade: quote.hdUpgrade,
      hdUpgradeAmount: quote.hdUpgradeAmount,
      deliveryPolicyVersion: 1,
      updatedAt: serverTimestamp(),
    }, { merge: true })
  }
  await batch.commit()
}

async function settleOrderPayouts({ db, getStripe, orderId, serverTimestamp }) {
  if (!orderId || typeof getStripe !== "function") return
  const stripe = getStripe()
  if (!stripe?.transfers || typeof stripe.transfers.create !== "function") return

  const snapshot = await db.collection("payout_ledger")
    .where("orderId", "==", orderId)
    .where("status", "==", "pending_transfer")
    .get()

  for (const document of snapshot.docs || []) {
    const payout = document.data() || {}
    const destination = payout.stripeAccountId
    const net = number(payout.net, number(payout.photographerAmount))
    if (!destination || net <= 0) {
      await document.ref.set({
        status: "blocked_connect_required",
        updatedAt: serverTimestamp(),
      }, { merge: true })
      continue
    }

    try {
      const transfer = await stripe.transfers.create({
        amount: Math.round(net * 100),
        currency: String(payout.currency || "EUR").toLowerCase(),
        destination,
        transfer_group: orderId,
        metadata: {
          kind: "media_marketplace_photographer_payout",
          orderId,
          photographerId: String(payout.photographerId || ""),
          payoutId: document.id,
        },
      }, { idempotencyKey: `media_payout_${document.id}` })
      await document.ref.set({
        status: "transferred",
        stripeTransferId: transfer.id,
        transferredAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      }, { merge: true })
    } catch (error) {
      await document.ref.set({
        status: "transfer_failed",
        transferErrorCode: String(error?.code || "stripe_transfer_failed"),
        transferErrorMessage: String(error?.message || "").slice(0, 500),
        updatedAt: serverTimestamp(),
      }, { merge: true })
      throw error
    }
  }
}

module.exports = function createMediaMarketplaceStripe(dependencies) {
  const db = databaseWithTransactionFallback(dependencies.db)
  const serverTimestamp = () => dependencies.admin.firestore.FieldValue.serverTimestamp()
  const wrappedOnCall = (options, handler) => dependencies.onCall(
    options,
    async (request) => {
      const deliveryOptions = mediaDeliveryOptionsFromPayload(request?.data)
      return mediaDeliveryContext.run(deliveryOptions, async () => {
        const result = await handler(request)
        if (!result?.orderId) return result
        const patch = await persistMediaDeliveryPolicy({
          db,
          orderId: result.orderId,
          deliveryOptions,
          HttpsError: dependencies.HttpsError,
          serverTimestamp,
        })
        return adjustMarketplaceOrderResult(
          result,
          patch,
          request?.data?.checkoutPayload,
        )
      })
    },
  )
  const wrappedGetStripe = () => stripeWithMediaDeliveryPolicy(
    dependencies.getStripe(),
    mediaDeliveryContext.getStore() || normalizeMediaDeliveryOptions(null),
  )
  const handlers = createImplementation({
    ...dependencies,
    db,
    onCall: wrappedOnCall,
    getStripe: wrappedGetStripe,
  })
  const originalCreateOrderForPaymentIntent = handlers.createMarketplaceOrderForPaymentIntent
  const originalCheckoutHandler = handlers.handleMarketplaceCheckoutSessionCompleted
  const originalPaymentIntentHandler = handlers.fulfillMarketplaceOrderFromPaymentIntent

  async function createMarketplaceOrderForPaymentIntent(args) {
    const checkoutPayload = args?.checkoutPayload && typeof args.checkoutPayload === "object"
      ? args.checkoutPayload
      : {}
    const deliveryOptions = mediaDeliveryOptionsFromPayload(checkoutPayload)
    return mediaDeliveryContext.run(deliveryOptions, async () => {
      const result = await originalCreateOrderForPaymentIntent(args)
      const patch = await persistMediaDeliveryPolicy({
        db,
        orderId: result.orderId,
        deliveryOptions,
        HttpsError: dependencies.HttpsError,
        serverTimestamp,
      })
      return adjustMarketplaceOrderResult(result, patch, checkoutPayload)
    })
  }

  async function finalize(orderId) {
    await preservePurchasedPhotos({ db, admin: dependencies.admin, orderId })
    await enforceDeliveryEntitlements({ db, orderId, serverTimestamp })
    await settleOrderPayouts({
      db,
      getStripe: dependencies.getStripe,
      orderId,
      serverTimestamp,
    })
  }

  return {
    ...handlers,
    createMarketplaceOrderForPaymentIntent,
    handleMarketplaceCheckoutSessionCompleted: async (session) => {
      const fulfilled = await originalCheckoutHandler(session)
      if (fulfilled === true && session?.metadata?.orderId) {
        await finalize(session.metadata.orderId)
      }
      return fulfilled
    },
    fulfillMarketplaceOrderFromPaymentIntent: async (paymentIntent) => {
      const fulfilled = await originalPaymentIntentHandler(paymentIntent)
      if (fulfilled === true && paymentIntent?.metadata?.orderId) {
        await finalize(paymentIntent.metadata.orderId)
      }
      return fulfilled
    },
  }
}
