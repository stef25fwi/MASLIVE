/**
 * Cloud Function Firebase Gen2
 * Calcul automatique position moyenne groupe
 * Trigger: group_positions/{adminGroupId}/members/{uid}
 */

const { onDocumentWritten } = require("firebase-functions/v2/firestore");
const admin = require("firebase-admin");

// index.js initialise déjà admin.initializeApp(), mais on garde ce garde-fou.
if (!admin.apps.length) {
  admin.initializeApp();
}
const db = admin.firestore();

/**
 * Calcule la position moyenne quand un membre met à jour sa position
 */
exports.calculateGroupAveragePosition = onDocumentWritten(
  "group_positions/{adminGroupId}/members/{uid}",
  async (event) => {
    const adminGroupId = event.params.adminGroupId;
    
    console.log(`Calcul position moyenne pour groupe: ${adminGroupId}`);

    try {
      // Récupère toutes les positions des membres du groupe
      const membersSnapshot = await db
        .collection("group_positions")
        .doc(adminGroupId)
        .collection("members")
        .get();

      if (membersSnapshot.empty) {
        console.log("Aucun membre trouvé");
        return;
      }

      const validPositions = [];
      const now = Date.now();
      const MAX_AGE_MS = 20 * 1000; // 20 secondes
      const MAX_ACCURACY = 50; // 50 mètres

      // Filtre positions valides
      membersSnapshot.forEach((doc) => {
        const data = doc.data();
        if (!data.lastPosition) return;

        const pos = data.lastPosition;
        const timestamp = pos.ts?.toMillis() || 0;
        const age = now - timestamp;

        // Ignore positions trop anciennes
        if (age > MAX_AGE_MS) {
          console.log(`Position ${doc.id} trop ancienne: ${age}ms`);
          return;
        }

        // Ignore positions avec mauvaise précision
        if (pos.accuracy && pos.accuracy > MAX_ACCURACY) {
          console.log(`Position ${doc.id} mauvaise précision: ${pos.accuracy}m`);
          return;
        }

        // Ignore positions nulles
        if (pos.lat === 0 && pos.lng === 0) {
          console.log(`Position ${doc.id} nulle`);
          return;
        }

        validPositions.push({
          lat: pos.lat,
          lng: pos.lng,
          alt: pos.alt,
        });
      });

      if (validPositions.length === 0) {
        console.log("Aucune position valide trouvée");
        return;
      }

      console.log(`${validPositions.length} positions valides trouvées`);

      // Calcule moyenne
      let sumLat = 0;
      let sumLng = 0;
      let sumAlt = 0;
      let altCount = 0;

      validPositions.forEach((pos) => {
        sumLat += pos.lat;
        sumLng += pos.lng;
        if (pos.alt != null) {
          sumAlt += pos.alt;
          altCount++;
        }
      });

      const avgLat = sumLat / validPositions.length;
      const avgLng = sumLng / validPositions.length;
      const avgAlt = altCount > 0 ? sumAlt / altCount : null;

      const averagePosition = {
        lat: avgLat,
        lng: avgLng,
        alt: avgAlt,
        accuracy: null,
        ts: new Date(),
      };

      console.log(`Position moyenne calculée: ${avgLat}, ${avgLng}`);

      // Met à jour dans le profil admin
      const adminSnapshot = await db
        .collection("group_admins")
        .where("adminGroupId", "==", adminGroupId)
        .limit(1)
        .get();

      if (adminSnapshot.empty) {
        console.log("Admin non trouvé");
        return;
      }

      const adminDoc = adminSnapshot.docs[0];
      await adminDoc.ref.update({
        averagePosition: averagePosition,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      console.log("Position moyenne mise à jour avec succès");
    } catch (error) {
      console.error("Erreur calcul position moyenne:", error);
      throw error;
    }
  }
);
