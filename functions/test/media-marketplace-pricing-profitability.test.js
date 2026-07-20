"use strict"

const test = require("node:test")
const assert = require("node:assert/strict")

const {
  MEDIA_HD_UPGRADE_PRICE,
  ESTIMATED_AI_COST_EUR,
  PHOTO_PACKS,
  PHOTOGRAPHER_PLANS,
  STORAGE_EXTENSIONS,
  extensionForCode,
  quoteForPhotoCount,
  photoSelectionPrice,
  mediaDeliveryQuote,
  stripeFeeEstimate,
  quotaSnapshot,
  planFor,
} = require("../src/media-marketplace-pricing")

test("buyer photo packs expose the approved MASLIVE prices", () => {
  assert.deepEqual(
    PHOTO_PACKS.map((pack) => [pack.photoCount, pack.price]),
    [[1, 6.90], [2, 10.90], [5, 19.90], [10, 29.90], [20, 44.90]],
  )
  assert.equal(PHOTO_PACKS.find((pack) => pack.highlighted)?.code, "essential")
})

test("automatic pricing always uses the cheapest approved offer", () => {
  assert.equal(photoSelectionPrice(1), 6.90)
  assert.equal(photoSelectionPrice(2), 10.90)
  assert.equal(photoSelectionPrice(5), 19.90)
  assert.equal(photoSelectionPrice(7), 29.90)
  assert.equal(photoSelectionPrice(9), 29.90)
  assert.equal(photoSelectionPrice(20), 44.90)
  assert.equal(photoSelectionPrice(21), 51.80)
  assert.deepEqual(quoteForPhotoCount(9), {
    requestedPhotoCount: 9,
    billedPhotoCount: 10,
    bonusPhotoSlots: 1,
    packs: [PHOTO_PACKS.find((pack) => pack.code === "experience")],
    total: 29.90,
  })
})

test("automatic pricing is never more expensive than single photos", () => {
  for (let count = 1; count <= 100; count += 1) {
    assert.ok(photoSelectionPrice(count) <= (count * 6.90), `${count} photos`)
  }
})

test("HD upgrade costs exactly 2.90 euros per order", () => {
  assert.equal(MEDIA_HD_UPGRADE_PRICE, 2.90)
  const quote = mediaDeliveryQuote({ subtotal: 19.90, hdUpgrade: true })
  assert.deepEqual(quote, {
    hdUpgrade: true,
    hdUpgradeAmount: 2.90,
    allowedVariants: ["original", "hd", "preview", "web"],
    total: 22.80,
  })
  assert.equal(Object.isFrozen(quote), true)
  assert.equal(Object.isFrozen(quote.allowedVariants), true)
})

test("standard delivery never grants original or HD variants", () => {
  const quote = mediaDeliveryQuote({ subtotal: 19.90, hdUpgrade: false })
  assert.deepEqual(quote, {
    hdUpgrade: false,
    hdUpgradeAmount: 0,
    allowedVariants: ["preview", "web"],
    total: 19.90,
  })
  assert.equal(quote.allowedVariants.includes("original"), false)
  assert.equal(quote.allowedVariants.includes("hd"), false)
})

test("photographer plans keep exact quotas, quality and commissions", () => {
  assert.deepEqual(
    PHOTOGRAPHER_PLANS.map((plan) => ({
      code: plan.code,
      monthlyPrice: plan.monthlyPrice,
      maxPublishedPhotos: plan.maxPublishedPhotos,
      storageGiB: plan.maxStorageBytes / (1024 ** 3),
      maxMegapixels: plan.maxMegapixels,
      commissionRate: plan.commissionRate,
      includedBasicAiCredits: plan.includedBasicAiCredits,
      includedAdvancedAiCredits: plan.includedAdvancedAiCredits,
    })),
    [
      { code: "discovery", monthlyPrice: 0, maxPublishedPhotos: 250, storageGiB: 3, maxMegapixels: 12, commissionRate: 0.30, includedBasicAiCredits: 0, includedAdvancedAiCredits: 0 },
      { code: "pro", monthlyPrice: 19.90, maxPublishedPhotos: 3000, storageGiB: 30, maxMegapixels: 24, commissionRate: 0.25, includedBasicAiCredits: 0, includedAdvancedAiCredits: 0 },
      { code: "studio", monthlyPrice: 39.90, maxPublishedPhotos: 10000, storageGiB: 120, maxMegapixels: 40, commissionRate: 0.20, includedBasicAiCredits: 0, includedAdvancedAiCredits: 0 },
      { code: "agency", monthlyPrice: 79.90, maxPublishedPhotos: 30000, storageGiB: 400, maxMegapixels: 60, commissionRate: 0.15, includedBasicAiCredits: 0, includedAdvancedAiCredits: 0 },
    ],
  )
})

test("quota snapshots include paid storage without mixing AI credits", () => {
  const quota = quotaSnapshot(planFor("pro"), {
    extraPhotos: 1000,
    extraStorageBytes: 10 * (1024 ** 3),
  })
  assert.equal(quota.maxPublishedPhotos, 4000)
  assert.equal(quota.maxStorageBytes, 40 * (1024 ** 3))
  assert.equal(quota.commissionRate, 0.25)
  assert.equal(quota.includedBasicAiCredits, 0)
  assert.equal(quota.includedAdvancedAiCredits, 0)
  assert.equal(quota.aiCreditsBilledSeparately, true)
})

test("extensions match the approved storage, AI and event prices", () => {
  assert.deepEqual(
    STORAGE_EXTENSIONS.map((extension) => [
      extension.code,
      extension.price,
      extension.extraPhotos,
      extension.extraStorageBytes / (1024 ** 3),
      extension.basicAiCredits || 0,
      extension.advancedAiCredits || 0,
      extension.durationDays || null,
    ]),
    [
      ["plus_1000", 5.90, 1000, 10, 0, 0, null],
      ["plus_5000", 19.90, 5000, 50, 0, 0, null],
      ["ai_basic_1000", 7.90, 0, 0, 1000, 0, 36500],
      ["ai_advanced_1000", 11.90, 0, 0, 0, 1000, 36500],
      ["event_30d", 14.90, 5000, 50, 0, 0, 30],
      ["event_30d_basic", 29.90, 5000, 50, 5000, 0, 30],
      ["event_30d_advanced", 39.90, 5000, 50, 0, 5000, 30],
    ],
  )
  assert.equal(extensionForCode("AI_BASIC_1000").creditsNeverExpire, true)
  assert.equal(extensionForCode("event_30d_advanced").creditsExpireWithExtension, true)
  assert.equal(ESTIMATED_AI_COST_EUR, 0.01)
})

test("Stripe France/EEE fee estimate is 1.5 percent plus 0.25 euro", () => {
  assert.equal(stripeFeeEstimate(19.90), 0.55)
  assert.equal(stripeFeeEstimate(0), 0)
})
