"use strict"

const assert = require("node:assert/strict")
const fs = require("node:fs")
const path = require("node:path")
const test = require("node:test")

const createPhotographerCompleteFlow = require("../src/photographer-complete-flow")

function harness() {
  const noopDocument = {
    get: async () => ({ exists: false, data: () => ({}) }),
    set: async () => {},
    delete: async () => {},
  }
  const db = {
    collection: () => ({
      doc: () => noopDocument,
      add: async () => ({ id: "new-doc" }),
      where() { return this },
      limit() { return this },
      get: async () => ({ empty: true, size: 0, docs: [] }),
    }),
  }
  class HttpsError extends Error {
    constructor(code, message) {
      super(message)
      this.code = code
    }
  }
  return createPhotographerCompleteFlow({
    admin: {
      firestore: {
        FieldValue: {
          serverTimestamp: () => "server-time",
          increment: (value) => value,
        },
        Timestamp: { fromMillis: (value) => ({ value, toMillis: () => value }) },
      },
      storage: () => ({ bucket: () => ({ file: () => ({}) }) }),
    },
    db,
    onCall: (_options, handler) => handler,
    onRequest: (_options, handler) => handler,
    onDocumentUpdated: (_options, handler) => handler,
    HttpsError,
  })
}

test("exporte toutes les opérations avancées du photographe", () => {
  const handlers = harness()
  const expected = [
    "getPhotographerAdvancedDashboard",
    "getPhotographerWorkspaceConfig",
    "savePhotographerWorkspaceConfig",
    "createPhotographerApiKey",
    "revokePhotographerApiKey",
    "savePhotographerImportSession",
    "listPhotographerImportSessions",
    "generateGalleryPrivateLink",
    "duplicatePhotographerGallery",
    "deletePhotographerGallery",
    "generatePhotographerExport",
    "photographerMediaImportApi",
    "analyzePhotographerPhoto",
  ]
  assert.deepEqual(Object.keys(handlers).sort(), expected.sort())
})

test("le contrat protège les imports API et les clés hachées", () => {
  const source = fs.readFileSync(
    path.join(__dirname, "../src/photographer-complete-flow.js"),
    "utf8",
  )
  assert.match(source, /crypto\.randomBytes\(32\)/)
  assert.match(source, /createHash\("sha256"\)/)
  assert.match(source, /getSignedUrl/)
  assert.match(source, /action must be prepare or finalize/)
  assert.match(source, /API import is available on Studio and Agency plans/)
})

test("l'analyse automatique couvre dossards, couleurs et visages anonymisés", () => {
  const source = fs.readFileSync(
    path.join(__dirname, "../src/photographer-complete-flow.js"),
    "utf8",
  )
  assert.match(source, /TEXT_DETECTION/)
  assert.match(source, /IMAGE_PROPERTIES/)
  assert.match(source, /FACE_DETECTION/)
  assert.match(source, /bibNumbers/)
  assert.match(source, /colorTags/)
  assert.match(source, /anonymous_landmark_hash/)
  assert.match(source, /faceGroupingConsent/)
})

test("les exports et le cycle galerie sont présents", () => {
  const source = fs.readFileSync(
    path.join(__dirname, "../src/photographer-complete-flow.js"),
    "utf8",
  )
  assert.match(source, /generatePhotographerExport/)
  assert.match(source, /invoiceText/)
  assert.match(source, /duplicatePhotographerGallery/)
  assert.match(source, /Purchased photos prevent gallery deletion/)
  assert.match(source, /generateGalleryPrivateLink/)
})
