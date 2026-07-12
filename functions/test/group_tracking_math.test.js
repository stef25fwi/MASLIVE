const test = require('node:test');
const assert = require('node:assert/strict');

const { __test } = require('../group_tracking');

function tracker(uid, lat, lng, accuracy = 10, ageMs = 5000) {
  return { uid, role: 'tracker', lat, lng, alt: 0, accuracy, ageMs };
}

test('median calcule correctement valeurs paires et impaires', () => {
  assert.equal(__test.median([1, 9, 3]), 3);
  assert.equal(__test.median([1, 3, 5, 7]), 4);
});

test('la pondération favorise une position récente et précise', () => {
  const good = tracker('good', 16.2, -61.5, 8, 2000);
  const poor = tracker('poor', 16.2, -61.5, 50, 80000);
  assert.ok(__test.rawWeight(good) > __test.rawWeight(poor));
});

test('le filtre robuste retire un point aberrant', () => {
  const positions = [
    tracker('a', 16.24000, -61.53000),
    tracker('b', 16.24010, -61.53010),
    tracker('c', 16.23990, -61.52990),
    tracker('outlier', 16.26000, -61.55000),
  ];
  const result = __test.robustFilter(positions);
  assert.equal(result.removed, 1);
  assert.equal(result.kept.some((item) => item.uid === 'outlier'), false);
});

test('la sélection normale exclut admin quand au moins deux trackers existent', () => {
  const selected = __test.choosePositions([
    tracker('a', 16.24, -61.53),
    tracker('b', 16.2401, -61.5301),
    { uid: 'admin', role: 'admin', lat: 16.25, lng: -61.54, alt: 0, accuracy: 5, ageMs: 1000 },
  ]);
  assert.equal(selected.adminFallbackUsed, false);
  assert.equal(selected.positions.length, 2);
  assert.equal(selected.positions.every((item) => item.role === 'tracker'), true);
});

test('la sélection plafonne le calcul à dix trackers', () => {
  const positions = Array.from({ length: 14 }, (_, index) =>
    tracker(`t${index}`, 16.24 + index * 0.00001, -61.53, 10 + index, 1000),
  );
  const selected = __test.choosePositions(positions);
  assert.equal(selected.positions.length, 10);
  assert.equal(selected.trackerCount, 10);
});

test('un saut supérieur à 150 m exige deux mesures cohérentes', () => {
  const now = Date.now();
  const first = __test.smoothedCenter(
    { lat: 16.2500, lng: -61.5400, alt: 0 },
    { lat: 16.2400, lng: -61.5300 },
    now,
  );
  assert.equal(first.status, 'jump_pending');

  const second = __test.smoothedCenter(
    { lat: 16.2501, lng: -61.5401, alt: 0 },
    {
      lat: 16.2400,
      lng: -61.5300,
      pendingJump: {
        lat: 16.2500,
        lng: -61.5400,
        observedAt: { toMillis: () => now - 10000 },
      },
    },
    now,
  );
  assert.equal(second.status, 'accepted');
  assert.equal(second.jumpConfirmed, true);
});

test('le centroïde pondéré reste au voisinage du groupe', () => {
  const center = __test.weightedCenter([
    tracker('a', 16.2400, -61.5300, 8, 1000),
    tracker('b', 16.2402, -61.5302, 12, 3000),
    tracker('c', 16.2399, -61.5299, 15, 5000),
  ]);
  assert.ok(center.lat > 16.2398 && center.lat < 16.2403);
  assert.ok(center.lng > -61.5303 && center.lng < -61.5298);
});

test('le plan A conserve les cadences optimisées', () => {
  assert.equal(__test.CFG.aggregationMs, 30000);
  assert.equal(__test.CFG.publishHeartbeatMs, 60000);
  assert.equal(__test.CFG.idealTrackers, 5);
  assert.equal(__test.CFG.maxTrackers, 10);
});
