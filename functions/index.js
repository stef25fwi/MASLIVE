/**
 * Cloud Functions Gen 2 (firebase-functions v2)
 * - nearbySearch (onCall)
 * - updateGroupLocation (onCall)
 * - initializeRoles (onCall) - Initialise les rôles par défaut
 */

const admin = require("firebase-admin");
const ngeohash = require("ngeohash");
const { setGlobalOptions, logger } = require("firebase-functions/v2");
const { defineSecret } = require("firebase-functions/params");
const {
  onDocumentCreated,
  onDocumentUpdated,
} = require("firebase-functions/v2/firestore");
const { onCall, onRequest, HttpsError } = require("firebase-functions/v2/https");

const STRIPE_SECRET_KEY = defineSecret("STRIPE_SECRET_KEY");
const STRIPE_WEBHOOK_SECRET = defineSecret("STRIPE_WEBHOOK_SECRET");

// Stripe SDK (lazy initialization)
const stripeModule = require("stripe");
let stripe = null;

const DEFAULT_STOREX_SHOP_ID = "global";

function toSafeInt(n, fallback = 0) {
  const x = Number(n);
  if (!Number.isFinite(x)) return fallback;
  return Math.trunc(x);
}

function looksLikeNonEmptyString(v) {
  return typeof v === "string" && v.trim().length > 0;
}

function uniqueStrings(arr) {
  return Array.from(new Set((arr || []).filter((x) => typeof x === "string" && x.trim().length > 0).map((x) => x.trim())));
}

function normalizeShippingAddress(address) {
  const a = (address && typeof address === "object") ? address : {};
  const s = (k, max = 120) => {
    const v = (typeof a[k] === "string") ? a[k].trim() : "";
    return v.length > max ? v.slice(0, max) : v;
  };

  const out = {
    firstName: s("firstName", 80),
    lastName: s("lastName", 80),
    country: s("country", 80),
    state: s("state", 80),
    addressLine1: s("addressLine1", 200),
    addressLine2: s("addressLine2", 200),
    region: s("region", 120),
    zip: s("zip", 20),
    email: s("email", 160),
    phone: s("phone", 40),
  };

  // Champs requis (aligné avec l'app)
  if (!out.firstName || !out.lastName || !out.addressLine1 || !out.zip || !out.email || !out.phone) {
    throw new HttpsError("invalid-argument", "Shipping address incomplete");
  }
  if (!out.email.includes("@")) {
    throw new HttpsError("invalid-argument", "Invalid email");
  }
  return out;
}

function deepLinkForOrder(orderId) {
  return `maslive://orders/${orderId}`;
}

function assertPositiveCents(value, name) {
  const cents = toSafeInt(value, 0);
  if (cents <= 0) {
    throw new HttpsError("failed-precondition", `${name} must be > 0`);
  }
  return cents;
}

async function fetchStorexProductsById(productIds, { shopId = DEFAULT_STOREX_SHOP_ID } = {}) {
  const unique = Array.from(new Set((productIds || []).filter(Boolean)));
  if (!unique.length) return new Map();

  const primaryRefs = unique.map((id) => db.collection("shops").doc(shopId).collection("products").doc(id));
  const primarySnaps = await db.getAll(...primaryRefs);
  const out = new Map();

  const missing = [];
  for (let i = 0; i < unique.length; i++) {
    const id = unique[i];
    const snap = primarySnaps[i];
    if (snap.exists) {
      out.set(id, snap.data() || {});
    } else {
      missing.push(id);
    }
  }

  if (missing.length) {
    const fallbackRefs = missing.map((id) => db.collection("products").doc(id));
    const fallbackSnaps = await db.getAll(...fallbackRefs);
    for (let i = 0; i < missing.length; i++) {
      const id = missing[i];
      const snap = fallbackSnaps[i];
      if (snap.exists) out.set(id, snap.data() || {});
    }
  }

  return out;
}

async function fetchPhotosById(photoIds) {
  const unique = Array.from(new Set((photoIds || []).filter(Boolean)));
  if (!unique.length) return new Map();
  const refs = unique.map((id) => db.collection("photos").doc(id));
  const snaps = await db.getAll(...refs);
  const out = new Map();
  for (let i = 0; i < unique.length; i++) {
    const id = unique[i];
    const snap = snaps[i];
    if (snap.exists) out.set(id, snap.data() || {});
  }
  return out;
}

function getStripeWebhookSecret() {
  return STRIPE_WEBHOOK_SECRET.value() || process.env.STRIPE_WEBHOOK_SECRET;
}

function getStripe() {
  if (!stripe) {
    const apiKey = STRIPE_SECRET_KEY.value() || process.env.STRIPE_SECRET_KEY;
    if (!apiKey) {
      throw new Error(
        "STRIPE_SECRET_KEY not configured. Run: " +
        "firebase functions:secrets:set STRIPE_SECRET_KEY"
      );
    }
    stripe = stripeModule(apiKey);
  }
  return stripe;
}

function getStripeV20240620() {
  // Stripe client specifically pinned for createStorexPaymentIntent
  const apiKey = STRIPE_SECRET_KEY.value() || process.env.STRIPE_SECRET_KEY;

  if (!apiKey) {
    throw new Error(
      "STRIPE_SECRET_KEY not configured. Run: " +
        "firebase functions:secrets:set STRIPE_SECRET_KEY"
    );
  }

  return stripeModule(apiKey, { apiVersion: "2024-06-20" });
}

function isAllowedRedirectUrl(url) {
  if (typeof url !== "string" || url.trim().length === 0) return false;
  try {
    const u = new URL(url);

    // Allow local development
    if (u.protocol === "http:" && (u.hostname === "localhost" || u.hostname === "127.0.0.1")) {
      return true;
    }

    // Production: strict allowlist
    if (u.protocol !== "https:") return false;

    const allowedHosts = new Set([
      "maslive.web.app",
      "maslive.firebaseapp.com",
    ]);

    return allowedHosts.has(u.hostname);
  } catch {
    return false;
  }
}

async function getUidFromAuthorizationHeader(req) {
  const h = req.headers.authorization || req.headers.Authorization;
  if (!h || typeof h !== "string") return null;
  const m = h.match(/^Bearer\s+(.+)$/i);
  if (!m) return null;
  const idToken = m[1];
  try {
    const decoded = await admin.auth().verifyIdToken(idToken);
    return decoded?.uid || null;
  } catch {
    return null;
  }
}

async function findUserIdByStripeSubscriptionId(subscriptionId) {
  if (!subscriptionId) return null;
  const snap = await db
    .collection("users")
    .where("stripe.subscriptionId", "==", subscriptionId)
    .limit(1)
    .get();
  if (snap.empty) return null;
  return snap.docs[0].id;
}


setGlobalOptions({ region: "us-east1" });

admin.initializeApp();
const db = admin.firestore();

function assertNumber(n, name) {
  if (typeof n !== "number" || Number.isNaN(n) || !Number.isFinite(n)) {
    throw new HttpsError("invalid-argument", `${name} must be a number`);
  }
}

function clamp(n, min, max) {
  return Math.max(min, Math.min(max, n));
}

function distanceKm(aLat, aLng, bLat, bLng) {
  const R = 6371;
  const toRad = (x) => (x * Math.PI) / 180;
  const dLat = toRad(bLat - aLat);
  const dLng = toRad(bLng - aLng);
  const s1 = Math.sin(dLat / 2) ** 2;
  const s2 = Math.cos(toRad(aLat)) * Math.cos(toRad(bLat)) * Math.sin(dLng / 2) ** 2;
  const c = 2 * Math.atan2(Math.sqrt(s1 + s2), Math.sqrt(1 - (s1 + s2)));
  return R * c;
}

function geohashPrecisionForRadius(radiusKm) {
  if (radiusKm <= 0.15) return 7;
  if (radiusKm <= 0.6) return 6;
  if (radiusKm <= 2.4) return 5;
  if (radiusKm <= 20) return 4;
  if (radiusKm <= 78) return 3;
  return 2;
}

/**
 * updateGroupLocation
 * { groupId, lat, lng, accuracy?, heading?, speed?, timestampMs? }
 */
exports.updateGroupLocation = onCall(
  {
    cpu: 0.083,
    memory: "256MiB",
    timeoutSeconds: 30,
    maxInstances: 20,
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Authentication required");
    }

    const data = request.data || {};
    const { groupId, lat, lng } = data;

    if (!groupId || typeof groupId !== "string") {
      throw new HttpsError("invalid-argument", "groupId is required");
    }
    assertNumber(lat, "lat");
    assertNumber(lng, "lng");

    if (lat < -90 || lat > 90) throw new HttpsError("invalid-argument", "lat out of range");
    if (lng < -180 || lng > 180) throw new HttpsError("invalid-argument", "lng out of range");

    // Authorization: only admins or users bound to the same groupId
    const userRef = db.collection("users").doc(request.auth.uid);
    const userSnap = await userRef.get();
    const user = userSnap.exists ? userSnap.data() : null;

    const isAdmin = !!user && (user.isAdmin === true || user.role === "admin");
    const userGroupId = user && typeof user.groupId === "string" ? user.groupId : null;

    if (!isAdmin) {
      if (!userGroupId || userGroupId !== groupId) {
        throw new HttpsError(
          "permission-denied",
          "Not allowed to update this group's location"
        );
      }
    }

    const accuracy = typeof data.accuracy === "number" ? data.accuracy : null;
    const heading = typeof data.heading === "number" ? data.heading : null;
    const speed = typeof data.speed === "number" ? data.speed : null;
    const tsMs = typeof data.timestampMs === "number" ? data.timestampMs : Date.now();
    const geohash = ngeohash.encode(lat, lng, 8);

    const groupRef = db.collection("groups").doc(groupId);

    await groupRef.set(
      {
        lastLocation: {
          lat,
          lng,
          geohash,
          accuracy,
          heading,
          speed,
          timestampMs: tsMs,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
      },
      { merge: true }
    );

    await groupRef.collection("points").add({
      lat,
      lng,
      geohash,
      accuracy,
      heading,
      speed,
      timestampMs: tsMs,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      uid: request.auth.uid,
    });

    return { ok: true };
  }
);

/**
 * nearbySearch
 * { centerLat, centerLng, radiusKm?, limit? }
 */
exports.nearbySearch = onCall(
  {
    cpu: 0.083,
    memory: "256MiB",
    timeoutSeconds: 60,
    maxInstances: 20,
  },
  async (request) => {
    const data = request.data || {};
    const centerLat = data.centerLat;
    const centerLng = data.centerLng;

    assertNumber(centerLat, "centerLat");
    assertNumber(centerLng, "centerLng");

    let radiusKm = typeof data.radiusKm === "number" ? data.radiusKm : 2;
    radiusKm = clamp(radiusKm, 0.1, 50);

    let limit = typeof data.limit === "number" ? Math.floor(data.limit) : 50;
    limit = clamp(limit, 1, 200);

    const precision = geohashPrecisionForRadius(radiusKm);
    const centerHash = ngeohash.encode(centerLat, centerLng, precision);
    const neighbors = ngeohash.neighbors(centerHash);
    const prefixes = [centerHash, ...neighbors];
    const results = new Map();

    for (const prefix of prefixes) {
      const snap = await db
        .collection("groups")
        .orderBy("lastLocation.geohash")
        .startAt(prefix)
        .endAt(prefix + "\uf8ff")
        .limit(limit)
        .get();

      for (const doc of snap.docs) {
        const d = doc.data() || {};
        const loc = d.lastLocation || {};
        const lat = loc.lat;
        const lng = loc.lng;

        if (typeof lat !== "number" || typeof lng !== "number") continue;

        const dist = distanceKm(centerLat, centerLng, lat, lng);
        if (dist <= radiusKm) {
          if (!results.has(doc.id)) {
            results.set(doc.id, {
              id: doc.id,
              distanceKm: dist,
              ...d,
            });
          }
        }
      }
    }

    const arr = Array.from(results.values())
      .sort((a, b) => a.distanceKm - b.distanceKm)
      .slice(0, limit);

    return { ok: true, count: arr.length, items: arr };
  }
);

/**
 * createStorexPaymentIntent (callable)
 * Lit users/{uid}/cart (source de vérité), crée users/{uid}/orders/{orderId}
 * puis renvoie { orderId, clientSecret }.
 */
exports.createStorexPaymentIntent = onCall(
  { region: "us-east1", secrets: [STRIPE_SECRET_KEY] },
  async (req) => {
  const auth = req.auth;
  if (!auth) throw new HttpsError("unauthenticated", "Sign in required");
  const uid = auth.uid;

  const data = req.data || {};
  const currency = String(data.currency || "eur").toLowerCase();
  const shippingCents = Number(data.shippingCents || 0);
  const shippingMethod = String(data.shippingMethod || "flat_rate");
  const shippingAddress = normalizeShippingAddress(data.address);

  // 1) Lire le panier Firestore (source de vérité)
  const cartSnap = await admin
    .firestore()
    .collection("users")
    .doc(uid)
    .collection("cart")
    .get();

  if (cartSnap.empty) throw new HttpsError("failed-precondition", "Cart empty");

  // IMPORTANT: Ne jamais faire confiance aux montants venant de users/{uid}/cart.
  // On recalcule les prix depuis la source de vérité (products).
  const cartDocs = cartSnap.docs.map((d) => ({ id: d.id, data: d.data() || {} }));
  const productIds = cartDocs
    .map((x) => x.data.productId)
    .filter((v) => typeof v === "string" && v.trim().length > 0);
  const productsById = await fetchStorexProductsById(productIds);

  let subtotalCents = 0;
  const items = [];

  for (const doc of cartDocs) {
    const it = doc.data;
    const productId = typeof it.productId === "string" ? it.productId.trim() : "";
    if (!productId) continue;

    const qty = clamp(toSafeInt(it.quantity, 1), 1, 99);
    const product = productsById.get(productId);
    if (!product) {
      throw new HttpsError("failed-precondition", `Product not found: ${productId}`);
    }

    if (product.isActive === false) {
      throw new HttpsError("failed-precondition", `Product inactive: ${productId}`);
    }
    if (looksLikeNonEmptyString(product.moderationStatus) && String(product.moderationStatus).toLowerCase() !== "approved") {
      throw new HttpsError("failed-precondition", `Product not approved: ${productId}`);
    }

    const priceCents = assertPositiveCents(product.priceCents, "product.priceCents");
    subtotalCents += priceCents * qty;

    items.push({
      key: doc.id,
      groupId: it.groupId || "",
      productId,
      title: looksLikeNonEmptyString(product.title) ? product.title : (it.title || ""),
      priceCents,
      quantity: qty,
      sellerId: looksLikeNonEmptyString(product.ownerId)
        ? product.ownerId
        : (looksLikeNonEmptyString(product.ownerUid)
            ? product.ownerUid
            : (looksLikeNonEmptyString(product.sellerId) ? product.sellerId : "")),
      size: it.size || "M",
      color: it.color || "Noir",
      imageUrl: looksLikeNonEmptyString(product.imageUrl) ? product.imageUrl : (it.imageUrl || ""),
      imagePath: product.imagePath || it.imagePath || null,
    });
  }

  if (subtotalCents <= 0) {
    throw new HttpsError("failed-precondition", "Cart total invalid");
  }

  // 2) Valider shipping (whitelist)
  const allowedShipping = new Set([0, 500, 2000]);
  const safeShipping = allowedShipping.has(shippingCents) ? shippingCents : 2000;

  const totalCents = subtotalCents + safeShipping;

  // 3) Créer order
  const orderRef = admin
    .firestore()
    .collection("users")
    .doc(uid)
    .collection("orders")
    .doc();

  const shopId = DEFAULT_STOREX_SHOP_ID;

  // groupId: prend le premier item non vide (sinon string vide)
  const groupId = items.find((x) => (x.groupId || "").trim().length > 0)?.groupId || "";

  // orderNo: générer un numéro de commande lisible (ORD-YYYYMMDD-shortId)
  const now = new Date();
  const datePart = now.toISOString().slice(0, 10).replace(/-/g, "");
  const shortId = orderRef.id.slice(0, 6).toUpperCase();
  const orderNo = `ORD-${datePart}-${shortId}`;

  // itemsCount: nombre total d'items
  const itemsCount = items.length;

  await orderRef.set({
    orderNo,
    itemsCount,
    status: "pending",
    currency: currency.toUpperCase(),
    subtotalCents,
    shippingCents: safeShipping,
    totalCents,
    shippingMethod,
    shippingAddress,
    items,
    paymentMethod: "stripe",
    userId: uid,
    groupId,
    shopId,
    totalPrice: totalCents,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  // 3b) Miroir dans /orders/{orderId} pour l'admin + pages commandes
  // Schéma compatible avec app/lib/models/order_model.dart
  const rootOrderRef = admin.firestore().collection("orders").doc(orderRef.id);

  const sellerIds = uniqueStrings(items.map((it) => it.sellerId));
  await rootOrderRef.set(
    {
      orderNo,
      itemsCount,
      userId: uid,
      buyerId: uid,
      buyerEmail: shippingAddress.email,
      groupId,
      shopId,
      sellerIds,
      shippingAddress,
      items: items.map((it) => ({
        productId: it.productId || "",
        title: it.title || "",
        quantity: Number(it.quantity || 1),
        pricePerUnit: Number(it.priceCents || 0),
        sellerId: it.sellerId || "",
      })),
      totalPrice: totalCents,
      status: "pending",
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      deliveredAt: null,
      storex: {
        currency: currency.toUpperCase(),
        subtotalCents,
        shippingCents: safeShipping,
        totalCents,
        shippingMethod,
      },
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true }
  );

  // 4) PaymentIntent
  const stripeClient = getStripeV20240620();
  const pi = await stripeClient.paymentIntents.create(
    {
      amount: totalCents,
      currency,
      automatic_payment_methods: { enabled: true },
      metadata: { uid, orderId: orderRef.id },
    },
    { idempotencyKey: orderRef.id }
  );

  await orderRef.update({
    stripe: { paymentIntentId: pi.id },
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  await rootOrderRef.set(
    {
      stripe: { paymentIntentId: pi.id },
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true }
  );

  return {
    orderId: orderRef.id,
    clientSecret: pi.client_secret,
  };
  }
);

async function writeInboxMessage({ sellerId, orderId, buyerId, nbItems }) {
  const title = "Nouvelle commande";
  const body = `Une commande est en attente de validation.${nbItems ? ` (${nbItems} article(s))` : ""}`;

  const message = {
    type: "order",
    title,
    body,
    orderId,
    deepLink: deepLinkForOrder(orderId),
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    read: false,
    actionLabel: "Consulter la commande",
    meta: {
      buyerId: buyerId || "",
    },
  };

  await admin
    .firestore()
    .collection("users")
    .doc(sellerId)
    .collection("inbox")
    .add(message);
}

async function getFcmTokensForUser(uid) {
  const tokens = [];

  // Preferred storage: users/{uid}/devices/{deviceId}
  try {
    const snap = await admin.firestore().collection("users").doc(uid).collection("devices").get();
    snap.forEach((d) => {
      const t = d.get("token");
      if (typeof t === "string" && t.length > 10) tokens.push(t);
    });
  } catch (_) {}

  // Back-compat: users/{uid}.fcmTokens (array)
  if (tokens.length === 0) {
    try {
      const userSnap = await admin.firestore().collection("users").doc(uid).get();
      const data = userSnap.exists ? (userSnap.data() || {}) : {};
      const arr = Array.isArray(data.fcmTokens) ? data.fcmTokens : [];
      for (const t of arr) {
        if (typeof t === "string" && t.length > 10) tokens.push(t);
      }
    } catch (_) {}
  }

  return uniqueStrings(tokens);
}

async function cleanupInvalidTokens(uid, invalidTokensSet) {
  if (!invalidTokensSet || invalidTokensSet.size === 0) return;

  // Remove from devices collection
  try {
    const devicesSnap = await admin.firestore().collection("users").doc(uid).collection("devices").get();
    const batch = admin.firestore().batch();
    devicesSnap.forEach((doc) => {
      const token = doc.get("token");
      if (typeof token === "string" && invalidTokensSet.has(token)) {
        batch.delete(doc.ref);
      }
      // Also support token-as-docId
      if (invalidTokensSet.has(doc.id)) {
        batch.delete(doc.ref);
      }
    });
    await batch.commit();
  } catch (_) {}

  // Remove from legacy user doc array
  try {
    await admin.firestore().collection("users").doc(uid).set(
      {
        fcmTokens: admin.firestore.FieldValue.arrayRemove(Array.from(invalidTokensSet)),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
  } catch (_) {}
}

async function sendPushToSeller({ sellerId, orderId, nbItems }) {
  const tokens = await getFcmTokensForUser(sellerId);
  if (!tokens.length) {
    logger.info(`No FCM tokens for seller ${sellerId}`);
    return;
  }

  const title = "Nouvelle commande";
  const body = `Commande à valider${nbItems ? ` (${nbItems} article(s))` : ""}`;

  const message = {
    tokens,
    notification: { title, body },
    data: {
      type: "order",
      orderId,
      deepLink: deepLinkForOrder(orderId),
    },
    android: {
      priority: "high",
      notification: {
        channelId: "orders",
      },
    },
    apns: {
      payload: {
        aps: {
          sound: "default",
        },
      },
    },
  };

  const resp = await admin.messaging().sendEachForMulticast(message);

  const invalid = new Set();
  resp.responses.forEach((r, idx) => {
    if (!r.success) {
      const code = (r.error && r.error.code) ? r.error.code : "";
      if (
        String(code).includes("registration-token-not-registered") ||
        String(code).includes("invalid-registration-token") ||
        String(code).includes("messaging/invalid-argument") ||
        String(code).includes("messaging/registration-token-not-registered")
      ) {
        invalid.add(tokens[idx]);
      }
      logger.warn(`Push failed seller=${sellerId} tokenIndex=${idx} code=${code}`, r.error);
    }
  });

  await cleanupInvalidTokens(sellerId, invalid);
}

// Inbox vendeur + Push sur création de commande root (/orders/{orderId})
exports.notifySellersOnOrderCreate = onDocumentCreated(
  {
    document: "orders/{orderId}",
    region: "us-east1",
  },
  async (event) => {
    const orderId = event.params.orderId;
    const snap = event.data;
    if (!snap) return;

    const order = snap.data() || {};
    const items = Array.isArray(order.items) ? order.items : [];
    const sellerIdsFromItems = items
      .map((it) => (it && typeof it.sellerId === "string" ? it.sellerId : ""))
      .filter(Boolean);
    const sellerIds = uniqueStrings([...(Array.isArray(order.sellerIds) ? order.sellerIds : []), ...sellerIdsFromItems]);

    // ✅ Garantit sellerIds unique dans la commande (utile pour rules/isSellerOfOrder)
    try {
      const stored = Array.isArray(order.sellerIds) ? uniqueStrings(order.sellerIds) : [];
      const storedKey = JSON.stringify([...stored].sort());
      const desiredKey = JSON.stringify([...sellerIds].sort());

      const patch = {};
      if (storedKey !== desiredKey) patch.sellerIds = sellerIds;
      if (typeof order.buyerId !== "string" || order.buyerId.trim().length === 0) {
        if (typeof order.userId === "string" && order.userId.trim().length > 0) {
          patch.buyerId = order.userId.trim();
        }
      }

      if (Object.keys(patch).length) {
        await db.collection("orders").doc(orderId).set(
          {
            ...patch,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          },
          { merge: true }
        );
      }
    } catch (e) {
      logger.warn(`Failed to normalize sellerIds for order ${orderId}`, e);
    }

    if (!sellerIds.length) {
      logger.warn(`Order ${orderId} has no sellers`);
      return;
    }

    const nbItems = items.length;
    const buyerId = typeof order.buyerId === "string" ? order.buyerId : (typeof order.userId === "string" ? order.userId : "");

    await Promise.all(
      sellerIds.map(async (sellerId) => {
        await writeInboxMessage({ sellerId, orderId, buyerId, nbItems });
        await sendPushToSeller({ sellerId, orderId, nbItems });
      })
    );

    logger.info(`Notified sellers for order ${orderId}`, { sellerIds });
  }
);

async function sendPendingProductNotification({ groupId, productId, product }) {
  // Récupérer les tokens des admins master
  const [isAdminSnap, roleAdminSnap] = await Promise.all([
    db.collection("users").where("isAdmin", "==", true).get(),
    db.collection("users").where("role", "==", "admin").get(),
  ]);

  const tokens = new Set();
  for (const doc of [...isAdminSnap.docs, ...roleAdminSnap.docs]) {
    const d = doc.data() || {};
    const arr = Array.isArray(d.fcmTokens) ? d.fcmTokens : [];
    for (const t of arr) {
      if (typeof t === "string" && t.trim().length > 0) tokens.add(t.trim());
    }
  }

  const tokenList = Array.from(tokens);
  if (tokenList.length === 0) return;

  const title = "Nouvel article à valider";
  const body = (product.title
    ? `${product.title}`
    : "Un article est en attente de validation"
  ).toString();

  // Envoi en lots (FCM max 500 tokens par requête)
  const chunkSize = 500;
  for (let i = 0; i < tokenList.length; i += chunkSize) {
    const chunk = tokenList.slice(i, i + chunkSize);
    await admin.messaging().sendEachForMulticast({
      tokens: chunk,
      notification: { title, body },
      data: {
        type: "pending_product",
        groupId,
        productId,
      },
    });
  }
}

/**
 * notifyPendingProductCreated
 * Déclenchée quand un admin groupe crée un produit en attente.
 * Notifie tous les admins master (users/{uid}.isAdmin == true OU role == 'admin').
 */
exports.notifyPendingProductCreated = onDocumentCreated(
  {
    document: "groups/{groupId}/products/{productId}",
    cpu: 0.083,
    memory: "256MiB",
    timeoutSeconds: 30,
    maxInstances: 2,
  },
  async (event) => {
    const snap = event.data;
    if (!snap) return;

    const product = snap.data() || {};
    const status = (product.moderationStatus || "").toString();
    const isActive = product.isActive === true;

    // On ne notifie que les créations en attente.
    if (status !== "pending" || isActive) return;

    const groupId = event.params.groupId;
    const productId = event.params.productId;

    await sendPendingProductNotification({ groupId, productId, product });
  }
);

/**
 * notifyPendingProductResubmitted
 * Déclenchée quand un produit passe à nouveau en pending (ex: correction après refus).
 */
exports.notifyPendingProductResubmitted = onDocumentUpdated(
  {
    document: "groups/{groupId}/products/{productId}",
    cpu: 0.083,
    memory: "256MiB",
    timeoutSeconds: 30,
    maxInstances: 2,
  },
  async (event) => {
    const before = event.data?.before;
    const after = event.data?.after;
    if (!before || !after) return;

    const prev = before.data() || {};
    const next = after.data() || {};

    const prevStatus = (prev.moderationStatus || "").toString();
    const nextStatus = (next.moderationStatus || "").toString();
    const nextActive = next.isActive === true;

    if (prevStatus === "pending") return;
    if (nextStatus !== "pending" || nextActive) return;

    const groupId = event.params.groupId;
    const productId = event.params.productId;

    await sendPendingProductNotification({
      groupId,
      productId,
      product: next,
    });
  }
);

// ========== GESTION DES RÔLES ET PERMISSIONS ==========

/**
 * Définitions des rôles par défaut
 */
const defaultRoles = [
  {
    id: "user",
    name: "Utilisateur",
    description: "Utilisateur standard avec permissions de base",
    roleType: "user",
    priority: 10,
    permissions: [
      "readPublicContent",
      "createAccount",
      "updateOwnProfile",
      "createOrder",
      "viewOwnOrders",
      "manageCart",
      "manageFavorites",
      "followGroups",
    ],
    isActive: true,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  },
  {
    id: "tracker",
    name: "Traceur",
    description: "Utilisateur avec permissions de suivi de localisation",
    roleType: "tracker",
    priority: 20,
    permissions: [
      "readPublicContent",
      "createAccount",
      "updateOwnProfile",
      "createOrder",
      "viewOwnOrders",
      "manageCart",
      "manageFavorites",
      "followGroups",
      "updateLocation",
      "viewTracking",
    ],
    isActive: true,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  },
  {
    id: "group",
    name: "Administrateur de groupe",
    description: "Gestion complète d'un groupe spécifique",
    roleType: "group",
    priority: 50,
    permissions: [
      "readPublicContent",
      "createAccount",
      "updateOwnProfile",
      "createOrder",
      "viewOwnOrders",
      "manageCart",
      "manageFavorites",
      "followGroups",
      "manageGroupInfo",
      "manageGroupProducts",
      "viewGroupOrders",
      "viewGroupStats",
      "manageGroupMembers",
    ],
    isActive: true,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  },
  {
    id: "admin",
    name: "Administrateur",
    description: "Administrateur avec accès complet au système",
    roleType: "admin",
    priority: 90,
    permissions: [
      "readPublicContent",
      "createAccount",
      "updateOwnProfile",
      "createOrder",
      "viewOwnOrders",
      "manageCart",
      "manageFavorites",
      "followGroups",
      "manageAllGroups",
      "manageAllUsers",
      "manageAllProducts",
      "manageAllOrders",
      "managePlaces",
      "managePOIs",
      "manageCircuits",
      "viewAllStats",
      "moderateContent",
    ],
    isActive: true,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  },
  {
    id: "superAdmin",
    name: "Super Administrateur",
    description: "Tous les droits sur le système",
    roleType: "superAdmin",
    priority: 100,
    permissions: [
      "readPublicContent",
      "createAccount",
      "updateOwnProfile",
      "createOrder",
      "viewOwnOrders",
      "manageCart",
      "manageFavorites",
      "followGroups",
      "updateLocation",
      "viewTracking",
      "manageGroupInfo",
      "manageGroupProducts",
      "viewGroupOrders",
      "viewGroupStats",
      "manageGroupMembers",
      "manageAllGroups",
      "manageAllUsers",
      "manageAllProducts",
      "manageAllOrders",
      "managePlaces",
      "managePOIs",
      "manageCircuits",
      "viewAllStats",
      "moderateContent",
      "manageRoles",
      "managePermissions",
      "accessAdminPanel",
      "deleteAnyContent",
    ],
    isActive: true,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  },
];

/**
 * Cloud Function pour initialiser les rôles dans Firestore
 * Callable uniquement par un super admin
 */
exports.initializeRoles = onCall({ region: "us-east1" }, async (request) => {
  const uid = request.auth?.uid;

  if (!uid) {
    throw new HttpsError("unauthenticated", "Utilisateur non authentifié");
  }

  // Vérifier que l'utilisateur est super admin
  const userDoc = await db.collection("users").doc(uid).get();
  if (!userDoc.exists) {
    throw new HttpsError("permission-denied", "Profil utilisateur introuvable");
  }

  const userData = userDoc.data();
  const userRole = userData.role || "user";

  // Seul un superAdmin peut initialiser les rôles
  if (userRole !== "superAdmin" && !userData.isAdmin) {
    throw new HttpsError(
      "permission-denied",
      "Seul un super administrateur peut initialiser les rôles"
    );
  }

  // Créer ou mettre à jour les rôles par défaut
  const batch = db.batch();
  let created = 0;
  let updated = 0;

  for (const role of defaultRoles) {
    const roleRef = db.collection("roles").doc(role.id);
    const roleDoc = await roleRef.get();

    if (roleDoc.exists) {
      // Mettre à jour en préservant certaines données existantes
      batch.set(roleRef, role, { merge: true });
      updated++;
    } else {
      // Créer nouveau rôle
      batch.set(roleRef, role);
      created++;
    }
  }

  await batch.commit();

  return {
    success: true,
    message: `Rôles initialisés avec succès`,
    stats: {
      created,
      updated,
      total: defaultRoles.length,
    },
  };
});

/**
 * Cloud Function pour assigner un rôle à un utilisateur
 * Callable par admin ou super admin
 */
exports.assignUserRole = onCall({ region: "us-east1" }, async (request) => {
  const uid = request.auth?.uid;
  const { targetUserId, role, groupId } = request.data || {};

  if (!uid) {
    throw new HttpsError("unauthenticated", "Utilisateur non authentifié");
  }

  if (!targetUserId || !role) {
    throw new HttpsError(
      "invalid-argument",
      "targetUserId et role sont requis"
    );
  }

  // Vérifier que l'utilisateur a les permissions
  const callerDoc = await db.collection("users").doc(uid).get();
  if (!callerDoc.exists) {
    throw new HttpsError("permission-denied", "Profil utilisateur introuvable");
  }

  const callerData = callerDoc.data();
  const callerRole = callerData.role || "user";

  // Seuls admin et superAdmin peuvent assigner des rôles
  if (!["admin", "superAdmin"].includes(callerRole) && !callerData.isAdmin) {
    throw new HttpsError(
      "permission-denied",
      "Permissions insuffisantes pour assigner des rôles"
    );
  }

  // Vérifier que le rôle cible existe
  const roleDoc = await db.collection("roles").doc(role).get();
  if (!roleDoc.exists) {
    throw new HttpsError("not-found", `Le rôle '${role}' n'existe pas`);
  }

  // Vérifier que l'utilisateur cible existe
  const targetDoc = await db.collection("users").doc(targetUserId).get();
  if (!targetDoc.exists) {
    throw new HttpsError(
      "not-found",
      `L'utilisateur ${targetUserId} n'existe pas`
    );
  }

  const updates = {
    role,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };

  // Si c'est un rôle groupe, le groupId est requis
  if (role === "group") {
    if (!groupId) {
      throw new HttpsError(
        "invalid-argument",
        "groupId est requis pour le rôle groupe"
      );
    }
    updates.groupId = groupId;
  } else {
    updates.groupId = null;
  }

  // Mettre à jour isAdmin pour la rétrocompatibilité
  updates.isAdmin = ["admin", "superAdmin"].includes(role);

  await db.collection("users").doc(targetUserId).update(updates);

  return {
    success: true,
    message: `Rôle '${role}' assigné à l'utilisateur ${targetUserId}`,
    userId: targetUserId,
    role,
    groupId: groupId || null,
  };
});

// ========== GESTION DES CATÉGORIES D'UTILISATEURS ==========

/**
 * Définitions des catégories par défaut
 */
const defaultUserCategories = [
  {
    id: "pilote",
    name: "Pilote",
    description: "Pilote de moto participant aux événements",
    categoryType: "pilote",
    priority: 10,
    requiresApproval: false,
    badgeColor: "#FF6B00",
    iconName: "sports_motorsports",
    benefits: [
      {
        id: "parking_prioritaire",
        title: "Parking prioritaire",
        description: "Accès aux zones de parking réservées aux pilotes",
        iconName: "local_parking",
      },
      {
        id: "acces_paddock",
        title: "Accès paddock",
        description: "Accès aux zones techniques et paddock",
        iconName: "garage",
      },
    ],
    isActive: true,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  },
  {
    id: "passager",
    name: "Passager",
    description: "Passager accompagnant un pilote",
    categoryType: "passager",
    priority: 20,
    requiresApproval: false,
    badgeColor: "#4CAF50",
    iconName: "airline_seat_recline_normal",
    benefits: [
      {
        id: "accompagnement",
        title: "Accompagnement pilote",
        description: "Peut accompagner un pilote lors des événements",
        iconName: "group",
      },
    ],
    isActive: true,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  },
  {
    id: "organisateur",
    name: "Organisateur",
    description: "Organisateur d'événements et circuits",
    categoryType: "organisateur",
    priority: 30,
    requiresApproval: true,
    badgeColor: "#9C27B0",
    iconName: "event_note",
    benefits: [
      {
        id: "gestion_evenements",
        title: "Gestion événements",
        description: "Peut créer et gérer des événements",
        iconName: "edit_calendar",
      },
      {
        id: "stats_avancees",
        title: "Statistiques avancées",
        description: "Accès aux statistiques détaillées des événements",
        iconName: "analytics",
      },
    ],
    isActive: true,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  },
  {
    id: "comercant",
    name: "Commerçant",
    description: "Commerçant ou vendeur sur les événements",
    categoryType: "comercant",
    priority: 40,
    requiresApproval: true,
    badgeColor: "#2196F3",
    iconName: "store",
    benefits: [
      {
        id: "stand_commerce",
        title: "Stand commercial",
        description: "Peut installer un stand lors des événements",
        iconName: "storefront",
      },
      {
        id: "visibilite",
        title: "Visibilité augmentée",
        description: "Profil mis en avant dans la section commerce",
        iconName: "trending_up",
      },
    ],
    isActive: true,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  },
  {
    id: "secours",
    name: "Secours",
    description: "Personnel de secours et sécurité",
    categoryType: "secours",
    priority: 50,
    requiresApproval: true,
    badgeColor: "#F44336",
    iconName: "local_hospital",
    benefits: [
      {
        id: "acces_total",
        title: "Accès total",
        description: "Accès à toutes les zones pour interventions",
        iconName: "vpn_key",
      },
      {
        id: "communication_prioritaire",
        title: "Communication prioritaire",
        description: "Accès aux canaux de communication prioritaires",
        iconName: "priority_high",
      },
    ],
    isActive: true,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  },
  {
    id: "vip",
    name: "VIP",
    description: "Invité VIP ou partenaire privilégié",
    categoryType: "vip",
    priority: 60,
    requiresApproval: true,
    badgeColor: "#FFD700",
    iconName: "star",
    benefits: [
      {
        id: "acces_exclusif",
        title: "Accès exclusif",
        description: "Accès aux zones VIP et espaces privés",
        iconName: "workspace_premium",
      },
      {
        id: "services_premium",
        title: "Services premium",
        description: "Services et avantages premium",
        iconName: "diamond",
      },
    ],
    isActive: true,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  },
  {
    id: "media",
    name: "Média",
    description: "Presse et médias accrédités",
    categoryType: "media",
    priority: 70,
    requiresApproval: true,
    badgeColor: "#607D8B",
    iconName: "photo_camera",
    benefits: [
      {
        id: "acces_media",
        title: "Accès média",
        description: "Accès aux zones réservées à la presse",
        iconName: "badge",
      },
      {
        id: "ressources_presse",
        title: "Ressources presse",
        description: "Accès aux communiqués et ressources médias",
        iconName: "article",
      },
    ],
    isActive: true,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  },
  {
    id: "benevole",
    name: "Bénévole",
    description: "Bénévole aidant à l'organisation",
    categoryType: "benevole",
    priority: 80,
    requiresApproval: true,
    badgeColor: "#00BCD4",
    iconName: "volunteer_activism",
    benefits: [
      {
        id: "participation_orga",
        title: "Participation organisation",
        description: "Peut aider à l'organisation des événements",
        iconName: "handshake",
      },
      {
        id: "recompenses",
        title: "Récompenses",
        description: "Points et récompenses pour l'aide apportée",
        iconName: "card_giftcard",
      },
    ],
    isActive: true,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  },
  {
    id: "spectateur",
    name: "Spectateur",
    description: "Spectateur des événements",
    categoryType: "spectateur",
    priority: 90,
    requiresApproval: false,
    badgeColor: "#9E9E9E",
    iconName: "visibility",
    benefits: [
      {
        id: "acces_public",
        title: "Accès zones publiques",
        description: "Accès aux zones publiques des événements",
        iconName: "public",
      },
    ],
    isActive: true,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  },
];

/**
 * Cloud Function pour initialiser les catégories d'utilisateurs dans Firestore
 * Callable uniquement par un admin ou super admin
 */
exports.initializeUserCategories = onCall(
  {
    region: "us-east1",
    cpu: 0.083,
    memory: "256MiB",
    timeoutSeconds: 60,
    maxInstances: 2,
  },
  async (request) => {
    const uid = request.auth?.uid;

    if (!uid) {
      throw new HttpsError("unauthenticated", "Utilisateur non authentifié");
    }

    // Vérifier que l'utilisateur est admin ou super admin
    const userDoc = await db.collection("users").doc(uid).get();
    if (!userDoc.exists) {
      throw new HttpsError(
        "permission-denied",
        "Profil utilisateur introuvable"
      );
    }

    const userData = userDoc.data();
    const userRole = userData.role || "user";

    // Seul un admin ou superAdmin peut initialiser les catégories
    if (!["admin", "superAdmin"].includes(userRole) && !userData.isAdmin) {
      throw new HttpsError(
        "permission-denied",
        "Seul un administrateur peut initialiser les catégories"
      );
    }

    // Créer ou mettre à jour les catégories par défaut
    const batch = db.batch();
    let created = 0;
    let updated = 0;

    for (const category of defaultUserCategories) {
      const categoryRef = db.collection("userCategories").doc(category.id);
      const categoryDoc = await categoryRef.get();

      if (categoryDoc.exists) {
        // Mettre à jour en préservant certaines données existantes
        batch.set(categoryRef, category, { merge: true });
        updated++;
      } else {
        // Créer nouvelle catégorie
        batch.set(categoryRef, category);
        created++;
      }
    }

    await batch.commit();

    return {
      success: true,
      message: `Catégories d'utilisateurs initialisées avec succès`,
      stats: {
        created,
        updated,
        total: defaultUserCategories.length,
      },
    };
  }
);

/**
 * Cloud Function pour assigner une catégorie à un utilisateur
 * Callable par l'utilisateur lui-même (si auto-assignable) ou par un admin
 */
exports.assignUserCategory = onCall(
  {
    region: "us-east1",
    cpu: 0.083,
    memory: "256MiB",
    timeoutSeconds: 60,
    maxInstances: 2,
  },
  async (request) => {
    const uid = request.auth?.uid;
    const {
      targetUserId,
      categoryId,
      expiresAt,
      verificationProof,
    } = request.data || {};

    if (!uid) {
      throw new HttpsError("unauthenticated", "Utilisateur non authentifié");
    }

    if (!targetUserId || !categoryId) {
      throw new HttpsError(
        "invalid-argument",
        "targetUserId et categoryId sont requis"
      );
    }

    // Vérifier que la catégorie existe
    const categoryDoc = await db
      .collection("userCategories")
      .doc(categoryId)
      .get();
    if (!categoryDoc.exists) {
      throw new HttpsError(
        "not-found",
        `La catégorie '${categoryId}' n'existe pas`
      );
    }

    const categoryData = categoryDoc.data();

    // Vérifier les permissions
    const callerDoc = await db.collection("users").doc(uid).get();
    if (!callerDoc.exists) {
      throw new HttpsError(
        "permission-denied",
        "Profil utilisateur introuvable"
      );
    }

    const callerData = callerDoc.data();
    const callerRole = callerData.role || "user";
    const isAdmin =
      ["admin", "superAdmin"].includes(callerRole) || callerData.isAdmin;
    const isSelfAssignment = uid === targetUserId;

    // Vérifier les droits d'assignation
    if (!isAdmin && isSelfAssignment && categoryData.requiresApproval) {
      throw new HttpsError(
        "permission-denied",
        "Cette catégorie nécessite une approbation administrative"
      );
    }

    if (!isAdmin && !isSelfAssignment) {
      throw new HttpsError(
        "permission-denied",
        "Vous ne pouvez pas assigner une catégorie à un autre utilisateur"
      );
    }

    // Vérifier que l'utilisateur cible existe
    const targetDoc = await db.collection("users").doc(targetUserId).get();
    if (!targetDoc.exists) {
      throw new HttpsError(
        "not-found",
        `L'utilisateur ${targetUserId} n'existe pas`
      );
    }

    // Créer l'assignation
    const assignment = {
      userId: targetUserId,
      categoryId,
      categoryType: categoryData.categoryType,
      assignedAt: admin.firestore.FieldValue.serverTimestamp(),
      assignedBy: isAdmin ? uid : null,
      isActive: true,
    };

    if (expiresAt) {
      assignment.expiresAt = admin.firestore.Timestamp.fromDate(
        new Date(expiresAt)
      );
    }

    if (verificationProof) {
      assignment.verificationProof = verificationProof;
    }

    // Ajouter à la sous-collection de l'utilisateur
    const assignmentRef = db
      .collection("users")
      .doc(targetUserId)
      .collection("categories")
      .doc(categoryId);

    await assignmentRef.set(assignment);

    return {
      success: true,
      message: `Catégorie '${categoryData.name}' assignée à l'utilisateur ${targetUserId}`,
      userId: targetUserId,
      categoryId,
      categoryName: categoryData.name,
    };
  }
);

/**
 * Cloud Function pour révoquer une catégorie d'un utilisateur
 * Callable uniquement par un admin
 */
exports.revokeUserCategory = onCall(
  {
    region: "us-east1",
    cpu: 0.083,
    memory: "256MiB",
    timeoutSeconds: 60,
    maxInstances: 2,
  },
  async (request) => {
    const uid = request.auth?.uid;
    const { targetUserId, categoryId } = request.data || {};

    if (!uid) {
      throw new HttpsError("unauthenticated", "Utilisateur non authentifié");
    }

    if (!targetUserId || !categoryId) {
      throw new HttpsError(
        "invalid-argument",
        "targetUserId et categoryId sont requis"
      );
    }

    // Vérifier que l'appelant est admin
    const callerDoc = await db.collection("users").doc(uid).get();
    if (!callerDoc.exists) {
      throw new HttpsError(
        "permission-denied",
        "Profil utilisateur introuvable"
      );
    }

    const callerData = callerDoc.data();
    const callerRole = callerData.role || "user";

    if (!["admin", "superAdmin"].includes(callerRole) && !callerData.isAdmin) {
      throw new HttpsError(
        "permission-denied",
        "Seul un administrateur peut révoquer des catégories"
      );
    }

    // Supprimer l'assignation
    const assignmentRef = db
      .collection("users")
      .doc(targetUserId)
      .collection("categories")
      .doc(categoryId);

    const assignmentDoc = await assignmentRef.get();
    if (!assignmentDoc.exists) {
      throw new HttpsError(
        "not-found",
        "Cette catégorie n'est pas assignée à cet utilisateur"
      );
    }

    await assignmentRef.delete();

    return {
      success: true,
      message: `Catégorie révoquée pour l'utilisateur ${targetUserId}`,
      userId: targetUserId,
      categoryId,
    };
  }
);

/**
 * createCheckoutSessionForOrder
 * Crée une Stripe Checkout Session pour une commande en attente
 * { orderId: string }
 * Returns: { checkoutUrl: string }
 */
exports.createCheckoutSessionForOrder = onCall(
  {
    region: "us-east1",
    cpu: 0.083,
    memory: "256MiB",
    timeoutSeconds: 30,
    secrets: [STRIPE_SECRET_KEY],
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Authentication required");
    }

    const { orderId } = request.data || {};
    const uid = request.auth.uid;

    if (!orderId || typeof orderId !== "string") {
      throw new HttpsError("invalid-argument", "orderId is required");
    }

    // 1. Récupère la commande depuis Firestore
    const orderRef = db.collection("users").doc(uid).collection("orders").doc(orderId);
    const orderSnap = await orderRef.get();

    if (!orderSnap.exists) {
      throw new HttpsError("not-found", `Order ${orderId} not found`);
    }

    const orderData = orderSnap.data();

    // Idempotence: si une session existe déjà sur la commande, la réutiliser.
    if (orderData?.stripeSessionUrl && typeof orderData.stripeSessionUrl === "string") {
      return { checkoutUrl: orderData.stripeSessionUrl };
    }

    if (orderData.status !== "pending") {
      throw new HttpsError(
        "failed-precondition",
        `Order ${orderId} is not in pending status (current: ${orderData.status})`
      );
    }

    // IMPORTANT: Ne jamais faire confiance aux montants venant de users/{uid}/orders.
    // On recalcule les prix depuis la source de vérité (photos).

    // 2. Prépare les line_items pour Stripe
    const items = orderData.items || [];
    if (items.length === 0) {
      throw new HttpsError("invalid-argument", "Order has no items");
    }

    // Recalcul prix photo depuis /photos
    const photoIds = items
      .map((it) => it.photoId)
      .filter((v) => typeof v === "string" && v.trim().length > 0);
    const photosById = await fetchPhotosById(photoIds);

    const validatedItems = items.map((item) => {
      const photoId = typeof item.photoId === "string" ? item.photoId.trim() : "";
      if (!photoId) {
        throw new HttpsError("failed-precondition", "Missing photoId in order item");
      }

      const photo = photosById.get(photoId);
      if (!photo) {
        throw new HttpsError("failed-precondition", `Photo not found: ${photoId}`);
      }
      if (photo.isActive === false) {
        throw new HttpsError("failed-precondition", `Photo inactive: ${photoId}`);
      }
      if (looksLikeNonEmptyString(photo.moderationStatus) && String(photo.moderationStatus).toLowerCase() !== "approved") {
        throw new HttpsError("failed-precondition", `Photo not approved: ${photoId}`);
      }

      const priceCents = assertPositiveCents(photo.priceCents, "photo.priceCents");
      return {
        ...item,
        priceCents,
        eventName: looksLikeNonEmptyString(photo.eventName) ? photo.eventName : (item.eventName || ""),
        groupName: looksLikeNonEmptyString(photo.groupName) ? photo.groupName : (item.groupName || ""),
        photographerName: looksLikeNonEmptyString(photo.photographerName) ? photo.photographerName : (item.photographerName || ""),
      };
    });

    // Discount venant du client: on ne l'applique pas sans une politique côté serveur.
    const discountCents = 0;

    const lineItems = validatedItems.map((item) => ({
      price_data: {
        currency: "eur",
        product_data: {
          name: `Photo - ${item.eventName || "Événement"}`,
          description: `${item.groupName || "Groupe"} • ${item.photographerName || "Photographe"}`,
          metadata: {
            photoId: item.photoId,
            eventName: item.eventName || "",
            groupName: item.groupName || "",
          },
        },
        unit_amount: item.priceCents, // Prix en centimes
      },
      quantity: 1,
    }));

    // 3. Crée une Checkout Session Stripe
    try {
      const stripeClient = getStripe();
      const session = await stripeClient.checkout.sessions.create(
        {
        mode: "payment",
        line_items: lineItems,
        success_url: `https://maslive.web.app/success?orderId=${orderId}`,
        cancel_url: `https://maslive.web.app/cancel?orderId=${orderId}`,
        metadata: {
          orderId,
          userId: uid,
          itemCount: validatedItems.length,
          totalCents: validatedItems.reduce((sum, it) => sum + toSafeInt(it.priceCents, 0), 0) - discountCents,
        },
        customer_email: request.auth.token.email || undefined,
        },
        { idempotencyKey: `users_${uid}_order_${orderId}` }
      );

      // 4. Sauvegarde le sessionId dans la commande
      await orderRef.update({
        stripeSessionId: session.id,
        stripeSessionUrl: session.url,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      return { checkoutUrl: session.url };
    } catch (error) {
      console.error("Stripe error:", error);
      throw new HttpsError(
        "internal",
        `Failed to create checkout session: ${error.message}`
      );
    }
  }
);

/**
 * createCheckoutSession (HTTP)
 * Achat unique (photos/articles) via Stripe Checkout.
 * Body: { orderId, successUrl, cancelUrl }
 * - Lit /orders/{orderId}
 * - items attendus: [{ priceId: "price_...", qty?: number }]
 * Returns: { url, sessionId }
 */
exports.createCheckoutSession = onRequest(
  {
    region: "us-east1",
    cpu: 0.083,
    memory: "256MiB",
    timeoutSeconds: 30,
    secrets: [STRIPE_SECRET_KEY],
  },
  async (req, res) => {
    try {
      // CORS minimal (si appelé depuis web/mobile)
      res.set("Access-Control-Allow-Origin", "*");
      res.set("Access-Control-Allow-Methods", "POST, OPTIONS");
      res.set("Access-Control-Allow-Headers", "Content-Type, Authorization");
      if (req.method === "OPTIONS") return res.status(204).send("");

      if (req.method !== "POST") {
        return res.status(405).json({ error: "POST only" });
      }

      const uid = await getUidFromAuthorizationHeader(req);
      if (!uid) {
        return res.status(401).json({ error: "Unauthorized" });
      }

      const { orderId, successUrl, cancelUrl } = req.body || {};

      if (!orderId || typeof orderId !== "string") {
        return res.status(400).json({ error: "orderId required" });
      }
      if (!isAllowedRedirectUrl(successUrl) || !isAllowedRedirectUrl(cancelUrl)) {
        return res
          .status(400)
          .json({ error: "successUrl & cancelUrl required (https)" });
      }

      const orderRef = db.collection("orders").doc(orderId);
      const orderSnap = await orderRef.get();
      if (!orderSnap.exists) {
        return res.status(404).json({ error: "order not found" });
      }

      const order = orderSnap.data() || {};

      // Ownership check: l'utilisateur ne peut créer une session que pour sa commande.
      const orderUid = typeof order.uid === "string" ? order.uid : (typeof order.userId === "string" ? order.userId : "");
      if (!orderUid || orderUid !== uid) {
        return res.status(403).json({ error: "Forbidden" });
      }

      const status = (order.status || "pending").toString();
      if (status !== "pending") {
        return res.status(409).json({ error: `order status is ${status}` });
      }

      const items = Array.isArray(order.items) ? order.items : [];
      const line_items = items
        .map((it) => {
          const priceId = it.priceId;
          const qty = Number(it.qty || 1);
          if (!priceId || typeof priceId !== "string") return null;
          if (!Number.isFinite(qty) || qty <= 0) return null;
          return { price: priceId, quantity: Math.floor(qty) };
        })
        .filter(Boolean);

      if (!line_items.length) {
        return res.status(400).json({ error: "order has no items (priceId missing)" });
      }

      const stripeClient = getStripe();
      const session = await stripeClient.checkout.sessions.create(
        {
          mode: "payment",
          line_items,
          success_url: `${successUrl}?session_id={CHECKOUT_SESSION_ID}`,
          cancel_url: cancelUrl,
          metadata: {
            orderId,
            uid,
            kind: "one_time",
          },
          client_reference_id: orderId,
        },
        { idempotencyKey: `order_${orderId}` }
      );

      await orderRef.set(
        {
          stripe: {
            sessionId: session.id,
            sessionUrl: session.url || null,
            paymentIntentId: session.payment_intent || null,
          },
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );

      return res.json({ url: session.url, sessionId: session.id });
    } catch (e) {
      console.error("createCheckoutSession error", e);
      return res.status(500).json({ error: String(e?.message || e) });
    }
  }
);

/**
 * createSubscriptionCheckoutSession (HTTP)
 * Abonnement via Stripe Checkout.
 * Body: { priceId, successUrl, cancelUrl }
 * Auth: Authorization: Bearer <Firebase ID token>
 * Returns: { url, sessionId }
 */
exports.createSubscriptionCheckoutSession = onRequest(
  {
    region: "us-east1",
    cpu: 0.083,
    memory: "256MiB",
    timeoutSeconds: 30,
    secrets: [STRIPE_SECRET_KEY],
  },
  async (req, res) => {
    try {
      res.set("Access-Control-Allow-Origin", "*");
      res.set("Access-Control-Allow-Methods", "POST, OPTIONS");
      res.set("Access-Control-Allow-Headers", "Content-Type, Authorization");
      if (req.method === "OPTIONS") return res.status(204).send("");

      if (req.method !== "POST") {
        return res.status(405).json({ error: "POST only" });
      }

      const uid = await getUidFromAuthorizationHeader(req);
      if (!uid) {
        return res.status(401).json({ error: "Unauthorized" });
      }

      const { priceId, successUrl, cancelUrl } = req.body || {};

      if (!priceId || typeof priceId !== "string" || !priceId.startsWith("price_")) {
        return res.status(400).json({ error: "priceId required" });
      }
      if (!isAllowedRedirectUrl(successUrl) || !isAllowedRedirectUrl(cancelUrl)) {
        return res
          .status(400)
          .json({ error: "successUrl & cancelUrl required (https)" });
      }

      const stripeClient = getStripe();
      const session = await stripeClient.checkout.sessions.create(
        {
          mode: "subscription",
          line_items: [{ price: priceId, quantity: 1 }],
          success_url: `${successUrl}?session_id={CHECKOUT_SESSION_ID}`,
          cancel_url: cancelUrl,
          metadata: { uid, kind: "subscription" },
          client_reference_id: uid,
          subscription_data: {
            metadata: { uid, kind: "subscription" },
          },
        },
        { idempotencyKey: `sub_${uid}_${priceId}` }
      );

      await db
        .collection("users")
        .doc(uid)
        .set(
          {
            premium: {
              status: "checkout_pending",
            },
            stripe: {
              pendingCheckoutSessionId: session.id,
            },
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          },
          { merge: true }
        );

      return res.json({ url: session.url, sessionId: session.id });
    } catch (e) {
      console.error("createSubscriptionCheckoutSession error", e);
      return res.status(500).json({ error: String(e?.message || e) });
    }
  }
);

/**
 * createMediaShopCheckout
 * Crée une Checkout Session Stripe pour le Media Shop (photos vendues)
 * { userId: string }
 * Returns: { checkoutUrl: string }
 */
exports.createMediaShopCheckout = onCall(
  {
    region: "us-east1",
    cpu: 0.083,
    memory: "256MiB",
    timeoutSeconds: 30,
    secrets: [STRIPE_SECRET_KEY],
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Authentication required");
    }

    const uid = request.auth.uid;
    const { userId } = request.data;

    // Sécurité: l'utilisateur ne peut créer une commande que pour lui-même
    if (uid !== userId) {
      throw new HttpsError(
        "permission-denied",
        "You can only create orders for yourself"
      );
    }

    // 1. Récupère le panier de l'utilisateur depuis Firestore
    const cartRef = db.collection("users").doc(uid).collection("cart");
    const cartSnap = await cartRef.get();

    if (cartSnap.empty) {
      throw new HttpsError("failed-precondition", "Cart is empty");
    }

    const cartItems = [];
    cartSnap.forEach((doc) => {
      cartItems.push({ id: doc.id, ...doc.data() });
    });

    // IMPORTANT: Ne jamais faire confiance aux montants venant de users/{uid}/cart.
    // On supporte 2 types d'items:
    // - Storex (produits): productId présent -> prix depuis products
    // - Media Shop (photos): photoId ou id -> prix depuis photos
    const storexProductIds = cartItems
      .map((it) => (typeof it.productId === "string" ? it.productId.trim() : ""))
      .filter(Boolean);
    const photosIds = cartItems
      .map((it) => (typeof it.photoId === "string" ? it.photoId.trim() : ""))
      .filter(Boolean);

    const productsById = await fetchStorexProductsById(storexProductIds);
    const photosById = await fetchPhotosById(photosIds);

    // 2. Crée la commande dans Firestore
    const orderRef = db.collection("users").doc(uid).collection("orders").doc();
    const orderId = orderRef.id;

    const items = cartItems.map((item) => {
      const productId = typeof item.productId === "string" ? item.productId.trim() : "";
      const qty = clamp(toSafeInt(item.quantity, 1), 1, 99);

      // Storex product item
      if (productId) {
        const product = productsById.get(productId);
        if (!product) {
          throw new HttpsError("failed-precondition", `Product not found: ${productId}`);
        }
        if (product.isActive === false) {
          throw new HttpsError("failed-precondition", `Product inactive: ${productId}`);
        }
        if (looksLikeNonEmptyString(product.moderationStatus) && String(product.moderationStatus).toLowerCase() !== "approved") {
          throw new HttpsError("failed-precondition", `Product not approved: ${productId}`);
        }

        const priceCents = assertPositiveCents(product.priceCents, "product.priceCents");
        return {
          productId,
          priceCents,
          thumbPath: looksLikeNonEmptyString(product.imageUrl) ? product.imageUrl : (item.imageUrl || ""),
          fullPath: "",
          eventName: "",
          groupName: item.groupId || "",
          photographerName: "",
          photographerId: null,
          title: looksLikeNonEmptyString(product.title) ? product.title : (item.title || ""),
          size: item.size || "",
          color: item.color || "",
          quantity: qty,
        };
      }

      // Media Shop photo item
      const photoId = typeof item.photoId === "string" && item.photoId.trim().length > 0
        ? item.photoId.trim()
        : item.id;
      const photo = photosById.get(photoId);
      if (!photo) {
        throw new HttpsError("failed-precondition", `Photo not found: ${photoId}`);
      }
      if (photo.isActive === false) {
        throw new HttpsError("failed-precondition", `Photo inactive: ${photoId}`);
      }
      if (looksLikeNonEmptyString(photo.moderationStatus) && String(photo.moderationStatus).toLowerCase() !== "approved") {
        throw new HttpsError("failed-precondition", `Photo not approved: ${photoId}`);
      }

      const priceCents = assertPositiveCents(photo.priceCents, "photo.priceCents");
      return {
        photoId,
        priceCents,
        thumbPath: looksLikeNonEmptyString(photo.thumbPath) ? photo.thumbPath : (item.imageUrl || item.thumbPath || ""),
        thumbUrl: looksLikeNonEmptyString(photo.thumbUrl) ? photo.thumbUrl : (item.thumbUrl || ""),
        fullPath: looksLikeNonEmptyString(photo.fullPath) ? photo.fullPath : (item.fullPath || ""),
        eventName: looksLikeNonEmptyString(photo.eventName) ? photo.eventName : (item.eventName || ""),
        groupName: looksLikeNonEmptyString(photo.groupName) ? photo.groupName : (item.groupName || ""),
        photographerName: looksLikeNonEmptyString(photo.photographerName) ? photo.photographerName : (item.photographerName || ""),
        photographerId: item.photographerId || null,
        title: looksLikeNonEmptyString(photo.title) ? photo.title : (item.title || ""),
        size: item.size || "",
        color: item.color || "",
        quantity: qty,
      };
    });

    const totalCents = items.reduce((sum, item) => {
      return sum + (toSafeInt(item.priceCents, 0) * (toSafeInt(item.quantity, 1)));
    }, 0);

    const orderData = {
      userId: uid,
      items,
      totalCents,
      discountCents: 0,
      discountPercent: 0,
      discountRule: null,
      status: "pending",
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    await orderRef.set(orderData);

    // 3. Crée les line_items pour Stripe
    const lineItems = items.map((item) => {
      // Privilégier thumbUrl (URL publique HTTPS) pour Stripe, sinon omettre l'image
      const imageUrl = looksLikeNonEmptyString(item.thumbUrl) ? item.thumbUrl : null;
      const images = imageUrl && imageUrl.startsWith("https://") ? [imageUrl] : [];

      return {
        price_data: {
          currency: "eur",
          product_data: {
            name: item.title || `Photo ${item.photoId || "?"}`,
            description: `${item.eventName || ""} ${item.groupName || ""}`.trim(),
            images,
            metadata: {
              photoId: item.photoId || "",
              eventName: item.eventName || "",
              groupName: item.groupName || "",
            },
          },
          unit_amount: item.priceCents,
        },
        quantity: item.quantity || 1,
      };
    });

    // 4. Crée une Checkout Session Stripe
    try {
      const stripeClient = getStripe();
      const session = await stripeClient.checkout.sessions.create(
        {
          mode: "payment",
          line_items: lineItems,
          success_url: `https://maslive.web.app/success?orderId=${orderId}`,
          cancel_url: `https://maslive.web.app/cancel?orderId=${orderId}`,
          metadata: {
            orderId,
            userId: uid,
            itemCount: items.length,
            totalCents,
          },
          customer_email: request.auth.token.email || undefined,
        },
        { idempotencyKey: `mediaShop_${uid}_${orderId}` }
      );

      // 5. Met à jour la commande avec le sessionId
      await orderRef.update({
        stripeSessionId: session.id,
        stripeSessionUrl: session.url,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      // 6. NE PAS vider le panier ici : attendre la confirmation de paiement (webhook checkout.session.completed)
      // pour éviter la perte du panier si l'utilisateur annule ou échoue.
      // Le panier sera vidé par handleCheckoutSessionCompleted() après paiement confirmé.

      return { checkoutUrl: session.url };
    } catch (error) {
      console.error("Stripe error:", error);
      throw new HttpsError(
        "internal",
        `Failed to create checkout session: ${error.message}`
      );
    }
  }
);

/**
 * createBusinessConnectOnboardingLink
 * Démarre / poursuit l'onboarding Stripe Connect Express pour un compte business.
 * {}
 * Returns: { url: string, accountId: string }
 */
exports.createBusinessConnectOnboardingLink = onCall(
  {
    region: "us-east1",
    cpu: 0.083,
    memory: "256MiB",
    timeoutSeconds: 30,
    secrets: [STRIPE_SECRET_KEY],
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Authentication required");
    }

    const uid = request.auth.uid;
    const businessRef = db.collection("businesses").doc(uid);
    const businessSnap = await businessRef.get();

    if (!businessSnap.exists) {
      throw new HttpsError("not-found", "Business profile not found");
    }

    const business = businessSnap.data() || {};
    if (business.ownerUid !== uid) {
      throw new HttpsError("permission-denied", "Not allowed");
    }

    if (business.status !== "approved") {
      throw new HttpsError(
        "failed-precondition",
        `Business status must be approved (current: ${business.status || "unknown"})`
      );
    }

    const stripeClient = getStripe();

    let accountId = business.stripe && business.stripe.accountId;

    // Crée le compte Stripe Express si absent
    if (!accountId) {
      const email = business.email || request.auth.token.email;
      const country = business.country === "France" ? "FR" : "FR";
      const companyName = business.companyName || undefined;

      const account = await stripeClient.accounts.create({
        type: "express",
        country,
        email,
        business_type: "company",
        company: {
          name: companyName,
        },
        capabilities: {
          card_payments: { requested: true },
          transfers: { requested: true },
        },
        metadata: {
          uid,
        },
      });

      accountId = account.id;

      await businessRef.set(
        {
          stripe: {
            accountId,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          },
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );
    }

    // URLs de retour / refresh (doivent être https)
    const baseUrl = "https://maslive.web.app/";
    const refreshUrl = `${baseUrl}?stripeConnect=refresh`;
    const returnUrl = `${baseUrl}?stripeConnect=return`;

    const link = await stripeClient.accountLinks.create({
      account: accountId,
      refresh_url: refreshUrl,
      return_url: returnUrl,
      type: "account_onboarding",
    });

    return { url: link.url, accountId };
  }
);

/**
 * refreshBusinessConnectStatus
 * Rafraîchit l'état Stripe du compte Connect (charges/payouts/details)
 * {}
 * Returns: { accountId, detailsSubmitted, chargesEnabled, payoutsEnabled }
 */
exports.refreshBusinessConnectStatus = onCall(
  {
    region: "us-east1",
    cpu: 0.083,
    memory: "256MiB",
    timeoutSeconds: 30,
    secrets: [STRIPE_SECRET_KEY],
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Authentication required");
    }

    const uid = request.auth.uid;
    const businessRef = db.collection("businesses").doc(uid);
    const businessSnap = await businessRef.get();

    if (!businessSnap.exists) {
      throw new HttpsError("not-found", "Business profile not found");
    }

    const business = businessSnap.data() || {};
    if (business.ownerUid !== uid) {
      throw new HttpsError("permission-denied", "Not allowed");
    }

    const accountId = business.stripe && business.stripe.accountId;
    if (!accountId) {
      throw new HttpsError(
        "failed-precondition",
        "Stripe accountId not found for this business"
      );
    }

    const stripeClient = getStripe();
    const account = await stripeClient.accounts.retrieve(accountId);

    const detailsSubmitted = !!account.details_submitted;
    const chargesEnabled = !!account.charges_enabled;
    const payoutsEnabled = !!account.payouts_enabled;
    const requirements = account.requirements || {};

    await businessRef.set(
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
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    return { accountId, detailsSubmitted, chargesEnabled, payoutsEnabled };
  }
);

/**
 * stripeWebhook
 * Endpoint pour recevoir les événements webhook de Stripe.
 * Configure dans le dashboard Stripe: https://dashboard.stripe.com/webhooks
 * URL: https://us-east1-maslive.cloudfunctions.net/stripeWebhook
 * 
 * Événements écoutés:
 * - checkout.session.completed: Commande payée (Media Shop)
 * - payment_intent.succeeded: Paiement réussi
 * - account.updated: Statut du compte Connect changé
 */
exports.stripeWebhook = onRequest(
  {
    region: "us-east1",
    cpu: 0.083,
    memory: "256MiB",
    timeoutSeconds: 30,
    secrets: [STRIPE_SECRET_KEY, STRIPE_WEBHOOK_SECRET],
    // CORS non nécessaire pour les webhooks (appelés par Stripe directement)
  },
  async (req, res) => {
    // Seul POST est accepté
    if (req.method !== "POST") {
      res.status(405).send("Method Not Allowed");
      return;
    }

    const sig = req.headers["stripe-signature"];
    const webhookSecret = getStripeWebhookSecret();

    if (!webhookSecret) {
      console.error("STRIPE_WEBHOOK_SECRET not configured");
      res.status(500).send("Webhook secret not configured");
      return;
    }

    let event;

    try {
      const stripeClient = getStripe();
      // Vérification de la signature du webhook (sécurité)
      event = stripeClient.webhooks.constructEvent(
        req.rawBody,
        sig,
        webhookSecret
      );
    } catch (err) {
      console.error("Webhook signature verification failed:", err.message);
      res.status(400).send(`Webhook Error: ${err.message}`);
      return;
    }

    console.log("Webhook event received:", event.type, event.id);

    try {
      switch (event.type) {
        case "checkout.session.completed":
          await handleCheckoutSessionCompleted(event.data.object);
          break;

        case "customer.subscription.updated":
          await handleCustomerSubscriptionUpdated(event.data.object);
          break;

        case "customer.subscription.deleted":
          await handleCustomerSubscriptionDeleted(event.data.object);
          break;

        case "invoice.paid":
          await handleInvoicePaid(event.data.object);
          break;

        case "invoice.payment_failed":
          await handleInvoicePaymentFailed(event.data.object);
          break;

        case "payment_intent.succeeded":
          await handlePaymentIntentSucceeded(event.data.object);
          break;

        case "account.updated":
          await handleAccountUpdated(event.data.object);
          break;

        case "account.application.authorized":
        case "account.application.deauthorized":
          console.log("Account application event:", event.type);
          break;

        default:
          console.log("Unhandled event type:", event.type);
      }

      res.status(200).json({ received: true, eventType: event.type });
    } catch (error) {
      console.error("Error processing webhook:", error);
      res.status(500).send("Webhook handler error");
    }
  }
);

/**
 * Traite l'événement checkout.session.completed
 * Commande payée via le Media Shop
 */
async function handleCheckoutSessionCompleted(session) {
  console.log("Processing checkout.session.completed:", session.id);

  // Supporte 2 modèles:
  // - Nouveau modèle simple: /orders/{orderId}
  // - Modèle existant Media Shop: /users/{uid}/orders/{orderId}
  const orderId = session.metadata?.orderId || session.client_reference_id;
  const uid = session.metadata?.uid || session.metadata?.userId;

  if (!orderId) {
    console.warn("Missing orderId in session metadata");
    return;
  }

  // 1) Essaye d'abord /orders/{orderId}
  const rootOrderRef = db.collection("orders").doc(orderId);
  const rootSnap = await rootOrderRef.get();
  if (rootSnap.exists) {
    const rootOrder = rootSnap.data() || {};

    await rootOrderRef.set(
      {
        status: "paid",
        paidAt: admin.firestore.FieldValue.serverTimestamp(),
        stripe: {
          sessionId: session.id,
          paymentIntentId: session.payment_intent || null,
        },
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    if (uid && typeof uid === "string") {
      await db
        .collection("users")
        .doc(uid)
        .collection("purchases")
        .doc(orderId)
        .set(
          {
            orderId,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
          },
          { merge: true }
        );
    }

    // Décrémenter le stock des produits root order
    try {
      const items = rootOrder.items || [];
      const productsToDecrement = items
        .filter((item) => item.productId && typeof item.productId === "string")
        .map((item) => ({
          productId: item.productId,
          quantity: Number(item.quantity || 1),
        }))
        .filter((p) => p.quantity > 0);

      if (productsToDecrement.length > 0) {
        await db.runTransaction(async (transaction) => {
          const productRefs = {};
          const productDocs = {};
          for (const { productId } of productsToDecrement) {
            const rootRef = db.collection("products").doc(productId);
            const rootSnap = await transaction.get(rootRef);
            productRefs[productId] = rootRef;
            productDocs[productId] = rootSnap.exists ? rootSnap.data() : null;

            if (rootOrder.shopId) {
              const shopRef = db
                .collection("shops")
                .doc(rootOrder.shopId)
                .collection("products")
                .doc(productId);
              const shopSnap = await transaction.get(shopRef);
              productRefs[`${productId}_shop`] = shopRef;
              if (shopSnap.exists) {
                productDocs[`${productId}_shop`] = shopSnap.data();
              }
            }
          }

          for (const { productId, quantity } of productsToDecrement) {
            const product = productDocs[productId];
            if (!product) continue;

            const currentStock = Number(product.stock || 0);
            const newStock = Math.max(0, currentStock - quantity);

            const updateData = {
              stock: newStock,
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            };

            const alertQty = Number(product.alertQty || 0);
            if (alertQty > 0) {
              if (newStock === 0) {
                updateData.stockStatus = "out_of_stock";
              } else if (newStock <= alertQty) {
                updateData.stockStatus = "low_stock";
              } else {
                updateData.stockStatus = "in_stock";
              }
            }

            transaction.update(productRefs[productId], updateData);
            if (productRefs[`${productId}_shop`]) {
              transaction.update(productRefs[`${productId}_shop`], updateData);
            }

            console.log(
              `Stock decremented (root order) for product ${productId}: ${currentStock} -> ${newStock} (-${quantity})`
            );
          }
        });
      }
    } catch (stockErr) {
      console.error(`Failed to decrement stock for root order ${orderId}:`, stockErr);
    }

    console.log(`Root order ${orderId} marked as paid`);
    return;
  }

  // 2) Fallback vers modèle existant users/{uid}/orders/{orderId}
  if (!uid || typeof uid !== "string") {
    console.warn("Missing uid/userId in session metadata for users orders");
    return;
  }

  const userOrderRef = db.collection("users").doc(uid).collection("orders").doc(orderId);
  const userOrderSnap = await userOrderRef.get();
  if (!userOrderSnap.exists) {
    console.warn(`Order ${orderId} not found (root nor user ${uid})`);
    return;
  }

  const order = userOrderSnap.data() || {};

  await userOrderRef.update({
    status: "paid",
    paidAt: admin.firestore.FieldValue.serverTimestamp(),
    stripeSessionId: session.id,
    stripePaymentIntentId: session.payment_intent,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  const items = order.items || [];
  const batch = db.batch();

  for (const item of items) {
    const photoId = item.photoId;
    if (!photoId) continue;

    const purchaseRef = db.collection("users").doc(uid).collection("purchases").doc(photoId);
    batch.set(purchaseRef, {
      photoId,
      orderId,
      priceCents: item.priceCents || 0,
      purchasedAt: admin.firestore.FieldValue.serverTimestamp(),
      eventName: item.eventName || "",
      groupName: item.groupName || "",
      photographerName: item.photographerName || "",
      photographerId: item.photographerId || null,
      thumbnailUrl: item.thumbPath || null,
      fullPath: item.fullPath || null,
      stripeSessionId: session.id,
    });
  }

  await batch.commit();

  // Décrémenter le stock des produits achetés (transaction Firestore)
  try {
    const productsToDecrement = items
      .filter((item) => item.productId && typeof item.productId === "string")
      .map((item) => ({
        productId: item.productId,
        quantity: Number(item.quantity || 1),
      }))
      .filter((p) => p.quantity > 0);

    if (productsToDecrement.length > 0) {
      await db.runTransaction(async (transaction) => {
        // Lire tous les produits concernés
        const productRefs = {};
        const productDocs = {};
        for (const { productId } of productsToDecrement) {
          // Lire dans /products (source de vérité)
          const rootRef = db.collection("products").doc(productId);
          const rootSnap = await transaction.get(rootRef);
          productRefs[productId] = rootRef;
          productDocs[productId] = rootSnap.exists ? rootSnap.data() : null;

          // Lire aussi miroir /shops/{shopId}/products si shopId présent
          if (order.shopId) {
            const shopRef = db
              .collection("shops")
              .doc(order.shopId)
              .collection("products")
              .doc(productId);
            const shopSnap = await transaction.get(shopRef);
            productRefs[`${productId}_shop`] = shopRef;
            if (shopSnap.exists) {
              productDocs[`${productId}_shop`] = shopSnap.data();
            }
          }
        }

        // Calculer nouveaux stocks et appliquer les updates
        for (const { productId, quantity } of productsToDecrement) {
          const product = productDocs[productId];
          if (!product) {
            console.warn(`Product ${productId} not found, skipping stock decrement`);
            continue;
          }

          const currentStock = Number(product.stock || 0);
          const newStock = Math.max(0, currentStock - quantity); // Empêcher stock négatif

          const updateData = {
            stock: newStock,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          };

          // Auto-update stockStatus si alertQty présent
          const alertQty = Number(product.alertQty || 0);
          if (alertQty > 0) {
            if (newStock === 0) {
              updateData.stockStatus = "out_of_stock";
            } else if (newStock <= alertQty) {
              updateData.stockStatus = "low_stock";
            } else {
              updateData.stockStatus = "in_stock";
            }
          }

          // Update /products (root)
          transaction.update(productRefs[productId], updateData);

          // Update /shops/{shopId}/products (miroir)
          if (productRefs[`${productId}_shop`]) {
            transaction.update(productRefs[`${productId}_shop`], updateData);
          }

          console.log(
            `Stock decremented for product ${productId}: ${currentStock} -> ${newStock} (-${quantity})`
          );
        }
      });
    }
  } catch (stockErr) {
    console.error(`Failed to decrement stock for order ${orderId}:`, stockErr);
    // Ne pas bloquer le paiement si le stock échoue (ordre déjà marqué payé)
  }

  // Vider le panier de l'utilisateur après paiement confirmé
  try {
    const cartSnap = await db.collection("users").doc(uid).collection("cart").get();
    if (!cartSnap.empty) {
      const cartBatch = db.batch();
      cartSnap.forEach((doc) => cartBatch.delete(doc.ref));
      await cartBatch.commit();
      console.log(`Cart cleared for user ${uid} after successful payment`);
    }
  } catch (err) {
    console.error(`Failed to clear cart for user ${uid}:`, err);
  }

  console.log(`User order ${orderId} marked as paid, ${items.length} purchases created`);
}

async function handleCustomerSubscriptionUpdated(subscription) {
  const subscriptionId = subscription?.id;
  const uid = subscription?.metadata?.uid;

  const resolvedUid = uid || (await findUserIdByStripeSubscriptionId(subscriptionId));
  if (!resolvedUid) {
    console.warn("Subscription updated: cannot resolve uid", subscriptionId);
    return;
  }

  const status = (subscription?.status || "unknown").toString();
  const isActive = status === "active" || status === "trialing";

  await db
    .collection("users")
    .doc(resolvedUid)
    .set(
      {
        premium: {
          status: isActive ? "active" : "inactive",
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        stripe: {
          customerId: subscription?.customer || null,
          subscriptionId: subscriptionId || null,
          subscriptionStatus: status,
        },
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
}

async function handleCustomerSubscriptionDeleted(subscription) {
  const subscriptionId = subscription?.id;
  const uid = subscription?.metadata?.uid;

  const resolvedUid = uid || (await findUserIdByStripeSubscriptionId(subscriptionId));
  if (!resolvedUid) {
    console.warn("Subscription deleted: cannot resolve uid", subscriptionId);
    return;
  }

  await db
    .collection("users")
    .doc(resolvedUid)
    .set(
      {
        premium: {
          status: "inactive",
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        stripe: {
          subscriptionStatus: "deleted",
        },
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
}

async function handleInvoicePaid(invoice) {
  const subscriptionId = invoice?.subscription;
  if (!subscriptionId) return;
  const uid = await findUserIdByStripeSubscriptionId(subscriptionId);
  if (!uid) return;

  await db
    .collection("users")
    .doc(uid)
    .set(
      {
        premium: {
          status: "active",
          lastPaidAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
}

async function handleInvoicePaymentFailed(invoice) {
  const subscriptionId = invoice?.subscription;
  if (!subscriptionId) return;
  const uid = await findUserIdByStripeSubscriptionId(subscriptionId);
  if (!uid) return;

  await db
    .collection("users")
    .doc(uid)
    .set(
      {
        premium: {
          status: "inactive",
          lastPaymentFailedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
}

/**
 * Traite l'événement payment_intent.succeeded
 * Paiement réussi (confirmation supplémentaire)
 */
async function handlePaymentIntentSucceeded(paymentIntent) {
  console.log("Processing payment_intent.succeeded:", paymentIntent.id);

  const uid = paymentIntent.metadata?.uid;
  const orderId = paymentIntent.metadata?.orderId;

  if (!uid || !orderId) {
    console.warn("Missing uid or orderId in payment intent metadata");
    return;
  }

  const orderRef = db
    .collection("users")
    .doc(uid)
    .collection("orders")
    .doc(orderId);

  await orderRef.set(
    {
      status: "confirmed",
      paidAt: admin.firestore.FieldValue.serverTimestamp(),
      stripe: {
        paymentIntentId: paymentIntent.id,
        status: paymentIntent.status || "succeeded",
      },
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true }
  );

  // Miroir root order (si présent)
  const rootOrderRef = db.collection("orders").doc(orderId);
  await rootOrderRef.set(
    {
      status: "confirmed",
      paidAt: admin.firestore.FieldValue.serverTimestamp(),
      stripe: {
        paymentIntentId: paymentIntent.id,
        status: paymentIntent.status || "succeeded",
      },
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true }
  );

  console.log(`Order ${orderId} marked as paid via payment_intent.succeeded`);
}

/**
 * Traite l'événement account.updated
 * Statut du compte Stripe Connect changé
 */
async function handleAccountUpdated(account) {
  console.log("Processing account.updated:", account.id);

  const uid = account.metadata?.uid;
  if (!uid) {
    console.warn("No uid in account metadata, cannot update Firestore");
    return;
  }

  const businessRef = db.collection("businesses").doc(uid);
  const businessSnap = await businessRef.get();

  if (!businessSnap.exists) {
    console.warn(`Business profile ${uid} not found`);
    return;
  }

  const detailsSubmitted = !!account.details_submitted;
  const chargesEnabled = !!account.charges_enabled;
  const payoutsEnabled = !!account.payouts_enabled;
  const requirements = account.requirements || {};

  await businessRef.set(
    {
      stripe: {
        accountId: account.id,
        detailsSubmitted,
        chargesEnabled,
        payoutsEnabled,
        currentlyDue: requirements.currently_due || [],
        eventuallyDue: requirements.eventually_due || [],
        pastDue: requirements.past_due || [],
        currentDeadline: requirements.current_deadline || null,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true }
  );

  console.log(`Business ${uid} Stripe status auto-updated via webhook`);
}

// ============================================================================
// COMMERCE SUBMISSION MODERATION (Cloud Functions Gen 2)
// ============================================================================

/**
 * Approuve une soumission commerce et la publie dans /shops/{scopeId}/products ou /media
 */
exports.approveCommerceSubmission = onCall(
  {
    region: "us-east1",
    cpu: 0.083,
    memory: "256MiB",
    timeoutSeconds: 60,
    maxInstances: 2,
  },
  async (request) => {
    const { submissionId } = request.data;
    const uid = request.auth?.uid;

  if (!uid) {
    throw new HttpsError("unauthenticated", "User must be authenticated");
  }

  if (!submissionId) {
    throw new HttpsError("invalid-argument", "submissionId is required");
  }

  // Récupérer la soumission
  const submissionRef = admin.firestore().collection("commerce_submissions").doc(submissionId);
  const submissionDoc = await submissionRef.get();

  if (!submissionDoc.exists) {
    throw new HttpsError("not-found", "Submission not found");
  }

  const submission = submissionDoc.data();

  // Vérifier le statut
  if (submission.status !== "pending") {
    throw new HttpsError("failed-precondition", `Submission status is ${submission.status}, must be pending`);
  }

  // Vérifier les permissions du modérateur
  const userDoc = await admin.firestore().collection("users").doc(uid).get();
  if (!userDoc.exists) {
    throw new HttpsError("permission-denied", "User profile not found");
  }

  const userData = userDoc.data();
  const role = userData.role;
  const isAdmin = userData.isAdmin === true;

  // SuperAdmin et admin peuvent tout modérer
  const canModerate = isAdmin || role === "admin" || role === "superadmin";

  // Admin groupe peut modérer uniquement son scope
  const isAdminGroupe = role === "admin_groupe";
  const managedScopeIds = userData.managedScopeIds || [];
  const canModerateScope = isAdminGroupe && submission.scopeType === "group" && managedScopeIds.includes(submission.scopeId);

  if (!canModerate && !canModerateScope) {
    throw new HttpsError("permission-denied", "User cannot moderate this submission");
  }

  // Déterminer la collection cible
  const scopeId = submission.scopeId || "global";
  const targetCollection = submission.type === "product" ? "products" : "media";
  const targetPath = `shops/${scopeId}/${targetCollection}`;

  // Créer le document publié
  const publishedData = {
    sourceSubmissionId: submissionId,
    ownerUid: submission.ownerUid,
    ownerRole: submission.ownerRole,
    scopeType: submission.scopeType,
    scopeId: submission.scopeId,
    title: submission.title,
    description: submission.description,
    mediaUrls: submission.mediaUrls || [],
    thumbUrl: submission.thumbUrl || null,
    publishedAt: admin.firestore.FieldValue.serverTimestamp(),
    publishedBy: uid,
  };

  // Champs produit
  if (submission.type === "product") {
    publishedData.price = submission.price || 0;
    publishedData.currency = submission.currency || "EUR";
    publishedData.stock = submission.stock || 0;
    publishedData.isActive = submission.isActive !== false;
  }

  // Champs media
  if (submission.type === "media") {
    publishedData.mediaType = submission.mediaType || "photo";
    if (submission.takenAt) publishedData.takenAt = submission.takenAt;
    if (submission.location) publishedData.location = submission.location;
    if (submission.photographer) publishedData.photographer = submission.photographer;
  }

  // Publier dans la boutique
  await admin.firestore().collection(targetPath).doc(submissionId).set(publishedData);

  // Mettre à jour la soumission
  await submissionRef.update({
    status: "approved",
    publishedRef: `${targetPath}/${submissionId}`,
    moderatedBy: uid,
    moderatedAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  console.log(`Submission ${submissionId} approved by ${uid} and published to ${targetPath}/${submissionId}`);

  return { success: true, publishedRef: `${targetPath}/${submissionId}` };
  }
);

/**
 * Refuse une soumission commerce avec une note
 */
exports.rejectCommerceSubmission = onCall(
  {
    region: "us-east1",
    cpu: 0.083,
    memory: "256MiB",
    timeoutSeconds: 60,
    maxInstances: 2,
  },
  async (request) => {
  const { submissionId, note } = request.data;
  const uid = request.auth?.uid;

  if (!uid) {
    throw new HttpsError("unauthenticated", "User must be authenticated");
  }

  if (!submissionId || !note) {
    throw new HttpsError("invalid-argument", "submissionId and note are required");
  }

  // Récupérer la soumission
  const submissionRef = admin.firestore().collection("commerce_submissions").doc(submissionId);
  const submissionDoc = await submissionRef.get();

  if (!submissionDoc.exists) {
    throw new HttpsError("not-found", "Submission not found");
  }

  const submission = submissionDoc.data();

  // Vérifier le statut
  if (submission.status !== "pending") {
    throw new HttpsError("failed-precondition", `Submission status is ${submission.status}, must be pending`);
  }

  // Vérifier les permissions du modérateur
  const userDoc = await admin.firestore().collection("users").doc(uid).get();
  if (!userDoc.exists) {
    throw new HttpsError("permission-denied", "User profile not found");
  }

  const userData = userDoc.data();
  const role = userData.role;
  const isAdmin = userData.isAdmin === true;

  // SuperAdmin et admin peuvent tout modérer
  const canModerate = isAdmin || role === "admin" || role === "superadmin";

  // Admin groupe peut modérer uniquement son scope
  const isAdminGroupe = role === "admin_groupe";
  const managedScopeIds = userData.managedScopeIds || [];
  const canModerateScope = isAdminGroupe && submission.scopeType === "group" && managedScopeIds.includes(submission.scopeId);

  if (!canModerate && !canModerateScope) {
    throw new HttpsError("permission-denied", "User cannot moderate this submission");
  }

  // Mettre à jour la soumission
  await submissionRef.update({
    status: "rejected",
    moderationNote: note,
    moderatedBy: uid,
    moderatedAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  console.log(`Submission ${submissionId} rejected by ${uid}`);

  return { success: true };
  }
);

// ============================================================================
// COMMERCE NOTIFICATIONS (Cloud Functions Gen 2)
// ============================================================================

/**
 * Notifier le propriétaire quand sa soumission est approuvée
 */
exports.notifyCommerceApproved = onDocumentUpdated(
  {
    document: "commerce_submissions/{submissionId}",
    cpu: 0.083,
    memory: "256MiB",
    timeoutSeconds: 30,
    maxInstances: 2,
  },
  async (event) => {
    const before = event.data.before.data();
    const after = event.data.after.data();
    const submissionId = event.params.submissionId;

    // Vérifier changement de statut pending → approved
    if (before.status !== "pending" || after.status !== "approved") {
      return;
    }

    const ownerUid = after.ownerUid;
    const title = after.title || "Votre contenu";
    const type = after.type === "product" ? "produit" : "média";

    // Récupérer le token FCM du propriétaire
    const userDoc = await admin.firestore().collection("users").doc(ownerUid).get();
    if (!userDoc.exists) return;

    const fcmToken = userDoc.data()?.fcmToken;
    if (!fcmToken) return;

    // Envoyer notification
    try {
      await admin.messaging().send({
        token: fcmToken,
        notification: {
          title: "✅ Contenu validé !",
          body: `Votre ${type} "${title}" est maintenant publié.`,
        },
        data: {
          type: "commerce_approved",
          submissionId: submissionId,
          route: "/commerce/my-submissions",
        },
      });
      console.log(`Notification approval sent to ${ownerUid} for ${submissionId}`);
    } catch (error) {
      console.error(`Failed to send approval notification: ${error}`);
    }
  }
);

/**
 * Notifier le propriétaire quand sa soumission est refusée
 */
exports.notifyCommerceRejected = onDocumentUpdated(
  {
    document: "commerce_submissions/{submissionId}",
    cpu: 0.083,
    memory: "256MiB",
    timeoutSeconds: 30,
    maxInstances: 2,
  },
  async (event) => {
    const before = event.data.before.data();
    const after = event.data.after.data();
    const submissionId = event.params.submissionId;

    // Vérifier changement de statut pending → rejected
    if (before.status !== "pending" || after.status !== "rejected") {
      return;
    }

    const ownerUid = after.ownerUid;
    const title = after.title || "Votre contenu";
    const type = after.type === "product" ? "produit" : "média";
    const note = after.moderationNote || "Aucune note";

    // Récupérer le token FCM du propriétaire
    const userDoc = await admin.firestore().collection("users").doc(ownerUid).get();
    if (!userDoc.exists) return;

    const fcmToken = userDoc.data()?.fcmToken;
    if (!fcmToken) return;

    // Envoyer notification
    try {
      await admin.messaging().send({
        token: fcmToken,
        notification: {
          title: "❌ Contenu refusé",
          body: `Votre ${type} "${title}" nécessite des modifications : ${note}`,
        },
        data: {
          type: "commerce_rejected",
          submissionId: submissionId,
          route: "/commerce/my-submissions",
        },
      });
      console.log(`Notification rejection sent to ${ownerUid} for ${submissionId}`);
    } catch (error) {
      console.error(`Failed to send rejection notification: ${error}`);
    }
  }
);

// ============================================================================
// SUPERADMIN ARTICLES - Initialisation des articles de base
// ============================================================================

const superadminArticlesInitData = [
  {
    name: "Casquette MAS'LIVE",
    description: "Casquette officiellement siglée MAS'LIVE. Tissu respirant, ajustable.",
    category: "casquette",
    price: 19.99,
    imageUrl: "",
    stock: 100,
    isActive: true,
    sku: "CASQUETTE-001",
    tags: ["casquette", "accessoire", "outdoor"],
  },
  {
    name: "T-shirt MAS'LIVE",
    description: "T-shirt 100% coton de qualité premium avec logo MAS'LIVE. Confortable et durable.",
    category: "tshirt",
    price: 24.99,
    imageUrl: "",
    stock: 150,
    isActive: true,
    sku: "TSHIRT-001",
    tags: ["t-shirt", "vêtement", "coton"],
  },
  {
    name: "Porte-clé MAS'LIVE",
    description: "Porte-clé en acier inoxydable avec gravure MAS'LIVE. Compact et élégant.",
    category: "porteclé",
    price: 9.99,
    imageUrl: "",
    stock: 200,
    isActive: true,
    sku: "PORTECLE-001",
    tags: ["porte-clé", "accessoire", "acier"],
  },
  {
    name: "Bandana MAS'LIVE",
    description: "Bandana coloré multi-usage avec motif MAS'LIVE. Parfait pour le trail et les sports outdoor.",
    category: "bandana",
    price: 14.99,
    imageUrl: "",
    stock: 120,
    isActive: true,
    sku: "BANDANA-001",
    tags: ["bandana", "accessoire", "outdoor", "sport"],
  },
];

exports.initSuperadminArticles = onCall({ region: "us-east1" }, async (request) => {
  const uid = request.auth?.uid;

  if (!uid) {
    throw new HttpsError("unauthenticated", "Utilisateur non authentifié");
  }

  // Vérifier que l'utilisateur est super admin
  const userDoc = await db.collection("users").doc(uid).get();
  if (!userDoc.exists) {
    throw new HttpsError("permission-denied", "Profil utilisateur introuvable");
  }

  const userData = userDoc.data();
  const userRole = userData.role || "user";

  // Seul un superAdmin peut initialiser les articles
  if (userRole !== "superAdmin" && !userData.isAdmin) {
    throw new HttpsError(
      "permission-denied",
      "Seul un super administrateur peut initialiser les articles"
    );
  }

  try {
    const batch = db.batch();
    let created = 0;

    // Vérifier si les articles existent déjà
    const existingArticles = await db.collection("superadmin_articles").get();
    
    if (existingArticles.size > 0) {
      console.log(`Articles superadmin déjà initialisés (${existingArticles.size} articles trouvés)`);
      return {
        success: true,
        created: 0,
        message: "Les articles superadmin sont déjà initialisés",
      };
    }

    // Créer les articles de base
    const timestamp = admin.firestore.FieldValue.serverTimestamp();
    
    for (const article of superadminArticlesInitData) {
      const ref = db.collection("superadmin_articles").doc();
      batch.set(ref, {
        ...article,
        createdAt: timestamp,
        updatedAt: timestamp,
      });
      created++;
    }

    await batch.commit();

    console.log(`✅ Articles superadmin initialisés: ${created} articles créés`);

    return {
      success: true,
      created: created,
      message: `${created} articles superadmin créés avec succès`,
    };
  } catch (error) {
    console.error("Erreur lors de l'initialisation des articles superadmin:", error);
    throw new HttpsError("internal", `Erreur: ${error.message}`);
  }
});

// ============================================================================
// GROUP TRACKING - Position moyenne automatique
// ============================================================================

const groupTracking = require("./group_tracking");
exports.calculateGroupAveragePosition = groupTracking.calculateGroupAveragePosition;

