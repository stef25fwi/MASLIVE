"use strict";

module.exports = function createSuperAdminUserManagementHandlers(deps) {
  const { admin, db, onCall, HttpsError, logger } = deps;
  const REGION = "us-east1";
  const ALLOWED_ROLES = new Set(["user", "tracker", "group", "admin"]);

  function cleanString(value, max = 160) {
    if (typeof value !== "string") return "";
    return value.trim().slice(0, max);
  }

  function normalizeRole(value) {
    const raw = cleanString(value, 40).toLowerCase().replace(/[ -]/g, "_");
    if (["group", "group_admin", "admin_group", "admin_groupe"].includes(raw)) return "group";
    if (["tracker", "tracker_group", "tracker_groupe"].includes(raw)) return "tracker";
    if (raw === "admin") return "admin";
    return "user";
  }

  async function assertSuperAdmin(request) {
    const uid = request.auth?.uid;
    if (!uid) throw new HttpsError("unauthenticated", "Authentification requise.");
    const snap = await db.collection("users").doc(uid).get();
    const data = snap.data() || {};
    const role = cleanString(data.role, 40).toLowerCase().replace(/[ -]/g, "");
    if (role !== "superadmin") {
      throw new HttpsError("permission-denied", "Action réservée au SuperAdmin.");
    }
    return uid;
  }

  async function generateUniqueGroupCode() {
    for (let attempt = 0; attempt < 30; attempt += 1) {
      const code = String(100000 + Math.floor(Math.random() * 900000));
      const ref = db.collection("group_admin_codes").doc(code);
      const snap = await ref.get();
      if (!snap.exists) return code;
    }
    throw new HttpsError("resource-exhausted", "Impossible de générer un code groupe unique.");
  }

  async function resolveGroupAdmin(code) {
    const normalized = cleanString(code, 6);
    if (!/^\d{6}$/.test(normalized)) {
      throw new HttpsError("invalid-argument", "Code Admin Groupe invalide.");
    }
    const snap = await db.collection("group_admin_codes").doc(normalized).get();
    const data = snap.data() || {};
    if (!snap.exists || data.isActive !== true || !data.adminUid) {
      throw new HttpsError("not-found", "Aucun Admin Groupe actif pour ce code.");
    }
    return { code: normalized, adminUid: data.adminUid };
  }

  async function writeRoleProfiles({ uid, displayName, role, adminGroupId }) {
    const batch = db.batch();
    const now = admin.firestore.FieldValue.serverTimestamp();
    const groupAdminRef = db.collection("group_admins").doc(uid);
    const trackerRef = db.collection("group_trackers").doc(uid);

    if (role === "group") {
      const code = adminGroupId || await generateUniqueGroupCode();
      const codeRef = db.collection("group_admin_codes").doc(code);
      batch.set(groupAdminRef, {
        uid,
        adminGroupId: code,
        displayName,
        isVisible: true,
        visibleMapIds: [],
        lastPosition: null,
        averagePosition: null,
        createdAt: now,
        updatedAt: now,
      }, { merge: true });
      batch.set(codeRef, {
        adminUid: uid,
        createdAt: now,
        isActive: true,
      }, { merge: true });
      batch.delete(trackerRef);
      await batch.commit();
      return code;
    }

    if (role === "tracker") {
      const group = await resolveGroupAdmin(adminGroupId);
      batch.set(trackerRef, {
        uid,
        adminGroupId: group.code,
        linkedAdminUid: group.adminUid,
        displayName,
        lastPosition: null,
        trackingActive: false,
        trackingSessionId: null,
        trackingStoppedAt: null,
        createdAt: now,
        updatedAt: now,
      }, { merge: true });
      batch.delete(groupAdminRef);
      await batch.commit();
      return group.code;
    }

    batch.delete(groupAdminRef);
    batch.delete(trackerRef);
    await batch.commit();
    return null;
  }

  const searchManagedUsers = onCall({ region: REGION, timeoutSeconds: 30 }, async (request) => {
    await assertSuperAdmin(request);
    const query = cleanString(request.data?.query, 120).toLowerCase();
    const limit = Math.min(Math.max(Number(request.data?.limit) || 100, 1), 300);
    const snapshot = await db.collection("users").orderBy("updatedAt", "desc").limit(limit).get();
    const users = snapshot.docs.map((doc) => {
      const data = doc.data() || {};
      return {
        uid: doc.id,
        email: data.email || "",
        displayName: data.displayName || "",
        role: data.role || "user",
        isActive: data.isActive !== false,
        isAdmin: data.isAdmin === true,
        adminGroupId: data.adminGroupId || data.groupId || null,
        updatedAt: data.updatedAt?.toDate?.()?.toISOString?.() || null,
      };
    }).filter((user) => {
      if (!query) return true;
      return [user.uid, user.email, user.displayName, user.role, user.adminGroupId]
        .some((value) => String(value || "").toLowerCase().includes(query));
    });
    return { users };
  });

  const createManagedUser = onCall({ region: REGION, timeoutSeconds: 30 }, async (request) => {
    const actorUid = await assertSuperAdmin(request);
    const email = cleanString(request.data?.email, 160).toLowerCase();
    const password = cleanString(request.data?.password, 128);
    const displayName = cleanString(request.data?.displayName, 120);
    const role = normalizeRole(request.data?.role);
    const requestedGroupCode = cleanString(request.data?.adminGroupId, 6);

    if (!email.includes("@")) throw new HttpsError("invalid-argument", "Email invalide.");
    if (password.length < 12) throw new HttpsError("invalid-argument", "Mot de passe de 12 caractères minimum requis.");
    if (!displayName) throw new HttpsError("invalid-argument", "Nom affiché requis.");
    if (!ALLOWED_ROLES.has(role)) throw new HttpsError("invalid-argument", "Rôle non autorisé.");

    let record;
    try {
      record = await admin.auth().createUser({ email, password, displayName, emailVerified: true, disabled: false });
      const groupCode = await writeRoleProfiles({
        uid: record.uid,
        displayName,
        role,
        adminGroupId: requestedGroupCode || null,
      });
      await db.collection("users").doc(record.uid).set({
        email,
        displayName,
        role,
        isAdmin: role === "admin",
        isActive: true,
        groupId: role === "tracker" ? groupCode : null,
        adminGroupId: role === "group" ? groupCode : null,
        createdBySuperAdminUid: actorUid,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });
      await db.collection("admin_audit_logs").add({
        actorUid,
        action: "create_user",
        targetUid: record.uid,
        role,
        adminGroupId: groupCode,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      return {
        uid: record.uid,
        email,
        displayName,
        role,
        adminGroupId: groupCode,
        qrPayload: groupCode ? JSON.stringify({ type: "maslive_group", code: groupCode, groupName: displayName }) : null,
      };
    } catch (error) {
      if (record?.uid) await admin.auth().deleteUser(record.uid).catch(() => null);
      if (error instanceof HttpsError) throw error;
      if (error?.code === "auth/email-already-exists") throw new HttpsError("already-exists", "Cet email existe déjà.");
      logger.error("createManagedUser failed", error);
      throw new HttpsError("internal", "Création du compte impossible.");
    }
  });

  const updateManagedUser = onCall({ region: REGION, timeoutSeconds: 30 }, async (request) => {
    const actorUid = await assertSuperAdmin(request);
    const targetUid = cleanString(request.data?.uid, 128);
    if (!targetUid) throw new HttpsError("invalid-argument", "UID requis.");
    const userRef = db.collection("users").doc(targetUid);
    const currentSnap = await userRef.get();
    if (!currentSnap.exists) throw new HttpsError("not-found", "Utilisateur introuvable.");
    const current = currentSnap.data() || {};
    const currentRole = cleanString(current.role, 40);
    if (currentRole === "superAdmin" && targetUid !== actorUid) {
      throw new HttpsError("permission-denied", "Un autre SuperAdmin ne peut pas être modifié ici.");
    }

    const displayName = cleanString(request.data?.displayName ?? current.displayName, 120);
    const email = cleanString(request.data?.email ?? current.email, 160).toLowerCase();
    const role = normalizeRole(request.data?.role ?? current.role);
    const isActive = request.data?.isActive !== false;
    const password = cleanString(request.data?.password, 128);
    const requestedGroupCode = cleanString(request.data?.adminGroupId, 6);

    const authPatch = { displayName, email, disabled: !isActive };
    if (password) {
      if (password.length < 12) throw new HttpsError("invalid-argument", "Mot de passe de 12 caractères minimum requis.");
      authPatch.password = password;
    }
    await admin.auth().updateUser(targetUid, authPatch);
    const groupCode = await writeRoleProfiles({
      uid: targetUid,
      displayName,
      role,
      adminGroupId: requestedGroupCode || current.adminGroupId || current.groupId || null,
    });
    await userRef.set({
      email,
      displayName,
      role,
      isAdmin: role === "admin",
      isActive,
      groupId: role === "tracker" ? groupCode : null,
      adminGroupId: role === "group" ? groupCode : null,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
    await db.collection("admin_audit_logs").add({
      actorUid,
      action: "update_user",
      targetUid,
      role,
      adminGroupId: groupCode,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    return { uid: targetUid, role, adminGroupId: groupCode };
  });

  const deleteManagedUser = onCall({ region: REGION, timeoutSeconds: 30 }, async (request) => {
    const actorUid = await assertSuperAdmin(request);
    const targetUid = cleanString(request.data?.uid, 128);
    if (!targetUid) throw new HttpsError("invalid-argument", "UID requis.");
    if (targetUid === actorUid) throw new HttpsError("failed-precondition", "Vous ne pouvez pas supprimer votre propre compte.");
    const userRef = db.collection("users").doc(targetUid);
    const snap = await userRef.get();
    const profile = snap.data() || {};
    if (cleanString(profile.role, 40).toLowerCase().replace(/[ -]/g, "") === "superadmin") {
      throw new HttpsError("permission-denied", "Suppression d’un SuperAdmin interdite.");
    }

    const groupAdminSnap = await db.collection("group_admins").doc(targetUid).get();
    const groupCode = groupAdminSnap.data()?.adminGroupId || profile.adminGroupId || null;
    const batch = db.batch();
    batch.delete(userRef);
    batch.delete(db.collection("group_trackers").doc(targetUid));
    batch.delete(db.collection("group_admins").doc(targetUid));
    if (groupCode) batch.delete(db.collection("group_admin_codes").doc(String(groupCode)));
    batch.set(db.collection("deleted_users_history").doc(targetUid), {
      uid: targetUid,
      email: profile.email || null,
      displayName: profile.displayName || null,
      role: profile.role || "user",
      adminGroupId: groupCode,
      deletedByUid: actorUid,
      deletedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
    await batch.commit();
    await admin.auth().deleteUser(targetUid).catch((error) => {
      if (error?.code !== "auth/user-not-found") throw error;
    });
    return { deleted: true, uid: targetUid };
  });

  return {
    searchManagedUsers,
    createManagedUser,
    updateManagedUser,
    deleteManagedUser,
  };
};
