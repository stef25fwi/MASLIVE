#!/usr/bin/env node

/**
 * Script pour compter le nombre d'utilisateurs dans Firestore
 * Usage: node scripts/count_users.js
 */

const admin = require('firebase-admin');

// Initialiser Firebase Admin (utilise les credentials du projet)
admin.initializeApp();

const db = admin.firestore();

async function countUsers() {
  try {
    console.log('🔍 Comptage des utilisateurs...\n');
    
    // Compter tous les documents dans la collection users
    const snapshot = await db.collection('users').count().get();
    const totalUsers = snapshot.data().count;
    
    console.log(`👥 Nombre total d'utilisateurs: ${totalUsers}`);
    
    // Statistiques supplémentaires
    const usersSnapshot = await db.collection('users').limit(1000).get();
    
    let admins = 0;
    let groupAdmins = 0;
    let regularUsers = 0;
    let usersWithGroup = 0;
    
    usersSnapshot.forEach(doc => {
      const data = doc.data();
      if (data.isAdmin === true || data.role === 'admin') {
        admins++;
      } else if (data.role === 'group_admin') {
        groupAdmins++;
      } else {
        regularUsers++;
      }
      
      if (data.groupId) {
        usersWithGroup++;
      }
    });
    
    console.log('\n📊 Statistiques (sur les 1000 premiers):');
    console.log(`   - Admins master: ${admins}`);
    console.log(`   - Admins de groupe: ${groupAdmins}`);
    console.log(`   - Utilisateurs standard: ${regularUsers}`);
    console.log(`   - Utilisateurs avec groupe: ${usersWithGroup}`);
    
    process.exit(0);
  } catch (error) {
    console.error('❌ Erreur:', error.message);
    process.exit(1);
  }
}

countUsers();
