"use strict"

const test = require("node:test")
const assert = require("node:assert/strict")
const fs = require("node:fs")
const path = require("node:path")

const root = path.resolve(__dirname, "..")
const packageJson = JSON.parse(fs.readFileSync(path.join(root, "package.json"), "utf8"))
const entrypoint = fs.readFileSync(path.join(root, "firebase-entrypoint.js"), "utf8")


test("Firebase utilise le point d'entrée enrichi", () => {
  assert.equal(packageJson.main, "firebase-entrypoint.js")
})


test("le point d'entrée conserve les exports existants", () => {
  assert.match(entrypoint, /const legacyExports = require\("\.\/index"\)/)
  assert.match(entrypoint, /\.\.\.legacyExports/)
})


test("les trois actions de cycle de vie sont exportées", () => {
  assert.match(entrypoint, /createPhotographerSubscriptionLifecycle/)
  assert.match(entrypoint, /\.\.\.photographerSubscriptionLifecycle/)

  const lifecycle = fs.readFileSync(
    path.join(root, "src", "photographer-subscription-lifecycle.js"),
    "utf8",
  )
  assert.match(lifecycle, /createPhotographerBillingPortalLink/)
  assert.match(lifecycle, /cancelPhotographerSubscription/)
  assert.match(lifecycle, /resumePhotographerSubscription/)
})
