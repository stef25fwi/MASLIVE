/**
 * Tracking groupe MASLIVE — calcul robuste et économe.
 *
 * Pipeline :
 * - les trackers publient au maximum toutes les 15/45/60 secondes ;
 * - cette fonction agrège au maximum une fois toutes les 15 secondes ;
 * - seuls les trackers entrent dans la moyenne normale ;
 * - la position de l'admin n'est utilisée qu'en secours ;
 * - pondération précision + fraîcheur, filtre médiane/MAD et lissage ;
 * - publication circuit seulement après déplacement >= 5 m ou heartbeat 30 s.
 */

const { onDocumentWritten } = require("firebase-functions/v2/firestore");
const admin = require("firebase-admin");

if (!admin.apps.length) {
  admin.initializeApp();
}
const db = admin.firestore();

const AGGREGATION_INTERVAL_MS = 15 * 1000;
const TRACKER_MAX_AGE_MS = 90 * 1000;
const ADMIN_FALLBACK_MAX_AGE_MS = 120 * 1000;
const MAX_ACCURACY_M = 50;
const MAX_ACTIVE_TRACKERS = 10;
const IDEAL_TRACKER_COUNT = 5;
const MAX_PLAUSIBLE_SPEED_MPS = 25;
const MAX_JUMP_M = 150;
const JUMP_CONFIRM_DISTANCE_M = 60;
const JUMP_CONFIRM_MAX_AGE_MS = 45 * 1000;
const SMOOTHING_ALPHA = 0.35;
const PUBLICATION_MIN_MOVE_M = 5;
const PUBLICATION_HEARTBEAT_MS = 30 * 1000;

function timestampMs(value) {
  if (!value) return 0;
  if (typeof value.toMillis === "function") return value.toMillis();
  if (value instanceof Date) return value.getTime();
  const numeric = Number(value);
  return Number.isFinite(numeric) ? numeric : 0;
}

function clamp(value, min, max) {
  return Math.min(max, Math.max(min, value));
}

function median(values) {
  if (!Array.isArray(values) || values.length === 0) return 0;
  const sorted = [...values].sort((a, b) => a - b);
  const middle = Math.floor(sorted.length / 2);
  return sorted.length % 2 === 0
    ? (sorted[middle - 1] + sorted[middle]) / 2
    : sorted[middle];
}

function isValidCoordinate(lat, lng) {
  return (
    Number.isFinite(lat) &&
    Number.isFinite(lng) &&
    lat >= -90 &&
    lat <= 90 &&
    lng >= -180 &&
    lng <= 180 &&
    !(lat === 0 && lng === 0)
  );
}

function distanceM(lat1, lng1, lat2, lng2) {
  const earthRadiusM = 6371000;
  const dLat = ((lat2 - lat1) * Math.PI) / 180;
  const dLng = ((lng2 - lng1) * Math.PI) / 180;
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos((lat1 * Math.PI) / 180) *
      Math.cos((lat2 * Math.PI) / 180) *
      Math.sin(dLng / 2) ** 2;
  return earthRadiusM * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

function normalizeRole(value) {
  const role = String(value || "").trim().toLowerCase();
  if (role === "tracker") return "tracker";
  if (["admin", "admin_group", "group", "group-admin"].includes(role)) {
    return "admin";
  }
  return "unknown";
}

function parseMemberPosition(doc, nowMs) {
  const data = doc.data() || {};
  if (data.isTracking === false) return null;

  const expiresAtMs = timestampMs(data.expiresAt);
  if (expiresAtMs > 0 && expiresAtMs < nowMs) return null;

  const raw = data.lastPosition;
  if (!raw || typeof raw !== "object") return null;

  const lat = Number(raw.lat);
  const lng = Number(raw.lng);
  if (!isValidCoordinate(lat, lng)) return null;

  const accuracyValue = Number(raw.accuracy);
  const accuracy = Number.isFinite(accuracyValue) ? accuracyValue : MAX_ACCURACY_M;
  if (accuracy < 0 || accuracy > MAX_ACCURACY_M) return null;

  const tsMs = timestampMs(raw.ts || raw.timestamp);
  if (tsMs <= 0) return null;
  const ageMs = Math.max(0, nowMs - tsMs);

  const previous = data.previousPosition;
  if (previous && typeof previous === "object") {
    const previousLat = Number(previous.lat);
    const previousLng = Number(previous.lng);
    const previousTsMs = timestampMs(previous.ts || previous.timestamp);
    if (
      isValidCoordinate(previousLat, previousLng) &&
      previousTsMs > 0 &&
      tsMs > previousTsMs
    ) {
      const elapsedSeconds = (tsMs - previousTsMs) / 1000;
      const travelledM = distanceM(previousLat, previousLng, lat, lng);
      const speedMps = travelledM / elapsedSeconds;
      if (travelledM > 80 && speedMps > MAX_PLAUSIBLE_SPEED_MPS) {
        return null;
      }
    }
  }

  return {
    uid: doc.id,
    role: normalizeRole(data.role),
    lat,
    lng,
    alt: Number.isFinite(Number(raw.alt ?? raw.altitude))
      ? Number(raw.alt ?? raw.altitude)
      : 0,
    accuracy,
    tsMs,
    ageMs,
  };
}

function rawPositionWeight(position) {
  const sigma = clamp(Number(position.accuracy) || MAX_ACCURACY_M, 8, 50);
  const ageSeconds = Math.max(0, Number(position.ageMs) || 0) / 1000;
  const accuracyWeight = 1 / (sigma * sigma);
  const ageWeight = Math.exp(-ageSeconds / 45);
  return accuracyWeight * ageWeight;
}

function withCappedWeights(positions) {
  const rawWeights = positions.map(rawPositionWeight);
  const medianWeight = Math.max(median(rawWeights), 1e-9);
  const maxWeight = medianWeight * 4;
  return positions.map((position, index) => ({
    ...position,
    weight: Math.min(rawWeights[index], maxWeight),
  }));
}

function calculateWeightedGeodeticCenter(positions) {
  if (!positions.length) return null;
  const weighted = withCappedWeights(positions);

  let sumX = 0;
  let sumY = 0;
  let sumZ = 0;
  let sumAlt = 0;
  let sumWeights = 0;

  for (const position of weighted) {
    const latRad = (position.lat * Math.PI) / 180;
    const lngRad = (position.lng * Math.PI) / 180;
    const cosLat = Math.cos(latRad);
    const weight = position.weight;

    sumX += cosLat * Math.cos(lngRad) * weight;
    sumY += cosLat * Math.sin(lngRad) * weight;
    sumZ += Math.sin(latRad) * weight;
    sumAlt += (position.alt || 0) * weight;
    sumWeights += weight;
  }

  if (sumWeights <= 0) return null;
  const avgX = sumX / sumWeights;
  const avgY = sumY / sumWeights;
  const avgZ = sumZ / sumWeights;

  return {
    lat:
      (Math.atan2(avgZ, Math.sqrt(avgX * avgX + avgY * avgY)) * 180) /
      Math.PI,
    lng: (Math.atan2(avgY, avgX) * 180) / Math.PI,
    alt: sumAlt / sumWeights,
  };
}

function robustFilterPositions(positions) {
  if (positions.length < 3) {
    return { kept: positions, removed: 0, thresholdM: null };
  }

  const medianLat = median(positions.map((position) => position.lat));
  const medianLng = median(positions.map((position) => position.lng));
  const distances = positions.map((position) =>
    distanceM(position.lat, position.lng, medianLat, medianLng)
  );
  const medianDistance = median(distances);
  const mad = median(distances.map((value) => Math.abs(value - medianDistance)));
  const thresholdM = clamp(
    Math.max(80, medianDistance + 3 * Math.max(mad, 10)),
    80,
    250
  );

  const kept = positions.filter((_, index) => distances[index] <= thresholdM);
  const minimumKept = Math.max(2, Math.ceil(positions.length / 2));
  if (kept.length < minimumKept) {
    return { kept: positions, removed: 0, thresholdM };
  }

  return {
    kept,
    removed: positions.length - kept.length,
    thresholdM,
  };
}

function choosePositions(candidates) {
  const trackers = candidates
    .filter(
      (position) =>
        position.role === "tracker" && position.ageMs <= TRACKER_MAX_AGE_MS
    )
    .sort((a, b) => rawPositionWeight(b) - rawPositionWeight(a))
    .slice(0, MAX_ACTIVE_TRACKERS);
  const admins = candidates
    .filter(
      (position) =>
        position.role === "admin" && position.ageMs <= ADMIN_FALLBACK_MAX_AGE_MS
    )
    .sort((a, b) => rawPositionWeight(b) - rawPositionWeight(a));

  if (trackers.length >= 2) {
    return {
      positions: trackers,
      trackerCount: trackers.length,
      adminFallbackUsed: false,
      source: "trackers",
    };
  }
  if (trackers.length === 1 && admins.length > 0) {
    return {
      positions: [trackers[0], admins[0]],
      trackerCount: 1,
      adminFallbackUsed: true,
      source: "tracker_plus_admin_fallback",
    };
  }
  if (trackers.length === 1) {
    return {
      positions: trackers,
      trackerCount: 1,
      adminFallbackUsed: false,
      source: "single_tracker",
    };
  }
  if (admins.length > 0) {
    return {
      positions: [admins[0]],
      trackerCount: 0,
      adminFallbackUsed: true,
      source: "admin_fallback_only",
    };
  }
  return {
    positions: [],
    trackerCount: 0,
    adminFallbackUsed: false,
    source: "none",
  };
}

function qualityLabel(trackerCount, adminFallbackUsed) {
  if (trackerCount >= 3) return trackerCount >= IDEAL_TRACKER_COUNT ? "optimal" : "good";
  if (trackerCount === 2) return "acceptable";
  if (trackerCount === 1 && !adminFallbackUsed) return "low";
  return "fallback";
}

async function findAdminDocument(adminGroupId) {
  const snapshot = await db
    .collection("group_admins")
    .where("adminGroupId", "==", adminGroupId)
    .limit(1)
    .get();
  return snapshot.empty ? null : snapshot.docs[0];
}

async function acquireAggregationSlot(adminGroupId, force = false) {
  const lockRef = db
    .collection("group_positions")
    .doc(adminGroupId)
    .collection("meta")
    .doc("aggregation");
  const nowMs = Date.now();
  let acquired = false;

  await db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(lockRef);
    const lastRunAtMs = snapshot.exists
      ? timestampMs(snapshot.data()?.lastRunAt)
      : 0;
    if (!force && nowMs - lastRunAtMs < AGGREGATION_INTERVAL_MS) {
      return;
    }
    transaction.set(
      lockRef,
      {
        lastRunAt: admin.firestore.Timestamp.fromMillis(nowMs),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
    acquired = true;
  });

  return acquired;
}

function resolveSmoothedCenter(candidate, averagePosition, nowMs) {
  const previousLat = Number(averagePosition?.lat);
  const previousLng = Number(averagePosition?.lng);
  if (!isValidCoordinate(previousLat, previousLng)) {
    return { status: "accepted", center: candidate, jumpConfirmed: false };
  }

  const jumpM = distanceM(previousLat, previousLng, candidate.lat, candidate.lng);
  if (jumpM > MAX_JUMP_M) {
    const pending = averagePosition?.pendingJump;
    const pendingLat = Number(pending?.lat);
    const pendingLng = Number(pending?.lng);
    const pendingAtMs = timestampMs(pending?.observedAt);
    const coherentPending =
      isValidCoordinate(pendingLat, pendingLng) &&
      nowMs - pendingAtMs <= JUMP_CONFIRM_MAX_AGE_MS &&
      distanceM(pendingLat, pendingLng, candidate.lat, candidate.lng) <=
        JUMP_CONFIRM_DISTANCE_M;

    if (!coherentPending) {
      return {
        status: "jump_pending",
        center: { lat: previousLat, lng: previousLng, alt: candidate.alt },
        pendingJump: candidate,
        jumpConfirmed: false,
      };
    }

    return { status: "accepted", center: candidate, jumpConfirmed: true };
  }

  return {
    status: "accepted",
    center: {
      lat: previousLat * (1 - SMOOTHING_ALPHA) + candidate.lat * SMOOTHING_ALPHA,
      lng: previousLng * (1 - SMOOTHING_ALPHA) + candidate.lng * SMOOTHING_ALPHA,
      alt:
        Number(averagePosition?.alt || 0) * (1 - SMOOTHING_ALPHA) +
        Number(candidate.alt || 0) * SMOOTHING_ALPHA,
    },
    jumpConfirmed: false,
  };
}

function looksLikeCircuitSelection(selection) {
  return (
    selection &&
    typeof selection === "object" &&
    typeof selection.countryId === "string" &&
    selection.countryId.trim().length > 0 &&
    typeof selection.eventId === "string" &&
    selection.eventId.trim().length > 0 &&
    typeof selection.circuitId === "string" &&
    selection.circuitId.trim().length > 0
  );
}

function sameCircuit(a, b) {
  return (
    looksLikeCircuitSelection(a) &&
    looksLikeCircuitSelection(b) &&
    a.countryId === b.countryId &&
    a.eventId === b.eventId &&
    a.circuitId === b.circuitId
  );
}

function groupTrackingDocRef(selection, adminGroupId) {
  return db
    .collection("marketMap")
    .doc(selection.countryId)
    .collection("events")
    .doc(selection.eventId)
    .collection("circuits")
    .doc(selection.circuitId)
    .collection("group_tracking")
    .doc(adminGroupId);
}

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
    const deletion = !event.data?.after?.exists;
    if (!(await acquireAggregationSlot(adminGroupId, deletion))) {
      return;
    }

    const membersSnapshot = await db
      .collection("group_positions")
      .doc(adminGroupId)
      .collection("members")
      .get();
    const nowMs = Date.now();
    const candidates = membersSnapshot.docs
      .map((doc) => parseMemberPosition(doc, nowMs))
      .filter(Boolean);
    const selection = choosePositions(candidates);
    const adminDoc = await findAdminDocument(adminGroupId);
    if (!adminDoc) return;

    if (selection.positions.length === 0) {
      await adminDoc.ref.update({
        averagePosition: admin.firestore.FieldValue.delete(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      return;
    }

    const robust = robustFilterPositions(selection.positions);
    const candidateCenter = calculateWeightedGeodeticCenter(robust.kept);
    if (!candidateCenter) return;

    const adminData = adminDoc.data() || {};
    const resolved = resolveSmoothedCenter(
      candidateCenter,
      adminData.averagePosition,
      nowMs
    );
    const serverTimestamp = admin.firestore.FieldValue.serverTimestamp();

    if (resolved.status === "jump_pending") {
      await adminDoc.ref.update({
        "averagePosition.pendingJump": {
          lat: resolved.pendingJump.lat,
          lng: resolved.pendingJump.lng,
          alt: resolved.pendingJump.alt || 0,
          observedAt: serverTimestamp,
        },
        "averagePosition.qualityStatus": "jump_pending",
        "averagePosition.calculatedAt": serverTimestamp,
        "averagePosition.rawCandidate": {
          lat: candidateCenter.lat,
          lng: candidateCenter.lng,
        },
        updatedAt: serverTimestamp,
      });
      return;
    }

    const finalCenter = resolved.center;
    const distances = robust.kept.map((position) =>
      distanceM(position.lat, position.lng, finalCenter.lat, finalCenter.lng)
    );
    const minDistance = Math.min(...distances);
    const maxDistance = Math.max(...distances);
    const averageDistance =
      distances.reduce((sum, value) => sum + value, 0) / distances.length;

    await adminDoc.ref.update({
      "averagePosition.lat": finalCenter.lat,
      "averagePosition.lng": finalCenter.lng,
      "averagePosition.alt": finalCenter.alt || 0,
      "averagePosition.ts": serverTimestamp,
      "averagePosition.altitude": finalCenter.alt || 0,
      "averagePosition.timestamp": serverTimestamp,
      "averagePosition.calculatedAt": serverTimestamp,
      "averagePosition.pendingJump": admin.firestore.FieldValue.delete(),
      "averagePosition.rawCandidate": {
        lat: candidateCenter.lat,
        lng: candidateCenter.lng,
      },
      "averagePosition.memberCount": robust.kept.length,
      "averagePosition.trackerCount": selection.trackerCount,
      "averagePosition.activeMemberCount": candidates.length,
      "averagePosition.adminFallbackUsed": selection.adminFallbackUsed,
      "averagePosition.source": selection.source,
      "averagePosition.qualityStatus": qualityLabel(
        selection.trackerCount,
        selection.adminFallbackUsed
      ),
      "averagePosition.jumpConfirmed": resolved.jumpConfirmed,
      "averagePosition.outliersRemoved": robust.removed,
      "averagePosition.outlierThresholdM": robust.thresholdM,
      "averagePosition.windowMs": TRACKER_MAX_AGE_MS,
      "averagePosition.recommendedTrackerCount": IDEAL_TRACKER_COUNT,
      "averagePosition.maxTrackerCount": MAX_ACTIVE_TRACKERS,
      "averagePosition.stats": {
        minDistance,
        maxDistance,
        avgDistance: averageDistance,
      },
      updatedAt: serverTimestamp,
    });
  }
);

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
    const afterSnapshot = event.data?.after;
    const beforeSnapshot = event.data?.before;
    const after = afterSnapshot?.exists ? afterSnapshot.data() : null;
    const before = beforeSnapshot?.exists ? beforeSnapshot.data() : null;
    const adminUid = event.params.adminUid;
    const adminGroupId = String(
      after?.adminGroupId || before?.adminGroupId || ""
    ).trim();
    if (!adminGroupId) return;

    const beforeSelection = before?.selectedCircuit;
    const afterSelection = after?.selectedCircuit;
    if (
      looksLikeCircuitSelection(beforeSelection) &&
      !sameCircuit(beforeSelection, afterSelection)
    ) {
      await groupTrackingDocRef(beforeSelection, adminGroupId).delete().catch(() => {});
    }

    if (!after || !looksLikeCircuitSelection(afterSelection)) return;
    const ref = groupTrackingDocRef(afterSelection, adminGroupId);
    const average = after.averagePosition;
    const lat = Number(average?.lat);
    const lng = Number(average?.lng);
    const hasAverage = isValidCoordinate(lat, lng);
    const isVisible = after.isVisible !== false;

    if (!isVisible || !hasAverage) {
      await ref.delete().catch(() => {});
      return;
    }

    const existing = await ref.get();
    if (existing.exists) {
      const existingData = existing.data() || {};
      const oldLat = Number(existingData.lat);
      const oldLng = Number(existingData.lng);
      const updatedAtMs = timestampMs(existingData.updatedAt);
      if (isValidCoordinate(oldLat, oldLng)) {
        const movedM = distanceM(oldLat, oldLng, lat, lng);
        if (
          movedM < PUBLICATION_MIN_MOVE_M &&
          Date.now() - updatedAtMs < PUBLICATION_HEARTBEAT_MS
        ) {
          return;
        }
      }
    }

    await ref.set(
      {
        adminGroupId,
        adminUid,
        displayName:
          typeof after.displayName === "string" ? after.displayName : "",
        position: new admin.firestore.GeoPoint(lat, lng),
        lat,
        lng,
        memberCount:
          typeof average?.memberCount === "number"
            ? average.memberCount
            : null,
        trackerCount:
          typeof average?.trackerCount === "number"
            ? average.trackerCount
            : null,
        qualityStatus: average?.qualityStatus || "unknown",
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
  }
);

exports.__test = {
  clamp,
  median,
  distanceM,
  rawPositionWeight,
  calculateWeightedGeodeticCenter,
  robustFilterPositions,
  choosePositions,
  qualityLabel,
  resolveSmoothedCenter,
};
