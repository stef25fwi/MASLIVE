"use strict"

module.exports = function createPhotographerSubscriptionLifecycle({
  admin,
  db,
  onCall,
  HttpsError,
  STRIPE_SECRET_KEY,
  getStripe,
  isAllowedRedirectUrl,
}) {
  const options = {
    region: "us-east1",
    secrets: [STRIPE_SECRET_KEY],
    timeoutSeconds: 30,
  }

  const string = (value) => typeof value === "string" ? value.trim() : ""
  const serverTimestamp = () => admin.firestore.FieldValue.serverTimestamp()

  async function ownedContext(request) {
    const uid = request.auth?.uid
    if (!uid) throw new HttpsError("unauthenticated", "Authentication required")

    const photographerId = string(request.data?.photographerId)
    if (!photographerId) {
      throw new HttpsError("invalid-argument", "photographerId is required")
    }

    const profileRef = db.collection("photographers").doc(photographerId)
    const profileSnapshot = await profileRef.get()
    if (!profileSnapshot.exists) {
      throw new HttpsError("not-found", "Photographer profile not found")
    }
    const profile = profileSnapshot.data() || {}
    if (string(profile.ownerUid) !== uid) {
      throw new HttpsError("permission-denied", "Not allowed")
    }

    const subscriptionId = string(profile.activeSubscriptionId)
    if (!subscriptionId) {
      throw new HttpsError("failed-precondition", "No active photographer subscription")
    }
    const subscriptionRef = db.collection("photographer_subscriptions").doc(subscriptionId)
    const subscriptionSnapshot = await subscriptionRef.get()
    if (!subscriptionSnapshot.exists) {
      throw new HttpsError("not-found", "Subscription record not found")
    }
    const subscription = subscriptionSnapshot.data() || {}
    if (string(subscription.ownerUid) && string(subscription.ownerUid) !== uid) {
      throw new HttpsError("permission-denied", "Not allowed")
    }

    const stripeSubscriptionId = string(subscription.stripeSubscriptionId)
    const stripeCustomerId = string(subscription.stripeCustomerId)
    if (!stripeSubscriptionId) {
      throw new HttpsError("failed-precondition", "Stripe subscription is not configured")
    }

    return {
      uid,
      photographerId,
      profileRef,
      subscriptionRef,
      subscription,
      stripeSubscriptionId,
      stripeCustomerId,
    }
  }

  const createPhotographerBillingPortalLink = onCall(options, async (request) => {
    const context = await ownedContext(request)
    if (!context.stripeCustomerId) {
      throw new HttpsError("failed-precondition", "Stripe customer is not configured")
    }

    const requestedReturnUrl = string(request.data?.returnUrl)
    const returnUrl = requestedReturnUrl && isAllowedRedirectUrl(requestedReturnUrl)
      ? requestedReturnUrl
      : "https://maslive.web.app/#/media-marketplace/subscription"

    const session = await getStripe().billingPortal.sessions.create({
      customer: context.stripeCustomerId,
      return_url: returnUrl,
    })

    return { url: session.url }
  })

  const cancelPhotographerSubscription = onCall(options, async (request) => {
    const context = await ownedContext(request)
    const stripeSubscription = await getStripe().subscriptions.update(
      context.stripeSubscriptionId,
      { cancel_at_period_end: true },
      { idempotencyKey: `photographer_cancel_${context.stripeSubscriptionId}` },
    )

    await context.subscriptionRef.set({
      cancelAtPeriodEnd: true,
      cancellationRequestedAt: serverTimestamp(),
      status: stripeSubscription.status || context.subscription.status || "active",
      updatedAt: serverTimestamp(),
    }, { merge: true })

    return {
      success: true,
      cancelAtPeriodEnd: true,
      currentPeriodEnd: stripeSubscription.current_period_end || null,
    }
  })

  const resumePhotographerSubscription = onCall(options, async (request) => {
    const context = await ownedContext(request)
    const stripeSubscription = await getStripe().subscriptions.update(
      context.stripeSubscriptionId,
      { cancel_at_period_end: false },
      { idempotencyKey: `photographer_resume_${context.stripeSubscriptionId}` },
    )

    await context.subscriptionRef.set({
      cancelAtPeriodEnd: false,
      resumedAt: serverTimestamp(),
      cancellationRequestedAt: null,
      status: stripeSubscription.status || context.subscription.status || "active",
      updatedAt: serverTimestamp(),
    }, { merge: true })

    return {
      success: true,
      cancelAtPeriodEnd: false,
      currentPeriodEnd: stripeSubscription.current_period_end || null,
    }
  })

  return {
    createPhotographerBillingPortalLink,
    cancelPhotographerSubscription,
    resumePhotographerSubscription,
  }
}
