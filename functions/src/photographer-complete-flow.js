"use strict"

const crypto = require("node:crypto")

module.exports = function createPhotographerCompleteFlow({
  admin,
  db,
  onCall,
  onRequest,
  onDocumentUpdated,
  HttpsError,
}) {
  const region = "us-east1"
  const serverTimestamp = () => admin.firestore.FieldValue.serverTimestamp()
  const timestampFromMillis = (value) => admin.firestore.Timestamp.fromMillis(value)

  const collections = Object.freeze({
    photographers: "photographers",
    subscriptions: "photographer_subscriptions",
    galleries: "media_galleries",
    photos: "media_photos",
    packs: "media_packs",
    entitlements: "media_entitlements",
    orders: "orders",
    payouts: "payout_ledger",
    apiKeys: "photographer_api_keys",
    importJobs: "photographer_import_jobs",
    importSessions: "photographer_import_sessions",
    audit: "photographer_audit_log",
    marketMap: "marketMap",
  })

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
    const parsed = Date.parse(value || "")
    return Number.isFinite(parsed) ? parsed : 0
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

  async function ownedProfileFromAuth(auth, photographerId) {
    if (!auth?.uid) throw new HttpsError("unauthenticated", "Authentication required")
    const id = text(photographerId, 160)
    if (!id) throw new HttpsError("invalid-argument", "photographerId is required")
    const ref = db.collection(collections.photographers).doc(id)
    const snapshot = await ref.get()
    if (!snapshot.exists) throw new HttpsError("not-found", "Photographer profile not found")
    const profile = snapshot.data() || {}
    const claims = auth.token || {}
    const adminRole = claims.admin === true || claims.isAdmin === true || ["admin", "superadmin", "super-admin"].includes(claims.role)
    if (!adminRole && text(profile.ownerUid, 160) !== auth.uid) {
      throw new HttpsError("permission-denied", "Photographer profile does not belong to you")
    }
    return { id, ref, profile, ownerUid: text(profile.ownerUid, 160) }
  }

  async function ownedProfile(request) {
    return ownedProfileFromAuth(request.auth, request.data?.photographerId)
  }

  async function writeAudit({ photographerId, ownerUid, action, targetId = null, details = {} }) {
    await db.collection(collections.audit).add({
      photographerId,
      ownerUid,
      action: text(action, 120),
      targetId: targetId ? text(targetId, 200) : null,
      details,
      createdAt: serverTimestamp(),
    })
  }

  async function queryArrayContains(collection, field, value) {
    try {
      return await db.collection(collection).where(field, "array-contains", value).get()
    } catch (_) {
      return { docs: [] }
    }
  }

  async function loadOrders(photographerId) {
    const [modern, legacy] = await Promise.all([
      queryArrayContains(collections.orders, "photographerIds", photographerId),
      queryArrayContains(collections.orders, "sellerIds", photographerId),
    ])
    const seen = new Set()
    const orders = []
    for (const doc of [...modern.docs, ...legacy.docs]) {
      if (seen.has(doc.id)) continue
      seen.add(doc.id)
      const data = doc.data() || {}
      const items = list(data.items).filter((item) => text(item?.photographerId, 160) === photographerId)
      orders.push({ id: doc.id, ...data, items })
    }
    orders.sort((a, b) => timestampMs(b.createdAt) - timestampMs(a.createdAt))
    return orders
  }

  const getPhotographerAdvancedDashboard = onCall(
    { region, timeoutSeconds: 60, memory: "512MiB" },
    async (request) => {
      const context = await ownedProfile(request)
      const photographerId = context.id
      const eventId = text(request.data?.eventId, 200)
      const [subscriptions, galleries, photos, orders, payouts] = await Promise.all([
        db.collection(collections.subscriptions).where("photographerId", "==", photographerId).get(),
        db.collection(collections.galleries).where("photographerId", "==", photographerId).get(),
        db.collection(collections.photos).where("photographerId", "==", photographerId).get(),
        loadOrders(photographerId),
        db.collection(collections.payouts).where("photographerId", "==", photographerId).get(),
      ])

      const now = Date.now()
      const monthStart = new Date()
      monthStart.setUTCDate(1)
      monthStart.setUTCHours(0, 0, 0, 0)
      const monthStartMs = monthStart.getTime()
      const paidOrders = orders.filter((order) => ["paid", "succeeded"].includes(text(order.paymentStatus, 40).toLowerCase()))
      const monthOrders = paidOrders.filter((order) => timestampMs(order.paidAt || order.createdAt) >= monthStartMs)
      const lineNet = (order) => {
        const matching = list(order.items).filter((item) => text(item?.photographerId, 160) === photographerId)
        if (matching.length) return matching.reduce((sum, item) => sum + number(item.photographerAmount, number(item.lineSubtotal)), 0)
        return number(order.photographerNetTotal, number(order.photographerAmount))
      }

      const payoutRows = payouts.docs.map((doc) => ({ id: doc.id, ...(doc.data() || {}) }))
      const amountFor = (statuses) => payoutRows
        .filter((row) => statuses.includes(text(row.status, 80).toLowerCase()))
        .reduce((sum, row) => sum + number(row.net, number(row.photographerAmount)), 0)

      const pendingPhotos = photos.docs.filter((doc) => {
        const photo = doc.data() || {}
        return ["queued", "processing"].includes(text(photo.processingStatus, 40)) || text(photo.moderationStatus, 40) === "pending"
      }).length

      const expiryWarnings = galleries.docs
        .map((doc) => ({ id: doc.id, ...(doc.data() || {}) }))
        .filter((gallery) => {
          const expiry = timestampMs(gallery.expiresAt || gallery.archiveAt)
          return expiry > now && expiry <= now + (14 * 86400000)
        })
        .sort((a, b) => timestampMs(a.expiresAt || a.archiveAt) - timestampMs(b.expiresAt || b.archiveAt))
        .map((gallery) => ({
          galleryId: gallery.id,
          title: text(gallery.title, 160),
          expiresAt: new Date(timestampMs(gallery.expiresAt || gallery.archiveAt)).toISOString(),
        }))

      const activeSubscription = subscriptions.docs
        .map((doc) => ({ id: doc.id, ...(doc.data() || {}) }))
        .filter((subscription) => ["active", "trialing", "past_due", "incomplete"].includes(text(subscription.status, 40)))
        .sort((a, b) => timestampMs(b.updatedAt) - timestampMs(a.updatedAt))[0] || null

      let circuitsWithoutGallery = []
      if (eventId) {
        try {
          const circuitSnapshot = await db.collection(collections.marketMap).where("eventId", "==", eventId).get()
          const covered = new Set(galleries.docs.map((doc) => text((doc.data() || {}).linkedCircuitId, 200)).filter(Boolean))
          circuitsWithoutGallery = circuitSnapshot.docs
            .map((doc) => ({
              circuitId: text((doc.data() || {}).circuitId, 200) || doc.id,
              name: text((doc.data() || {}).name, 160) || text((doc.data() || {}).title, 160) || doc.id,
            }))
            .filter((circuit) => !covered.has(circuit.circuitId))
        } catch (_) {
          circuitsWithoutGallery = []
        }
      }

      return {
        monthlySalesCount: monthOrders.length,
        monthlyRevenueGross: monthOrders.reduce((sum, order) => sum + number(order.total), 0),
        monthlyRevenueNet: monthOrders.reduce((sum, order) => sum + lineNet(order), 0),
        totalSalesCount: paidOrders.length,
        totalRevenueNet: paidOrders.reduce((sum, order) => sum + lineNet(order), 0),
        revenueAvailable: amountFor(["pending_transfer", "available"]),
        revenuePending: amountFor(["processing", "pending", "blocked_connect_required", "transfer_failed"]),
        revenueTransferred: amountFor(["transferred", "paid"]),
        pendingPhotos,
        activeGalleryCount: galleries.docs.filter((doc) => ["draft", "processing", "published"].includes(text((doc.data() || {}).status, 40))).length,
        expiryWarnings,
        circuitsWithoutGallery,
        nextRenewalAt: activeSubscription?.currentPeriodEnd
          ? new Date(timestampMs(activeSubscription.currentPeriodEnd)).toISOString()
          : null,
        cancelAtPeriodEnd: activeSubscription?.cancelAtPeriodEnd === true,
      }
    },
  )

  function sanitizedPeople(values, max) {
    return list(values).slice(0, max).map((value) => ({
      id: text(value?.id, 120) || crypto.randomUUID(),
      name: text(value?.name, 120),
      email: text(value?.email, 200).toLowerCase(),
      role: text(value?.role, 60) || "editor",
      status: text(value?.status, 40) || "invited",
    })).filter((value) => value.name || value.email)
  }

  function sanitizedBrands(values, max) {
    return list(values).slice(0, max).map((value) => ({
      id: text(value?.id, 120) || crypto.randomUUID(),
      name: text(value?.name, 120),
      logoUrl: text(value?.logoUrl, 1000),
      accentColor: text(value?.accentColor, 20),
      description: text(value?.description, 500),
      domain: text(value?.domain, 300),
    })).filter((value) => value.name)
  }

  function sanitizedPromotions(values, max) {
    return list(values).slice(0, max).map((value) => ({
      id: text(value?.id, 120) || crypto.randomUUID(),
      code: text(value?.code, 40).toUpperCase(),
      percentOff: Math.max(0, Math.min(90, number(value?.percentOff))),
      amountOff: Math.max(0, number(value?.amountOff)),
      active: value?.active !== false,
      startsAt: text(value?.startsAt, 60) || null,
      endsAt: text(value?.endsAt, 60) || null,
      galleryIds: unique(list(value?.galleryIds).map((item) => text(item, 200))).slice(0, 100),
    })).filter((value) => value.code)
  }

  const savePhotographerWorkspaceConfig = onCall(
    { region, timeoutSeconds: 30 },
    async (request) => {
      const context = await ownedProfile(request)
      const limits = planLimits(context.profile.activePlanId)
      const config = request.data?.config || {}
      const workspaceConfig = {
        collaborators: sanitizedPeople(config.collaborators, limits.collaborators),
        brands: sanitizedBrands(config.brands, limits.brands),
        promotions: sanitizedPromotions(config.promotions, limits.promotions),
        storefront: {
          headline: text(config.storefront?.headline, 160),
          description: text(config.storefront?.description, 1000),
          accentColor: text(config.storefront?.accentColor, 20),
          layout: ["grid", "editorial", "minimal"].includes(text(config.storefront?.layout, 30))
            ? text(config.storefront.layout, 30)
            : "grid",
          showPhotographerName: config.storefront?.showPhotographerName !== false,
          showEventContext: config.storefront?.showEventContext !== false,
          customWatermarkText: limits.customWatermark ? text(config.storefront?.customWatermarkText, 80) : "",
        },
        faceGroupingConsent: config.faceGroupingConsent === true,
        faceGroupingConsentAt: config.faceGroupingConsent === true ? serverTimestamp() : null,
        updatedAt: serverTimestamp(),
      }
      await context.ref.set({ workspaceConfig, updatedAt: serverTimestamp() }, { merge: true })
      await writeAudit({
        photographerId: context.id,
        ownerUid: context.ownerUid,
        action: "workspace_config_updated",
        details: {
          collaborators: workspaceConfig.collaborators.length,
          brands: workspaceConfig.brands.length,
          promotions: workspaceConfig.promotions.length,
        },
      })
      return { success: true, config: workspaceConfig, limits }
    },
  )

  const getPhotographerWorkspaceConfig = onCall(
    { region, timeoutSeconds: 30 },
    async (request) => {
      const context = await ownedProfile(request)
      return {
        config: context.profile.workspaceConfig || {},
        limits: planLimits(context.profile.activePlanId),
      }
    },
  )

  const createPhotographerApiKey = onCall(
    { region, timeoutSeconds: 30 },
    async (request) => {
      const context = await ownedProfile(request)
      const limits = planLimits(context.profile.activePlanId)
      if (!limits.api) throw new HttpsError("failed-precondition", "API import is available on Studio and Agency plans")
      const raw = `msl_${crypto.randomBytes(32).toString("base64url")}`
      const hash = crypto.createHash("sha256").update(raw).digest("hex")
      await db.collection(collections.apiKeys).doc(hash).set({
        tokenHash: hash,
        photographerId: context.id,
        ownerUid: context.ownerUid,
        label: text(request.data?.label, 120) || "Import API",
        active: true,
        createdAt: serverTimestamp(),
        lastUsedAt: null,
      })
      await writeAudit({ photographerId: context.id, ownerUid: context.ownerUid, action: "api_key_created", targetId: hash.slice(0, 12) })
      return { apiKey: raw, keyId: hash, endpoint: "https://us-east1-maslive.cloudfunctions.net/photographerMediaImportApi" }
    },
  )

  const revokePhotographerApiKey = onCall(
    { region, timeoutSeconds: 30 },
    async (request) => {
      const context = await ownedProfile(request)
      const keyId = text(request.data?.keyId, 128)
      const ref = db.collection(collections.apiKeys).doc(keyId)
      const snapshot = await ref.get()
      if (!snapshot.exists || text((snapshot.data() || {}).photographerId, 160) !== context.id) {
        throw new HttpsError("not-found", "API key not found")
      }
      await ref.set({ active: false, revokedAt: serverTimestamp() }, { merge: true })
      await writeAudit({ photographerId: context.id, ownerUid: context.ownerUid, action: "api_key_revoked", targetId: keyId.slice(0, 12) })
      return { success: true }
    },
  )

  const savePhotographerImportSession = onCall(
    { region, timeoutSeconds: 30 },
    async (request) => {
      const context = await ownedProfile(request)
      const sessionId = text(request.data?.sessionId, 160) || crypto.randomUUID()
      const completed = unique(list(request.data?.completedFiles).map((item) => text(item, 300))).slice(0, 10000)
      await db.collection(collections.importSessions).doc(sessionId).set({
        sessionId,
        photographerId: context.id,
        ownerUid: context.ownerUid,
        galleryId: text(request.data?.galleryId, 160),
        folderName: text(request.data?.folderName, 300),
        totalFiles: Math.max(completed.length, integer(request.data?.totalFiles)),
        completedFiles: completed,
        failedFiles: list(request.data?.failedFiles).slice(0, 1000),
        status: text(request.data?.status, 40) || "in_progress",
        createdAt: request.data?.createdAt ? timestampFromMillis(number(request.data.createdAt)) : serverTimestamp(),
        updatedAt: serverTimestamp(),
      }, { merge: true })
      return { sessionId, completedCount: completed.length }
    },
  )

  const listPhotographerImportSessions = onCall(
    { region, timeoutSeconds: 30 },
    async (request) => {
      const context = await ownedProfile(request)
      const snapshot = await db.collection(collections.importSessions).where("photographerId", "==", context.id).get()
      const sessions = snapshot.docs.map((doc) => ({ id: doc.id, ...(doc.data() || {}) }))
        .sort((a, b) => timestampMs(b.updatedAt) - timestampMs(a.updatedAt))
        .slice(0, 20)
      return { sessions }
    },
  )

  const generateGalleryPrivateLink = onCall(
    { region, timeoutSeconds: 30 },
    async (request) => {
      const context = await ownedProfile(request)
      const galleryId = text(request.data?.galleryId, 160)
      const ref = db.collection(collections.galleries).doc(galleryId)
      const snapshot = await ref.get()
      if (!snapshot.exists || text((snapshot.data() || {}).photographerId, 160) !== context.id) {
        throw new HttpsError("not-found", "Gallery not found")
      }
      const token = crypto.randomBytes(24).toString("base64url")
      await ref.set({ privateAccessToken: token, visibility: "unlisted", privateLinkCreatedAt: serverTimestamp(), updatedAt: serverTimestamp() }, { merge: true })
      const url = `https://maslive.web.app/#/media-marketplace?galleryId=${encodeURIComponent(galleryId)}&access=${encodeURIComponent(token)}`
      return { url, token }
    },
  )

  const duplicatePhotographerGallery = onCall(
    { region, timeoutSeconds: 60, memory: "512MiB" },
    async (request) => {
      const context = await ownedProfile(request)
      const galleryId = text(request.data?.galleryId, 160)
      const sourceRef = db.collection(collections.galleries).doc(galleryId)
      const sourceSnapshot = await sourceRef.get()
      if (!sourceSnapshot.exists || text((sourceSnapshot.data() || {}).photographerId, 160) !== context.id) {
        throw new HttpsError("not-found", "Gallery not found")
      }
      const source = sourceSnapshot.data() || {}
      const targetRef = db.collection(collections.galleries).doc()
      const packs = await db.collection(collections.packs).where("galleryId", "==", galleryId).get()
      const batch = db.batch()
      batch.set(targetRef, {
        ...source,
        galleryId: targetRef.id,
        title: `${text(source.title, 180)} — copie`,
        status: "draft",
        visibility: "private",
        photoCount: 0,
        publishedPhotoCount: 0,
        coverPhotoId: null,
        coverUrl: null,
        privateAccessToken: null,
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      })
      for (const packDoc of packs.docs) {
        const packRef = db.collection(collections.packs).doc()
        batch.set(packRef, { ...packDoc.data(), packId: packRef.id, galleryId: targetRef.id, createdAt: serverTimestamp(), updatedAt: serverTimestamp() })
      }
      batch.set(context.ref, { activeGalleryCount: admin.firestore.FieldValue.increment(1), updatedAt: serverTimestamp() }, { merge: true })
      await batch.commit()
      await writeAudit({ photographerId: context.id, ownerUid: context.ownerUid, action: "gallery_duplicated", targetId: targetRef.id, details: { sourceGalleryId: galleryId } })
      return { galleryId: targetRef.id }
    },
  )

  const deletePhotographerGallery = onCall(
    { region, cpu: 0.5, timeoutSeconds: 120, memory: "1GiB" },
    async (request) => {
      const context = await ownedProfile(request)
      const galleryId = text(request.data?.galleryId, 160)
      const galleryRef = db.collection(collections.galleries).doc(galleryId)
      const gallerySnapshot = await galleryRef.get()
      if (!gallerySnapshot.exists || text((gallerySnapshot.data() || {}).photographerId, 160) !== context.id) {
        throw new HttpsError("not-found", "Gallery not found")
      }
      const [photos, packs] = await Promise.all([
        db.collection(collections.photos).where("galleryId", "==", galleryId).get(),
        db.collection(collections.packs).where("galleryId", "==", galleryId).get(),
      ])
      const photoIds = photos.docs.map((doc) => doc.id)
      for (let offset = 0; offset < photoIds.length; offset += 10) {
        const chunk = photoIds.slice(offset, offset + 10)
        if (!chunk.length) continue
        const entitlements = await db.collection(collections.entitlements).where("photoIds", "array-contains-any", chunk).limit(1).get()
        if (!entitlements.empty) throw new HttpsError("failed-precondition", "Purchased photos prevent gallery deletion. Archive it instead.")
      }
      const bucket = admin.storage().bucket()
      for (const photoDoc of photos.docs) {
        const photo = photoDoc.data() || {}
        const paths = [photo.originalPath, photo.previewPath, photo.thumbnailPath, photo.watermarkedPath].map((value) => text(value, 1000)).filter(Boolean)
        await Promise.all(paths.map((path) => bucket.file(path).delete({ ignoreNotFound: true }).catch(() => null)))
      }
      const writes = [...photos.docs, ...packs.docs]
      for (let offset = 0; offset < writes.length; offset += 400) {
        const batch = db.batch()
        for (const doc of writes.slice(offset, offset + 400)) batch.delete(doc.ref)
        await batch.commit()
      }
      await galleryRef.delete()
      await context.ref.set({ activeGalleryCount: admin.firestore.FieldValue.increment(-1), updatedAt: serverTimestamp() }, { merge: true })
      await writeAudit({ photographerId: context.id, ownerUid: context.ownerUid, action: "gallery_deleted", targetId: galleryId, details: { photos: photos.size, packs: packs.size } })
      return { success: true }
    },
  )

  function csvCell(value) {
    const raw = value == null ? "" : String(value)
    return `"${raw.replace(/"/g, '""')}"`
  }

  const generatePhotographerExport = onCall(
    { region, timeoutSeconds: 60, memory: "512MiB" },
    async (request) => {
      const context = await ownedProfile(request)
      const kind = text(request.data?.kind, 40) || "sales"
      const from = timestampMs(request.data?.from)
      const to = timestampMs(request.data?.to) || Number.MAX_SAFE_INTEGER
      const orders = (await loadOrders(context.id)).filter((order) => {
        const date = timestampMs(order.paidAt || order.createdAt)
        return date >= from && date <= to
      })
      const header = ["orderId", "date", "status", "currency", "gross", "platformFee", "stripeFee", "net", "buyerUid"]
      const rows = orders.map((order) => [
        order.id,
        new Date(timestampMs(order.paidAt || order.createdAt)).toISOString(),
        order.paymentStatus || "",
        order.currency || "EUR",
        number(order.total).toFixed(2),
        number(order.platformFee).toFixed(2),
        number(order.stripeFee).toFixed(2),
        number(order.photographerNetTotal, number(order.photographerAmount)).toFixed(2),
        kind === "clients" ? text(order.buyerUid, 160) : "",
      ])
      const csv = [header, ...rows].map((row) => row.map(csvCell).join(";")).join("\r\n")
      const gross = orders.reduce((sum, order) => sum + number(order.total), 0)
      const net = orders.reduce((sum, order) => sum + number(order.photographerNetTotal, number(order.photographerAmount)), 0)
      const invoiceNumber = `MASLIVE-${context.id.slice(0, 8).toUpperCase()}-${new Date().toISOString().slice(0, 10).replace(/-/g, "")}`
      const invoiceText = [
        `FACTURE / RELEVÉ PHOTOGRAPHE ${invoiceNumber}`,
        `Photographe: ${text(context.profile.brandName, 160)}`,
        `Période: ${from ? new Date(from).toLocaleDateString("fr-FR") : "début"} - ${to < Number.MAX_SAFE_INTEGER ? new Date(to).toLocaleDateString("fr-FR") : "aujourd'hui"}`,
        `Commandes: ${orders.length}`,
        `Chiffre d'affaires brut: ${gross.toFixed(2)} EUR`,
        `Net photographe: ${net.toFixed(2)} EUR`,
      ].join("\n")
      await writeAudit({ photographerId: context.id, ownerUid: context.ownerUid, action: `export_${kind}_generated`, details: { orders: orders.length, from, to } })
      return { csv, invoiceText, invoiceNumber, orderCount: orders.length, gross, net }
    },
  )

  async function apiContext(req) {
    const authorization = text(req.headers.authorization, 500)
    const raw = authorization.startsWith("Bearer ") ? authorization.slice(7).trim() : ""
    if (!raw) return null
    const hash = crypto.createHash("sha256").update(raw).digest("hex")
    const ref = db.collection(collections.apiKeys).doc(hash)
    const snapshot = await ref.get()
    if (!snapshot.exists || (snapshot.data() || {}).active !== true) return null
    await ref.set({ lastUsedAt: serverTimestamp() }, { merge: true })
    return { keyId: hash, ref, ...(snapshot.data() || {}) }
  }

  const photographerMediaImportApi = onRequest(
    { region, timeoutSeconds: 120, memory: "512MiB", cors: true },
    async (req, res) => {
      res.set("Access-Control-Allow-Origin", "*")
      res.set("Access-Control-Allow-Headers", "Authorization, Content-Type")
      if (req.method === "OPTIONS") return res.status(204).send("")
      if (req.method !== "POST") return res.status(405).json({ error: "POST required" })
      const context = await apiContext(req)
      if (!context) return res.status(401).json({ error: "Invalid API key" })
      const action = text(req.body?.action, 40)
      const galleryId = text(req.body?.galleryId, 160)
      const gallerySnapshot = await db.collection(collections.galleries).doc(galleryId).get()
      if (!gallerySnapshot.exists || text((gallerySnapshot.data() || {}).photographerId, 160) !== text(context.photographerId, 160)) {
        return res.status(404).json({ error: "Gallery not found" })
      }
      const gallery = gallerySnapshot.data() || {}
      if (action === "prepare") {
        const fileName = text(req.body?.fileName, 300) || "photo.jpg"
        const contentType = text(req.body?.contentType, 120) || "image/jpeg"
        const sizeBytes = integer(req.body?.sizeBytes)
        if (sizeBytes <= 0) return res.status(400).json({ error: "sizeBytes is required" })
        const photoId = db.collection(collections.photos).doc().id
        const extension = ["image/png", "image/webp"].includes(contentType) ? contentType.split("/")[1] : "jpg"
        const originalPath = `photographers/${context.photographerId}/events/${text(gallery.eventId, 160)}/galleries/${galleryId}/originals/${photoId}.${extension}`
        const jobRef = db.collection(collections.importJobs).doc(photoId)
        await jobRef.set({
          jobId: photoId,
          photoId,
          photographerId: context.photographerId,
          ownerUid: context.ownerUid,
          galleryId,
          eventId: gallery.eventId,
          fileName,
          contentType,
          sizeBytes,
          originalPath,
          status: "prepared",
          createdAt: serverTimestamp(),
          expiresAt: timestampFromMillis(Date.now() + (60 * 60 * 1000)),
        })
        const [uploadUrl] = await admin.storage().bucket().file(originalPath).getSignedUrl({
          version: "v4",
          action: "write",
          expires: Date.now() + (15 * 60 * 1000),
          contentType,
        })
        return res.json({ jobId: photoId, photoId, uploadUrl, originalPath, expiresInSeconds: 900 })
      }
      if (action === "finalize") {
        const jobId = text(req.body?.jobId, 160)
        const jobRef = db.collection(collections.importJobs).doc(jobId)
        const jobSnapshot = await jobRef.get()
        if (!jobSnapshot.exists) return res.status(404).json({ error: "Import job not found" })
        const job = jobSnapshot.data() || {}
        if (text(job.photographerId, 160) !== text(context.photographerId, 160) || text(job.galleryId, 160) !== galleryId) {
          return res.status(403).json({ error: "Import job ownership mismatch" })
        }
        const [exists] = await admin.storage().bucket().file(job.originalPath).exists()
        if (!exists) return res.status(409).json({ error: "Upload not found" })
        const photoRef = db.collection(collections.photos).doc(job.photoId)
        const previewBase = `photographers/${context.photographerId}/events/${text(gallery.eventId, 160)}/galleries/${galleryId}`
        await photoRef.set({
          photoId: job.photoId,
          photographerId: context.photographerId,
          ownerUid: context.ownerUid,
          galleryId,
          eventId: gallery.eventId,
          eventName: gallery.title || "",
          countryId: gallery.linkedCountry || "",
          circuitId: gallery.linkedCircuitId || "",
          originalPath: job.originalPath,
          previewPath: `${previewBase}/previews/${job.photoId}.webp`,
          thumbnailPath: `${previewBase}/thumbs/${job.photoId}.webp`,
          watermarkedPath: `${previewBase}/watermarked/${job.photoId}.webp`,
          downloadFileName: job.fileName,
          sizeBytes: job.sizeBytes,
          mimeType: job.contentType,
          tags: [],
          faceTags: [],
          bibNumbers: [],
          colorTags: [],
          moderationStatus: "pending",
          lifecycleStatus: "draft",
          visibility: "private",
          processingStatus: "queued",
          isPublished: false,
          isForSale: false,
          unitPrice: 6.90,
          currency: "EUR",
          createdAt: serverTimestamp(),
          updatedAt: serverTimestamp(),
        })
        await jobRef.set({ status: "finalized", finalizedAt: serverTimestamp(), updatedAt: serverTimestamp() }, { merge: true })
        return res.json({ success: true, photoId: job.photoId })
      }
      return res.status(400).json({ error: "action must be prepare or finalize" })
    },
  )

  function nearestColorName(red, green, blue) {
    const palette = {
      noir: [20, 20, 20], blanc: [240, 240, 240], rouge: [210, 40, 40], orange: [230, 120, 30],
      jaune: [230, 210, 40], vert: [45, 155, 75], bleu: [40, 95, 200], violet: [125, 65, 170],
      rose: [225, 95, 150], marron: [120, 75, 45], gris: [125, 125, 125], turquoise: [40, 175, 175],
    }
    let best = "inconnu"
    let bestDistance = Number.MAX_SAFE_INTEGER
    for (const [name, rgb] of Object.entries(palette)) {
      const distance = ((red - rgb[0]) ** 2) + ((green - rgb[1]) ** 2) + ((blue - rgb[2]) ** 2)
      if (distance < bestDistance) { bestDistance = distance; best = name }
    }
    return best
  }

  function anonymousFaceSignatures(faces) {
    return list(faces).map((face) => {
      const landmarks = list(face.landmarks).slice(0, 16).map((landmark) => {
        const position = landmark.position || {}
        return `${text(landmark.type, 40)}:${number(position.x).toFixed(1)}:${number(position.y).toFixed(1)}:${number(position.z).toFixed(1)}`
      }).join("|")
      if (!landmarks) return null
      return `anon_${crypto.createHash("sha256").update(landmarks).digest("hex").slice(0, 20)}`
    }).filter(Boolean)
  }

  async function visionAnnotate(buffer, faceGroupingEnabled) {
    const credential = admin.app().options.credential
    if (!credential || typeof credential.getAccessToken !== "function") return null
    const token = await credential.getAccessToken()
    const features = [
      { type: "TEXT_DETECTION", maxResults: 10 },
      { type: "IMAGE_PROPERTIES", maxResults: 10 },
      { type: "LABEL_DETECTION", maxResults: 12 },
    ]
    if (faceGroupingEnabled) features.push({ type: "FACE_DETECTION", maxResults: 20 })
    const response = await fetch("https://vision.googleapis.com/v1/images:annotate", {
      method: "POST",
      headers: { Authorization: `Bearer ${token.access_token}`, "Content-Type": "application/json" },
      body: JSON.stringify({ requests: [{ image: { content: buffer.toString("base64") }, features }] }),
    })
    if (!response.ok) throw new Error(`Vision API ${response.status}: ${(await response.text()).slice(0, 300)}`)
    return (await response.json()).responses?.[0] || null
  }

  const analyzePhotographerPhoto = onDocumentUpdated(
    { document: "media_photos/{photoId}", region, cpu: 0.5, timeoutSeconds: 180, memory: "1GiB", maxInstances: 10 },
    async (event) => {
      const before = event.data?.before?.data() || {}
      const after = event.data?.after?.data() || {}
      if (after.processingStatus !== "processed" || before.processingStatus === "processed") return
      const gallerySnapshot = await db.collection(collections.galleries).doc(text(after.galleryId, 160)).get()
      const gallery = gallerySnapshot.data() || {}
      const profileSnapshot = await db.collection(collections.photographers).doc(text(after.photographerId, 160)).get()
      const profile = profileSnapshot.data() || {}
      const consent = profile.workspaceConfig?.faceGroupingConsent === true && gallery.faceGroupingEnabled === true
      const path = text(after.previewPath, 1000) || text(after.originalPath, 1000)
      if (!path) return
      try {
        const [buffer] = await admin.storage().bucket().file(path).download()
        const annotation = await visionAnnotate(buffer, consent)
        if (!annotation) return
        const detectedText = text(annotation.fullTextAnnotation?.text || annotation.textAnnotations?.[0]?.description, 10000)
        const bibNumbers = unique((detectedText.match(/\b\d{1,5}\b/g) || []).map((value) => value.replace(/^0+/, "") || "0")).slice(0, 30)
        const labels = list(annotation.labelAnnotations).filter((value) => number(value.score) >= 0.65).map((value) => text(value.description, 80).toLowerCase()).filter(Boolean).slice(0, 20)
        const colors = list(annotation.imagePropertiesAnnotation?.dominantColors?.colors).slice(0, 5).map((value) => {
          const color = value.color || {}
          return nearestColorName(number(color.red), number(color.green), number(color.blue))
        })
        const faceTags = consent ? anonymousFaceSignatures(annotation.faceAnnotations) : []
        const existingTags = list(after.tags).map((value) => text(value, 80).toLowerCase()).filter(Boolean)
        await event.data.after.ref.set({
          tags: unique([...existingTags, ...labels, ...colors, ...bibNumbers.map((value) => `dossard:${value}`)]),
          bibNumbers,
          colorTags: unique(colors),
          faceTags,
          faceCount: list(annotation.faceAnnotations).length,
          faceGroupingMode: consent ? "anonymous_landmark_hash" : "disabled",
          autoAnalysisStatus: "completed",
          autoAnalysisAt: serverTimestamp(),
          updatedAt: serverTimestamp(),
        }, { merge: true })
      } catch (error) {
        await event.data.after.ref.set({
          autoAnalysisStatus: "failed",
          autoAnalysisError: text(error?.message, 500),
          updatedAt: serverTimestamp(),
        }, { merge: true })
      }
    },
  )

  return {
    getPhotographerAdvancedDashboard,
    getPhotographerWorkspaceConfig,
    savePhotographerWorkspaceConfig,
    createPhotographerApiKey,
    revokePhotographerApiKey,
    savePhotographerImportSession,
    listPhotographerImportSessions,
    generateGalleryPrivateLink,
    duplicatePhotographerGallery,
    deletePhotographerGallery,
    generatePhotographerExport,
    photographerMediaImportApi,
    analyzePhotographerPhoto,
  }
}
