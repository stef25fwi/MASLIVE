/**
 * Cloud Functions Gen 2 (firebase-functions v2)
 * - nearbySearch (onCall)
 * - updateGroupLocation (onCall)
 * - initializeRoles (onCall) - Initialise les rôles par défaut
 */

const admin = require("firebase-admin");
const ngeohash = require("ngeohash");
const { setGlobalOptions } = require("firebase-functions/v2");
const {
  onDocumentCreated,
  onDocumentUpdated,
} = require("firebase-functions/v2/firestore");
const { onCall, onRequest, HttpsError } = require("firebase-functions/v2/https");

// Stripe SDK (lazy initialization)
const stripeModule = require("stripe");
let stripe = null;

function getStripeWebhookSecret() {
  try {
    const config = require("firebase-functions").config();
    return config.stripe?.webhook_secret || process.env.STRIPE_WEBHOOK_SECRET;
  } catch (e) {
    return process.env.STRIPE_WEBHOOK_SECRET;
  }
}

function getStripe() {
  if (!stripe) {
    // Try Firebase config first, then environment variables
    let apiKey = null;
    
    try {
      const config = require("firebase-functions").config();
      apiKey = config.stripe?.secret_key || process.env.STRIPE_SECRET_KEY;
    } catch (e) {
      apiKey = process.env.STRIPE_SECRET_KEY;
    }
    
    if (!apiKey) {
      throw new Error(
        "STRIPE_SECRET_KEY not configured. Run: " +
        "firebase functions:config:set stripe.secret_key=\"sk_test_...\""
      );
    }
    stripe = stripeModule(apiKey);
  }
  return stripe;
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
  { region: "us-east1" },
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
  { region: "us-east1" },
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
  { region: "us-east1" },
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

    if (orderData.status !== "pending") {
      throw new HttpsError(
        "failed-precondition",
        `Order ${orderId} is not in pending status (current: ${orderData.status})`
      );
    }

    // 2. Prépare les line_items pour Stripe
    const items = orderData.items || [];
    if (items.length === 0) {
      throw new HttpsError("invalid-argument", "Order has no items");
    }

    const lineItems = items.map((item) => ({
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

    // Applique le discount si présent
    const discountCents = orderData.discountCents || 0;
    if (discountCents > 0) {
      // Ajoute une ligne négative pour le discount
      lineItems.push({
        price_data: {
          currency: "eur",
          product_data: {
            name: `Réduction ${orderData.discountRule || "Pack"} (-${orderData.discountPercent || 0}%)`,
            description: `Pack discount appliqué`,
          },
          unit_amount: -discountCents, // Montant négatif
        },
        quantity: 1,
      });
    }

    // 3. Crée une Checkout Session Stripe
    try {
      const stripeClient = getStripe();
      const session = await stripeClient.checkout.sessions.create({
        mode: "payment",
        line_items: lineItems,
        success_url: `https://maslive.web.app/success?orderId=${orderId}`,
        cancel_url: `https://maslive.web.app/cancel?orderId=${orderId}`,
        metadata: {
          orderId,
          userId: uid,
          itemCount: items.length,
          totalCents: orderData.totalCents || 0,
        },
        customer_email: request.auth.token.email || undefined,
      });

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

    // 2. Crée la commande dans Firestore
    const orderRef = db.collection("users").doc(uid).collection("orders").doc();
    const orderId = orderRef.id;

    const items = cartItems.map((item) => ({
      photoId: item.photoId || item.id,
      priceCents: item.priceCents || 0,
      thumbPath: item.imageUrl || item.thumbPath || "",
      fullPath: item.fullPath || "",
      eventName: item.eventName || "",
      groupName: item.groupName || "",
      photographerName: item.photographerName || "",
      photographerId: item.photographerId || null,
      title: item.title || "",
      size: item.size || "",
      color: item.color || "",
      quantity: item.quantity || 1,
    }));

    const totalCents = items.reduce((sum, item) => {
      return sum + (item.priceCents * (item.quantity || 1));
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
    const lineItems = items.map((item) => ({
      price_data: {
        currency: "eur",
        product_data: {
          name: item.title || `Photo ${item.photoId}`,
          description: `${item.eventName || ""} ${item.groupName || ""}`.trim(),
          images: item.thumbPath ? [item.thumbPath] : [],
          metadata: {
            photoId: item.photoId,
            eventName: item.eventName || "",
            groupName: item.groupName || "",
          },
        },
        unit_amount: item.priceCents,
      },
      quantity: item.quantity || 1,
    }));

    // 4. Crée une Checkout Session Stripe
    try {
      const stripeClient = getStripe();
      const session = await stripeClient.checkout.sessions.create({
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
      });

      // 5. Met à jour la commande avec le sessionId
      await orderRef.update({
        stripeSessionId: session.id,
        stripeSessionUrl: session.url,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      // 6. Vide le panier après création de la commande
      const batch = db.batch();
      cartSnap.forEach((doc) => batch.delete(doc.ref));
      await batch.commit();

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

  const orderId = session.metadata?.orderId;
  const userId = session.metadata?.userId;

  if (!orderId || !userId) {
    console.warn("Missing orderId or userId in session metadata");
    return;
  }

  const orderRef = db.collection("users").doc(userId).collection("orders").doc(orderId);
  const orderSnap = await orderRef.get();

  if (!orderSnap.exists) {
    console.warn(`Order ${orderId} not found for user ${userId}`);
    return;
  }

  const order = orderSnap.data();

  // Met à jour le statut de la commande
  await orderRef.update({
    status: "paid",
    paidAt: admin.firestore.FieldValue.serverTimestamp(),
    stripeSessionId: session.id,
    stripePaymentIntentId: session.payment_intent,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  // Crée les documents purchases pour chaque photo
  const items = order.items || [];
  const batch = db.batch();

  for (const item of items) {
    const photoId = item.photoId;
    if (!photoId) continue;

    const purchaseRef = db.collection("users").doc(userId).collection("purchases").doc(photoId);
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

  console.log(`Order ${orderId} marked as paid, ${items.length} purchases created`);
}

/**
 * Traite l'événement payment_intent.succeeded
 * Paiement réussi (confirmation supplémentaire)
 */
async function handlePaymentIntentSucceeded(paymentIntent) {
  console.log("Processing payment_intent.succeeded:", paymentIntent.id);

  // Logique additionnelle si nécessaire (notifications, analytics, etc.)
  // La plupart du traitement est fait dans checkout.session.completed
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
