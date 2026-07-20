"use strict"

const crypto = require("node:crypto")

module.exports = function createPhotographerFinalOverrides({
  admin,
  db,
  onCall,
  HttpsError,
  legacyExports,
  photographerEndToEnd,
}) {
  const region = "us-east1"
  const serverTimestamp = () => admin.firestore.FieldValue.serverTimestamp()

  function text(value, max = 500) {
    return typeof value === "string" ? value.trim().slice(0, max) : ""
  }

  function timestampMs(value) {
    if (value && typeof value.toMillis === "function") return value.toMillis()
    const parsed = Date.parse(value || "")
    return Number.isFinite(parsed) ? parsed : 0
  }

  function promoCode(request) {
    return text(request?.data?.promoCode, 40).toUpperCase()
  }

  async function promoDefinition(code) {
    if (!code) return null
    const snapshot = await db.collection("config").doc("promo_codes").get()
    return snapshot.exists ? ((snapshot.data() || {}).codes || {})[code] || null : null
  }

  async function cartKinds(uid) {
    const snapshot = await db.collection("users").doc(uid).collection("cart_items").get()
    const types = new Set(snapshot.docs.map((doc) => text((doc.data() || {}).itemType, 30).toLowerCase()))
    return {
      hasMedia: types.has("media"),
      hasMerch: types.has("merch"),
      empty: snapshot.empty,
    }
  }

  async function rejectPhotographerPromoInMixed(request) {
    const code = promoCode(request)
    if (!code) return
    const promo = await promoDefinition(code)
    if (promo?.source === "photographer") {
      throw new HttpsError(
        "failed-precondition",
        "Ce code photographe est réservé à un panier composé uniquement de photos et de packs média.",
      )
    }
  }

  const validatePhotographerPromoCode = onCall(
    { region, timeoutSeconds: 30 },
    async (request) => {
      const uid = request.auth?.uid
      if (!uid) throw new HttpsError("unauthenticated", "Authentication required")
      const kinds = await cartKinds(uid)
      if (!kinds.hasMedia || kinds.hasMerch) {
        return {
          valid: false,
          discountCents: 0,
          message: kinds.hasMerch
            ? "Les codes photographes sont valables uniquement sur un panier 100 % média."
            : "Ajoute d’abord une photo ou un pack média au panier.",
        }
      }
      const result = await photographerEndToEnd.validatePhotographerPromoCode(request)
      if (result?.valid === true) {
        const code = promoCode(request)
        const expiresAt = admin.firestore.Timestamp.fromMillis(Date.now() + (10 * 60 * 1000))
        await db.collection("users").doc(uid).collection("carts").doc("media_checkout").set({
          validatedPhotographerPromoCode: code,
          validatedPhotographerPromoExpiresAt: expiresAt,
          validatedPhotographerPromoAt: serverTimestamp(),
          updatedAt: serverTimestamp(),
        }, { merge: true })
      }
      return result
    },
  )

  const validatePromoCode = onCall(
    { region, timeoutSeconds: 30 },
    async (request) => {
      const code = promoCode(request)
      const promo = await promoDefinition(code)
      if (promo?.source === "photographer") {
        return {
          valid: false,
          discountCents: 0,
          message: "Utilise ce code dans un panier composé uniquement de photos.",
        }
      }
      return legacyExports.validatePromoCode(request)
    },
  )

  const createMediaMarketplaceCheckout = onCall(
    { region, timeoutSeconds: 60, memory: "512MiB" },
    async (request) => {
      const uid = request.auth?.uid
      if (!uid) throw new HttpsError("unauthenticated", "Authentication required")
      const stateRef = db.collection("users").doc(uid).collection("carts").doc("media_checkout")
      const stateSnapshot = await stateRef.get()
      const state = stateSnapshot.exists ? stateSnapshot.data() || {} : {}
      const code = text(state.validatedPhotographerPromoCode, 40).toUpperCase()
      const expiresAt = timestampMs(state.validatedPhotographerPromoExpiresAt)
      if (code && expiresAt > Date.now()) {
        try {
          const result = await photographerEndToEnd.createMediaMarketplacePromoCheckout({
            ...request,
            data: {
              ...(request.data || {}),
              promoCode: code,
            },
          })
          await stateRef.set({
            validatedPhotographerPromoCode: null,
            validatedPhotographerPromoExpiresAt: null,
            consumedPhotographerPromoCode: code,
            consumedPhotographerPromoAt: serverTimestamp(),
            updatedAt: serverTimestamp(),
          }, { merge: true })
          return result
        } catch (error) {
          await stateRef.set({
            validatedPhotographerPromoCode: null,
            validatedPhotographerPromoExpiresAt: null,
            promoCheckoutError: text(error?.message, 300),
            updatedAt: serverTimestamp(),
          }, { merge: true })
          throw error
        }
      }
      return legacyExports.createMediaMarketplaceCheckout(request)
    },
  )

  const createMixedCartCheckoutSession = onCall(
    { region, timeoutSeconds: 60, memory: "512MiB" },
    async (request) => {
      await rejectPhotographerPromoInMixed(request)
      return legacyExports.createMixedCartCheckoutSession(request)
    },
  )

  const createMixedCartPaymentIntent = onCall(
    { region, timeoutSeconds: 60, memory: "512MiB" },
    async (request) => {
      await rejectPhotographerPromoInMixed(request)
      return legacyExports.createMixedCartPaymentIntent(request)
    },
  )

  const generateGalleryPrivateLink = onCall(
    { region, timeoutSeconds: 30 },
    async (request) => {
      const result = await photographerEndToEnd.generateGalleryPrivateLink(request)
      const galleryId = text(request.data?.galleryId, 160)
      const token = text(result?.token, 600)
      if (!galleryId || !token) throw new HttpsError("internal", "Private link generation failed")
      return {
        ...result,
        url: `https://maslive.web.app/?galleryId=${encodeURIComponent(galleryId)}&access=${encodeURIComponent(token)}#/media-marketplace`,
        tokenFingerprint: crypto.createHash("sha256").update(token).digest("hex").slice(0, 12),
      }
    },
  )

  return {
    validatePhotographerPromoCode,
    validatePromoCode,
    createMediaMarketplaceCheckout,
    createMixedCartCheckoutSession,
    createMixedCartPaymentIntent,
    generateGalleryPrivateLink,
  }
}
