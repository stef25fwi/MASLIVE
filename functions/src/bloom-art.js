"use strict";

module.exports = function createBloomArtHandlers(deps) {
  const {
    admin,
    db,
    onCall,
    HttpsError,
    STRIPE_SECRET_KEY,
    getStripe,
    isAllowedRedirectUrl,
    resolveStripeConnectCountry,
  } = deps;

  const REGION = "us-east1";
  const KIND = "bloom_art";
  const AUTO_ACCEPT_PERCENT = 0.90;
  const PLATFORM_FEE_PERCENT = 0.10;
  const PAYMENT_WINDOW_HOURS = 48;
  const ALMA_MIN = 50;
  const ALMA_MAX = 5000;

  const C = {
    items: "bloom_art_items",
    profiles: "bloom_art_seller_profiles",
    offers: "bloom_art_offers",
    orders: "bloom_art_orders",
    events: "bloom_art_payment_events",
  };

  const OFFER = {
    pending: "pending",
    accepted: "accepted",
    autoAccepted: "auto_accepted",
    checkoutStarted: "checkout_started",
    paid: "paid",
    declined: "declined",
    expired: "expired",
    cancelled: "cancelled",
  };

  const ITEM = { draft: "draft", published: "published", reserved: "reserved", sold: "sold" };
  const ORDER = { draft: "draft", checkoutStarted: "checkout_started", paid: "paid", failed: "failed", cancelled: "cancelled", expired: "expired" };

  const now = () => admin.firestore.FieldValue.serverTimestamp();
  const clean = (v, fallback = "") => typeof v === "string" && v.trim() ? v.trim() : fallback;
  const number = (v, fallback = 0) => Number.isFinite(Number(v)) ? Number(v) : fallback;
  const cents = (v) => Math.max(0, Math.round(number(v) * 100));
  const timestampAfterHours = (hours) => admin.firestore.Timestamp.fromMillis(Date.now() + hours * 3600000);

  function authUid(request) {
    if (!request.auth) throw new HttpsError("unauthenticated", "Authentication required");
    return request.auth.uid;
  }

  function paymentMethods(amount, currency) {
    const result = ["card"];
    if (String(currency || "EUR").toUpperCase() === "EUR" && amount >= ALMA_MIN && amount <= ALMA_MAX) result.push("alma");
    return result;
  }

  function assertSeller(uid, offer) {
    if (offer.sellerId !== uid) throw new HttpsError("permission-denied", "Only the seller can perform this action");
  }

  function assertBuyer(uid, offer) {
    if (offer.buyerId !== uid) throw new HttpsError("permission-denied", "Only the buyer can perform this action");
  }

  function payable(profile) {
    const stripe = profile?.stripe || {};
    return !!stripe.accountId && stripe.detailsSubmitted === true && stripe.chargesEnabled === true && stripe.payoutsEnabled === true;
  }

  async function notify(uid, payload) {
    if (!uid) return;
    try {
      await db.collection("users").doc(uid).collection("inbox").add({
        type: payload.type || "bloom_art_offer",
        title: payload.title,
        body: payload.body,
        itemId: payload.itemId || null,
        offerId: payload.offerId || null,
        orderId: payload.orderId || null,
        actionLabel: payload.actionLabel || "Voir",
        read: false,
        createdAt: now(),
      });
    } catch (error) {
      console.error("[BloomArt] inbox notification failed", error);
    }
  }

  async function releaseReservation({ offerId, reason, expectedStatuses }) {
    const offerRef = db.collection(C.offers).doc(offerId);
    await db.runTransaction(async (tx) => {
      const offerSnap = await tx.get(offerRef);
      if (!offerSnap.exists) return;
      const offer = offerSnap.data() || {};
      if (!expectedStatuses.includes(offer.status)) return;
      const itemRef = db.collection(C.items).doc(offer.itemId);
      const itemSnap = await tx.get(itemRef);
      const item = itemSnap.exists ? itemSnap.data() || {} : {};
      tx.update(offerRef, {
        status: reason === "expired" ? OFFER.expired : OFFER.cancelled,
        checkoutEligible: false,
        closedAt: now(),
        closeReason: reason,
        updatedAt: now(),
      });
      if (itemSnap.exists && item.availabilityStatus === ITEM.reserved && item.reservedByOfferId === offerId) {
        tx.update(itemRef, {
          availabilityStatus: ITEM.published,
          reservedByOfferId: admin.firestore.FieldValue.delete(),
          reservedUntil: admin.firestore.FieldValue.delete(),
          updatedAt: now(),
        });
      }
    });
  }

  async function getVerifiedSellerProfile(uid) {
    const snap = await db.collection(C.profiles).doc(uid).get();
    if (!snap.exists) throw new HttpsError("failed-precondition", "Bloom Art seller profile is required");
    const profile = snap.data() || {};
    if (!["artisan_art", "artist_creator"].includes(clean(profile.profileType))) {
      throw new HttpsError("failed-precondition", "Only Artisan d'art profiles can sell Bloom Art items");
    }
    if (profile.sellerStatus !== "active" || profile.businessVerificationStatus !== "verified" || !/^\d{14}$/.test(clean(profile.siret))) {
      throw new HttpsError("failed-precondition", "Verified SIRET required");
    }
    return profile;
  }

  const verifyBloomArtSiret = onCall({ region: REGION }, async (request) => {
    const uid = authUid(request);
    const siret = clean(request.data?.siret).replace(/\s/g, "");
    if (!/^\d{14}$/.test(siret)) throw new HttpsError("invalid-argument", "A valid 14 digit SIRET is required");
    let sum = 0;
    let doubleDigit = false;
    for (let i = siret.length - 1; i >= 0; i -= 1) {
      let digit = Number(siret[i]);
      if (doubleDigit) { digit *= 2; if (digit > 9) digit -= 9; }
      sum += digit;
      doubleDigit = !doubleDigit;
    }
    if (sum % 10 !== 0) throw new HttpsError("invalid-argument", "Invalid SIRET checksum");
    await db.collection(C.profiles).doc(uid).set({
      userId: uid,
      siret,
      siren: siret.slice(0, 9),
      sellerStatus: "active",
      businessVerificationStatus: "verified",
      businessVerificationSource: "server_luhn",
      businessVerifiedAt: now(),
      updatedAt: now(),
    }, { merge: true });
    return { verified: true, siret };
  });

  const createBloomArtConnectOnboardingLink = onCall({ region: REGION, secrets: [STRIPE_SECRET_KEY] }, async (request) => {
    const uid = authUid(request);
    const profile = await getVerifiedSellerProfile(uid);
    const stripe = getStripe();
    let accountId = profile?.stripe?.accountId;
    if (!accountId) {
      const account = await stripe.accounts.create({
        type: "express",
        country: resolveStripeConnectCountry ? resolveStripeConnectCountry(profile.country || "FR") : "FR",
        email: request.auth.token.email || undefined,
        capabilities: { card_payments: { requested: true }, transfers: { requested: true } },
        metadata: { kind: "bloom_art_seller", uid },
      }, { idempotencyKey: `bloom_art_connect_${uid}` });
      accountId = account.id;
      await db.collection(C.profiles).doc(uid).set({ stripe: { accountId, detailsSubmitted: false, chargesEnabled: false, payoutsEnabled: false }, payoutStatus: "pending", updatedAt: now() }, { merge: true });
    }
    const refreshUrl = clean(request.data?.refreshUrl, "https://maslive.web.app/#/bloom-art/dashboard");
    const returnUrl = clean(request.data?.returnUrl, "https://maslive.web.app/#/bloom-art/dashboard");
    if (!isAllowedRedirectUrl(refreshUrl) || !isAllowedRedirectUrl(returnUrl)) throw new HttpsError("invalid-argument", "Invalid redirect URL domain");
    const link = await stripe.accountLinks.create({ account: accountId, refresh_url: refreshUrl, return_url: returnUrl, type: "account_onboarding" });
    return { url: link.url, accountId };
  });

  const refreshBloomArtConnectStatus = onCall({ region: REGION, secrets: [STRIPE_SECRET_KEY] }, async (request) => {
    const uid = authUid(request);
    const ref = db.collection(C.profiles).doc(uid);
    const snap = await ref.get();
    const accountId = snap.data()?.stripe?.accountId;
    if (!accountId) throw new HttpsError("failed-precondition", "Stripe account not found");
    const account = await getStripe().accounts.retrieve(accountId);
    const stripeState = {
      accountId,
      detailsSubmitted: !!account.details_submitted,
      chargesEnabled: !!account.charges_enabled,
      payoutsEnabled: !!account.payouts_enabled,
      currentlyDue: account.requirements?.currently_due || [],
      pastDue: account.requirements?.past_due || [],
      updatedAt: now(),
    };
    await ref.set({ stripe: stripeState, payoutStatus: stripeState.payoutsEnabled ? "active" : "pending", updatedAt: now() }, { merge: true });
    return stripeState;
  });

  const createBloomArtItem = onCall({ region: REGION, secrets: [STRIPE_SECRET_KEY] }, async (request) => {
    const uid = authUid(request);
    const profile = await getVerifiedSellerProfile(uid);
    if (!payable(profile)) throw new HttpsError("failed-precondition", "Complete Stripe Connect before publishing an artwork");
    const data = request.data || {};
    const title = clean(data.title);
    const referencePrice = number(data.referencePrice);
    if (!title || referencePrice <= 0) throw new HttpsError("invalid-argument", "Title and positive reference price are required");
    const ref = db.collection(C.items).doc();
    const batch = db.batch();
    batch.set(ref, {
      sellerId: uid,
      sellerProfileType: "artisan_art",
      sellerDisplayName: clean(data.sellerDisplayName, clean(profile.artistName, "Artisan d'art")),
      sellerSiretVerified: true,
      title,
      description: clean(data.description),
      category: clean(data.category, "Artisanat d’art"),
      condition: clean(data.condition, "good"),
      materials: Array.isArray(data.materials) ? data.materials.map(String).slice(0, 20) : [],
      dimensions: clean(data.dimensions),
      images: Array.isArray(data.images) ? data.images.filter((v) => typeof v === "string" && v.trim()).slice(0, 10) : [],
      currency: clean(data.currency, "EUR").toUpperCase(),
      availabilityStatus: ITEM.draft,
      isPublished: false,
      deliveryMode: clean(data.deliveryMode, "delivery_or_pickup"),
      deliveryNotes: clean(data.deliveryNotes),
      createdAt: now(), updatedAt: now(),
    });
    batch.set(ref.collection("private").doc("pricing"), { referencePrice, currency: clean(data.currency, "EUR").toUpperCase(), updatedAt: now() });
    await batch.commit();
    return { itemId: ref.id };
  });

  const submitBloomArtOffer = onCall({ region: REGION, secrets: [STRIPE_SECRET_KEY] }, async (request) => {
    const uid = authUid(request);
    const itemId = clean(request.data?.itemId);
    const proposedPrice = number(request.data?.proposedPrice);
    const buyerMessage = clean(request.data?.buyerMessage).slice(0, 500);
    if (!itemId || proposedPrice <= 0) throw new HttpsError("invalid-argument", "Item and positive price are required");
    const itemRef = db.collection(C.items).doc(itemId);
    const pricingRef = itemRef.collection("private").doc("pricing");
    const offerRef = db.collection(C.offers).doc();
    const result = await db.runTransaction(async (tx) => {
      const [itemSnap, pricingSnap] = await Promise.all([tx.get(itemRef), tx.get(pricingRef)]);
      if (!itemSnap.exists || !pricingSnap.exists) throw new HttpsError("not-found", "Artwork not found");
      const item = itemSnap.data() || {};
      if (item.availabilityStatus !== ITEM.published || item.isPublished !== true) throw new HttpsError("failed-precondition", "Artwork is not available");
      if (item.sellerId === uid) throw new HttpsError("failed-precondition", "Cannot bid on your own artwork");
      const active = await tx.get(db.collection(C.offers).where("itemId", "==", itemId).where("buyerId", "==", uid).where("status", "in", [OFFER.pending, OFFER.accepted, OFFER.autoAccepted, OFFER.checkoutStarted]).limit(1));
      if (!active.empty) throw new HttpsError("already-exists", "You already have an active offer on this artwork");
      const referencePrice = number(pricingSnap.data()?.referencePrice);
      const autoAccepted = referencePrice > 0 && proposedPrice >= referencePrice * AUTO_ACCEPT_PERCENT;
      const deadline = autoAccepted ? timestampAfterHours(PAYMENT_WINDOW_HOURS) : null;
      tx.set(offerRef, {
        itemId, buyerId: uid, sellerId: item.sellerId,
        proposedPrice, buyerMessage,
        autoAccepted,
        status: autoAccepted ? OFFER.autoAccepted : OFFER.pending,
        checkoutEligible: autoAccepted,
        paymentDeadlineAt: deadline,
        createdAt: now(), respondedAt: autoAccepted ? now() : null,
        acceptedAt: autoAccepted ? now() : null,
        declinedAt: null, paidAt: null, updatedAt: now(),
      });
      if (autoAccepted) {
        tx.update(itemRef, { availabilityStatus: ITEM.reserved, reservedByOfferId: offerRef.id, reservedUntil: deadline, updatedAt: now() });
      }
      return { autoAccepted, sellerId: item.sellerId, title: item.title || "Création", deadline };
    });
    await notify(result.sellerId, { title: result.autoAccepted ? "Offre auto-acceptée" : "Nouvelle offre", body: `${proposedPrice.toFixed(2)} EUR pour ${result.title}`, itemId, offerId: offerRef.id, actionLabel: "Voir l'offre" });
    return { offerId: offerRef.id, status: result.autoAccepted ? OFFER.autoAccepted : OFFER.pending, checkoutEligible: result.autoAccepted, paymentDeadlineAt: result.deadline?.toMillis?.() || null };
  });

  const acceptBloomArtOffer = onCall({ region: REGION, secrets: [STRIPE_SECRET_KEY] }, async (request) => {
    const uid = authUid(request);
    const offerId = clean(request.data?.offerId);
    const offerRef = db.collection(C.offers).doc(offerId);
    const result = await db.runTransaction(async (tx) => {
      const offerSnap = await tx.get(offerRef);
      if (!offerSnap.exists) throw new HttpsError("not-found", "Offer not found");
      const offer = offerSnap.data() || {};
      assertSeller(uid, offer);
      if (offer.status !== OFFER.pending) throw new HttpsError("failed-precondition", `Cannot accept ${offer.status}`);
      const itemRef = db.collection(C.items).doc(offer.itemId);
      const itemSnap = await tx.get(itemRef);
      if (!itemSnap.exists) throw new HttpsError("not-found", "Artwork not found");
      const item = itemSnap.data() || {};
      if (item.availabilityStatus !== ITEM.published) throw new HttpsError("failed-precondition", "Artwork is no longer available");
      const deadline = timestampAfterHours(PAYMENT_WINDOW_HOURS);
      tx.update(offerRef, { status: OFFER.accepted, checkoutEligible: true, respondedAt: now(), acceptedAt: now(), paymentDeadlineAt: deadline, updatedAt: now() });
      tx.update(itemRef, { availabilityStatus: ITEM.reserved, reservedByOfferId: offerId, reservedUntil: deadline, updatedAt: now() });
      return { buyerId: offer.buyerId, itemId: offer.itemId, deadline };
    });
    await notify(result.buyerId, { title: "Offre acceptée", body: `Vous disposez de ${PAYMENT_WINDOW_HOURS} h pour payer.`, itemId: result.itemId, offerId, actionLabel: "Payer" });
    return { success: true, paymentDeadlineAt: result.deadline.toMillis() };
  });

  const declineBloomArtOffer = onCall({ region: REGION }, async (request) => {
    const uid = authUid(request);
    const offerId = clean(request.data?.offerId);
    const ref = db.collection(C.offers).doc(offerId);
    const snap = await ref.get();
    if (!snap.exists) throw new HttpsError("not-found", "Offer not found");
    const offer = snap.data() || {};
    assertSeller(uid, offer);
    if (offer.status !== OFFER.pending) throw new HttpsError("failed-precondition", `Cannot decline ${offer.status}`);
    await ref.update({ status: OFFER.declined, checkoutEligible: false, respondedAt: now(), declinedAt: now(), updatedAt: now() });
    await notify(offer.buyerId, { title: "Offre refusée", body: "Le vendeur n'a pas retenu cette proposition.", itemId: offer.itemId, offerId });
    return { success: true };
  });

  const createBloomArtCheckout = onCall({ region: REGION, secrets: [STRIPE_SECRET_KEY] }, async (request) => {
    const uid = authUid(request);
    const offerId = clean(request.data?.offerId);
    const successUrl = clean(request.data?.successUrl);
    const cancelUrl = clean(request.data?.cancelUrl);
    if (!offerId || !successUrl || !cancelUrl || !isAllowedRedirectUrl(successUrl) || !isAllowedRedirectUrl(cancelUrl)) throw new HttpsError("invalid-argument", "Valid offer and redirect URLs required");
    const offerRef = db.collection(C.offers).doc(offerId);
    const orderRef = db.collection(C.orders).doc(offerId);
    const prepared = await db.runTransaction(async (tx) => {
      const offerSnap = await tx.get(offerRef);
      if (!offerSnap.exists) throw new HttpsError("not-found", "Offer not found");
      const offer = offerSnap.data() || {};
      assertBuyer(uid, offer);
      if (![OFFER.accepted, OFFER.autoAccepted].includes(offer.status) || offer.checkoutEligible !== true) throw new HttpsError("failed-precondition", "Offer is not payable");
      if (offer.paymentDeadlineAt?.toMillis?.() <= Date.now()) throw new HttpsError("deadline-exceeded", "Payment deadline expired");
      const itemRef = db.collection(C.items).doc(offer.itemId);
      const itemSnap = await tx.get(itemRef);
      const item = itemSnap.data() || {};
      if (item.availabilityStatus !== ITEM.reserved || item.reservedByOfferId !== offerId) throw new HttpsError("failed-precondition", "Artwork is not reserved for this offer");
      const profileSnap = await tx.get(db.collection(C.profiles).doc(offer.sellerId));
      if (!profileSnap.exists || !payable(profileSnap.data())) throw new HttpsError("failed-precondition", "Seller payout account is not ready");
      const existing = await tx.get(orderRef);
      if (existing.exists && existing.data()?.paymentStatus === "paid") throw new HttpsError("already-exists", "Order already paid");
      const fee = Math.round(offer.proposedPrice * PLATFORM_FEE_PERCENT * 100) / 100;
      const payload = existing.exists ? existing.data() : {
        itemId: offer.itemId, offerId, sellerId: offer.sellerId, buyerId: uid,
        finalPrice: offer.proposedPrice, platformFee: fee, netAmount: Math.max(0, offer.proposedPrice - fee), feePercent: PLATFORM_FEE_PERCENT,
        currency: item.currency || "EUR", paymentStatus: "pending", orderStatus: ORDER.draft,
        itemTitle: item.title || "Bloom Art", payoutStatus: "pending", createdAt: now(),
      };
      tx.set(orderRef, { ...payload, updatedAt: now() }, { merge: true });
      return { offer, item, payload };
    });
    const stripe = getStripe();
    let session;
    try {
      session = await stripe.checkout.sessions.create({
        mode: "payment",
        payment_method_types: paymentMethods(prepared.offer.proposedPrice, prepared.item.currency),
        line_items: [{ price_data: { currency: String(prepared.item.currency || "EUR").toLowerCase(), product_data: { name: prepared.item.title || "Bloom Art" }, unit_amount: cents(prepared.offer.proposedPrice) }, quantity: 1 }],
        client_reference_id: offerId,
        success_url: `${successUrl}${successUrl.includes("?") ? "&" : "?"}orderId=${offerId}`,
        cancel_url: `${cancelUrl}${cancelUrl.includes("?") ? "&" : "?"}orderId=${offerId}`,
        customer_email: request.auth.token.email || undefined,
        metadata: { kind: KIND, orderId: offerId, offerId, itemId: prepared.offer.itemId, buyerId: uid, sellerId: prepared.offer.sellerId },
        payment_intent_data: { transfer_group: `bloom_art_order_${offerId}`, metadata: { kind: KIND, orderId: offerId, offerId, itemId: prepared.offer.itemId } },
        expires_at: Math.floor(Math.min(prepared.offer.paymentDeadlineAt.toMillis(), Date.now() + 24 * 3600000) / 1000),
      }, { idempotencyKey: `bloom_art_checkout_${uid}_${offerId}` });
      await db.runTransaction(async (tx) => {
        tx.set(orderRef, { stripeCheckoutSessionId: session.id, orderStatus: ORDER.checkoutStarted, updatedAt: now() }, { merge: true });
        tx.update(offerRef, { status: OFFER.checkoutStarted, updatedAt: now() });
      });
    } catch (error) {
      await orderRef.set({ orderStatus: ORDER.failed, failureReason: clean(error?.code, "checkout_error"), updatedAt: now() }, { merge: true });
      await releaseReservation({ offerId, reason: "checkout_failed", expectedStatuses: [OFFER.accepted, OFFER.autoAccepted, OFFER.checkoutStarted] });
      throw error;
    }
    return { orderId: offerId, checkoutUrl: session.url, stripeSessionId: session.id };
  });

  async function settlePayout(orderId) {
    const ref = db.collection(C.orders).doc(orderId);
    const snap = await ref.get();
    if (!snap.exists) return;
    const order = snap.data() || {};
    if (order.payoutStatus === "paid") return;
    const profile = (await db.collection(C.profiles).doc(order.sellerId).get()).data() || {};
    if (!payable(profile)) {
      await ref.set({ payoutStatus: "pending_account", updatedAt: now() }, { merge: true });
      return;
    }
    try {
      const transfer = await getStripe().transfers.create({ amount: cents(order.netAmount), currency: String(order.currency || "EUR").toLowerCase(), destination: profile.stripe.accountId, transfer_group: `bloom_art_order_${orderId}`, metadata: { orderId, sellerId: order.sellerId } }, { idempotencyKey: `bloom_art_payout_${orderId}` });
      await ref.set({ payoutStatus: "paid", transferId: transfer.id, paidOutAt: now(), updatedAt: now() }, { merge: true });
    } catch (error) {
      await ref.set({ payoutStatus: "failed", payoutFailureReason: clean(error?.code, "transfer_error"), updatedAt: now() }, { merge: true });
    }
  }

  async function handleBloomArtCheckoutCompleted(session) {
    if (clean(session?.metadata?.kind).toLowerCase() !== KIND) return false;
    const orderId = clean(session.metadata?.orderId);
    const offerId = clean(session.metadata?.offerId, orderId);
    const itemId = clean(session.metadata?.itemId);
    if (!orderId) return true;
    if (session.payment_status !== "paid") return true;
    const eventKey = clean(session.id, orderId);
    const eventRef = db.collection(C.events).doc(`checkout_${eventKey}`);
    const newlyPaid = await db.runTransaction(async (tx) => {
      if ((await tx.get(eventRef)).exists) return false;
      const orderRef = db.collection(C.orders).doc(orderId);
      const orderSnap = await tx.get(orderRef);
      if (!orderSnap.exists) throw new Error(`Bloom Art order ${orderId} missing`);
      const order = orderSnap.data() || {};
      if (order.paymentStatus === "paid") { tx.set(eventRef, { processedAt: now() }); return false; }
      tx.update(orderRef, { paymentStatus: "paid", orderStatus: ORDER.paid, stripeCheckoutSessionId: session.id, stripePaymentIntentId: session.payment_intent || null, paidAt: now(), updatedAt: now() });
      tx.update(db.collection(C.offers).doc(offerId), { status: OFFER.paid, paidAt: now(), checkoutEligible: false, updatedAt: now() });
      const itemRef = db.collection(C.items).doc(itemId || order.itemId);
      const itemSnap = await tx.get(itemRef);
      const item = itemSnap.data() || {};
      if (item.reservedByOfferId !== offerId) throw new Error("Reservation ownership mismatch");
      tx.update(itemRef, { availabilityStatus: ITEM.sold, soldAt: now(), updatedAt: now() });
      tx.set(eventRef, { processedAt: now(), orderId, offerId, itemId: itemId || order.itemId });
      return true;
    });
    // settlePayout est idempotent (garde payoutStatus === "paid") : on le retente a
    // chaque webhook pour recuperer un eventuel echec de transfert precedent, mais
    // les notifications ne doivent partir qu'une seule fois (Stripe envoie a la fois
    // checkout.session.completed et payment_intent.succeeded pour le meme paiement).
    await settlePayout(orderId);
    if (newlyPaid) {
      const order = (await db.collection(C.orders).doc(orderId).get()).data() || {};
      await Promise.all([
        notify(order.buyerId, { type: "bloom_art_order", title: "Paiement confirmé", body: "Votre œuvre est réservée définitivement.", itemId: order.itemId, offerId, orderId }),
        notify(order.sellerId, { type: "bloom_art_order", title: "Œuvre vendue", body: "Le paiement de l'acheteur est confirmé.", itemId: order.itemId, offerId, orderId }),
      ]);
    }
    return true;
  }

  async function handleBloomArtPaymentIntentSucceeded(paymentIntent) {
    if (clean(paymentIntent?.metadata?.kind).toLowerCase() !== KIND) return false;
    return handleBloomArtCheckoutCompleted({ id: paymentIntent.id, payment_status: "paid", payment_intent: paymentIntent.id, metadata: paymentIntent.metadata || {} });
  }

  return {
    createBloomArtItem,
    submitBloomArtOffer,
    acceptBloomArtOffer,
    declineBloomArtOffer,
    createBloomArtCheckout,
    createBloomArtConnectOnboardingLink,
    refreshBloomArtConnectStatus,
    verifyBloomArtSiret,
    handleBloomArtCheckoutCompleted,
    handleBloomArtPaymentIntentSucceeded,
  };
};
