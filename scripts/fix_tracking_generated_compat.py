from pathlib import Path

root = Path(__file__).resolve().parents[1]
service_path = root / 'app/lib/services/group/group_tracking_service.dart'
service = service_path.read_text(encoding='utf-8')

old_profile = """      batch.set(
        profileRef,
        <String, dynamic>{
          'lastPosition': geoPosition.toMap(),
          'trackingActive': true,
          'trackingSessionId': session.id,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
"""
new_profile = """      final profileData = <String, dynamic>{
        'lastPosition': geoPosition.toMap(),
        'trackingActive': true,
        'trackingSessionId': session.id,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (session.role == 'tracker') {
        profileData['uid'] = user.uid;
        profileData['trackingStoppedAt'] = null;
      }
      batch.set(
        profileRef,
        profileData,
        SetOptions(merge: true),
      );
"""
if old_profile not in service:
    raise RuntimeError('profile compatibility block not found')
service = service.replace(old_profile, new_profile, 1)

old_stop = """      batch.set(
        profileRef,
        <String, dynamic>{
          'trackingActive': false,
          'trackingSessionId': null,
          'trackingStoppedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
"""
new_stop = """      final stoppedProfileData = <String, dynamic>{
        'trackingActive': false,
        'trackingSessionId': null,
        'trackingStoppedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (session.role == 'tracker') {
        stoppedProfileData['uid'] = user.uid;
      }
      batch.set(
        profileRef,
        stoppedProfileData,
        SetOptions(merge: true),
      );
"""
if old_stop not in service:
    raise RuntimeError('stop profile compatibility block not found')
service = service.replace(old_stop, new_stop, 1)
service_path.write_text(service, encoding='utf-8')

rules_path = root / 'firestore.rules'
rules = rules_path.read_text(encoding='utf-8')
old_session = """          && request.resource.data.sessionId == resource.data.sessionId
          && request.resource.data.lastPosition.ts >= resource.data.lastPosition.ts;
"""
new_session = """          && (
            request.resource.data.sessionId == resource.data.sessionId
            || resource.data.isTracking == false
            || resource.data.expiresAt < request.time
          )
          && request.resource.data.lastPosition.ts >= resource.data.lastPosition.ts;
"""
if old_session not in rules:
    raise RuntimeError('live session rollover rule not found')
rules = rules.replace(old_session, new_session, 1)
rules_path.write_text(rules, encoding='utf-8')

print('Generated tracking compatibility fixes applied.')
