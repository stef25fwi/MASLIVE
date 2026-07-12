from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def write(path: str, value: str) -> None:
    (ROOT / path).write_text(value, encoding="utf-8")


def replace_once(value: str, old: str, new: str, label: str) -> str:
    count = value.count(old)
    if count != 1:
        raise RuntimeError(f"{label}: expected 1 occurrence, found {count}")
    return value.replace(old, new, 1)


# Main tracking service: restore local session state and expose live presences.
path = "app/lib/services/group/group_tracking_service.dart"
value = read(path)
value = replace_once(
    value,
    """  bool get isTracking =>
      _positionSubscription != null && _currentSession?.isActive == true;
""",
    """  bool get isTracking =>
      _positionSubscription != null && _currentSession?.isActive == true;

  TrackSession? get currentSession => _currentSession;

  bool isTrackingFor({
    required String adminGroupId,
    required String role,
  }) {
    final session = _currentSession;
    final normalizedRole = role == 'admin' ? 'admin' : 'tracker';
    return isTracking &&
        session?.adminGroupId == adminGroupId &&
        session?.role == normalizedRole;
  }
""",
    "tracking getters",
)
value = replace_once(
    value,
    """  Stream<List<TrackSession>> streamGroupSessions(String adminGroupId) {
""",
    """  Stream<Set<String>> streamActiveMemberUids(String adminGroupId) {
    return _firestore
        .collection('group_positions')
        .doc(adminGroupId)
        .collection('members')
        .snapshots()
        .map((snapshot) {
      final now = DateTime.now();
      return snapshot.docs.where((doc) {
        final data = doc.data();
        if (data['isTracking'] != true) return false;

        final expiresAt = data['expiresAt'];
        if (expiresAt is! Timestamp || !expiresAt.toDate().isAfter(now)) {
          return false;
        }

        final rawPosition = data['lastPosition'];
        if (rawPosition is! Map) return false;
        final rawTimestamp = rawPosition['ts'];
        if (rawTimestamp is! Timestamp) return false;

        final age = now.difference(rawTimestamp.toDate());
        return age.inSeconds >= -30 && age <= _liveTtl;
      }).map((doc) => doc.id).toSet();
    });
  }

  Stream<List<TrackSession>> streamGroupSessions(String adminGroupId) {
""",
    "live member stream",
)
write(path, value)


# Restore tracking UI state after page navigation.
path = "app/lib/pages/group/tracker_group_profile_page.dart"
value = read(path)
value = replace_once(
    value,
    """        final tracker = await _linkService.getTrackerProfile(uid);
        setState(() => _tracker = tracker);
""",
    """        final tracker = await _linkService.getTrackerProfile(uid);
        if (!mounted) return;
        setState(() {
          _tracker = tracker;
          final groupId = tracker?.adminGroupId;
          _isTracking = groupId != null &&
              _trackingService.isTrackingFor(
                adminGroupId: groupId,
                role: 'tracker',
              );
        });
""",
    "tracker restore",
)
load_start = value.index("  Future<void> _loadTrackerProfile() async {")
load_end = value.index("  Future<void> _scanQr() async {", load_start)
load_block = value[load_start:load_end]
old_loading = "      setState(() => _isLoading = false);"
if old_loading not in load_block:
    raise RuntimeError("tracker mounted guard: loading statement not found")
load_block = load_block.replace(
    old_loading,
    "      if (mounted) setState(() => _isLoading = false);",
    1,
)
value = value[:load_start] + load_block + value[load_end:]
write(path, value)


path = "app/lib/pages/group/admin_group_dashboard_page.dart"
value = read(path)
value = replace_once(
    value,
    """        final admin = await _linkService.getAdminProfile(uid);
        setState(() => _admin = admin);
""",
    """        final admin = await _linkService.getAdminProfile(uid);
        if (!mounted) return;
        setState(() {
          _admin = admin;
          _isTracking = admin != null &&
              _trackingService.isTrackingFor(
                adminGroupId: admin.adminGroupId,
                role: 'admin',
              );
        });
""",
    "admin restore",
)
value = replace_once(
    value,
    """    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _createAdminProfile() async {
""",
    """    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _createAdminProfile() async {
""",
    "admin mounted guard",
)
new_method = r"""  Widget _buildTrackersList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Trackers rattachés',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        StreamBuilder<List<GroupTracker>>(
          stream: _linkService.streamAdminTrackers(_admin!.adminGroupId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.people_outline, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          'Aucun tracker rattaché',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Partagez le code ${_admin!.adminGroupId}',
                            style: TextStyle(color: Colors.grey[600], fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            final trackers = snapshot.data!;
            return StreamBuilder<Set<String>>(
              stream: _trackingService.streamActiveMemberUids(
                _admin!.adminGroupId,
              ),
              builder: (context, liveSnapshot) {
                final activeUids = liveSnapshot.data ?? const <String>{};
                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: trackers.length,
                  itemBuilder: (context, index) {
                    final tracker = trackers[index];
                    final isLive = activeUids.contains(tracker.uid);
                    final stale = tracker.trackingActive && !isLive;
                    final initial = tracker.displayName.trim().isEmpty
                        ? '?'
                        : tracker.displayName.trim()[0].toUpperCase();
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(child: Text(initial)),
                        title: Text(tracker.displayName),
                        subtitle: Text(
                          isLive
                              ? 'GPS actif • position live reçue'
                              : stale
                                  ? 'Signal expiré • relance requise'
                                  : 'GPS inactif',
                        ),
                        trailing: Icon(
                          isLive
                              ? Icons.gps_fixed
                              : stale
                                  ? Icons.gps_not_fixed
                                  : Icons.gps_off,
                          color: isLive
                              ? Colors.green
                              : stale
                                  ? Colors.orange
                                  : Colors.grey,
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
      ],
    );
  }
"""
value, count = re.subn(
    r"  Widget _buildTrackersList\(\) \{.*?\n  \}\n\}",
    new_method + "\n}",
    value,
    count=1,
    flags=re.DOTALL,
)
if count != 1:
    raise RuntimeError(f"admin tracker list: expected 1 replacement, found {count}")
write(path, value)


# Harden Firestore rules for tracker profiles, live positions and history points.
path = "firestore.rules"
value = read(path)
start = value.index("    // Profils trackers\n")
end = value.index("    // Historique des sessions + points\n", start)
replacement = r"""    function isValidTrackingPosition(position) {
      return position is map
        && position.keys().hasAll(['lat', 'lng', 'alt', 'accuracy', 'ts'])
        && position.keys().hasOnly(['lat', 'lng', 'alt', 'accuracy', 'ts'])
        && position.lat is number
        && position.lng is number
        && position.lat >= -90
        && position.lat <= 90
        && position.lng >= -180
        && position.lng <= 180
        && !(position.lat == 0 && position.lng == 0)
        && (position.alt == null || position.alt is number)
        && position.accuracy is number
        && position.accuracy >= 0
        && position.accuracy <= 50
        && position.ts is timestamp
        && position.ts >= request.time - duration.value(10, 'm')
        && position.ts <= request.time + duration.value(2, 'm');
    }

    function isValidTrackerLink(data) {
      return (
          data.adminGroupId == null
          && data.linkedAdminUid == null
        ) || (
          data.adminGroupId is string
          && data.adminGroupId.matches('^\\d{6}$')
          && data.linkedAdminUid is string
          && exists(/databases/$(database)/documents/group_admin_codes/$(data.adminGroupId))
          && get(/databases/$(database)/documents/group_admin_codes/$(data.adminGroupId)).data.isActive == true
          && get(/databases/$(database)/documents/group_admin_codes/$(data.adminGroupId)).data.adminUid == data.linkedAdminUid
        );
    }

    function isValidTrackerProfile(data, trackerUid) {
      return data.keys().hasOnly([
          'uid',
          'adminGroupId',
          'linkedAdminUid',
          'displayName',
          'lastPosition',
          'trackingActive',
          'trackingSessionId',
          'trackingStoppedAt',
          'createdAt',
          'updatedAt'
        ])
        && data.uid == trackerUid
        && data.displayName is string
        && data.displayName.size() > 0
        && data.displayName.size() <= 120
        && isValidTrackerLink(data)
        && (data.lastPosition == null || isValidTrackingPosition(data.lastPosition))
        && data.trackingActive is bool
        && (data.trackingSessionId == null || data.trackingSessionId is string)
        && (data.trackingStoppedAt == null || data.trackingStoppedAt is timestamp)
        && data.createdAt is timestamp
        && data.updatedAt is timestamp;
    }

    // Profils trackers
    match /group_trackers/{trackerUid} {
      allow read: if isSignedIn() && (
        request.auth.uid == trackerUid
        || isMasterAdmin()
        || isGroupAdminByAdminGroupId(resource.data.adminGroupId)
      );

      allow create: if isSignedIn()
        && isValidTrackerProfile(request.resource.data, trackerUid)
        && (
          isMasterAdmin()
          || isGroupAdminByAdminGroupId(request.resource.data.adminGroupId)
          || request.auth.uid == trackerUid
        );

      allow update: if isSignedIn()
        && isValidTrackerProfile(request.resource.data, trackerUid)
        && (
          isMasterAdmin()
          || (
            request.auth.uid == trackerUid
            && request.resource.data.uid == resource.data.uid
            && request.resource.data.createdAt == resource.data.createdAt
            && request.resource.data.diff(resource.data).changedKeys().hasOnly([
              'adminGroupId',
              'linkedAdminUid',
              'displayName',
              'lastPosition',
              'trackingActive',
              'trackingSessionId',
              'trackingStoppedAt',
              'updatedAt'
            ])
          )
          || (
            isGroupAdminByAdminGroupId(resource.data.adminGroupId)
            && request.resource.data.uid == resource.data.uid
            && request.resource.data.createdAt == resource.data.createdAt
            && request.resource.data.adminGroupId == resource.data.adminGroupId
            && request.resource.data.linkedAdminUid == resource.data.linkedAdminUid
            && request.resource.data.diff(resource.data).changedKeys().hasOnly([
              'displayName',
              'updatedAt'
            ])
          )
        );
      allow delete: if isMasterAdmin();
    }

    function expectedLiveRole(adminGroupId, uid) {
      return exists(/databases/$(database)/documents/group_admins/$(uid))
          && get(/databases/$(database)/documents/group_admins/$(uid)).data.adminGroupId == adminGroupId
        ? 'admin'
        : (exists(/databases/$(database)/documents/group_trackers/$(uid))
            && get(/databases/$(database)/documents/group_trackers/$(uid)).data.adminGroupId == adminGroupId
          ? 'tracker'
          : null);
    }

    function isValidLiveMember(data, adminGroupId, uid) {
      return data.keys().hasAll([
          'role',
          'isTracking',
          'sessionId',
          'lastPosition',
          'previousPosition',
          'expiresAt',
          'updatedAt'
        ])
        && data.keys().hasOnly([
          'role',
          'isTracking',
          'sessionId',
          'lastPosition',
          'previousPosition',
          'expiresAt',
          'updatedAt'
        ])
        && data.role == expectedLiveRole(adminGroupId, uid)
        && data.isTracking is bool
        && data.sessionId is string
        && data.sessionId.size() > 0
        && isValidTrackingPosition(data.lastPosition)
        && (data.previousPosition == null || isValidTrackingPosition(data.previousPosition))
        && data.expiresAt is timestamp
        && data.expiresAt >= request.time - duration.value(2, 'm')
        && data.expiresAt <= request.time + duration.value(3, 'm')
        && data.updatedAt == request.time;
    }

    // Positions live par membre (source d'agrégation CF)
    match /group_positions/{adminGroupId} {
      allow read: if isSignedIn() && (
        isGroupMemberByAdminGroupId(adminGroupId) || isMasterAdmin()
      );
      allow write: if false;

      match /members/{uid} {
        allow read: if isSignedIn() && (
          isGroupMemberByAdminGroupId(adminGroupId) || isMasterAdmin()
        );
        allow create: if isSignedIn()
          && request.auth.uid == uid
          && isGroupMemberByAdminGroupId(adminGroupId)
          && isValidLiveMember(request.resource.data, adminGroupId, uid);
        allow update: if isSignedIn()
          && request.auth.uid == uid
          && isGroupMemberByAdminGroupId(adminGroupId)
          && isValidLiveMember(request.resource.data, adminGroupId, uid)
          && request.resource.data.sessionId == resource.data.sessionId
          && request.resource.data.lastPosition.ts >= resource.data.lastPosition.ts;
        allow delete: if isMasterAdmin();
      }
    }

"""
value = value[:start] + replacement + value[end:]
value = replace_once(
    value,
    """          allow create: if isSignedIn()
            && isGroupMemberByAdminGroupId(adminGroupId)
            && _sessionDoc().uid == request.auth.uid;

          allow update, delete: if false;
""",
    """          allow create: if isSignedIn()
            && isGroupMemberByAdminGroupId(adminGroupId)
            && _sessionDoc().uid == request.auth.uid
            && request.resource.data.keys().hasAll(['lat', 'lng', 'alt', 'accuracy', 'ts'])
            && request.resource.data.keys().hasOnly(['lat', 'lng', 'alt', 'accuracy', 'ts'])
            && isValidTrackingPosition(request.resource.data)
            && request.resource.data.ts >= _sessionDoc().startedAt;

          allow update, delete: if false;
""",
    "history point validation",
)
write(path, value)


# Remove the unused alternative pipeline to avoid accidental bypass of Plan A.
for legacy in (
    "app/lib/services/group_tracking_service.dart",
    "app/lib/services/geolocator_gps_stream_provider.dart",
):
    candidate = ROOT / legacy
    if candidate.exists():
        candidate.unlink()


# Align documentation.
write(
    "docs/GROUP_TRACKING_BATTERY_QUALITY.md",
    """# Tracking groupe — batterie, qualité et coût

## Réglages de production

- GPS mobile : précision haute uniquement pendant la session, filtre distance 15 m.
- Envoi live adaptatif : 15 s en mouvement, 45 s lent, 60 s immobile.
- Historique : 120 s ou 60 m ; heartbeat de 5 min après 2 min immobile.
- Profil tracker/admin : mise à jour toutes les 5 min.
- Présence live : TTL 120 s et suppression serveur à l'arrêt.
- Agrégation serveur : maximum une fois toutes les 30 s.
- Publication carte : déplacement supérieur ou égal à 5 m, ou heartbeat 60 s.

## Qualité de calcul

- seuls les trackers sont utilisés en fonctionnement normal ;
- l'Admin Groupe est un secours si moins de deux trackers sont disponibles ;
- précision manquante = 50 m, jamais 0 m ;
- poids = précision inverse au carré × décroissance avec l'âge ;
- poids individuel plafonné à 4 fois le poids médian ;
- filtre robuste par médiane et MAD, seuil entre 80 et 250 m ;
- rejet des sauts impliquant une vitesse supérieure à 25 m/s ;
- lissage 35 % nouvelle position / 65 % ancienne ;
- déplacement supérieur à 150 m confirmé par deux calculs cohérents ;
- maximum 10 trackers pris dans le calcul, les meilleurs points étant retenus.

## Dimensionnement recommandé

- minimum utile : 3 trackers ;
- idéal : 5 trackers ;
- grand groupe : 6 à 8 trackers ;
- plafond de calcul : 10 trackers.
""",
)
write(
    "docs/GROUP_TRACKING_PR_BODY.md",
    """## Configuration active

- cadence mobile adaptative 15 / 45 / 60 secondes ;
- filtre distance GPS 15 mètres ;
- historique limité à 120 secondes ou 60 mètres ;
- heartbeat historique immobile 5 minutes ;
- profil tracker/admin mis à jour toutes les 5 minutes ;
- calcul serveur limité à une fois toutes les 30 secondes ;
- publication circuit à partir de 5 mètres ou heartbeat 60 secondes ;
- présence dashboard basée sur `group_positions` ;
- règles Firestore validant rôle, structure, coordonnées et champs modifiables ;
- ancien pipeline GPS alternatif supprimé.
""",
)


# Static guardrails executed by the existing Functions test suite.
write(
    "functions/test/group_tracking_rules_guardrails.test.js",
    """const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');

const root = path.resolve(__dirname, '..', '..');
const rules = fs.readFileSync(path.join(root, 'firestore.rules'), 'utf8');

test('group tracking rules lock live payloads', () => {
  assert.match(rules, /function expectedLiveRole\\(adminGroupId, uid\\)/);
  assert.match(rules, /data\\.role == expectedLiveRole\\(adminGroupId, uid\\)/);
  assert.match(rules, /data\\.expiresAt <= request\\.time \\+ duration\\.value\\(3, 'm'\\)/);
  assert.match(rules, /lastPosition\\.ts >= resource\\.data\\.lastPosition\\.ts/);
});

test('tracker profiles and history points are restricted', () => {
  assert.match(rules, /function isValidTrackerProfile\\(data, trackerUid\\)/);
  assert.match(rules, /isValidTrackerLink\\(data\\)/);
  assert.match(rules, /isValidTrackingPosition\\(request\\.resource\\.data\\)/);
});

test('legacy GPS pipeline is removed', () => {
  assert.equal(fs.existsSync(path.join(root, 'app/lib/services/group_tracking_service.dart')), false);
  assert.equal(fs.existsSync(path.join(root, 'app/lib/services/geolocator_gps_stream_provider.dart')), false);
});
""",
)

print("tracking consistency patch applied")
