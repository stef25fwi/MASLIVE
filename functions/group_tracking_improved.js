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
      const weight = useWeights
        ? 1.0 / (1.0 + (pos.accuracy || 50) / 50.0)
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
    return 1.0 / (1.0 + (accuracy || 50) / 50.0);
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
  "group_positions/{adminGroupId}/members/{uid}",
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
        console.log("❌ Aucun membre trouvé");
        return;
      }

      const validPositions = [];
      const now = Date.now();
      const MAX_AGE_MS = 20 * 1000; // 20 secondes
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

        // Ignore positions trop anciennes
        if (age > MAX_AGE_MS) {
          filteredCount++;
          details.push(`${doc.id}: too old (${age}ms)`);
          return;
        }

        // Ignore positions avec mauvaise précision
        if (pos.accuracy && pos.accuracy > MAX_ACCURACY) {
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

        validPositions.push({
          lat: pos.lat,
          lng: pos.lng,
          alt: pos.altitude || 0,
          accuracy: pos.accuracy || 0,
          uid: doc.id,
        });
      });

      console.log(
        `📊 Positions: total=${membersSnapshot.size}, valides=${validPositions.length}, filtrées=${filteredCount}`
      );
      if (details.length > 0 && details.length <= 5) {
        console.log(`   Détails filtrage: ${details.join(", ")}`);
      }

      if (validPositions.length === 0) {
        console.log("⚠️  Aucune position valide");
        return;
      }

      // Calcule le centroïde géodésique avec pondération
      const avgPos = GeoUtils.calculateGeodeticCenter(validPositions, true);

      if (!avgPos) {
        console.log("❌ Impossible calculer centroïde");
        return;
      }

      console.log(
        `✅ Position moyenne calculée: lat=${avgPos.lat.toFixed(5)}, lng=${avgPos.lng.toFixed(5)}, alt=${avgPos.alt.toFixed(1)}`
      );

      // Calcule distances par rapport à la moyenne
      const distances = validPositions.map((pos) => ({
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
      const adminSnapshot = await db
        .collection("group_admins")
        .where("adminGroupId", "==", adminGroupId)
        .limit(1)
        .get();

      if (adminSnapshot.empty) {
        console.log("❌ Admin non trouvé pour groupe");
        return;
      }

      const adminUid = adminSnapshot.docs[0].id;

      // Met à jour la position moyenne de l'admin
      const serverTimestamp = admin.firestore.FieldValue.serverTimestamp();
      await db.collection("group_admins").doc(adminUid).update({
        "averagePosition.lat": avgPos.lat,
        "averagePosition.lng": avgPos.lng,
        "averagePosition.altitude": avgPos.alt,
        "averagePosition.timestamp": serverTimestamp,
        "averagePosition.memberCount": validPositions.length,
        "averagePosition.calculatedAt": serverTimestamp,
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
