"use strict"

const test = require("node:test")
const assert = require("node:assert/strict")
const fs = require("node:fs")
const path = require("node:path")

function read(relativePath) {
  return fs.readFileSync(path.join(__dirname, "..", relativePath), "utf8")
}

test("paid media delivery rights are enforced after both fulfillment paths", () => {
  const source = read("src/media-marketplace-stripe.js")

  assert.match(source, /async function enforceDeliveryEntitlements\(/)
  assert.match(source, /await enforceDeliveryEntitlements\(\{ db, orderId, serverTimestamp \}\)/)
  assert.match(source, /handleMarketplaceCheckoutSessionCompleted:[\s\S]*await finalize\(session\.metadata\.orderId\)/)
  assert.match(source, /fulfillMarketplaceOrderFromPaymentIntent:[\s\S]*await finalize\(paymentIntent\.metadata\.orderId\)/)
})

test("legacy purchases keep their historical HD rights", () => {
  const source = read("src/media-marketplace-stripe.js")

  assert.match(source, /if \(!deliveryOptions \|\| typeof deliveryOptions !== "object"\) return/)
  assert.match(source, /Legacy orders did not persist delivery options/)
})

test("new entitlements use the immutable delivery quote", () => {
  const source = read("src/media-marketplace-stripe.js")

  assert.match(source, /const \{ mediaDeliveryQuote \} = require\("\.\/media-marketplace-pricing"\)/)
  assert.match(source, /allowedVariants: \[\.\.\.quote\.allowedVariants\]/)
  assert.match(source, /hdUpgradeAmount: quote\.hdUpgradeAmount/)
  assert.match(source, /deliveryPolicyVersion: 1/)
})
