/**
 * Cloud Functions Gen 2 (firebase-functions v2)
 * - nearbySearch (onCall)
 * - updateGroupLocation (onCall)
 */

const admin = require("firebase-admin");
const ngeohash = require("ngeohash");
const { setGlobalOptions } = require("firebase-functions/v2");
const {
  onDocumentCreated,
  onDocumentUpdated,
} = require("firebase-functions/v2/firestore");
const { onCall, HttpsError } = require("firebase-functions/v2/https");

setGlobalOptions({ region: "us-central1" });

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
    cpu: 1,
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
    cpu: 1,
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
  "groups/{groupId}/products/{productId}",
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
  "groups/{groupId}/products/{productId}",
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
