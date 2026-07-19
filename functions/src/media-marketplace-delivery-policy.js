"use strict"

const {
  MEDIA_HD_UPGRADE_PRICE,
  mediaDeliveryQuote,
  roundCurrency,
  stripeFeeEstimate,
} = require("./media-marketplace-pricing")

const MEDIA_DELIVERY_POLICY_VERSION = 1

function asNumber(value, fallback = 0) {
  const parsed = Number(value)
  return Number.isFinite(parsed) ? parsed : fallback
}

function normalizeMediaDeliveryOptions(value) {
  const source = value && typeof value === "object" ? value : {}
  return Object.freeze({ hdUpgrade: source.hdUpgrade === true })
}

function mediaDeliveryOptionsFromPayload(payload) {
  const source = payload && typeof payload === "object" ? payload : {}
  const nestedCheckoutPayload = source.checkoutPayload && typeof source.checkoutPayload === "object"
    ? source.checkoutPayload
    : {}
  return normalizeMediaDeliveryOptions(
    source.mediaDeliveryOptions || nestedCheckoutPayload.mediaDeliveryOptions,
  )
}

function mediaDeliveryRecord(options, quote) {
  return Object.freeze({
    hdUpgrade: options.hdUpgrade === true,
    hdUpgradeAmount: quote.hdUpgradeAmount,
    allowedVariants: Object.freeze([...quote.allowedVariants]),
    policyVersion: MEDIA_DELIVERY_POLICY_VERSION,
    priceScope: "per_order",
    currency: "EUR",
  })
}

function buildMediaDeliveryOrderPatch(order, options) {
  const source = order && typeof order === "object" ? order : {}
  const normalized = normalizeMediaDeliveryOptions(options)
  const baseMediaSubtotal = roundCurrency(
    asNumber(source.baseMediaSubtotal, asNumber(source.subtotal, asNumber(source.total))),
  )
  const quote = mediaDeliveryQuote({
    subtotal: baseMediaSubtotal,
    hdUpgrade: normalized.hdUpgrade,
  })
  const basePlatformFee = roundCurrency(
    asNumber(source.basePlatformFee, asNumber(source.platformFee)),
  )
  const photographerAmount = roundCurrency(asNumber(source.photographerAmount))
  const platformFee = roundCurrency(basePlatformFee + quote.hdUpgradeAmount)
  const stripeFee = stripeFeeEstimate(quote.total)
  const deliveryOptions = mediaDeliveryRecord(normalized, quote)

  return Object.freeze({
    baseMediaSubtotal,
    basePlatformFee,
    subtotal: quote.total,
    total: quote.total,
    platformFee,
    photographerAmount,
    stripeFeeEstimate: stripeFee,
    mediaDeliveryOptions: deliveryOptions,
    deliveryPolicyVersion: MEDIA_DELIVERY_POLICY_VERSION,
    pricingBreakdown: Object.freeze({
      ...(source.pricingBreakdown && typeof source.pricingBreakdown === "object"
        ? source.pricingBreakdown
        : {}),
      baseMediaSubtotal,
      hdUpgradeAmount: quote.hdUpgradeAmount,
      total: quote.total,
      platformFee,
      photographerAmount,
      stripeFee,
      platformNetEstimate: roundCurrency(platformFee - stripeFee),
    }),
  })
}

function appendMediaDeliveryLineItem(payload, options) {
  const source = payload && typeof payload === "object" ? payload : {}
  const normalized = normalizeMediaDeliveryOptions(options)
  if (!normalized.hdUpgrade) return source

  const existingItems = Array.isArray(source.line_items) ? source.line_items : []
  const alreadyPresent = existingItems.some((item) => {
    const metadata = item?.price_data?.product_data?.metadata
    return metadata?.kind === "media_hd_upgrade"
  })
  if (alreadyPresent) return source

  const currency = String(
    existingItems[0]?.price_data?.currency || "eur",
  ).trim().toLowerCase() || "eur"
  const metadata = {
    ...(source.metadata && typeof source.metadata === "object" ? source.metadata : {}),
    mediaHdUpgrade: "true",
    mediaHdUpgradeAmountCents: String(Math.round(MEDIA_HD_UPGRADE_PRICE * 100)),
    mediaDeliveryPolicyVersion: String(MEDIA_DELIVERY_POLICY_VERSION),
  }
  const paymentIntentData = source.payment_intent_data && typeof source.payment_intent_data === "object"
    ? source.payment_intent_data
    : {}

  return {
    ...source,
    line_items: [
      ...existingItems,
      {
        quantity: 1,
        price_data: {
          currency,
          unit_amount: Math.round(MEDIA_HD_UPGRADE_PRICE * 100),
          product_data: {
            name: "Option téléchargement HD",
            description: "Accès aux fichiers originaux et aux variantes haute définition de la commande photo.",
            metadata: {
              kind: "media_hd_upgrade",
              priceScope: "per_order",
              policyVersion: String(MEDIA_DELIVERY_POLICY_VERSION),
            },
          },
        },
      },
    ],
    metadata,
    payment_intent_data: {
      ...paymentIntentData,
      metadata: {
        ...(paymentIntentData.metadata && typeof paymentIntentData.metadata === "object"
          ? paymentIntentData.metadata
          : {}),
        mediaHdUpgrade: "true",
        mediaHdUpgradeAmountCents: String(Math.round(MEDIA_HD_UPGRADE_PRICE * 100)),
        mediaDeliveryPolicyVersion: String(MEDIA_DELIVERY_POLICY_VERSION),
      },
    },
  }
}

function adjustMarketplaceOrderResult(result, patch, checkoutPayload) {
  const source = result && typeof result === "object" ? result : {}
  const totalCents = Math.round(asNumber(patch?.total) * 100)
  const groups = checkoutPayload && typeof checkoutPayload === "object"
    ? checkoutPayload.groups
    : null
  const mediaItems = groups && Array.isArray(groups.media) ? groups.media : []

  return {
    ...source,
    amountCents: totalCents,
    totalCents,
    itemsCount: asNumber(source.itemsCount, mediaItems.length),
    pricingBreakdown: patch?.pricingBreakdown || source.pricingBreakdown || null,
    mediaDeliveryOptions: patch?.mediaDeliveryOptions || null,
  }
}

module.exports = {
  MEDIA_DELIVERY_POLICY_VERSION,
  normalizeMediaDeliveryOptions,
  mediaDeliveryOptionsFromPayload,
  buildMediaDeliveryOrderPatch,
  appendMediaDeliveryLineItem,
  adjustMarketplaceOrderResult,
}
