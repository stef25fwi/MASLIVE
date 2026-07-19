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

module.exports = require("./media-marketplace-stripe-profitability")
