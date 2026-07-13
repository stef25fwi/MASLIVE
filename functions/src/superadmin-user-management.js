"use strict";

module.exports = function createSuperAdminUserManagementHandlers(deps) {
  const { admin, db, onCall, HttpsError, logger } = deps;
  const REGION = "us-east1";
  const ALLOWED_ROLES = new Set(["user", "tracker", "group", "admin"]);
  const MAX_SEARCH_RESULTS = 1000;

  function cleanString(value, max = 160) {
    if (typeof value !== "string") return "";
    return value.trim().slice(0, max);
  }

  function normalizeRole(value) {
    const raw = cleanString(value, 40).toLowerCase().replace(/[ -]/g, "_");
    if (["group", "group_admin", "admin_group", "admin_groupe"].includes(raw)) return "group";
    if (["tracker", "tracker_group", "tracker_groupe"].includes(raw)) return "tracker";
    if (raw === "admin") return "admin";
    if (raw === "superadmin" || raw === "super_admin") return "superAdmin";
    return "user";
  }

  function qrPayloadForGroup(code, displayName) {
    if (!code) return null;
    return JSON.stringify({
      type: "maslive_group",
      code,
      groupName: displayName || "Groupe MASLIVE",
    });
  }

  async function assertSuperAdmin(request) {
    const uid = request.auth?.uid;
    if (!uid) throw new HttpsError("unauthenticated", "Authentification requise.");
    const snap = await db.collection("users").doc(uid).get();
    const data = snap.data() || {};
    const role = normalizeRole(data.role);
    if (role !== "superAdmin") {
      throw new HttpsError("permission-denied", "Action réservée au SuperAdmin.");
    }
    return uid;
  }

  async function writeAudit({ actorUid, action, targetUid, details = {} }) {
    await db.collection("admin_audit_logs").add({
      actorUid,
      action,
      targetUid: targetUid || null,
      details,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  }

  async function generateUniqueGroupCode() {
    for (let attempt = 0; attempt < 40; attempt += 1) {
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

  async function getRoleContext(uid, userData = null) {
    const profile = userData || (await db.collection("users").doc(uid).get()).data() || {};
    const [groupAdminSnap, trackerSnap] = await Promise.all([
      db.collection("group_admins").doc(uid).get(),
      db.collection("group_trackers").doc(uid).get(),
    ]);
    return {
      role: normalizeRole(profile.role),
      groupAdminId: groupAdminSnap.data()?.adminGroupId || profile.adminGroupId || null,
      trackerGroupId: trackerSnap.data()?.adminGroupId || profile.groupId || null,
    };
  }

  async function detachTrackersFromGroup(groupCode, actorUid) {
    if (!groupCode) return 0;
    const trackersSnap = await db
      .collection("group_trackers")
      .where("adminGroupId", "==", String(groupCode))
      .get();
    if (trackersSnap.empty) return 0;

    const chunks = [];
    for (let i = 0; i < trackersSnap.docs.length; i += 400) {
      chunks.push(trackersSnap.docs.slice(i, i + 400));
    }
    for (const docs of chunks) {
      const batch = db.batch();
      for (const trackerDoc of docs) {
        batch.delete(trackerDoc.ref);
        batch.set(
          db.collection("users").doc(trackerDoc.id),
          {
            role: "user",
            groupId: null,
            adminGroupId: null,
            isAdmin: false,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            detachedBySuperAdminUid: actorUid,
          },
          { merge: true }
        );
      }
      await batch.commit();
      await Promise.all(
        docs.map((trackerDoc) =>
          admin.auth().setCustomUserClaims(trackerDoc.id, { role: "user", isAdmin: false }).catch(() => null)
        )
      );
    }
    return trackersSnap.size;
  }

  async function clearPreviousRoleProfiles({ uid, roleContext, nextRole, actorUid }) {
    const batch = db.batch();
    if (roleContext.role === "group" && nextRole !== "group") {
      if (roleContext.groupAdminId) {
        batch.delete(db.collection("group_admin_codes").doc(String(roleContext.groupAdminId)));
      }
      batch.delete(db.collection("group_admins").doc(uid));
    }
    if (roleContext.role === "tracker" && nextRole !== "tracker") {
      batch.delete(db.collection("group_trackers").doc(uid));
    }
    await batch.commit();

    if (roleContext.role === "group" && nextRole !== "group" && roleContext.groupAdminId) {
      await detachTrackersFromGroup(roleContext.groupAdminId, actorUid);
    }
  }

  async function writeRoleProfile({ uid, displayName, role, requestedGroupCode, existingGroupCode = null }) {
    const now = admin.firestore.FieldValue.serverTimestamp();

    if (role === "group") {
      const code = requestedGroupCode || existingGroupCode || (await generateUniqueGroupCode());
      const batch = db.batch();
      batch.set(
        db.collection("group_admins").doc(uid),
        {
          uid,
          adminGroupId: code,
          displayName,
          isVisible: true,
          visibleMapIds: [],
          lastPosition: null,
          averagePosition: null,
          updatedAt: now,
          createdAt: now,
        },
        { merge: true }
      );
      batch.set(
        db.collection("group_admin_codes").doc(code),
        { adminUid: uid, isActive: true, updatedAt: now, createdAt: now },
        { merge: true }
      );
      batch.delete(db.collection("group_trackers").doc(uid));
      await batch.commit();
      return code;
    }

    if (role === "tracker") {
      const group = await resolveGroupAdmin(requestedGroupCode || existingGroupCode);
      const batch = db.batch();
      batch.set(
        db.collection("group_trackers").doc(uid),
        {
          uid,
          adminGroupId: group.code,
          linkedAdminUid: group.adminUid,
          displayName,
          lastPosition: null,
          trackingActive: false,
          trackingSessionId: null,
          trackingStoppedAt: null,
          updatedAt: now,
          createdAt: now,
        },
        { merge: true }
      );
      batch.delete(db.collection("group_admins").doc(uid));
      await batch.commit();
      return group.code;
    }

    const batch = db.batch();
    batch.delete(db.collection("group_admins").doc(uid));
    batch.delete(db.collection("group_trackers").doc(uid));
    await batch.commit();
    return null;
  }

  async function listAuthUsers() {
    const records = [];
    let pageToken;
    do {
      const page = await admin.auth().listUsers(Math.min(1000, MAX_SEARCH_RESULTS - records.length), pageToken);
      records.push(...page.users);
      pageToken = records.length < MAX_SEARCH_RESULTS ? page.pageToken : undefined;
    } while (pageToken && records.length < MAX_SEARCH_RESULTS);
    return records;
  }

  const searchManagedUsers = onCall({ region: REGION, timeoutSeconds: 60 }, async (request) => {
    await assertSuperAdmin(request);
    const query = cleanString(request.data?.query, 160).toLowerCase();
    const authUsers = await listAuthUsers();
    const refs = authUsers.map((record) => db.collection("users").doc(record.uid));
    const profileSnaps = [];
    for (let i = 0; i < refs.length; i += 100) {
      profileSnaps.push(...(await db.getAll(...refs.slice(i, i + 100))));
    }
    const profileByUid = new Map(profileSnaps.map((snap) => [snap.id, snap.data() || {}]));

    const users = authUsers
      .map((record) => {
        const data = profileByUid.get(record.uid) || {};
        return {
          uid: record.uid,
          email: record.email || data.email || "",
          displayName: record.displayName || data.displayName || "",
          role: normalizeRole(data.role),
          isActive: record.disabled !== true && data.isActive !== false,
          isAdmin: data.isAdmin === true,
          adminGroupId: data.adminGroupId || data.groupId || null,
          emailVerified: record.emailVerified === true,
          createdAt: record.metadata?.creationTime || null,
          lastSignInAt: record.metadata?.lastSignInTime || null,
        };
      })
      .filter((user) => {
        if (!query) return true;
        return [user.uid, user.email, user.displayName, user.role, user.adminGroupId]
          .some((value) => String(value || "").toLowerCase().includes(query));
      })
      .slice(0, 300);

    return { users, truncated: authUsers.length >= MAX_SEARCH_RESULTS };
  });

  const createManagedUser = onCall({ region: REGION, timeoutSeconds: 45 }, async (request) => {
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
    if (role === "tracker" && !/^\d{6}$/.test(requestedGroupCode)) {
      throw new HttpsError("invalid-argument", "Le Tracker doit être rattaché à un code Admin Groupe valide.");
    }

    let record;
    try {
      record = await admin.auth().createUser({
        email,
        password,
        displayName,
        emailVerified: true,
        disabled: false,
      });
      const groupCode = await writeRoleProfile({
        uid: record.uid,
        displayName,
        role,
        requestedGroupCode: requestedGroupCode || null,
      });
      await admin.auth().setCustomUserClaims(record.uid, {
        role,
        isAdmin: role === "admin",
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
      await writeAudit({
        actorUid,
        action: "create_user",
        targetUid: record.uid,
        details: { role, adminGroupId: groupCode, email },
      });
      return {
        uid: record.uid,
        email,
        displayName,
        role,
        adminGroupId: groupCode,
        qrPayload: qrPayloadForGroup(groupCode, displayName),
      };
    } catch (error) {
      if (record?.uid) await admin.auth().deleteUser(record.uid).catch(() => null);
      if (error instanceof HttpsError) throw error;
      if (error?.code === "auth/email-already-exists") {
        throw new HttpsError("already-exists", "Cet email existe déjà.");
      }
      logger.error("createManagedUser failed", error);
      throw new HttpsError("internal", "Création du compte impossible.");
    }
  });

  const updateManagedUser = onCall({ region: REGION, timeoutSeconds: 45 }, async (request) => {
    const actorUid = await assertSuperAdmin(request);
    const targetUid = cleanString(request.data?.uid, 128);
    if (!targetUid) throw new HttpsError("invalid-argument", "UID requis.");
    const userRef = db.collection("users").doc(targetUid);
    const currentSnap = await userRef.get();
    if (!currentSnap.exists) throw new HttpsError("not-found", "Utilisateur introuvable.");
    const current = currentSnap.data() || {};
    const currentRole = normalizeRole(current.role);
    if (currentRole === "superAdmin") {
      throw new HttpsError("permission-denied", "Un compte SuperAdmin ne peut pas être modifié ici.");
    }

    const displayName = cleanString(request.data?.displayName ?? current.displayName, 120);
    const email = cleanString(request.data?.email ?? current.email, 160).toLowerCase();
    const role = normalizeRole(request.data?.role ?? current.role);
    const isActive = request.data?.isActive !== false;
    const password = cleanString(request.data?.password, 128);
    const requestedGroupCode = cleanString(request.data?.adminGroupId, 6);
    if (!ALLOWED_ROLES.has(role)) throw new HttpsError("invalid-argument", "Rôle non autorisé.");
    if (role === "tracker" && !/^\d{6}$/.test(requestedGroupCode || current.groupId || "")) {
      throw new HttpsError("invalid-argument", "Code Admin Groupe requis pour un Tracker.");
    }

    const roleContext = await getRoleContext(targetUid, current);
    const authPatch = { displayName, email, disabled: !isActive };
    if (password) {
      if (password.length < 12) throw new HttpsError("invalid-argument", "Mot de passe de 12 caractères minimum requis.");
      authPatch.password = password;
    }
    await admin.auth().updateUser(targetUid, authPatch);
    await clearPreviousRoleProfiles({ uid: targetUid, roleContext, nextRole: role, actorUid });
    const groupCode = await writeRoleProfile({
      uid: targetUid,
      displayName,
      role,
      requestedGroupCode: requestedGroupCode || null,
      existingGroupCode: role === "group" ? roleContext.groupAdminId : roleContext.trackerGroupId,
    });
    await admin.auth().setCustomUserClaims(targetUid, { role, isAdmin: role === "admin" });
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
    await writeAudit({
      actorUid,
      action: "update_user",
      targetUid,
      details: { previousRole: currentRole, role, adminGroupId: groupCode, isActive },
    });
    return {
      uid: targetUid,
      role,
      adminGroupId: groupCode,
      qrPayload: qrPayloadForGroup(groupCode, displayName),
    };
  });

  const regenerateManagedGroupCode = onCall({ region: REGION, timeoutSeconds: 45 }, async (request) => {
    const actorUid = await assertSuperAdmin(request);
    const targetUid = cleanString(request.data?.uid, 128);
    if (!targetUid) throw new HttpsError("invalid-argument", "UID requis.");
    const userSnap = await db.collection("users").doc(targetUid).get();
    const user = userSnap.data() || {};
    if (!userSnap.exists || normalizeRole(user.role) !== "group") {
      throw new HttpsError("failed-precondition", "Ce compte n’est pas un Admin Groupe.");
    }
    const groupSnap = await db.collection("group_admins").doc(targetUid).get();
    const oldCode = groupSnap.data()?.adminGroupId || user.adminGroupId;
    if (!oldCode) throw new HttpsError("not-found", "Code groupe actuel introuvable.");
    const newCode = await generateUniqueGroupCode();
    const trackersSnap = await db.collection("group_trackers").where("adminGroupId", "==", String(oldCode)).get();

    const batch = db.batch();
    batch.delete(db.collection("group_admin_codes").doc(String(oldCode)));
    batch.set(db.collection("group_admin_codes").doc(newCode), {
      adminUid: targetUid,
      isActive: true,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    batch.set(db.collection("group_admins").doc(targetUid), {
      adminGroupId: newCode,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
    batch.set(db.collection("users").doc(targetUid), {
      adminGroupId: newCode,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
    for (const trackerDoc of trackersSnap.docs) {
      batch.set(trackerDoc.ref, {
        adminGroupId: newCode,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });
      batch.set(db.collection("users").doc(trackerDoc.id), {
        groupId: newCode,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });
    }
    await batch.commit();
    await writeAudit({
      actorUid,
      action: "regenerate_group_code",
      targetUid,
      details: { oldCode, newCode, migratedTrackers: trackersSnap.size },
    });
    return {
      uid: targetUid,
      oldCode,
      adminGroupId: newCode,
      migratedTrackers: trackersSnap.size,
      qrPayload: qrPayloadForGroup(newCode, user.displayName),
    };
  });

  const deleteManagedUser = onCall({ region: REGION, timeoutSeconds: 60 }, async (request) => {
    const actorUid = await assertSuperAdmin(request);
    const targetUid = cleanString(request.data?.uid, 128);
    if (!targetUid) throw new HttpsError("invalid-argument", "UID requis.");
    if (targetUid === actorUid) {
      throw new HttpsError("failed-precondition", "Vous ne pouvez pas supprimer votre propre compte.");
    }
    const userRef = db.collection("users").doc(targetUid);
    const snap = await userRef.get();
    const profile = snap.data() || {};
    if (normalizeRole(profile.role) === "superAdmin") {
      throw new HttpsError("permission-denied", "Suppression d’un SuperAdmin interdite.");
    }

    const roleContext = await getRoleContext(targetUid, profile);
    let detachedTrackers = 0;
    if (roleContext.role === "group" && roleContext.groupAdminId) {
      detachedTrackers = await detachTrackersFromGroup(roleContext.groupAdminId, actorUid);
    }

    const batch = db.batch();
    batch.delete(userRef);
    batch.delete(db.collection("group_trackers").doc(targetUid));
    batch.delete(db.collection("group_admins").doc(targetUid));
    if (roleContext.groupAdminId) {
      batch.delete(db.collection("group_admin_codes").doc(String(roleContext.groupAdminId)));
    }
    batch.set(db.collection("deleted_users_history").doc(targetUid), {
      uid: targetUid,
      email: profile.email || null,
      displayName: profile.displayName || null,
      role: profile.role || "user",
      adminGroupId: roleContext.groupAdminId || roleContext.trackerGroupId || null,
      detachedTrackers,
      deletedByUid: actorUid,
      deletedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
    await batch.commit();
    await admin.auth().deleteUser(targetUid).catch((error) => {
      if (error?.code !== "auth/user-not-found") throw error;
    });
    await writeAudit({
      actorUid,
      action: "delete_user",
      targetUid,
      details: { role: roleContext.role, detachedTrackers },
    });
    return { deleted: true, uid: targetUid, detachedTrackers };
  });

  return {
    searchManagedUsers,
    createManagedUser,
    updateManagedUser,
    regenerateManagedGroupCode,
    deleteManagedUser,
  };
};
