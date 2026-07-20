"use strict"

const crypto = require("node:crypto")
const { onDocumentUpdated, onDocumentWritten } = require("firebase-functions/v2/firestore")
const {
  ESTIMATED_AI_COST_EUR,
  extensionForCode,
} = require("./media-marketplace-pricing")

module.exports = function createPhotographerAiCredits({
  admin,
  db,
  onCall,
  HttpsError,
}) {
  const region = "us-east1"
  const ACCOUNTS = "photographer_ai_credit_accounts"
  const USAGE = "photographer_ai_credit_usage"
  const WORKSPACES = "photographer_workspaces"
  const COLLABORATORS = "photographer_collaborators"
  const EXTENSIONS = "photographer_storage_extensions"
  const serverTimestamp = () => admin.firestore.FieldValue.serverTimestamp()

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

  function isAdmin(auth) {
    const token = auth?.token || {}
    return token.admin === true || token.isAdmin === true || ["admin", "superadmin", "super-admin"].includes(token.role)
  }

  async function managedProfile(auth, photographerId, allowedRoles = ["owner", "manager", "editor", "finance", "viewer"]) {
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
    const collaborator = await db.collection(COLLABORATORS).doc(`${id}_${auth.uid}`).get()
    const data = collaborator.exists ? collaborator.data() || {} : {}
    if (data.status !== "accepted" || data.uid !== auth.uid || !allowedRoles.includes(data.role)) {
      throw new HttpsError("permission-denied", "This photographer workspace is not available to you")
    }
    return { id, ref, profile, role: data.role, ownerUid: profile.ownerUid }
  }

  function accountRef(photographerId) {
    return db.collection(ACCOUNTS).doc(photographerId)
  }

  function lotsRef(photographerId) {
    return accountRef(photographerId).collection("lots")
  }

  function creditDefinition(code) {
    const extension = extensionForCode(code)
    if (!extension) return null
    const basic = Math.max(0, integer(extension.basicAiCredits))
    const advanced = Math.max(0, integer(extension.advancedAiCredits))
    if (!basic && !advanced) return null
    return {
      extension,
      mode: advanced > 0 ? "advanced" : "basic",
      quantity: advanced > 0 ? advanced : basic,
      expiresWithExtension: extension.creditsExpireWithExtension === true,
      neverExpires: extension.creditsNeverExpire === true,
    }
  }

  const grantPhotographerAiCreditsFromExtension = onDocumentWritten(
    {
      document: `${EXTENSIONS}/{extensionId}`,
      region,
      timeoutSeconds: 60,
      memory: "512MiB",
    },
    async (event) => {
      const afterSnapshot = event.data?.after
      const beforeSnapshot = event.data?.before
      const after = afterSnapshot?.exists ? afterSnapshot.data() || {} : null
      const before = beforeSnapshot?.exists ? beforeSnapshot.data() || {} : null
      const definition = creditDefinition(after?.code || before?.code)
      if (!definition) return

      const photographerId = text(after?.photographerId || before?.photographerId, 160)
      if (!photographerId) return
      const lotRef = lotsRef(photographerId).doc(event.params.extensionId)

      if (!after || after.status !== "active") {
        if (definition.expiresWithExtension) {
          await lotRef.set({
            status: "expired",
            remaining: 0,
            expiredAt: serverTimestamp(),
            updatedAt: serverTimestamp(),
          }, { merge: true })
        }
        return
      }

      const extensionRef = afterSnapshot.ref
      const expiresAt = definition.expiresWithExtension
        ? (after.expiresAt || null)
        : null

      await db.runTransaction(async (transaction) => {
        const [freshExtension, existingLot] = await Promise.all([
          transaction.get(extensionRef),
          transaction.get(lotRef),
        ])
        if (!freshExtension.exists) return
        const current = freshExtension.data() || {}
        if (current.status !== "active") return
        if (existingLot.exists && (existingLot.data() || {}).grantApplied === true) {
          transaction.set(extensionRef, {
            aiCreditGrantApplied: true,
            aiCreditLotId: lotRef.id,
            updatedAt: serverTimestamp(),
          }, { merge: true })
          return
        }

        const account = accountRef(photographerId)
        transaction.set(lotRef, {
          lotId: lotRef.id,
          photographerId,
          ownerUid: current.ownerUid || null,
          sourceExtensionId: extensionRef.id,
          sourceCode: definition.extension.code,
          mode: definition.mode,
          granted: definition.quantity,
          remaining: definition.quantity,
          status: "active",
          expiresAt,
          neverExpires: definition.neverExpires,
          grantApplied: true,
          createdAt: serverTimestamp(),
          updatedAt: serverTimestamp(),
        }, { merge: true })
        transaction.set(account, {
          photographerId,
          [`${definition.mode}Granted`]: admin.firestore.FieldValue.increment(definition.quantity),
          lastGrantAt: serverTimestamp(),
          updatedAt: serverTimestamp(),
        }, { merge: true })
        transaction.set(extensionRef, {
          aiCreditGrantApplied: true,
          aiCreditLotId: lotRef.id,
          aiCreditMode: definition.mode,
          aiCreditQuantity: definition.quantity,
          updatedAt: serverTimestamp(),
        }, { merge: true })
      })
    },
  )

  async function activeLots(photographerId, mode) {
    const snapshot = await lotsRef(photographerId).where("mode", "==", mode).get()
    const now = Date.now()
    const rows = []
    const expiredWrites = []
    for (const doc of snapshot.docs) {
      const data = doc.data() || {}
      const expiresAt = timestampMs(data.expiresAt)
      const expired = expiresAt > 0 && expiresAt <= now
      if (expired && data.status === "active") {
        expiredWrites.push(doc.ref.set({
          status: "expired",
          remaining: 0,
          expiredAt: serverTimestamp(),
          updatedAt: serverTimestamp(),
        }, { merge: true }))
      }
      if (data.status !== "active" || expired || integer(data.remaining) <= 0) continue
      rows.push({ id: doc.id, ref: doc.ref, ...data })
    }
    if (expiredWrites.length) await Promise.all(expiredWrites)
    rows.sort((a, b) => {
      const aExpiry = timestampMs(a.expiresAt) || Number.MAX_SAFE_INTEGER
      const bExpiry = timestampMs(b.expiresAt) || Number.MAX_SAFE_INTEGER
      if (aExpiry !== bExpiry) return aExpiry - bExpiry
      return timestampMs(a.createdAt) - timestampMs(b.createdAt)
    })
    return rows
  }

  async function consumeCredit({ photographerId, photoId, mode, reason, requestKey }) {
    const candidates = await activeLots(photographerId, mode)
    for (const candidate of candidates) {
      const usageRef = db.collection(USAGE).doc()
      const result = await db.runTransaction(async (transaction) => {
        const lot = await transaction.get(candidate.ref)
        if (!lot.exists) return null
        const data = lot.data() || {}
        const expiresAt = timestampMs(data.expiresAt)
        if (data.status !== "active" || integer(data.remaining) <= 0 || (expiresAt > 0 && expiresAt <= Date.now())) {
          return null
        }
        transaction.set(candidate.ref, {
          remaining: admin.firestore.FieldValue.increment(-1),
          consumed: admin.firestore.FieldValue.increment(1),
          lastConsumedAt: serverTimestamp(),
          updatedAt: serverTimestamp(),
        }, { merge: true })
        transaction.set(accountRef(photographerId), {
          [`${mode}Consumed`]: admin.firestore.FieldValue.increment(1),
          lastConsumedAt: serverTimestamp(),
          updatedAt: serverTimestamp(),
        }, { merge: true })
        transaction.set(usageRef, {
          usageId: usageRef.id,
          photographerId,
          photoId,
          mode,
          reason,
          requestKey,
          lotId: candidate.id,
          status: "consumed",
          estimatedCostEur: ESTIMATED_AI_COST_EUR,
          consumedAt: serverTimestamp(),
          createdAt: serverTimestamp(),
          updatedAt: serverTimestamp(),
        })
        return { usageId: usageRef.id, lotId: candidate.id, mode }
      })
      if (result) return result
    }
    return null
  }

  async function refundCredit({ photographerId, usageId, lotId, mode, error }) {
    if (!usageId || !lotId) return
    const usageRef = db.collection(USAGE).doc(usageId)
    const lotRef = lotsRef(photographerId).doc(lotId)
    await db.runTransaction(async (transaction) => {
      const usage = await transaction.get(usageRef)
      if (!usage.exists || (usage.data() || {}).status !== "consumed") return
      transaction.set(lotRef, {
        remaining: admin.firestore.FieldValue.increment(1),
        consumed: admin.firestore.FieldValue.increment(-1),
        updatedAt: serverTimestamp(),
      }, { merge: true })
      transaction.set(accountRef(photographerId), {
        [`${mode}Consumed`]: admin.firestore.FieldValue.increment(-1),
        updatedAt: serverTimestamp(),
      }, { merge: true })
      transaction.set(usageRef, {
        status: "refunded",
        refundReason: text(error?.message || error, 500),
        refundedAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      }, { merge: true })
    })
  }

  async function creditBalance(photographerId) {
    const [basicLots, advancedLots, account] = await Promise.all([
      activeLots(photographerId, "basic"),
      activeLots(photographerId, "advanced"),
      accountRef(photographerId).get(),
    ])
    const data = account.exists ? account.data() || {} : {}
    const remaining = (rows) => rows.reduce((sum, row) => sum + Math.max(0, integer(row.remaining)), 0)
    return {
      basic: {
        granted: Math.max(0, integer(data.basicGranted)),
        consumed: Math.max(0, integer(data.basicConsumed)),
        remaining: remaining(basicLots),
      },
      advanced: {
        granted: Math.max(0, integer(data.advancedGranted)),
        consumed: Math.max(0, integer(data.advancedConsumed)),
        remaining: remaining(advancedLots),
      },
      activeLots: [...basicLots, ...advancedLots].map((row) => ({
        lotId: row.id,
        mode: row.mode,
        remaining: integer(row.remaining),
        expiresAt: row.expiresAt || null,
        sourceCode: row.sourceCode || null,
      })),
      estimatedCostPerAnalysisEur: ESTIMATED_AI_COST_EUR,
      policy: {
        firstAnalysisConsumesOneCredit: true,
        manualReanalysisConsumesOneCredit: true,
        movingPhotoConsumesCredit: false,
        editingPriceConsumesCredit: false,
        editingTagsConsumesCredit: false,
      },
    }
  }

  const getPhotographerAiCreditBalance = onCall(
    { region, timeoutSeconds: 30 },
    async (request) => {
      const context = await managedProfile(request.auth, request.data?.photographerId)
      return creditBalance(context.id)
    },
  )

  async function workspaceFor(photographerId, profile) {
    const workspace = await db.collection(WORKSPACES).doc(photographerId).get()
    return workspace.exists ? workspace.data() || {} : profile.workspaceConfig || {}
  }

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

  async function visionAnnotate(buffer, advanced) {
    const credential = admin.app().options.credential
    if (!credential || typeof credential.getAccessToken !== "function") {
      throw new Error("Google Vision credential unavailable")
    }
    const token = await credential.getAccessToken()
    const features = [
      { type: "TEXT_DETECTION", maxResults: 10 },
      { type: "IMAGE_PROPERTIES", maxResults: 10 },
      { type: "LABEL_DETECTION", maxResults: 12 },
    ]
    if (advanced) features.push({ type: "FACE_DETECTION", maxResults: 20 })
    const response = await fetch("https://vision.googleapis.com/v1/images:annotate", {
      method: "POST",
      headers: { Authorization: `Bearer ${token.access_token}`, "Content-Type": "application/json" },
      body: JSON.stringify({ requests: [{ image: { content: buffer.toString("base64") }, features }] }),
    })
    if (!response.ok) throw new Error(`Vision API ${response.status}: ${(await response.text()).slice(0, 300)}`)
    return (await response.json()).responses?.[0] || null
  }

  async function claimAnalysis(photoRef, requestKey) {
    return db.runTransaction(async (transaction) => {
      const snapshot = await transaction.get(photoRef)
      if (!snapshot.exists) return false
      const data = snapshot.data() || {}
      if (data.aiAnalysisLastHandledKey === requestKey) return false
      const lockAt = timestampMs(data.aiAnalysisLockAt)
      if (data.aiAnalysisLockKey === requestKey && lockAt > Date.now() - (10 * 60 * 1000)) return false
      transaction.set(photoRef, {
        aiAnalysisLockKey: requestKey,
        aiAnalysisLockAt: serverTimestamp(),
        autoAnalysisStatus: "awaiting_credit",
        updatedAt: serverTimestamp(),
      }, { merge: true })
      return true
    })
  }

  const analyzePhotographerPhoto = onDocumentUpdated(
    {
      document: "media_photos/{photoId}",
      region,
      timeoutSeconds: 180,
      memory: "1GiB",
      maxInstances: 10,
    },
    async (event) => {
      const before = event.data?.before?.data() || {}
      const after = event.data?.after?.data() || {}
      const firstAnalysis = after.processingStatus === "processed" &&
        before.processingStatus !== "processed" &&
        !after.aiFirstAnalysisAt
      const manualRequestId = text(after.aiAnalysisRequestId, 160)
      const manualAnalysis = !!manualRequestId && manualRequestId !== text(before.aiAnalysisRequestId, 160)
      if (!firstAnalysis && !manualAnalysis) return

      const photoRef = event.data.after.ref
      const requestKey = manualAnalysis ? `manual:${manualRequestId}` : `first:${event.params.photoId}`
      if (!await claimAnalysis(photoRef, requestKey)) return

      const photographerId = text(after.photographerId, 160)
      const galleryId = text(after.galleryId, 160)
      const [gallerySnapshot, profileSnapshot] = await Promise.all([
        db.collection("media_galleries").doc(galleryId).get(),
        db.collection("photographers").doc(photographerId).get(),
      ])
      const gallery = gallerySnapshot.exists ? gallerySnapshot.data() || {} : {}
      const profile = profileSnapshot.exists ? profileSnapshot.data() || {} : {}
      const workspace = await workspaceFor(photographerId, profile)
      const consent = workspace.faceGroupingConsent === true && gallery.faceGroupingEnabled === true
      const requestedMode = manualAnalysis ? text(after.aiAnalysisRequestedMode, 20).toLowerCase() : ""
      const desiredMode = requestedMode === "advanced" || (!requestedMode && consent) ? "advanced" : "basic"
      const reason = manualAnalysis ? "manual_reanalysis" : "first_import_analysis"

      let usage = await consumeCredit({
        photographerId,
        photoId: event.params.photoId,
        mode: desiredMode,
        reason,
        requestKey,
      })
      let effectiveMode = desiredMode
      let downgraded = false
      if (!usage && desiredMode === "advanced" && !manualAnalysis) {
        usage = await consumeCredit({
          photographerId,
          photoId: event.params.photoId,
          mode: "basic",
          reason: `${reason}_basic_fallback`,
          requestKey,
        })
        effectiveMode = "basic"
        downgraded = !!usage
      }

      if (!usage) {
        await photoRef.set({
          autoAnalysisStatus: "credit_required",
          aiCreditModeRequired: desiredMode,
          aiAnalysisReason: reason,
          aiAnalysisLastHandledKey: requestKey,
          aiAnalysisLockKey: null,
          aiAnalysisLockAt: null,
          ...(manualAnalysis ? { aiAnalysisRequestHandledId: manualRequestId } : {}),
          updatedAt: serverTimestamp(),
        }, { merge: true })
        return
      }

      const path = text(after.previewPath, 1000) || text(after.originalPath, 1000)
      try {
        if (!path) throw new Error("Photo preview path missing")
        await photoRef.set({
          autoAnalysisStatus: "processing",
          aiCreditUsageId: usage.usageId,
          aiCreditModeConsumed: effectiveMode,
          aiAnalysisReason: reason,
          updatedAt: serverTimestamp(),
        }, { merge: true })
        const [buffer] = await admin.storage().bucket().file(path).download()
        const annotation = await visionAnnotate(buffer, effectiveMode === "advanced")
        if (!annotation) throw new Error("Google Vision returned no annotation")
        const detectedText = text(annotation.fullTextAnnotation?.text || annotation.textAnnotations?.[0]?.description, 10000)
        const bibNumbers = unique((detectedText.match(/\b\d{1,5}\b/g) || []).map((value) => value.replace(/^0+/, "") || "0")).slice(0, 30)
        const labels = list(annotation.labelAnnotations)
          .filter((value) => number(value.score) >= 0.65)
          .map((value) => text(value.description, 80).toLowerCase())
          .filter(Boolean)
          .slice(0, 20)
        const colors = list(annotation.imagePropertiesAnnotation?.dominantColors?.colors).slice(0, 5).map((value) => {
          const color = value.color || {}
          return nearestColorName(number(color.red), number(color.green), number(color.blue))
        })
        const faces = effectiveMode === "advanced" && consent ? list(annotation.faceAnnotations) : []
        const faceTags = effectiveMode === "advanced" && consent ? anonymousFaceSignatures(faces) : []
        const existingTags = list(after.tags).map((value) => text(value, 80).toLowerCase()).filter(Boolean)
        await photoRef.set({
          tags: unique([...existingTags, ...labels, ...colors, ...bibNumbers.map((value) => `dossard:${value}`)]),
          bibNumbers,
          colorTags: unique(colors),
          faceTags,
          faceCount: faces.length,
          faceGroupingMode: effectiveMode === "advanced" && consent ? "anonymous_landmark_hash" : "disabled",
          autoAnalysisStatus: "completed",
          autoAnalysisAt: serverTimestamp(),
          aiAnalysisMode: effectiveMode,
          aiAnalysisDowngradedToBasic: downgraded,
          aiAnalysisLastHandledKey: requestKey,
          aiAnalysisLockKey: null,
          aiAnalysisLockAt: null,
          aiCreditUsageId: usage.usageId,
          aiCreditCostEstimateEur: ESTIMATED_AI_COST_EUR,
          ...(firstAnalysis ? { aiFirstAnalysisAt: serverTimestamp() } : {}),
          ...(manualAnalysis ? {
            aiLastManualAnalysisAt: serverTimestamp(),
            aiAnalysisRequestHandledId: manualRequestId,
          } : {}),
          updatedAt: serverTimestamp(),
        }, { merge: true })
      } catch (error) {
        await refundCredit({
          photographerId,
          usageId: usage.usageId,
          lotId: usage.lotId,
          mode: usage.mode,
          error,
        })
        await photoRef.set({
          autoAnalysisStatus: "failed",
          autoAnalysisError: text(error?.message, 500),
          aiAnalysisLastHandledKey: requestKey,
          aiAnalysisLockKey: null,
          aiAnalysisLockAt: null,
          aiCreditUsageId: null,
          ...(manualAnalysis ? { aiAnalysisRequestHandledId: manualRequestId } : {}),
          updatedAt: serverTimestamp(),
        }, { merge: true })
      }
    },
  )

  const reanalyzePhotographerPhoto = onCall(
    { region, timeoutSeconds: 30 },
    async (request) => {
      const photographerId = text(request.data?.photographerId, 160)
      const context = await managedProfile(request.auth, photographerId, ["owner", "manager", "editor"])
      const photoId = text(request.data?.photoId, 160)
      const mode = text(request.data?.mode, 20).toLowerCase() === "advanced" ? "advanced" : "basic"
      const photoRef = db.collection("media_photos").doc(photoId)
      const photoSnapshot = await photoRef.get()
      if (!photoSnapshot.exists || text((photoSnapshot.data() || {}).photographerId, 160) !== context.id) {
        throw new HttpsError("not-found", "Photo not found")
      }
      if (mode === "advanced") {
        const photo = photoSnapshot.data() || {}
        const [gallery, workspace] = await Promise.all([
          db.collection("media_galleries").doc(text(photo.galleryId, 160)).get(),
          db.collection(WORKSPACES).doc(context.id).get(),
        ])
        if ((workspace.data() || {}).faceGroupingConsent !== true || (gallery.data() || {}).faceGroupingEnabled !== true) {
          throw new HttpsError("failed-precondition", "Le regroupement visuel avancé nécessite le consentement et son activation sur la galerie.")
        }
      }
      const requestId = crypto.randomUUID()
      await photoRef.set({
        aiAnalysisRequestId: requestId,
        aiAnalysisRequestedMode: mode,
        aiAnalysisRequestedByUid: request.auth.uid,
        aiAnalysisRequestedAt: serverTimestamp(),
        autoAnalysisStatus: "queued",
        updatedAt: serverTimestamp(),
      }, { merge: true })
      return { requestId, mode, estimatedCostEur: ESTIMATED_AI_COST_EUR }
    },
  )

  return {
    grantPhotographerAiCreditsFromExtension,
    getPhotographerAiCreditBalance,
    reanalyzePhotographerPhoto,
    analyzePhotographerPhoto,
  }
}
