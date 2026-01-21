#!/usr/bin/env node

/**
 * Script pour créer un administrateur
 * Usage: node scripts/create_admin.js <email> <role>
 * Exemple: node scripts/create_admin.js admin@maslive.com superAdmin
 */

const admin = require('firebase-admin');

// Initialiser Firebase Admin
const serviceAccount = require('../serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();
const auth = admin.auth();

async function createAdmin(email, role = 'admin') {
  try {
    console.log(`🔍 Recherche de l'utilisateur avec l'email: ${email}`);
    
    // Trouver l'utilisateur par email
    const userRecord = await auth.getUserByEmail(email);
    const uid = userRecord.uid;
    
    console.log(`✅ Utilisateur trouvé: ${uid}`);
    
    // Vérifier les rôles valides
    const validRoles = ['admin', 'superAdmin', 'group', 'tracker', 'user'];
    if (!validRoles.includes(role)) {
      throw new Error(`Rôle invalide. Rôles valides: ${validRoles.join(', ')}`);
    }
    
    // Mettre à jour le profil utilisateur dans Firestore
    await db.collection('users').doc(uid).set({
      role: role,
      isAdmin: ['admin', 'superAdmin'].includes(role),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
    
    console.log(`✅ Utilisateur promu au rôle: ${role}`);
    console.log(`📋 UID: ${uid}`);
    console.log(`📧 Email: ${email}`);
    
    // Afficher les informations du profil
    const userDoc = await db.collection('users').doc(uid).get();
    console.log('\n📄 Profil utilisateur:');
    console.log(JSON.stringify(userDoc.data(), null, 2));
    
    process.exit(0);
  } catch (error) {
    console.error('❌ Erreur:', error.message);
    
    if (error.code === 'auth/user-not-found') {
      console.log('\n💡 Suggestion: Créez d\'abord le compte utilisateur dans Firebase Authentication');
    }
    
    process.exit(1);
  }
}

// Récupérer les arguments de la ligne de commande
const email = process.argv[2];
const role = process.argv[3] || 'admin';

if (!email) {
  console.log('Usage: node scripts/create_admin.js <email> [role]');
  console.log('Exemple: node scripts/create_admin.js admin@maslive.com superAdmin');
  console.log('\nRôles disponibles: user, tracker, group, admin, superAdmin');
  process.exit(1);
}

createAdmin(email, role);
