# RGPD/DSAR Support - Fiche 1 Page (MASLIVE)

Objectif: traiter une demande DSAR (export/suppression) en moins de 10 minutes, avec preuves minimales.

## 0) Prerequis

- Ticket ouvert: DSAR-YYYYMMDD-XXXX
- Identite verifiee (in-app authentifie ou verification support validee)
- Type de demande: export ou delete
- UID utilisateur disponible

## 1) Export DSAR (3-5 min)

1. Demander a l'utilisateur connecte d'executer l'export dans l'app.
2. Backend appele: exportMyPersonalData.
3. Recuperer le resultat JSON et l'attacher au ticket.
4. Verifier la trace dans gdpr_requests:
   - type=export
   - status=completed
   - uid=<UID>

Validation rapide:
- payload present (auth + firestore.profile + firestore.subCollections)
- generatedAt present
- statut ticket: completed

## 2) Suppression DSAR (5-10 min)

1. Demander a l'utilisateur connecte d'executer la suppression dans l'app.
2. Backend appele: deleteMyAccountGdpr.
3. Verifier la trace gdpr_requests:
   - type=delete
   - status=completed
   - uid=<UID>
4. Verifier suppression Auth:
   - utilisateur non trouvable dans Firebase Auth.
5. Verifier suppression Firestore:
   - users/<UID> absent.

Validation rapide:
- gdpr_requests status=completed
- Auth supprime
- users/<UID> supprime

## 3) Script Node de verification (option support interne)

Utiliser si verification manuelle necessaire.

```javascript
// verify_dsar.js
const admin = require('firebase-admin');

admin.initializeApp({
  credential: admin.credential.applicationDefault(),
});

const db = admin.firestore();

async function verify(uid) {
  const out = { uid };

  // Auth check
  try {
    await admin.auth().getUser(uid);
    out.authDeleted = false;
  } catch (e) {
    out.authDeleted = e?.code === 'auth/user-not-found';
  }

  // Firestore check
  const userSnap = await db.collection('users').doc(uid).get();
  out.firestoreUserDeleted = !userSnap.exists;

  // Latest GDPR request
  const reqSnap = await db
    .collection('gdpr_requests')
    .where('uid', '==', uid)
    .orderBy('createdAt', 'desc')
    .limit(1)
    .get();

  if (!reqSnap.empty) {
    out.latestGdprRequest = {
      id: reqSnap.docs[0].id,
      ...reqSnap.docs[0].data(),
    };
  } else {
    out.latestGdprRequest = null;
  }

  console.log(JSON.stringify(out, null, 2));
}

verify(process.argv[2]).catch((e) => {
  console.error(e);
  process.exit(1);
});
```

Execution:

```bash
node verify_dsar.js <UID>
```

## 4) Reponse support standard (copier/coller)

Export termine:
"Votre demande d'export de donnees personnelles a ete traitee. Le fichier d'export est disponible et a ete genere le <DATE>."

Suppression terminee:
"Votre demande de suppression de compte et de donnees personnelles a ete traitee. La suppression est effective depuis le <DATE>."

## 5) Escalade si echec (status=failed)

- Lire errorCode dans gdpr_requests
- Ouvrir incident Sec/Back (priorite P2)
- Corriger la cause puis relancer le traitement
- Conserver les preuves (avant/apres) dans le ticket
