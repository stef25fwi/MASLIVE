"use strict"

const GiB = 1024 * 1024 * 1024
const MiB = 1024 * 1024
const MEDIA_HD_UPGRADE_PRICE = 2.90
const ESTIMATED_AI_COST_EUR = 0.01

const PHOTO_PACKS = Object.freeze([
  Object.freeze({ code: "single", title: "1 photo souvenir", photoCount: 1, price: 6.90, highlighted: false }),
  Object.freeze({ code: "duo", title: "Pack Duo", photoCount: 2, price: 10.90, highlighted: false }),
  Object.freeze({ code: "essential", title: "Pack Essentiel", photoCount: 5, price: 19.90, highlighted: true }),
  Object.freeze({ code: "experience", title: "Pack Expérience", photoCount: 10, price: 29.90, highlighted: false }),
  Object.freeze({ code: "personal_gallery", title: "Galerie personnelle", photoCount: 20, price: 44.90, highlighted: false }),
])

const PHOTOGRAPHER_PLANS = Object.freeze([
  Object.freeze({ id: "discovery", code: "discovery", name: "Découverte", monthlyPrice: 0, annualPrice: 0, maxPublishedPhotos: 250, maxStorageBytes: 3 * GiB, maxActiveGalleries: 2, maxActivePacks: 10, maxFileBytes: 8 * MiB, maxMegapixels: 12, retentionDays: 30, commissionRate: 0.30, maxCollaborators: 1, qualityLabel: "JPEG 12 MP", includedBasicAiCredits: 0, includedAdvancedAiCredits: 0 }),
  Object.freeze({ id: "pro", code: "pro", name: "Pro", monthlyPrice: 19.90, annualPrice: 199, maxPublishedPhotos: 3000, maxStorageBytes: 30 * GiB, maxActiveGalleries: 20, maxActivePacks: 100, maxFileBytes: 20 * MiB, maxMegapixels: 24, retentionDays: 183, commissionRate: 0.25, maxCollaborators: 1, qualityLabel: "JPEG 24 MP", includedBasicAiCredits: 0, includedAdvancedAiCredits: 0 }),
  Object.freeze({ id: "studio", code: "studio", name: "Studio", monthlyPrice: 39.90, annualPrice: 399, maxPublishedPhotos: 10000, maxStorageBytes: 120 * GiB, maxActiveGalleries: 999, maxActivePacks: 500, maxFileBytes: 40 * MiB, maxMegapixels: 40, retentionDays: 365, commissionRate: 0.20, maxCollaborators: 5, qualityLabel: "JPEG 40 MP", includedBasicAiCredits: 0, includedAdvancedAiCredits: 0 }),
  Object.freeze({ id: "agency", code: "agency", name: "Agence", monthlyPrice: 79.90, annualPrice: 799, maxPublishedPhotos: 30000, maxStorageBytes: 400 * GiB, maxActiveGalleries: 9999, maxActivePacks: 2000, maxFileBytes: 60 * MiB, maxMegapixels: 60, retentionDays: 548, commissionRate: 0.15, maxCollaborators: 25, qualityLabel: "JPEG HD 60 MP", includedBasicAiCredits: 0, includedAdvancedAiCredits: 0 }),
])

// Le moteur Stripe historique considère une extension sans durationDays comme
// récurrente. Les packs IA à achat unique utilisent donc une durée technique
// longue, tandis que leurs crédits sont enregistrés sans expiration par le
// ledger IA. Les packs événementiels expirent réellement après 30 jours.
const STORAGE_EXTENSIONS = Object.freeze([
  Object.freeze({
    code: "plus_1000",
    kind: "storage",
    title: "+1 000 photos et +10 Go",
    description: "Extension récurrente de capacité active.",
    price: 5.90,
    extraPhotos: 1000,
    extraStorageBytes: 10 * GiB,
    basicAiCredits: 0,
    advancedAiCredits: 0,
  }),
  Object.freeze({
    code: "plus_5000",
    kind: "storage",
    title: "+5 000 photos et +50 Go",
    description: "Extension récurrente pour les volumes réguliers.",
    price: 19.90,
    extraPhotos: 5000,
    extraStorageBytes: 50 * GiB,
    basicAiCredits: 0,
    advancedAiCredits: 0,
  }),
  Object.freeze({
    code: "ai_basic_1000",
    kind: "ai_basic",
    title: "1 000 analyses OCR et couleurs",
    description: "Dossards, couleurs dominantes et tags automatiques.",
    price: 7.90,
    extraPhotos: 0,
    extraStorageBytes: 0,
    basicAiCredits: 1000,
    advancedAiCredits: 0,
    durationDays: 36500,
    creditsNeverExpire: true,
  }),
  Object.freeze({
    code: "ai_advanced_1000",
    kind: "ai_advanced",
    title: "1 000 analyses avancées avec regroupement visuel",
    description: "OCR, couleurs, tags et regroupement visuel anonyme avec consentement.",
    price: 11.90,
    extraPhotos: 0,
    extraStorageBytes: 0,
    basicAiCredits: 0,
    advancedAiCredits: 1000,
    durationDays: 36500,
    creditsNeverExpire: true,
  }),
  Object.freeze({
    code: "event_30d",
    kind: "event_storage",
    title: "Événement 30 jours sans analyse IA",
    description: "+5 000 photos et +50 Go pendant 30 jours.",
    price: 14.90,
    extraPhotos: 5000,
    extraStorageBytes: 50 * GiB,
    basicAiCredits: 0,
    advancedAiCredits: 0,
    durationDays: 30,
  }),
  Object.freeze({
    code: "event_30d_basic",
    kind: "event_basic",
    title: "Événement 30 jours avec 5 000 analyses basiques",
    description: "+5 000 photos, +50 Go et 5 000 analyses OCR/couleurs.",
    price: 29.90,
    extraPhotos: 5000,
    extraStorageBytes: 50 * GiB,
    basicAiCredits: 5000,
    advancedAiCredits: 0,
    durationDays: 30,
    creditsExpireWithExtension: true,
  }),
  Object.freeze({
    code: "event_30d_advanced",
    kind: "event_advanced",
    title: "Événement 30 jours avec analyse avancée",
    description: "+5 000 photos, +50 Go et 5 000 analyses avancées.",
    price: 39.90,
    extraPhotos: 5000,
    extraStorageBytes: 50 * GiB,
    basicAiCredits: 0,
    advancedAiCredits: 5000,
    durationDays: 30,
    creditsExpireWithExtension: true,
  }),
])

const PHOTOGRAPHER_ADD_ONS = STORAGE_EXTENSIONS

function normalizeCode(value) {
  return typeof value === "string" ? value.trim().toLowerCase() : ""
}

function planFor(value) {
  const normalized = normalizeCode(value)
  return PHOTOGRAPHER_PLANS.find((plan) => plan.id === normalized || plan.code === normalized) || PHOTOGRAPHER_PLANS[0]
}

function extensionForCode(value) {
  const normalized = normalizeCode(value)
  return STORAGE_EXTENSIONS.find((extension) => extension.code === normalized) || null
}

function packForCode(value) {
  const normalized = normalizeCode(value)
  return PHOTO_PACKS.find((pack) => pack.code === normalized) || null
}

function packForCount(count) {
  const normalized = Math.max(0, Math.trunc(Number(count) || 0))
  return PHOTO_PACKS.find((pack) => pack.photoCount === normalized) || null
}

function roundCurrency(value) {
  return Math.round((Number(value) + Number.EPSILON) * 100) / 100
}

function quoteForPhotoCount(count) {
  const requestedPhotoCount = Math.max(0, Math.trunc(Number(count) || 0))
  if (!requestedPhotoCount) {
    return { requestedPhotoCount: 0, billedPhotoCount: 0, bonusPhotoSlots: 0, packs: [], total: 0 }
  }

  const maxPackSize = Math.max(...PHOTO_PACKS.map((pack) => pack.photoCount))
  const maxBilledCount = requestedPhotoCount + maxPackSize - 1
  const bestPrices = Array(maxBilledCount + 1).fill(Number.POSITIVE_INFINITY)
  const combinations = Array(maxBilledCount + 1).fill(null)
  bestPrices[0] = 0
  combinations[0] = []

  for (let current = 1; current <= maxBilledCount; current += 1) {
    for (const pack of PHOTO_PACKS) {
      const previous = current - pack.photoCount
      if (previous < 0 || combinations[previous] == null) continue
      const candidate = bestPrices[previous] + pack.price
      if (candidate < bestPrices[current] - 0.0001) {
        bestPrices[current] = candidate
        combinations[current] = [...combinations[previous], pack]
      }
    }
  }

  let billedPhotoCount = requestedPhotoCount
  for (let current = requestedPhotoCount; current <= maxBilledCount; current += 1) {
    if (combinations[current] == null) continue
    if (combinations[billedPhotoCount] == null ||
        bestPrices[current] < bestPrices[billedPhotoCount] - 0.0001 ||
        (Math.abs(bestPrices[current] - bestPrices[billedPhotoCount]) < 0.0001 && current < billedPhotoCount)) {
      billedPhotoCount = current
    }
  }

  return {
    requestedPhotoCount,
    billedPhotoCount,
    bonusPhotoSlots: billedPhotoCount - requestedPhotoCount,
    packs: combinations[billedPhotoCount],
    total: roundCurrency(bestPrices[billedPhotoCount]),
  }
}

function bestPackCombination(count) {
  return quoteForPhotoCount(count).packs
}

function photoSelectionPrice(count) {
  return quoteForPhotoCount(count).total
}

function mediaDeliveryQuote({ subtotal = 0, hdUpgrade = false } = {}) {
  const normalizedSubtotal = Math.max(0, Number(subtotal) || 0)
  const hdUpgradeAmount = hdUpgrade ? MEDIA_HD_UPGRADE_PRICE : 0
  return Object.freeze({
    hdUpgrade: hdUpgrade === true,
    hdUpgradeAmount,
    allowedVariants: hdUpgrade === true
      ? Object.freeze(["original", "hd", "preview", "web"])
      : Object.freeze(["preview", "web"]),
    total: roundCurrency(normalizedSubtotal + hdUpgradeAmount),
  })
}

function stripeFeeEstimate(total) {
  const normalized = Math.max(0, Number(total) || 0)
  return normalized > 0 ? roundCurrency((normalized * 0.015) + 0.25) : 0
}

function quotaSnapshot(plan, extensionTotals = {}) {
  const selected = planFor(plan?.code || plan?.id || plan)
  return {
    planCode: selected.code,
    maxPublishedPhotos: selected.maxPublishedPhotos + Math.max(0, Number(extensionTotals.extraPhotos) || 0),
    maxStorageBytes: selected.maxStorageBytes + Math.max(0, Number(extensionTotals.extraStorageBytes) || 0),
    maxActiveGalleries: selected.maxActiveGalleries,
    maxActivePacks: selected.maxActivePacks,
    maxFileBytes: selected.maxFileBytes,
    maxMegapixels: selected.maxMegapixels,
    retentionDays: selected.retentionDays,
    maxCollaborators: selected.maxCollaborators,
    commissionRate: selected.commissionRate,
    qualityLabel: selected.qualityLabel,
    includedBasicAiCredits: selected.includedBasicAiCredits,
    includedAdvancedAiCredits: selected.includedAdvancedAiCredits,
    aiCreditsBilledSeparately: true,
  }
}

function planDocument(plan, timestampValue) {
  const selected = planFor(plan?.code || plan?.id || plan)
  return {
    planId: selected.id,
    code: selected.code,
    name: selected.name,
    description: selected.code === "discovery" ? "Tester la vente photo avec une conservation limitée." : selected.code === "pro" ? "Offre recommandée pour les photographes indépendants." : selected.code === "studio" ? "Pour les studios événementiels et volumes réguliers." : "Pour les équipes, marques et organisateurs multi-événements.",
    monthlyPrice: selected.monthlyPrice,
    annualPrice: selected.annualPrice,
    maxPublishedPhotos: selected.maxPublishedPhotos,
    maxStorageBytes: selected.maxStorageBytes,
    maxActiveGalleries: selected.maxActiveGalleries,
    maxActivePacks: selected.maxActivePacks,
    commissionRate: selected.commissionRate,
    maxFileBytes: selected.maxFileBytes,
    maxMegapixels: selected.maxMegapixels,
    retentionDays: selected.retentionDays,
    maxCollaborators: selected.maxCollaborators,
    qualityLabel: selected.qualityLabel,
    includedBasicAiCredits: selected.includedBasicAiCredits,
    includedAdvancedAiCredits: selected.includedAdvancedAiCredits,
    aiCreditsBilledSeparately: true,
    isActive: true,
    createdAt: timestampValue,
    updatedAt: timestampValue,
  }
}

function defaultPackDocuments({ photographerId, ownerUid, galleryId, eventId, timestampValue }) {
  return PHOTO_PACKS.map((pack, index) => ({
    packId: `${galleryId}_${pack.code}`,
    photographerId,
    ownerUid,
    galleryId,
    eventId,
    title: pack.title,
    description: pack.highlighted ? "Offre recommandée MASLIVE" : `${pack.photoCount} photo(s) au tarif pack`,
    pricingMode: "pick_n",
    photoIds: [],
    pickCount: pack.photoCount,
    price: pack.price,
    currency: "EUR",
    isActive: true,
    sortOrder: index,
    createdAt: timestampValue,
    updatedAt: timestampValue,
  }))
}

module.exports = {
  GiB,
  MiB,
  MEDIA_HD_UPGRADE_PRICE,
  ESTIMATED_AI_COST_EUR,
  PHOTO_PACKS,
  PHOTOGRAPHER_PLANS,
  STORAGE_EXTENSIONS,
  PHOTOGRAPHER_ADD_ONS,
  planFor,
  extensionForCode,
  packForCode,
  packForCount,
  quoteForPhotoCount,
  bestPackCombination,
  photoSelectionPrice,
  mediaDeliveryQuote,
  stripeFeeEstimate,
  roundCurrency,
  quotaSnapshot,
  planDocument,
  defaultPackDocuments,
}
