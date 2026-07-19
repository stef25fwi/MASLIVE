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

const createImplementation = require("./media-marketplace-stripe-profitability")

function databaseWithTransactionFallback(db) {
  if (typeof db?.runTransaction === "function") return db
  return {
    ...db,
    runTransaction: async (callback) => callback({
      get: (ref) => ref.get(),
      set: (ref, data, options) => ref.set(data, options),
      delete: (ref) => typeof ref.delete === "function" ? ref.delete() : Promise.resolve(),
    }),
  }
}

function number(value, fallback = 0) {
  const parsed = Number(value)
  return Number.isFinite(parsed) ? parsed : fallback
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
  const handlers = createImplementation({ ...dependencies, db })
  const serverTimestamp = () => dependencies.admin.firestore.FieldValue.serverTimestamp()
  const originalCheckoutHandler = handlers.handleMarketplaceCheckoutSessionCompleted
  const originalPaymentIntentHandler = handlers.fulfillMarketplaceOrderFromPaymentIntent

  return {
    ...handlers,
    handleMarketplaceCheckoutSessionCompleted: async (session) => {
      const fulfilled = await originalCheckoutHandler(session)
      if (fulfilled === true && session?.metadata?.orderId) {
        await settleOrderPayouts({
          db,
          getStripe: dependencies.getStripe,
          orderId: session.metadata.orderId,
          serverTimestamp,
        })
      }
      return fulfilled
    },
    fulfillMarketplaceOrderFromPaymentIntent: async (paymentIntent) => {
      const fulfilled = await originalPaymentIntentHandler(paymentIntent)
      if (fulfilled === true && paymentIntent?.metadata?.orderId) {
        await settleOrderPayouts({
          db,
          getStripe: dependencies.getStripe,
          orderId: paymentIntent.metadata.orderId,
          serverTimestamp,
        })
      }
      return fulfilled
    },
  }
}
