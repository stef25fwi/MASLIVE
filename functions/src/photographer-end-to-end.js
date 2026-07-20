"use strict"

const crypto = require("node:crypto")
const sharp = require("sharp")
const {
  planFor,
  photoSelectionPrice,
  mediaDeliveryQuote,
  stripeFeeEstimate,
  roundCurrency,
} = require("./media-marketplace-pricing")

module.exports = function createPhotographerEndToEnd({
  admin,
  db,
  onCall,
  onDocumentUpdated,
  HttpsError,
  STRIPE_SECRET_KEY,
  getStripe,
  isAllowedRedirectUrl,
}) {
  const region = "us-east1"
  const serverTimestamp = () => admin.firestore.FieldValue.serverTimestamp()
  const increment = (value) => admin.firestore.FieldValue.increment(value)
  const WORKSPACES = "photographer_workspaces"
  const COLLABORATORS = "photographer_collaborators"
  const ACCESS_LOGS = "media_gallery_access_logs"
  const DOWNLOAD_LOGS = "media_download_logs"
  const ORDER_KIND = "media_marketplace_order"
  const SUCCESS_URL = "https://maslive.web.app/#/media-marketplace/success"
  const CANCEL_URL = "https://maslive.web.app/#/media-marketplace/cancel"

  function text(value, max = 500) {
    return typeof value === "string" ? value.trim().slice(0, max) : ""
  }

  function number(value, fallback = 0) {
    const parsed = Number(value)
    return Number.isFinite(parsed) ? parsed : fallback
  }

  function integer(value, fallback = 0) {
    return Math.trunc(number(value, fallback))
  }

  function list(value) {
    return Array.isArray(value) ? value : []
  }

  function unique(values) {
    return [...new Set(list(values).filter(Boolean))]
  }

  function timestampMs(value) {
    if (value && typeof value.toMillis === "function") return value.toMillis()
    if (typeof value === "number") return value
    const parsed = Date.parse(value || "")
    return Number.isFinite(parsed) ? parsed : 0
  }

  function sha256(value) {
    return crypto.createHash("sha256").update(String(value || "")).digest("hex")
  }

  function normalizeEmail(value) {
    return text(value, 320).toLowerCase()
  }

  function safeRole(value) {
    const role = text(value, 40).toLowerCase()
    return ["viewer", "editor", "manager", "finance"].includes(role) ? role : "editor"
  }

  function planLimits(planId) {
    switch (text(planId, 32).toLowerCase()) {
      case "agency":
        return { collaborators: 25, brands: 20, promotions: 100, api: true, customWatermark: true }
      case "studio":
        return { collaborators: 5, brands: 5, promotions: 30, api: true, customWatermark: true }
      case "pro":
        return { collaborators: 1, brands: 1, promotions: 10, api: false, customWatermark: false }
      default:
        return { collaborators: 0, brands: 1, promotions: 0, api: false, customWatermark: false }
    }
  }

  function isAdmin(auth) {
    const token = auth?.token || {}
    return token.admin === true || token.isAdmin === true || ["admin", "superadmin", "super-admin"].includes(token.role)
  }

  async function collaboratorContext(photographerId, auth) {
    if (!auth?.uid) return null
    const ref = db.collection(COLLABORATORS).doc(`${photographerId}_${auth.uid}`)
    const snapshot = await ref.get()
    if (!snapshot.exists) return null
    const data = snapshot.data() || {}
    if (data.status !== "accepted" || data.uid !== auth.uid) return null
    return { ref, ...data }
  }

  async function managedProfile(auth, photographerId, allowedRoles = ["owner", "manager"]) {
    if (!auth?.uid) throw new HttpsError("unauthenticated", "Authentication required")
    const id = text(photographerId, 160)
    if (!id) throw new HttpsError("invalid-argument", "photographerId is required")
    const ref = db.collection("photographers").doc(id)
    const snapshot = await ref.get()
    if (!snapshot.exists) throw new HttpsError("not-found", "Photographer profile not found")
    const profile = snapshot.data() || {}
    if (isAdmin(auth) || profile.ownerUid === auth.uid) {
      return { id, ref, profile, role: "owner", ownerUid: profile.ownerUid }
    }
    const collaborator = await collaboratorContext(id, auth)
    if (!collaborator || !allowedRoles.includes(collaborator.role)) {
      throw new HttpsError("permission-denied", "This photographer workspace is not available to you")
    }
    return { id, ref, profile, role: collaborator.role, ownerUid: profile.ownerUid, collaborator }
  }

  function cleanCollaborators(values, max) {
    return list(values).slice(0, max).map((value) => ({
      id: text(value?.id, 120) || crypto.randomUUID(),
      name: text(value?.name, 120),
      email: normalizeEmail(value?.email),
      role: safeRole(value?.role),
      status: text(value?.status, 40) || "invited",
    })).filter((value) => value.email)
  }

  function cleanBrands(values, max) {
    return list(values).slice(0, max).map((value) => ({
      id: text(value?.id, 120) || crypto.randomUUID(),
      name: text(value?.name, 120),
      logoUrl: text(value?.logoUrl, 1000),
      accentColor: text(value?.accentColor, 20),
      description: text(value?.description, 800),
      domain: text(value?.domain, 300),
    })).filter((value) => value.name)
  }

  function cleanPromotions(values, max, photographerId) {
    return list(values).slice(0, max).map((value) => ({
      id: text(value?.id, 120) || crypto.randomUUID(),
      code: text(value?.code, 40).toUpperCase(),
      percentOff: Math.max(0, Math.min(90, number(value?.percentOff))),
      amountOff: Math.max(0, number(value?.amountOff)),
      active: value?.active !== false,
      startsAt: text(value?.startsAt, 60) || null,
      endsAt: text(value?.endsAt, 60) || null,
      galleryIds: unique(list(value?.galleryIds).map((item) => text(item, 200))).slice(0, 100),
      photographerId,
    })).filter((value) => value.code && (value.percentOff > 0 || value.amountOff > 0))
  }

  function publicStorefront(config, limits) {
    const storefront = config?.storefront || {}
    return {
      headline: text(storefront.headline, 160),
      description: text(storefront.description, 1000),
      accentColor: text(storefront.accentColor, 20),
      layout: ["grid", "editorial", "minimal"].includes(text(storefront.layout, 30))
        ? text(storefront.layout, 30)
        : "grid",
      showPhotographerName: storefront.showPhotographerName !== false,
      showEventContext: storefront.showEventContext !== false,
      customWatermarkText: limits.customWatermark ? text(storefront.customWatermarkText, 80) : "",
      brands: cleanBrands(config?.brands, limits.brands).map((brand) => ({
        id: brand.id,
        name: brand.name,
        logoUrl: brand.logoUrl,
        accentColor: brand.accentColor,
        description: brand.description,
        domain: brand.domain,
      })),
    }
  }

  async function syncCollaborators(context, collaborators) {
    const existing = await db.collection(COLLABORATORS).where("photographerId", "==", context.id).get()
    const desiredEmails = new Set(collaborators.map((item) => item.email))
    const batch = db.batch()
    for (const doc of existing.docs) {
      const data = doc.data() || {}
      if (!desiredEmails.has(normalizeEmail(data.emailLower))) {
        batch.set(doc.ref, { status: "revoked", revokedAt: serverTimestamp(), updatedAt: serverTimestamp() }, { merge: true })
      }
    }
    for (const collaborator of collaborators) {
      const invitationId = `${context.id}_${sha256(collaborator.email).slice(0, 32)}`
      const invitationRef = db.collection(COLLABORATORS).doc(invitationId)
      const current = await invitationRef.get()
      const currentData = current.exists ? current.data() || {} : {}
      batch.set(invitationRef, {
        invitationId,
        photographerId: context.id,
        ownerUid: context.ownerUid,
        name: collaborator.name,
        emailLower: collaborator.email,
        role: collaborator.role,
        status: currentData.status === "accepted" ? "accepted" : "invited",
        uid: currentData.uid || null,
        invitedAt: currentData.invitedAt || serverTimestamp(),
        updatedAt: serverTimestamp(),
      }, { merge: true })
    }
    await batch.commit()
  }

  async function syncGlobalPromotions(context, promotions) {
    const ref = db.collection("config").doc("promo_codes")
    await db.runTransaction(async (transaction) => {
      const snapshot = await transaction.get(ref)
      const data = snapshot.exists ? snapshot.data() || {} : {}
      const codes = { ...(data.codes || {}) }
      for (const [code, value] of Object.entries(codes)) {
        if (value?.source === "photographer" && value?.photographerId === context.id) delete codes[code]
      }
      for (const promotion of promotions) {
        codes[promotion.code] = {
          type: promotion.percentOff > 0 ? "percentage" : "fixed",
          value: promotion.percentOff > 0 ? promotion.percentOff : Math.round(promotion.amountOff * 100),
          maxDiscountCents: null,
          minSubtotalCents: 0,
          disabled: promotion.active !== true,
          startsAt: promotion.startsAt || null,
          expiresAt: promotion.endsAt || null,
          description: `Promotion ${context.profile.brandName || context.id}`,
          source: "photographer",
          photographerId: context.id,
          galleryIds: promotion.galleryIds,
        }
      }
      transaction.set(ref, { codes, updatedAt: serverTimestamp() }, { merge: true })
    })
  }

  const getPhotographerWorkspaceConfig = onCall(
    { region, timeoutSeconds: 30 },
    async (request) => {
      const context = await managedProfile(request.auth, request.data?.photographerId, ["owner", "manager", "editor", "finance", "viewer"])
      const workspace = await db.collection(WORKSPACES).doc(context.id).get()
      const fallback = context.profile.workspaceConfig || {}
      return {
        config: workspace.exists ? workspace.data() || {} : fallback,
        limits: planLimits(context.profile.activePlanId),
        role: context.role,
      }
    },
  )

  const savePhotographerWorkspaceConfig = onCall(
    { region, timeoutSeconds: 60 },
    async (request) => {
      const context = await managedProfile(request.auth, request.data?.photographerId, ["owner", "manager"])
      const limits = planLimits(context.profile.activePlanId)
      const raw = request.data?.config || {}
      const collaborators = cleanCollaborators(raw.collaborators, limits.collaborators)
      const brands = cleanBrands(raw.brands, limits.brands)
      const promotions = cleanPromotions(raw.promotions, limits.promotions, context.id)
      const config = {
        collaborators,
        brands,
        promotions,
        storefront: publicStorefront({ ...raw, brands }, limits),
        faceGroupingConsent: raw.faceGroupingConsent === true,
        faceGroupingConsentAt: raw.faceGroupingConsent === true ? serverTimestamp() : null,
        updatedAt: serverTimestamp(),
      }
      await Promise.all([
        db.collection(WORKSPACES).doc(context.id).set({
          ...config,
          photographerId: context.id,
          ownerUid: context.ownerUid,
          updatedByUid: request.auth.uid,
          updatedAt: serverTimestamp(),
        }, { merge: true }),
        context.ref.set({
          publicStorefront: config.storefront,
          workspaceConfig: admin.firestore.FieldValue.delete(),
          updatedAt: serverTimestamp(),
        }, { merge: true }),
        syncCollaborators(context, collaborators),
        syncGlobalPromotions(context, promotions),
      ])
      return { success: true, config, limits, role: context.role }
    },
  )

  const acceptPendingPhotographerCollaborations = onCall(
    { region, timeoutSeconds: 30 },
    async (request) => {
      if (!request.auth?.uid) throw new HttpsError("unauthenticated", "Authentication required")
      const email = normalizeEmail(request.auth.token?.email)
      if (!email) return { accepted: [] }
      const snapshot = await db.collection(COLLABORATORS).where("emailLower", "==", email).get()
      const accepted = []
      const batch = db.batch()
      for (const doc of snapshot.docs) {
        const data = doc.data() || {}
        if (!["invited", "accepted"].includes(data.status)) continue
        const targetRef = db.collection(COLLABORATORS).doc(`${data.photographerId}_${request.auth.uid}`)
        batch.set(targetRef, {
          ...data,
          invitationId: doc.id,
          uid: request.auth.uid,
          status: "accepted",
          acceptedAt: data.acceptedAt || serverTimestamp(),
          updatedAt: serverTimestamp(),
        }, { merge: true })
        if (doc.id !== targetRef.id) batch.set(doc.ref, { status: "accepted", uid: request.auth.uid, acceptedAt: serverTimestamp(), updatedAt: serverTimestamp() }, { merge: true })
        accepted.push({ photographerId: data.photographerId, role: data.role })
      }
      await batch.commit()
      return { accepted }
    },
  )

  const getMyPhotographerWorkspaces = onCall(
    { region, timeoutSeconds: 30 },
    async (request) => {
      if (!request.auth?.uid) throw new HttpsError("unauthenticated", "Authentication required")
      const [owned, collaborations] = await Promise.all([
        db.collection("photographers").where("ownerUid", "==", request.auth.uid).get(),
        db.collection(COLLABORATORS).where("uid", "==", request.auth.uid).where("status", "==", "accepted").get(),
      ])
      const byId = new Map()
      for (const doc of owned.docs) byId.set(doc.id, { photographerId: doc.id, role: "owner", profile: doc.data() || {} })
      for (const collaboration of collaborations.docs) {
        const data = collaboration.data() || {}
        if (!data.photographerId || byId.has(data.photographerId)) continue
        const profile = await db.collection("photographers").doc(data.photographerId).get()
        if (profile.exists) byId.set(profile.id, { photographerId: profile.id, role: data.role, profile: profile.data() || {} })
      }
      return { workspaces: [...byId.values()] }
    },
  )

  const generateGalleryPrivateLink = onCall(
    { region, timeoutSeconds: 30 },
    async (request) => {
      const context = await managedProfile(request.auth, request.data?.photographerId, ["owner", "manager", "editor"])
      const galleryId = text(request.data?.galleryId, 160)
      const galleryRef = db.collection("media_galleries").doc(galleryId)
      const snapshot = await galleryRef.get()
      if (!snapshot.exists || (snapshot.data() || {}).photographerId !== context.id) {
        throw new HttpsError("not-found", "Gallery not found")
      }
      const token = crypto.randomBytes(32).toString("base64url")
      await galleryRef.set({
        privateAccessTokenHash: sha256(token),
        privateAccessToken: admin.firestore.FieldValue.delete(),
        visibility: "unlisted",
        privateLinkCreatedAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      }, { merge: true })
      const url = `https://maslive.web.app/#/media-marketplace?galleryId=${encodeURIComponent(galleryId)}&access=${encodeURIComponent(token)}`
      return { url, token }
    },
  )

  function participantMatches(gallery, request) {
    if (gallery.participantRestricted !== true) return true
    const allow = new Set(list(gallery.participantAllowList).map((value) => text(value, 320).toLowerCase()))
    const uid = text(request.auth?.uid, 160).toLowerCase()
    const email = normalizeEmail(request.auth?.token?.email)
    const participantCode = text(request.data?.participantCode, 320).toLowerCase()
    return allow.has(uid) || allow.has(email) || (participantCode && allow.has(participantCode))
  }

  function serializeDoc(doc) {
    const data = doc.data() || {}
    return { id: doc.id, ...data }
  }

  const openMediaGalleryAccess = onCall(
    { region, timeoutSeconds: 60, memory: "512MiB" },
    async (request) => {
      if (!request.auth?.uid) throw new HttpsError("unauthenticated", "Connecte-toi pour ouvrir cette galerie")
      const galleryId = text(request.data?.galleryId, 160)
      const token = text(request.data?.accessToken, 600)
      if (!galleryId) throw new HttpsError("invalid-argument", "galleryId is required")
      const gallerySnapshot = await db.collection("media_galleries").doc(galleryId).get()
      if (!gallerySnapshot.exists) throw new HttpsError("not-found", "Gallery not found")
      const gallery = gallerySnapshot.data() || {}
      const profileSnapshot = await db.collection("photographers").doc(text(gallery.photographerId, 160)).get()
      const profile = profileSnapshot.exists ? profileSnapshot.data() || {} : {}
      const collaborator = await collaboratorContext(text(gallery.photographerId, 160), request.auth)
      const ownerAccess = isAdmin(request.auth) || profile.ownerUid === request.auth.uid || collaborator != null
      const expectedHash = text(gallery.privateAccessTokenHash, 128)
      const legacyToken = text(gallery.privateAccessToken, 600)
      const tokenMatches = expectedHash
        ? crypto.timingSafeEqual(Buffer.from(expectedHash), Buffer.from(sha256(token)))
        : Boolean(legacyToken && token && legacyToken === token)
      const publiclyVisible = gallery.status === "published" && gallery.visibility === "public"
      if (!ownerAccess && !publiclyVisible && !tokenMatches) {
        throw new HttpsError("permission-denied", "Lien privé invalide ou expiré")
      }
      if (!ownerAccess && !participantMatches(gallery, request)) {
        throw new HttpsError("permission-denied", "Cette galerie est réservée aux participants autorisés")
      }
      const [photoSnapshot, packSnapshot] = await Promise.all([
        db.collection("media_photos")
          .where("galleryId", "==", galleryId)
          .where("isPublished", "==", true)
          .get(),
        db.collection("media_packs")
          .where("galleryId", "==", galleryId)
          .where("isActive", "==", true)
          .get(),
      ])
      const photos = photoSnapshot.docs
        .filter((doc) => {
          const photo = doc.data() || {}
          return photo.lifecycleStatus === "published" && photo.moderationStatus === "approved"
        })
        .map(serializeDoc)
      const packs = packSnapshot.docs.map(serializeDoc)
      await db.collection(ACCESS_LOGS).add({
        galleryId,
        photographerId: gallery.photographerId,
        userUid: request.auth.uid,
        accessMode: ownerAccess ? "workspace" : publiclyVisible ? "public" : "private_link",
        createdAt: serverTimestamp(),
      })
      return {
        gallery: serializeDoc(gallerySnapshot),
        photos,
        packs,
        storefront: profile.publicStorefront || {},
        photographer: {
          photographerId: profile.photographerId || profileSnapshot.id,
          brandName: profile.brandName || "",
          avatarUrl: profile.avatarUrl || "",
          bio: profile.bio || "",
        },
      }
    },
  )

  async function loadPromo(code) {
    const snapshot = await db.collection("config").doc("promo_codes").get()
    const codes = snapshot.exists ? (snapshot.data() || {}).codes || {} : {}
    return codes[text(code, 40).toUpperCase()] || null
  }

  function validatePromoData(promo, subtotalCents, photographerIds, galleryIds) {
    if (!promo || promo.disabled === true) return { valid: false, discountCents: 0, message: "Code promo invalide" }
    const startsAt = timestampMs(promo.startsAt)
    const expiresAt = timestampMs(promo.expiresAt)
    if (startsAt && Date.now() < startsAt) return { valid: false, discountCents: 0, message: "Code promo pas encore actif" }
    if (expiresAt && Date.now() > expiresAt) return { valid: false, discountCents: 0, message: "Code promo expiré" }
    if (promo.photographerId && !photographerIds.includes(promo.photographerId)) {
      return { valid: false, discountCents: 0, message: "Code non valable pour ce photographe" }
    }
    const allowedGalleries = list(promo.galleryIds).filter(Boolean)
    if (allowedGalleries.length && !galleryIds.some((id) => allowedGalleries.includes(id))) {
      return { valid: false, discountCents: 0, message: "Code non valable pour cette galerie" }
    }
    const minimum = integer(promo.minSubtotalCents)
    if (minimum > 0 && subtotalCents < minimum) {
      return { valid: false, discountCents: 0, message: `Minimum commande: ${(minimum / 100).toFixed(2)}€` }
    }
    let discountCents = 0
    if (promo.type === "percentage") discountCents = Math.floor(subtotalCents * Math.max(0, number(promo.value)) / 100)
    if (promo.type === "fixed") discountCents = Math.max(0, integer(promo.value))
    if (promo.maxDiscountCents) discountCents = Math.min(discountCents, integer(promo.maxDiscountCents))
    discountCents = Math.min(discountCents, Math.max(0, subtotalCents - 50))
    if (discountCents <= 0) return { valid: false, discountCents: 0, message: "Réduction invalide" }
    return { valid: true, discountCents, message: `Réduction appliquée: -${(discountCents / 100).toFixed(2)}€` }
  }

  async function mediaCart(uid) {
    const snapshot = await db.collection("users").doc(uid).collection("cart_items").where("itemType", "==", "media").get()
    return snapshot.docs.map((doc) => ({ cartItemId: doc.id, ...(doc.data() || {}) }))
  }

  async function getDocs(collection, ids) {
    const normalized = unique(ids)
    const snapshots = normalized.length ? await db.getAll(...normalized.map((id) => db.collection(collection).doc(id))) : []
    return new Map(snapshots.filter((snap) => snap.exists).map((snap) => [snap.id, snap.data() || {}]))
  }

  async function buildMediaItems(cartItems) {
    const photoItems = cartItems.filter((item) => text(item.metadata?.assetType || item.assetType).toLowerCase() === "photo")
    const packItems = cartItems.filter((item) => text(item.metadata?.assetType || item.assetType).toLowerCase() === "pack")
    const [photos, packs] = await Promise.all([
      getDocs("media_photos", photoItems.map((item) => item.productId)),
      getDocs("media_packs", packItems.map((item) => item.productId)),
    ])
    const grouped = new Map()
    for (const cartItem of photoItems) {
      const photoId = text(cartItem.productId, 160)
      const photo = photos.get(photoId)
      if (!photo || photo.isPublished !== true || photo.isForSale !== true || photo.lifecycleStatus !== "published") {
        throw new HttpsError("failed-precondition", `Photo ${photoId} is not available`)
      }
      const key = `${photo.photographerId}::${photo.galleryId}`
      if (!grouped.has(key)) grouped.set(key, { photographerId: photo.photographerId, galleryId: photo.galleryId, eventId: photo.eventId, photoIds: [], cartItemIds: [], imageUrl: photo.thumbnailPath || "", currency: photo.currency || "EUR" })
      const group = grouped.get(key)
      if (!group.photoIds.includes(photoId)) group.photoIds.push(photoId)
      group.cartItemIds.push(cartItem.cartItemId)
    }
    const items = []
    for (const group of grouped.values()) {
      items.push({
        assetId: `selection_${group.galleryId}_${group.photoIds.join("_")}`,
        assetType: "photo_selection",
        photographerId: group.photographerId,
        galleryId: group.galleryId,
        eventId: group.eventId,
        title: `${group.photoIds.length} photo(s) — tarif pack automatique`,
        imageUrl: group.imageUrl,
        photoIds: group.photoIds,
        lineSubtotal: photoSelectionPrice(group.photoIds.length),
        currency: group.currency,
        cartItemIds: group.cartItemIds,
      })
    }
    for (const cartItem of packItems) {
      const packId = text(cartItem.productId, 160)
      const pack = packs.get(packId)
      if (!pack || pack.isActive !== true) throw new HttpsError("failed-precondition", `Pack ${packId} is not available`)
      const photoIds = unique(list(pack.photoIds).map((id) => text(id, 160)))
      items.push({
        assetId: packId,
        assetType: "pack",
        photographerId: pack.photographerId,
        galleryId: pack.galleryId,
        eventId: pack.eventId,
        title: pack.title || "Pack photos",
        imageUrl: pack.coverUrl || "",
        photoIds,
        lineSubtotal: roundCurrency(number(pack.price)),
        currency: pack.currency || "EUR",
        cartItemIds: [cartItem.cartItemId],
      })
    }
    if (!items.length) throw new HttpsError("failed-precondition", "Media cart is empty")
    for (const item of items) {
      const profile = await db.collection("photographers").doc(item.photographerId).get()
      if (!profile.exists) throw new HttpsError("failed-precondition", "Photographer profile not found")
      const data = profile.data() || {}
      const plan = planFor(data.activePlanId || "discovery")
      item.commissionRate = plan.commissionRate
      item.platformFee = roundCurrency(item.lineSubtotal * plan.commissionRate)
      item.photographerAmount = roundCurrency(item.lineSubtotal - item.platformFee)
      item.planCode = plan.code
      item.stripeAccountId = text(data.stripeAccountId || data.stripe?.accountId, 160) || null
    }
    return items
  }

  const validatePhotographerPromoCode = onCall(
    { region, timeoutSeconds: 30 },
    async (request) => {
      if (!request.auth?.uid) throw new HttpsError("unauthenticated", "Authentication required")
      const items = await buildMediaItems(await mediaCart(request.auth.uid))
      const subtotalCents = Math.round(items.reduce((sum, item) => sum + item.lineSubtotal, 0) * 100)
      const promo = await loadPromo(request.data?.promoCode)
      return validatePromoData(
        promo,
        subtotalCents,
        unique(items.map((item) => item.photographerId)),
        unique(items.map((item) => item.galleryId)),
      )
    },
  )

  function applyDiscount(items, discountCents) {
    const baseTotal = items.reduce((sum, item) => sum + item.lineSubtotal, 0)
    let remaining = roundCurrency(discountCents / 100)
    return items.map((item, index) => {
      const share = index === items.length - 1
        ? remaining
        : roundCurrency((item.lineSubtotal / baseTotal) * (discountCents / 100))
      remaining = roundCurrency(remaining - share)
      const discountedSubtotal = Math.max(0.50, roundCurrency(item.lineSubtotal - share))
      const platformFee = roundCurrency(discountedSubtotal * item.commissionRate)
      return {
        ...item,
        originalSubtotal: item.lineSubtotal,
        promoDiscount: roundCurrency(item.lineSubtotal - discountedSubtotal),
        lineSubtotal: discountedSubtotal,
        platformFee,
        photographerAmount: roundCurrency(discountedSubtotal - platformFee),
      }
    })
  }

  const createMediaMarketplacePromoCheckout = onCall(
    { region, secrets: [STRIPE_SECRET_KEY], timeoutSeconds: 60, memory: "512MiB" },
    async (request) => {
      const uid = request.auth?.uid
      if (!uid) throw new HttpsError("unauthenticated", "Authentication required")
      let items = await buildMediaItems(await mediaCart(uid))
      const baseSubtotalCents = Math.round(items.reduce((sum, item) => sum + item.lineSubtotal, 0) * 100)
      const promoCode = text(request.data?.promoCode, 40).toUpperCase()
      const promo = await loadPromo(promoCode)
      const validation = validatePromoData(
        promo,
        baseSubtotalCents,
        unique(items.map((item) => item.photographerId)),
        unique(items.map((item) => item.galleryId)),
      )
      if (!validation.valid) throw new HttpsError("failed-precondition", validation.message)
      items = applyDiscount(items, validation.discountCents)
      const mediaDelivery = mediaDeliveryQuote({
        subtotal: items.reduce((sum, item) => sum + item.lineSubtotal, 0),
        hdUpgrade: request.data?.mediaDeliveryOptions?.hdUpgrade === true,
      })
      const subtotal = roundCurrency(items.reduce((sum, item) => sum + item.lineSubtotal, 0))
      const platformFee = roundCurrency(items.reduce((sum, item) => sum + item.platformFee, 0))
      const photographerAmount = roundCurrency(items.reduce((sum, item) => sum + item.photographerAmount, 0))
      const total = mediaDelivery.total
      const orderRef = db.collection("orders").doc()
      const pricingBreakdown = {
        originalSubtotal: roundCurrency(baseSubtotalCents / 100),
        promoDiscount: roundCurrency(validation.discountCents / 100),
        subtotal,
        hdUpgradeAmount: mediaDelivery.hdUpgradeAmount,
        total,
        platformFee,
        photographerAmount,
        stripeFee: stripeFeeEstimate(total),
        platformNetEstimate: roundCurrency(platformFee - stripeFeeEstimate(total)),
      }
      await orderRef.set({
        orderId: orderRef.id,
        buyerUid: uid,
        userId: uid,
        kind: ORDER_KIND,
        cartSource: "unified_cart_items",
        items,
        sellerIds: unique(items.map((item) => item.photographerId)),
        photographerIds: unique(items.map((item) => item.photographerId)),
        currency: items[0].currency || "EUR",
        subtotal,
        total,
        platformFee,
        photographerAmount,
        stripeFeeEstimate: pricingBreakdown.stripeFee,
        pricingBreakdown,
        promoCode,
        promoDiscount: pricingBreakdown.promoDiscount,
        mediaDeliveryOptions: {
          hdUpgrade: mediaDelivery.hdUpgrade,
          hdUpgradeAmount: mediaDelivery.hdUpgradeAmount,
          allowedVariants: [...mediaDelivery.allowedVariants],
        },
        paymentStatus: "pending",
        fulfillmentStatus: "pending",
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      })
      const lineItems = items.map((item) => ({
        quantity: 1,
        price_data: {
          currency: String(item.currency || "EUR").toLowerCase(),
          unit_amount: Math.round(item.lineSubtotal * 100),
          product_data: {
            name: item.title,
            images: text(item.imageUrl, 1000).startsWith("http") ? [item.imageUrl] : [],
            metadata: { assetId: item.assetId, galleryId: item.galleryId, photographerId: item.photographerId },
          },
        },
      }))
      if (mediaDelivery.hdUpgradeAmount > 0) {
        lineItems.push({
          quantity: 1,
          price_data: {
            currency: String(items[0].currency || "EUR").toLowerCase(),
            unit_amount: Math.round(mediaDelivery.hdUpgradeAmount * 100),
            product_data: { name: "Option téléchargement HD" },
          },
        })
      }
      const session = await getStripe().checkout.sessions.create({
        mode: "payment",
        line_items: lineItems,
        success_url: isAllowedRedirectUrl(request.data?.successUrl) ? request.data.successUrl : SUCCESS_URL,
        cancel_url: isAllowedRedirectUrl(request.data?.cancelUrl) ? request.data.cancelUrl : CANCEL_URL,
        client_reference_id: orderRef.id,
        metadata: { kind: ORDER_KIND, uid, orderId: orderRef.id, promoCode },
        payment_intent_data: { metadata: { kind: ORDER_KIND, uid, orderId: orderRef.id, promoCode } },
      }, { idempotencyKey: `media_promo_checkout_${uid}_${orderRef.id}` })
      await orderRef.set({ stripeSessionId: session.id, checkoutUrl: session.url, updatedAt: serverTimestamp() }, { merge: true })
      return { orderId: orderRef.id, checkoutUrl: session.url, stripeSessionId: session.id, pricingBreakdown }
    },
  )

  function normalizeStoragePath(path) {
    const normalized = text(path, 1200).replace(/\\/g, "/")
    if (!normalized || normalized.startsWith("/") || normalized.includes("..") || normalized.includes("//")) return ""
    return normalized
  }

  function storagePathForVariant(photo, variant) {
    if (["original", "hd"].includes(variant)) return normalizeStoragePath(photo.originalPath)
    if (["preview", "web"].includes(variant)) return normalizeStoragePath(photo.previewPath)
    if (["thumbnail", "thumb"].includes(variant)) return normalizeStoragePath(photo.thumbnailPath)
    if (variant === "watermarked") return normalizeStoragePath(photo.watermarkedPath)
    return ""
  }

  async function deliveryPath(photo, gallery, variant) {
    const sourcePath = storagePathForVariant(photo, variant)
    if (!sourcePath) throw new HttpsError("failed-precondition", "Requested file variant is unavailable")
    const maxMp = Math.max(1, integer(gallery.maxDownloadMegapixels, 60))
    if (!["original", "hd"].includes(variant)) return sourcePath
    const width = integer(photo.width)
    const height = integer(photo.height)
    if (!width || !height || (width * height) / 1000000 <= maxMp) return sourcePath
    const sourceFile = admin.storage().bucket().file(sourcePath)
    const [source] = await sourceFile.download()
    const scale = Math.sqrt((maxMp * 1000000) / (width * height))
    const targetWidth = Math.max(1, Math.floor(width * scale))
    const buffer = await sharp(source).rotate().resize({ width: targetWidth, withoutEnlargement: true }).jpeg({ quality: 92, mozjpeg: true }).toBuffer()
    const targetPath = `photographers/${photo.photographerId}/events/${photo.eventId}/galleries/${photo.galleryId}/deliveries/${photo.photoId}_${maxMp}mp.jpg`
    await admin.storage().bucket().file(targetPath).save(buffer, {
      resumable: false,
      metadata: { contentType: "image/jpeg", cacheControl: "private,max-age=86400", metadata: { generatedForDelivery: "true", maxMegapixels: String(maxMp) } },
    })
    return targetPath
  }

  const getMediaDownloadUrl = onCall(
    { region, timeoutSeconds: 120, memory: "1GiB" },
    async (request) => {
      const buyerUid = request.auth?.uid
      if (!buyerUid) throw new HttpsError("unauthenticated", "Authentication required")
      const entitlementId = text(request.data?.entitlementId, 180)
      const photoId = text(request.data?.photoId, 180)
      const variant = text(request.data?.variant || "original", 40).toLowerCase()
      const entitlementSnapshot = await db.collection("media_entitlements").doc(entitlementId).get()
      if (!entitlementSnapshot.exists) throw new HttpsError("not-found", "Entitlement not found")
      const entitlement = entitlementSnapshot.data() || {}
      if (entitlement.buyerUid !== buyerUid || !list(entitlement.photoIds).includes(photoId)) {
        throw new HttpsError("permission-denied", "This download does not belong to you")
      }
      const allowed = list(entitlement.allowedVariants).length ? list(entitlement.allowedVariants) : ["original", "hd", "preview", "web"]
      if (!allowed.includes(variant)) throw new HttpsError("permission-denied", "This quality is not included in your purchase")
      const photoSnapshot = await db.collection("media_photos").doc(photoId).get()
      if (!photoSnapshot.exists) throw new HttpsError("not-found", "Photo not found")
      const photo = { photoId, ...(photoSnapshot.data() || {}) }
      const gallerySnapshot = await db.collection("media_galleries").doc(text(photo.galleryId, 160)).get()
      const gallery = gallerySnapshot.exists ? gallerySnapshot.data() || {} : {}
      const path = await deliveryPath(photo, gallery, variant)
      const hours = Math.max(1, Math.min(168, integer(gallery.downloadWindowHours, 72)))
      const expiresAtMs = Date.now() + (hours * 60 * 60 * 1000)
      const [url] = await admin.storage().bucket().file(path).getSignedUrl({
        action: "read",
        expires: expiresAtMs,
        responseDisposition: `attachment; filename="${text(photo.downloadFileName, 300) || `maslive_${photoId}.jpg`}"`,
      })
      await db.collection(DOWNLOAD_LOGS).add({
        buyerUid,
        entitlementId,
        photoId,
        galleryId: photo.galleryId,
        variant,
        storagePath: path,
        expiresAt: admin.firestore.Timestamp.fromMillis(expiresAtMs),
        createdAt: serverTimestamp(),
      })
      return { url, expiresAt: new Date(expiresAtMs).toISOString(), variant, photoId, maxDownloadMegapixels: gallery.maxDownloadMegapixels || null }
    },
  )

  function watermarkSvg(width, height, label) {
    const safe = text(label, 80).replace(/[&<>"']/g, "") || "MASLIVE"
    const size = Math.max(26, Math.round(Math.min(width, height) * 0.055))
    return Buffer.from(`<svg width="${width}" height="${height}" xmlns="http://www.w3.org/2000/svg"><style>.w{fill:white;fill-opacity:.72;stroke:black;stroke-opacity:.35;stroke-width:2;font-family:Arial,sans-serif;font-size:${size}px;font-weight:800;letter-spacing:3px}</style><g transform="translate(${Math.round(width / 2)} ${Math.round(height / 2)}) rotate(-24)"><text class="w" text-anchor="middle">${safe}</text></g></svg>`)
  }

  const applyGalleryWatermark = onDocumentUpdated(
    { document: "media_photos/{photoId}", region, timeoutSeconds: 180, memory: "1GiB", maxInstances: 10 },
    async (event) => {
      const before = event.data?.before?.data() || {}
      const after = event.data?.after?.data() || {}
      if (after.processingStatus !== "processed" || before.processingStatus === "processed") return
      const gallerySnapshot = await db.collection("media_galleries").doc(text(after.galleryId, 160)).get()
      if (!gallerySnapshot.exists) return
      const gallery = gallerySnapshot.data() || {}
      if (gallery.watermarkEnabled === false) return
      const profileSnapshot = await db.collection("photographers").doc(text(after.photographerId, 160)).get()
      const profile = profileSnapshot.exists ? profileSnapshot.data() || {} : {}
      const publicStorefront = profile.publicStorefront || {}
      const label = text(gallery.watermarkText, 80) || text(publicStorefront.customWatermarkText, 80) || `MASLIVE • ${text(profile.brandName, 60)}`
      const previewPath = normalizeStoragePath(after.previewPath)
      const watermarkedPath = normalizeStoragePath(after.watermarkedPath)
      if (!previewPath || !watermarkedPath) return
      const [preview] = await admin.storage().bucket().file(previewPath).download()
      const metadata = await sharp(preview).metadata()
      const width = integer(metadata.width, 1600)
      const height = integer(metadata.height, 1200)
      const output = await sharp(preview).composite([{ input: watermarkSvg(width, height, label), blend: "over" }]).webp({ quality: 82 }).toBuffer()
      await admin.storage().bucket().file(watermarkedPath).save(output, {
        resumable: false,
        metadata: { contentType: "image/webp", cacheControl: "private,max-age=31536000,immutable", metadata: { galleryWatermark: label } },
      })
      await event.data.after.ref.set({ appliedWatermarkText: label, watermarkAppliedAt: serverTimestamp(), updatedAt: serverTimestamp() }, { merge: true })
    },
  )

  function pdfEscape(value) {
    return String(value || "").replace(/\\/g, "\\\\").replace(/\(/g, "\\(").replace(/\)/g, "\\)")
  }

  function simplePdf(lines) {
    const content = ["BT", "/F1 12 Tf", "50 790 Td"]
    lines.forEach((line, index) => {
      if (index > 0) content.push("0 -20 Td")
      content.push(`(${pdfEscape(line)}) Tj`)
    })
    content.push("ET")
    const stream = content.join("\n")
    const objects = [
      "1 0 obj << /Type /Catalog /Pages 2 0 R >> endobj",
      "2 0 obj << /Type /Pages /Kids [3 0 R] /Count 1 >> endobj",
      "3 0 obj << /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] /Resources << /Font << /F1 5 0 R >> >> /Contents 4 0 R >> endobj",
      `4 0 obj << /Length ${Buffer.byteLength(stream)} >> stream\n${stream}\nendstream endobj`,
      "5 0 obj << /Type /Font /Subtype /Type1 /BaseFont /Helvetica >> endobj",
    ]
    let pdf = "%PDF-1.4\n"
    const offsets = [0]
    for (const object of objects) {
      offsets.push(Buffer.byteLength(pdf))
      pdf += `${object}\n`
    }
    const xref = Buffer.byteLength(pdf)
    pdf += `xref\n0 ${objects.length + 1}\n0000000000 65535 f \n`
    for (let index = 1; index < offsets.length; index += 1) pdf += `${String(offsets[index]).padStart(10, "0")} 00000 n \n`
    pdf += `trailer << /Size ${objects.length + 1} /Root 1 0 R >>\nstartxref\n${xref}\n%%EOF`
    return Buffer.from(pdf)
  }

  const generatePhotographerPdfInvoice = onCall(
    { region, timeoutSeconds: 60, memory: "512MiB" },
    async (request) => {
      const context = await managedProfile(request.auth, request.data?.photographerId, ["owner", "manager", "finance"])
      const from = timestampMs(request.data?.from)
      const to = timestampMs(request.data?.to) || Date.now()
      const snapshot = await db.collection("orders").where("sellerIds", "array-contains", context.id).get()
      const orders = snapshot.docs.map((doc) => ({ id: doc.id, ...(doc.data() || {}) })).filter((order) => {
        const date = timestampMs(order.paidAt || order.createdAt)
        return date >= from && date <= to && ["paid", "succeeded"].includes(text(order.paymentStatus, 40).toLowerCase())
      })
      const gross = orders.reduce((sum, order) => sum + number(order.total), 0)
      const net = orders.reduce((sum, order) => sum + number(order.photographerNetTotal, number(order.photographerAmount)), 0)
      const numberValue = `MASLIVE-${context.id.slice(0, 8).toUpperCase()}-${new Date().toISOString().slice(0, 10).replace(/-/g, "")}`
      const lines = [
        `RELEVE PHOTOGRAPHE ${numberValue}`,
        `Photographe : ${text(context.profile.brandName, 120)}`,
        `Periode : ${from ? new Date(from).toLocaleDateString("fr-FR") : "debut"} - ${new Date(to).toLocaleDateString("fr-FR")}`,
        `Commandes payees : ${orders.length}`,
        `Chiffre d'affaires brut : ${gross.toFixed(2)} EUR`,
        `Net photographe : ${net.toFixed(2)} EUR`,
        "Document genere automatiquement par MASLIVE.",
      ]
      return { invoiceNumber: numberValue, pdfBase64: simplePdf(lines).toString("base64"), mimeType: "application/pdf", gross, net, orderCount: orders.length }
    },
  )

  return {
    getPhotographerWorkspaceConfig,
    savePhotographerWorkspaceConfig,
    acceptPendingPhotographerCollaborations,
    getMyPhotographerWorkspaces,
    generateGalleryPrivateLink,
    openMediaGalleryAccess,
    validatePhotographerPromoCode,
    createMediaMarketplacePromoCheckout,
    getMediaDownloadUrl,
    applyGalleryWatermark,
    generatePhotographerPdfInvoice,
  }
}
