const test = require("node:test")
const assert = require("node:assert/strict")
const fs = require("node:fs")
const path = require("node:path")

let testEnv = null

async function loadRulesTestingOrSkip(t) {
  let rulesTesting
  try {
    rulesTesting = require("@firebase/rules-unit-testing")
  } catch (_e) {
    t.skip("@firebase/rules-unit-testing not installed")
    return null
  }

  if (!process.env.FIRESTORE_EMULATOR_HOST) {
    t.skip("FIRESTORE_EMULATOR_HOST is not set")
    return null
  }

  return rulesTesting
}

test("rules emulator setup", async (t) => {
  const rulesTesting = await loadRulesTestingOrSkip(t)
  if (!rulesTesting) return

  if (testEnv) return

  const rules = fs.readFileSync(
    path.join(__dirname, "..", "..", "firestore.rules"),
    "utf8"
  )

  testEnv = await rulesTesting.initializeTestEnvironment({
    projectId: "maslive-security-tests",
    firestore: { rules },
  })

  t.after(async () => {
    if (testEnv) {
      await testEnv.cleanup()
      testEnv = null
    }
  })

  assert.ok(testEnv)
})

test("rules emulator: legacy order create rejects marketplace-shaped payload", async (t) => {
  const rulesTesting = await loadRulesTestingOrSkip(t)
  if (!rulesTesting) return
  if (!testEnv) {
    t.skip("rules test environment unavailable")
    return
  }

  const db = testEnv.authenticatedContext("user_legacy").firestore()
  const orderRef = db.collection("orders").doc("order_legacy_1")

  await rulesTesting.assertFails(
    orderRef.set({
      userId: "user_legacy",
      groupId: "g1",
      items: [{ productId: "p1", quantity: 1 }],
      totalPrice: 1000,
      status: "pending",
      buyerUid: "user_legacy",
      metadata: { kind: "media_marketplace_order" },
    })
  )
})

test("rules emulator: marketplace order create accepts expected model", async (t) => {
  const rulesTesting = await loadRulesTestingOrSkip(t)
  if (!rulesTesting) return
  if (!testEnv) {
    t.skip("rules test environment unavailable")
    return
  }

  const db = testEnv.authenticatedContext("buyer_market").firestore()
  const orderRef = db.collection("orders").doc("order_market_1")

  await rulesTesting.assertSucceeds(
    orderRef.set({
      orderId: "order_market_1",
      buyerUid: "buyer_market",
      photographerIds: ["photographer_1"],
      photographerOwnerUids: ["owner_1"],
      items: [{ assetId: "photo_1", assetType: "photo", lineSubtotal: 10 }],
      currency: "EUR",
      subtotal: 10,
      stripeFee: 1,
      platformFee: 1,
      taxAmount: 0,
      total: 10,
      photographerNetTotal: 8,
      paymentStatus: "pending",
      deliveryStatus: "pending",
      pricingBreakdown: { subtotal: 10, total: 10 },
      metadata: { kind: "media_marketplace_order" },
      createdAt: null,
      updatedAt: null,
    })
  )
})

test("rules emulator: media_entitlements stay non-writable by client", async (t) => {
  const rulesTesting = await loadRulesTestingOrSkip(t)
  if (!rulesTesting) return
  if (!testEnv) {
    t.skip("rules test environment unavailable")
    return
  }

  const db = testEnv.authenticatedContext("buyer_market").firestore()
  const entRef = db.collection("media_entitlements").doc("ent_1")

  await rulesTesting.assertFails(
    entRef.set({
      entitlementId: "ent_1",
      buyerUid: "buyer_market",
      assetId: "photo_1",
      assetType: "photo",
      isActive: true,
    })
  )
})
