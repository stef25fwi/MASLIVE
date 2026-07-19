const legacyFunctions = require("./index")
const admin = require("firebase-admin")
const sharp = require("sharp")
const { logger } = require("firebase-functions/v2")
const { onCall, HttpsError } = require("firebase-functions/v2/https")
const { onSchedule } = require("firebase-functions/v2/scheduler")
const createPhotographerMediaManagement = require("./src/photographer-media-management")

if (admin.apps.length === 0) {
  admin.initializeApp()
}

Object.assign(exports, legacyFunctions)
Object.assign(
  exports,
  createPhotographerMediaManagement({
    admin,
    db: admin.firestore(),
    onCall,
    onSchedule,
    HttpsError,
    logger,
    sharp,
  })
)
