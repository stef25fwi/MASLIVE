const test = require("node:test")
const assert = require("node:assert/strict")

const createPoiImageWebpHandlers = require("../src/poi-image-webp")

test("getPlacePhotoUploadForWebpConversion targets only non-webp POI originals", () => {
  const helper = createPoiImageWebpHandlers.__test.getPlacePhotoUploadForWebpConversion

  assert.deepEqual(
    helper({
      name: "places/poi_project_1/images/img_123/original.jpg",
      contentType: "image/jpeg",
      metadata: { firebaseStorageDownloadTokens: "abc" },
    }),
    {
      path: "places/poi_project_1/images/img_123/original.jpg",
      parentId: "poi_project_1",
      imageId: "img_123",
      extension: "jpg",
      contentType: "image/jpeg",
      customMetadata: { firebaseStorageDownloadTokens: "abc" },
    },
  )

  assert.equal(
    helper({
      name: "places/poi_project_1/images/img_123/original.webp",
      contentType: "image/webp",
    }),
    null,
  )

  assert.equal(
    helper({
      name: "shops/global/logo/original.png",
      contentType: "image/png",
    }),
    null,
  )
})

test("convertPlacePhotoUploadToWebp rewrites the storage object in place and updates image_assets metadata", async () => {
  const saveCalls = []
  const dbState = new Map([
    ["image_assets/img_123", { metadata: { mimeType: "image/jpeg" } }],
  ])

  const admin = {
    storage() {
      return {
        bucket(bucketName) {
          return {
            file(objectPath) {
              return {
                async download() {
                  return [Buffer.from("raw-image")]
                },
                async save(buffer, options) {
                  saveCalls.push({ bucketName, objectPath, buffer, options })
                },
              }
            },
          }
        },
      }
    },
    firestore: {
      FieldValue: {
        serverTimestamp: () => "__ts__",
      },
    },
  }

  const db = {
    collection(name) {
      return {
        doc(id) {
          const key = `${name}/${id}`
          return {
            async get() {
              const value = dbState.get(key)
              return {
                exists: value != null,
                data: () => value,
              }
            },
            async set(value, options = {}) {
              const previous = dbState.get(key) || {}
              if (options.merge) {
                dbState.set(key, {
                  ...previous,
                  ...value,
                  metadata: {
                    ...(previous.metadata || {}),
                    ...(value.metadata || {}),
                  },
                })
                return
              }
              dbState.set(key, value)
            },
          }
        },
      }
    },
  }

  const logger = {
    info() {},
    warn() {},
    error(message, meta) {
      throw new Error(`${message}: ${JSON.stringify(meta)}`)
    },
  }

  const sharpCalls = []
  const sharp = (buffer, options) => {
    sharpCalls.push({ buffer: buffer.toString(), options })
    const chain = {
      rotate() {
        return chain
      },
      webp(webpOptions) {
        sharpCalls.push({ webpOptions })
        return chain
      },
      async toBuffer() {
        return Buffer.from("converted-webp")
      },
    }
    return chain
  }

  const handlers = createPoiImageWebpHandlers({
    admin,
    db,
    onObjectFinalized: (_options, handler) => handler,
    logger,
    sharp,
  })

  await handlers.convertPlacePhotoUploadToWebp({
    data: {
      bucket: "maslive.appspot.com",
      name: "places/poi_project_1/images/img_123/original.png",
      contentType: "image/png",
      cacheControl: "public,max-age=3600",
      metadata: {
        firebaseStorageDownloadTokens: "token-1",
      },
    },
  })

  assert.equal(saveCalls.length, 1)
  assert.equal(saveCalls[0].bucketName, "maslive.appspot.com")
  assert.equal(saveCalls[0].objectPath, "places/poi_project_1/images/img_123/original.png")
  assert.equal(saveCalls[0].options.metadata.contentType, "image/webp")
  assert.equal(saveCalls[0].options.metadata.metadata.firebaseStorageDownloadTokens, "token-1")
  assert.equal(saveCalls[0].options.metadata.metadata.masliveWebpConverted, "true")
  assert.equal(saveCalls[0].options.metadata.metadata.masliveOriginalExtension, "png")
  assert.equal(dbState.get("image_assets/img_123").metadata.mimeType, "image/webp")
  assert.equal(sharpCalls[0].buffer, "raw-image")
})