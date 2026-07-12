/**
 * Bloom Art — Galerie d'art avec système d'offres de prix
 *
 * Collections Firestore :
 *   bloom_art_items              — articles en vente
 *   bloom_art_items/{id}/private — données privées (referencePrice) – lecture serveur uniquement
 *   bloom_art_seller_profiles    — profils vendeur
 *   bloom_art_offers             — offres de prix des visiteurs
 *   bloom_art_orders             — commandes après acceptation d'offre
 */

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
  } = deps;

  const BLOOM_ART_KIND = "bloom_art";
  const AUTO_ACCEPT_THRESHOLD_PERCENT = 0.90;

  const COLLECTIONS = {
    items: "bloom_art_items",
    sellerProfiles: "bloom_art_seller_profiles",
    offers: "bloom_art_offers",
    orders: "bloom_art_orders",
  };

  const OFFER_STATUS = {
    pending: "pending",
    accepted: "accepted",
    declined: "declined",
    autoAccepted: "auto_accepted",
    checkoutStarted: "checkout_started",
    paid: "paid",
  };

  const ORDER_STATUS = {
    draft: "draft",
    checkoutStarted: "checkout_started",
    paid: "paid",
    failed: "failed",
    cancelled: "cancelled",
  };

  const ITEM_STATUS = {
    draft: "draft",
    published: "published",
    reserved: "reserved",
    sold: "sold",
  };

  function serverTimestamp() {
    return admin.firestore.FieldValue.serverTimestamp();
  }

  function looksLikeNonEmptyString(v) {
    return typeof v === "string" && v.trim().length > 0;
  }

  function cleanString(value, fallback = "") {
    return looksLikeNonEmptyString(value) ? value.trim() : fallback;
  }

  function toNumber(value, fallback = 0) {
    const parsed = Number(value);
    return Number.isFinite(parsed) ? parsed : fallback;
  }

  function amountToCents(amount) {
    return Math.max(0, Math.round(toNumber(amount, 0) * 100));
  }

  function normalizeProfileType(profileType) {
    return profileType === "artist_creator" ? "artisan_art" : profileType;
  }

  function normalizeMaterials(value) {
    if (Array.isArray(value)) {
      return value
        .map((entry) => String(entry || "").trim())
        .filter((entry) => entry.length > 0)
        .slice(0, 20);
    }
    if (looksLikeNonEmptyString(value)) {
      return value
        .split(",")
        .map((entry) => entry.trim())
        .filter((entry) => entry.length > 0)
        .slice(0, 20);
    }
    return [];
  }

  function computeAutoAcceptMin(referencePrice) {
    return referencePrice * AUTO_ACCEPT_THRESHOLD_PERCENT;
  }

  function shouldAutoAccept(proposedPrice, referencePrice) {
    if (referencePrice <= 0) return false;
    return proposedPrice >= computeAutoAcceptMin(referencePrice);
  }

  function assertAuthenticated(request) {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Authentication required");
    }
    return request.auth.uid;
  }

  function assertSellerOwnsOffer(uid, offer) {
    if (offer.sellerId !== uid) {
      throw new HttpsError("permission-denied", "Only the seller can perform this action");
    }
  }

  function assertBuyerOwnsOffer(uid, offer) {
    if (offer.buyerId !== uid) {
      throw new HttpsError("permission-denied", "Only the buyer can perform this action");
    }
  }

  async function getVerifiedSellerProfile(uid) {
    const profileSnap = await db.collection(COLLECTIONS.sellerProfiles).doc(uid).get();
    if (!profileSnap.exists) {
      throw new HttpsError(
        "failed-precondition",
        "Bloom Art seller profile is required before creating an item"
      );
    }

    const profile = profileSnap.data() || {};
    const profileType = normalizeProfileType(cleanString(profile.profileType));
    const siret = cleanString(profile.siret);
    const sellerStatus = cleanString(profile.sellerStatus, "pending");
    const verificationStatus = cleanString(profile.businessVerificationStatus, "not_verified");

    if (profileType !== "artisan_art") {
      throw new HttpsError(
        "failed-precondition",
        "Only declared Artisan d'art sellers can create Bloom Art items"
      );
    }

    if (sellerStatus !== "active" || verificationStatus !== "verified") {
      throw new HttpsError(
        "failed-precondition",
        "SIRET verification is required before creating Bloom Art items"
      );
    }

    if (!/^\d{14}$/.test(siret)) {
      throw new HttpsError(
        "failed-precondition",
        "A valid 14-digit SIRET is required before creating Bloom Art items"
      );
    }

    return {
      ...profile,
      profileType,
      siret,
      sellerStatus,
      businessVerificationStatus: verificationStatus,
    };
  }

  const createBloomArtItem = onCall(
    { region: "us-east1", secrets: [STRIPE_SECRET_KEY] },
    async (request) => {
      const uid = assertAuthenticated(request);
      const data = request.data || {};
      const sellerProfile = await getVerifiedSellerProfile(uid);

      const title = cleanString(data.title);
      if (!title) {
        throw new HttpsError("invalid-argument", "Title is required");
      }

      const referencePrice = toNumber(data.referencePrice, 0);
      if (referencePrice <= 0) {
        throw new HttpsError("invalid-argument", "referencePrice must be > 0");
      }

      const currency = cleanString(data.currency, "EUR").toUpperCase();
      const itemRef = db.collection(COLLECTIONS.items).doc();
      const privateRef = itemRef.collection("private").doc("pricing");
      const sellerDisplayName = cleanString(
        data.sellerDisplayName,
        cleanString(sellerProfile.artistName, cleanString(sellerProfile.fullName, "Artisan d'art"))
      );

      const itemPayload = {
        sellerId: uid,
        sellerProfileType: "artisan_art",
        sellerDisplayName,
        sellerSiretVerified: true,
        sellerSiret: sellerProfile.siret,
        sellerBusinessName: cleanString(sellerProfile.businessName),
        sellerRegion: cleanString(sellerProfile.region),
        title,
        description: cleanString(data.description),
        category: cleanString(data.category, "Artisanat d’art"),
        condition: cleanString(data.condition, "good"),
        materials: normalizeMaterials(data.materials),
        dimensions: cleanString(data.dimensions),
        images: Array.isArray(data.images)
          ? data.images.filter((u) => looksLikeNonEmptyString(u)).slice(0, 10)
          : [],
        currency,
        availabilityStatus: ITEM_STATUS.draft,
        isPublished: false,
        deliveryMode: cleanString(data.deliveryMode, "delivery_or_pickup"),
        deliveryNotes: cleanString(data.deliveryNotes),
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      };

      const batch = db.batch();
      batch.set(itemRef, itemPayload);
      batch.set(privateRef, {
        referencePrice,
        currency,
        sellerSiret: sellerProfile.siret,
        updatedAt: serverTimestamp(),
      });
      await batch.commit();

      return { itemId: itemRef.id };
    }
  );

  const submitBloomArtOffer = onCall(
    { region: "us-east1", secrets: [STRIPE_SECRET_KEY] },
    async (request) => {
      const uid = assertAuthenticated(request);
      const data = request.data || {};

      const itemId = cleanString(data.itemId);
      if (!itemId) {
        throw new HttpsError("invalid-argument", "itemId is required");
      }

      const proposedPrice = toNumber(data.proposedPrice, 0);
      if (proposedPrice <= 0) {
        throw new HttpsError("invalid-argument", "proposedPrice must be > 0");
      }

      const buyerMessage = cleanString(data.buyerMessage).slice(0, 500);
      const itemRef = db.collection(COLLECTIONS.items).doc(itemId);
      const privateRef = itemRef.collection("private").doc("pricing");
      const [itemSnap, privateSnap] = await Promise.all([itemRef.get(), privateRef.get()]);

      if (!itemSnap.exists) {
        throw new HttpsError("not-found", "Item not found");
      }

      const item = itemSnap.data();
      if (item.availabilityStatus !== ITEM_STATUS.published) {
        throw new HttpsError("failed-precondition", "Item is not available");
      }

      if (item.sellerId === uid) {
        throw new HttpsError("failed-precondition", "Cannot bid on your own item");
      }

      if (!privateSnap.exists) {
        throw new HttpsError("internal", "Item pricing data missing");
      }

      const referencePrice = toNumber(privateSnap.data().referencePrice, 0);
      if (referencePrice <= 0) {
        throw new HttpsError("internal", "Invalid reference price");
      }

      const existingOffersSnap = await db
        .collection(COLLECTIONS.offers)
        .where("itemId", "==", itemId)
        .where("buyerId", "==", uid)
        .where("status", "in", [
          OFFER_STATUS.pending,
          OFFER_STATUS.accepted,
          OFFER_STATUS.autoAccepted,
          OFFER_STATUS.checkoutStarted,
        ])
        .limit(1)
        .get();

      if (!existingOffersSnap.empty) {
        throw new HttpsError("already-exists", "You already have an active offer on this item");
      }

      const autoAccepted = shouldAutoAccept(proposedPrice, referencePrice);
      const offerRef = db.collection(COLLECTIONS.offers).doc();
      const offerPayload = {
        itemId,
        buyerId: uid,
        sellerId: item.sellerId,
        proposedPrice,
        buyerMessage,
        referencePriceSnapshot: referencePrice,
        autoAcceptThresholdPercent: AUTO_ACCEPT_THRESHOLD_PERCENT,
        autoAccepted,
        status: autoAccepted ? OFFER_STATUS.autoAccepted : OFFER_STATUS.pending,
        checkoutEligible: autoAccepted,
        createdAt: serverTimestamp(),
        respondedAt: autoAccepted ? serverTimestamp() : null,
        acceptedAt: autoAccepted ? serverTimestamp() : null,
        declinedAt: null,
        paidAt: null,
      };

      await offerRef.set(offerPayload);
      if (autoAccepted) {
        await itemRef.update({ availabilityStatus: ITEM_STATUS.reserved, updatedAt: serverTimestamp() });
      }

      return {
        offerId: offerRef.id,
        status: offerPayload.status,
        checkoutEligible: offerPayload.checkoutEligible,
      };
    }
  );

  const acceptBloomArtOffer = onCall(
    { region: "us-east1", secrets: [STRIPE_SECRET_KEY] },
    async (request) => {
      const uid = assertAuthenticated(request);
      const offerId = cleanString((request.data || {}).offerId);
      if (!offerId) throw new HttpsError("invalid-argument", "offerId is required");

      const offerRef = db.collection(COLLECTIONS.offers).doc(offerId);
      await db.runTransaction(async (transaction) => {
        const offerSnap = await transaction.get(offerRef);
        if (!offerSnap.exists) throw new HttpsError("not-found", "Offer not found");

        const offer = offerSnap.data();
        assertSellerOwnsOffer(uid, offer);
        if (offer.status !== OFFER_STATUS.pending) {
          throw new HttpsError("failed-precondition", `Cannot accept offer with status: ${offer.status}`);
        }

        const otherAcceptedSnap = await transaction.get(
          db
            .collection(COLLECTIONS.offers)
            .where("itemId", "==", offer.itemId)
            .where("status", "in", [
              OFFER_STATUS.accepted,
              OFFER_STATUS.autoAccepted,
              OFFER_STATUS.checkoutStarted,
              OFFER_STATUS.paid,
            ])
            .limit(1)
        );

        if (!otherAcceptedSnap.empty) {
          throw new HttpsError("failed-precondition", "Another offer is already accepted for this item");
        }

        transaction.update(offerRef, {
          status: OFFER_STATUS.accepted,
          checkoutEligible: true,
          respondedAt: serverTimestamp(),
          acceptedAt: serverTimestamp(),
        });
        transaction.update(db.collection(COLLECTIONS.items).doc(offer.itemId), {
          availabilityStatus: ITEM_STATUS.reserved,
          updatedAt: serverTimestamp(),
        });
      });

      return { success: true };
    }
  );

  const declineBloomArtOffer = onCall(
    { region: "us-east1", secrets: [STRIPE_SECRET_KEY] },
    async (request) => {
      const uid = assertAuthenticated(request);
      const offerId = cleanString((request.data || {}).offerId);
      if (!offerId) throw new HttpsError("invalid-argument", "offerId is required");

      const offerRef = db.collection(COLLECTIONS.offers).doc(offerId);
      const offerSnap = await offerRef.get();
      if (!offerSnap.exists) throw new HttpsError("not-found", "Offer not found");

      const offer = offerSnap.data();
      assertSellerOwnsOffer(uid, offer);
      if (offer.status !== OFFER_STATUS.pending) {
        throw new HttpsError("failed-precondition", `Cannot decline offer with status: ${offer.status}`);
      }

      await offerRef.update({
        status: OFFER_STATUS.declined,
        checkoutEligible: false,
        respondedAt: serverTimestamp(),
        declinedAt: serverTimestamp(),
      });

      return { success: true };
    }
  );

  const createBloomArtCheckout = onCall(
    { region: "us-east1", secrets: [STRIPE_SECRET_KEY] },
    async (request) => {
      const uid = assertAuthenticated(request);
      const data = request.data || {};
      const offerId = cleanString(data.offerId);
      if (!offerId) throw new HttpsError("invalid-argument", "offerId is required");

      const successUrl = cleanString(data.successUrl);
      const cancelUrl = cleanString(data.cancelUrl);
      if (!successUrl || !cancelUrl) {
        throw new HttpsError("invalid-argument", "successUrl and cancelUrl are required");
      }
      if (!isAllowedRedirectUrl(successUrl) || !isAllowedRedirectUrl(cancelUrl)) {
        throw new HttpsError("invalid-argument", "Invalid redirect URL domain");
      }

      const result = await db.runTransaction(async (transaction) => {
        const offerRef = db.collection(COLLECTIONS.offers).doc(offerId);
        const offerSnap = await transaction.get(offerRef);
        if (!offerSnap.exists) throw new HttpsError("not-found", "Offer not found");

        const offer = offerSnap.data();
        assertBuyerOwnsOffer(uid, offer);

        if (![OFFER_STATUS.accepted, OFFER_STATUS.autoAccepted].includes(offer.status)) {
          throw new HttpsError("failed-precondition", `Cannot checkout offer with status: ${offer.status}`);
        }
        if (!offer.checkoutEligible) throw new HttpsError("failed-precondition", "Offer is not eligible for checkout");

        const itemRef = db.collection(COLLECTIONS.items).doc(offer.itemId);
        const itemSnap = await transaction.get(itemRef);
        if (!itemSnap.exists) throw new HttpsError("not-found", "Item no longer exists");

        const item = itemSnap.data();
        if (item.availabilityStatus === ITEM_STATUS.sold) {
          throw new HttpsError("failed-precondition", "Item is already sold");
        }

        const orderRef = db.collection(COLLECTIONS.orders).doc(offerId);
        const orderId = orderRef.id;
        const existingOrderSnap = await transaction.get(orderRef);
        if (existingOrderSnap.exists) {
          const existingOrder = existingOrderSnap.data();
          if (existingOrder.paymentStatus === "paid" || existingOrder.orderStatus === ORDER_STATUS.paid) {
            throw new HttpsError("failed-precondition", "This Bloom Art order is already paid");
          }
          return { orderId, offer, item, orderPayload: existingOrder, reuseExistingOrder: true };
        }

        const orderPayload = {
          itemId: offer.itemId,
          offerId,
          sellerId: offer.sellerId,
          buyerId: uid,
          finalPrice: offer.proposedPrice,
          currency: item.currency || "EUR",
          checkoutSource: BLOOM_ART_KIND,
          stripeCheckoutSessionId: null,
          stripePaymentIntentId: null,
          paymentStatus: "pending",
          orderStatus: ORDER_STATUS.draft,
          itemTitle: item.title || "",
          createdAt: serverTimestamp(),
          updatedAt: serverTimestamp(),
        };
        transaction.set(orderRef, orderPayload);
        return { orderId, offer, item, orderPayload, reuseExistingOrder: false };
      });

      const stripeClient = getStripe();
      if (result.reuseExistingOrder === true) {
        const existingSessionId = result.orderPayload?.stripeCheckoutSessionId;
        const existingOrderStatus = result.orderPayload?.orderStatus;
        if (looksLikeNonEmptyString(existingSessionId)) {
          const existingSession = await stripeClient.checkout.sessions.retrieve(existingSessionId);
          return { orderId: result.orderId, checkoutUrl: existingSession.url, stripeSessionId: existingSession.id };
        }
        if (existingOrderStatus && existingOrderStatus !== ORDER_STATUS.failed) {
          throw new HttpsError("failed-precondition", "A checkout session is already being prepared for this offer");
        }
      }

      const priceInCents = amountToCents(result.offer.proposedPrice);
      let session;
      try {
        session = await stripeClient.checkout.sessions.create(
          {
            mode: "payment",
            line_items: [
              {
                price_data: {
                  currency: (result.item.currency || "EUR").toLowerCase(),
                  product_data: {
                    name: result.item.title || "Bloom Art",
                    description: `Offre acceptee — ${result.item.title || "Article Bloom Art"}`,
                  },
                  unit_amount: priceInCents,
                },
                quantity: 1,
              },
            ],
            client_reference_id: result.orderId,
            success_url: `${successUrl}?orderId=${result.orderId}`,
            cancel_url: `${cancelUrl}?orderId=${result.orderId}`,
            metadata: {
              kind: BLOOM_ART_KIND,
              orderId: result.orderId,
              offerId,
              itemId: result.offer.itemId,
              buyerId: uid,
              sellerId: result.offer.sellerId,
              uid,
            },
            customer_email: request.auth.token.email || undefined,
          },
          { idempotencyKey: `bloom_art_checkout_${uid}_${result.orderId}` }
        );

        await db.runTransaction(async (transaction) => {
          const orderRef = db.collection(COLLECTIONS.orders).doc(result.orderId);
          const offerRef = db.collection(COLLECTIONS.offers).doc(offerId);
          const [orderSnap, offerSnap] = await Promise.all([transaction.get(orderRef), transaction.get(offerRef)]);
          if (!orderSnap.exists || !offerSnap.exists) {
            throw new HttpsError("failed-precondition", "Bloom Art order or offer no longer exists");
          }
          transaction.update(orderRef, {
            stripeCheckoutSessionId: session.id,
            orderStatus: ORDER_STATUS.checkoutStarted,
            updatedAt: serverTimestamp(),
          });
          transaction.update(offerRef, { status: OFFER_STATUS.checkoutStarted, updatedAt: serverTimestamp() });
        });
      } catch (error) {
        await db.collection(COLLECTIONS.orders).doc(result.orderId).set(
          { orderStatus: ORDER_STATUS.failed, updatedAt: serverTimestamp() },
          { merge: true }
        );
        throw error;
      }

      return { orderId: result.orderId, checkoutUrl: session.url, stripeSessionId: session.id };
    }
  );

  async function handleBloomArtCheckoutCompleted(session) {
    const kind = (session?.metadata?.kind || "").toLowerCase();
    if (kind !== BLOOM_ART_KIND) return false;

    const orderId = session.metadata?.orderId;
    const offerId = session.metadata?.offerId;
    const itemId = session.metadata?.itemId;
    if (!orderId) {
      console.warn("[BloomArt] Missing orderId in checkout session metadata");
      return true;
    }

    const orderRef = db.collection(COLLECTIONS.orders).doc(orderId);
    await db.runTransaction(async (transaction) => {
      const orderSnap = await transaction.get(orderRef);
      if (!orderSnap.exists) {
        console.warn(`[BloomArt] Order ${orderId} not found`);
        return;
      }

      const order = orderSnap.data();
      if (order.paymentStatus === "paid" || order.orderStatus === ORDER_STATUS.paid) return;

      transaction.update(orderRef, {
        paymentStatus: "paid",
        orderStatus: ORDER_STATUS.paid,
        stripeCheckoutSessionId: session.id,
        stripePaymentIntentId: session.payment_intent || null,
        stripeCustomerId: session.customer || null,
        updatedAt: serverTimestamp(),
      });

      if (offerId) {
        transaction.update(db.collection(COLLECTIONS.offers).doc(offerId), {
          status: OFFER_STATUS.paid,
          paidAt: serverTimestamp(),
        });
      }

      if (itemId) {
        const itemRef = db.collection(COLLECTIONS.items).doc(itemId);
        transaction.update(itemRef, { availabilityStatus: ITEM_STATUS.sold, updatedAt: serverTimestamp() });
        const pendingOffersSnap = await transaction.get(
          db
            .collection(COLLECTIONS.offers)
            .where("itemId", "==", itemId)
            .where("status", "in", [OFFER_STATUS.pending, OFFER_STATUS.accepted, OFFER_STATUS.autoAccepted])
        );
        for (const doc of pendingOffersSnap.docs) {
          if (doc.id !== offerId) {
            transaction.update(doc.ref, {
              status: OFFER_STATUS.declined,
              checkoutEligible: false,
              declinedAt: serverTimestamp(),
            });
          }
        }
      }
    });

    return true;
  }

  async function handleBloomArtPaymentIntentSucceeded(paymentIntent) {
    const kind = (paymentIntent?.metadata?.kind || "").toLowerCase();
    if (kind !== BLOOM_ART_KIND) return false;
    const orderId = paymentIntent.metadata?.orderId;
    if (!orderId) {
      console.warn("[BloomArt] Missing orderId in payment_intent metadata");
      return true;
    }
    return handleBloomArtCheckoutCompleted({
      ...paymentIntent,
      id: paymentIntent.id,
      payment_intent: paymentIntent.id,
      metadata: paymentIntent.metadata,
    });
  }

  return {
    createBloomArtItem,
    submitBloomArtOffer,
    acceptBloomArtOffer,
    declineBloomArtOffer,
    createBloomArtCheckout,
    handleBloomArtCheckoutCompleted,
    handleBloomArtPaymentIntentSucceeded,
  };
};
