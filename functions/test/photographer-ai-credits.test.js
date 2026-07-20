"use strict"

const test = require("node:test")
const assert = require("node:assert/strict")
const fs = require("node:fs")
const path = require("node:path")

const {
  ESTIMATED_AI_COST_EUR,
  extensionForCode,
} = require("../src/media-marketplace-pricing")

const aiSource = fs.readFileSync(
  path.join(__dirname, "../src/photographer-ai-credits.js"),
  "utf8",
)
const entrypointSource = fs.readFileSync(
  path.join(__dirname, "../firebase-entrypoint.js"),
  "utf8",
)

test("les packs IA et événement respectent la grille économique validée", () => {
  assert.deepEqual(
    [
      "plus_1000",
      "plus_5000",
      "ai_basic_1000",
      "ai_advanced_1000",
      "event_30d",
      "event_30d_basic",
      "event_30d_advanced",
    ].map((code) => {
      const extension = extensionForCode(code)
      return [
        code,
        extension.price,
        extension.extraPhotos,
        extension.basicAiCredits || 0,
        extension.advancedAiCredits || 0,
      ]
    }),
    [
      ["plus_1000", 5.90, 1000, 0, 0],
      ["plus_5000", 19.90, 5000, 0, 0],
      ["ai_basic_1000", 7.90, 0, 1000, 0],
      ["ai_advanced_1000", 11.90, 0, 0, 1000],
      ["event_30d", 14.90, 5000, 0, 0],
      ["event_30d_basic", 29.90, 5000, 5000, 0],
      ["event_30d_advanced", 39.90, 5000, 0, 5000],
    ],
  )
  assert.equal(ESTIMATED_AI_COST_EUR, 0.01)
})

test("chaque achat Stripe génère un lot idempotent de crédits", () => {
  assert.match(aiSource, /photographer_storage_extensions\/\{extensionId\}/)
  assert.match(aiSource, /grantApplied === true/)
  assert.match(aiSource, /aiCreditGrantApplied: true/)
  assert.match(aiSource, /sourceExtensionId: extensionRef\.id/)
  assert.match(aiSource, /creditsExpireWithExtension/)
  assert.match(aiSource, /creditsNeverExpire/)
})

test("la première analyse et la réanalyse manuelle sont les seuls déclencheurs facturés", () => {
  assert.match(aiSource, /const firstAnalysis = after\.processingStatus === "processed"/)
  assert.match(aiSource, /const manualAnalysis = !!manualRequestId/)
  assert.match(aiSource, /if \(!firstAnalysis && !manualAnalysis\) return/)
  assert.match(aiSource, /reason = manualAnalysis \? "manual_reanalysis" : "first_import_analysis"/)
  assert.match(aiSource, /firstAnalysisConsumesOneCredit: true/)
  assert.match(aiSource, /manualReanalysisConsumesOneCredit: true/)
  assert.match(aiSource, /movingPhotoConsumesCredit: false/)
  assert.match(aiSource, /editingPriceConsumesCredit: false/)
  assert.match(aiSource, /editingTagsConsumesCredit: false/)
})

test("un échec Vision rembourse le crédit débité", () => {
  assert.match(aiSource, /async function refundCredit/)
  assert.match(aiSource, /remaining: admin\.firestore\.FieldValue\.increment\(1\)/)
  assert.match(aiSource, /status: "refunded"/)
  assert.match(aiSource, /await refundCredit\(/)
})

test("le mode avancé impose le consentement et le regroupement anonyme", () => {
  assert.match(aiSource, /faceGroupingConsent !== true/)
  assert.match(aiSource, /faceGroupingEnabled !== true/)
  assert.match(aiSource, /anonymousFaceSignatures/)
  assert.match(aiSource, /anonymous_landmark_hash/)
})

test("le nouveau trigger remplace le trigger historique dans l'entrypoint Firebase", () => {
  const completeIndex = entrypointSource.indexOf("...photographerCompleteFlow")
  const aiIndex = entrypointSource.indexOf("...photographerAiCredits")
  assert.ok(completeIndex >= 0)
  assert.ok(aiIndex > completeIndex)
  assert.match(entrypointSource, /const photographerAiCredits = createPhotographerAiCredits/)
})
