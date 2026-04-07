const test = require("node:test")
const assert = require("node:assert/strict")
const fs = require("node:fs")
const path = require("node:path")

function readRepoFile(relativePath) {
  const filePath = path.join(__dirname, "..", relativePath)
  return fs.readFileSync(filePath, "utf8")
}

function sliceBetween(source, startMarker, endMarker) {
  const start = source.indexOf(startMarker)
  if (start === -1) return ""

  const end = endMarker ? source.indexOf(endMarker, start + startMarker.length) : -1
  if (end === -1) return source.slice(start)

  return source.slice(start, end)
}

test("stripe checkout keeps transaction lock guardrails", () => {
  const stripeSrc = readRepoFile("src/media-marketplace-stripe.js")

  assert.match(stripeSrc, /runTransaction\(async \(transaction\) => \{[\s\S]*checkoutLockedUntil/, "checkout lock transaction must exist")
  assert.match(stripeSrc, /Checkout already in progress\. Please wait a moment and try again\./, "concurrent checkout rejection message must exist")
  assert.match(stripeSrc, /lastCheckoutOrderId/, "successful checkout should record last order id")
})

test("storex checkout keeps unified merch cart as single source of truth", () => {
  const indexSrc = readRepoFile("index.js")

  assert.match(indexSrc, /collection\("cart_items"\)[\s\S]*where\("itemType", "==", "merch"\)/, "storex checkout must read merch from unified cart_items")
  assert.doesNotMatch(indexSrc, /userRef\.collection\("cart"\)\.get\(\)/, "storex checkout must not fallback to legacy cart collection")
  assert.doesNotMatch(indexSrc, /legacy_cart/, "storex checkout metadata must not record a legacy cart source")
})

test("media checkout keeps unified cart items as single source of truth", () => {
  const stripeSrc = readRepoFile("src/media-marketplace-stripe.js")

  assert.match(stripeSrc, /const cartItems = unifiedCart\.items/, "media checkout must derive checkout items from unified cart_items")
  assert.match(stripeSrc, /cartSource: "unified_cart_items"/, "media checkout metadata must record unified cart source")
  assert.doesNotMatch(stripeSrc, /Array\.isArray\(cartData\.items\)/, "media checkout must not read legacy cart items arrays")
  assert.doesNotMatch(stripeSrc, /legacy_cart/, "media checkout must not fallback to legacy cart sources")
})

test("media checkout defers cart cleanup until payment confirmation", () => {
  const stripeSrc = readRepoFile("src/media-marketplace-stripe.js")

  assert.match(stripeSrc, /cartItemId: cartItem\.cartItemId \|\| null/, "media order items must retain unified cart item ids")
  assert.match(stripeSrc, /function queueUnifiedMediaCartCleanup\(batch, buyerUid, order\)/, "deferred media cart cleanup helper must exist")
  assert.match(stripeSrc, /collection\(COLLECTIONS\.users\)[\s\S]*collection\(COLLECTIONS\.unifiedCartItems\)[\s\S]*doc\(cartItemId\)/, "cleanup helper must target unified media cart docs by cart item id")
  assert.doesNotMatch(stripeSrc, /unifiedCart\.refs\.forEach\(\(ref\) => batch\.delete\(ref\)\)/, "media checkout must not delete unified cart items before payment confirmation")
})

test("media checkout uses hash-routed web return URLs by default", () => {
  const stripeSrc = readRepoFile("src/media-marketplace-stripe.js")

  assert.match(stripeSrc, /https:\/\/maslive\.web\.app\/#\/media-marketplace\/success/, "media checkout success URL must target Flutter hash route")
  assert.match(stripeSrc, /https:\/\/maslive\.web\.app\/#\/media-marketplace\/cancel/, "media checkout cancel URL must target Flutter hash route")
})

test("media checkout keeps the server lock until success or explicit cancel", () => {
  const stripeSrc = readRepoFile("src/media-marketplace-stripe.js")
  const mixedSection = sliceBetween(
    stripeSrc,
    "async function createMarketplaceOrderForPaymentIntent({ uid, checkoutPayload })",
    "async function fulfillMarketplaceOrderFromPaymentIntent"
  )
  const checkoutSection = sliceBetween(
    stripeSrc,
    "const createMediaMarketplaceCheckout = onCall(",
    "const createPhotographerSubscriptionCheckoutSession = onCall("
  )

  assert.doesNotMatch(
    mixedSection,
    /await checkoutStateRef\.set\([\s\S]*?checkoutLockedUntil: null[\s\S]*?lastCheckoutOrderId: orderId/,
    "mixed media order creation must not release checkout lock immediately"
  )
  assert.doesNotMatch(
    checkoutSection,
    /await checkoutStateRef\.set\([\s\S]*?checkoutLockedUntil: null[\s\S]*?lastCheckoutOrderId: orderId/,
    "media checkout session creation must not release checkout lock immediately"
  )
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
