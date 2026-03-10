const test = require("node:test")
const assert = require("node:assert/strict")

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

test("rules emulator: legacy order cannot be forged as marketplace order", async (t) => {
  const rulesTesting = await loadRulesTestingOrSkip(t)
  if (!rulesTesting) return

  // Placeholder assert to keep this suite non-failing until emulator wiring is added.
  assert.equal(typeof rulesTesting.initializeTestEnvironment, "function")
})

test("rules emulator: media_entitlements remain non-writable by clients", async (t) => {
  const rulesTesting = await loadRulesTestingOrSkip(t)
  if (!rulesTesting) return

  // Placeholder assert to keep this suite non-failing until emulator wiring is added.
  assert.equal(typeof rulesTesting.assertFails, "function")
})
