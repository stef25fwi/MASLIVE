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
    mediaEntitlements: "media_entitlements",
    mediaDownloadLogs: "media_download_logs",
    adminModerationQueue: "admin_moderation_queue",
    payoutLedger: "payout_ledger",
  }

  const DOWNLOAD_VARIANTS = new Set(["original", "preview", "thumbnail", "watermarked"])
  const VARIANT_DIRECTORY_BY_NAME = {
    original: "originals",
    preview: "previews",
    thumbnail: "thumbs",
    watermarked: "watermarked",
  }
  const ARCHIVED_GALLERY_STATUS = "archived"

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
    return typeof value === "string" && value.trim().length > 0 ? value.trim() : ""
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

  function normalizeDownloadVariant(value) {
    const variant = nonEmptyString(value) || "original"
    if (!DOWNLOAD_VARIANTS.has(variant)) {
      throw new HttpsError("invalid-argument", `Unsupported media variant: ${variant}`)
    }
    return variant
  }

  function getAllowedDownloadVariants(entitlement) {
    const explicitVariants = uniqueStrings(entitlement?.allowedVariants)
      .filter((variant) => DOWNLOAD_VARIANTS.has(variant))

    if (explicitVariants.length > 0) {
      return explicitVariants
    }

    return ["original"]
  }

  function buildDownloadPath(photo, variant) {
    switch (variant) {
      case "preview":
        return photo.previewPath || ""
      case "thumbnail":
        return photo.thumbnailPath || ""
      case "watermarked":
        return photo.watermarkedPath || ""
      case "original":
      default:
        return photo.originalPath || ""
    }
  }

  function normalizeStoragePath(path) {
    const normalized = nonEmptyString(path).replace(/\\/g, "/")
    if (!normalized) return ""
    if (normalized.startsWith("/") || normalized.includes("..") || normalized.includes("//")) {
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

    const expectedPrefix = `photographers/${photographerId}/events/${eventId}/galleries/${galleryId}/${variantDirectory}/`
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
      expires: Date.now() + (15 * 60 * 1000),
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
    const ipAddress = nonEmptyString(rawRequest?.headers?.["x-forwarded-for"]) ||
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
    const publishedPhotoDocs = photosSnapshot.docs.filter((doc) => doc.data()?.isPublished === true)
    const publishedPhotoCount = publishedPhotoDocs.length
    const activePackDocs = packsSnapshot.docs.filter((doc) => doc.data()?.isActive === true)
    const packCount = activePackDocs.length
    const coverDoc = publishedPhotoDocs[0] || photosSnapshot.docs[0] || null
    const coverData = coverDoc?.data() || null

    await db.collection(COLLECTIONS.mediaGalleries).doc(galleryId).set(
      {
        photoCount,
        publishedPhotoCount,
        packCount,
        coverPhotoId: coverDoc?.id || null,
        coverUrl: coverData?.thumbnailPath || coverData?.previewPath || null,
        updatedAt: serverTimestamp(),
      },
      { merge: true }
    )
  }

  async function recalculatePhotographerCounters(photographerId) {
    if (!photographerId) return

    const [photosSnapshot, galleriesSnapshot, packsSnapshot, payoutSnapshot] = await Promise.all([
      db.collection(COLLECTIONS.mediaPhotos).where("photographerId", "==", photographerId).get(),
      db.collection(COLLECTIONS.mediaGalleries).where("photographerId", "==", photographerId).get(),
      db.collection(COLLECTIONS.mediaPacks).where("photographerId", "==", photographerId).get(),
      db.collection(COLLECTIONS.payoutLedger).where("photographerId", "==", photographerId).get(),
    ])

    const publishedPhotoCount = photosSnapshot.docs.filter((doc) => doc.data()?.isPublished === true).length
    const activeGalleryCount = galleriesSnapshot.docs.filter((doc) => doc.data()?.status !== ARCHIVED_GALLERY_STATUS).length
    const activePackCount = packsSnapshot.docs.filter((doc) => doc.data()?.isActive === true).length
    const storageUsedBytes = photosSnapshot.docs.reduce((sum, doc) => {
      return sum + toInteger(doc.data()?.sizeBytes, 0)
    }, 0)
    const salesCount = payoutSnapshot.docs.length
    const totalRevenueGross = payoutSnapshot.docs.reduce((sum, doc) => {
      return sum + toNumber(doc.data()?.grossAmount, 0)
    }, 0)
    const totalRevenueNet = payoutSnapshot.docs.reduce((sum, doc) => {
      return sum + toNumber(doc.data()?.netAmount, 0)
    }, 0)

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

    const queueRef = db.collection(COLLECTIONS.adminModerationQueue).doc(`photo_${photoId}`)
    const moderationStatus = nonEmptyString(photoData.moderationStatus) || "pending"

    if (moderationStatus === "approved") {
      await queueRef.delete().catch(() => null)
      return
    }

    const reviewedAt = moderationStatus === "rejected" ? serverTimestamp() : null
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
        reviewedAt,
        createdAt: serverTimestamp(),
      },
      { merge: true }
    )
  }

  async function syncPhotoDerivedState(photoId, photoData) {
    if (!photoId || !photoData) return

    const lifecycleStatus = nonEmptyString(photoData.lifecycleStatus) || "draft"
    const moderationStatus = nonEmptyString(photoData.moderationStatus) || "pending"
    const shouldBePublished = moderationStatus === "approved" && lifecycleStatus === "published"
    const shouldBeForSale = shouldBePublished && photoData.isForSale === true

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
    const photographerIds = uniqueStrings([beforeData?.photographerId, data?.photographerId])

    await Promise.all([
      ...galleryIds.map((galleryId) => recalculateGalleryCounters(galleryId)),
      ...photographerIds.map((photographerId) => recalculatePhotographerCounters(photographerId)),
    ])
  }

  async function handlePackWriteAfter(data, beforeData) {
    const galleryIds = uniqueStrings([beforeData?.galleryId, data?.galleryId])
    const photographerIds = uniqueStrings([beforeData?.photographerId, data?.photographerId])

    await Promise.all([
      ...galleryIds.map((galleryId) => recalculateGalleryCounters(galleryId)),
      ...photographerIds.map((photographerId) => recalculatePhotographerCounters(photographerId)),
    ])
  }

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
        throw new HttpsError("invalid-argument", "entitlementId and assetId are required")
      }

      const entitlementSnapshot = await db.collection(COLLECTIONS.mediaEntitlements).doc(entitlementId).get()
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
        throw new HttpsError("permission-denied", "This entitlement does not belong to you")
      }

      if (entitlement.isActive !== true) {
        await logDownloadAttempt({
          buyerUid,
          entitlementId,
          assetId,
          assetType: entitlement.assetType || "photo",
          outcome: "denied_inactive",
          request,
        })
        throw new HttpsError("failed-precondition", "Entitlement inactive")
      }

      if (entitlement.expiresAt && entitlement.expiresAt.toDate && entitlement.expiresAt.toDate() < new Date()) {
        await logDownloadAttempt({
          buyerUid,
          entitlementId,
          assetId,
          assetType: entitlement.assetType || "photo",
          outcome: "denied_expired",
          request,
        })
        throw new HttpsError("failed-precondition", "Entitlement expired")
      }

      const downloadLimit = entitlement.downloadLimit == null ? null : toInteger(entitlement.downloadLimit, 0)
      const downloadCount = toInteger(entitlement.downloadCount, 0)
      if (downloadLimit != null && downloadCount >= downloadLimit) {
        await logDownloadAttempt({
          buyerUid,
          entitlementId,
          assetId,
          assetType: entitlement.assetType || "photo",
          outcome: "denied_limit_reached",
          request,
        })
        throw new HttpsError("failed-precondition", "Download limit reached")
      }

      if (entitlement.assetId !== assetId) {
        await logDownloadAttempt({
          buyerUid,
          entitlementId,
          assetId,
          assetType: entitlement.assetType || "photo",
          outcome: "denied_asset_mismatch",
          request,
        })
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
        throw new HttpsError("permission-denied", "Requested media variant is not covered by this entitlement")
      }

      let targetPhotoId = assetId
      if (entitlement.assetType === "pack") {
        targetPhotoId = requestedPhotoId
        if (!targetPhotoId || !Array.isArray(entitlement.photoIds) || !entitlement.photoIds.includes(targetPhotoId)) {
          await logDownloadAttempt({
            buyerUid,
            entitlementId,
            assetId,
            assetType: entitlement.assetType,
            photoId: requestedPhotoId || null,
            outcome: "denied_photo_not_entitled",
            request,
          })
          throw new HttpsError("permission-denied", "Requested photo is not covered by this pack")
        }
      }

      const photo = await getPhotoById(targetPhotoId)
      if (!photo) {
        await logDownloadAttempt({
          buyerUid,
          entitlementId,
          assetId,
          assetType: entitlement.assetType || "photo",
          photoId: targetPhotoId,
          outcome: "denied_photo_missing",
          request,
        })
        throw new HttpsError("not-found", "Photo not found")
      }

      const downloadPath = buildDownloadPath(photo, variant)
      if (!downloadPath) {
        await logDownloadAttempt({
          buyerUid,
          entitlementId,
          assetId,
          assetType: entitlement.assetType || "photo",
          photoId: targetPhotoId,
          outcome: "denied_variant_unavailable",
          request,
          metadata: { variant, allowedVariants },
        })
        throw new HttpsError("failed-precondition", "Requested media variant is not available")
      }

      const normalizedDownloadPath = normalizeStoragePath(downloadPath)
      if (!isStrictMarketplacePhotoPath(photo, variant, normalizedDownloadPath)) {
        await logDownloadAttempt({
          buyerUid,
          entitlementId,
          assetId,
          assetType: entitlement.assetType || "photo",
          photoId: targetPhotoId,
          outcome: "denied_invalid_storage_path",
          request,
          metadata: {
            variant,
            requestedPath: downloadPath,
          },
        })
        throw new HttpsError("permission-denied", "Storage path is not allowed for this entitlement")
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
        db.collection(COLLECTIONS.adminModerationQueue).doc(`photo_${photoId}`).delete().catch(() => null),
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
      if (!data) return
      await handlePackWriteAfter(data, null)
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
      if (!afterData) return
      await handlePackWriteAfter(afterData, beforeData)
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

  return {
    getMediaDownloadUrl,
    syncMediaPhotoOnCreate,
    syncMediaPhotoOnUpdate,
    syncMediaPhotoOnDelete,
    syncMediaPackOnCreate,
    syncMediaPackOnUpdate,
    syncMediaPackOnDelete,
  }
}