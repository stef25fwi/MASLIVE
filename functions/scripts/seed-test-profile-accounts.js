'use strict';

const admin = require('firebase-admin');

const args = new Set(process.argv.slice(2));
const confirmed = args.has('--confirm-test-data');
const allowLiveProject = process.env.ALLOW_TEST_PROFILE_SEED === 'true';
const password = process.env.TEST_PROFILE_PASSWORD;

if (!confirmed) {
  console.error('Ajoute --confirm-test-data pour confirmer la création des comptes de test.');
  process.exit(1);
}

if (!password || password.length < 12) {
  console.error('TEST_PROFILE_PASSWORD est requis et doit contenir au moins 12 caractères.');
  process.exit(1);
}

if (!admin.apps.length) {
  admin.initializeApp();
}

const projectId = admin.app().options.projectId || process.env.GCLOUD_PROJECT || '';
const usingAuthEmulator = Boolean(process.env.FIREBASE_AUTH_EMULATOR_HOST);
const usingFirestoreEmulator = Boolean(process.env.FIRESTORE_EMULATOR_HOST);

if ((!usingAuthEmulator || !usingFirestoreEmulator) && !allowLiveProject) {
  console.error(
    `Refus de créer des comptes sur le projet ${projectId || '(inconnu)'}. ` +
      'Utilise les émulateurs ou définis explicitement ALLOW_TEST_PROFILE_SEED=true.',
  );
  process.exit(1);
}

const auth = admin.auth();
const db = admin.firestore();
const now = admin.firestore.FieldValue.serverTimestamp();
const testGroupId = '900001';

const profiles = [
  {
    index: 1,
    label: 'Utilisateur',
    role: 'user',
    isAdmin: false,
    activities: [],
  },
  {
    index: 2,
    label: 'Artisan d’art',
    role: 'user',
    isAdmin: false,
    activities: ['artisan_art'],
    bloomArt: true,
  },
  {
    index: 3,
    label: 'Créateur digital',
    role: 'user',
    isAdmin: false,
    activities: ['creator_digital'],
    photographer: true,
  },
  {
    index: 4,
    label: 'Tracker Groupe',
    role: 'tracker',
    isAdmin: false,
    activities: [],
    tracker: true,
  },
  {
    index: 5,
    label: 'Admin Groupe',
    role: 'group',
    isAdmin: false,
    activities: [],
    groupAdmin: true,
  },
  {
    index: 6,
    label: 'Admin MASLIVE',
    role: 'admin',
    isAdmin: true,
    activities: [],
  },
  {
    index: 7,
    label: 'SuperAdmin',
    role: 'superAdmin',
    isAdmin: true,
    activities: [],
  },
];

async function upsertAuthUser(email, displayName) {
  try {
    const existing = await auth.getUserByEmail(email);
    return auth.updateUser(existing.uid, {
      password,
      displayName,
      emailVerified: true,
      disabled: false,
    });
  } catch (error) {
    if (error.code !== 'auth/user-not-found') throw error;
    return auth.createUser({
      email,
      password,
      displayName,
      emailVerified: true,
      disabled: false,
    });
  }
}

async function seedProfile(profile) {
  const email = `ilipresto${profile.index}@mail.fr`;
  const displayName = `Test ${profile.label}`;
  const user = await upsertAuthUser(email, displayName);

  const batch = db.batch();
  batch.set(
    db.collection('users').doc(user.uid),
    {
      uid: user.uid,
      email,
      displayName,
      role: profile.role,
      isAdmin: profile.isAdmin,
      isActive: true,
      activities: profile.activities,
      groupId: profile.groupAdmin || profile.tracker ? testGroupId : null,
      isTestAccount: true,
      testProfileLabel: profile.label,
      updatedAt: now,
      createdAt: now,
    },
    { merge: true },
  );

  if (profile.bloomArt) {
    batch.set(
      db.collection('bloom_art_seller_profiles').doc(user.uid),
      {
        ownerUid: user.uid,
        profileType: 'artisan_art',
        displayName,
        status: 'verified',
        verificationStatus: 'verified',
        isActive: true,
        isTestAccount: true,
        createdAt: now,
        updatedAt: now,
      },
      { merge: true },
    );
  }

  if (profile.photographer) {
    batch.set(
      db.collection('photographers').doc(`test-${user.uid}`),
      {
        ownerUid: user.uid,
        displayName,
        status: 'active',
        isActive: true,
        isTestAccount: true,
        createdAt: now,
        updatedAt: now,
      },
      { merge: true },
    );
  }

  if (profile.groupAdmin) {
    batch.set(
      db.collection('group_admins').doc(user.uid),
      {
        uid: user.uid,
        adminGroupId: testGroupId,
        displayName,
        isVisible: false,
        isTestAccount: true,
        createdAt: now,
        updatedAt: now,
      },
      { merge: true },
    );
    batch.set(
      db.collection('group_admin_codes').doc(testGroupId),
      {
        adminUid: user.uid,
        isActive: true,
        isTestAccount: true,
        createdAt: now,
      },
      { merge: true },
    );
  }

  if (profile.tracker) {
    const adminEmail = 'ilipresto5@mail.fr';
    const groupAdminUser = await auth.getUserByEmail(adminEmail);
    batch.set(
      db.collection('group_trackers').doc(user.uid),
      {
        uid: user.uid,
        adminGroupId: testGroupId,
        linkedAdminUid: groupAdminUser.uid,
        displayName,
        trackingActive: false,
        trackingSessionId: null,
        trackingStoppedAt: null,
        lastPosition: null,
        isTestAccount: true,
        createdAt: now,
        updatedAt: now,
      },
      { merge: true },
    );
  }

  await batch.commit();
  return { email, uid: user.uid, profile: profile.label };
}

async function main() {
  const ordered = [...profiles].sort((a, b) => {
    if (a.groupAdmin) return -1;
    if (b.groupAdmin) return 1;
    return a.index - b.index;
  });

  const created = [];
  for (const profile of ordered) {
    created.push(await seedProfile(profile));
  }

  created.sort((a, b) => a.email.localeCompare(b.email, 'fr', { numeric: true }));
  console.table(created);
  console.log(`Mot de passe commun : variable TEST_PROFILE_PASSWORD (${password.length} caractères).`);
  console.log(`Groupe de test Admin/Tracker : ${testGroupId}.`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
