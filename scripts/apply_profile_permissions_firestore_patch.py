#!/usr/bin/env python3
"""Applique le patch Firestore profils/droits MASLIVE.

Usage depuis la racine du repo :
  python3 scripts/apply_profile_permissions_firestore_patch.py

Le script est idempotent : il n'ajoute pas deux fois le bloc
`group_admin_requests` et remplace les helpers commerce legacy si trouvés.
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
RULES = ROOT / "firestore.rules"

GROUP_ADMIN_REQUESTS_BLOCK = r'''
    // ========== COLLECTION: GROUP ADMIN REQUESTS (Demandes Admin Groupe) ==========
    match /group_admin_requests/{uid} {
      allow read: if isSignedIn() && (
        request.auth.uid == uid || isMasterAdmin()
      );

      allow create: if isSignedIn()
        && request.auth.uid == uid
        && request.resource.data.requestUid == uid
        && request.resource.data.status == 'pending'
        && request.resource.data.keys().hasOnly([
          'requestUid',
          'displayName',
          'email',
          'status',
          'requestedAt',
          'updatedAt',
          'reviewedAt',
          'reviewedBy',
          'rejectionReason'
        ])
        && !request.resource.data.keys().hasAny([
          'adminGroupId',
          'role',
          'groupId',
          'isAdmin'
        ]);

      allow update: if isMasterAdmin() || (
        isSignedIn()
        && request.auth.uid == uid
        && resource.data.status in ['pending', 'rejected']
        && request.resource.data.requestUid == resource.data.requestUid
        && request.resource.data.status == 'pending'
        && !request.resource.data.keys().hasAny([
          'adminGroupId',
          'role',
          'groupId',
          'isAdmin',
          'reviewedAt',
          'reviewedBy'
        ])
      );

      allow delete: if isMasterAdmin() || (
        isSignedIn()
        && request.auth.uid == uid
        && resource.data.status in ['pending', 'rejected']
      );
    }
'''.strip("\n")

OLD_CAN_SUBMIT = r'''      function canSubmitCommerce() {
        return hasUserDoc() && (
          isMasterAdmin()
          || userRole() == 'admin_groupe'
          || (getUserData().accountType == 'pro' && getUserData().keys().hasAny(['activities']))
          || userRole() == 'superadmin'
        );
      }
'''

NEW_CAN_SUBMIT = r'''      function canSubmitCommerce() {
        return hasUserDoc() && (
          isMasterAdmin()
          || userRole() == 'group'
          || userRole() == 'group-admin'
          || userRole() == 'admin_group'
          || userRole() == 'admin_groupe'
          || (getUserData().accountType == 'pro' && getUserData().keys().hasAny(['activities']))
          || userRole() == 'superAdmin'
          || userRole() == 'superadmin'
        );
      }
'''

OLD_CAN_MODERATE = r'''      function canModerate() {
        return isMasterAdmin()
          || (userRole() == 'admin_groupe' 
              && resource.data.scopeType == 'group' 
              && getUserData().keys().hasAny(['managedScopeIds']) 
              && getUserData().managedScopeIds.hasAny([resource.data.scopeId]));
      }
'''

NEW_CAN_MODERATE = r'''      function canModerate() {
        return isMasterAdmin()
          || ((userRole() == 'group'
              || userRole() == 'group-admin'
              || userRole() == 'admin_group'
              || userRole() == 'admin_groupe')
            && resource.data.scopeType == 'group'
            && (
              (getUserData().keys().hasAny(['managedScopeIds'])
                && getUserData().managedScopeIds.hasAny([resource.data.scopeId]))
              || userGroupId() == resource.data.scopeId
            ));
      }
'''


def main() -> None:
    text = RULES.read_text()
    changed = False

    if "match /group_admin_requests/{uid}" not in text:
        marker = "    // ========== COLLECTION: PLACES (Lieux) =========="
        if marker not in text:
            raise SystemExit("Marqueur d'insertion introuvable: COLLECTION: PLACES")
        text = text.replace(marker, f"{GROUP_ADMIN_REQUESTS_BLOCK}\n\n{marker}", 1)
        changed = True

    if OLD_CAN_SUBMIT in text:
        text = text.replace(OLD_CAN_SUBMIT, NEW_CAN_SUBMIT, 1)
        changed = True
    elif "function canSubmitCommerce()" not in text:
        raise SystemExit("Helper canSubmitCommerce introuvable")

    if OLD_CAN_MODERATE in text:
        text = text.replace(OLD_CAN_MODERATE, NEW_CAN_MODERATE, 1)
        changed = True
    elif "function canModerate()" not in text:
        raise SystemExit("Helper canModerate introuvable")

    if changed:
        RULES.write_text(text)
        print("Patch Firestore profils/droits applique.")
    else:
        print("Aucun changement: patch deja applique.")


if __name__ == "__main__":
    main()
