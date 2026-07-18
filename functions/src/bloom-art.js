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
    resolveStripeConnectCountry,
  } = deps;

  const BLOOM_ART_KIND = "bloom_art";
  const AUTO_ACCEPT_THRESHOLD_PERCENT = 0.90;
  const PLATFORM_FEE_PERCENT = 0.10;
  // Alma (paiement en 2/3/4 fois) est un moyen de paiement natif Stripe : pas de
  // clé API séparée, juste activé côté Dashboard Stripe. Limites Alma: EUR only,
  // montant entre 50 et 5000 EUR. https://docs.stripe.com/payments/alma
  const ALMA_MIN_AMOUNT = 50;
  const ALMA_MAX_AMOUNT = 5000;

  function resolveBloomArtPaymentMethodTypes(amount, currency) {
    const types = ["card"];
    const normalizedCurrency = String(currency || "EUR").toUpperCase();
    const normalizedAmount = Number(amount) || 0;
    if (
      normalizedCurrency === "EUR" &&
      normalizedAmount >= ALMA_MIN_AMOUNT &&
      normalizedAmount <= ALMA_MAX_AMOUNT
    ) {
      types.push("alma");
    }
    return types;
  }

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

  function computeCommissionSplit(amount) {
    const platformFee = Math.round(toNumber(amount, 0) * PLATFORM_FEE_PERCENT * 100) / 100;
    const netAmount = Math.max(0, toNumber(amount, 0) - platformFee);
    return { platformFee, netAmount };
  }

  async function getFcmTokensForUser(uid) {
    const tokens = [];
    try {
      const snap = await db.collection("users").doc(uid).collection("devices").get();
      snap.forEach((d) => {
        const t = d.get("token");
        if (typeof t === "string" && t.length > 10) tokens.push(t);
      });
    } catch (_) {}

    if (tokens.length === 0) {
      try {
        const userSnap = await db.collection("users").doc(uid).get();
        const data = userSnap.exists ? (userSnap.data() || {}) : {};
        const arr = Array.isArray(data.fcmTokens) ? data.fcmTokens : [];
        for (const t of arr) {
          if (typeof t === "string" && t.length > 10) tokens.push(t);
        }
      } catch (_) {}
    }

    return Array.from(new Set(tokens));
  }

  async function notifyBloomArtSellerOffer({ sellerId, itemId, itemTitle, offerId, proposedPrice, currency, autoAccepted }) {
    if (!looksLikeNonEmptyString(sellerId)) return;

    const title = autoAccepted ? "Vente Bloom Art conclue" : "Nouvelle proposition de prix";
    const displayPrice = `${Number(proposedPrice).toFixed(2)} ${currency || "EUR"}`;
    const body = autoAccepted
      ? `Offre acceptée automatiquement pour "${itemTitle || "votre création"}" — ${displayPrice}.`
      : `Un acheteur propose ${displayPrice} pour "${itemTitle || "votre création"}". A valider manuellement.`;

    try {
      await db.collection("users").doc(sellerId).collection("inbox").add({
        type: "bloom_art_offer",
        title,
        body,
        itemId,
        offerId,
        createdAt: serverTimestamp(),
        read: false,
        actionLabel: "Voir l'offre",
        meta: { autoAccepted: !!autoAccepted },
      });
    } catch (err) {
      console.error(`[BloomArt] Failed to write inbox notification for seller ${sellerId}:`, err?.message || err);
    }

    try {
      const tokens = await getFcmTokensForUser(sellerId);
      if (!tokens.length) return;
      await admin.messaging().sendEachForMulticast({
        tokens,
        notification: { title, body },
        data: { type: "bloom_art_offer", itemId: itemId || "", offerId: offerId || "" },
        android: { priority: "high", notification: { channelId: "orders" } },
        apns: { payload: { aps: { sound: "default" } } },
      });
    } catch (err) {
      console.error(`[BloomArt] Failed to push notification for seller ${sellerId}:`, err?.message || err);
    }
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

  // Vérification SIRET côté serveur — remplace l'ancien flux client-side où
  // Flutter appelait directement recherche-entreprises.api.gouv.fr et écrivait
  // lui-même businessVerificationStatus/sellerStatus sur Firestore (un client
  // modifié pouvait donc s'auto-déclarer "verified"/"active" sans vrai SIRET).
  // Désormais seul ce Cloud Function (Admin SDK, bypass les rules) peut poser
  // ces champs ; les rules bloquent leur écriture directe côté client.
  const SIRET_REGEXP = /^\d{14}$/;

  function passesSiretLuhn(value) {
    let sum = 0;
    let shouldDouble = false;
    for (let i = value.length - 1; i >= 0; i -= 1) {
      let digit = parseInt(value[i], 10);
      if (shouldDouble) {
        digit *= 2;
        if (digit > 9) digit -= 9;
      }
      sum += digit;
      shouldDouble = !shouldDouble;
    }
    return sum % 10 === 0;
  }

  function readPath(source, path) {
    let current = source;
    for (const part of path.split(".")) {
      if (current && typeof current === "object" && !Array.isArray(current)) {
        current = current[part];
        continue;
      }
      if (Array.isArray(current)) {
        const index = Number.parseInt(part, 10);
        if (!Number.isInteger(index) || index < 0 || index >= current.length) return undefined;
        current = current[index];
        continue;
      }
      return undefined;
    }
    return current;
  }

  function stringValue(source, paths) {
    for (const path of paths) {
      const value = readPath(source, path);
      const str = value === null || value === undefined ? "" : String(value).trim();
      if (str && str !== "null") return str;
    }
    return "";
  }

  function domRegionFallback(postalCode) {
    if (postalCode.startsWith("971")) return "Guadeloupe";
    if (postalCode.startsWith("972")) return "Martinique";
    if (postalCode.startsWith("973")) return "Guyane";
    if (postalCode.startsWith("974")) return "La Réunion";
    if (postalCode.startsWith("976")) return "Mayotte";
    return "";
  }

  function normalizeCityText(value) {
    return String(value || "")
      .trim()
      .toLowerCase()
      .replace(/[\s\-']+/g, " ")
      .replace(/[éèê]/g, "e")
      .replace(/[àâ]/g, "a")
      .replace(/[îï]/g, "i")
      .replace(/[ôö]/g, "o")
      .replace(/[ùû]/g, "u")
      .replace(/ç/g, "c");
  }

  async function resolveRegionFromPostalCode(postalCode, city) {
    const normalizedPostalCode = cleanString(postalCode);
    if (!normalizedPostalCode) return "";

    try {
      const url = new URL("https://geo.api.gouv.fr/communes");
      url.searchParams.set("codePostal", normalizedPostalCode);
      url.searchParams.set("fields", "nom,region");
      url.searchParams.set("format", "json");

      const response = await fetch(url, { headers: { accept: "application/json" } });
      if (!response.ok) return domRegionFallback(normalizedPostalCode);

      const rows = await response.json();
      if (!Array.isArray(rows) || rows.length === 0) return domRegionFallback(normalizedPostalCode);

      const normalizedCity = normalizeCityText(city);
      let selected = null;
      for (const row of rows) {
        if (!row || typeof row !== "object") continue;
        const rowCity = normalizeCityText(row.nom || "");
        if (normalizedCity && rowCity === normalizedCity) {
          selected = row;
          break;
        }
        if (!selected) selected = row;
      }

      const region = selected && selected.region && typeof selected.region === "object"
        ? cleanString(selected.region.nom)
        : "";
      return region || domRegionFallback(normalizedPostalCode);
    } catch (_) {
      return domRegionFallback(normalizedPostalCode);
    }
  }

  const verifyBloomArtSiret = onCall(
    { region: "us-east1" },
    async (request) => {
      const uid = assertAuthenticated(request);
      const rawSiret = cleanString((request.data || {}).siret);
      const siret = rawSiret.replace(/[^0-9]/g, "");

      const invalid = (errorMessage) => ({
        siret,
        siren: "",
        denomination: "",
        nafCode: "",
        address: "",
        postalCode: "",
        city: "",
        region: "",
        isValid: false,
        errorMessage,
      });

      if (!SIRET_REGEXP.test(siret)) {
        return invalid("Le SIRET doit contenir 14 chiffres.");
      }
      if (!passesSiretLuhn(siret)) {
        return invalid("Le numéro SIRET ne respecte pas la clé de contrôle.");
      }

      let enterprise = null;
      try {
        const url = new URL("https://recherche-entreprises.api.gouv.fr/search");
        url.searchParams.set("q", siret);
        url.searchParams.set("per_page", "1");
        const response = await fetch(url, { headers: { accept: "application/json" } });
        if (response.ok) {
          const decoded = await response.json();
          const results = decoded && decoded.results;
          if (Array.isArray(results) && results.length > 0 && typeof results[0] === "object") {
            enterprise = results[0];
          }
        }
      } catch (fetchErr) {
        console.error("[BloomArt] verifyBloomArtSiret fetch failed:", fetchErr?.message || fetchErr);
      }

      if (!enterprise) {
        const profileRef = db.collection(COLLECTIONS.sellerProfiles).doc(uid);
        await profileRef.set(
          {
            userId: uid,
            profileType: "artisan_art",
            siret,
            businessVerificationStatus: "rejected",
            businessVerificationSource: "server_recherche_entreprises_api_gouv",
            updatedAt: serverTimestamp(),
          },
          { merge: true }
        );
        return invalid("Aucune entreprise française trouvée pour ce SIRET.");
      }

      const returnedSiret = stringValue(enterprise, [
        "siret",
        "siege.siret",
        "matching_etablissements.0.siret",
      ]);
      if (returnedSiret && returnedSiret.replace(/[^0-9]/g, "") !== siret) {
        const profileRef = db.collection(COLLECTIONS.sellerProfiles).doc(uid);
        await profileRef.set(
          {
            userId: uid,
            profileType: "artisan_art",
            siret,
            businessVerificationStatus: "rejected",
            businessVerificationSource: "server_recherche_entreprises_api_gouv",
            updatedAt: serverTimestamp(),
          },
          { merge: true }
        );
        return invalid("Le résultat API ne correspond pas exactement au SIRET saisi.");
      }

      const address = stringValue(enterprise, [
        "siege.adresse",
        "siege.geo_adresse",
        "matching_etablissements.0.adresse",
        "adresse",
      ]);
      const postalCode = stringValue(enterprise, [
        "siege.code_postal",
        "matching_etablissements.0.code_postal",
        "code_postal",
      ]);
      const city = stringValue(enterprise, [
        "siege.libelle_commune",
        "siege.commune",
        "matching_etablissements.0.commune",
        "commune",
      ]);
      const region = await resolveRegionFromPostalCode(postalCode, city);
      const siren = stringValue(enterprise, ["siren"]) || siret.slice(0, 9);
      const denomination = stringValue(enterprise, [
        "nom_complet",
        "nom_raison_sociale",
        "denomination",
        "siege.enseigne",
      ]);
      const nafCode = stringValue(enterprise, [
        "activite_principale",
        "naf",
        "code_naf",
        "siege.activite_principale",
      ]);

      const profileRef = db.collection(COLLECTIONS.sellerProfiles).doc(uid);
      const profileSnap = await profileRef.get();
      const profilePayload = {
        userId: uid,
        profileType: "artisan_art",
        siret,
        siren,
        businessName: denomination,
        nafCode,
        businessVerificationStatus: "verified",
        businessVerificationSource: "server_recherche_entreprises_api_gouv",
        businessVerifiedAt: serverTimestamp(),
        sellerStatus: "active",
        updatedAt: serverTimestamp(),
      };
      if (!profileSnap.exists) profilePayload.createdAt = serverTimestamp();
      if (address) profilePayload.address = address;
      if (address) profilePayload.businessAddress = address;
      if (postalCode) profilePayload.postalCode = postalCode;
      if (city) profilePayload.city = city;
      if (region) profilePayload.region = region;

      await profileRef.set(profilePayload, { merge: true });

      return {
        siret,
        siren,
        denomination,
        nafCode,
        address,
        postalCode,
        city,
        region,
        isValid: true,
      };
    }
  );

  const createBloomArtConnectOnboardingLink = onCall(
    { region: "us-east1", secrets: [STRIPE_SECRET_KEY] },
    async (request) => {
      const uid = assertAuthenticated(request);

      const profileRef = db.collection(COLLECTIONS.sellerProfiles).doc(uid);
      const profileSnap = await profileRef.get();
      if (!profileSnap.exists) {
        throw new HttpsError("not-found", "Bloom Art seller profile not found");
      }

      const profile = profileSnap.data() || {};
      if (profile.sellerStatus !== "active" || profile.businessVerificationStatus !== "verified") {
        throw new HttpsError(
          "failed-precondition",
          "Seller profile must be verified (SIRET) before configuring Stripe"
        );
      }

      const stripeClient = getStripe();
      let accountId = profile.stripe && profile.stripe.accountId;

      if (!accountId) {
        const email = cleanString(profile.email) || request.auth.token.email;
        const country = resolveStripeConnectCountry(profile.country);
        if (!country) {
          throw new HttpsError(
            "failed-precondition",
            "Unsupported or missing seller country for Stripe Connect"
          );
        }

        const account = await stripeClient.accounts.create({
          type: "express",
          country,
          email,
          business_type: "individual",
          capabilities: {
            card_payments: { requested: true },
            transfers: { requested: true },
          },
          metadata: {
            uid,
            kind: "bloom_art_seller",
          },
        });

        accountId = account.id;

        await profileRef.set(
          {
            stripe: {
              accountId,
              accountCountry: country,
              createdAt: serverTimestamp(),
              updatedAt: serverTimestamp(),
            },
            stripeAccountLinked: true,
            payoutStatus: "linked",
            updatedAt: serverTimestamp(),
          },
          { merge: true }
        );
      }

      const baseUrl = "https://maslive.web.app/";
      const refreshUrl = `${baseUrl}?stripeConnect=refresh&bloomArt=1`;
      const returnUrl = `${baseUrl}?stripeConnect=return&bloomArt=1`;

      const link = await stripeClient.accountLinks.create({
        account: accountId,
        refresh_url: refreshUrl,
        return_url: returnUrl,
        type: "account_onboarding",
      });

      return { url: link.url, accountId };
    }
  );

  const refreshBloomArtConnectStatus = onCall(
    { region: "us-east1", secrets: [STRIPE_SECRET_KEY] },
    async (request) => {
      const uid = assertAuthenticated(request);

      const profileRef = db.collection(COLLECTIONS.sellerProfiles).doc(uid);
      const profileSnap = await profileRef.get();
      if (!profileSnap.exists) {
        throw new HttpsError("not-found", "Bloom Art seller profile not found");
      }

      const profile = profileSnap.data() || {};
      const accountId = profile.stripe && profile.stripe.accountId;
      if (!accountId) {
        throw new HttpsError("failed-precondition", "Stripe accountId not found for this seller");
      }

      const stripeClient = getStripe();
      const account = await stripeClient.accounts.retrieve(accountId);

      const detailsSubmitted = !!account.details_submitted;
      const chargesEnabled = !!account.charges_enabled;
      const payoutsEnabled = !!account.payouts_enabled;
      const requirements = account.requirements || {};

      await profileRef.set(
        {
          stripe: {
            accountId,
            detailsSubmitted,
            chargesEnabled,
            payoutsEnabled,
            currentlyDue: requirements.currently_due || [],
            eventuallyDue: requirements.eventually_due || [],
            pastDue: requirements.past_due || [],
            currentDeadline: requirements.current_deadline || null,
            updatedAt: serverTimestamp(),
          },
          payoutStatus: chargesEnabled ? "active" : "pending",
          updatedAt: serverTimestamp(),
        },
        { merge: true }
      );

      return { accountId, detailsSubmitted, chargesEnabled, payoutsEnabled };
    }
  );

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

      await notifyBloomArtSellerOffer({
        sellerId: item.sellerId,
        itemId,
        itemTitle: item.title,
        offerId: offerRef.id,
        proposedPrice,
        currency: item.currency,
        autoAccepted,
      });

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

        const { platformFee, netAmount } = computeCommissionSplit(offer.proposedPrice);

        const orderPayload = {
          itemId: offer.itemId,
          offerId,
          sellerId: offer.sellerId,
          buyerId: uid,
          finalPrice: offer.proposedPrice,
          platformFee,
          netAmount,
          feePercent: PLATFORM_FEE_PERCENT,
          payoutStatus: "pending",
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
            payment_method_types: resolveBloomArtPaymentMethodTypes(
              result.offer.proposedPrice,
              result.item.currency
            ),
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

  async function settleBloomArtPayout(orderId) {
    if (!looksLikeNonEmptyString(orderId)) return;

    const orderRef = db.collection(COLLECTIONS.orders).doc(orderId);
    const orderSnap = await orderRef.get();
    if (!orderSnap.exists) return;

    const order = orderSnap.data() || {};
    if (order.payoutStatus === "paid" || order.payoutStatus === "pending_account") return;

    const sellerId = cleanString(order.sellerId);
    const netAmount = toNumber(order.netAmount, 0);
    const currency = cleanString(order.currency, "EUR").toLowerCase();
    const netCents = amountToCents(netAmount);
    if (!sellerId || netCents <= 0) return;

    const profileSnap = await db.collection(COLLECTIONS.sellerProfiles).doc(sellerId).get();
    const profile = profileSnap.exists ? (profileSnap.data() || {}) : {};
    const accountId = profile.stripe && profile.stripe.accountId;
    const chargesEnabled = !!(profile.stripe && profile.stripe.chargesEnabled);

    if (typeof accountId !== "string" || accountId.trim().length === 0 || !chargesEnabled) {
      await orderRef.set(
        {
          payoutStatus: "pending_account",
          payoutFailureReason: !accountId ? "no_connect_account" : "charges_disabled",
          updatedAt: serverTimestamp(),
        },
        { merge: true }
      );
      console.warn(
        `[BloomArt] Order ${orderId}: seller ${sellerId} not payable via Connect ` +
          `(${!accountId ? "no_connect_account" : "charges_disabled"}); amount kept on platform`
      );
      return;
    }

    const stripeClient = getStripe();
    try {
      const transfer = await stripeClient.transfers.create(
        {
          amount: netCents,
          currency,
          destination: accountId.trim(),
          transfer_group: `bloom_art_order_${orderId}`,
          metadata: { orderId, sellerId },
        },
        { idempotencyKey: `bloom_art_payout_${orderId}` }
      );

      await orderRef.set(
        {
          payoutStatus: "paid",
          transferId: transfer.id,
          paidOutAt: serverTimestamp(),
          updatedAt: serverTimestamp(),
        },
        { merge: true }
      );
    } catch (transferErr) {
      await orderRef.set(
        {
          payoutStatus: "failed",
          payoutFailureReason: transferErr?.code || "transfer_error",
          updatedAt: serverTimestamp(),
        },
        { merge: true }
      );
      console.error(
        `[BloomArt] Order ${orderId}: transfer to seller ${sellerId} failed:`,
        transferErr?.message || transferErr
      );
    }
  }

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

    try {
      await settleBloomArtPayout(orderId);
    } catch (payoutErr) {
      console.error(
        `[BloomArt] Failed to settle payout for order ${orderId}:`,
        payoutErr?.message || payoutErr
      );
    }

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
    createBloomArtConnectOnboardingLink,
    refreshBloomArtConnectStatus,
    verifyBloomArtSiret,
    handleBloomArtCheckoutCompleted,
    handleBloomArtPaymentIntentSucceeded,
  };
};
