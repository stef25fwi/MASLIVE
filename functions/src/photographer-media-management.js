module.exports = function createPhotographerMediaManagement(deps) {
  const {
    admin,
    db,
    onCall,
    onSchedule,
    HttpsError,
    logger,
    sharp,
  } = deps

  const COLLECTIONS = {
    photographers: "photographers",
    photographerPlans: "photographer_plans",
    photographerSubscriptions: "photographer_subscriptions",
    galleries: "media_galleries",
    photos: "media_photos",
    packs: "media_packs",
    entitlements: "media_entitlements",
    reservations: "media_upload_reservations",
  }

  const ACTIVE_SUBSCRIPTION_STATUSES = new Set(["trialing", "active", "past_due"])
  const ALLOWED_IMAGE_TYPES = new Set([
    "image/jpeg",
    "image/jpg",
    "image/png",
    "image/webp",
    "image/heic",
    "image/heif",
  ])
  const GIB = 1024 * 1024 * 1024
  const MIB = 1024 * 1024

  const PLAN_CATALOG = Object.freeze({
    discovery: Object.freeze({
      code: "discovery",
      name: "Découverte",
      monthlyPrice: 0,
      maxPublishedPhotos: 250,
      maxStorageBytes: 3 * GIB,
      maxActiveGalleries: 2,
      maxActivePacks: 5,
      maxFileBytes: 8 * MIB,
      maxMegapixels: 12,
      retentionDays: 30,
      commissionRate: 0.30,
      maxBatchUpload: 25,
    }),
    pro: Object.freeze({
      code: "pro",
      name: "Pro",
      monthlyPrice: 19.90,
      maxPublishedPhotos: 3000,
      maxStorageBytes: 30 * GIB,
      maxActiveGalleries: 20,
      maxActivePacks: 20,
      maxFileBytes: 20 * MIB,
      maxMegapixels: 24,
      retentionDays: 180,
      commissionRate: 0.25,
      maxBatchUpload: 100,
    }),
    studio: Object.freeze({
      code: "studio",
      name: "Studio",
      monthlyPrice: 39.90,
      maxPublishedPhotos: 10000,
      maxStorageBytes: 120 * GIB,
      maxActiveGalleries: 100,
      maxActivePacks: 100,
      maxFileBytes: 40 * MIB,
      maxMegapixels: 40,
      retentionDays: 365,
      commissionRate: 0.20,
      maxBatchUpload: 250,
    }),
    agency: Object.freeze({
      code: "agency",
      name: "Agence",
      monthlyPrice: 79.90,
      maxPublishedPhotos: 30000,
      maxStorageBytes: 400 * GIB,
      maxActiveGalleries: 500,
      maxActivePacks: 500,
      maxFileBytes: 70 * MIB,
      maxMegapixels: 60,
      retentionDays: 548,
      commissionRate: 0.15,
      maxBatchUpload: 500,
    }),
  })

  const DEFAULT_BUYER_PACKS = Object.freeze([
    Object.freeze({ code: "single", title: "1 photo souvenir", pickCount: 1, price: 6.90, oldPrice: 6.90, sortOrder: 10 }),
    Object.freeze({ code: "duo", title: "Pack Duo", pickCount: 2, price: 10.90, oldPrice: 13.80, sortOrder: 20 }),
    Object.freeze({ code: "essential", title: "Pack Essentiel", pickCount: 5, price: 19.90, oldPrice: 34.50, sortOrder: 30, recommended: true }),
    Object.freeze({ code: "experience", title: "Pack Expérience", pickCount: 10, price: 29.90, oldPrice: 69.00, sortOrder: 40 }),
    Object.freeze({ code: "personal_gallery", title: "Galerie personnelle", pickCount: 20, price: 44.90, oldPrice: 138.00, sortOrder: 50 }),
  ])

  function serverTimestamp() {
    return admin.firestore.FieldValue.serverTimestamp()
  }

  function nonEmptyString(value) {
    return typeof value === "string" && value.trim().length > 0 ? value.trim() : ""
  }

  function toNumber(value, fallback = 0) {
    const parsed = Number(value)
    return Number.isFinite(parsed) ? parsed : fallback
  }

  function toInteger(value, fallback = 0) {
    return Math.trunc(toNumber(value, fallback))
  }

  function clamp(value, min, max) {
    return Math.min(max, Math.max(min, value))
  }

  function normalizePlanCode(value) {
    const raw = nonEmptyString(value).toLowerCase()
    if (raw.includes("agency") || raw.includes("agence")) return "agency"
    if (raw.includes("studio")) return "studio"
    if (raw.includes("pro")) return "pro"
    return "discovery"
  }

  function normalizeMimeType(value) {
    const raw = nonEmptyString(value).toLowerCase()
    return raw === "image/jpg" ? "image/jpeg" : raw
  }

  function sanitizeFileBaseName(value, fallback = "photo") {
    const raw = nonEmptyString(value)
    if (!raw) return fallback
    const withoutExtension = raw.replace(/\.[^/.]+$/, "")
    const normalized = withoutExtension
      .normalize("NFD")
      .replace(/[\u0300-\u036f]/g, "")
      .replace(/[^a-zA-Z0-9_-]+/g, "_")
      .replace(/^_+|_+$/g, "")
      .toLowerCase()
      .slice(0, 80)
    return normalized || fallback
  }

  function extensionForMimeType(mimeType, fileName) {
    const normalized = normalizeMimeType(mimeType)
    if (normalized === "image/png") return "png"
    if (normalized === "image/webp") return "webp"
    if (normalized === "image/heic") return "heic"
    if (normalized === "image/heif") return "heif"
    const rawName = nonEmptyString(fileName).toLowerCase()
    if (rawName.endsWith(".jpeg")) return "jpeg"
    return "jpg"
  }

  function storageUrl(bucketName, storagePath) {
    return `gs://${bucketName}/${storagePath}`
  }

  function normalizeStoragePath(value) {
    const raw = nonEmptyString(value)
    if (!raw) return ""
    if (raw.startsWith("gs://")) {
      const firstSlash = raw.indexOf("/", 5)
      return firstSlash === -1 ? "" : raw.slice(firstSlash + 1)
    }
    return raw.replace(/^\/+/, "")
  }

  function planWithOverrides(basePlan, ...sources) {
    const plan = { ...basePlan }
    const integerFields = [
      "maxPublishedPhotos",
      "maxStorageBytes",
      "maxActiveGalleries",
      "maxActivePacks",
      "maxFileBytes",
      "maxMegapixels",
      "retentionDays",
      "maxBatchUpload",
    ]
    for (const source of sources) {
      if (!source || typeof source !== "object") continue
      for (const field of integerFields) {
        const value = toInteger(source[field], 0)
        if (value > 0) plan[field] = value
      }
      const commissionRate = toNumber(source.commissionRate, -1)
      if (commissionRate >= 0 && commissionRate <= 1) {
        plan.commissionRate = commissionRate
      }
      if (toNumber(source.monthlyPrice, -1) >= 0) {
        plan.monthlyPrice = toNumber(source.monthlyPrice, plan.monthlyPrice)
      }
      if (nonEmptyString(source.name)) plan.name = nonEmptyString(source.name)
      if (nonEmptyString(source.code)) plan.code = normalizePlanCode(source.code)
      if (nonEmptyString(source.planCode)) plan.code = normalizePlanCode(source.planCode)
    }
    return plan
  }

  async function assertPhotographerOwner(uid, photographerId) {
    if (!uid) throw new HttpsError("unauthenticated", "Authentication required")
    const normalizedId = nonEmptyString(photographerId)
    if (!normalizedId) {
      throw new HttpsError("invalid-argument", "photographerId is required")
    }
    const ref = db.collection(COLLECTIONS.photographers).doc(normalizedId)
    const snapshot = await ref.get()
    if (!snapshot.exists) {
      throw new HttpsError("not-found", "Photographer profile not found")
    }
    const profile = snapshot.data() || {}
    if (profile.ownerUid !== uid) {
      throw new HttpsError("permission-denied", "This photographer profile does not belong to you")
    }
    const status = nonEmptyString(profile.status).toLowerCase()
    if (status === "suspended" || status === "rejected") {
      throw new HttpsError("failed-precondition", "Photographer profile is not allowed to publish")
    }
    return { ref, snapshot, profile, photographerId: normalizedId }
  }

  async function resolvePhotographerPlan(photographerId, profile) {
    let subscription = null
    const subscriptions = await db
      .collection(COLLECTIONS.photographerSubscriptions)
      .where("photographerId", "==", photographerId)
      .where("status", "in", Array.from(ACTIVE_SUBSCRIPTION_STATUSES))
      .limit(1)
      .get()
    if (!subscriptions.empty) subscription = subscriptions.docs[0].data() || {}

    const quotaSnapshot = subscription?.quotaSnapshot && typeof subscription.quotaSnapshot === "object"
      ? subscription.quotaSnapshot
      : {}
    const candidateCode = quotaSnapshot.planCode || subscription?.planId || profile.activePlanId
    const code = normalizePlanCode(candidateCode)
    const basePlan = PLAN_CATALOG[code] || PLAN_CATALOG.discovery

    let planDocument = null
    const planId = nonEmptyString(subscription?.planId || profile.activePlanId)
    if (planId) {
      const planSnapshot = await db.collection(COLLECTIONS.photographerPlans).doc(planId).get()
      if (planSnapshot.exists) planDocument = planSnapshot.data() || {}
    }

    return planWithOverrides(basePlan, planDocument, quotaSnapshot)
  }

  async function getPendingReservationUsage(photographerId) {
    const snapshot = await db
      .collection(COLLECTIONS.reservations)
      .where("photographerId", "==", photographerId)
      .where("status", "==", "reserved")
      .limit(1000)
      .get()
    const now = Date.now()
    return snapshot.docs.reduce(
      (usage, document) => {
        const data = document.data() || {}
        const expiresAtMs = data.expiresAt?.toMillis?.() || 0
        if (expiresAtMs > 0 && expiresAtMs <= now) return usage
        usage.count += 1
        usage.bytes += Math.max(0, toInteger(data.sizeBytes, 0))
        return usage
      },
      { count: 0, bytes: 0 }
    )
  }

  async function getQuotaState(photographerId, profile, plan) {
    const pending = await getPendingReservationUsage(photographerId)
    const publishedPhotoCount = Math.max(0, toInteger(profile.publishedPhotoCount, 0))
    const activeGalleryCount = Math.max(0, toInteger(profile.activeGalleryCount, 0))
    const activePackCount = Math.max(0, toInteger(profile.activePackCount, 0))
    const storageUsedBytes = Math.max(0, toInteger(profile.storageUsedBytes, 0))
    return {
      plan,
      pendingReservationCount: pending.count,
      pendingReservationBytes: pending.bytes,
      publishedPhotoCount,
      activeGalleryCount,
      activePackCount,
      storageUsedBytes,
      photoCapacityRemaining: Math.max(0, plan.maxPublishedPhotos - publishedPhotoCount - pending.count),
      storageCapacityRemaining: Math.max(0, plan.maxStorageBytes - storageUsedBytes - pending.bytes),
      galleryCapacityRemaining: Math.max(0, plan.maxActiveGalleries - activeGalleryCount),
      packCapacityRemaining: Math.max(0, plan.maxActivePacks - activePackCount),
    }
  }

  async function assertOwnedGallery(photographerId, galleryId, ownerUid) {
    const normalizedGalleryId = nonEmptyString(galleryId)
    if (!normalizedGalleryId) {
      throw new HttpsError("invalid-argument", "galleryId is required")
    }
    const ref = db.collection(COLLECTIONS.galleries).doc(normalizedGalleryId)
    const snapshot = await ref.get()
    if (!snapshot.exists) throw new HttpsError("not-found", "Gallery not found")
    const gallery = snapshot.data() || {}
    if (gallery.photographerId !== photographerId || gallery.ownerUid !== ownerUid) {
      throw new HttpsError("permission-denied", "Gallery ownership mismatch")
    }
    return { ref, snapshot, gallery, galleryId: normalizedGalleryId }
  }

  function callableOptions({ heavy = false } = {}) {
    return heavy
      ? {
          region: "us-east1",
          cpu: 1,
          memory: "1GiB",
          timeoutSeconds: 180,
          maxInstances: 10,
        }
      : {
          region: "us-east1",
          cpu: 0.083,
          memory: "256MiB",
          timeoutSeconds: 60,
          maxInstances: 20,
        }
  }

  const getPhotographerMediaQuota = onCall(callableOptions(), async (request) => {
    const uid = request.auth?.uid
    const owned = await assertPhotographerOwner(uid, request.data?.photographerId)
    const plan = await resolvePhotographerPlan(owned.photographerId, owned.profile)
    const quota = await getQuotaState(owned.photographerId, owned.profile, plan)
    return quota
  })

  const createPhotographerMediaGallery = onCall(callableOptions(), async (request) => {
    const uid = request.auth?.uid
    const owned = await assertPhotographerOwner(uid, request.data?.photographerId)
    const title = nonEmptyString(request.data?.title)
    const eventId = nonEmptyString(request.data?.eventId)
    const circuitId = nonEmptyString(request.data?.circuitId)
    const countryId = nonEmptyString(request.data?.countryId)
    if (!title || !eventId || !circuitId || !countryId) {
      throw new HttpsError(
        "invalid-argument",
        "title, eventId, circuitId and countryId are required"
      )
    }

    const plan = await resolvePhotographerPlan(owned.photographerId, owned.profile)
    const quota = await getQuotaState(owned.photographerId, owned.profile, plan)
    if (quota.galleryCapacityRemaining <= 0) {
      throw new HttpsError("resource-exhausted", "Active gallery quota reached")
    }

    const ref = db.collection(COLLECTIONS.galleries).doc()
    const now = admin.firestore.Timestamp.now()
    await ref.set({
      galleryId: ref.id,
      photographerId: owned.photographerId,
      ownerUid: uid,
      eventId,
      eventName: nonEmptyString(request.data?.eventName) || null,
      title: title.slice(0, 120),
      description: nonEmptyString(request.data?.description).slice(0, 1000) || null,
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
      defaultPhotoUnitPrice: 6.90,
      currency: "EUR",
      planCodeAtCreation: plan.code,
      retentionDays: plan.retentionDays,
      createdAt: now,
      updatedAt: now,
    })

    return {
      galleryId: ref.id,
      planCode: plan.code,
      quota: {
        activeGalleryCount: quota.activeGalleryCount + 1,
        maxActiveGalleries: plan.maxActiveGalleries,
      },
    }
  })

  const reservePhotographerMediaUploads = onCall(callableOptions(), async (request) => {
    const uid = request.auth?.uid
    const owned = await assertPhotographerOwner(uid, request.data?.photographerId)
    const gallery = await assertOwnedGallery(
      owned.photographerId,
      request.data?.galleryId,
      uid
    )
    if (gallery.gallery.status === "archived") {
      throw new HttpsError("failed-precondition", "Archived gallery cannot receive uploads")
    }

    const rawFiles = Array.isArray(request.data?.files) ? request.data.files : []
    if (rawFiles.length === 0) {
      throw new HttpsError("invalid-argument", "At least one file is required")
    }

    const plan = await resolvePhotographerPlan(owned.photographerId, owned.profile)
    if (rawFiles.length > plan.maxBatchUpload) {
      throw new HttpsError(
        "resource-exhausted",
        `This plan accepts at most ${plan.maxBatchUpload} photos per batch`
      )
    }

    const files = rawFiles.map((raw, index) => {
      const fileName = nonEmptyString(raw?.fileName) || `photo_${index + 1}.jpg`
      const mimeType = normalizeMimeType(raw?.mimeType)
      const sizeBytes = toInteger(raw?.sizeBytes, 0)
      if (!ALLOWED_IMAGE_TYPES.has(mimeType)) {
        throw new HttpsError("invalid-argument", `Unsupported image type: ${mimeType || "unknown"}`)
      }
      if (sizeBytes <= 0 || sizeBytes > plan.maxFileBytes) {
        throw new HttpsError(
          "resource-exhausted",
          `${fileName} exceeds the ${Math.round(plan.maxFileBytes / MIB)} MB file limit`
        )
      }
      return { fileName, mimeType, sizeBytes }
    })

    const totalBytes = files.reduce((sum, file) => sum + file.sizeBytes, 0)
    const quota = await getQuotaState(owned.photographerId, owned.profile, plan)
    if (files.length > quota.photoCapacityRemaining) {
      throw new HttpsError("resource-exhausted", "Published photo quota would be exceeded")
    }
    if (totalBytes > quota.storageCapacityRemaining) {
      throw new HttpsError("resource-exhausted", "Storage quota would be exceeded")
    }

    const batch = db.batch()
    const createdAt = admin.firestore.Timestamp.now()
    const expiresAt = admin.firestore.Timestamp.fromMillis(Date.now() + 24 * 60 * 60 * 1000)
    const uploads = files.map((file, index) => {
      const reservationRef = db.collection(COLLECTIONS.reservations).doc()
      const photoRef = db.collection(COLLECTIONS.photos).doc()
      const extension = extensionForMimeType(file.mimeType, file.fileName)
      const basePrefix = `photographers/${owned.photographerId}/events/${gallery.gallery.eventId}/galleries/${gallery.galleryId}`
      const originalPath = `${basePrefix}/originals/${photoRef.id}.${extension}`
      const previewPath = `${basePrefix}/previews/${photoRef.id}.jpg`
      const thumbnailPath = `${basePrefix}/thumbs/${photoRef.id}.jpg`
      const watermarkedPath = `${basePrefix}/watermarked/${photoRef.id}.jpg`

      batch.set(reservationRef, {
        reservationId: reservationRef.id,
        photoId: photoRef.id,
        photographerId: owned.photographerId,
        ownerUid: uid,
        galleryId: gallery.galleryId,
        eventId: gallery.gallery.eventId,
        countryId: gallery.gallery.linkedCountry || "",
        circuitId: gallery.gallery.linkedCircuitId || "",
        fileName: file.fileName,
        sanitizedBaseName: sanitizeFileBaseName(file.fileName, `photo_${index + 1}`),
        mimeType: file.mimeType,
        sizeBytes: file.sizeBytes,
        originalPath,
        previewPath,
        thumbnailPath,
        watermarkedPath,
        status: "reserved",
        planCode: plan.code,
        maxFileBytes: plan.maxFileBytes,
        maxMegapixels: plan.maxMegapixels,
        createdAt,
        expiresAt,
        updatedAt: createdAt,
      })

      return {
        reservationId: reservationRef.id,
        photoId: photoRef.id,
        originalPath,
        previewPath,
        thumbnailPath,
        watermarkedPath,
        expiresAt: expiresAt.toDate().toISOString(),
      }
    })
    await batch.commit()

    return {
      uploads,
      planCode: plan.code,
      remaining: {
        photos: quota.photoCapacityRemaining - files.length,
        storageBytes: quota.storageCapacityRemaining - totalBytes,
      },
    }
  })

  async function buildMediaDerivatives(originalBuffer, metadata) {
    const oriented = sharp(originalBuffer).rotate()
    const previewBuffer = await oriented
      .clone()
      .resize({ width: 1600, height: 1600, fit: "inside", withoutEnlargement: true })
      .jpeg({ quality: 82, mozjpeg: true })
      .toBuffer()
    const thumbnailBuffer = await oriented
      .clone()
      .resize({ width: 480, height: 480, fit: "inside", withoutEnlargement: true })
      .jpeg({ quality: 74, mozjpeg: true })
      .toBuffer()

    const previewMetadata = await sharp(previewBuffer).metadata()
    const width = Math.max(1, toInteger(previewMetadata.width, metadata.width || 1600))
    const height = Math.max(1, toInteger(previewMetadata.height, metadata.height || 1200))
    const fontSize = clamp(Math.round(width / 18), 28, 84)
    const watermarkSvg = Buffer.from(
      `<svg xmlns="http://www.w3.org/2000/svg" width="${width}" height="${height}">` +
      `<rect x="0" y="${Math.max(0, height - Math.round(fontSize * 1.9))}" width="${width}" height="${Math.round(fontSize * 1.9)}" fill="rgba(0,0,0,0.30)"/>` +
      `<text x="50%" y="${Math.max(fontSize, height - Math.round(fontSize * 0.55))}" text-anchor="middle" font-family="Arial, sans-serif" font-size="${fontSize}" font-weight="700" fill="rgba(255,255,255,0.78)" letter-spacing="${Math.max(2, Math.round(fontSize / 8))}">MASLIVE • APERÇU</text>` +
      `</svg>`
    )
    const watermarkedBuffer = await sharp(previewBuffer)
      .composite([{ input: watermarkSvg, top: 0, left: 0 }])
      .jpeg({ quality: 80, mozjpeg: true })
      .toBuffer()

    return { previewBuffer, thumbnailBuffer, watermarkedBuffer }
  }

  const finalizePhotographerMediaUpload = onCall(callableOptions({ heavy: true }), async (request) => {
    const uid = request.auth?.uid
    if (!uid) throw new HttpsError("unauthenticated", "Authentication required")
    const reservationId = nonEmptyString(request.data?.reservationId)
    const requestedPhotoId = nonEmptyString(request.data?.photoId)
    if (!reservationId || !requestedPhotoId) {
      throw new HttpsError("invalid-argument", "reservationId and photoId are required")
    }

    const reservationRef = db.collection(COLLECTIONS.reservations).doc(reservationId)
    const reservationSnapshot = await reservationRef.get()
    if (!reservationSnapshot.exists) {
      throw new HttpsError("not-found", "Upload reservation not found")
    }
    const reservation = reservationSnapshot.data() || {}
    if (reservation.ownerUid !== uid) {
      throw new HttpsError("permission-denied", "Upload reservation ownership mismatch")
    }
    if (reservation.photoId !== requestedPhotoId) {
      throw new HttpsError("permission-denied", "Reserved photo id mismatch")
    }
    if (reservation.status === "finalized") {
      return { photoId: requestedPhotoId, alreadyFinalized: true }
    }
    if (reservation.status !== "reserved") {
      throw new HttpsError("failed-precondition", "Upload reservation is not active")
    }
    const expiresAtMs = reservation.expiresAt?.toMillis?.() || 0
    if (expiresAtMs > 0 && expiresAtMs <= Date.now()) {
      throw new HttpsError("deadline-exceeded", "Upload reservation expired")
    }

    const owned = await assertPhotographerOwner(uid, reservation.photographerId)
    const gallery = await assertOwnedGallery(
      owned.photographerId,
      reservation.galleryId,
      uid
    )
    const plan = await resolvePhotographerPlan(owned.photographerId, owned.profile)
    const bucket = admin.storage().bucket()
    const originalPath = normalizeStoragePath(reservation.originalPath)
    const originalFile = bucket.file(originalPath)
    const [exists] = await originalFile.exists()
    if (!exists) throw new HttpsError("failed-precondition", "Original upload is missing")

    const [objectMetadata] = await originalFile.getMetadata()
    const actualSizeBytes = toInteger(objectMetadata.size, 0)
    const actualMimeType = normalizeMimeType(objectMetadata.contentType || reservation.mimeType)
    const customMetadata = objectMetadata.metadata || {}
    if (
      customMetadata.reservationId !== reservationId ||
      customMetadata.photoId !== requestedPhotoId ||
      customMetadata.photographerId !== owned.photographerId ||
      customMetadata.galleryId !== gallery.galleryId
    ) {
      throw new HttpsError("permission-denied", "Storage metadata does not match reservation")
    }
    if (!ALLOWED_IMAGE_TYPES.has(actualMimeType)) {
      throw new HttpsError("invalid-argument", "Uploaded object is not a supported image")
    }
    if (actualSizeBytes <= 0 || actualSizeBytes > plan.maxFileBytes) {
      throw new HttpsError("resource-exhausted", "Uploaded object exceeds the plan file limit")
    }

    const [originalBuffer] = await originalFile.download()
    let imageMetadata
    try {
      imageMetadata = await sharp(originalBuffer).metadata()
    } catch (error) {
      throw new HttpsError("invalid-argument", "Uploaded image cannot be decoded")
    }
    const width = toInteger(imageMetadata.width, 0)
    const height = toInteger(imageMetadata.height, 0)
    const megapixels = width > 0 && height > 0 ? (width * height) / 1000000 : 0
    if (width <= 0 || height <= 0 || megapixels > plan.maxMegapixels) {
      throw new HttpsError(
        "resource-exhausted",
        `Image exceeds the ${plan.maxMegapixels} megapixel plan limit`
      )
    }

    const derivatives = await buildMediaDerivatives(originalBuffer, imageMetadata)
    const derivativeMetadata = {
      contentType: "image/jpeg",
      cacheControl: "public,max-age=31536000,immutable",
      metadata: {
        photographerId: owned.photographerId,
        galleryId: gallery.galleryId,
        photoId: requestedPhotoId,
        generatedBy: "photographer-media-management",
      },
    }
    await Promise.all([
      bucket.file(reservation.previewPath).save(derivatives.previewBuffer, derivativeMetadata),
      bucket.file(reservation.thumbnailPath).save(derivatives.thumbnailBuffer, derivativeMetadata),
      bucket.file(reservation.watermarkedPath).save(derivatives.watermarkedBuffer, derivativeMetadata),
    ])

    const moderationApproved = nonEmptyString(owned.profile.status).toLowerCase() === "approved"
    const unitPrice = clamp(toNumber(request.data?.unitPrice, gallery.gallery.defaultPhotoUnitPrice || 6.90), 1, 250)
    const now = admin.firestore.Timestamp.now()
    const photoRef = db.collection(COLLECTIONS.photos).doc(requestedPhotoId)

    await db.runTransaction(async (transaction) => {
      const latestReservation = await transaction.get(reservationRef)
      if (!latestReservation.exists) {
        throw new HttpsError("not-found", "Upload reservation disappeared")
      }
      const latest = latestReservation.data() || {}
      if (latest.status === "finalized") return
      if (latest.status !== "reserved" || latest.ownerUid !== uid) {
        throw new HttpsError("failed-precondition", "Upload reservation changed")
      }

      transaction.set(photoRef, {
        photoId: requestedPhotoId,
        photographerId: owned.photographerId,
        ownerUid: uid,
        galleryId: gallery.galleryId,
        eventId: gallery.gallery.eventId,
        eventName: gallery.gallery.eventName || null,
        countryId: gallery.gallery.linkedCountry || "",
        countryName: gallery.gallery.countryName || null,
        circuitId: gallery.gallery.linkedCircuitId || "",
        circuitName: gallery.gallery.circuitName || null,
        originalPath: storageUrl(bucket.name, reservation.originalPath),
        previewPath: storageUrl(bucket.name, reservation.previewPath),
        thumbnailPath: storageUrl(bucket.name, reservation.thumbnailPath),
        watermarkedPath: storageUrl(bucket.name, reservation.watermarkedPath),
        downloadFileName: reservation.fileName || `${requestedPhotoId}.jpg`,
        width,
        height,
        sizeBytes: actualSizeBytes,
        mimeType: actualMimeType,
        exif: {},
        tags: [],
        faceTags: [],
        moderationStatus: moderationApproved ? "approved" : "pending",
        lifecycleStatus: "ready",
        visibility: "private",
        isPublished: false,
        isForSale: false,
        unitPrice,
        currency: "EUR",
        createdAt: now,
        updatedAt: now,
      }, { merge: false })

      transaction.set(reservationRef, {
        status: "finalized",
        finalizedAt: now,
        actualSizeBytes,
        width,
        height,
        updatedAt: now,
      }, { merge: true })
    })

    return {
      photoId: requestedPhotoId,
      moderationStatus: moderationApproved ? "approved" : "pending",
      width,
      height,
      sizeBytes: actualSizeBytes,
      previewPath: storageUrl(bucket.name, reservation.previewPath),
      thumbnailPath: storageUrl(bucket.name, reservation.thumbnailPath),
    }
  })

  async function ensureDefaultPacksForGallery({ photographerId, ownerUid, galleryId, eventId, photoIds, coverUrl }) {
    const usablePhotoIds = Array.from(new Set((photoIds || []).filter(Boolean)))
    const existing = await db
      .collection(COLLECTIONS.packs)
      .where("galleryId", "==", galleryId)
      .get()
    const existingCodes = new Set(existing.docs.map((document) => nonEmptyString(document.data()?.commercialCode)))
    const batch = db.batch()
    let created = 0
    for (const definition of DEFAULT_BUYER_PACKS) {
      if (usablePhotoIds.length < definition.pickCount || existingCodes.has(definition.code)) continue
      const ref = db.collection(COLLECTIONS.packs).doc()
      batch.set(ref, {
        packId: ref.id,
        commercialCode: definition.code,
        photographerId,
        ownerUid,
        galleryId,
        eventId,
        title: definition.title,
        description: definition.recommended
          ? "Le pack recommandé pour revivre votre parcours."
          : `${definition.pickCount} photos sélectionnées dans cette galerie.`,
        coverUrl: coverUrl || null,
        pricingMode: "fixed_pack",
        photoIds: usablePhotoIds.slice(0, definition.pickCount),
        pickCount: definition.pickCount,
        price: definition.price,
        oldPrice: definition.oldPrice,
        currency: "EUR",
        isActive: true,
        moderationStatus: "approved",
        recommended: definition.recommended === true,
        sortOrder: definition.sortOrder,
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      })
      created += 1
    }
    if (created > 0) await batch.commit()
    return created
  }

  const ensurePhotographerGalleryDefaultPacks = onCall(callableOptions(), async (request) => {
    const uid = request.auth?.uid
    const owned = await assertPhotographerOwner(uid, request.data?.photographerId)
    const gallery = await assertOwnedGallery(
      owned.photographerId,
      request.data?.galleryId,
      uid
    )
    const plan = await resolvePhotographerPlan(owned.photographerId, owned.profile)
    const quota = await getQuotaState(owned.photographerId, owned.profile, plan)
    if (quota.packCapacityRemaining <= 0) {
      throw new HttpsError("resource-exhausted", "Active pack quota reached")
    }
    const photos = await db
      .collection(COLLECTIONS.photos)
      .where("galleryId", "==", gallery.galleryId)
      .where("moderationStatus", "==", "approved")
      .get()
    const photoIds = photos.docs
      .filter((document) => ["ready", "published"].includes(nonEmptyString(document.data()?.lifecycleStatus)))
      .map((document) => document.id)
    if (photoIds.length === 0) {
      throw new HttpsError("failed-precondition", "No approved photo is available for packs")
    }
    const created = await ensureDefaultPacksForGallery({
      photographerId: owned.photographerId,
      ownerUid: uid,
      galleryId: gallery.galleryId,
      eventId: gallery.gallery.eventId,
      photoIds,
      coverUrl: gallery.gallery.coverUrl || null,
    })
    return { created }
  })

  const publishPhotographerMediaGallery = onCall(callableOptions(), async (request) => {
    const uid = request.auth?.uid
    const owned = await assertPhotographerOwner(uid, request.data?.photographerId)
    if (nonEmptyString(owned.profile.status).toLowerCase() !== "approved") {
      throw new HttpsError("failed-precondition", "Photographer approval is required before publication")
    }
    const gallery = await assertOwnedGallery(
      owned.photographerId,
      request.data?.galleryId,
      uid
    )
    const plan = await resolvePhotographerPlan(owned.photographerId, owned.profile)
    const photoSnapshot = await db
      .collection(COLLECTIONS.photos)
      .where("galleryId", "==", gallery.galleryId)
      .get()
    const publishable = photoSnapshot.docs.filter((document) => {
      const data = document.data() || {}
      return data.moderationStatus === "approved" && ["ready", "published"].includes(data.lifecycleStatus)
    })
    if (publishable.length === 0) {
      throw new HttpsError("failed-precondition", "Gallery requires at least one approved photo")
    }

    const batch = db.batch()
    const now = admin.firestore.Timestamp.now()
    const retentionExpiresAt = admin.firestore.Timestamp.fromMillis(
      Date.now() + plan.retentionDays * 24 * 60 * 60 * 1000
    )
    for (const document of publishable) {
      batch.set(document.ref, {
        lifecycleStatus: "published",
        visibility: "public",
        isPublished: true,
        isForSale: true,
        updatedAt: now,
      }, { merge: true })
    }
    const coverPhoto = publishable[0]
    const coverData = coverPhoto.data() || {}
    batch.set(gallery.ref, {
      status: "published",
      visibility: "public",
      publishedAt: now,
      retentionDays: plan.retentionDays,
      retentionExpiresAt,
      coverPhotoId: coverPhoto.id,
      coverUrl: coverData.thumbnailPath || coverData.previewPath || null,
      updatedAt: now,
    }, { merge: true })
    await batch.commit()

    return {
      galleryId: gallery.galleryId,
      publishedPhotoCount: publishable.length,
      retentionExpiresAt: retentionExpiresAt.toDate().toISOString(),
    }
  })

  const archivePhotographerMediaGallery = onCall(callableOptions(), async (request) => {
    const uid = request.auth?.uid
    const owned = await assertPhotographerOwner(uid, request.data?.photographerId)
    const gallery = await assertOwnedGallery(
      owned.photographerId,
      request.data?.galleryId,
      uid
    )
    const photos = await db
      .collection(COLLECTIONS.photos)
      .where("galleryId", "==", gallery.galleryId)
      .get()
    const batch = db.batch()
    const now = admin.firestore.Timestamp.now()
    batch.set(gallery.ref, {
      status: "archived",
      visibility: "private",
      archivedAt: now,
      updatedAt: now,
    }, { merge: true })
    for (const photo of photos.docs) {
      batch.set(photo.ref, {
        isPublished: false,
        isForSale: false,
        visibility: "private",
        lifecycleStatus: "archived",
        updatedAt: now,
      }, { merge: true })
    }
    await batch.commit()
    return { galleryId: gallery.galleryId, archivedPhotoCount: photos.size }
  })

  async function photoHasActiveEntitlement(photoId) {
    const [direct, inPack] = await Promise.all([
      db.collection(COLLECTIONS.entitlements)
        .where("assetId", "==", photoId)
        .where("isActive", "==", true)
        .limit(1)
        .get(),
      db.collection(COLLECTIONS.entitlements)
        .where("photoIds", "array-contains", photoId)
        .where("isActive", "==", true)
        .limit(1)
        .get(),
    ])
    return !direct.empty || !inPack.empty
  }

  async function deleteStoragePaths(paths) {
    const bucket = admin.storage().bucket()
    await Promise.all(
      Array.from(new Set((paths || []).map(normalizeStoragePath).filter(Boolean)))
        .map((path) => bucket.file(path).delete({ ignoreNotFound: true }).catch((error) => {
          logger.warn("Unable to delete photographer media object", { path, code: error?.code || null })
        }))
    )
  }

  const deletePhotographerMediaPhoto = onCall(callableOptions(), async (request) => {
    const uid = request.auth?.uid
    const owned = await assertPhotographerOwner(uid, request.data?.photographerId)
    const photoId = nonEmptyString(request.data?.photoId)
    if (!photoId) throw new HttpsError("invalid-argument", "photoId is required")
    const ref = db.collection(COLLECTIONS.photos).doc(photoId)
    const snapshot = await ref.get()
    if (!snapshot.exists) throw new HttpsError("not-found", "Photo not found")
    const photo = snapshot.data() || {}
    if (photo.photographerId !== owned.photographerId || photo.ownerUid !== uid) {
      throw new HttpsError("permission-denied", "Photo ownership mismatch")
    }

    const sold = await photoHasActiveEntitlement(photoId)
    if (sold) {
      await ref.set({
        isPublished: false,
        isForSale: false,
        visibility: "private",
        lifecycleStatus: "archived",
        archivedReason: "sold_asset_retained",
        updatedAt: serverTimestamp(),
      }, { merge: true })
      return { photoId, deleted: false, retainedForBuyer: true }
    }

    await deleteStoragePaths([
      photo.originalPath,
      photo.previewPath,
      photo.thumbnailPath,
      photo.watermarkedPath,
    ])
    await ref.delete()
    return { photoId, deleted: true, retainedForBuyer: false }
  })

  const cleanupExpiredPhotographerMedia = onSchedule(
    {
      schedule: "every day 03:30",
      timeZone: "Europe/Paris",
      region: "us-east1",
      memory: "512MiB",
      timeoutSeconds: 540,
      maxInstances: 1,
    },
    async () => {
      const now = admin.firestore.Timestamp.now()
      const expiredReservations = await db
        .collection(COLLECTIONS.reservations)
        .where("status", "==", "reserved")
        .where("expiresAt", "<=", now)
        .limit(200)
        .get()

      for (const reservationDocument of expiredReservations.docs) {
        const reservation = reservationDocument.data() || {}
        await deleteStoragePaths([reservation.originalPath])
        await reservationDocument.ref.set({
          status: "expired",
          expiredAt: serverTimestamp(),
          updatedAt: serverTimestamp(),
        }, { merge: true })
      }

      const expiredGalleries = await db
        .collection(COLLECTIONS.galleries)
        .where("retentionExpiresAt", "<=", now)
        .limit(10)
        .get()
      let deletedPhotos = 0
      let retainedPhotos = 0

      for (const galleryDocument of expiredGalleries.docs) {
        const gallery = galleryDocument.data() || {}
        if (gallery.status === "expired") continue
        const photos = await db
          .collection(COLLECTIONS.photos)
          .where("galleryId", "==", galleryDocument.id)
          .limit(250)
          .get()

        for (const photoDocument of photos.docs) {
          const photo = photoDocument.data() || {}
          const sold = await photoHasActiveEntitlement(photoDocument.id)
          if (sold) {
            await deleteStoragePaths([
              photo.previewPath,
              photo.thumbnailPath,
              photo.watermarkedPath,
            ])
            await photoDocument.ref.set({
              previewPath: "",
              thumbnailPath: "",
              watermarkedPath: "",
              isPublished: false,
              isForSale: false,
              visibility: "private",
              lifecycleStatus: "archived",
              archivedReason: "retention_expired_buyer_original_retained",
              updatedAt: serverTimestamp(),
            }, { merge: true })
            retainedPhotos += 1
          } else {
            await deleteStoragePaths([
              photo.originalPath,
              photo.previewPath,
              photo.thumbnailPath,
              photo.watermarkedPath,
            ])
            await photoDocument.ref.delete()
            deletedPhotos += 1
          }
        }

        await galleryDocument.ref.set({
          status: "expired",
          visibility: "private",
          expiredAt: serverTimestamp(),
          updatedAt: serverTimestamp(),
        }, { merge: true })
      }

      logger.info("Photographer media retention cleanup completed", {
        expiredReservations: expiredReservations.size,
        expiredGalleries: expiredGalleries.size,
        deletedPhotos,
        retainedPhotos,
      })
    }
  )

  return {
    getPhotographerMediaQuota,
    createPhotographerMediaGallery,
    reservePhotographerMediaUploads,
    finalizePhotographerMediaUpload,
    ensurePhotographerGalleryDefaultPacks,
    publishPhotographerMediaGallery,
    archivePhotographerMediaGallery,
    deletePhotographerMediaPhoto,
    cleanupExpiredPhotographerMedia,
  }
}
