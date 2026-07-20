"use strict"

const legacyExports = require("./index")
const admin = require("firebase-admin")
const stripeModule = require("stripe")
const { defineSecret } = require("firebase-functions/params")
const { onCall, onRequest, HttpsError } = require("firebase-functions/v2/https")
const { onDocumentUpdated } = require("firebase-functions/v2/firestore")
const createPhotographerSubscriptionLifecycle = require("./src/photographer-subscription-lifecycle")
const createPhotographerCompleteFlow = require("./src/photographer-complete-flow")

const STRIPE_SECRET_KEY = defineSecret("STRIPE_SECRET_KEY")
let stripe = null

function getStripe() {
  if (!stripe) {
    const apiKey = STRIPE_SECRET_KEY.value() || process.env.STRIPE_SECRET_KEY
    if (!apiKey) {
      throw new Error(
        "STRIPE_SECRET_KEY not configured. Run: " +
        "firebase functions:secrets:set STRIPE_SECRET_KEY",
      )
    }
    stripe = stripeModule(apiKey)
  }
  return stripe
}

function isAllowedRedirectUrl(value) {
  if (typeof value !== "string" || value.trim().length === 0) return false
  try {
    const url = new URL(value)
    if (
      url.protocol === "http:" &&
      (url.hostname === "localhost" || url.hostname === "127.0.0.1")
    ) {
      return true
    }
    if (url.protocol !== "https:") return false
    return url.hostname === "maslive.web.app" || url.hostname === "maslive.firebaseapp.com"
  } catch (_) {
    return false
  }
}

const db = admin.firestore()

const photographerSubscriptionLifecycle = createPhotographerSubscriptionLifecycle({
  admin,
  db,
  onCall,
  HttpsError,
  STRIPE_SECRET_KEY,
  getStripe,
  isAllowedRedirectUrl,
})

const photographerCompleteFlow = createPhotographerCompleteFlow({
  admin,
  db,
  onCall,
  onRequest,
  onDocumentUpdated,
  HttpsError,
})

module.exports = {
  ...legacyExports,
  ...photographerSubscriptionLifecycle,
  ...photographerCompleteFlow,
}
