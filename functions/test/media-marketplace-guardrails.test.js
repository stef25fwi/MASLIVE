const test = require("node:test")
const assert = require("node:assert/strict")
const fs = require("node:fs")
const path = require("node:path")

function readRepoFile(relativePath) {
  const filePath = path.join(__dirname, "..", relativePath)
  return fs.readFileSync(filePath, "utf8")
}

test("stripe checkout keeps transaction lock guardrails", () => {
  const stripeSrc = readRepoFile("src/media-marketplace-stripe.js")

  assert.match(stripeSrc, /runTransaction\(async \(transaction\) => \{[\s\S]*checkoutLockedUntil/, "checkout lock transaction must exist")
  assert.match(stripeSrc, /Checkout already in progress\. Please wait a moment and try again\./, "concurrent checkout rejection message must exist")
  assert.match(stripeSrc, /lastCheckoutOrderId/, "successful checkout should record last order id")
})

test("stripe subscription keeps atomic active-subscription guardrails", () => {
  const stripeSrc = readRepoFile("src/media-marketplace-stripe.js")

  assert.match(stripeSrc, /runTransaction\(async \(transaction\) => \{[\s\S]*existingSubscriptionSnapshot/, "subscription check must run in transaction")
  assert.match(stripeSrc, /An active subscription already exists/, "duplicate subscription protection message must exist")
})

test("download signing keeps strict storage-path validation guardrails", () => {
  const mediaSrc = readRepoFile("src/media-marketplace-media.js")

  assert.match(mediaSrc, /function normalizeStoragePath\(path\)/)
  assert.match(mediaSrc, /normalized\.startsWith\("\/"\) \|\| normalized\.includes\("\.\."\) \|\| normalized\.includes\("\/\/"\)/)
  assert.match(mediaSrc, /function isStrictMarketplacePhotoPath\(photo, variant, storagePath\)/)
  assert.match(mediaSrc, /Storage path is not allowed for this entitlement/)
})

test("firestore rules keep media moderation and storage immutability guardrails", () => {
  const rules = readRepoFile("../firestore.rules")

  assert.match(rules, /request\.resource\.data\.moderationStatus == resource\.data\.moderationStatus/)
  assert.match(rules, /request\.resource\.data\.get\('originalPath', ''\) == resource\.data\.get\('originalPath', ''\)/)
  assert.match(rules, /request\.resource\.data\.get\('previewPath', ''\) == resource\.data\.get\('previewPath', ''\)/)
  assert.match(rules, /request\.resource\.data\.get\('thumbnailPath', ''\) == resource\.data\.get\('thumbnailPath', ''\)/)
  assert.match(rules, /request\.resource\.data\.get\('watermarkedPath', ''\) == resource\.data\.get\('watermarkedPath', ''\)/)
})
