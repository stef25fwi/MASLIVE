/**
 * Position groupe MASLIVE : agrégation robuste, lissée et limitée en coût.
 */
const { onDocumentWritten } = require("firebase-functions/v2/firestore");
const admin = require("firebase-admin");

if (!admin.apps.length) admin.initializeApp();
const db = admin.firestore();

const CFG = Object.freeze({
  aggregationMs: 15000,
  trackerMaxAgeMs: 90000,
  adminMaxAgeMs: 120000,
  maxAccuracyM: 50,
  maxTrackers: 10,
  idealTrackers: 5,
  maxSpeedMps: 25,
  jumpM: 150,
  jumpConfirmM: 60,
  jumpConfirmAgeMs: 45000,
  smoothingAlpha: 0.35,
  publishMoveM: 5,
  publishHeartbeatMs: 30000,
});

function timestampMs(value) {
  if (!value) return 0;
  if (typeof value.toMillis === "function") return value.toMillis();
  if (value instanceof Date) return value.getTime();
  const number = Number(value);
  return Number.isFinite(number) ? number : 0;
}

function clamp(value, min, max) {
  return Math.min(max, Math.max(min, value));
}

function median(values) {
  if (!values.length) return 0;
  const sorted = [...values].sort((a, b) => a - b);
  const middle = Math.floor(sorted.length / 2);
  return sorted.length % 2
    ? sorted[middle]
    : (sorted[middle - 1] + sorted[middle]) / 2;
}

function validCoordinate(lat, lng) {
  return Number.isFinite(lat) && Number.isFinite(lng) &&
    lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180 &&
    !(lat === 0 && lng === 0);
}

function distanceM(lat1, lng1, lat2, lng2) {
  const r = 6371000;
  const dLat = ((lat2 - lat1) * Math.PI) / 180;
  const dLng = ((lng2 - lng1) * Math.PI) / 180;
  const a = Math.sin(dLat / 2) ** 2 +
    Math.cos((lat1 * Math.PI) / 180) *
      Math.cos((lat2 * Math.PI) / 180) *
      Math.sin(dLng / 2) ** 2;
  return r * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

function roleOf(value) {
  const role = String(value || "").trim().toLowerCase();
  if (role === "tracker") return "tracker";
  if (["admin", "admin_group", "group", "group-admin"].includes(role)) {
    return "admin";
  }
  return "unknown";
}

function parseMember(doc, nowMs) {
  const data = doc.data() || {};
  if (data.isTracking === false) return null;
  const expiresAt = timestampMs(data.expiresAt);
  if (expiresAt && expiresAt < nowMs) return null;

  const raw = data.lastPosition;
  if (!raw || typeof raw !== "object") return null;
  const lat = Number(raw.lat);
  const lng = Number(raw.lng);
  if (!validCoordinate(lat, lng)) return null;

  const accuracyValue = Number(raw.accuracy);
  const accuracy = Number.isFinite(accuracyValue)
    ? accuracyValue
    : CFG.maxAccuracyM;
  if (accuracy < 0 || accuracy > CFG.maxAccuracyM) return null;

  const tsMs = timestampMs(raw.ts || raw.timestamp);
  if (!tsMs) return null;

  const previous = data.previousPosition;
  if (previous && typeof previous === "object") {
    const previousLat = Number(previous.lat);
    const previousLng = Number(previous.lng);
    const previousTs = timestampMs(previous.ts || previous.timestamp);
    if (validCoordinate(previousLat, previousLng) && previousTs && tsMs > previousTs) {
      const elapsed = (tsMs - previousTs) / 1000;
      const travelled = distanceM(previousLat, previousLng, lat, lng);
      if (travelled > 80 && travelled / elapsed > CFG.maxSpeedMps) return null;
    }
  }

  return {
    uid: doc.id,
    role: roleOf(data.role),
    lat,
    lng,
    alt: Number.isFinite(Number(raw.alt ?? raw.altitude))
      ? Number(raw.alt ?? raw.altitude)
      : 0,
    accuracy,
    ageMs: Math.max(0, nowMs - tsMs),
  };
}

function rawWeight(position) {
  const sigma = clamp(Number(position.accuracy) || CFG.maxAccuracyM, 8, 50);
  return (1 / (sigma * sigma)) * Math.exp(-(position.ageMs / 1000) / 45);
}

function weightedCenter(positions) {
  if (!positions.length) return null;
  const rawWeights = positions.map(rawWeight);
  const maxWeight = Math.max(median(rawWeights), 1e-9) * 4;
  let x = 0;
  let y = 0;
  let z = 0;
  let alt = 0;
  let total = 0;

  positions.forEach((position, index) => {
    const weight = Math.min(rawWeights[index], maxWeight);
    const lat = (position.lat * Math.PI) / 180;
    const lng = (position.lng * Math.PI) / 180;
    const cosLat = Math.cos(lat);
    x += cosLat * Math.cos(lng) * weight;
    y += cosLat * Math.sin(lng) * weight;
    z += Math.sin(lat) * weight;
    alt += (position.alt || 0) * weight;
    total += weight;
  });
  if (total <= 0) return null;

  const avgX = x / total;
  const avgY = y / total;
  const avgZ = z / total;
  return {
    lat: (Math.atan2(avgZ, Math.sqrt(avgX ** 2 + avgY ** 2)) * 180) / Math.PI,
    lng: (Math.atan2(avgY, avgX) * 180) / Math.PI,
    alt: alt / total,
  };
}

function robustFilter(positions) {
  if (positions.length < 3) return { kept: positions, removed: 0, thresholdM: null };
  const centerLat = median(positions.map((item) => item.lat));
  const centerLng = median(positions.map((item) => item.lng));
  const distances = positions.map((item) =>
    distanceM(item.lat, item.lng, centerLat, centerLng));
  const medianDistance = median(distances);
  const mad = median(distances.map((value) => Math.abs(value - medianDistance)));
  const thresholdM = clamp(
    Math.max(80, medianDistance + 3 * Math.max(mad, 10)), 80, 250);
  const kept = positions.filter((_, index) => distances[index] <= thresholdM);
  if (kept.length < Math.max(2, Math.ceil(positions.length / 2))) {
    return { kept: positions, removed: 0, thresholdM };
  }
  return { kept, removed: positions.length - kept.length, thresholdM };
}

function choosePositions(candidates) {
  const trackers = candidates
    .filter((item) => item.role === "tracker" && item.ageMs <= CFG.trackerMaxAgeMs)
    .sort((a, b) => rawWeight(b) - rawWeight(a))
    .slice(0, CFG.maxTrackers);
  const admins = candidates
    .filter((item) => item.role === "admin" && item.ageMs <= CFG.adminMaxAgeMs)
    .sort((a, b) => rawWeight(b) - rawWeight(a));

  if (trackers.length >= 2) {
    return { positions: trackers, trackerCount: trackers.length,
      adminFallbackUsed: false, source: "trackers" };
  }
  if (trackers.length === 1 && admins.length) {
    return { positions: [trackers[0], admins[0]], trackerCount: 1,
      adminFallbackUsed: true, source: "tracker_plus_admin_fallback" };
  }
  if (trackers.length === 1) {
    return { positions: trackers, trackerCount: 1,
      adminFallbackUsed: false, source: "single_tracker" };
  }
  if (admins.length) {
    return { positions: [admins[0]], trackerCount: 0,
      adminFallbackUsed: true, source: "admin_fallback_only" };
  }
  return { positions: [], trackerCount: 0,
    adminFallbackUsed: false, source: "none" };
}

function qualityLabel(trackerCount, fallback) {
  if (trackerCount >= CFG.idealTrackers) return "optimal";
  if (trackerCount >= 3) return "good";
  if (trackerCount === 2) return "acceptable";
  if (trackerCount === 1 && !fallback) return "low";
  return "fallback";
}

function smoothedCenter(candidate, average, nowMs) {
  const oldLat = Number(average?.lat);
  const oldLng = Number(average?.lng);
  if (!validCoordinate(oldLat, oldLng)) {
    return { status: "accepted", center: candidate, jumpConfirmed: false };
  }

  if (distanceM(oldLat, oldLng, candidate.lat, candidate.lng) > CFG.jumpM) {
    const pending = average?.pendingJump;
    const pendingLat = Number(pending?.lat);
    const pendingLng = Number(pending?.lng);
    const coherent = validCoordinate(pendingLat, pendingLng) &&
      nowMs - timestampMs(pending?.observedAt) <= CFG.jumpConfirmAgeMs &&
      distanceM(pendingLat, pendingLng, candidate.lat, candidate.lng) <=
        CFG.jumpConfirmM;
    if (!coherent) {
      return { status: "jump_pending", center: { lat: oldLat, lng: oldLng,
        alt: candidate.alt }, pendingJump: candidate, jumpConfirmed: false };
    }
    return { status: "accepted", center: candidate, jumpConfirmed: true };
  }

  const alpha = CFG.smoothingAlpha;
  return {
    status: "accepted",
    center: {
      lat: oldLat * (1 - alpha) + candidate.lat * alpha,
      lng: oldLng * (1 - alpha) + candidate.lng * alpha,
      alt: Number(average?.alt || 0) * (1 - alpha) +
        Number(candidate.alt || 0) * alpha,
    },
    jumpConfirmed: false,
  };
}

async function findAdmin(adminGroupId) {
  const snapshot = await db.collection("group_admins")
    .where("adminGroupId", "==", adminGroupId).limit(1).get();
  return snapshot.empty ? null : snapshot.docs[0];
}

async function acquireSlot(adminGroupId, force) {
  const ref = db.collection("group_positions").doc(adminGroupId)
    .collection("meta").doc("aggregation");
  const now = Date.now();
  let acquired = false;
  await db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(ref);
    const last = snapshot.exists ? timestampMs(snapshot.data()?.lastRunAt) : 0;
    if (!force && now - last < CFG.aggregationMs) return;
    transaction.set(ref, {
      lastRunAt: admin.firestore.Timestamp.fromMillis(now),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
    acquired = true;
  });
  return acquired;
}

function validSelection(value) {
  return value && typeof value === "object" &&
    [value.countryId, value.eventId, value.circuitId]
      .every((part) => typeof part === "string" && part.trim());
}

function sameSelection(a, b) {
  return validSelection(a) && validSelection(b) &&
    a.countryId === b.countryId && a.eventId === b.eventId &&
    a.circuitId === b.circuitId;
}

function circuitRef(selection, adminGroupId) {
  return db.collection("marketMap").doc(selection.countryId)
    .collection("events").doc(selection.eventId)
    .collection("circuits").doc(selection.circuitId)
    .collection("group_tracking").doc(adminGroupId);
}

exports.calculateGroupAveragePosition = onDocumentWritten({
  document: "group_positions/{adminGroupId}/members/{uid}",
  region: "us-east1", cpu: 0.25, memory: "256MiB",
  timeoutSeconds: 60, maxInstances: 5,
}, async (event) => {
  const adminGroupId = event.params.adminGroupId;
  const after = event.data?.after;

  // Nettoyage avec droits serveur après marquage isTracking=false par le client.
  if (after?.exists && after.data()?.isTracking === false) {
    await after.ref.delete();
    return;
  }

  const deletion = !after?.exists;
  if (!(await acquireSlot(adminGroupId, deletion))) return;

  const members = await db.collection("group_positions").doc(adminGroupId)
    .collection("members").get();
  const now = Date.now();
  const candidates = members.docs.map((doc) => parseMember(doc, now)).filter(Boolean);
  const selection = choosePositions(candidates);
  const adminDoc = await findAdmin(adminGroupId);
  if (!adminDoc) return;

  if (!selection.positions.length) {
    await adminDoc.ref.update({
      averagePosition: admin.firestore.FieldValue.delete(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    return;
  }

  const robust = robustFilter(selection.positions);
  const rawCenter = weightedCenter(robust.kept);
  if (!rawCenter) return;
  const resolved = smoothedCenter(rawCenter, adminDoc.data()?.averagePosition, now);
  const serverTime = admin.firestore.FieldValue.serverTimestamp();

  if (resolved.status === "jump_pending") {
    await adminDoc.ref.update({
      "averagePosition.pendingJump": {
        lat: rawCenter.lat, lng: rawCenter.lng, alt: rawCenter.alt || 0,
        observedAt: serverTime,
      },
      "averagePosition.rawCandidate": { lat: rawCenter.lat, lng: rawCenter.lng },
      "averagePosition.qualityStatus": "jump_pending",
      "averagePosition.calculatedAt": serverTime,
      updatedAt: serverTime,
    });
    return;
  }

  const center = resolved.center;
  const distances = robust.kept.map((item) =>
    distanceM(item.lat, item.lng, center.lat, center.lng));
  const minDistance = Math.min(...distances);
  const maxDistance = Math.max(...distances);
  const avgDistance = distances.reduce((sum, value) => sum + value, 0) /
    distances.length;

  await adminDoc.ref.update({
    "averagePosition.lat": center.lat,
    "averagePosition.lng": center.lng,
    "averagePosition.alt": center.alt || 0,
    "averagePosition.ts": serverTime,
    "averagePosition.altitude": center.alt || 0,
    "averagePosition.timestamp": serverTime,
    "averagePosition.calculatedAt": serverTime,
    "averagePosition.pendingJump": admin.firestore.FieldValue.delete(),
    "averagePosition.rawCandidate": { lat: rawCenter.lat, lng: rawCenter.lng },
    "averagePosition.memberCount": robust.kept.length,
    "averagePosition.trackerCount": selection.trackerCount,
    "averagePosition.activeMemberCount": candidates.length,
    "averagePosition.adminFallbackUsed": selection.adminFallbackUsed,
    "averagePosition.source": selection.source,
    "averagePosition.qualityStatus": qualityLabel(
      selection.trackerCount, selection.adminFallbackUsed),
    "averagePosition.jumpConfirmed": resolved.jumpConfirmed,
    "averagePosition.outliersRemoved": robust.removed,
    "averagePosition.outlierThresholdM": robust.thresholdM,
    "averagePosition.windowMs": CFG.trackerMaxAgeMs,
    "averagePosition.recommendedTrackerCount": CFG.idealTrackers,
    "averagePosition.maxTrackerCount": CFG.maxTrackers,
    "averagePosition.stats": { minDistance, maxDistance, avgDistance },
    updatedAt: serverTime,
  });
});

exports.publishGroupAverageToCircuit = onDocumentWritten({
  document: "group_admins/{adminUid}",
  region: "us-east1", cpu: 0.25, memory: "256MiB",
  timeoutSeconds: 60, maxInstances: 5,
}, async (event) => {
  const after = event.data?.after?.exists ? event.data.after.data() : null;
  const before = event.data?.before?.exists ? event.data.before.data() : null;
  const adminGroupId = String(after?.adminGroupId || before?.adminGroupId || "").trim();
  if (!adminGroupId) return;

  if (validSelection(before?.selectedCircuit) &&
      !sameSelection(before.selectedCircuit, after?.selectedCircuit)) {
    await circuitRef(before.selectedCircuit, adminGroupId).delete().catch(() => {});
  }
  if (!after || !validSelection(after.selectedCircuit)) return;

  const ref = circuitRef(after.selectedCircuit, adminGroupId);
  const lat = Number(after.averagePosition?.lat);
  const lng = Number(after.averagePosition?.lng);
  if (after.isVisible === false || !validCoordinate(lat, lng)) {
    await ref.delete().catch(() => {});
    return;
  }

  const existing = await ref.get();
  if (existing.exists) {
    const data = existing.data() || {};
    const oldLat = Number(data.lat);
    const oldLng = Number(data.lng);
    if (validCoordinate(oldLat, oldLng) &&
        distanceM(oldLat, oldLng, lat, lng) < CFG.publishMoveM &&
        Date.now() - timestampMs(data.updatedAt) < CFG.publishHeartbeatMs) {
      return;
    }
  }

  await ref.set({
    adminGroupId,
    adminUid: event.params.adminUid,
    displayName: typeof after.displayName === "string" ? after.displayName : "",
    position: new admin.firestore.GeoPoint(lat, lng),
    lat,
    lng,
    memberCount: after.averagePosition?.memberCount ?? null,
    trackerCount: after.averagePosition?.trackerCount ?? null,
    qualityStatus: after.averagePosition?.qualityStatus || "unknown",
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  }, { merge: true });
});

exports.__test = {
  clamp,
  median,
  distanceM,
  rawWeight,
  weightedCenter,
  robustFilter,
  choosePositions,
  qualityLabel,
  smoothedCenter,
};
