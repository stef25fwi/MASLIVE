const PLACE_PHOTO_ORIGINAL_RE = /^places\/([^/]+)\/images\/([^/]+)\/original(?:\.([a-z0-9]+))?$/i

function normalizeCustomMetadata(value) {
  if (!value || typeof value !== "object") return {}
  const out = {}
  for (const [key, entry] of Object.entries(value)) {
    if (entry == null) continue
    out[key] = String(entry)
  }
  return out
}

function getPlacePhotoUploadForWebpConversion(object) {
  const name = typeof object?.name === "string" ? object.name.trim() : ""
  if (!name) return null

  const match = PLACE_PHOTO_ORIGINAL_RE.exec(name)
  if (!match) return null

  const contentType = String(object?.contentType || "").trim().toLowerCase()
  if (!contentType.startsWith("image/")) return null

  const customMetadata = normalizeCustomMetadata(object?.metadata)
  if (customMetadata.masliveWebpConverted === "true") return null

  const extension = String(match[3] || "").trim().toLowerCase()
  if (extension === "webp" || contentType === "image/webp") return null

  return {
    path: name,
    parentId: match[1],
    imageId: match[2],
    extension: extension || "jpg",
    contentType,
    customMetadata,
  }
}

async function maybeMarkImageAssetAsWebp({ admin, db, imageId, objectPath, originalContentType, originalExtension, logger }) {
  if (!db || !imageId) return

  try {
    const ref = db.collection("image_assets").doc(imageId)
    const snap = await ref.get()
    if (!snap.exists) return

    await ref.set(
      {
        metadata: {
          mimeType: "image/webp",
        },
        backendTranscode: {
          format: "webp",
          objectPath,
          originalContentType,
          originalExtension,
          convertedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    )
  } catch (error) {
    logger.warn("Failed to mark image asset as backend-transcoded webp", {
      imageId,
      objectPath,
      code: error?.code || null,
      message: error?.message || String(error),
    })
  }
}

function createPoiImageWebpHandlers({ admin, db, onObjectFinalized, logger, sharp }) {
  if (!admin) throw new Error("admin is required")
  if (!onObjectFinalized) throw new Error("onObjectFinalized is required")
  if (!logger) throw new Error("logger is required")
  if (!sharp) throw new Error("sharp is required")

  const convertPlacePhotoUploadToWebp = onObjectFinalized(
    {
      region: "us-east1",
      timeoutSeconds: 120,
      memory: "1GiB",
    },
    async (event) => {
      const object = event?.data || {}
      const target = getPlacePhotoUploadForWebpConversion(object)
      if (!target) return null

      const bucketName = typeof object.bucket === "string" ? object.bucket.trim() : ""
      if (!bucketName) {
        logger.warn("Skipping POI WebP conversion: missing bucket", {
          path: object.name || null,
        })
        return null
      }

      const file = admin.storage().bucket(bucketName).file(target.path)

      try {
        const [inputBuffer] = await file.download()
        const outputBuffer = await sharp(inputBuffer, {
          animated: true,
          limitInputPixels: false,
        })
          .rotate()
          .webp({ quality: 88 })
          .toBuffer()

        const metadata = {
          ...(object.cacheControl ? { cacheControl: object.cacheControl } : {}),
          ...(object.contentDisposition ? { contentDisposition: object.contentDisposition } : {}),
          ...(object.contentEncoding ? { contentEncoding: object.contentEncoding } : {}),
          ...(object.contentLanguage ? { contentLanguage: object.contentLanguage } : {}),
          contentType: "image/webp",
          metadata: {
            ...target.customMetadata,
            masliveWebpConverted: "true",
            masliveOriginalExtension: target.extension,
            masliveOriginalContentType: target.contentType,
          },
        }

        await file.save(outputBuffer, {
          resumable: false,
          metadata,
        })

        await maybeMarkImageAssetAsWebp({
          admin,
          db,
          imageId: target.imageId,
          objectPath: target.path,
          originalContentType: target.contentType,
          originalExtension: target.extension,
          logger,
        })

        logger.info("Converted POI upload to WebP in place", {
          bucket: bucketName,
          path: target.path,
          imageId: target.imageId,
          originalContentType: target.contentType,
          originalExtension: target.extension,
          outputBytes: outputBuffer.length,
        })
      } catch (error) {
        logger.error("POI WebP conversion failed", {
          bucket: bucketName,
          path: target.path,
          imageId: target.imageId,
          originalContentType: target.contentType,
          originalExtension: target.extension,
          message: error?.message || String(error),
        })
      }

      return null
    },
  )

  return {
    convertPlacePhotoUploadToWebp,
  }
}

module.exports = createPoiImageWebpHandlers
module.exports.__test = {
  getPlacePhotoUploadForWebpConversion,
  normalizeCustomMetadata,
}