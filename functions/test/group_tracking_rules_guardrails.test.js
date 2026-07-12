const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');

const root = path.resolve(__dirname, '..', '..');
const rules = fs.readFileSync(path.join(root, 'firestore.rules'), 'utf8');

test('group tracking rules lock live payloads', () => {
  assert.match(rules, /function expectedLiveRole\(adminGroupId, uid\)/);
  assert.match(rules, /data\.role == expectedLiveRole\(adminGroupId, uid\)/);
  assert.match(rules, /data\.expiresAt <= request\.time \+ duration\.value\(3, 'm'\)/);
  assert.match(rules, /lastPosition\.ts >= resource\.data\.lastPosition\.ts/);
});

test('tracker profiles and history points are restricted', () => {
  assert.match(rules, /function isValidTrackerProfile\(data, trackerUid\)/);
  assert.match(rules, /isValidTrackerLink\(data\)/);
  assert.match(rules, /isValidTrackingPosition\(request\.resource\.data\)/);
});

test('legacy GPS pipeline is removed', () => {
  assert.equal(fs.existsSync(path.join(root, 'app/lib/services/group_tracking_service.dart')), false);
  assert.equal(fs.existsSync(path.join(root, 'app/lib/services/geolocator_gps_stream_provider.dart')), false);
});
