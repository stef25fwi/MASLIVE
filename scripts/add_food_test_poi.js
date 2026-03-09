
const crypto = require('crypto');

// eslint-disable-next-line import/no-unresolved, global-require
const serviceAccount = require('../serviceAccountKey.json');

function parseArgs(argv) {
  const opts = {
    countryId: null,
    eventId: null,
    eventName: 'maslive test',
    circuitId: null,
    circuitName: null,
    poiId: null,
  };

  for (const arg of argv) {
    if (arg.startsWith('--country-id=')) opts.countryId = arg.split('=')[1] || null;
    if (arg.startsWith('--event-id=')) opts.eventId = arg.split('=')[1] || null;
    if (arg.startsWith('--event-name=')) opts.eventName = arg.split('=')[1] || null;
    if (arg.startsWith('--circuit-id=')) opts.circuitId = arg.split('=')[1] || null;
    if (arg.startsWith('--circuit-name=')) opts.circuitName = arg.split('=')[1] || null;
    if (arg.startsWith('--poi-id=')) opts.poiId = arg.split('=')[1] || null;
  }

  return opts;
}

function normalizeText(v) {
  return String(v || '')
    .toLowerCase()
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .trim();
}

function slugify(v) {
  return normalizeText(v)
    .replace(/[^a-z0-9]+/g, '_')
    .replace(/^_+|_+$/g, '') || 'event_test';
}

function b64url(input) {
  return Buffer.from(input)
    .toString('base64')
    .replace(/=/g, '')
    .replace(/\+/g, '-')
    .replace(/\//g, '_');
}

function signJwt(claims, privateKey) {
  const header = { alg: 'RS256', typ: 'JWT' };
  const encodedHeader = b64url(JSON.stringify(header));
  const encodedClaims = b64url(JSON.stringify(claims));
  const data = `${encodedHeader}.${encodedClaims}`;
  const signer = crypto.createSign('RSA-SHA256');
  signer.update(data);
  signer.end();
  const signature = signer.sign(privateKey, 'base64url');
  return `${data}.${signature}`;
}

async function getAccessToken() {
  const now = Math.floor(Date.now() / 1000);
  const claims = {
    iss: serviceAccount.client_email,
    sub: serviceAccount.client_email,
    aud: 'https://oauth2.googleapis.com/token',
    scope: 'https://www.googleapis.com/auth/datastore',
    iat: now,
    exp: now + 3600,
  };

  const assertion = signJwt(claims, serviceAccount.private_key);
  const body = new URLSearchParams({
    grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
    assertion,
  });

  const res = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body,
  });

  if (!res.ok) {
    const txt = await res.text();
    throw new Error(`Token OAuth impossible (${res.status}): ${txt}`);
  }

  const data = await res.json();
  return data.access_token;
}

function toFirestoreValue(value) {
  if (value === null || value === undefined) return { nullValue: null };
  if (typeof value === 'string') return { stringValue: value };
  if (typeof value === 'boolean') return { booleanValue: value };
  if (typeof value === 'number') {
    return Number.isInteger(value)
      ? { integerValue: String(value) }
      : { doubleValue: value };
  }
  if (Array.isArray(value)) {
    return {
      arrayValue: {
        values: value.map((v) => toFirestoreValue(v)),
      },
    };
  }
  if (typeof value === 'object') {
    const fields = {};
    for (const [k, v] of Object.entries(value)) {
      fields[k] = toFirestoreValue(v);
    }
    return { mapValue: { fields } };
  }
  return { stringValue: String(value) };
}

function toFirestoreFields(objectValue) {
  const fields = {};
  for (const [k, v] of Object.entries(objectValue)) {
    fields[k] = toFirestoreValue(v);
  }
  return fields;
}

function fromFirestoreValue(value) {
  if (!value || typeof value !== 'object') return null;
  if ('stringValue' in value) return value.stringValue;
  if ('booleanValue' in value) return value.booleanValue;
  if ('integerValue' in value) return Number(value.integerValue);
  if ('doubleValue' in value) return Number(value.doubleValue);
  if ('nullValue' in value) return null;
  if ('arrayValue' in value) {
    const arr = value.arrayValue?.values || [];
    return arr.map((v) => fromFirestoreValue(v));
  }
  if ('mapValue' in value) {
    const fields = value.mapValue?.fields || {};
    const out = {};
    for (const [k, v] of Object.entries(fields)) {
      out[k] = fromFirestoreValue(v);
    }
    return out;
  }
  if ('timestampValue' in value) return value.timestampValue;
  return null;
}

function fromFirestoreFields(fields) {
  const out = {};
  for (const [k, v] of Object.entries(fields || {})) {
    out[k] = fromFirestoreValue(v);
  }
  return out;
}

async function listDocuments({ projectId, accessToken, relativeCollectionPath }) {
  const encodedPath = relativeCollectionPath
    .split('/')
    .map((s) => encodeURIComponent(s))
    .join('/');
  const url = `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents/${encodedPath}?pageSize=200`;
  const res = await fetch(url, {
    method: 'GET',
    headers: { Authorization: `Bearer ${accessToken}` },
  });

  if (res.status === 404) return [];
  if (!res.ok) {
    const txt = await res.text();
    throw new Error(`LIST ${relativeCollectionPath} en echec (${res.status}): ${txt}`);
  }

  const json = await res.json();
  return (json.documents || []).map((doc) => {
    const segments = String(doc.name || '').split('/');
    const id = segments[segments.length - 1];
    return {
      id,
      path: doc.name,
      data: fromFirestoreFields(doc.fields || {}),
    };
  });
}

async function getDocument({ projectId, accessToken, relativeDocPath }) {
  const encodedPath = relativeDocPath
    .split('/')
    .map((s) => encodeURIComponent(s))
    .join('/');
  const url = `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents/${encodedPath}`;
  const res = await fetch(url, {
    method: 'GET',
    headers: { Authorization: `Bearer ${accessToken}` },
  });

  if (res.status === 404) return null;
  if (!res.ok) {
    const txt = await res.text();
    throw new Error(`GET ${relativeDocPath} en echec (${res.status}): ${txt}`);
  }

  const doc = await res.json();
  return fromFirestoreFields(doc.fields || {});
}

function pickCircuitCenter(circuitData) {
  const c = circuitData?.center;
  if (
    c &&
    typeof c === 'object' &&
    Number.isFinite(Number(c.lat)) &&
    Number.isFinite(Number(c.lng))
  ) {
    return { lat: Number(c.lat), lng: Number(c.lng) };
  }

  const bounds = circuitData?.bounds;
  if (
    bounds &&
    typeof bounds === 'object' &&
    Number.isFinite(Number(bounds.south)) &&
    Number.isFinite(Number(bounds.north)) &&
    Number.isFinite(Number(bounds.west)) &&
    Number.isFinite(Number(bounds.east))
  ) {
    return {
      lat: (Number(bounds.south) + Number(bounds.north)) / 2,
      lng: (Number(bounds.west) + Number(bounds.east)) / 2,
    };
  }

  return { lat: 16.241, lng: -61.533 };
}

async function patchDoc({ projectId, accessToken, relativeDocPath, data }) {
  const encodedPath = relativeDocPath
    .split('/')
    .map((s) => encodeURIComponent(s))
    .join('/');
  const url = `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents/${encodedPath}`;

  const res = await fetch(url, {
    method: 'PATCH',
    headers: {
      Authorization: `Bearer ${accessToken}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ fields: toFirestoreFields(data) }),
  });

  if (!res.ok) {
    const txt = await res.text();
    throw new Error(`PATCH ${relativeDocPath} en echec (${res.status}): ${txt}`);
  }
}

async function resolveEventAndCircuit({ projectId, accessToken, opts }) {
  const countries = await listDocuments({
    projectId,
    accessToken,
    relativeCollectionPath: 'marketMap',
  });

  let chosenCountryId = opts.countryId;
  let chosenEventId = opts.eventId;
  let chosenEventName = null;

  if (!chosenEventId) {
    const targetName = normalizeText(opts.eventName || 'maslive test');
    for (const country of countries) {
      if (chosenCountryId && country.id !== chosenCountryId) continue;
      const events = await listDocuments({
        projectId,
        accessToken,
        relativeCollectionPath: `marketMap/${country.id}/events`,
      });

      const found = events.find((ev) => {
        const id = normalizeText(ev.id || '');
        const name = normalizeText(ev.data?.name || '');
        return (
          name === targetName ||
          name.includes(targetName) ||
          id === targetName ||
          id.includes(targetName)
        );
      });

      if (found) {
        chosenCountryId = country.id;
        chosenEventId = found.id;
        chosenEventName = found.data?.name || found.id;
        break;
      }
    }
  }

  if (!chosenCountryId || !chosenEventId) {
    // Fallback: create/use a predictable target event under a test country.
    const fallbackEventName = opts.eventName || 'maslive test';
    chosenCountryId = chosenCountryId || 'zz_test';
    chosenEventId = opts.eventId || slugify(fallbackEventName);
    chosenEventName = fallbackEventName;
  }

  const circuits = await listDocuments({
    projectId,
    accessToken,
    relativeCollectionPath: `marketMap/${chosenCountryId}/events/${chosenEventId}/circuits`,
  });

  if (!circuits.length) {
    return {
      countryId: chosenCountryId,
      eventId: chosenEventId,
      eventName: chosenEventName || chosenEventId,
      circuitId: opts.circuitId || 'food_test',
      circuitName: opts.circuitName || 'Food Test Circuit',
    };
  }

  let chosenCircuit = null;
  if (opts.circuitId) {
    chosenCircuit = circuits.find((c) => c.id === opts.circuitId) || null;
  } else if (opts.circuitName) {
    const targetCircuit = normalizeText(opts.circuitName);
    chosenCircuit = circuits.find((c) => {
      const name = normalizeText(c.data?.name || '');
      return name === targetCircuit || name.includes(targetCircuit);
    }) || null;
  }

  if (!chosenCircuit) {
    chosenCircuit = circuits[0];
  }

  return {
    countryId: chosenCountryId,
    eventId: chosenEventId,
    eventName: chosenEventName || chosenEventId,
    circuitId: chosenCircuit.id,
    circuitName: chosenCircuit.data?.name || chosenCircuit.id,
  };
}

async function addFoodTestPoi() {
  const opts = parseArgs(process.argv.slice(2));
  const projectId = serviceAccount.project_id;
  const accessToken = await getAccessToken();
  const nowIso = new Date().toISOString();

  const resolved = await resolveEventAndCircuit({ projectId, accessToken, opts });
  const countryId = resolved.countryId;
  const eventId = resolved.eventId;
  const circuitId = resolved.circuitId;
  let poiId = opts.poiId || `food_test_${Date.now()}`;

  await patchDoc({
    projectId,
    accessToken,
    relativeDocPath: `marketMap/${countryId}`,
    data: {
      name: countryId,
      isVisible: true,
      updatedAtIso: nowIso,
    },
  });

  // Réutiliser le dernier POI test déjà créé si présent (pour mettre à jour "ce" POI).
  if (!opts.poiId) {
    const existingPois = await listDocuments({
      projectId,
      accessToken,
      relativeCollectionPath: `marketMap/${countryId}/events/${eventId}/circuits/${circuitId}/pois`,
    });
    const candidates = existingPois
      .map((p) => p.id)
      .filter((id) => id.startsWith('food_test_'))
      .sort((a, b) => b.localeCompare(a));
    if (candidates.length > 0) {
      poiId = candidates[0];
    }
  }

  await patchDoc({
    projectId,
    accessToken,
    relativeDocPath: `marketMap/${countryId}/events/${eventId}`,
    data: {
      name: resolved.eventName,
      isVisible: true,
      updatedAtIso: nowIso,
    },
  });

  await patchDoc({
    projectId,
    accessToken,
    relativeDocPath: `marketMap/${countryId}/events/${eventId}/circuits/${circuitId}`,
    data: {
      name: resolved.circuitName,
      isVisible: true,
      center: { lat: 16.241, lng: -61.533 },
      updatedAtIso: nowIso,
    },
  });

  const circuitData = await getDocument({
    projectId,
    accessToken,
    relativeDocPath: `marketMap/${countryId}/events/${eventId}/circuits/${circuitId}`,
  });
  const center = pickCircuitCenter(circuitData);

  await patchDoc({
    projectId,
    accessToken,
    relativeDocPath:
      `marketMap/${countryId}/events/${eventId}/circuits/${circuitId}/layers/food`,
    data: {
      label: 'Food',
      type: 'food',
      isVisible: true,
      zIndex: 4,
      color: '#EF4444',
      icon: 'assets/images/icon-point.webp',
      updatedAtIso: nowIso,
    },
  });

  await patchDoc({
    projectId,
    accessToken,
    relativeDocPath:
      `marketMap/${countryId}/events/${eventId}/circuits/${circuitId}/pois/${poiId}`,
    data: {
      name: 'Food Test POI',
      description:
        'Fiche descriptive test: ce POI affiche une carte Polaroid avec image wom2.png.',
      type: 'food',
      layerType: 'food',
      layerId: 'food',
      lat: center.lat,
      lng: center.lng,
      isVisible: true,
      iconUrl: 'assets/images/icon-point.webp',
      imageUrl: 'assets/splash/wom2.png',
      address: 'Zone test MASLIVE',
      openingHours: '10:00 - 20:00',
      website: 'https://maslive.fr',
      metadata: {
        iconAsset: 'assets/images/icon-point.webp',
        isTest: true,
        popupEnabled: true,
        image: {
          url: 'assets/splash/wom2.png',
        },
        polaroid: {
          angleDeg: -2,
          grain: 0.2,
        },
      },
      createdAtIso: nowIso,
      updatedAtIso: nowIso,
    },
  });

  console.log('✅ POI food test cree.');
  console.log(`Event: ${resolved.eventName} (${eventId})`);
  console.log(`Circuit: ${resolved.circuitName} (${circuitId})`);
  console.log(`POI center: lat=${center.lat}, lng=${center.lng}`);
  console.log(
    `Path: marketMap/${countryId}/events/${eventId}/circuits/${circuitId}/pois/${poiId}`,
  );
}

addFoodTestPoi().catch((error) => {
  console.error('❌ Erreur creation POI food test:', error);
  process.exit(1);
});
