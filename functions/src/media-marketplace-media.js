"use strict"

const crypto = require("node:crypto")
const sharp = require("sharp")
const {
  planFor,
  quotaSnapshot,
} = require("./media-marketplace-pricing")

module.exports = function createMediaMarketplaceMedia({
  admin,
  db,
  onCall,
  HttpsError,
  onDocumentCreated,
  onDocumentUpdated,
  onDocumentDeleted,
}) {
  const COLLECTIONS = Object.freeze({
    photographers: "photographers",
    subscriptions: "photographer_subscriptions",
    galleries: "media_galleries",
    photos: "media_photos",
    packs: "media_packs",
    entitlements: "media_entitlements",
    downloadLogs: "media_download_logs",
    moderationQueue: "admin_moderation_queue",
  })

  const serverTimestamp = () => admin.firestore.FieldValue.serverTimestamp()
  const increment = (value) => admin.firestore.FieldValue.increment(value)

  function nonEmptyString(value) {
    return typeof value === "string" && value.trim().length > 0
      ? value.trim()
      : ""
  }

  function asInt(value, fallback = 0) {
    const parsed = Number(value)
    return Number.isFinite(parsed) ? Math.trunc(parsed) : fallback
  }

  function normalizeStoragePath(path) {
    const normalized = nonEmptyString(path).replace(/\\/g, "/")
    if (!normalized) return ""
    if (normalized.startsWith("/") || normalized.includes("..") || normalized.includes("//")) {
      return ""
    }
    return normalized
  }

  function expectedPhotoPrefix(photo) {
    return [
      "photographers",
      nonEmptyString(photo.photographerId),
      "events",
      nonEmptyString(photo.eventId),
      "galleries",
      nonEmptyString(photo.galleryId),
    ].join("/")
  }

  function expectedVariantDirectory(variant) {
    switch (variant) {
      case "original":
      case "hd":
        return "originals"
      case "preview":
      case "web":
        return "previews"
      case "thumbnail":
      case "thumb":
        return "thumbs"
      case "watermarked":
        return "watermarked"
      default:
        return ""
    }
  }

  function storagePathForVariant(photo, variant) {
    switch (variant) {
      case "original":
      case "hd":
        return normalizeStoragePath(photo.originalPath)
      case "preview":
      case "web":
        return normalizeStoragePath(photo.previewPath)
      case "thumbnail":
      case "thumb":
        return normalizeStoragePath(photo.thumbnailPath)
      case "watermarked":
        return normalizeStoragePath(photo.watermarkedPath)
      default:
        return ""
    }
  }

  function isStrictMarketplacePhotoPath(photo, variant, storagePath) {
    const normalized = normalizeStoragePath(storagePath)
    if (!normalized) return false
    const directory = expectedVariantDirectory(variant)
    if (!directory) return false
    const prefix = `${expectedPhotoPrefix(photo)}/${directory}/`
    if (!normalized.startsWith(prefix)) return false
    const basename = normalized.slice(prefix.length)
    if (!basename || basename.includes("/")) return false
    return basename.startsWith(`${photo.photoId}.`) || basename === photo.photoId
  }

  function isOwnerOrAdmin(profile, auth) {
    if (!auth?.uid) return false
    const claims = auth.token || {}
    const adminRole = claims.admin === true || claims.isAdmin === true || claims.role === "admin" || claims.role === "superadmin"
    return adminRole || profile?.ownerUid === auth.uid
  }

  async function readPlanContext(photographerId) {
    const photographerRef = db.collection(COLLECTIONS.photographers).doc(photographerId)
    const photographerSnap = await photographerRef.get()
    if (!photographerSnap.exists) {
      throw new HttpsError("failed-precondition", "Photographer profile not found")
    }
    const profile = photographerSnap.data() || {}
    const activePlanId = nonEmptyString(profile.activePlanId) || "discovery"
    const plan = planFor(activePlanId)
    let snapshot = quotaSnapshot(plan)

    const activeSubscriptionId = nonEmptyString(profile.activeSubscriptionId)
    if (activeSubscriptionId) {
      const subscriptionSnap = await db.collection(COLLECTIONS.subscriptions).doc(activeSubscriptionId).get()
      if (subscriptionSnap.exists) {
        const subscription = subscriptionSnap.data() || {}
        const stored = subscription.quotaSnapshot || {}
        snapshot = {
          ...snapshot,
          ...Object.fromEntries(
            Object.entries(stored).filter(([, value]) => value != null),
          ),
        }
      }
    }

    const extensions = profile.storageExtensions || {}
    snapshot.maxPublishedPhotos += asInt(extensions.extraPhotos)
    snapshot.maxStorageBytes += asInt(extensions.extraStorageBytes)
    return { profile, photographerRef, plan, quota: snapshot }
  }

  function watermarkSvg(width, height, brandName) {
    const safeBrand = nonEmptyString(brandName)
      .replace(/[&<>"']/g, "")
      .slice(0, 60) || "MASLIVE"
    const fontSize = Math.max(28, Math.round(Math.min(width, height) * 0.055))
    return Buffer.from(`
      <svg width="${width}" height="${height}" xmlns="http://www.w3.org/2000/svg">
        <style>
          .wm { fill: white; fill-opacity: .72; stroke: black; stroke-opacity: .35; stroke-width: 2px;
            font-family: Arial, sans-serif; font-size: ${fontSize}px; font-weight: 800; letter-spacing: 3px; }
        </style>
        <g transform="translate(${Math.round(width / 2)} ${Math.round(height / 2)}) rotate(-24)">
          <text class="wm" text-anchor="middle">MASLIVE • ${safeBrand}</text>
        </g>
        <rect x="12" y="12" width="${Math.max(0, width - 24)}" height="${Math.max(0, height - 24)}"
          fill="none" stroke="white" stroke-opacity=".42" stroke-width="3"/>
      </svg>
    `)
  }

  async function saveDerivative(bucket, path, buffer, metadata = {}) {
    const normalized = normalizeStoragePath(path)
    if (!normalized) throw new Error("Invalid derivative storage path")
    await bucket.file(normalized).save(buffer, {
      resumable: false,
      validation: "md5",
      metadata: {
        contentType: "image/webp",
        cacheControl: "private,max-age=31536000,immutable",
        metadata,
      },
    })
  }

  async function processPhotoDocument(photoId, data) {
    const photoRef = db.collection(COLLECTIONS.photos).doc(photoId)
    const originalPath = normalizeStoragePath(data.originalPath)
    if (!isStrictMarketplacePhotoPath({ ...data, photoId }, "original", originalPath)) {
      await photoRef.set({
        processingStatus: "failed",
        processingError: "invalid_original_path",
        isPublished: false,
        isForSale: false,
        updatedAt: serverTimestamp(),
      }, { merge: true })
      return false
    }

    const { profile, photographerRef, quota } = await readPlanContext(data.photographerId)
    if (profile.ownerUid !== data.ownerUid) {
      throw new HttpsError("permission-denied", "Photo owner does not match photographer profile")
    }

    const bucket = admin.storage().bucket()
    const originalFile = bucket.file(originalPath)
    const [exists] = await originalFile.exists()
    if (!exists) {
      await photoRef.set({
        processingStatus: "failed",
        processingError: "original_missing",
        updatedAt: serverTimestamp(),
      }, { merge: true })
      return false
    }

    const [fileMetadata] = await originalFile.getMetadata()
    const fileSize = asInt(fileMetadata.size, asInt(data.sizeBytes))
    const usedStorage = asInt(profile.storageUsedBytes)
    const usedPhotos = asInt(profile.publishedPhotoCount)

    if (fileSize <= 0 || fileSize > asInt(quota.maxFileBytes)) {
      await originalFile.delete({ ignoreNotFound: true })
      await photoRef.set({
        processingStatus: "rejected",
        processingError: "file_size_exceeds_plan",
        lifecycleStatus: "rejected",
        moderationStatus: "rejected",
        isPublished: false,
        isForSale: false,
        updatedAt: serverTimestamp(),
      }, { merge: true })
      return false
    }
    if (usedPhotos >= asInt(quota.maxPublishedPhotos) || usedStorage + fileSize > asInt(quota.maxStorageBytes)) {
      await originalFile.delete({ ignoreNotFound: true })
      await photoRef.set({
        processingStatus: "rejected",
        processingError: "quota_exceeded",
        lifecycleStatus: "rejected",
        moderationStatus: "rejected",
        isPublished: false,
        isForSale: false,
        updatedAt: serverTimestamp(),
      }, { merge: true })
      return false
    }

    await photoRef.set({ processingStatus: "processing", updatedAt: serverTimestamp() }, { merge: true })
    const [source] = await originalFile.download()
    const metadata = await sharp(source, { failOn: "error" }).metadata()
    const width = asInt(metadata.width)
    const height = asInt(metadata.height)
    const megapixels = (width * height) / 1000000
    if (!width || !height || megapixels > Number(quota.maxMegapixels || 0)) {
      await originalFile.delete({ ignoreNotFound: true })
      await photoRef.set({
        processingStatus: "rejected",
        processingError: "megapixels_exceed_plan",
        lifecycleStatus: "rejected",
        moderationStatus: "rejected",
        isPublished: false,
        isForSale: false,
        updatedAt: serverTimestamp(),
      }, { merge: true })
      return false
    }

    const base = sharp(source, { failOn: "error" }).rotate()
    const thumbnailBuffer = await base.clone()
      .resize({ width: 480, height: 480, fit: "cover", withoutEnlargement: true })
      .webp({ quality: 74, effort: 5 })
      .toBuffer()
    const previewBuffer = await base.clone()
      .resize({ width: 1600, height: 1600, fit: "inside", withoutEnlargement: true })
      .webp({ quality: 82, effort: 5 })
      .toBuffer()
    const previewMetadata = await sharp(previewBuffer).metadata()
    const wmWidth = asInt(previewMetadata.width, Math.min(width, 1600))
    const wmHeight = asInt(previewMetadata.height, Math.min(height, 1600))
    const watermarkedBuffer = await sharp(previewBuffer)
      .composite([{ input: watermarkSvg(wmWidth, wmHeight, profile.brandName), blend: "over" }])
      .webp({ quality: 82, effort: 5 })
      .toBuffer()

    const photo = { ...data, photoId }
    const previewPath = normalizeStoragePath(data.previewPath) || `${expectedPhotoPrefix(photo)}/previews/${photoId}.webp`
    const thumbnailPath = normalizeStoragePath(data.thumbnailPath) || `${expectedPhotoPrefix(photo)}/thumbs/${photoId}.webp`
    const watermarkedPath = normalizeStoragePath(data.watermarkedPath) || `${expectedPhotoPrefix(photo)}/watermarked/${photoId}.webp`

    const commonMetadata = {
      ownerUid: data.ownerUid,
      photographerId: data.photographerId,
      galleryId: data.galleryId,
      eventId: data.eventId,
      photoId,
      generatedBy: "media-marketplace-media",
    }
    await Promise.all([
      saveDerivative(bucket, thumbnailPath, thumbnailBuffer, commonMetadata),
      saveDerivative(bucket, previewPath, previewBuffer, commonMetadata),
      saveDerivative(bucket, watermarkedPath, watermarkedBuffer, commonMetadata),
    ])

    const retentionDays = Math.max(1, asInt(quota.retentionDays, 30))
    const purgeAt = admin.firestore.Timestamp.fromMillis(Date.now() + ((retentionDays + 30) * 86400000))
    const hash = crypto.createHash("sha256").update(source).digest("hex")
    const batch = db.batch()
    batch.set(photoRef, {
      previewPath,
      thumbnailPath,
      watermarkedPath,
      width,
      height,
      sizeBytes: fileSize,
      hash,
      processingStatus: "processed",
      processingError: null,
      moderationStatus: "pending",
      lifecycleStatus: "processing",
      unitPrice: 6.90,
      currency: "EUR",
      retentionDays,
      purgeAt,
      updatedAt: serverTimestamp(),
    }, { merge: true })
    batch.set(photographerRef, {
      storageUsedBytes: increment(fileSize),
      updatedAt: serverTimestamp(),
    }, { merge: true })
    batch.set(db.collection(COLLECTIONS.moderationQueue).doc(`photo_${photoId}`), {
      queueId: `photo_${photoId}`,
      kind: "media_photo",
      targetId: photoId,
      photographerId: data.photographerId,
      ownerUid: data.ownerUid,
      status: "pending",
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    }, { merge: true })
    await batch.commit()
    await refreshGalleryAndPhotographerCounters(data.galleryId, data.photographerId)
    return true
  }

  async function deletePhotoStorageFiles(photo) {
    const bucket = admin.storage().bucket()
    const paths = [photo.originalPath, photo.previewPath, photo.thumbnailPath, photo.watermarkedPath]
      .map(normalizeStoragePath)
      .filter(Boolean)
    await Promise.all(paths.map((path) => bucket.file(path).delete({ ignoreNotFound: true }).catch(() => null)))
  }

  async function refreshGalleryAndPhotographerCounters(galleryId, photographerId) {
    if (!nonEmptyString(galleryId) || !nonEmptyString(photographerId)) return
    const [galleryPhotosSnap, galleryPacksSnap, galleriesSnap, photographerPhotosSnap, photographerPacksSnap] = await Promise.all([
      db.collection(COLLECTIONS.photos).where("galleryId", "==", galleryId).get(),
      db.collection(COLLECTIONS.packs).where("galleryId", "==", galleryId).get(),
      db.collection(COLLECTIONS.galleries).where("photographerId", "==", photographerId).get(),
      db.collection(COLLECTIONS.photos).where("photographerId", "==", photographerId).get(),
      db.collection(COLLECTIONS.packs).where("photographerId", "==", photographerId).get(),
    ])
    const galleryPhotos = galleryPhotosSnap.docs.map((doc) => doc.data() || {})
    const galleryPacks = galleryPacksSnap.docs.map((doc) => doc.data() || {})
    const photographerPhotos = photographerPhotosSnap.docs.map((doc) => doc.data() || {})
    const photographerPacks = photographerPacksSnap.docs.map((doc) => doc.data() || {})
    const activeGalleries = galleriesSnap.docs.filter((doc) => {
      const status = nonEmptyString((doc.data() || {}).status)
      return status === "published" || status === "processing" || status === "draft"
    })
    const galleryPublishedPhotos = galleryPhotos.filter((photo) => photo.isPublished === true && photo.lifecycleStatus === "published")
    const galleryProcessedPhotos = galleryPhotos.filter((photo) => photo.processingStatus === "processed")
    const galleryActivePacks = galleryPacks.filter((pack) => pack.isActive === true)
    const photographerPublishedPhotos = photographerPhotos.filter((photo) => photo.isPublished === true && photo.lifecycleStatus === "published")
    const photographerProcessedPhotos = photographerPhotos.filter((photo) => photo.processingStatus === "processed")
    const photographerActivePacks = photographerPacks.filter((pack) => pack.isActive === true)
    const totalStorage = photographerProcessedPhotos.reduce((sum, photo) => sum + asInt(photo.sizeBytes), 0)
    const cover = galleryPublishedPhotos[0] || galleryProcessedPhotos[0] || null

    const batch = db.batch()
    batch.set(db.collection(COLLECTIONS.galleries).doc(galleryId), {
      photoCount: galleryPhotos.length,
      publishedPhotoCount: galleryPublishedPhotos.length,
      packCount: galleryActivePacks.length,
      coverPhotoId: cover?.photoId || null,
      coverUrl: cover?.thumbnailPath || null,
      updatedAt: serverTimestamp(),
    }, { merge: true })
    batch.set(db.collection(COLLECTIONS.photographers).doc(photographerId), {
      publishedPhotoCount: photographerPublishedPhotos.length,
      activeGalleryCount: activeGalleries.length,
      activePackCount: photographerActivePacks.length,
      storageUsedBytes: totalStorage,
      updatedAt: serverTimestamp(),
    }, { merge: true })
    await batch.commit()
  }

  async function writeDownloadLog({ buyerUid, entitlementId, photoId, variant, outcome, storagePath = null }) {
    await db.collection(COLLECTIONS.downloadLogs).add({
      buyerUid,
      entitlementId,
      photoId,
      variant,
      outcome,
      storagePath,
      createdAt: serverTimestamp(),
    })
  }

  const getMediaDownloadUrl = onCall(
    { region: "us-east1", cpu: 0.5, timeoutSeconds: 30, memory: "256MiB", maxInstances: 20 },
    async (request) => {
      const buyerUid = request.auth?.uid
      if (!buyerUid) throw new HttpsError("unauthenticated", "Authentication required")
      const entitlementId = nonEmptyString(request.data?.entitlementId)
      const photoId = nonEmptyString(request.data?.photoId)
      const variant = nonEmptyString(request.data?.variant || "original").toLowerCase()
      if (!entitlementId || !photoId) {
        throw new HttpsError("invalid-argument", "entitlementId and photoId are required")
      }

      const entitlementSnap = await db.collection(COLLECTIONS.entitlements).doc(entitlementId).get()
      if (!entitlementSnap.exists) throw new HttpsError("not-found", "Entitlement not found")
      const entitlement = entitlementSnap.data() || {}
      if (entitlement.buyerUid !== buyerUid) {
        await writeDownloadLog({ buyerUid, entitlementId, photoId, variant, outcome: "denied_not_owner" })
        throw new HttpsError("permission-denied", "This entitlement does not belong to you")
      }
      const entitledPhotoIds = Array.isArray(entitlement.photoIds) ? entitlement.photoIds : []
      if (!entitledPhotoIds.includes(photoId)) {
        await writeDownloadLog({ buyerUid, entitlementId, photoId, variant, outcome: "denied_photo_not_entitled" })
        throw new HttpsError("permission-denied", "This photo is not included in the entitlement")
      }
      const allowedVariants = Array.isArray(entitlement.allowedVariants)
        ? entitlement.allowedVariants.map((value) => nonEmptyString(value).toLowerCase())
        : ["original", "hd", "preview", "web"]
      if (!allowedVariants.includes(variant)) {
        await writeDownloadLog({ buyerUid, entitlementId, photoId, variant, outcome: "denied_variant_not_entitled" })
        throw new HttpsError("permission-denied", "This quality variant is not included in the entitlement")
      }

      const photoSnap = await db.collection(COLLECTIONS.photos).doc(photoId).get()
      if (!photoSnap.exists) throw new HttpsError("not-found", "Photo not found")
      const photo = { photoId, ...(photoSnap.data() || {}) }
      const storagePath = storagePathForVariant(photo, variant)
      if (!isStrictMarketplacePhotoPath(photo, variant, storagePath)) {
        await writeDownloadLog({ buyerUid, entitlementId, photoId, variant, outcome: "denied_invalid_storage_path", storagePath })
        throw new HttpsError("permission-denied", "Storage path is not allowed for this entitlement")
      }

      const expiresAtMs = Date.now() + (15 * 60 * 1000)
      const [url] = await admin.storage().bucket().file(storagePath).getSignedUrl({
        action: "read",
        expires: expiresAtMs,
        responseDisposition: `attachment; filename="${nonEmptyString(photo.downloadFileName) || `maslive_${photoId}.jpg`}"`,
      })
      await writeDownloadLog({ buyerUid, entitlementId, photoId, variant, outcome: "granted", storagePath })
      return { url, expiresAt: new Date(expiresAtMs).toISOString(), variant, photoId }
    },
  )

  const syncMediaPhotoOnCreate = onDocumentCreated(
    { document: "media_photos/{photoId}", region: "us-east1", cpu: 0.5, timeoutSeconds: 300, memory: "1GiB", maxInstances: 10 },
    async (event) => {
      const snapshot = event.data
      if (!snapshot) return
      const data = snapshot.data() || {}
      try {
        await processPhotoDocument(event.params.photoId, data)
      } catch (error) {
        await snapshot.ref.set({
          processingStatus: "failed",
          processingError: nonEmptyString(error?.message) || "processing_failed",
          updatedAt: serverTimestamp(),
        }, { merge: true })
        throw error
      }
    },
  )

  const syncMediaPhotoOnUpdate = onDocumentUpdated(
    { document: "media_photos/{photoId}", region: "us-east1", timeoutSeconds: 120, memory: "512MiB", maxInstances: 20 },
    async (event) => {
      const before = event.data?.before?.data() || {}
      const after = event.data?.after?.data() || {}
      const photoId = event.params.photoId
      if (before.moderationStatus !== "approved" && after.moderationStatus === "approved") {
        await event.data.after.ref.set({
          isPublished: true,
          isForSale: true,
          visibility: "public",
          lifecycleStatus: "published",
          publishedAt: serverTimestamp(),
          updatedAt: serverTimestamp(),
        }, { merge: true })
      }
      await refreshGalleryAndPhotographerCounters(after.galleryId, after.photographerId)
      await db.collection(COLLECTIONS.moderationQueue).doc(`photo_${photoId}`).set({
        status: nonEmptyString(after.moderationStatus) || "pending",
        updatedAt: serverTimestamp(),
      }, { merge: true })
    },
  )

  const syncMediaPhotoOnDelete = onDocumentDeleted(
    { document: "media_photos/{photoId}", region: "us-east1", timeoutSeconds: 120, memory: "512MiB", maxInstances: 20 },
    async (event) => {
      const data = event.data?.data() || {}
      await deletePhotoStorageFiles(data)
      await refreshGalleryAndPhotographerCounters(data.galleryId, data.photographerId)
      await db.collection(COLLECTIONS.moderationQueue).doc(`photo_${event.params.photoId}`).delete().catch(() => null)
    },
  )

  const syncMediaPackOnCreate = onDocumentCreated(
    { document: "media_packs/{packId}", region: "us-east1" },
    async (event) => {
      const data = event.data?.data() || {}
      await refreshGalleryAndPhotographerCounters(data.galleryId, data.photographerId)
    },
  )

  const syncMediaPackOnUpdate = onDocumentUpdated(
    { document: "media_packs/{packId}", region: "us-east1" },
    async (event) => {
      const data = event.data?.after?.data() || {}
      await refreshGalleryAndPhotographerCounters(data.galleryId, data.photographerId)
    },
  )

  const syncMediaPackOnDelete = onDocumentDeleted(
    { document: "media_packs/{packId}", region: "us-east1" },
    async (event) => {
      const data = event.data?.data() || {}
      await refreshGalleryAndPhotographerCounters(data.galleryId, data.photographerId)
    },
  )

  return {
    getMediaDownloadUrl,
    syncMediaPhotoOnCreate,
    syncMediaPhotoOnUpdate,
    syncMediaPhotoOnDelete,
    syncMediaPackOnCreate,
    syncMediaPackOnUpdate,
    syncMediaPackOnDelete,
    isOwnerOrAdmin,
  }
}
