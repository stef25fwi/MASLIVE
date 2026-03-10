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

test("stripe pricing breakdown keeps critical fee fields", () => {
  const stripeSrc = readRepoFile("src/media-marketplace-stripe.js")

  assert.match(stripeSrc, /function computeOrderBreakdown\(items\)/, "order breakdown function must exist")
  assert.match(stripeSrc, /const platformFee = items\.reduce\(/, "platform fee computation must exist")
  assert.match(stripeSrc, /const stripeFee = total > 0 \? \(\(total \* 0\.029\) \+ 0\.30\) : 0/, "stripe fee formula guardrail must exist")
  assert.match(stripeSrc, /pricingBreakdown: breakdown/, "orders must persist pricing breakdown snapshot")
})

test("stripe webhook handlers keep critical marketplace events", () => {
  const stripeSrc = readRepoFile("src/media-marketplace-stripe.js")

  assert.match(stripeSrc, /handleMarketplaceCheckoutSessionCompleted/, "checkout completion handler must exist")
  assert.match(stripeSrc, /handleMarketplaceCustomerSubscriptionUpdated/, "subscription updated handler must exist")
  assert.match(stripeSrc, /handleMarketplaceCustomerSubscriptionDeleted/, "subscription deleted handler must exist")
  assert.match(stripeSrc, /handleMarketplaceInvoicePaid/, "invoice paid handler must exist")
  assert.match(stripeSrc, /handleMarketplaceInvoicePaymentFailed/, "invoice failed handler must exist")
})

test("download signing keeps strict storage-path validation guardrails", () => {
  const mediaSrc = readRepoFile("src/media-marketplace-media.js")

  assert.match(mediaSrc, /function normalizeStoragePath\(path\)/)
  assert.match(mediaSrc, /normalized\.startsWith\("\/"\) \|\| normalized\.includes\("\.\."\) \|\| normalized\.includes\("\/\/"\)/)
  assert.match(mediaSrc, /function isStrictMarketplacePhotoPath\(photo, variant, storagePath\)/)
  assert.match(mediaSrc, /Storage path is not allowed for this entitlement/)
})

test("download access keeps entitlement ownership and variant guardrails", () => {
  const mediaSrc = readRepoFile("src/media-marketplace-media.js")

  assert.match(mediaSrc, /if \(entitlement\.buyerUid !== buyerUid\)/, "download must verify entitlement ownership")
  assert.match(mediaSrc, /This entitlement does not belong to you/, "ownership rejection message must exist")
  assert.match(mediaSrc, /if \(!allowedVariants\.includes\(variant\)\)/, "download must enforce entitled variants")
  assert.match(mediaSrc, /denied_variant_not_entitled/, "audit outcome for unauthorized variant must exist")
})

test("firestore rules keep media moderation and storage immutability guardrails", () => {
  const rules = readRepoFile("../firestore.rules")

  assert.match(rules, /request\.resource\.data\.moderationStatus == resource\.data\.moderationStatus/)
  assert.match(rules, /request\.resource\.data\.get\('originalPath', ''\) == resource\.data\.get\('originalPath', ''\)/)
  assert.match(rules, /request\.resource\.data\.get\('previewPath', ''\) == resource\.data\.get\('previewPath', ''\)/)
  assert.match(rules, /request\.resource\.data\.get\('thumbnailPath', ''\) == resource\.data\.get\('thumbnailPath', ''\)/)
  assert.match(rules, /request\.resource\.data\.get\('watermarkedPath', ''\) == resource\.data\.get\('watermarkedPath', ''\)/)
})

test("firestore rules keep photographer plans visibility restricted", () => {
  const rules = readRepoFile("../firestore.rules")

  assert.match(rules, /match \/photographer_plans\/\{planId\} \{[\s\S]*allow read: if isSignedIn\(\) && resource\.data\.isActive == true;/, "photographer plans read rule must stay restricted")
})
