"use strict"

const test = require("node:test")
const assert = require("node:assert/strict")

const {
  MEDIA_DELIVERY_POLICY_VERSION,
  normalizeMediaDeliveryOptions,
  mediaDeliveryOptionsFromPayload,
  buildMediaDeliveryOrderPatch,
  appendMediaDeliveryLineItem,
  adjustMarketplaceOrderResult,
} = require("../src/media-marketplace-delivery-policy")

test("delivery option accepts only the strict boolean true", () => {
  assert.deepEqual(normalizeMediaDeliveryOptions({ hdUpgrade: true }), {
    hdUpgrade: true,
  })
  assert.deepEqual(normalizeMediaDeliveryOptions({ hdUpgrade: "true" }), {
    hdUpgrade: false,
  })
  assert.deepEqual(
    mediaDeliveryOptionsFromPayload({
      checkoutPayload: { mediaDeliveryOptions: { hdUpgrade: true } },
    }),
    { hdUpgrade: true },
  )
})

test("standard delivery keeps the base price and limits download rights", () => {
  const patch = buildMediaDeliveryOrderPatch({
    subtotal: 19.90,
    total: 19.90,
    platformFee: 4.98,
    photographerAmount: 14.92,
    pricingBreakdown: { total: 19.90 },
  }, { hdUpgrade: false })

  assert.equal(patch.baseMediaSubtotal, 19.90)
  assert.equal(patch.total, 19.90)
  assert.equal(patch.platformFee, 4.98)
  assert.equal(patch.photographerAmount, 14.92)
  assert.deepEqual(patch.mediaDeliveryOptions.allowedVariants, ["preview", "web"])
  assert.equal(patch.mediaDeliveryOptions.hdUpgradeAmount, 0)
  assert.equal(patch.deliveryPolicyVersion, MEDIA_DELIVERY_POLICY_VERSION)
})

test("HD delivery adds 2.90 euros once and leaves photographer payout unchanged", () => {
  const patch = buildMediaDeliveryOrderPatch({
    subtotal: 19.90,
    total: 19.90,
    platformFee: 4.98,
    photographerAmount: 14.92,
    pricingBreakdown: { total: 19.90 },
  }, { hdUpgrade: true })

  assert.equal(patch.total, 22.80)
  assert.equal(patch.platformFee, 7.88)
  assert.equal(patch.photographerAmount, 14.92)
  assert.equal(patch.stripeFeeEstimate, 0.59)
  assert.equal(patch.pricingBreakdown.platformNetEstimate, 7.29)
  assert.deepEqual(
    patch.mediaDeliveryOptions.allowedVariants,
    ["original", "hd", "preview", "web"],
  )
})

test("Stripe checkout receives one dedicated HD line and audit metadata", () => {
  const source = {
    mode: "payment",
    line_items: [{
      quantity: 1,
      price_data: {
        currency: "eur",
        unit_amount: 1990,
        product_data: { name: "Pack Essentiel" },
      },
    }],
    metadata: { kind: "media_marketplace_order" },
    payment_intent_data: { metadata: { orderId: "order-1" } },
  }

  const upgraded = appendMediaDeliveryLineItem(source, { hdUpgrade: true })
  assert.equal(upgraded.line_items.length, 2)
  assert.equal(upgraded.line_items[1].price_data.unit_amount, 290)
  assert.equal(
    upgraded.line_items[1].price_data.product_data.metadata.kind,
    "media_hd_upgrade",
  )
  assert.equal(upgraded.metadata.mediaHdUpgrade, "true")
  assert.equal(upgraded.payment_intent_data.metadata.mediaHdUpgradeAmountCents, "290")

  const idempotent = appendMediaDeliveryLineItem(upgraded, { hdUpgrade: true })
  assert.equal(idempotent.line_items.length, 2)
  assert.equal(appendMediaDeliveryLineItem(source, { hdUpgrade: false }), source)
})

test("mixed checkout result exposes both amountCents and totalCents", () => {
  const patch = buildMediaDeliveryOrderPatch({
    subtotal: 10.90,
    platformFee: 2.73,
    photographerAmount: 8.17,
  }, { hdUpgrade: true })
  const result = adjustMarketplaceOrderResult(
    { orderId: "order-1", amountCents: 1090 },
    patch,
    { groups: { media: [{ id: "a" }, { id: "b" }] } },
  )

  assert.equal(result.amountCents, 1380)
  assert.equal(result.totalCents, 1380)
  assert.equal(result.itemsCount, 2)
  assert.equal(result.mediaDeliveryOptions.hdUpgrade, true)
})
