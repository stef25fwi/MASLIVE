/**
 * Bloom Art — Galerie d'art avec système d'offres de prix
 *
 * Collections Firestore :
 *   bloom_art_items            — articles en vente
 *   bloom_art_items/{id}/private — données privées (referencePrice) – lecture serveur uniquement
 *   bloom_art_seller_profiles  — profils vendeur
 *   bloom_art_offers           — offres de prix des visiteurs
 *   bloom_art_orders           — commandes après acceptation d'offre
 *
 * Intégration Stripe :
 *   Réutilise getStripe() existant + webhook central via metadata.kind === "bloom_art"
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

  // ─── Constants ──────────────────────────────────────────────────────
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

  // ─── Helpers ────────────────────────────────────────────────────────

  function serverTimestamp() {
    return admin.firestore.FieldValue.serverTimestamp();
  }

  function looksLikeNonEmptyString(v) {
    return typeof v === "string" && v.trim().length > 0;
  }

  function toNumber(value, fallback = 0) {
    const parsed = Number(value);
    return Number.isFinite(parsed) ? parsed : fallback;
  }

  function amountToCents(amount) {
    return Math.max(0, Math.round(toNumber(amount, 0) * 100));
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

  // ─── 1. createBloomArtItem ──────────────────────────────────────────
  // Callable : le vendeur crée un article Bloom Art.
  // Le referencePrice est stocké dans une sous-collection privée (non lisible côté client).
  const createBloomArtItem = onCall(
    { region: "us-east1", secrets: [STRIPE_SECRET_KEY] },
    async (request) => {
      const uid = assertAuthenticated(request);
      const data = request.data || {};

      const title = looksLikeNonEmptyString(data.title)
        ? data.title.trim()
        : null;
      if (!title) {
        throw new HttpsError("invalid-argument", "Title is required");
      }

      const referencePrice = toNumber(data.referencePrice, 0);
      if (referencePrice <= 0) {
        throw new HttpsError("invalid-argument", "referencePrice must be > 0");
      }

      const currency = looksLikeNonEmptyString(data.currency)
        ? data.currency.trim().toUpperCase()
        : "EUR";

      const itemRef = db.collection(COLLECTIONS.items).doc();
      const privateRef = itemRef.collection("private").doc("pricing");

      const itemPayload = {
        sellerId: uid,
        sellerProfileType: looksLikeNonEmptyString(data.sellerProfileType)
          ? data.sellerProfileType.trim()
          : "individual",
        sellerDisplayName: looksLikeNonEmptyString(data.sellerDisplayName)
          ? data.sellerDisplayName.trim()
          : "",
        title,
        description: looksLikeNonEmptyString(data.description)
          ? data.description.trim()
          : "",
        category: looksLikeNonEmptyString(data.category)
          ? data.category.trim()
          : "other",
        condition: looksLikeNonEmptyString(data.condition)
          ? data.condition.trim()
          : "good",
        materials: looksLikeNonEmptyString(data.materials)
          ? data.materials.trim()
          : "",
        dimensions: looksLikeNonEmptyString(data.dimensions)
          ? data.dimensions.trim()
          : "",
        images: Array.isArray(data.images)
          ? data.images.filter((u) => looksLikeNonEmptyString(u)).slice(0, 10)
          : [],
        currency,
        availabilityStatus: ITEM_STATUS.draft,
        isPublished: false,
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      };

      // Batch : document public + sous-doc privé (referencePrice)
      const batch = db.batch();
      batch.set(itemRef, itemPayload);
      batch.set(privateRef, {
        referencePrice,
        currency,
        updatedAt: serverTimestamp(),
      });
      await batch.commit();

      return { itemId: itemRef.id };
    }
  );

  // ─── 2. submitBloomArtOffer ─────────────────────────────────────────
  // Callable : un visiteur authentifié propose un prix.
  const submitBloomArtOffer = onCall(
    { region: "us-east1", secrets: [STRIPE_SECRET_KEY] },
    async (request) => {
      const uid = assertAuthenticated(request);
      const data = request.data || {};

      const itemId = looksLikeNonEmptyString(data.itemId)
        ? data.itemId.trim()
        : null;
      if (!itemId) {
        throw new HttpsError("invalid-argument", "itemId is required");
      }

      const proposedPrice = toNumber(data.proposedPrice, 0);
      if (proposedPrice <= 0) {
        throw new HttpsError("invalid-argument", "proposedPrice must be > 0");
      }

      const buyerMessage = looksLikeNonEmptyString(data.buyerMessage)
        ? data.buyerMessage.trim().slice(0, 500)
        : "";

      // Charger l'article + prix de référence côté serveur
      const itemRef = db.collection(COLLECTIONS.items).doc(itemId);
      const privateRef = itemRef.collection("private").doc("pricing");

      const [itemSnap, privateSnap] = await Promise.all([
        itemRef.get(),
        privateRef.get(),
      ]);

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

      // Empêcher plusieurs offres actives du même acheteur sur le même article
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
        throw new HttpsError(
          "already-exists",
          "You already have an active offer on this item"
        );
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

      // Si auto-acceptée, marquer l'article comme réservé
      if (autoAccepted) {
        await itemRef.update({
          availabilityStatus: ITEM_STATUS.reserved,
          updatedAt: serverTimestamp(),
        });
      }

      // TODO: Envoyer notification au vendeur (FCM / email)

      return {
        offerId: offerRef.id,
        status: offerPayload.status,
        checkoutEligible: offerPayload.checkoutEligible,
      };
    }
  );

  // ─── 3. acceptBloomArtOffer ─────────────────────────────────────────
  // Callable : le vendeur accepte une offre pending.
  const acceptBloomArtOffer = onCall(
    { region: "us-east1", secrets: [STRIPE_SECRET_KEY] },
    async (request) => {
      const uid = assertAuthenticated(request);
      const data = request.data || {};

      const offerId = looksLikeNonEmptyString(data.offerId)
        ? data.offerId.trim()
        : null;
      if (!offerId) {
        throw new HttpsError("invalid-argument", "offerId is required");
      }

      const offerRef = db.collection(COLLECTIONS.offers).doc(offerId);

      await db.runTransaction(async (transaction) => {
        const offerSnap = await transaction.get(offerRef);
        if (!offerSnap.exists) {
          throw new HttpsError("not-found", "Offer not found");
        }

        const offer = offerSnap.data();
        assertSellerOwnsOffer(uid, offer);

        if (offer.status !== OFFER_STATUS.pending) {
          throw new HttpsError(
            "failed-precondition",
            `Cannot accept offer with status: ${offer.status}`
          );
        }

        // Vérifier qu'aucune autre offre acceptée n'existe pour cet article
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
          throw new HttpsError(
            "failed-precondition",
            "Another offer is already accepted for this item"
          );
        }

        transaction.update(offerRef, {
          status: OFFER_STATUS.accepted,
          checkoutEligible: true,
          respondedAt: serverTimestamp(),
          acceptedAt: serverTimestamp(),
        });

        // Réserver l'article
        const itemRef = db.collection(COLLECTIONS.items).doc(offer.itemId);
        transaction.update(itemRef, {
          availabilityStatus: ITEM_STATUS.reserved,
          updatedAt: serverTimestamp(),
        });
      });

      // TODO: Notifier l'acheteur (FCM / email)

      return { success: true };
    }
  );

  // ─── 4. declineBloomArtOffer ────────────────────────────────────────
  // Callable : le vendeur refuse une offre pending.
  const declineBloomArtOffer = onCall(
    { region: "us-east1", secrets: [STRIPE_SECRET_KEY] },
    async (request) => {
      const uid = assertAuthenticated(request);
      const data = request.data || {};

      const offerId = looksLikeNonEmptyString(data.offerId)
        ? data.offerId.trim()
        : null;
      if (!offerId) {
        throw new HttpsError("invalid-argument", "offerId is required");
      }

      const offerRef = db.collection(COLLECTIONS.offers).doc(offerId);
      const offerSnap = await offerRef.get();

      if (!offerSnap.exists) {
        throw new HttpsError("not-found", "Offer not found");
      }

      const offer = offerSnap.data();
      assertSellerOwnsOffer(uid, offer);

      if (offer.status !== OFFER_STATUS.pending) {
        throw new HttpsError(
          "failed-precondition",
          `Cannot decline offer with status: ${offer.status}`
        );
      }

      await offerRef.update({
        status: OFFER_STATUS.declined,
        checkoutEligible: false,
        respondedAt: serverTimestamp(),
        declinedAt: serverTimestamp(),
      });

      // TODO: Notifier l'acheteur (FCM / email)

      return { success: true };
    }
  );

  // ─── 5. createBloomArtCheckout ──────────────────────────────────────
  // Callable : l'acheteur lance le paiement d'une offre acceptée.
  // Réutilise getStripe() et le pattern Checkout Session du projet.
  const createBloomArtCheckout = onCall(
    { region: "us-east1", secrets: [STRIPE_SECRET_KEY] },
    async (request) => {
      const uid = assertAuthenticated(request);
      const data = request.data || {};

      const offerId = looksLikeNonEmptyString(data.offerId)
        ? data.offerId.trim()
        : null;
      if (!offerId) {
        throw new HttpsError("invalid-argument", "offerId is required");
      }

      const successUrl = looksLikeNonEmptyString(data.successUrl)
        ? data.successUrl.trim()
        : null;
      const cancelUrl = looksLikeNonEmptyString(data.cancelUrl)
        ? data.cancelUrl.trim()
        : null;

      if (!successUrl || !cancelUrl) {
        throw new HttpsError("invalid-argument", "successUrl and cancelUrl are required");
      }

      if (!isAllowedRedirectUrl(successUrl) || !isAllowedRedirectUrl(cancelUrl)) {
        throw new HttpsError("invalid-argument", "Invalid redirect URL domain");
      }

      // Transaction : empêcher double checkout
      const result = await db.runTransaction(async (transaction) => {
        const offerRef = db.collection(COLLECTIONS.offers).doc(offerId);
        const offerSnap = await transaction.get(offerRef);

        if (!offerSnap.exists) {
          throw new HttpsError("not-found", "Offer not found");
        }

        const offer = offerSnap.data();
        assertBuyerOwnsOffer(uid, offer);

        const eligible = [OFFER_STATUS.accepted, OFFER_STATUS.autoAccepted];
        if (!eligible.includes(offer.status)) {
          throw new HttpsError(
            "failed-precondition",
            `Cannot checkout offer with status: ${offer.status}`
          );
        }

        if (!offer.checkoutEligible) {
          throw new HttpsError("failed-precondition", "Offer is not eligible for checkout");
        }

        // Vérifier que l'article est toujours réservé / pas déjà vendu
        const itemRef = db.collection(COLLECTIONS.items).doc(offer.itemId);
        const itemSnap = await transaction.get(itemRef);

        if (!itemSnap.exists) {
          throw new HttpsError("not-found", "Item no longer exists");
        }

        const item = itemSnap.data();
        if (item.availabilityStatus === ITEM_STATUS.sold) {
          throw new HttpsError("failed-precondition", "Item is already sold");
        }

        // Créer la commande Bloom Art
        const orderRef = db.collection(COLLECTIONS.orders).doc();
        const orderId = orderRef.id;

        const orderPayload = {
          itemId: offer.itemId,
          offerId,
          sellerId: offer.sellerId,
          buyerId: uid,
          finalPrice: offer.proposedPrice,
          currency: item.currency || "EUR",
          checkoutSource: BLOOM_ART_KIND,
          stripeCheckoutSessionId: null, // sera rempli après création Stripe
          stripePaymentIntentId: null,
          paymentStatus: "pending",
          orderStatus: ORDER_STATUS.draft,
          itemTitle: item.title || "",
          createdAt: serverTimestamp(),
          updatedAt: serverTimestamp(),
        };

        transaction.set(orderRef, orderPayload);

        // Mettre l'offre en checkout_started
        transaction.update(offerRef, {
          status: OFFER_STATUS.checkoutStarted,
          updatedAt: serverTimestamp(),
        });

        return {
          orderId,
          offer,
          item,
          orderPayload,
        };
      });

      // Créer la session Stripe Checkout hors transaction (appel réseau)
      const stripeClient = getStripe();
      const priceInCents = amountToCents(result.offer.proposedPrice);

      const session = await stripeClient.checkout.sessions.create(
        {
          mode: "payment",
          line_items: [
            {
              price_data: {
                currency: (result.item.currency || "EUR").toLowerCase(),
                product_data: {
                  name: result.item.title || "Bloom Art",
                  description: `Offre acceptée — ${result.item.title || "Article Bloom Art"}`,
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

      // Mettre à jour la commande avec l'ID de session Stripe
      await db.collection(COLLECTIONS.orders).doc(result.orderId).update({
        stripeCheckoutSessionId: session.id,
        orderStatus: ORDER_STATUS.checkoutStarted,
        updatedAt: serverTimestamp(),
      });

      return {
        orderId: result.orderId,
        checkoutUrl: session.url,
        stripeSessionId: session.id,
      };
    }
  );

  // ─── 6. Webhook handler ────────────────────────────────────────────
  // Appelé depuis handleCheckoutSessionCompleted dans index.js
  // Retourne true si l'événement a été traité (pattern identique à media-marketplace-stripe).
  async function handleBloomArtCheckoutCompleted(session) {
    const kind = (session?.metadata?.kind || "").toLowerCase();
    if (kind !== BLOOM_ART_KIND) {
      return false; // pas un événement Bloom Art
    }

    const orderId = session.metadata?.orderId;
    const offerId = session.metadata?.offerId;
    const itemId = session.metadata?.itemId;

    if (!orderId) {
      console.warn("[BloomArt] Missing orderId in checkout session metadata");
      return true; // traité (en erreur) pour ne pas re-dispatcher
    }

    console.log(`[BloomArt] Processing checkout completed for order ${orderId}`);

    const orderRef = db.collection(COLLECTIONS.orders).doc(orderId);

    await db.runTransaction(async (transaction) => {
      const orderSnap = await transaction.get(orderRef);
      if (!orderSnap.exists) {
        console.warn(`[BloomArt] Order ${orderId} not found`);
        return;
      }

      const order = orderSnap.data();

      // Idempotence : ne pas re-traiter une commande déjà payée
      if (order.paymentStatus === "paid" || order.orderStatus === ORDER_STATUS.paid) {
        console.log(`[BloomArt] Order ${orderId} already paid, skipping`);
        return;
      }

      // Mettre à jour la commande
      transaction.update(orderRef, {
        paymentStatus: "paid",
        orderStatus: ORDER_STATUS.paid,
        stripeCheckoutSessionId: session.id,
        stripePaymentIntentId: session.payment_intent || null,
        stripeCustomerId: session.customer || null,
        updatedAt: serverTimestamp(),
      });

      // Mettre à jour l'offre
      if (offerId) {
        const offerRef = db.collection(COLLECTIONS.offers).doc(offerId);
        transaction.update(offerRef, {
          status: OFFER_STATUS.paid,
          paidAt: serverTimestamp(),
        });
      }

      // Marquer l'article comme vendu
      if (itemId) {
        const itemRef = db.collection(COLLECTIONS.items).doc(itemId);
        transaction.update(itemRef, {
          availabilityStatus: ITEM_STATUS.sold,
          updatedAt: serverTimestamp(),
        });

        // Décliner toutes les autres offres en attente sur cet article
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

  // Handler pour payment_intent.succeeded (si utilisé en mode PI au lieu de Checkout)
  async function handleBloomArtPaymentIntentSucceeded(paymentIntent) {
    const kind = (paymentIntent?.metadata?.kind || "").toLowerCase();
    if (kind !== BLOOM_ART_KIND) {
      return false;
    }

    const orderId = paymentIntent.metadata?.orderId;
    if (!orderId) {
      console.warn("[BloomArt] Missing orderId in payment_intent metadata");
      return true;
    }

    // Délègue au même traitement (les champs sont compatibles)
    return handleBloomArtCheckoutCompleted({
      ...paymentIntent,
      id: paymentIntent.id,
      payment_intent: paymentIntent.id,
      metadata: paymentIntent.metadata,
    });
  }

  // ─── Exports ────────────────────────────────────────────────────────
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
