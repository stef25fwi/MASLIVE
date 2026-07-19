"use strict"

const { onSchedule } = require("firebase-functions/v2/scheduler")

module.exports = function createMediaMarketplaceMedia(deps) {
  const {
    admin,
    db,
    onCall,
    HttpsError,
    onDocumentCreated,
    onDocumentUpdated,
    onDocumentDeleted,
  } = deps

  const COLLECTIONS = {
    mediaPhotos: "media_photos",
    mediaPacks: "media_packs",
    mediaGalleries: "media_galleries",
    photographers: "photographers",
    photographerSubscriptions: "photographer_subscriptions",
    photographerPlans: "photographer_plans",
    mediaUploadReservations: "media_upload_reservations",
    mediaEntitlements: "media_entitlements",
    mediaDownloadLogs: "media_download_logs",
    adminModerationQueue: "admin_moderation_queue",
    payoutLedger: "payout_ledger",
    users: "users",
  }

  const DOWNLOAD_VARIANTS = new Set([
    "original",
    "preview",
    "thumbnail",
    "watermarked",
  ])
  const VARIANT_DIRECTORY_BY_NAME = {
    original: "originals",
    preview: "previews",
    thumbnail: "thumbs",
    watermarked: "watermarked",
  }
  const ACTIVE_SUBSCRIPTION_STATUSES = new Set([
    "active",
    "trialing",
    "past_due",
  ])
  const ARCHIVED_GALLERY_STATUS = "archived"
  const UPLOAD_RESERVATION_HOURS = 24

  const GiB = 1024 * 1024 * 1024
  const MiB = 1024 * 1024

  const PHOTOGRAPHER_PLANS = {
    discovery: {
      code: "discovery",
      name: "Découverte",
      monthlyPrice: 0,
      maxPublishedPhotos: 250,
      maxStorageBytes: 3 * GiB,
      maxActiveGalleries: 2,
      maxActivePacks: 10,
      maxFileBytes: 8 * MiB,
      maxMegapixels: 12,
      retentionDays: 30,
      commissionRate: 0.30,
      maxBatchUpload: 25,
    },
    pro: {
      code: "pro",
      name: "Pro",
      monthlyPrice: 19.90,
      maxPublishedPhotos: 3000,
      maxStorageBytes: 30 * GiB,
      maxActiveGalleries: 20,
      maxActivePacks: 100,
      maxFileBytes: 20 * MiB,
      maxMegapixels: 24,
      retentionDays: 180,
      commissionRate: 0.25,
      maxBatchUpload: 100,
    },
    studio: {
      code: "studio",
      name: "Studio",
      monthlyPrice: 39.90,
      maxPublishedPhotos: 10000,
      maxStorageBytes: 120 * GiB,
      maxActiveGalleries: 100,
      maxActivePacks: 500,
      maxFileBytes: 40 * MiB,
      maxMegapixels: 40,
      retentionDays: 365,
      commissionRate: 0.20,
      maxBatchUpload: 250,
    },
    agency: {
      code: "agency",
      name: "Agence",
      monthlyPrice: 79.90,
      maxPublishedPhotos: 30000,
      maxStorageBytes: 400 * GiB,
      maxActiveGalleries: 500,
      maxActivePacks: 2500,
      maxFileBytes: 70 * MiB,
      maxMegapixels: 60,
      retentionDays: 548,
      commissionRate: 0.15,
      maxBatchUpload: 500,
    },
  }

  const BUYER_PACKS = [
    {
      code: "single",
      title: "1 photo souvenir",
      pickCount: 1,
      price: 6.90,
      oldPrice: 6.90,
      sortOrder: 10,
      description: "La photo que vous préférez.",
    },
    {
      code: "duo",
      title: "Pack Duo",
      pickCount: 2,
      price: 10.90,
      oldPrice: 13.80,
      sortOrder: 20,
      description: "Un portrait et une photo en action.",
    },
    {
      code: "essential",
      title: "Pack Essentiel",
      pickCount: 5,
      price: 19.90,
      oldPrice: 34.50,
      sortOrder: 30,
      description: "Le meilleur équilibre pour revivre votre parcours.",
      recommended: true,
    },
    {
      code: "experience",
      title: "Pack Expérience",
      pickCount: 10,
      price: 29.90,
      oldPrice: 69.00,
      sortOrder: 40,
      description: "Pour votre groupe, votre famille ou tout le parcours.",
    },
    {
      code: "personal_gallery",
      title: "Galerie personnelle",
      pickCount: 20,
      price: 44.90,
      oldPrice: 138.00,
      sortOrder: 50,
      description: "Une sélection complète à télécharger.",
    },
  ]

  function serverTimestamp() {
    return admin.firestore.FieldValue.serverTimestamp()
  }

  function toNumber(value, fallback = 0) {
    const parsed = Number(value)
    return Number.isFinite(parsed) ? parsed : fallback
  }

  function toInteger(value, fallback = 0) {
    return Math.trunc(toNumber(value, fallback))
  }

  function nonEmptyString(value) {
    return typeof value === "string" && value.trim().length > 0
      ? value.trim()
      : ""
  }

  function uniqueStrings(values) {
    return Array.from(
      new Set(
        (values || [])
          .map((value) => nonEmptyString(value))
          .filter(Boolean)
      )
    )
  }

  function safeFileName(value, fallback = "photo.jpg") {
    const raw = nonEmptyString(value) || fallback
    const lastSegment = raw.split(/[\\/]/).pop() || fallback
    const sanitized = lastSegment
      .normalize("NFD")
      .replace(/[\u0300-\u036f]/g, "")
      .replace(/[^a-zA-Z0-9._-]+/g, "_")
      .replace(/^_+|_+$/g, "")
    return sanitized || fallback
  }

  function extensionForFileName(fileName, mimeType) {
    const safe = safeFileName(fileName)
    const dot = safe.lastIndexOf(".")
    if (dot > -1 && dot < safe.length - 1) {
      return safe.slice(dot + 1).toLowerCase().replace(/[^a-z0-9]/g, "") || "jpg"
    }
    const normalizedMime = nonEmptyString(mimeType).toLowerCase()
    if (normalizedMime.includes("png")) return "png"
    if (normalizedMime.includes("webp")) return "webp"
    if (normalizedMime.includes("heic")) return "heic"
    if (normalizedMime.includes("heif")) return "heif"
    return "jpg"
  }

  function normalizedPlanCode(raw) {
    const value = nonEmptyString(raw).toLowerCase()
    if (value.includes("agency") || value.includes("agence")) return "agency"
    if (value.includes("studio")) return "studio"
    if (value.includes("pro")) return "pro"
    return "discovery"
  }

  let planCatalogSyncPromise = null

  async function ensurePlanCatalogSeeded() {
    if (planCatalogSyncPromise) return planCatalogSyncPromise
    planCatalogSyncPromise = (async () => {
      const batch = db.batch()
      const descriptions = {
        discovery: "Tester la vente de photos avec un stockage volontairement limité.",
        pro: "L'offre principale pour couvrir régulièrement des circuits MASLIVE.",
        studio: "Pour les studios qui gèrent plusieurs événements et collaborateurs.",
        agency: "Pour les équipes multi-photographes et les grands volumes.",
      }
      const features = {
        discovery: ["2 galeries actives", "JPEG jusqu'à 12 Mpx", "Prévisualisations filigranées", "Conservation 30 jours"],
        pro: ["20 galeries actives", "JPEG jusqu'à 24 Mpx", "Statistiques par galerie", "Codes promotionnels"],
        studio: ["Galeries dans la limite du quota", "JPEG jusqu'à 40 Mpx", "Collaborateurs", "Filigrane personnalisé"],
        agency: ["Plusieurs photographes", "Plusieurs boutiques", "Import automatisé", "Support prioritaire"],
      }
      const now = serverTimestamp()
      for (const plan of Object.values(PHOTOGRAPHER_PLANS)) {
        const ref = db.collection(COLLECTIONS.photographerPlans).doc(plan.code)
        batch.set(ref, {
          planId: plan.code,
          code: plan.code,
          name: plan.name,
          description: descriptions[plan.code],
          monthlyPrice: plan.monthlyPrice,
          annualPrice: plan.monthlyPrice === 0 ? 0 : Number((plan.monthlyPrice * 10).toFixed(2)),
          maxPublishedPhotos: plan.maxPublishedPhotos,
          maxStorageBytes: plan.maxStorageBytes,
          maxActiveGalleries: plan.maxActiveGalleries,
          maxActivePacks: plan.maxActivePacks,
          maxFileBytes: plan.maxFileBytes,
          maxMegapixels: plan.maxMegapixels,
          retentionDays: plan.retentionDays,
          maxBatchUpload: plan.maxBatchUpload,
          commissionRate: plan.commissionRate,
          features: features[plan.code],
          isActive: true,
          updatedAt: now,
          createdAt: now,
        }, { merge: true })
      }
      await batch.commit()
    })().catch((error) => {
      planCatalogSyncPromise = null
      throw error
    })
    return planCatalogSyncPromise
  }

  function resolvePlanFromSnapshot(planCode, snapshot = {}) {
    const fallback = PHOTOGRAPHER_PLANS[normalizedPlanCode(planCode)]
    return {
      ...fallback,
      code: nonEmptyString(snapshot.planCode) || fallback.code,
      maxPublishedPhotos: toInteger(
        snapshot.maxPublishedPhotos,
        fallback.maxPublishedPhotos
      ),
      maxStorageBytes: toInteger(snapshot.maxStorageBytes, fallback.maxStorageBytes),
      maxActiveGalleries: toInteger(
        snapshot.maxActiveGalleries,
        fallback.maxActiveGalleries
      ),
      maxActivePacks: toInteger(snapshot.maxActivePacks, fallback.maxActivePacks),
      commissionRate: toNumber(snapshot.commissionRate, fallback.commissionRate),
      maxFileBytes: toInteger(snapshot.maxFileBytes, fallback.maxFileBytes),
      maxMegapixels: toInteger(snapshot.maxMegapixels, fallback.maxMegapixels),
      retentionDays: toInteger(snapshot.retentionDays, fallback.retentionDays),
      maxBatchUpload: toInteger(snapshot.maxBatchUpload, fallback.maxBatchUpload),
    }
  }

  async function getUserAccess(uid) {
    if (!uid) return { isAdmin: false }
    const snapshot = await db.collection(COLLECTIONS.users).doc(uid).get()
    const data = snapshot.exists ? snapshot.data() || {} : {}
    const role = nonEmptyString(data.role).toLowerCase()
    return {
      isAdmin:
        data.isAdmin === true ||
        role === "admin" ||
        role === "admin_master" ||
        role === "superadmin" ||
        role === "super-admin",
    }
  }

  async function getPhotographerOrThrow(photographerId) {
    const id = nonEmptyString(photographerId)
    if (!id) {
      throw new HttpsError("invalid-argument", "photographerId is required")
    }
    const snapshot = await db.collection(COLLECTIONS.photographers).doc(id).get()
    if (!snapshot.exists) {
      throw new HttpsError("not-found", "Photographer profile not found")
    }
    return { id: snapshot.id, ref: snapshot.ref, data: snapshot.data() || {} }
  }

  async function assertPhotographerOwner(request, photographerId) {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Authentication required")
    }
    const photographer = await getPhotographerOrThrow(photographerId)
    if (photographer.data.ownerUid === request.auth.uid) return photographer
    const access = await getUserAccess(request.auth.uid)
    if (!access.isAdmin) {
      throw new HttpsError(
        "permission-denied",
        "This photographer profile does not belong to you"
      )
    }
    return photographer
  }

  async function getActiveSubscription(photographerId) {
    const snapshot = await db
      .collection(COLLECTIONS.photographerSubscriptions)
      .where("photographerId", "==", photographerId)
      .where("status", "in", ["active", "trialing", "past_due"])
      .limit(1)
      .get()
    if (snapshot.empty) return null
    return { id: snapshot.docs[0].id, ...snapshot.docs[0].data() }
  }

  async function resolvePhotographerPlan(photographer) {
    await ensurePlanCatalogSeeded()
    const subscription = await getActiveSubscription(photographer.id)
    const status = nonEmptyString(subscription?.status).toLowerCase()
    const hasActiveSubscription = ACTIVE_SUBSCRIPTION_STATUSES.has(status)
    const planCode =
      subscription?.quotaSnapshot?.planCode ||
      subscription?.planId ||
      photographer.data.activePlanId ||
      "discovery"
    const plan = resolvePlanFromSnapshot(
      planCode,
      hasActiveSubscription ? subscription?.quotaSnapshot || {} : {}
    )
    return { plan, subscription, hasActiveSubscription }
  }

  async function getGalleryOwnedOrThrow(photographer, galleryId) {
    const id = nonEmptyString(galleryId)
    if (!id) throw new HttpsError("invalid-argument", "galleryId is required")
    const snapshot = await db.collection(COLLECTIONS.mediaGalleries).doc(id).get()
    if (!snapshot.exists) throw new HttpsError("not-found", "Gallery not found")
    const data = snapshot.data() || {}
    if (data.photographerId !== photographer.id) {
      throw new HttpsError("permission-denied", "Gallery owner mismatch")
    }
    return { id: snapshot.id, ref: snapshot.ref, data }
  }

  function normalizeDownloadVariant(value) {
    const variant = nonEmptyString(value) || "original"
    if (!DOWNLOAD_VARIANTS.has(variant)) {
      throw new HttpsError(
        "invalid-argument",
        `Unsupported media variant: ${variant}`
      )
    }
    return variant
  }

  function getAllowedDownloadVariants(entitlement) {
    const explicitVariants = uniqueStrings(entitlement?.allowedVariants).filter(
      (variant) => DOWNLOAD_VARIANTS.has(variant)
    )
    return explicitVariants.length > 0 ? explicitVariants : ["original"]
  }

  function buildDownloadPath(photo, variant) {
    switch (variant) {
      case "preview":
        return photo.previewStoragePath || photo.previewPath || ""
      case "thumbnail":
        return photo.thumbnailStoragePath || photo.thumbnailPath || ""
      case "watermarked":
        return photo.watermarkedStoragePath || photo.watermarkedPath || ""
      case "original":
      default:
        return photo.originalPath || ""
    }
  }

  function normalizeStoragePath(path) {
    const normalized = nonEmptyString(path).replace(/\\/g, "/")
    if (!normalized) return ""
    if (
      normalized.startsWith("/") || normalized.includes("..") || normalized.includes("//")
    ) {
      return ""
    }
    if (
      normalized.startsWith("http://") ||
      normalized.startsWith("https://") ||
      normalized.startsWith("gs://")
    ) {
      return ""
    }
    return normalized
  }

  function isStrictMarketplacePhotoPath(photo, variant, storagePath) {
    const normalizedPath = normalizeStoragePath(storagePath)
    if (!normalizedPath) return false
    const photographerId = nonEmptyString(photo?.photographerId)
    const eventId = nonEmptyString(photo?.eventId)
    const galleryId = nonEmptyString(photo?.galleryId)
    const variantDirectory = VARIANT_DIRECTORY_BY_NAME[variant]
    if (!photographerId || !eventId || !galleryId || !variantDirectory) {
      return false
    }
    const expectedPrefix =
      `photographers/${photographerId}/events/${eventId}/` +
      `galleries/${galleryId}/${variantDirectory}/`
    return normalizedPath.startsWith(expectedPrefix)
  }

  async function createSignedDownloadUrl(storagePath, fileName) {
    const bucket = admin.storage().bucket()
    const file = bucket.file(storagePath)
    const [exists] = await file.exists()
    if (!exists) {
      throw new HttpsError("not-found", "Media file not found in storage")
    }
    const [url] = await file.getSignedUrl({
      action: "read",
      expires: Date.now() + 15 * 60 * 1000,
      responseDisposition: fileName
        ? `attachment; filename="${String(fileName).replace(/"/g, "")}"`
        : undefined,
    })
    return url
  }

  async function logDownloadAttempt({
    buyerUid,
    entitlementId,
    assetId,
    assetType,
    photoId,
    outcome,
    signedUrlPath,
    request,
    metadata,
  }) {
    const rawRequest = request?.rawRequest
    const ipAddress =
      nonEmptyString(rawRequest?.headers?.["x-forwarded-for"]) ||
      nonEmptyString(rawRequest?.ip)
    const userAgent = nonEmptyString(rawRequest?.headers?.["user-agent"])
    const logRef = db.collection(COLLECTIONS.mediaDownloadLogs).doc()
    await logRef.set({
      logId: logRef.id,
      buyerUid,
      entitlementId,
      assetId,
      assetType,
      photoId: photoId || null,
      outcome,
      signedUrlPath: signedUrlPath || null,
      ipAddress: ipAddress || null,
      userAgent: userAgent || null,
      metadata: metadata || {},
      createdAt: serverTimestamp(),
    })
  }

  async function getPhotoById(photoId) {
    if (!photoId) return null
    const snapshot = await db.collection(COLLECTIONS.mediaPhotos).doc(photoId).get()
    if (!snapshot.exists) return null
    return { id: snapshot.id, ...snapshot.data() }
  }

  async function recalculateGalleryCounters(galleryId) {
    if (!galleryId) return
    const [photosSnapshot, packsSnapshot] = await Promise.all([
      db.collection(COLLECTIONS.mediaPhotos).where("galleryId", "==", galleryId).get(),
      db.collection(COLLECTIONS.mediaPacks).where("galleryId", "==", galleryId).get(),
    ])
    const photoCount = photosSnapshot.docs.length
    const publishedPhotoDocs = photosSnapshot.docs.filter(
      (doc) => doc.data()?.isPublished === true
    )
    const publishedPhotoCount = publishedPhotoDocs.length
    const activePackDocs = packsSnapshot.docs.filter(
      (doc) => doc.data()?.isActive === true
    )
    const packCount = activePackDocs.length
    const coverDoc = publishedPhotoDocs[0] || photosSnapshot.docs[0] || null
    const coverData = coverDoc?.data() || null
    await db.collection(COLLECTIONS.mediaGalleries).doc(galleryId).set(
      {
        photoCount,
        publishedPhotoCount,
        packCount,
        coverPhotoId: coverDoc?.id || null,
        coverUrl:
          coverData?.thumbnailPath || coverData?.previewPath || null,
        updatedAt: serverTimestamp(),
      },
      { merge: true }
    )
  }

  async function recalculatePhotographerCounters(photographerId) {
    if (!photographerId) return
    const [photosSnapshot, galleriesSnapshot, packsSnapshot, payoutSnapshot] =
      await Promise.all([
        db
          .collection(COLLECTIONS.mediaPhotos)
          .where("photographerId", "==", photographerId)
          .get(),
        db
          .collection(COLLECTIONS.mediaGalleries)
          .where("photographerId", "==", photographerId)
          .get(),
        db
          .collection(COLLECTIONS.mediaPacks)
          .where("photographerId", "==", photographerId)
          .get(),
        db
          .collection(COLLECTIONS.payoutLedger)
          .where("photographerId", "==", photographerId)
          .get(),
      ])
    const publishedPhotoCount = photosSnapshot.docs.filter(
      (doc) => doc.data()?.isPublished === true
    ).length
    const activeGalleryCount = galleriesSnapshot.docs.filter(
      (doc) => doc.data()?.status !== ARCHIVED_GALLERY_STATUS
    ).length
    const activePackCount = packsSnapshot.docs.filter(
      (doc) => doc.data()?.isActive === true
    ).length
    const storageUsedBytes = photosSnapshot.docs.reduce(
      (sum, doc) => sum + toInteger(doc.data()?.sizeBytes, 0),
      0
    )
    const salesCount = payoutSnapshot.docs.length
    const totalRevenueGross = payoutSnapshot.docs.reduce(
      (sum, doc) => sum + toNumber(doc.data()?.grossAmount, 0),
      0
    )
    const totalRevenueNet = payoutSnapshot.docs.reduce(
      (sum, doc) => sum + toNumber(doc.data()?.netAmount, 0),
      0
    )
    await db.collection(COLLECTIONS.photographers).doc(photographerId).set(
      {
        publishedPhotoCount,
        activeGalleryCount,
        activePackCount,
        storageUsedBytes,
        salesCount,
        totalRevenueGross,
        totalRevenueNet,
        updatedAt: serverTimestamp(),
      },
      { merge: true }
    )
  }

  async function syncPhotoModerationQueue(photoId, photoData) {
    if (!photoId || !photoData) return
    const queueRef = db
      .collection(COLLECTIONS.adminModerationQueue)
      .doc(`photo_${photoId}`)
    const moderationStatus =
      nonEmptyString(photoData.moderationStatus) || "pending"
    if (moderationStatus === "approved") {
      await queueRef.delete().catch(() => null)
      return
    }
    await queueRef.set(
      {
        queueId: `photo_${photoId}`,
        entityType: "photo",
        entityId: photoId,
        photographerId: photoData.photographerId || null,
        ownerUid: photoData.ownerUid || null,
        status: moderationStatus,
        reason: photoData.moderationReason || null,
        snapshot: {
          photoId,
          galleryId: photoData.galleryId || null,
          eventId: photoData.eventId || null,
          thumbnailPath: photoData.thumbnailPath || null,
          previewPath: photoData.previewPath || null,
          originalPath: photoData.originalPath || null,
          title: photoData.downloadFileName || null,
          tags: Array.isArray(photoData.tags) ? photoData.tags : [],
          bibNumber: photoData.bibNumber || null,
          visibility: photoData.visibility || null,
          lifecycleStatus: photoData.lifecycleStatus || null,
          isPublished: photoData.isPublished === true,
          isForSale: photoData.isForSale === true,
          unitPrice: toNumber(photoData.unitPrice, 0),
          currency: photoData.currency || "EUR",
        },
        updatedAt: serverTimestamp(),
        createdAt: serverTimestamp(),
      },
      { merge: true }
    )
  }

  async function syncPhotoDerivedState(photoId, photoData) {
    if (!photoId || !photoData) return
    const lifecycleStatus =
      nonEmptyString(photoData.lifecycleStatus) || "draft"
    const moderationStatus =
      nonEmptyString(photoData.moderationStatus) || "pending"
    const shouldBePublished =
      moderationStatus === "approved" && lifecycleStatus === "published"
    const shouldBeForSale = shouldBePublished && photoData.saleEnabled !== false
    if (
      photoData.isPublished === shouldBePublished &&
      photoData.isForSale === shouldBeForSale
    ) {
      return
    }
    await db.collection(COLLECTIONS.mediaPhotos).doc(photoId).set(
      {
        isPublished: shouldBePublished,
        isForSale: shouldBeForSale,
        updatedAt: serverTimestamp(),
      },
      { merge: true }
    )
  }

  async function handlePhotoWriteAfter(data, beforeData) {
    const galleryIds = uniqueStrings([beforeData?.galleryId, data?.galleryId])
    const photographerIds = uniqueStrings([
      beforeData?.photographerId,
      data?.photographerId,
    ])
    await Promise.all([
      ...galleryIds.map((galleryId) => recalculateGalleryCounters(galleryId)),
      ...photographerIds.map((photographerId) =>
        recalculatePhotographerCounters(photographerId)
      ),
    ])
  }

  async function handlePackWriteAfter(data, beforeData) {
    const galleryIds = uniqueStrings([beforeData?.galleryId, data?.galleryId])
    const photographerIds = uniqueStrings([
      beforeData?.photographerId,
      data?.photographerId,
    ])
    await Promise.all([
      ...galleryIds.map((galleryId) => recalculateGalleryCounters(galleryId)),
      ...photographerIds.map((photographerId) =>
        recalculatePhotographerCounters(photographerId)
      ),
    ])
  }

  async function ensureDefaultPacksInternal({ photographer, gallery, photos }) {
    const photoIds = photos.map((doc) => doc.id)
    if (photoIds.length === 0) return 0
    const existingSnapshot = await db
      .collection(COLLECTIONS.mediaPacks)
      .where("galleryId", "==", gallery.id)
      .get()
    const existingCodes = new Set(
      existingSnapshot.docs.map((doc) => nonEmptyString(doc.data()?.catalogCode))
    )
    const batch = db.batch()
    let created = 0
    for (const definition of BUYER_PACKS) {
      if (photoIds.length < definition.pickCount) continue
      if (existingCodes.has(definition.code)) continue
      const packRef = db
        .collection(COLLECTIONS.mediaPacks)
        .doc(`${gallery.id}_${definition.code}`)
      batch.set(
        packRef,
        {
          packId: packRef.id,
          catalogCode: definition.code,
          photographerId: photographer.id,
          ownerUid: photographer.data.ownerUid,
          galleryId: gallery.id,
          eventId: gallery.data.eventId,
          title: definition.title,
          description: definition.description,
          coverUrl: gallery.data.coverUrl || null,
          pricingMode: "pick_n",
          photoIds,
          pickCount: definition.pickCount,
          price: definition.price,
          oldPrice: definition.oldPrice,
          currency: "EUR",
          isActive: gallery.data.status === "published",
          isRecommended: definition.recommended === true,
          sortOrder: definition.sortOrder,
          createdAt: serverTimestamp(),
          updatedAt: serverTimestamp(),
        },
        { merge: true }
      )
      created += 1
    }
    if (created > 0) await batch.commit()
    return created
  }

  const createPhotographerMediaGallery = onCall(
    {
      region: "us-east1",
      cpu: 0.083,
      memory: "256MiB",
      timeoutSeconds: 30,
    },
    async (request) => {
      const photographer = await assertPhotographerOwner(
        request,
        request.data?.photographerId
      )
      const title = nonEmptyString(request.data?.title)
      const eventId = nonEmptyString(request.data?.eventId)
      const circuitId = nonEmptyString(request.data?.circuitId)
      const countryId = nonEmptyString(request.data?.countryId)
      if (!title || !eventId || !circuitId || !countryId) {
        throw new HttpsError(
          "invalid-argument",
          "title, countryId, eventId and circuitId are required"
        )
      }
      const { plan } = await resolvePhotographerPlan(photographer)
      const activeGalleries = await db
        .collection(COLLECTIONS.mediaGalleries)
        .where("photographerId", "==", photographer.id)
        .get()
      const activeCount = activeGalleries.docs.filter(
        (doc) => doc.data()?.status !== ARCHIVED_GALLERY_STATUS
      ).length
      if (activeCount >= plan.maxActiveGalleries) {
        throw new HttpsError(
          "resource-exhausted",
          `Quota de galeries atteint pour l’offre ${plan.name}`
        )
      }
      const galleryRef = db.collection(COLLECTIONS.mediaGalleries).doc()
      const now = serverTimestamp()
      await galleryRef.set({
        galleryId: galleryRef.id,
        photographerId: photographer.id,
        ownerUid: photographer.data.ownerUid,
        eventId,
        eventName: nonEmptyString(request.data?.eventName) || null,
        title,
        description: nonEmptyString(request.data?.description) || null,
        visibility: "private",
        status: "draft",
        tags: [],
        linkedCountry: countryId,
        countryName: nonEmptyString(request.data?.countryName) || null,
        linkedCircuitId: circuitId,
        circuitName: nonEmptyString(request.data?.circuitName) || null,
        linkedGroupIds: [],
        photoCount: 0,
        publishedPhotoCount: 0,
        packCount: 0,
        retentionDays: plan.retentionDays,
        planCodeAtCreation: plan.code,
        createdAt: now,
        updatedAt: now,
      })
      return {
        galleryId: galleryRef.id,
        planCode: plan.code,
        maxActiveGalleries: plan.maxActiveGalleries,
      }
    }
  )

  const reservePhotographerMediaUploads = onCall(
    {
      region: "us-east1",
      cpu: 0.083,
      memory: "256MiB",
      timeoutSeconds: 60,
    },
    async (request) => {
      const photographer = await assertPhotographerOwner(
        request,
        request.data?.photographerId
      )
      const gallery = await getGalleryOwnedOrThrow(
        photographer,
        request.data?.galleryId
      )
      if (gallery.data.status === ARCHIVED_GALLERY_STATUS) {
        throw new HttpsError(
          "failed-precondition",
          "Une galerie archivée ne peut plus recevoir de photos"
        )
      }
      const files = Array.isArray(request.data?.files) ? request.data.files : []
      const { plan } = await resolvePhotographerPlan(photographer)
      if (files.length === 0 || files.length > plan.maxBatchUpload) {
        throw new HttpsError(
          "invalid-argument",
          `Le lot doit contenir entre 1 et ${plan.maxBatchUpload} photos`
        )
      }
      let totalBytes = 0
      const normalizedFiles = files.map((file, index) => {
        const fileName = safeFileName(file?.fileName, `photo_${index + 1}.jpg`)
        const mimeType = nonEmptyString(file?.mimeType).toLowerCase()
        const sizeBytes = toInteger(file?.sizeBytes, 0)
        if (!mimeType.startsWith("image/") || sizeBytes <= 0) {
          throw new HttpsError("invalid-argument", `Fichier invalide: ${fileName}`)
        }
        if (sizeBytes > plan.maxFileBytes) {
          throw new HttpsError(
            "resource-exhausted",
            `${fileName} dépasse la limite de ${Math.round(plan.maxFileBytes / MiB)} Mo`
          )
        }
        totalBytes += sizeBytes
        return { fileName, mimeType, sizeBytes }
      })

      const currentStorage = toInteger(photographer.data.storageUsedBytes, 0)
      const currentReservedStorage = toInteger(
        photographer.data.reservedStorageBytes,
        0
      )
      const currentPhotos = toInteger(photographer.data.publishedPhotoCount, 0)
      const currentReservedPhotos = toInteger(
        photographer.data.reservedPhotoCount,
        0
      )
      if (
        currentStorage + currentReservedStorage + totalBytes >
        plan.maxStorageBytes
      ) {
        throw new HttpsError(
          "resource-exhausted",
          `Quota de stockage atteint pour l’offre ${plan.name}`
        )
      }
      if (
        currentPhotos + currentReservedPhotos + normalizedFiles.length >
        plan.maxPublishedPhotos
      ) {
        throw new HttpsError(
          "resource-exhausted",
          `Quota photo atteint pour l’offre ${plan.name}`
        )
      }

      const now = Date.now()
      const expiresAt = admin.firestore.Timestamp.fromMillis(
        now + UPLOAD_RESERVATION_HOURS * 60 * 60 * 1000
      )
      const uploads = normalizedFiles.map((file) => {
        const photoRef = db.collection(COLLECTIONS.mediaPhotos).doc()
        const reservationRef = db
          .collection(COLLECTIONS.mediaUploadReservations)
          .doc()
        const extension = extensionForFileName(file.fileName, file.mimeType)
        const basePrefix =
          `photographers/${photographer.id}/events/${gallery.data.eventId}/` +
          `galleries/${gallery.id}`
        return {
          reservationId: reservationRef.id,
          reservationRef,
          photoId: photoRef.id,
          file,
          originalPath: `${basePrefix}/originals/${photoRef.id}.${extension}`,
          previewPath: `${basePrefix}/previews/${photoRef.id}.jpg`,
          thumbnailPath: `${basePrefix}/thumbs/${photoRef.id}.jpg`,
          watermarkedPath: `${basePrefix}/watermarked/${photoRef.id}.jpg`,
        }
      })

      await db.runTransaction(async (transaction) => {
        const latestSnapshot = await transaction.get(photographer.ref)
        const latest = latestSnapshot.data() || {}
        const used = toInteger(latest.storageUsedBytes, 0)
        const reservedBytes = toInteger(latest.reservedStorageBytes, 0)
        const publishedPhotos = toInteger(latest.publishedPhotoCount, 0)
        const reservedPhotos = toInteger(latest.reservedPhotoCount, 0)
        if (used + reservedBytes + totalBytes > plan.maxStorageBytes) {
          throw new HttpsError("resource-exhausted", "Quota stockage atteint")
        }
        if (
          publishedPhotos + reservedPhotos + uploads.length >
          plan.maxPublishedPhotos
        ) {
          throw new HttpsError("resource-exhausted", "Quota photo atteint")
        }
        transaction.set(
          photographer.ref,
          {
            reservedStorageBytes: reservedBytes + totalBytes,
            reservedPhotoCount: reservedPhotos + uploads.length,
            updatedAt: serverTimestamp(),
          },
          { merge: true }
        )
        for (const upload of uploads) {
          transaction.set(upload.reservationRef, {
            reservationId: upload.reservationId,
            photoId: upload.photoId,
            photographerId: photographer.id,
            ownerUid: photographer.data.ownerUid,
            galleryId: gallery.id,
            eventId: gallery.data.eventId,
            countryId: gallery.data.linkedCountry || "",
            countryName: gallery.data.countryName || null,
            eventName: gallery.data.eventName || null,
            circuitId: gallery.data.linkedCircuitId || "",
            circuitName: gallery.data.circuitName || null,
            fileName: upload.file.fileName,
            mimeType: upload.file.mimeType,
            reservedBytes: upload.file.sizeBytes,
            originalPath: upload.originalPath,
            previewPath: upload.previewPath,
            thumbnailPath: upload.thumbnailPath,
            watermarkedPath: upload.watermarkedPath,
            planCode: plan.code,
            maxFileBytes: plan.maxFileBytes,
            maxMegapixels: plan.maxMegapixels,
            status: "reserved",
            expiresAt,
            createdAt: serverTimestamp(),
            updatedAt: serverTimestamp(),
          })
        }
      })

      return {
        expiresAt: expiresAt.toDate().toISOString(),
        planCode: plan.code,
        uploads: uploads.map((upload) => ({
          reservationId: upload.reservationId,
          photoId: upload.photoId,
          originalPath: upload.originalPath,
          previewPath: upload.previewPath,
          thumbnailPath: upload.thumbnailPath,
          watermarkedPath: upload.watermarkedPath,
        })),
      }
    }
  )

  const finalizePhotographerMediaUpload = onCall(
    {
      region: "us-east1",
      cpu: 0.083,
      memory: "512MiB",
      timeoutSeconds: 90,
    },
    async (request) => {
      if (!request.auth) {
        throw new HttpsError("unauthenticated", "Authentication required")
      }
      const reservationId = nonEmptyString(request.data?.reservationId)
      const photoId = nonEmptyString(request.data?.photoId)
      if (!reservationId || !photoId) {
        throw new HttpsError(
          "invalid-argument",
          "reservationId and photoId are required"
        )
      }
      const reservationRef = db
        .collection(COLLECTIONS.mediaUploadReservations)
        .doc(reservationId)
      const reservationSnapshot = await reservationRef.get()
      if (!reservationSnapshot.exists) {
        throw new HttpsError("not-found", "Upload reservation not found")
      }
      const reservation = reservationSnapshot.data() || {}
      const photographer = await assertPhotographerOwner(
        request,
        reservation.photographerId
      )
      if (reservation.photoId !== photoId || reservation.status !== "reserved") {
        throw new HttpsError(
          "failed-precondition",
          "Upload reservation is not active"
        )
      }
      if (
        reservation.expiresAt?.toDate &&
        reservation.expiresAt.toDate().getTime() < Date.now()
      ) {
        throw new HttpsError("deadline-exceeded", "Upload reservation expired")
      }

      const originalPath = normalizeStoragePath(request.data?.originalPath)
      if (originalPath !== reservation.originalPath) {
        throw new HttpsError("permission-denied", "Original storage path mismatch")
      }
      const sizeBytes = toInteger(request.data?.sizeBytes, 0)
      const width = toInteger(request.data?.width, 0)
      const height = toInteger(request.data?.height, 0)
      const megapixels = (width * height) / 1000000
      if (sizeBytes <= 0 || sizeBytes > toInteger(reservation.maxFileBytes, 0)) {
        throw new HttpsError("resource-exhausted", "File size exceeds plan limit")
      }
      if (
        width <= 0 ||
        height <= 0 ||
        megapixels > toNumber(reservation.maxMegapixels, 0)
      ) {
        throw new HttpsError(
          "resource-exhausted",
          "Image resolution exceeds plan limit"
        )
      }

      const bucket = admin.storage().bucket()
      const storagePaths = [
        reservation.originalPath,
        reservation.previewPath,
        reservation.thumbnailPath,
        reservation.watermarkedPath,
      ]
      const metadataResults = await Promise.all(
        storagePaths.map(async (path) => {
          const file = bucket.file(path)
          const [exists] = await file.exists()
          if (!exists) {
            throw new HttpsError(
              "failed-precondition",
              `Uploaded media file missing: ${path}`
            )
          }
          const [metadata] = await file.getMetadata()
          return metadata
        })
      )
      const actualOriginalBytes = toInteger(metadataResults[0]?.size, 0)
      if (actualOriginalBytes <= 0 || actualOriginalBytes > reservation.maxFileBytes) {
        throw new HttpsError("resource-exhausted", "Stored original is too large")
      }

      const profileApproved =
        photographer.data.isVerified === true ||
        ["approved", "active", "verified"].includes(
          nonEmptyString(photographer.data.status).toLowerCase()
        )
      const unitPrice = Math.min(
        99,
        Math.max(0.99, toNumber(request.data?.unitPrice, 6.90))
      )
      const now = serverTimestamp()
      const photoRef = db.collection(COLLECTIONS.mediaPhotos).doc(photoId)
      await db.runTransaction(async (transaction) => {
        const freshReservation = await transaction.get(reservationRef)
        if (!freshReservation.exists) {
          throw new HttpsError("not-found", "Upload reservation not found")
        }
        const freshData = freshReservation.data() || {}
        if (freshData.status !== "reserved") {
          throw new HttpsError(
            "failed-precondition",
            "Upload already finalized"
          )
        }
        const profileSnapshot = await transaction.get(photographer.ref)
        const profile = profileSnapshot.data() || {}
        transaction.set(photoRef, {
          photoId,
          photographerId: photographer.id,
          ownerUid: photographer.data.ownerUid,
          galleryId: reservation.galleryId,
          eventId: reservation.eventId,
          eventName: reservation.eventName || null,
          countryId: reservation.countryId || "",
          countryName: reservation.countryName || null,
          circuitId: reservation.circuitId || "",
          circuitName: reservation.circuitName || null,
          originalPath: reservation.originalPath,
          previewPath: nonEmptyString(request.data?.previewPath),
          thumbnailPath: nonEmptyString(request.data?.thumbnailPath),
          watermarkedPath: nonEmptyString(request.data?.watermarkedPath),
          previewStoragePath: reservation.previewPath,
          thumbnailStoragePath: reservation.thumbnailPath,
          watermarkedStoragePath: reservation.watermarkedPath,
          derivativeStoragePaths: {
            preview: reservation.previewPath,
            thumbnail: reservation.thumbnailPath,
            watermarked: reservation.watermarkedPath,
          },
          downloadFileName:
            safeFileName(request.data?.downloadFileName, reservation.fileName),
          width,
          height,
          sizeBytes: actualOriginalBytes,
          mimeType:
            nonEmptyString(request.data?.mimeType) || reservation.mimeType,
          tags: [],
          faceTags: [],
          moderationStatus: profileApproved ? "approved" : "pending",
          lifecycleStatus: "ready",
          visibility: "private",
          isPublished: false,
          isForSale: false,
          saleEnabled: true,
          unitPrice,
          currency: "EUR",
          createdAt: now,
          updatedAt: now,
        })
        transaction.set(
          reservationRef,
          {
            status: "finalized",
            finalizedAt: now,
            actualBytes: actualOriginalBytes,
            updatedAt: now,
          },
          { merge: true }
        )
        transaction.set(
          photographer.ref,
          {
            reservedStorageBytes: Math.max(
              0,
              toInteger(profile.reservedStorageBytes, 0) -
                toInteger(reservation.reservedBytes, 0)
            ),
            reservedPhotoCount: Math.max(
              0,
              toInteger(profile.reservedPhotoCount, 0) - 1
            ),
            storageUsedBytes:
              toInteger(profile.storageUsedBytes, 0) + actualOriginalBytes,
            updatedAt: now,
          },
          { merge: true }
        )
      })
      return {
        photoId,
        galleryId: reservation.galleryId,
        moderationStatus: profileApproved ? "approved" : "pending",
        lifecycleStatus: "ready",
      }
    }
  )

  const ensurePhotographerGalleryDefaultPacks = onCall(
    {
      region: "us-east1",
      cpu: 0.083,
      memory: "256MiB",
      timeoutSeconds: 60,
    },
    async (request) => {
      const photographer = await assertPhotographerOwner(
        request,
        request.data?.photographerId
      )
      const gallery = await getGalleryOwnedOrThrow(
        photographer,
        request.data?.galleryId
      )
      const photosSnapshot = await db
        .collection(COLLECTIONS.mediaPhotos)
        .where("galleryId", "==", gallery.id)
        .get()
      const eligiblePhotos = photosSnapshot.docs.filter((doc) => {
        const data = doc.data() || {}
        return data.lifecycleStatus !== "archived"
      })
      const created = await ensureDefaultPacksInternal({
        photographer,
        gallery,
        photos: eligiblePhotos,
      })
      return { created, totalPhotos: eligiblePhotos.length }
    }
  )

  const publishPhotographerMediaGallery = onCall(
    {
      region: "us-east1",
      cpu: 0.083,
      memory: "512MiB",
      timeoutSeconds: 90,
    },
    async (request) => {
      const photographer = await assertPhotographerOwner(
        request,
        request.data?.photographerId
      )
      const gallery = await getGalleryOwnedOrThrow(
        photographer,
        request.data?.galleryId
      )
      const status = nonEmptyString(photographer.data.status).toLowerCase()
      const profileApproved =
        photographer.data.isVerified === true ||
        ["approved", "active", "verified"].includes(status)
      if (!profileApproved) {
        throw new HttpsError(
          "failed-precondition",
          "Le profil photographe doit être validé avant publication"
        )
      }
      if (
        photographer.data.stripe?.chargesEnabled !== true ||
        photographer.data.stripe?.payoutsEnabled !== true
      ) {
        throw new HttpsError(
          "failed-precondition",
          "Termine la configuration Stripe Connect avant de publier"
        )
      }
      const photosSnapshot = await db
        .collection(COLLECTIONS.mediaPhotos)
        .where("galleryId", "==", gallery.id)
        .get()
      const eligiblePhotos = photosSnapshot.docs.filter((doc) => {
        const data = doc.data() || {}
        return ["ready", "published"].includes(data.lifecycleStatus)
      })
      if (eligiblePhotos.length === 0) {
        throw new HttpsError(
          "failed-precondition",
          "La galerie doit contenir au moins une photo prête"
        )
      }
      const { plan } = await resolvePhotographerPlan(photographer)
      const nowDate = new Date()
      const retentionExpiresAt = admin.firestore.Timestamp.fromDate(
        new Date(nowDate.getTime() + plan.retentionDays * 24 * 60 * 60 * 1000)
      )
      const batch = db.batch()
      for (const photoDoc of eligiblePhotos) {
        batch.set(
          photoDoc.ref,
          {
            moderationStatus: "approved",
            lifecycleStatus: "published",
            visibility: "public",
            isPublished: true,
            isForSale: true,
            saleEnabled: true,
            retentionExpiresAt,
            publishedAt: serverTimestamp(),
            updatedAt: serverTimestamp(),
          },
          { merge: true }
        )
      }
      batch.set(
        gallery.ref,
        {
          status: "published",
          visibility: "public",
          retentionDays: plan.retentionDays,
          retentionExpiresAt,
          publishedAt: serverTimestamp(),
          updatedAt: serverTimestamp(),
        },
        { merge: true }
      )
      await batch.commit()
      const refreshedGallery = {
        ...gallery,
        data: { ...gallery.data, status: "published" },
      }
      const packsCreated = await ensureDefaultPacksInternal({
        photographer,
        gallery: refreshedGallery,
        photos: eligiblePhotos,
      })
      const packsSnapshot = await db
        .collection(COLLECTIONS.mediaPacks)
        .where("galleryId", "==", gallery.id)
        .get()
      const packBatch = db.batch()
      packsSnapshot.docs.forEach((doc) => {
        packBatch.set(
          doc.ref,
          { isActive: true, updatedAt: serverTimestamp() },
          { merge: true }
        )
      })
      if (!packsSnapshot.empty) await packBatch.commit()
      return {
        galleryId: gallery.id,
        publishedPhotoCount: eligiblePhotos.length,
        packsCreated,
        retentionExpiresAt: retentionExpiresAt.toDate().toISOString(),
      }
    }
  )

  const archivePhotographerMediaGallery = onCall(
    {
      region: "us-east1",
      cpu: 0.083,
      memory: "256MiB",
      timeoutSeconds: 60,
    },
    async (request) => {
      const photographer = await assertPhotographerOwner(
        request,
        request.data?.photographerId
      )
      const gallery = await getGalleryOwnedOrThrow(
        photographer,
        request.data?.galleryId
      )
      const { plan } = await resolvePhotographerPlan(photographer)
      const deleteAfter = admin.firestore.Timestamp.fromMillis(
        Date.now() + plan.retentionDays * 24 * 60 * 60 * 1000
      )
      const [photosSnapshot, packsSnapshot] = await Promise.all([
        db
          .collection(COLLECTIONS.mediaPhotos)
          .where("galleryId", "==", gallery.id)
          .get(),
        db
          .collection(COLLECTIONS.mediaPacks)
          .where("galleryId", "==", gallery.id)
          .get(),
      ])
      const batch = db.batch()
      batch.set(
        gallery.ref,
        {
          status: "archived",
          visibility: "private",
          archivedAt: serverTimestamp(),
          deleteAfter,
          updatedAt: serverTimestamp(),
        },
        { merge: true }
      )
      photosSnapshot.docs.forEach((doc) => {
        batch.set(
          doc.ref,
          {
            isPublished: false,
            isForSale: false,
            visibility: "private",
            lifecycleStatus: "archived",
            deleteAfter,
            updatedAt: serverTimestamp(),
          },
          { merge: true }
        )
      })
      packsSnapshot.docs.forEach((doc) => {
        batch.set(
          doc.ref,
          { isActive: false, updatedAt: serverTimestamp() },
          { merge: true }
        )
      })
      await batch.commit()
      return { galleryId: gallery.id, deleteAfter: deleteAfter.toDate().toISOString() }
    }
  )

  async function hasActiveEntitlementForPhoto(photoId) {
    const [direct, pack] = await Promise.all([
      db
        .collection(COLLECTIONS.mediaEntitlements)
        .where("assetId", "==", photoId)
        .where("isActive", "==", true)
        .limit(1)
        .get(),
      db
        .collection(COLLECTIONS.mediaEntitlements)
        .where("photoIds", "array-contains", photoId)
        .where("isActive", "==", true)
        .limit(1)
        .get(),
    ])
    return !direct.empty || !pack.empty
  }

  async function deletePhotoFiles(photo) {
    const paths = uniqueStrings([
      photo.originalPath,
      photo.previewStoragePath,
      photo.thumbnailStoragePath,
      photo.watermarkedStoragePath,
      photo.derivativeStoragePaths?.preview,
      photo.derivativeStoragePaths?.thumbnail,
      photo.derivativeStoragePaths?.watermarked,
    ])
    const bucket = admin.storage().bucket()
    await Promise.all(
      paths.map((path) => bucket.file(path).delete({ ignoreNotFound: true }))
    )
  }

  const deletePhotographerMediaPhoto = onCall(
    {
      region: "us-east1",
      cpu: 0.083,
      memory: "256MiB",
      timeoutSeconds: 60,
    },
    async (request) => {
      const photographer = await assertPhotographerOwner(
        request,
        request.data?.photographerId
      )
      const photoId = nonEmptyString(request.data?.photoId)
      if (!photoId) throw new HttpsError("invalid-argument", "photoId is required")
      const photoSnapshot = await db
        .collection(COLLECTIONS.mediaPhotos)
        .doc(photoId)
        .get()
      if (!photoSnapshot.exists) throw new HttpsError("not-found", "Photo not found")
      const photo = photoSnapshot.data() || {}
      if (photo.photographerId !== photographer.id) {
        throw new HttpsError("permission-denied", "Photo owner mismatch")
      }
      if (await hasActiveEntitlementForPhoto(photoId)) {
        throw new HttpsError(
          "failed-precondition",
          "Une photo déjà achetée doit être conservée"
        )
      }
      await deletePhotoFiles(photo)
      await photoSnapshot.ref.delete()
      return { deleted: true, photoId }
    }
  )

  const getMediaDownloadUrl = onCall(
    {
      region: "us-east1",
      cpu: 0.083,
      memory: "256MiB",
      timeoutSeconds: 30,
    },
    async (request) => {
      if (!request.auth) {
        throw new HttpsError("unauthenticated", "Authentication required")
      }
      const buyerUid = request.auth.uid
      const entitlementId = nonEmptyString(request.data?.entitlementId)
      const assetId = nonEmptyString(request.data?.assetId)
      const requestedPhotoId = nonEmptyString(request.data?.photoId)
      const variant = normalizeDownloadVariant(request.data?.variant)
      if (!entitlementId || !assetId) {
        throw new HttpsError(
          "invalid-argument",
          "entitlementId and assetId are required"
        )
      }
      const entitlementSnapshot = await db
        .collection(COLLECTIONS.mediaEntitlements)
        .doc(entitlementId)
        .get()
      if (!entitlementSnapshot.exists) {
        await logDownloadAttempt({
          buyerUid,
          entitlementId,
          assetId,
          assetType: "photo",
          outcome: "denied_not_found",
          request,
        })
        throw new HttpsError("not-found", "Entitlement not found")
      }
      const entitlement = entitlementSnapshot.data() || {}
      if (entitlement.buyerUid !== buyerUid) {
        await logDownloadAttempt({
          buyerUid,
          entitlementId,
          assetId,
          assetType: entitlement.assetType || "photo",
          outcome: "denied_wrong_user",
          request,
        })
        throw new HttpsError(
          "permission-denied",
          "This entitlement does not belong to you"
        )
      }
      if (entitlement.isActive !== true) {
        throw new HttpsError("failed-precondition", "Entitlement inactive")
      }
      if (
        entitlement.expiresAt?.toDate &&
        entitlement.expiresAt.toDate() < new Date()
      ) {
        throw new HttpsError("failed-precondition", "Entitlement expired")
      }
      const downloadLimit =
        entitlement.downloadLimit == null
          ? null
          : toInteger(entitlement.downloadLimit, 0)
      const downloadCount = toInteger(entitlement.downloadCount, 0)
      if (downloadLimit != null && downloadCount >= downloadLimit) {
        throw new HttpsError(
          "failed-precondition",
          "Download limit reached"
        )
      }
      if (entitlement.assetId !== assetId) {
        throw new HttpsError("permission-denied", "Asset mismatch")
      }
      const allowedVariants = getAllowedDownloadVariants(entitlement)
      if (!allowedVariants.includes(variant)) {
        await logDownloadAttempt({
          buyerUid,
          entitlementId,
          assetId,
          assetType: entitlement.assetType || "photo",
          photoId: requestedPhotoId || null,
          outcome: "denied_variant_not_entitled",
          request,
          metadata: { variant, allowedVariants },
        })
        throw new HttpsError(
          "permission-denied",
          "Requested media variant is not covered by this entitlement"
        )
      }
      let targetPhotoId = assetId
      if (entitlement.assetType === "pack") {
        targetPhotoId = requestedPhotoId
        if (
          !targetPhotoId ||
          !Array.isArray(entitlement.photoIds) ||
          !entitlement.photoIds.includes(targetPhotoId)
        ) {
          throw new HttpsError(
            "permission-denied",
            "Requested photo is not covered by this pack"
          )
        }
      }
      const photo = await getPhotoById(targetPhotoId)
      if (!photo) throw new HttpsError("not-found", "Photo not found")
      const downloadPath = buildDownloadPath(photo, variant)
      const normalizedDownloadPath = normalizeStoragePath(downloadPath)
      if (
        !normalizedDownloadPath ||
        !isStrictMarketplacePhotoPath(
          photo,
          variant,
          normalizedDownloadPath
        )
      ) {
        throw new HttpsError(
          "permission-denied",
          "Storage path is not allowed for this entitlement"
        )
      }
      const signedUrl = await createSignedDownloadUrl(
        normalizedDownloadPath,
        photo.downloadFileName || `${targetPhotoId}.jpg`
      )
      await Promise.all([
        entitlementSnapshot.ref.set(
          {
            downloadCount: admin.firestore.FieldValue.increment(1),
            updatedAt: serverTimestamp(),
          },
          { merge: true }
        ),
        logDownloadAttempt({
          buyerUid,
          entitlementId,
          assetId,
          assetType: entitlement.assetType || "photo",
          photoId: targetPhotoId,
          outcome: "allowed",
          signedUrlPath: normalizedDownloadPath,
          request,
          metadata: { variant, allowedVariants },
        }),
      ])
      return {
        url: signedUrl,
        expiresInSeconds: 900,
        path: normalizedDownloadPath,
        photoId: targetPhotoId,
        variant,
      }
    }
  )

  const syncMediaPhotoOnCreate = onDocumentCreated(
    {
      document: `${COLLECTIONS.mediaPhotos}/{photoId}`,
      region: "us-east1",
      cpu: 0.083,
      memory: "256MiB",
      timeoutSeconds: 30,
    },
    async (event) => {
      const data = event.data?.data()
      const photoId = event.params.photoId
      if (!data || !photoId) return
      await Promise.all([
        syncPhotoModerationQueue(photoId, data),
        syncPhotoDerivedState(photoId, data),
        handlePhotoWriteAfter(data, null),
      ])
    }
  )

  const syncMediaPhotoOnUpdate = onDocumentUpdated(
    {
      document: `${COLLECTIONS.mediaPhotos}/{photoId}`,
      region: "us-east1",
      cpu: 0.083,
      memory: "256MiB",
      timeoutSeconds: 30,
    },
    async (event) => {
      const beforeData = event.data?.before?.data()
      const afterData = event.data?.after?.data()
      const photoId = event.params.photoId
      if (!afterData || !photoId) return
      await Promise.all([
        syncPhotoModerationQueue(photoId, afterData),
        syncPhotoDerivedState(photoId, afterData),
        handlePhotoWriteAfter(afterData, beforeData),
      ])
    }
  )

  const syncMediaPhotoOnDelete = onDocumentDeleted(
    {
      document: `${COLLECTIONS.mediaPhotos}/{photoId}`,
      region: "us-east1",
      cpu: 0.083,
      memory: "256MiB",
      timeoutSeconds: 30,
    },
    async (event) => {
      const beforeData = event.data?.data()
      const photoId = event.params.photoId
      await Promise.all([
        db
          .collection(COLLECTIONS.adminModerationQueue)
          .doc(`photo_${photoId}`)
          .delete()
          .catch(() => null),
        handlePhotoWriteAfter(null, beforeData),
      ])
    }
  )

  const syncMediaPackOnCreate = onDocumentCreated(
    {
      document: `${COLLECTIONS.mediaPacks}/{packId}`,
      region: "us-east1",
      cpu: 0.083,
      memory: "256MiB",
      timeoutSeconds: 30,
    },
    async (event) => {
      const data = event.data?.data()
      if (data) await handlePackWriteAfter(data, null)
    }
  )

  const syncMediaPackOnUpdate = onDocumentUpdated(
    {
      document: `${COLLECTIONS.mediaPacks}/{packId}`,
      region: "us-east1",
      cpu: 0.083,
      memory: "256MiB",
      timeoutSeconds: 30,
    },
    async (event) => {
      const beforeData = event.data?.before?.data()
      const afterData = event.data?.after?.data()
      if (afterData) await handlePackWriteAfter(afterData, beforeData)
    }
  )

  const syncMediaPackOnDelete = onDocumentDeleted(
    {
      document: `${COLLECTIONS.mediaPacks}/{packId}`,
      region: "us-east1",
      cpu: 0.083,
      memory: "256MiB",
      timeoutSeconds: 30,
    },
    async (event) => {
      const beforeData = event.data?.data()
      await handlePackWriteAfter(null, beforeData)
    }
  )

  async function releaseExpiredReservation(reservationDoc) {
    const reservation = reservationDoc.data() || {}
    if (reservation.status !== "reserved") return false
    const photographerRef = db
      .collection(COLLECTIONS.photographers)
      .doc(reservation.photographerId)
    await Promise.all(
      uniqueStrings([
        reservation.originalPath,
        reservation.previewPath,
        reservation.thumbnailPath,
        reservation.watermarkedPath,
      ]).map((path) =>
        admin.storage().bucket().file(path).delete({ ignoreNotFound: true })
      )
    )
    await db.runTransaction(async (transaction) => {
      const freshReservation = await transaction.get(reservationDoc.ref)
      if (!freshReservation.exists || freshReservation.data()?.status !== "reserved") {
        return
      }
      const profileSnapshot = await transaction.get(photographerRef)
      const profile = profileSnapshot.exists ? profileSnapshot.data() || {} : {}
      transaction.set(
        photographerRef,
        {
          reservedStorageBytes: Math.max(
            0,
            toInteger(profile.reservedStorageBytes, 0) -
              toInteger(reservation.reservedBytes, 0)
          ),
          reservedPhotoCount: Math.max(
            0,
            toInteger(profile.reservedPhotoCount, 0) - 1
          ),
          updatedAt: serverTimestamp(),
        },
        { merge: true }
      )
      transaction.set(
        reservationDoc.ref,
        {
          status: "expired",
          expiredAt: serverTimestamp(),
          updatedAt: serverTimestamp(),
        },
        { merge: true }
      )
    })
    return true
  }

  const cleanupPhotographerMediaStorage = onSchedule(
    {
      schedule: "every day 03:20",
      timeZone: "Europe/Paris",
      region: "us-east1",
      cpu: 0.083,
      memory: "512MiB",
      timeoutSeconds: 540,
    },
    async () => {
      const now = admin.firestore.Timestamp.now()
      const expiredReservations = await db
        .collection(COLLECTIONS.mediaUploadReservations)
        .where("status", "==", "reserved")
        .where("expiresAt", "<=", now)
        .limit(200)
        .get()
      let expiredCount = 0
      for (const reservationDoc of expiredReservations.docs) {
        if (await releaseExpiredReservation(reservationDoc)) expiredCount += 1
      }

      const archivedGalleries = await db
        .collection(COLLECTIONS.mediaGalleries)
        .where("status", "==", "archived")
        .where("deleteAfter", "<=", now)
        .limit(30)
        .get()
      let deletedPhotos = 0
      for (const galleryDoc of archivedGalleries.docs) {
        const photoSnapshot = await db
          .collection(COLLECTIONS.mediaPhotos)
          .where("galleryId", "==", galleryDoc.id)
          .get()
        let galleryHasPurchasedPhoto = false
        for (const photoDoc of photoSnapshot.docs) {
          if (await hasActiveEntitlementForPhoto(photoDoc.id)) {
            galleryHasPurchasedPhoto = true
            continue
          }
          await deletePhotoFiles(photoDoc.data() || {})
          await photoDoc.ref.delete()
          deletedPhotos += 1
        }
        if (!galleryHasPurchasedPhoto) {
          const packSnapshot = await db
            .collection(COLLECTIONS.mediaPacks)
            .where("galleryId", "==", galleryDoc.id)
            .get()
          const batch = db.batch()
          packSnapshot.docs.forEach((doc) => batch.delete(doc.ref))
          batch.delete(galleryDoc.ref)
          await batch.commit()
        }
      }
      console.log("Photographer media cleanup completed", {
        expiredReservations: expiredCount,
        deletedPhotos,
      })
    }
  )

  return {
    createPhotographerMediaGallery,
    reservePhotographerMediaUploads,
    finalizePhotographerMediaUpload,
    publishPhotographerMediaGallery,
    archivePhotographerMediaGallery,
    ensurePhotographerGalleryDefaultPacks,
    deletePhotographerMediaPhoto,
    getMediaDownloadUrl,
    syncMediaPhotoOnCreate,
    syncMediaPhotoOnUpdate,
    syncMediaPhotoOnDelete,
    syncMediaPackOnCreate,
    syncMediaPackOnUpdate,
    syncMediaPackOnDelete,
    cleanupPhotographerMediaStorage,
  }
}
