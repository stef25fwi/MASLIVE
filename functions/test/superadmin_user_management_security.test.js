"use strict";

const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");
const assert = require("node:assert/strict");

const root = path.resolve(__dirname, "..", "..");
const moduleSource = fs.readFileSync(
  path.join(root, "functions", "src", "superadmin-user-management.js"),
  "utf8"
);
const indexSource = fs.readFileSync(
  path.join(root, "functions", "index.js"),
  "utf8"
);
const authSource = fs.readFileSync(
  path.join(root, "app", "lib", "services", "auth_service.dart"),
  "utf8"
);

test("la gestion des comptes reste réservée au SuperAdmin", () => {
  assert.match(moduleSource, /Action réservée au SuperAdmin/);
  assert.match(moduleSource, /assertSuperAdmin\(request\)/);
  assert.match(moduleSource, /request\.auth\?\.uid/);
});

test("les opérations critiques conservent leurs garde-fous", () => {
  assert.match(moduleSource, /Mot de passe de 12 caractères minimum requis/);
  assert.match(moduleSource, /Vous ne pouvez pas supprimer votre propre compte/);
  assert.match(moduleSource, /Suppression d’un SuperAdmin interdite/);
  assert.match(moduleSource, /admin_audit_logs/);
  assert.doesNotMatch(moduleSource, /qrPayloadForGroup\([^)]*password/);
});

test("le module expose toutes les opérations et reste branché dans index", () => {
  for (const name of [
    "searchManagedUsers",
    "createManagedUser",
    "updateManagedUser",
    "regenerateManagedGroupCode",
    "deleteManagedUser",
  ]) {
    assert.match(moduleSource, new RegExp(name));
  }
  assert.match(indexSource, /createSuperAdminUserManagementHandlers/);
  assert.match(indexSource, /Object\.assign\(exports, superAdminUserManagement\)/);
});

test("la déconnexion Firebase est prioritaire sur la session Google", () => {
  const firebaseSignOut = authSource.indexOf("await _auth.signOut()");
  const googleSignOut = authSource.indexOf("GoogleSignIn.instance.signOut()");
  assert.ok(firebaseSignOut >= 0, "Firebase signOut absent");
  assert.ok(googleSignOut >= 0, "Google signOut absent");
  assert.ok(firebaseSignOut < googleSignOut, "Firebase doit être déconnecté en premier");
});
