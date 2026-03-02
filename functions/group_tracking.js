/**
 * Cloud Function Firebase Gen2 - Améliorée
 * Calcul automatique position moyenne groupe avec:
 * - Centroïde géodésique (plus précis)
 * - Pondération par accuracy
 * Trigger: group_positions/{adminGroupId}/members/{uid}
 */

const { onDocumentWritten } = require("firebase-functions/v2/firestore");
const admin = require("firebase-admin");

if (!admin.apps.length) {
  admin.initializeApp();
}
const db = admin.firestore();

async function findAdminUidByGroupId(adminGroupId) {
  const snap = await db
    .collection("group_admins")
    .where("adminGroupId", "==", adminGroupId)
    .limit(1)
    .get();
  if (snap.empty) return null;
  return snap.docs[0].id;
}

function looksLikeCircuitSelection(sel) {
  return (
    sel &&
    typeof sel === "object" &&
    typeof sel.countryId === "string" &&
    sel.countryId.trim().length > 0 &&
    typeof sel.eventId === "string" &&
    sel.eventId.trim().length > 0 &&
    typeof sel.circuitId === "string" &&
    sel.circuitId.trim().length > 0
  );
}

function sameCircuit(a, b) {
  if (!looksLikeCircuitSelection(a) || !looksLikeCircuitSelection(b)) return false;
  return (
    a.countryId === b.countryId &&
    a.eventId === b.eventId &&
    a.circuitId === b.circuitId
  );
}

function groupTrackingDocRef(sel, adminGroupId) {
  return db
    .collection("marketMap")
    .doc(sel.countryId)
    .collection("events")
    .doc(sel.eventId)
    .collection("circuits")
    .doc(sel.circuitId)
    .collection("group_tracking")
    .doc(adminGroupId);
}

/**
 * Utilitaires géodésiques
 */
const GeoUtils = {
  /**
   * Calcule le centroïde géodésique (précis pour longues distances)
   * @param {Array<{lat, lng, alt, accuracy}>} positions
   * @param {boolean} useWeights - Pondérer par accuracy
   * @returns {{lat, lng, alt}}
   */
  calculateGeodeticCenter(positions, useWeights = true) {
    if (!positions.length) return null;

    let sumX = 0, sumY = 0, sumZ = 0, sumAlt = 0, sumWeights = 0;

    for (const pos of positions) {
      // Poids basé sur accuracy
      const accuracy = Number.isFinite(Number(pos.accuracy))
        ? Number(pos.accuracy)
        : 50;
      const weight = useWeights
        ? 1.0 / (1.0 + accuracy / 50.0)
        : 1.0;

      // Conversion lat/lng en radians
      const latRad = (pos.lat * Math.PI) / 180;
      const lngRad = (pos.lng * Math.PI) / 180;

      // Projection 3D
      const cosLat = Math.cos(latRad);
      const x = cosLat * Math.cos(lngRad);
      const y = cosLat * Math.sin(lngRad);
      const z = Math.sin(latRad);

      // Accumulation pondérée
      sumX += x * weight;
      sumY += y * weight;
      sumZ += z * weight;
      sumAlt += (pos.alt || 0) * weight;
      sumWeights += weight;
    }

    // Normalisation
    const avgX = sumX / sumWeights;
    const avgY = sumY / sumWeights;
    const avgZ = sumZ / sumWeights;
    const avgAlt = sumAlt / sumWeights;

    // Conversion inverse
    const lat =
      (Math.atan2(avgZ, Math.sqrt(avgX * avgX + avgY * avgY)) * 180) /
      Math.PI;
    const lng = (Math.atan2(avgY, avgX) * 180) / Math.PI;

    return { lat, lng, alt: avgAlt };
  },

  /**
   * Calcule poids inversement proportionnels à accuracy
   */
  calculateWeight(accuracy) {
    const a = Number.isFinite(Number(accuracy)) ? Number(accuracy) : 50;
    return 1.0 / (1.0 + a / 50.0);
  },

  /**
   * Distance Haversine (km)
   */
  distanceKm(lat1, lng1, lat2, lng2) {
    const R = 6371;
    const dLat = ((lat2 - lat1) * Math.PI) / 180;
    const dLng = ((lng2 - lng1) * Math.PI) / 180;
    const a =
      Math.sin(dLat / 2) * Math.sin(dLat / 2) +
      Math.cos((lat1 * Math.PI) / 180) *
        Math.cos((lat2 * Math.PI) / 180) *
        Math.sin(dLng / 2) *
        Math.sin(dLng / 2);
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    return R * c;
  },
};

/**
 * Calcule la position moyenne quand un membre met à jour sa position
 * Utilise centroïde géodésique + pondération accuracy
 */
exports.calculateGroupAveragePosition = onDocumentWritten(
  {
    document: "group_positions/{adminGroupId}/members/{uid}",
    region: "us-east1",
    cpu: 0.25,
    memory: "256MiB",
    timeoutSeconds: 60,
    maxInstances: 5,
  },
  async (event) => {
    const adminGroupId = event.params.adminGroupId;

    console.log(`📍 Calcul position moyenne groupe: ${adminGroupId}`);

    try {
      // Récupère toutes les positions des membres
      const membersSnapshot = await db
        .collection("group_positions")
        .doc(adminGroupId)
        .collection("members")
        .get();

      if (membersSnapshot.empty) {
        console.log("⚠️  Aucun membre trouvé => efface averagePosition");
        const adminUid = await findAdminUidByGroupId(adminGroupId);
        if (!adminUid) return;
        await db.collection("group_admins").doc(adminUid).update({
          averagePosition: admin.firestore.FieldValue.delete(),
        });
        return;
      }

      const validPositions = [];
      const fallbackRecentPositions = [];
      const now = Date.now();
      const STRICT_MAX_AGE_MS = 20 * 1000; // 20 secondes (live)
      const FALLBACK_MAX_AGE_MS = 2 * 60 * 1000; // 2 minutes (immobile / réseau)
      const MAX_ACCURACY = 50; // 50 mètres

      let filteredCount = 0;
      const details = [];

      // Filtre positions valides
      membersSnapshot.forEach((doc) => {
        const data = doc.data();
        if (!data.lastPosition) {
          details.push(`${doc.id}: no position`);
          return;
        }

        const pos = data.lastPosition;
        const timestamp = pos.ts?.toMillis?.() || pos.ts || 0;
        const age = now - timestamp;

        // Ignore positions avec mauvaise précision
        if (pos.accuracy != null && Number(pos.accuracy) > MAX_ACCURACY) {
          filteredCount++;
          details.push(`${doc.id}: low accuracy (${pos.accuracy}m)`);
          return;
        }

        // Ignore positions nulles/invalides
        if (!pos.lat || !pos.lng || pos.lat === 0 || pos.lng === 0) {
          filteredCount++;
          details.push(`${doc.id}: invalid (lat=${pos.lat}, lng=${pos.lng})`);
          return;
        }

        // Classement par fraîcheur: live (<=20s) ou fallback (<=2min)
        if (age <= STRICT_MAX_AGE_MS) {
          validPositions.push({
            lat: pos.lat,
            lng: pos.lng,
            alt: (pos.alt ?? pos.altitude) || 0,
            accuracy: pos.accuracy || 0,
            uid: doc.id,
          });
          return;
        }

        if (age <= FALLBACK_MAX_AGE_MS) {
          fallbackRecentPositions.push({
            lat: pos.lat,
            lng: pos.lng,
            alt: (pos.alt ?? pos.altitude) || 0,
            accuracy: pos.accuracy || 0,
            uid: doc.id,
          });
          details.push(`${doc.id}: stale (${age}ms)`);
          return;
        }

        filteredCount++;
        details.push(`${doc.id}: too old (${age}ms)`);
      });

      const usedCount = validPositions.length > 0
        ? validPositions.length
        : fallbackRecentPositions.length;

      console.log(
        `📊 Positions: total=${membersSnapshot.size}, live=${validPositions.length}, fallback<=2min=${fallbackRecentPositions.length}, utilisées=${usedCount}, filtrées=${filteredCount}`
      );
      if (details.length > 0 && details.length <= 5) {
        console.log(`   Détails filtrage: ${details.join(", ")}`);
      }

      const positionsForAverage = validPositions.length > 0
        ? validPositions
        : fallbackRecentPositions;

      if (positionsForAverage.length === 0) {
        console.log("⚠️  Aucune position (live ou fallback) => efface averagePosition");
        const adminUid = await findAdminUidByGroupId(adminGroupId);
        if (!adminUid) return;
        await db.collection("group_admins").doc(adminUid).update({
          averagePosition: admin.firestore.FieldValue.delete(),
        });
        return;
      }

      // Calcule le centroïde géodésique avec pondération
      const avgPos = GeoUtils.calculateGeodeticCenter(positionsForAverage, true);

      if (!avgPos) {
        console.log("❌ Impossible calculer centroïde");
        return;
      }

      console.log(
        `✅ Position moyenne calculée: lat=${avgPos.lat.toFixed(5)}, lng=${avgPos.lng.toFixed(5)}, alt=${avgPos.alt.toFixed(1)}`
      );

      // Calcule distances par rapport à la moyenne
      const distances = positionsForAverage.map((pos) => ({
        uid: pos.uid,
        distance: GeoUtils.distanceKm(pos.lat, pos.lng, avgPos.lat, avgPos.lng) * 1000, // en mètres
      }));

      // Statistiques
      const minDist = Math.min(...distances.map((d) => d.distance));
      const maxDist = Math.max(...distances.map((d) => d.distance));
      const avgDist =
        distances.reduce((sum, d) => sum + d.distance, 0) / distances.length;

      console.log(
        `📏 Distances par rapport moyenne: min=${minDist.toFixed(1)}m, max=${maxDist.toFixed(1)}m, avg=${avgDist.toFixed(1)}m`
      );

      // Récupère l'admin pour trouver son UID
      const adminUid = await findAdminUidByGroupId(adminGroupId);
      if (!adminUid) {
        console.log("❌ Admin non trouvé pour groupe");
        return;
      }

      // Met à jour la position moyenne de l'admin
      const serverTimestamp = admin.firestore.FieldValue.serverTimestamp();
      await db.collection("group_admins").doc(adminUid).update({
        "averagePosition.lat": avgPos.lat,
        "averagePosition.lng": avgPos.lng,
        // Align with GeoPosition.toMap() (client): alt + ts
        "averagePosition.alt": avgPos.alt,
        "averagePosition.ts": serverTimestamp,
        // Back-compat (legacy keys used in older writes)
        "averagePosition.altitude": avgPos.alt,
        "averagePosition.timestamp": serverTimestamp,
        "averagePosition.memberCount": positionsForAverage.length,
        "averagePosition.calculatedAt": serverTimestamp,
        "averagePosition.windowMs": validPositions.length > 0 ? STRICT_MAX_AGE_MS : FALLBACK_MAX_AGE_MS,
        "averagePosition.distances": distances,
        "averagePosition.stats": {
          minDistance: minDist,
          maxDistance: maxDist,
          avgDistance: avgDist,
        },
      });

      console.log(
        `✅ Position moyenne sauvegardée pour admin ${adminUid} (groupe ${adminGroupId})`
      );
    } catch (error) {
      console.error("❌ Erreur calcul position moyenne:", error);
      throw error;
    }
  }
);

/**
 * Publie la position moyenne d'un groupe sur le circuit MarketMap sélectionné par l'admin.
 *
 * Source: group_admins/{adminUid}
 * Dest: marketMap/{countryId}/events/{eventId}/circuits/{circuitId}/group_tracking/{adminGroupId}
 *
 * - Si `isVisible` est false OU circuit non sélectionné OU averagePosition manquante => suppression.
 * - Si circuit change => suppression de l'ancien emplacement.
 */
exports.publishGroupAverageToCircuit = onDocumentWritten(
  {
    document: "group_admins/{adminUid}",
    region: "us-east1",
    cpu: 0.25,
    memory: "256MiB",
    timeoutSeconds: 60,
    maxInstances: 5,
  },
  async (event) => {
    const afterSnap = event.data?.after;
    const beforeSnap = event.data?.before;

    const after = afterSnap && afterSnap.exists ? afterSnap.data() : null;
    const before = beforeSnap && beforeSnap.exists ? beforeSnap.data() : null;

    const adminUid = event.params.adminUid;
    const adminGroupId = (after?.adminGroupId || before?.adminGroupId || "").toString();
    if (!adminGroupId || adminGroupId.trim().length === 0) {
      return;
    }

    const beforeSel = before?.selectedCircuit;
    const afterSel = after?.selectedCircuit;

    // Si changement de circuit => supprimer l'ancien doc.
    if (looksLikeCircuitSelection(beforeSel) && !sameCircuit(beforeSel, afterSel)) {
      try {
        await groupTrackingDocRef(beforeSel, adminGroupId).delete();
      } catch (e) {
        // Delete idempotent: si doc absent, ok.
        console.log("ℹ️ delete old group_tracking skipped:", String(e));
      }
    }

    // Si suppression du doc admin, ou circuit invalide => rien à publier.
    if (!after) {
      return;
    }

    if (!looksLikeCircuitSelection(afterSel)) {
      return;
    }

    const isVisible = after.isVisible !== false;
    const avg = after.averagePosition;

    const lat = Number(avg?.lat);
    const lng = Number(avg?.lng);
    const hasAvg = Number.isFinite(lat) && Number.isFinite(lng) && lat !== 0 && lng !== 0;

    const ref = groupTrackingDocRef(afterSel, adminGroupId);

    if (!isVisible || !hasAvg) {
      try {
        await ref.delete();
      } catch (e) {
        console.log("ℹ️ delete group_tracking skipped:", String(e));
      }
      return;
    }

    const memberCount = typeof avg?.memberCount === "number" ? avg.memberCount : null;
    const displayName = typeof after.displayName === "string" ? after.displayName : "";

    await ref.set(
      {
        adminGroupId,
        adminUid,
        displayName,
        position: new admin.firestore.GeoPoint(lat, lng),
        lat,
        lng,
        ...(memberCount != null ? { memberCount } : {}),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
  }
);
